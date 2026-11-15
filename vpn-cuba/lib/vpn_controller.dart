import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sing_box/sing_box.dart';

import 'subscription.dart';

/// Listas gratuitas de servidores (texto plano, un enlace por línea).
/// Se prueban en este orden; si la primera falla, se usa la segunda.
const _kSubA =
    'https://raw.githubusercontent.com/0xRadikal/Free-v2ray-Configs/main/top100.txt';
const _kSubB =
    'https://raw.githubusercontent.com/morpheusadam/v2ray-config/main/subs/bundles/best.txt';
const _kIpCheck = 'https://api.ipify.org';

const _kCachedSubKey = 'vpn_cached_subscription';
const _kWorkingLinkKey = 'vpn_working_link';
const _kWarnedKey = 'vpn_warned';

enum VpnPhase { disconnected, searching, connecting, connected, failed }

/// Todo lo que la pantalla única necesita mostrar. La pantalla es tonta:
/// solo pinta este estado, así se puede fotografiar sin VPN real.
class VpnUiState {
  const VpnUiState({
    required this.phase,
    required this.statusText,
    required this.hint,
    this.country,
    this.ip,
    this.elapsed = '',
  });

  final VpnPhase phase;
  final String statusText;
  final String hint;
  final String? country;
  final String? ip;

  /// Tiempo conectado, ya formateado (`02:34`). Vacío si no está conectado.
  final String elapsed;

  bool get isBusy =>
      phase == VpnPhase.searching || phase == VpnPhase.connecting;
  bool get isConnected => phase == VpnPhase.connected;
}

/// Un toque y listo: descarga la lista, prueba servidores y conecta.
/// El usuario nunca ve listas, enlaces ni errores técnicos.
class VpnController extends ChangeNotifier {
  VpnController() {
    try {
      _tunnelSub =
          SingBox.instance.watchConnectionState().listen(_onTunnelState);
    } catch (_) {
      // Sin motor no hay escucha; conectar lo dirá con palabras amables.
    }
  }

  VpnPhase _phase = VpnPhase.disconnected;
  String _statusText = 'Toca Conectar y listo';
  String _hint = 'La app busca sola el mejor servidor gratuito.';
  String? _country;
  String? _ip;
  DateTime? _connectedSince;
  Timer? _timer;
  StreamSubscription<SingBoxConnectionState>? _tunnelSub;
  List<ServerLink> _lastCandidates = const [];
  ServerLink? _currentLink;
  bool _userDisconnect = false;
  bool _reconnectTried = false;

  /// Lista precargada en segundo plano al abrir la app (ver
  /// [preloadServers]): así al tocar Conectar ya está lista y no hay
  /// que esperar la descarga. Fresca 10 minutos; pasado ese tiempo se
  /// vuelve a descargar.
  List<ServerLink>? _preloadedLinks;
  DateTime? _preloadedAt;
  bool _preloadRunning = false;

  VpnUiState get uiState => VpnUiState(
        phase: _phase,
        statusText: _statusText,
        hint: _hint,
        country: _country,
        ip: _ip,
        elapsed: _connectedSince == null
            ? ''
            : _formatElapsed(DateTime.now().difference(_connectedSince!)),
      );

  static String _formatElapsed(Duration d) {
    final total = d.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _setPhase(VpnPhase phase, String statusText, String hint) {
    _phase = phase;
    _statusText = statusText;
    _hint = hint;
    notifyListeners();
  }

  /// El botón grande: conectar si está apagado, desconectar si está encendido.
  Future<void> toggle() async {
    if (_phase == VpnPhase.connected ||
        _phase == VpnPhase.connecting ||
        _phase == VpnPhase.searching) {
      await disconnect();
      return;
    }
    await _connectFlow();
  }

  Future<void> disconnect() async {
    _userDisconnect = true;
    _reconnectTried = false;
    _stopTimer();
    try {
      await SingBox.instance.disconnect();
    } catch (_) {
      // Si ya estaba parado, no pasa nada.
    }
    _currentLink = null;
    _country = null;
    _ip = null;
    _connectedSince = null;
    _setPhase(
      VpnPhase.disconnected,
      'Toca Conectar y listo',
      'La app busca sola el mejor servidor gratuito.',
    );
    _userDisconnect = false;
  }

  /// Precarga en segundo plano: descarga la lista al abrir la app y
  /// la guarda, para que al tocar Conectar ya esté lista. Nunca
  /// bloquea la pantalla y nunca avisa de errores: si falla, Conectar
  /// descarga la lista en ese momento, como antes.
  Future<void> preloadServers() async {
    if (_preloadRunning) return;
    if (_preloadedLinks != null &&
        _preloadedAt != null &&
        DateTime.now().difference(_preloadedAt!) <
            const Duration(minutes: 10)) {
      return;
    }
    _preloadRunning = true;
    try {
      final links = await _downloadServers();
      if (links != null && links.isNotEmpty) {
        _preloadedLinks = links;
        _preloadedAt = DateTime.now();
      }
    } catch (_) {
      // Silencio: la precarga es solo un atajo.
    } finally {
      _preloadRunning = false;
    }
  }

  Future<void> _connectFlow() async {
    _setPhase(
      VpnPhase.searching,
      'Buscando el mejor servidor…',
      'Probando servidores gratuitos…',
    );
    try {
      await SingBox.instance.requestNotificationPermission();
    } catch (_) {
      // Sin permiso de notificaciones la VPN funciona igual.
    }
    // PERMISO DE VPN (Android, VpnService.prepare): se pide EXPLÍCITO
    // antes de probar ningún servidor. En Android muestra el diálogo
    // del sistema ("VPN Cuba quiere configurar una conexión VPN que le
    // permite supervisar el tráfico de red" / Aceptar / Cancelar).
    // Verificado en el plugin sing_box 1.0.0: connect() también lo
    // pide solo (requestPermission: true), pero explícito sale siempre
    // al tocar Conectar, antes de todo. Si ya está concedido, devuelve
    // true al instante sin diálogo. Si el usuario lo niega: mensaje
    // amable y vuelta a Desconectado, nunca se queda en "Buscando…".
    try {
      final granted = await SingBox.instance.requestVpnPermission();
      if (!granted) {
        _setPhase(
          VpnPhase.failed,
          'Necesitas aceptar el permiso de VPN para conectar',
          'Toca el botón para intentarlo de nuevo.',
        );
        return;
      }
    } catch (_) {
      // Si no se pudo pedir aquí, connect() lo intenta de nuevo y su
      // SingBoxPermissionException ya tiene el mensaje amable.
    }
    // VÍA RÁPIDA: si hay un último servidor que funcionó, se prueba
    // PRIMERO sin esperar a descargar la lista. Solo si falla se
    // descarga la lista y se sigue con los demás. Así el segundo
    // toque de Conectar es el más rápido de todos.
    String? failedRaw;
    final workingRaw = await _loadWorkingRaw();
    if (workingRaw != null) {
      final parsed = parseSubscription(workingRaw);
      if (parsed.isNotEmpty) {
        final link = parsed.first;
        _setPhase(
          VpnPhase.connecting,
          'Conectando…',
          'No cierres la app, esto puede tardar unos segundos.',
        );
        try {
          await SingBox.instance.connect(
            link.raw,
            timeout: const Duration(seconds: 10),
          );
          _onConnected(link);
          return;
        } on SingBoxPermissionException {
          _setPhase(
            VpnPhase.failed,
            'Necesitas aceptar el permiso de VPN para conectar',
            'Toca el botón para intentarlo de nuevo.',
          );
          return;
        } on SingBoxCancelledException {
          _setPhase(
            VpnPhase.disconnected,
            'Toca Conectar y listo',
            'La app busca sola el mejor servidor gratuito.',
          );
          return;
        } catch (_) {
          // El bueno de antes ya no responde: se sigue con la lista.
          failedRaw = link.raw;
        }
      }
    }
    final List<ServerLink> links;
    try {
      links = await _loadServers();
    } catch (_) {
      _setPhase(
        VpnPhase.failed,
        'No se pudo conectar, inténtalo de nuevo',
        'Toca el botón para intentarlo de nuevo.',
      );
      return;
    }
    await _tryServers(links, maxAttempts: 6, skipRaw: failedRaw);
  }

  Future<String?> _loadWorkingRaw() async {
    final prefs = await SharedPreferences.getInstance();
    final working = prefs.getString(_kWorkingLinkKey);
    return (working == null || working.isEmpty) ? null : working;
  }

  /// Descarga una lista (8 s por fuente; top100 es pequeña, 21 KB) o
  /// devuelve `null` si no hay red o las dos fuentes fallan.
  Future<List<ServerLink>?> _downloadServers() async {
    for (final url in [_kSubA, _kSubB]) {
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final links = parseSubscription(res.body);
          if (links.length >= 5) {
            await _cacheSubscription(res.body);
            return links;
          }
        }
      } catch (_) {
        // Se prueba la siguiente fuente y luego la copia guardada.
      }
    }
    return null;
  }

  /// Lista precargada si está fresca; si no, descarga (8 s por fuente)
  /// o usa la guardada si no hay red. El último servidor que funcionó
  /// va primero.
  Future<List<ServerLink>> _loadServers() async {
    if (_preloadedLinks != null &&
        _preloadedAt != null &&
        DateTime.now().difference(_preloadedAt!) <
            const Duration(minutes: 10)) {
      return await _withWorkingFirst(_preloadedLinks!);
    }
    final downloaded = await _downloadServers();
    if (downloaded != null) return await _withWorkingFirst(downloaded);
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_kCachedSubKey);
    if (cached != null && cached.isNotEmpty) {
      final links = parseSubscription(cached);
      if (links.isNotEmpty) return await _withWorkingFirst(links);
    }
    throw const _NoServersException();
  }

  Future<List<ServerLink>> _withWorkingFirst(List<ServerLink> links) async {
    final prefs = await SharedPreferences.getInstance();
    final working = prefs.getString(_kWorkingLinkKey);
    if (working == null || working.isEmpty) return links;
    final idx = links.indexWhere((l) => l.raw == working);
    if (idx == 0) return links;
    if (idx > 0) {
      return [links[idx], ...links.where((l) => l.raw != working)];
    }
    final parsed = parseSubscription(working);
    if (parsed.isNotEmpty) return [...parsed, ...links];
    return links;
  }

  Future<void> _cacheSubscription(String body) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCachedSubKey, body);
  }

  Future<void> _saveWorking(String raw) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kWorkingLinkKey, raw);
  }

  /// Prueba servidores en orden (máx. 6), 10 s por intento, en silencio.
  /// [skipRaw] es el servidor que ya falló en la vía rápida: no se
  /// vuelve a probar para no perder 10 s en lo mismo.
  Future<bool> _tryServers(List<ServerLink> links,
      {required int maxAttempts, String? skipRaw}) async {
    final candidates = rankServers(links).take(20).toList();
    _lastCandidates = candidates;
    var attempts = 0;
    for (final link in candidates) {
      if (skipRaw != null && link.raw == skipRaw) continue;
      if (attempts >= maxAttempts) break;
      attempts++;
      _setPhase(
        VpnPhase.connecting,
        attempts == 1 ? 'Conectando…' : 'Probando otro servidor…',
        'No cierres la app, esto puede tardar unos segundos.',
      );
      try {
        await SingBox.instance.connect(
          link.raw,
          timeout: const Duration(seconds: 10),
        );
        _onConnected(link);
        return true;
      } on SingBoxPermissionException {
        _setPhase(
          VpnPhase.failed,
          'Necesitas aceptar el permiso de VPN para conectar',
          'Toca el botón para intentarlo de nuevo.',
        );
        return false;
      } on SingBoxCancelledException {
        // El usuario tocó el botón para cancelar.
        _setPhase(
          VpnPhase.disconnected,
          'Toca Conectar y listo',
          'La app busca sola el mejor servidor gratuito.',
        );
        return false;
      } catch (_) {
        // Servidor malo: se prueba el siguiente sin molestar al usuario.
        continue;
      }
    }
    _setPhase(
      VpnPhase.failed,
      'No se pudo conectar, inténtalo de nuevo',
      'Toca el botón para intentarlo de nuevo.',
    );
    return false;
  }

  void _onConnected(ServerLink link) {
    _currentLink = link;
    _country = countryFromName(link.name);
    _connectedSince = DateTime.now();
    _ip = null;
    _reconnectTried = false;
    unawaited(_saveWorking(link.raw));
    unawaited(_fetchIp());
    _setPhase(
      VpnPhase.connected,
      '¡Ya estás protegido!',
      'Tu conexión pasa por otro país. Toca el botón para desconectar.',
    );
    _startTimer();
  }

  Future<void> _fetchIp() async {
    try {
      final res = await http
          .get(Uri.parse(_kIpCheck))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final ip = res.body.trim();
        if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(ip) ||
            ip.contains(':')) {
          _ip = ip;
          notifyListeners();
        }
      }
    } catch (_) {
      // La IP es un extra: si no se pudo saber, simplemente no se muestra.
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_phase == VpnPhase.connected) notifyListeners();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Si el túnel se cae solo, se prueba una vez el siguiente servidor.
  void _onTunnelState(SingBoxConnectionState state) {
    if (state.status == SingBoxConnectionStatus.disconnected &&
        _phase == VpnPhase.connected &&
        !_userDisconnect &&
        !_reconnectTried) {
      _reconnectTried = true;
      unawaited(_reconnectOnce());
    }
  }

  Future<void> _reconnectOnce() async {
    final current = _currentLink;
    final next = _lastCandidates.firstWhere(
      (l) => current == null || l.raw != current.raw,
      orElse: () => const ServerLink(raw: '', scheme: '', name: ''),
    );
    if (next.raw.isEmpty) {
      _setPhase(
        VpnPhase.failed,
        'Se perdió la conexión, toca para conectar',
        'Toca el botón para intentarlo de nuevo.',
      );
      return;
    }
    _setPhase(
      VpnPhase.connecting,
      'Reconectando…',
      'No cierres la app, esto puede tardar unos segundos.',
    );
    try {
      await SingBox.instance.connect(
        next.raw,
        timeout: const Duration(seconds: 10),
      );
      _onConnected(next);
    } catch (_) {
      _setPhase(
        VpnPhase.failed,
        'Se perdió la conexión, toca para conectar',
        'Toca el botón para intentarlo de nuevo.',
      );
    }
  }

  @override
  void dispose() {
    _stopTimer();
    _tunnelSub?.cancel();
    super.dispose();
  }
}

class _NoServersException implements Exception {
  const _NoServersException();
}

/// Clave del aviso de primera vez (la usa `main.dart`).
String get warnedKey => _kWarnedKey;

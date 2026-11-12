// Sistema de Soporte (Quemia 7.0, Kristian 09:52): el botón Soporte ya
// NO abre WhatsApp directo; abre una ventanita en la app para escribir
// y enviar. Los mensajes van a Firestore ('support_messages') y el
// admin responde desde el panel; la respuesta llega a la bandeja local
// de notificaciones (listenForReplies).
//
// Reglas (las de toda la capa online 7.0):
//   - Puerta de identidad (09:19): solo con Google vinculada. Sin
//     ella, sendMessage devuelve false y no toca Firestore; las
//     lecturas devuelven vacío.
//   - Timeout de 5 s en cada llamada, fallo en silencio, nada
//     bloquea: sin internet el mensaje queda encolado en local
//     (SharedPreferences) y se reintenta solo al abrir la app y al
//     volver a primer plano (retryPendingSupport, lo llama main()).
//   - Nada online dentro del estudio: este servicio solo lo llaman
//     main(), la ventanita de Soporte y la bandeja.
//   - Sin textos de interfaz aquí: el título del aviso de respuesta
//     usa la clave existente 'supportWord' y el cuerpo ES la
//     respuesta del admin (valor, no texto de UI); la ventanita la
//     construye la UI contra esta API (los textos en 6 idiomas los
//     pone el agente de UI).
//   - La respuesta automática de Muse NO va en esta versión.
//
// Colección 'support_messages' (campos canónicos, LOS MISMOS que
// lee la app de admin: authorUid, username, message, createdAt,
// status ('abierto' o 'respondido'), reply, replyAt):
//   - createdAt y replyAt se escriben como Timestamp de Firestore
//     (la app de admin solo entiende Timestamp/DateTime: un entero
//     en milisegundos lo leería como 1970). En la cola local
//     (JSON) se guardan como milisegundos y al reintentar se
//     convierten de nuevo a Timestamp.
//   - reply es null hasta que responde el admin (la admin lo lee
//     como '' si viene null); replyAt es null hasta la respuesta.
//   - Lectura tolerante: fromMap acepta también los alias
//     'uid'/'createdAtMs'/'repliedAtMs' por si un documento viejo
//     se escribió con esos nombres, y reply '' como "sin respuesta".
//
// Los ajustes remotos viven en 'settings/app' (los mismos que lee
// la app de admin): 'supportNumber' (por defecto '+5356519431') y
// 'showWhatsApp' (por defecto false). Se aceptan también como
// alias los nombres 'supportWhatsAppNumber'/'showWhatsAppInSupport'
// por si el documento remoto los trae así; mandan los canónicos.

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_sync.dart';
import 'auth_service.dart';
import 'localization.dart';
import 'notification_inbox.dart';
import 'online_common.dart';
import 'user_prefs.dart';

/// Un mensaje de soporte (mío) con su respuesta del admin, si la hay.
class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.authorUid,
    required this.username,
    required this.message,
    required this.createdAt,
    required this.status,
    this.reply,
    this.replyAt,
  });

  final String id;
  final String authorUid;
  final String username;
  final String message;
  final DateTime createdAt;

  /// 'abierto' o 'respondido'.
  final String status;

  /// Respuesta del admin (null hasta que responde).
  final String? reply;

  /// Cuándo respondió el admin (null hasta que responde).
  final DateTime? replyAt;

  /// ¿Trae respuesta del admin (texto no vacío)?
  bool get hasReply => (reply ?? '').trim().isNotEmpty;

  /// ¿Ya está respondido? (status 'respondido' o reply no vacío).
  bool get isAnswered => status == 'respondido' || hasReply;

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// null si el mapa no trae lo mínimo (autor, texto y fecha sanos).
  /// El status se normaliza a 'abierto'/'respondido': un valor roto
  /// se deriva de si hay respuesta o no. Acepta los alias
  /// 'uid' (authorUid), 'createdAtMs' (createdAt) y 'repliedAtMs'
  /// (replyAt), y reply '' como "sin respuesta".
  static SupportMessage? fromMap(
      String id, Map<String, dynamic> map) {
    final authorUid = map['authorUid'] ?? map['uid'];
    final message = map['message'];
    final createdAt =
        _parseDate(map['createdAt'] ?? map['createdAtMs']);
    if (id.isEmpty || authorUid is! String || authorUid.isEmpty) {
      return null;
    }
    if (message is! String || message.trim().isEmpty) return null;
    if (createdAt == null) return null;
    final reply = map['reply'];
    final cleanReply =
        reply is String && reply.trim().isNotEmpty ? reply : null;
    final rawStatus = map['status'];
    final status = rawStatus == 'respondido'
        ? 'respondido'
        : rawStatus == 'abierto'
            ? 'abierto'
            : (cleanReply != null ? 'respondido' : 'abierto');
    return SupportMessage(
      id: id,
      authorUid: authorUid,
      username:
          map['username'] is String ? map['username'] as String : '',
      message: message,
      createdAt: createdAt,
      status: status,
      reply: cleanReply,
      replyAt: _parseDate(map['replyAt'] ?? map['repliedAtMs']),
    );
  }

  /// Mapa canónico para escribir en 'support_messages': las fechas
  /// van como Timestamp (lo que espera la app de admin).
  Map<String, dynamic> toMap() => <String, dynamic>{
        'authorUid': authorUid,
        'username': username,
        'message': message,
        'createdAt': Timestamp.fromDate(createdAt),
        'status': status,
        'reply': reply,
        'replyAt':
            replyAt == null ? null : Timestamp.fromDate(replyAt!),
      };

  /// Igual que toMap, pero con las fechas en milisegundos (para la
  /// cola local en SharedPreferences, que es JSON).
  Map<String, dynamic> toLocalMap() => <String, dynamic>{
        'authorUid': authorUid,
        'username': username,
        'message': message,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'status': status,
        'reply': reply,
        'replyAt': replyAt?.millisecondsSinceEpoch,
      };
}

/// Ajustes de soporte del documento remoto 'settings/app' (los edita
/// el admin; los mismos que lee la app de admin). El número es el del
/// soporte de Quemia; showWhatsApp decide si la ventanita ofrece
/// también la opción de WhatsApp.
class SupportSettings {
  const SupportSettings({
    required this.supportNumber,
    required this.showWhatsApp,
  });

  /// Número de soporte de Quemia (el del creador).
  static const String defaultNumber = '+5356519431';

  /// Valores si no hay remoto ni caché: número del creador y SIN
  /// opción de WhatsApp (la ventanita es el canal de soporte).
  static const SupportSettings defaults = SupportSettings(
    supportNumber: defaultNumber,
    showWhatsApp: false,
  );

  final String supportNumber;
  final bool showWhatsApp;

  /// Lee un mapa remoto (o de caché) sobre [fallback]: cada campo
  /// remoto válido manda; lo que falte o venga roto conserva el del
  /// fallback. Así un remoto parcial (solo un campo) no borra el
  /// otro. Acepta los alias 'supportWhatsAppNumber' y
  /// 'showWhatsAppInSupport' si los canónicos no vienen.
  static SupportSettings fromMap(
    Map<String, dynamic> map, [
    SupportSettings fallback = defaults,
  ]) {
    final number = map['supportNumber'] ?? map['supportWhatsAppNumber'];
    final wa = map['showWhatsApp'] ?? map['showWhatsAppInSupport'];
    return SupportSettings(
      supportNumber: number is String && number.trim().isNotEmpty
          ? number.trim()
          : fallback.supportNumber,
      showWhatsApp: wa is bool ? wa : fallback.showWhatsApp,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'supportNumber': supportNumber,
        'showWhatsApp': showWhatsApp,
      };
}

class SupportService {
  SupportService._();

  /// Instancia única: la UI (ventanita de Soporte) y main() usan esta.
  static final SupportService instance = SupportService._();

  static const String collection = 'support_messages';

  /// Cola de mensajes que quedaron sin enviar (sin internet).
  static const String _pendingKey = 'melli_online_pending_support';

  /// Caché local de los ajustes remotos (para leer sin red).
  static const String _settingsCacheKey = 'melli_support_settings';

  /// Ids de mensajes cuya respuesta YA avisó en la bandeja: así el
  /// aviso sale una sola vez, también entre reinicios de la app.
  static const String _seenRepliesKey = 'melli_support_seen_replies';

  /// Cada cuánto se vuelve a mirar si el admin respondió (además del
  /// chequeo inmediato al arrancar y al volver a primer plano).
  static const Duration _replyCheckInterval = Duration(minutes: 5);

  /// Intervalo del sondeo de watchMyMessages (30 s en la app; los
  /// tests lo acortan para no esperar).
  @visibleForTesting
  static Duration watchPollInterval = const Duration(seconds: 30);

  AnalyticsRepository get _repo => AnalyticsSync.repository;
  String get _me => AuthService.currentUid ?? '';
  String get _myName => UserPrefs.userName;

  bool _listening = false;
  Timer? _replyTimer;
  bool _checkingReplies = false;
  final Set<String> _seenRepliedIds = {};
  bool _seenLoaded = false;

  /// Envía [text] como mensaje de soporte. Devuelve true si quedó
  /// enviado; false si quedó encolado en local (sin internet), sin
  /// Google vinculada o con el texto vacío. Nunca lanza ni muestra
  /// un error feo: lo encolado se envía solo al volver internet
  /// (retryPendingSupport, al abrir la app y al volver a primer
  /// plano). Sin Google no se escribe nada en ningún lado.
  Future<bool> sendMessage(String text) async {
    try {
      final clean = text.trim();
      if (clean.isEmpty) return false;
      if (!OnlineCommon.allowed || _me.isEmpty) return false;
      final msg = SupportMessage(
        id: '',
        authorUid: _me,
        username: _myName,
        message: clean,
        createdAt: DateTime.now(),
        status: 'abierto',
      );
      final id = await OnlineCommon.call(
          () => _repo.createDoc(collection, msg.toMap()));
      if (id != null) return true;
      await OnlineCommon.enqueue(_pendingKey, msg.toLocalMap());
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Mis mensajes con sus respuestas, los más nuevos primero. Vacío
  /// sin Google o sin internet. Nunca lanza.
  Future<List<SupportMessage>> fetchMyMessages() async {
    if (!OnlineCommon.allowed || _me.isEmpty) return [];
    final docs = await OnlineCommon.call(() => _repo.queryDocs(
          collection,
          whereField: 'authorUid',
          isEqualTo: _me,
        ));
    if (docs == null) return [];
    final out = <SupportMessage>[];
    for (final doc in docs) {
      final id = doc['id']?.toString() ?? '';
      final msg = SupportMessage.fromMap(id, doc);
      if (msg != null) out.add(msg);
    }
    // Orden en el teléfono (no orderBy en la consulta: con el filtro
    // por autor, ordenar en Firestore exigiría un índice compuesto y
    // la consulta fallaría en silencio sin él). Los documentos
    // escritos por una versión vieja con el campo 'uid' en vez de
    // 'authorUid' no salen en esta consulta: fromMap los acepta al
    // leerlos, pero la consulta filtra por authorUid.
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  /// Mis mensajes en vivo: emite la lista al suscribirse y la
  /// vuelve a leer cada [watchPollInterval]. La UI la escucha para
  /// que la respuesta del admin aparezca en la ventanita sin
  /// recargar. Sin Google emite listas vacías.
  Stream<List<SupportMessage>> watchMyMessages() async* {
    yield await fetchMyMessages();
    await for (final _ in Stream.periodic(watchPollInterval)) {
      yield await fetchMyMessages();
    }
  }

  /// Ajustes de soporte (número y opción de WhatsApp): primero el
  /// remoto ('settings/app'); si no hay red o el remoto es inválido,
  /// la caché local; si tampoco hay caché, los valores por defecto.
  /// Un remoto válido se guarda en caché (también parcial: cada
  /// campo remoto válido se mezcla sobre lo cacheado). Nunca lanza.
  Future<SupportSettings> fetchSupportSettings() async {
    SupportSettings base = SupportSettings.defaults;
    try {
      final cached = await _cachedSettings();
      if (cached != null) base = cached;
    } catch (_) {
      // Sin caché: siguen los valores por defecto.
    }
    try {
      final remote = await AnalyticsSync.fetchRemoteSettings();
      final hasRemote = (remote['supportNumber'] is String &&
              (remote['supportNumber'] as String).trim().isNotEmpty) ||
          (remote['supportWhatsAppNumber'] is String &&
              (remote['supportWhatsAppNumber'] as String)
                  .trim()
                  .isNotEmpty) ||
          remote['showWhatsApp'] is bool ||
          remote['showWhatsAppInSupport'] is bool;
      if (!hasRemote) return base;
      final merged = SupportSettings.fromMap(remote, base);
      await _saveSettingsCache(merged);
      return merged;
    } catch (_) {
      return base;
    }
  }

  /// Observa mis mensajes y avisa en la bandeja local cuando llega
  /// una respuesta del admin (reply no vacío en un mensaje que antes
  /// no la tenía). main() la llama al iniciar y al volver a primer
  /// plano: cada llamada hace un chequeo inmediato, y el temporizador
  /// (cada 5 min) solo se arranca una vez. Idempotente y silenciosa:
  /// sin Google o sin internet no hace nada. El aviso sale una sola
  /// vez por respuesta (ids vistos guardados en local).
  void listenForReplies() {
    try {
      unawaited(checkRepliesNow());
      if (_listening) return;
      _listening = true;
      _replyTimer = Timer.periodic(
        _replyCheckInterval,
        (_) => unawaited(checkRepliesNow()),
      );
    } catch (_) {
      // La escucha es opcional: si algo falla, la app sigue.
    }
  }

  /// Un chequeo de respuestas del admin, ahora mismo. Lo usan
  /// listenForReplies (inmediato + temporizador) y los tests. Sin
  /// Google o sin internet no hace nada. Nunca lanza.
  Future<void> checkRepliesNow() async {
    if (_checkingReplies) return;
    _checkingReplies = true;
    try {
      if (!OnlineCommon.allowed || _me.isEmpty) return;
      await _loadSeenReplies();
      final mine = await fetchMyMessages();
      final fresh = <SupportMessage>[];
      for (final m in mine) {
        if (m.hasReply && !_seenRepliedIds.contains(m.id)) {
          fresh.add(m);
        }
      }
      if (fresh.isEmpty) return;
      for (final m in fresh) {
        await NotificationInbox.add(
          id: 'support-reply-${m.id}',
          kind: InboxKind.support,
          title: tr('supportWord'),
          body: m.reply!.trim(),
          data: {'supportMessageId': m.id},
        );
        _seenRepliedIds.add(m.id);
      }
      await _saveSeenReplies();
    } catch (_) {
      // Silencio: el próximo chequeo lo vuelve a intentar.
    } finally {
      _checkingReplies = false;
    }
  }

  /// Reintenta los mensajes que quedaron encolados sin internet.
  /// Devuelve cuántos se enviaron. Lo llama main() al abrir la app
  /// y al volver a primer plano (Regla 2). La fecha guardada en la
  /// cola se convierte de nuevo a Timestamp al enviar.
  Future<int> retryPendingSupport() async {
    if (!OnlineCommon.allowed || _me.isEmpty) return 0;
    final items = await OnlineCommon.pending(_pendingKey);
    var done = 0;
    for (var i = items.length - 1; i >= 0; i--) {
      final item = items[i];
      final msg =
          SupportMessage.fromMap('pending-$i', item);
      if (msg == null) {
        // Entrada rota en la cola: se descarta para no reintentar
        // en vano para siempre.
        await OnlineCommon.removeAt(_pendingKey, i);
        continue;
      }
      final id = await OnlineCommon.call(
          () => _repo.createDoc(collection, msg.toMap()));
      if (id != null) {
        await OnlineCommon.removeAt(_pendingKey, i);
        done++;
      }
    }
    return done;
  }

  /// Mensajes encolados sin enviar (solo lectura local): la
  /// ventanita los muestra mientras no tienen red. Nunca lanza.
  Future<List<SupportMessage>> pendingMessages() async {
    final items = await OnlineCommon.pending(_pendingKey);
    final out = <SupportMessage>[];
    for (var i = 0; i < items.length; i++) {
      final msg = SupportMessage.fromMap('pending-$i', items[i]);
      if (msg != null) out.add(msg);
    }
    return out;
  }

  /// ¿Cuántos mensajes pendientes hay?
  Future<int> pendingCount() => OnlineCommon.pendingCount(_pendingKey);

  Future<SupportSettings?> _cachedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_settingsCacheKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return SupportSettings.fromMap(
          Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveSettingsCache(SupportSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _settingsCacheKey, jsonEncode(settings.toMap()));
    } catch (_) {
      // Guardar la caché es opcional: el remoto se vuelve a leer.
    }
  }

  Future<void> _loadSeenReplies() async {
    if (_seenLoaded) return;
    _seenLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getStringList(_seenRepliesKey);
      if (seen != null) _seenRepliedIds.addAll(seen);
    } catch (_) {
      // Sin lista guardada: se avisará de las respuestas que haya.
    }
  }

  Future<void> _saveSeenReplies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _seenRepliesKey, _seenRepliedIds.toList());
    } catch (_) {
      // Sin guardar la lista, el aviso podría repetirse: inofensivo
      // (la bandeja sustituye la entrada con el mismo id).
    }
  }

  /// Solo para tests: para el temporizador y limpia el estado de
  /// escucha (ids vistos, intervalo de sondeo).
  @visibleForTesting
  void resetForTests() {
    _replyTimer?.cancel();
    _replyTimer = null;
    _listening = false;
    _checkingReplies = false;
    _seenRepliedIds.clear();
    _seenLoaded = false;
    watchPollInterval = const Duration(seconds: 30);
  }
}

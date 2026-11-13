// Tabla de posiciones (ronda #8, Quemia 6.5; rediseño Duolingo
// 7.0, Zona C): filas planas separadas por líneas finas, sin
// cabecera de tabla y sin columna de niveles — nombre + racha con
// llama + XP a la derecha. El top 3 lleva SOLO el laurel de 72 dp
// (decisión de Kristian: se quedan los laureles, sin trofeo, sin
// medalla, sin corona). Puestos 4+: número en el color del acento. Usuario actual
// con fondo verde claro #CCFBF1, sin borde. Avatar = SocialAvatar
// (cara por defecto o foto premium, nunca inicial).
//
// La lista viene en vivo del stream de AnalyticsSync
// (leaderboardStream): ordenada por puntos de mayor a menor,
// con puesto, nombre de usuario, niveles superados, puntos y
// racha. El usuario actual (deviceId == AnalyticsSync.deviceId)
// va resaltado con tinte del acento y "(tú)". Deslizar hacia abajo
// vuelve a escuchar el stream (pull-to-refresh). Sin nadie
// todavía: la mascota + "¡No te duermas! Haz un nivel para
// empezar a subir en la tabla".
//
// entriesStream y currentDeviceId son inyectables para probar la
// pantalla sin Firebase; sin ellos se usan los de AnalyticsSync.

import '../widgets/shadows.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../services/accent.dart';

import '../services/analytics_sync.dart';
import '../services/localization.dart';
import '../services/social_service.dart';
import '../widgets/lucide_icons.dart';
import '../widgets/social_avatar.dart';
import '../widgets/online_gate.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    this.entriesStream,
    this.currentDeviceId,
    this.isGoogleLinked,
    this.onLinkGoogle,
  });

  final Stream<List<LeaderboardEntry>>? entriesStream;
  final String? currentDeviceId;

  /// null = preguntar a AuthService (puerta de Google).
  final bool? isGoogleLinked;
  final Future<bool> Function()? onLinkGoogle;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Stream<List<LeaderboardEntry>> _stream;

  /// Sin datos pasado este tiempo, la espera es que no hay internet
  /// (regla 2): se muestra el estado tranquilo, no un spinner eterno.
  static const _offlineAfter = Duration(seconds: 8);

  Timer? _offlineTimer;
  var _loadTimedOut = false;

  // Quemia 7.0: animación de subida de puesto — se recuerda el
  // puesto anterior de mi usuario; si mejora, salta un aviso.
  int? _prevMyRank;
  int? _rankUpRank;
  Timer? _rankUpTimer;

  Stream<List<LeaderboardEntry>> get _source =>
      widget.entriesStream ?? AnalyticsSync.leaderboardStream();

  String get _myDeviceId => widget.currentDeviceId ?? AnalyticsSync.deviceId;

  /// ¿Se usa el stream real (sin inyectar)? Solo entonces el
  /// "vacío" puede significar "sin conexión": con un stream
  /// inyectado (tests, previews), vacío es vacío de verdad.
  bool get _usingRealStream => widget.entriesStream == null;

  @override
  void initState() {
    super.initState();
    _stream = _source;
    _startOfflineTimer();
  }

  @override
  void dispose() {
    _offlineTimer?.cancel();
    _rankUpTimer?.cancel();
    super.dispose();
  }

  void _startOfflineTimer() {
    _offlineTimer?.cancel();
    _loadTimedOut = false;
    _offlineTimer = Timer(_offlineAfter, () {
      if (mounted) setState(() => _loadTimedOut = true);
    });
  }

  /// Pull-to-refresh: vuelve a escuchar el stream desde el inicio,
  /// para que la tabla se actualice aunque el stream no haya
  /// empujado nada nuevo.
  Future<void> _refresh() async {
    setState(() => _stream = _source);
    _startOfflineTimer();
    // Dar tiempo a que el nuevo stream emita su primer valor.
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  /// Estado tranquilo (regla 2): solo el texto, sin iconos de
  /// error ni rojo. Sigue siendo deslizable para reintentar con
  /// pull-to-refresh. El texto va centrado en la pantalla
  /// (regla 10: nada de medio pantalla en blanco arriba y el
  /// mensaje pegado arriba).
  Widget _calmMessage(String text) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, height: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Vacío de verdad (con internet): la mascota + la frase, con
  /// pull-to-refresh para reintentar. No hay asset de mascota
  /// durmiendo declarado en pubspec, así que la mascota es Brenda
  /// (assets/brenda.png, ya declarado). La mascota y la frase van
  /// centradas en la pantalla (regla 10), no pegadas arriba con
  /// medio pantalla en blanco debajo.
  Widget _emptyState() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/brenda.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr('lbEmpty'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 17, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text(tr('lbTitle'))),
      body: OnlineGate(
        isGoogleLinked: widget.isGoogleLinked,
        onLinkGoogle: widget.onLinkGoogle,
        child: StreamBuilder<List<LeaderboardEntry>>(
          stream: _stream,
          builder: (context, snapshot) {
            // El stream atrapa sus errores y muestra el estado
            // tranquilo, nunca un error rojo (regla 2). Por si un
            // stream inyectado emite un error, también se atrapa aquí.
            if (snapshot.hasError) {
              return _calmMessage(tr('lbOffline'));
            }
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              // Esperando demasiado: casi seguro sin internet.
              if (_loadTimedOut) return _calmMessage(tr('lbOffline'));
              return const Center(child: CircularProgressIndicator());
            }
            final entries = List<LeaderboardEntry>.of(snapshot.data ?? [])
              ..sort((a, b) => b.points.compareTo(a.points));
            // Quemia 7.0: subida de puesto — si mi puesto mejoró
            // respecto a la última vez, salta el aviso (y se oculta
            // solo a los 4 segundos).
            final myIndex =
                entries.indexWhere((e) => e.deviceId == _myDeviceId);
            final myRank = myIndex < 0 ? null : myIndex + 1;
            if (myRank != null) {
              if (_prevMyRank != null && myRank < _prevMyRank!) {
                final improvedTo = myRank;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || _rankUpRank == improvedTo) return;
                  setState(() => _rankUpRank = improvedTo);
                  _rankUpTimer?.cancel();
                  _rankUpTimer = Timer(const Duration(seconds: 4), () {
                    if (mounted) setState(() => _rankUpRank = null);
                  });
                });
              }
              _prevMyRank = myRank;
            }
            if (entries.isEmpty) {
              // Vacío con el stream real y Firebase sin arrancar
              // (modo avión / sin internet): estado tranquilo, no
              // "Sé el primero...".
              if (_usingRealStream && !AnalyticsSync.firebaseReady) {
                return _calmMessage(tr('lbOffline'));
              }
              return _emptyState();
            }
            return Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: entries.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark
                          ? const Color(0xFF37464F)
                          : const Color(0xFFE5E5E5),
                    ),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final isMe = entry.deviceId == _myDeviceId;
                      return _EntryRow(
                        rank: index + 1,
                        entry: entry,
                        isMe: isMe,
                        isDark: isDark,
                        scheme: scheme,
                      );
                    },
                  ),
                ),
                if (_rankUpRank != null)
                  Positioned(
                    top: 12,
                    left: 56,
                    right: 56,
                    child: _RankUpBanner(rank: _rankUpRank!),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.rank,
    required this.entry,
    required this.isMe,
    required this.isDark,
    required this.scheme,
  });

  final int rank;
  final LeaderboardEntry entry;
  final bool isMe;
  final bool isDark;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final name = isMe ? '${entry.username} ${tr('youSuffix')}' : entry.username;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          // Los 3 primeros (ronda 2b, por Kristian): SOLO el
          // laurel con el número que él envió — sin trofeo,
          // sin medalla, sin avatar con inicial y sin corona.
          // El laurel (72 dp, ronda 2c) va centrado en el hueco
          // de 98 dp del puesto + el avatar, así los nombres
          // quedan alineados con las demás filas.
          if (rank <= 3)
            SizedBox(
              width: 98,
              child: Center(child: _RankLaurel(rank: rank)),
            )
          else ...[
            _RankNumber(rank: rank),
            const SizedBox(width: 10),
            // Avatares por rango (diseño 7.0, añadido de
            // Kristian): solo del 4º en adelante — el aspecto
            // del avatar depende del puesto y se ve igual para
            // todo el que mira la tabla. 4º-10º marco del color del acento,
            // 11º en adelante avatar normal. El hueco es fijo
            // (42) para que los nombres queden alineados. Con
            // marco de rango, la foto de avatar premium se dibuja
            // dentro del marco.
            SizedBox(
              width: 42,
              height: 42,
              child: Center(
                child: SocialAvatar(
                  username: entry.username,
                  size: 36,
                  rank: rank,
                  avatarAsset: isMe
                      ? SocialService.equippedAvatarAsset ?? entry.avatarAsset
                      : entry.avatarAsset,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                // Quemia 7.0: mi insignia equipada junto al nombre.
                if (isMe && SocialService.equippedBadgeId != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _BadgeIcon(id: SocialService.equippedBadgeId!),
                  ),
              ],
            ),
          ),
          // Racha con llama (sin columna de niveles: el diseño
          // Duolingo muestra nombre + racha + XP a la derecha).
          SizedBox(
            width: 56,
            child: Row(
              children: [
                const LucideIcon(
                  LucideIcons.flame,
                  size: 16,
                  color: Color(0xFFFF9600),
                ),
                const SizedBox(width: 3),
                Text(
                  '${entry.streak}',
                  style: TextStyle(fontSize: 15, color: scheme.onSurface),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '${entry.points}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
    // Fila plana (rediseño Duolingo 7.0): sin tarjeta, sin sombra,
    // sin fondo gris. La línea divisoria la pone el separador de la
    // lista. El usuario actual lleva fondo verde claro #CCFBF1,
    // sin borde (en oscuro, tinte del acento).
    return Container(
      key: isMe ? const ValueKey('leaderboard-me') : null,
      color: isMe
          ? (isDark ? scheme.primary.withValues(alpha: 0.25) : AppAccent.primarySoft)
          : Colors.transparent,
      child: content,
    );
  }
}

/// Laurel con el número (ronda 2b): los 3 primeros llevan SOLO
/// el logo que envió Kristian — laurel dorado con el 1, plateado
/// con el 2, bronce con el 3 — recortados de su imagen, con fondo
/// transparente. Sin trofeo, sin medalla, sin avatar con inicial
/// y sin corona. El laurel es el logo entero en una sola pieza.
class _RankLaurel extends StatelessWidget {
  const _RankLaurel({required this.rank});

  final int rank;

  String get _asset => switch (rank) {
        1 => 'assets/laurel_oro.png',
        2 => 'assets/laurel_plata.png',
        _ => 'assets/laurel_bronce.png',
      };

  @override
  Widget build(BuildContext context) {
    // El recorte es apaisado (~1.28:1): a 72 dp de ancho mide
    // ~56 dp de alto. Ronda 2c (Kristian): el laurel era demasiado
    // grande a 96 dp, ahora es más pequeño.
    return SizedBox(
      key: ValueKey('leaderboard-laurel-$rank'),
      width: 72,
      child: Image.asset(
        _asset,
        width: 72,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// Número del puesto, del 4º en adelante: en el color del acento (rediseño
/// Duolingo 7.0), no en oscuro.
class _RankNumber extends StatelessWidget {
  const _RankNumber({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Center(
        child: Text(
          '$rank',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Insignia equipada junto al nombre (Quemia 7.0): círculo ámbar
/// de 20 dp con estrella, trofeo o llama.
class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final icon = switch (id) {
      'badge_trophy' => LucideIcons.trophy,
      'badge_flame' => LucideIcons.flame,
      _ => LucideIcons.star,
    };
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF59E0B),
      ),
      alignment: Alignment.center,
      // Icono oscuro sobre el ámbar: el blanco sobre #F59E0B
      // apenas se lee (regla 6: el contraste se verifica).
      child: LucideIcon(icon, size: 12, color: const Color(0xFF4B4B4B)),
    );
  }
}

/// Aviso de subida de puesto (Quemia 7.0): aparece con un pequeño
/// pop cuando mi puesto mejora y se oculta solo a los 4 segundos.
class _RankUpBanner extends StatelessWidget {
  const _RankUpBanner({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.7, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        key: const ValueKey('rank-up-banner'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppAccent.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            standardShadow(AppAccent.primary),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LucideIcon(
              LucideIcons.trendingUp,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                tr('lbRankUp').replaceFirst('%s', '$rank'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

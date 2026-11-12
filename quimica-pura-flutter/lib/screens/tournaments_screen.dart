// Torneos (Quemia 7.0): activos y próximos, con título, tema,
// fechas, preguntas y premio en puntos + trofeo. Entrar es gratis.
// Cada torneo muestra mi mejor puntaje; al jugar, la clasificación
// con medallas para los 3 primeros. Si quedo 1º: celebración de
// victoria (confeti + trofeo). Sin Google, la puerta.

import 'package:flutter/material.dart';

import '../services/localization.dart';
import '../services/social_service.dart';
import '../services/user_prefs.dart';
import '../widgets/duo_button.dart';
import '../widgets/lucide_icons.dart';
import '../widgets/online_gate.dart';
import '../widgets/simple_quiz.dart';
import '../widgets/social_avatar.dart';
import '../widgets/tournament_victory.dart';

class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({
    super.key,
    this.isGoogleLinked,
    this.onLinkGoogle,
  });

  final bool? isGoogleLinked;
  final Future<bool> Function()? onLinkGoogle;

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  var _online = true;

  @override
  void initState() {
    super.initState();
    SocialService.online.then((v) {
      if (mounted) setState(() => _online = v);
    });
  }

  void _open(TournamentInfo t) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TournamentDetailScreen(
          tournamentId: t.id,
          isGoogleLinked: widget.isGoogleLinked,
          onLinkGoogle: widget.onLinkGoogle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text(tr('tournTitle'))),
      body: OnlineGate(
        isGoogleLinked: widget.isGoogleLinked,
        onLinkGoogle: widget.onLinkGoogle,
        child: !_online
            ? _CalmLine(text: tr('socialOffline'))
            : StreamBuilder<List<TournamentInfo>>(
                stream: SocialService.tournamentsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _CalmLine(text: tr('socialOffline'));
                  }
                  final all = snapshot.data ?? [];
                  if (all.isEmpty) {
                    return _EmptyTournaments(scheme: scheme);
                  }
                  final active =
                      all.where((t) => t.status == 'active').toList();
                  final upcoming =
                      all.where((t) => t.status != 'active').toList();
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      if (active.isNotEmpty) ...[
                        _SectionTitle(text: tr('tournActive')),
                        for (final t in active)
                          _TournamentCard(
                            tournament: t,
                            isDark: isDark,
                            scheme: scheme,
                            onTap: () => _open(t),
                          ),
                      ],
                      if (upcoming.isNotEmpty) ...[
                        _SectionTitle(text: tr('tournUpcoming')),
                        for (final t in upcoming)
                          _TournamentCard(
                            tournament: t,
                            isDark: isDark,
                            scheme: scheme,
                            onTap: () => _open(t),
                          ),
                      ],
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Color(0xFF4B4B4B),
        ),
      ),
    );
  }
}

class _CalmLine extends StatelessWidget {
  const _CalmLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, height: 1.5),
        ),
      ),
    );
  }
}

class _EmptyTournaments extends StatelessWidget {
  const _EmptyTournaments({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFF7E6),
              ),
              alignment: Alignment.center,
              child: const LucideIcon(
                LucideIcons.trophy,
                size: 34,
                color: Color(0xFFFF9600),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr('tournEmpty'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  const _TournamentCard({
    required this.tournament,
    required this.isDark,
    required this.scheme,
    required this.onTap,
  });

  final TournamentInfo tournament;
  final bool isDark;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    // Diseño Duolingo §3.6: tarjeta blanca + borde 2 pt #E5E5E5,
    // radio 16, sin sombra borrosa (se borra el borde ámbar).
    // Un solo ámbar: el trofeo en su círculo #FFF7E6.
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? const Color(0xFF37464F) : const Color(0xFFE5E5E5),
            width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFFF7E6),
                    ),
                    alignment: Alignment.center,
                    child: const LucideIcon(
                      LucideIcons.trophy,
                      size: 22,
                      color: Color(0xFFFF9600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4B4B4B),
                          ),
                        ),
                        Text(
                          t.dateRange,
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${t.topic} · ${tr('tournQuestions').replaceFirst('%s', '${t.questionCount}')}',
                style: const TextStyle(fontSize: 16, color: Color(0xFF4B4B4B)),
              ),
              const SizedBox(height: 4),
              // El premio va en su propia línea: compartiendo la
              // fila con "Tu mejor puntaje" se cortaba a "500…".
              // Estrella amarilla #FFC800, no medalla ámbar.
              Row(
                children: [
                  const LucideIcon(
                    LucideIcons.star,
                    size: 16,
                    color: Color(0xFFFFC800),
                    filled: true,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      tr('tournPrize').replaceFirst('%s', '${t.prizePoints}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B4B4B),
                      ),
                    ),
                  ),
                ],
              ),
              if (t.myBestScore != null) ...[
                const SizedBox(height: 4),
                Text(
                  tr('tournYourBest').replaceFirst('%s', '${t.myBestScore}'),
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: t.joined
                    ? t.status == 'active'
                        ? DuoButton.primary(
                            label: tr('tournPlay').toUpperCase(),
                            onPressed: onTap,
                            fontSize: 17,
                          )
                        // "Unido" (torneo próximo, ya dentro): botón
                    // secundario Duolingo estándar (blanco + borde
                    // 2 pt #E5E5E5 + texto #4B4B4B, §1.4), sin tinte
                    // teal propio: en la pantalla manda un solo
                    // color de acción (regla 9).
                    : DuoButton.secondary(
                            label: tr('tournJoined').toUpperCase(),
                            onPressed: onTap,
                            fontSize: 17,
                          )
                    // Entrar gratis: azul #1CB0F6 (la acción
                    // secundaria es azul en Duolingo). Nunca ámbar.
                    : DuoButton.primary(
                        label: tr('tournJoin').toUpperCase(),
                        onPressed: () async {
                          await SocialService.joinTournament(t.id);
                        },
                        topColor: const Color(0xFF1CB0F6),
                        bottomColor: const Color(0xFF1CB0F6),
                        edgeColor: const Color(0xFF1899D6),
                        fontSize: 17,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detalle de un torneo: clasificación + jugar.
class TournamentDetailScreen extends StatefulWidget {
  const TournamentDetailScreen({
    super.key,
    required this.tournamentId,
    this.isGoogleLinked,
    this.onLinkGoogle,
  });

  final String tournamentId;
  final bool? isGoogleLinked;
  final Future<bool> Function()? onLinkGoogle;

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  var _playing = false;
  var _showVictory = false;
  var _offlineScore = false;
  int? _pendingScore;
  int? _pendingTimeMs;

  /// Tiempo de juego: desde "Jugar" hasta terminar. Es el
  /// desempate en la clasificación (a igualdad de puntos gana el
  /// más rápido): antes llegaba 0 y los empates exactos compartían
  /// puesto.
  final _playStopwatch = Stopwatch();

  void _startPlaying() {
    _playStopwatch.reset();
    _playStopwatch.start();
    setState(() => _playing = true);
  }

  Future<void> _onFinished(int score, int total) async {
    _playStopwatch.stop();
    final timeMs = _playStopwatch.elapsedMilliseconds;
    final online = await SocialService.online;
    if (!online) {
      if (mounted) {
        setState(() {
          _playing = false;
          _offlineScore = true;
          _pendingScore = score;
          _pendingTimeMs = timeMs;
        });
      }
      return;
    }
    final updated = await SocialService.submitTournamentScore(
        widget.tournamentId, score,
        timeMs: timeMs);
    if (!mounted) return;
    setState(() => _playing = false);
    if (updated != null &&
        updated.ranking.isNotEmpty &&
        updated.ranking.first.username == UserPrefs.userName) {
      setState(() => _showVictory = true);
    }
  }

  Future<void> _retrySubmit() async {
    final score = _pendingScore;
    if (score == null) return;
    final online = await SocialService.online;
    if (!online) return;
    await SocialService.submitTournamentScore(widget.tournamentId, score,
        timeMs: _pendingTimeMs ?? 0);
    if (mounted) {
      setState(() {
        _offlineScore = false;
        _pendingScore = null;
        _pendingTimeMs = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('tournTitle'))),
      body: OnlineGate(
        isGoogleLinked: widget.isGoogleLinked,
        onLinkGoogle: widget.onLinkGoogle,
        child: StreamBuilder<List<TournamentInfo>>(
          stream: SocialService.tournamentsStream(),
          builder: (context, snapshot) {
            final all = snapshot.data ?? [];
            final t = all.where((x) => x.id == widget.tournamentId).firstOrNull;
            if (t == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_playing) {
              return SimpleQuizRunner(
                key: ValueKey('tourn-quiz-${t.id}'),
                title: t.title,
                items: kDuelQuestions,
                playerName: UserPrefs.userName,
                shuffleSeed: 11,
                onFinished: _onFinished,
                onExit: () => setState(() => _playing = false),
              );
            }
            return Stack(
              children: [
                _DetailBody(
                  tournament: t,
                  scheme: scheme,
                  offlineScore: _offlineScore,
                  onRetry: _retrySubmit,
                  onPlay:
                      t.status == 'active' && t.joined ? _startPlaying : null,
                  onJoin: t.joined
                      ? null
                      : () async {
                          await SocialService.joinTournament(t.id);
                        },
                ),
                if (_showVictory)
                  TournamentVictory(
                    prizePoints: t.prizePoints,
                    onClose: () => setState(() => _showVictory = false),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.tournament,
    required this.scheme,
    required this.offlineScore,
    required this.onRetry,
    required this.onPlay,
    required this.onJoin,
  });

  final TournamentInfo tournament;
  final ColorScheme scheme;
  final bool offlineScore;
  final VoidCallback onRetry;
  final VoidCallback? onPlay;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final me = UserPrefs.userName;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? scheme.surfaceContainerHighest : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color:
                    isDark ? const Color(0xFF37464F) : const Color(0xFFE5E5E5),
                width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4B4B4B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${t.topic} · ${t.dateRange} · ${tr('tournQuestions').replaceFirst('%s', '${t.questionCount}')}',
                  style:
                      TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                // El premio va en su propia línea: compartiendo la
                // fila con "Tu mejor puntaje" se cortaba a "500…"
                // (igual que en la tarjeta de la lista).
                Row(
                  children: [
                    const LucideIcon(
                      LucideIcons.star,
                      size: 16,
                      color: Color(0xFFFFC800),
                      filled: true,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        tr('tournPrize').replaceFirst('%s', '${t.prizePoints}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B4B4B),
                        ),
                      ),
                    ),
                  ],
                ),
                if (t.myBestScore != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    tr('tournYourBest').replaceFirst('%s', '${t.myBestScore}'),
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: onPlay != null
                      ? DuoButton.primary(
                          label: tr('tournPlay').toUpperCase(),
                          onPressed: onPlay,
                          fontSize: 17,
                        )
                      : onJoin != null
                          ? DuoButton.primary(
                              label: tr('tournJoin').toUpperCase(),
                              onPressed: onJoin,
                              topColor: const Color(0xFF1CB0F6),
                              bottomColor: const Color(0xFF1CB0F6),
                              edgeColor: const Color(0xFF1899D6),
                              fontSize: 17,
                            )
                          : OutlinedButton(
                              onPressed: null,
                              child: Text(tr('tournJoined')),
                            ),
                ),
              ],
            ),
          ),
        ),
        if (offlineScore)
          // Aviso de puntaje sin internet: contenedor plano blanco
          // con borde 2 pt #E5E5E5 y radio 16 (diseño §3.15). Sin
          // tarjeta ámbar con sombra (reglas 3 y 4) y sin borde
          // ámbar: el aviso es neutro, no un error.
          Container(
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: isDark ? scheme.surfaceContainerHighest : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isDark
                      ? const Color(0xFF37464F)
                      : const Color(0xFFE5E5E5),
                  width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr('tournOfflineScore'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: scheme.onSurface),
                  ),
                  const SizedBox(height: 12),
                  // Botón secundario §1.4 (blanco + borde #E5E5E5 +
                  // labio, texto "REINTENTAR" 17 pt peso 800 en
                  // mayúsculas): antes era un OutlinedButton del
                  // tema con "Reintentar" en caja de frase.
                  DuoButton.secondary(
                    label: tr('tournRetry').toUpperCase(),
                    onPressed: onRetry,
                    fontSize: 17,
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
          child: Text(
            tr('tournRanking'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF4B4B4B),
            ),
          ),
        ),
        if (t.ranking.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              tr('tournEmptyRanking'),
              style: TextStyle(
                fontSize: 15,
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (var i = 0; i < t.ranking.length; i++)
            _RankingRow(
              rank: i + 1,
              entry: t.ranking[i],
              isMe: t.ranking[i].username == me,
              isDark: isDark,
              scheme: scheme,
            ),
      ],
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.rank,
    required this.entry,
    required this.isMe,
    required this.isDark,
    required this.scheme,
  });

  final int rank;
  final FriendEntry entry;
  final bool isMe;
  final bool isDark;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF00C2A8);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _TournMedal(rank: rank),
          const SizedBox(width: 10),
          SocialAvatar(
            username: entry.username,
            avatarAsset: entry.avatarAsset,
            badgeId: entry.badgeId,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isMe ? '${entry.username} ${tr('youSuffix')}' : entry.username,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
          Text(
            '${entry.points}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
    // Filas planas (diseño §3.15, como la tabla de posiciones):
    // sin tarjeta gris con sombra (regla 3), separadas por una
    // línea 1 pt #E5E5E5. Mi fila: fondo teal suave, sin borde y
    // sin sombra — el resaltado es el fondo, como en la tabla.
    if (!isMe) {
      return Column(
        children: [
          content,
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E5E5)),
        ],
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: teal.withValues(alpha: isDark ? 0.25 : 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: content,
    );
  }
}

/// Medalla de puesto para los 3 primeros (oro/plata/bronce).
/// Plana (diseño Duolingo §3.6): disco sólido en tinte claro de
/// la medalla + borde 2 pt del color de la medalla, número en
/// #4B4B4B en negrita. Sin degradado (regla 1) y sin sombra
/// borrosa (regla 3); el texto nunca va sobre color (regla 7),
/// así el número se lee igual en oro, plata y bronce.
class _TournMedal extends StatelessWidget {
  const _TournMedal({required this.rank});
  final int rank;

  static const _gold = Color(0xFFFFD700);
  static const _silver = Color(0xFFC0C0C0);
  static const _bronze = Color(0xFFCD7F32);

  @override
  Widget build(BuildContext context) {
    final medalColor = switch (rank) {
      1 => _gold,
      2 => _silver,
      3 => _bronze,
      _ => null,
    };
    if (medalColor == null) {
      return SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      );
    }
    final tint = switch (rank) {
      1 => const Color(0xFFFFF3C4),
      2 => const Color(0xFFEFEFEF),
      _ => const Color(0xFFF7E3CE),
    };
    return Container(
      key: ValueKey('tourn-medal-$rank'),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tint,
        border: Border.all(color: medalColor, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4B4B4B),
        ),
      ),
    );
  }
}

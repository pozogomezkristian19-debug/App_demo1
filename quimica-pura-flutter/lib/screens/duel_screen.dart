// Duelo online (Quemia 7.0): cada jugador en su propio teléfono.
// Retar → las mismas 5 preguntas para los dos → responder →
// "Esperando a tu amigo..." mientras el otro juega → resultado con
// el ganador resaltado. Si el rival no responde: "Tu rival no
// respondió — ganas por abandono". Si pierde el internet a mitad
// de la partida: aviso "[nombre] perdió el internet" con "Esperar
// un poco" o "Terminar la partida ganando por abandono". Cancelar
// deja los puntos intactos y no quita vidas. Sin Google, la puerta.

import 'dart:async';

import 'package:flutter/material.dart';
import '../services/accent.dart';

import '../services/localization.dart';
import '../services/social_service.dart';
import '../services/user_prefs.dart';
import '../widgets/celebration.dart';
import '../widgets/disconnect_banner.dart';
import '../widgets/duo_button.dart';
import '../widgets/lucide_icons.dart';
import '../widgets/online_gate.dart';
import '../widgets/shadows.dart';
import '../widgets/simple_quiz.dart';
import '../widgets/social_avatar.dart';
import '../widgets/twin_avatars.dart';

class DuelScreen extends StatefulWidget {
  const DuelScreen({
    super.key,
    this.opponentUsername,
    this.random = false,
    this.isGoogleLinked,
    this.onLinkGoogle,
    this.initialMatch,
  });

  final String? opponentUsername;
  final bool random;
  final bool? isGoogleLinked;
  final Future<bool> Function()? onLinkGoogle;

  /// Partida ya creada (tests/previews).
  final DuelState? initialMatch;

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen> {
  DuelState? _match;
  StreamSubscription<DuelState>? _sub;
  var _disconnectDismissed = false;
  var _cancelled = false;

  /// Tiempo de juego: desde "Empezar el duelo" hasta terminar.
  /// Es el desempate (a igualdad de aciertos gana el más rápido).
  final _playStopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final match = widget.initialMatch ??
        await SocialService.createDuel(
          opponentUsername: widget.opponentUsername,
          random: widget.random,
        );
    if (!mounted || match == null) return;
    setState(() => _match = match);
    _sub = SocialService.duelStream(match.matchId).listen((next) {
      if (!mounted) return;
      setState(() {
        // El rival volvió: el aviso puede aparecer de nuevo si se
        // vuelve a caer.
        if (next.opponentConnected && _match?.opponentConnected == false) {
          _disconnectDismissed = false;
        }
        // La fase local manda cuando voy por delante: la pantalla
        // lleva la intro (presentación) y el juego (playing); una
        // emisión del repo con fase 'intro' o 'playing' no me
        // devuelve a la presentación ni me saca del juego. El repo
        // no conoce 'playing': su 'playing' al abrir un duelo es
        // la intro en la pantalla. El abandono y el final SÍ pasan
        // (son estados del repo).
        final mine = _match;
        var merged = next;
        if (mine != null) {
          final mineEarly = mine.phase == DuelPhase.intro ||
              mine.phase == DuelPhase.playing;
          final nextEarly = next.phase == DuelPhase.intro ||
              next.phase == DuelPhase.playing;
          if (mineEarly && nextEarly) {
            merged = next.copyWith(phase: mine.phase);
          } else if (mine.phase == DuelPhase.waiting && nextEarly) {
            merged = next.copyWith(phase: DuelPhase.waiting);
          } else if (mine.phase == DuelPhase.finished &&
              next.phase != DuelPhase.finished) {
            merged = next.copyWith(phase: DuelPhase.finished);
          }
        }
        _match = merged;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _beginPlaying() {
    final match = _match;
    if (match == null) return;
    _playStopwatch.reset();
    _playStopwatch.start();
    setState(() => _match = match.copyWith(phase: DuelPhase.playing));
  }

  Future<void> _onFinished(int score, int total) async {
    final match = _match;
    if (match == null) return;
    _playStopwatch.stop();
    await SocialService.submitDuelScore(
      match.matchId,
      score,
      timeMs: _playStopwatch.elapsedMilliseconds,
    );
  }

  Future<void> _cancel() async {
    final match = _match;
    if (match != null) await SocialService.cancelDuel(match.matchId);
    if (!mounted) return;
    setState(() => _cancelled = true);
  }

  Future<void> _claimForfeit() async {
    final match = _match;
    if (match == null) return;
    await SocialService.forfeitDuel(match.matchId);
  }

  bool get _showDisconnect =>
      _match != null &&
      !_match!.opponentConnected &&
      !_disconnectDismissed &&
      (_match!.phase == DuelPhase.playing ||
          _match!.phase == DuelPhase.waiting);

  @override
  Widget build(BuildContext context) {
    // Cabecera limpia con el MISMO fondo que el cuerpo cuando es
    // la pantalla de resultado (oscura): la banda clara encima del
    // cuerpo oscuro se veía como un error (corrección 2026-11-11).
    const dark = Color(0xFF131F24);
    final isResult = _match?.phase == DuelPhase.finished;
    return Scaffold(
      backgroundColor: isResult ? dark : null,
      appBar: AppBar(
        // Título blanco explícito en el resultado: el titleTextStyle
        // del tema gana a foregroundColor y lo dejaba gris oscuro
        // sobre el fondo oscuro (poco contraste).
        title: Text(
          tr('duelTitle'),
          style: isResult ? const TextStyle(color: Colors.white) : null,
        ),
        backgroundColor: isResult ? dark : null,
        foregroundColor: isResult ? Colors.white : null,
        elevation: isResult ? 0 : null,
      ),
      body: OnlineGate(
        isGoogleLinked: widget.isGoogleLinked,
        onLinkGoogle: widget.onLinkGoogle,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_cancelled) return _CancelledView(onBack: () => Navigator.of(context).maybePop());
    final match = _match;
    if (match == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        if (_showDisconnect)
          DisconnectBanner(
            opponentName: match.opponentName,
            onWait: () => setState(() => _disconnectDismissed = true),
            onForfeit: _claimForfeit,
          ),
        Expanded(child: _phaseContent(match)),
      ],
    );
  }

  Widget _phaseContent(DuelState match) {
    switch (match.phase) {
      case DuelPhase.searching:
        return _WaitingView(
          title: tr('duelFindingOpponent'),
          subtitle: null,
          showCancel: true,
          onCancel: _cancel,
        );
      case DuelPhase.intro:
        return _IntroView(
          opponentName: match.opponentName,
          onStart: _beginPlaying,
          onCancel: _cancel,
        );
      case DuelPhase.playing:
        return SimpleQuizRunner(
          key: ValueKey('duel-quiz-${match.matchId}'),
          title: tr('duelAgainst').replaceFirst('%s', match.opponentName),
          items: match.questions,
          playerName: UserPrefs.userName,
          shuffleSeed: 7,
          onFinished: _onFinished,
          onExit: _cancel,
        );
      case DuelPhase.waiting:
        return _WaitingView(
          title: tr('duelWaiting'),
          subtitle: tr('duelWaitingSub'),
          myScore: match.myScore,
          total: match.questions.length,
          showCancel: true,
          onCancel: _cancel,
        );
      case DuelPhase.finished:
        return _ResultView(
          match: match,
          onBack: () => Navigator.of(context).maybePop(),
        );
      case DuelPhase.abandoned:
        return _AbandonedView(
          onClaim: _claimForfeit,
          onCancel: _cancel,
        );
    }
  }
}

/// Vista de espera (buscando rival / esperando al amigo).
class _WaitingView extends StatelessWidget {
  const _WaitingView({
    required this.title,
    required this.subtitle,
    this.myScore,
    this.total,
    required this.showCancel,
    required this.onCancel,
  });

  final String title;
  final String? subtitle;
  final int? myScore;
  final int? total;
  final bool showCancel;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (myScore != null && total != null) ...[
              const SizedBox(height: 16),
              Text(
                '${tr('duelYourScore')}: $myScore/$total',
                style: TextStyle(fontSize: 16, color: scheme.onSurface),
              ),
            ],
            if (showCancel) ...[
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: onCancel,
                child: Text(tr('duelCancel')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IntroView extends StatelessWidget {
  const _IntroView({
    required this.opponentName,
    required this.onStart,
    required this.onCancel,
  });

  final String opponentName;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        // Tarjeta con la sombra estándar (ronda 2): antes era un
        // Card sin elevación ni sombra.
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? scheme.surfaceContainerHighest : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [standardShadow(kShadowNeutralTint)],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: SocialAvatar(username: opponentName, size: 72)),
                const SizedBox(height: 16),
                Text(
                  tr('duelAgainst').replaceFirst('%s', opponentName),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('duelQuestionsNote'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                DuoButton.primary(
                  label: tr('duelStart').toUpperCase(),
                  onPressed: onStart,
                ),
                const SizedBox(height: 10),
                DuoButton.secondary(
                  label: tr('duelCancel').toUpperCase(),
                  onPressed: onCancel,
                  textColor: const Color(0xFF00A18D),
                  edgeColor: AppAccent.primarySoft,
                  fontSize: 15,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiempo en ms → "48 s" o "1:05".
String _fmtTime(int ms) {
  final s = (ms / 1000).round();
  if (s < 60) return '$s s';
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Resultado de duelo (spec §3.12, correcciones de Kristian
/// 2026-11-11): mismo patrón de victoria que el resultado de
/// nivel (§3.4) — pantalla oscura #131F24, mascota grande
/// celebrando, título amarillo, confeti, 2 tarjetas de color
/// sólido EXACTAMENTE iguales (mismo alto y ancho, con la cara
/// de cada jugador dentro, texto BLANCO en negrita) y un solo
/// botón grande del acento "VOLVER". La corona del ganador va SOBRE
/// LA FOTO de la mascota, nunca dentro de una tarjeta (cero
/// amarillo sobre verde). El contenido reparte la pantalla: nada
/// de medio pantalla vacía.
class _ResultView extends StatelessWidget {
  const _ResultView({required this.match, required this.onBack});

  final DuelState match;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF131F24);
    const muted = Color(0xFFAFAFAF);
    final title = match.wonByForfeit
        ? tr('duelYouWin')
        : match.isDraw
            ? tr('duelDraw')
            : match.iWon
                ? tr('duelYouWin')
                : tr('duelYouLose');
    final total = match.questions.length;
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: dark,
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Mascota grande celebrando (sin aro) con la
                        // corona del ganador SOBRE SU FOTO.
                        Column(
                          children: [
                            Center(
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ClipOval(
                                    child: Image.asset(
                                      companionAsset(companionOfTheDay()),
                                      width: 168,
                                      height: 168,
                                      fit: BoxFit.cover,
                                      filterQuality: FilterQuality.medium,
                                    ),
                                  ),
                                  if (match.iWon)
                                    const Positioned(
                                      right: -8,
                                      top: -12,
                                      child: LucideIcon(
                                        LucideIcons.crown,
                                        size: 44,
                                        color: Color(0xFFFFC800),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: match.iWon || match.isDraw
                                    ? const Color(0xFFFFC800)
                                    : Colors.white,
                              ),
                            ),
                            if (match.wonByForfeit) ...[
                              const SizedBox(height: 8),
                              Text(
                                tr('duelWinByForfeitTitle'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 15, color: muted),
                              ),
                            ],
                          ],
                        ),
                        // Las dos tarjetas EXACTAMENTE iguales: mismo
                        // flex (Expanded sin flex distinto), mismo
                        // contenido (cara, nombre, marcador) y texto
                        // blanco en negrita sobre el color.
                        Row(
                          children: [
                            Expanded(
                              child: _DuelScoreCard(
                                color: AppAccent.primary,
                                name: tr('youWord'),
                                score: '${match.myScore}/$total',
                                avatar: SocialAvatar(
                                  username: UserPrefs.userName,
                                  avatarAsset: companionAsset(
                                      Companion.kristian),
                                  size: 72,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DuelScoreCard(
                                color: const Color(0xFF1CB0F6),
                                name: match.opponentName,
                                score: '${match.opponentScore}/$total',
                                avatar: SocialAvatar(
                                  username: match.opponentName,
                                  size: 72,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // El desempate es el tiempo: si los dos tiempos
                        // se conocen, se ven (así un 5/5 perdido no
                        // parece un error).
                        if (match.myTimeMs > 0 && match.opponentTimeMs > 0)
                          Text(
                            tr('duelTimes')
                                .replaceFirst('%s', _fmtTime(match.myTimeMs))
                                .replaceFirst(
                                    '%s', _fmtTime(match.opponentTimeMs)),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 14, color: muted),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: DuoButton.primary(
                            label: tr('duelBack').toUpperCase(),
                            onPressed: onBack,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          if (match.iWon)
            const Positioned.fill(child: CelebrationOverlay()),
        ],
      ),
    );
  }
}

/// Una tarjeta de puntos del duelo (§3.12.2): color sólido, cara
/// del jugador dentro, nombre y marcador en BLANCO y negrita.
/// Las dos tarjetas son idénticas en tamaño: mismo flex y mismo
/// contenido. La corona del ganador NO va aquí (va sobre la foto
/// de la mascota, fuera de las tarjetas).
class _DuelScoreCard extends StatelessWidget {
  const _DuelScoreCard({
    required this.color,
    required this.name,
    required this.score,
    required this.avatar,
  });

  final Color color;
  final String name;
  final String score;

  /// La cara del jugador (SocialAvatar: el muñeco propio o la
  /// cara por defecto del rival; nunca una inicial).
  final Widget avatar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          const SizedBox(height: 10),
          Text(name.toUpperCase(),
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(score,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// El rival no respondió a tiempo: victoria por abandono o cancelar.
class _AbandonedView extends StatelessWidget {
  const _AbandonedView({required this.onClaim, required this.onCancel});

  final VoidCallback onClaim;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LucideIcon(
              LucideIcons.triangleAlert,
              size: 40,
              color: Color(0xFFF59E0B),
            ),
            const SizedBox(height: 16),
            Text(
              tr('duelWinByForfeitTitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            DuoButton.primary(
              label: tr('duelClaimWin').toUpperCase(),
              onPressed: onClaim,
            ),
            const SizedBox(height: 10),
            DuoButton.secondary(
              label: tr('duelCancel').toUpperCase(),
              onPressed: onCancel,
              textColor: const Color(0xFF00A18D),
              edgeColor: AppAccent.primarySoft,
              fontSize: 15,
            ),
          ],
        ),
      ),
    );
  }
}

/// Cancelado: puntos intactos, sin perder vidas.
class _CancelledView extends StatelessWidget {
  const _CancelledView({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('duelCancelKept'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                height: 1.5,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            DuoButton.primary(
              label: tr('duelBack').toUpperCase(),
              onPressed: onBack,
            ),
          ],
        ),
      ),
    );
  }
}

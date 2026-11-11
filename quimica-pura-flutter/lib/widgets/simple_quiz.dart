// Quiz reutilizable (v5): lo usan el examen con tiempo, el reto de dos
// jugadores y cualquier quiz corto. Registra las respuestas en
// ProgressService igual que el quiz de Niveles (aciertos por tema y
// errores para repasar), con sonido y vibración al contestar. Puntos
// por dificultad en cada respuesta (v6). Vidas: NINGUNA (fix4, punto
// 5): las vidas son solo de los niveles; aquí salir no cuesta nada.
//
// - `durationSeconds`: si se pasa, hay cuenta atrás y al llegar a cero
//   se entrega el quiz automáticamente.
// - `playerName`: etiqueta del jugador que está contestando (reto).
// - `trackProgress`: false en el turno del invitado del Reto
//   (jugador 2, sin cuenta): sus respuestas no tocan el progreso.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'lucide_icons.dart';

import '../models.dart';
import '../services/localization.dart';
import '../services/numeric_answer.dart';
import '../services/points.dart';
import '../services/progress.dart';
import '../services/sound_service.dart';
import 'numeric_keypad.dart';
import 'twin_avatars.dart';

/// Tokens claros (paleta propia de Melli-Qui, sin verde Duolingo):
/// teal #00C2A8 como color principal, teal oscuro #00A18D.
const _teal = Color(0xFF00C2A8);
const _tealDark = Color(0xFF00A18D);

class SimpleQuizRunner extends StatefulWidget {
  const SimpleQuizRunner({
    super.key,
    required this.title,
    required this.items,
    required this.onFinished,
    required this.onExit,
    this.durationSeconds,
    this.playerName,
    this.onRepeat,
    this.itemIds,
    this.trackProgress = true,
  });

  final String title;
  final List<QuizQuestion> items;

  /// (correctas, respondidas). En un quiz con tiempo, "respondidas" es
  /// cuántas preguntas se llegaron a contestar antes de que se acabara
  /// el tiempo, no el tamaño de la lista (la lista no tiene fin real).
  final void Function(int score, int total) onFinished;
  final VoidCallback onExit;
  final int? durationSeconds;
  final String? playerName;
  final VoidCallback? onRepeat;

  /// Id de cada pregunta ('bank:...' o 'gen:...'), para guardar los
  /// errores con el id correcto. Si no se pasa, se asume banco.
  final List<String>? itemIds;

  /// false en el turno del invitado del Reto (jugador 2, sin cuenta):
  /// sus respuestas no tocan el progreso (ni puntos, ni estadísticas,
  /// ni errores) y el resultado no muestra la línea de puntos (fix4,
  /// punto 5). Los puntos del Reto son solo los del jugador 1 (tú).
  final bool trackProgress;

  @override
  State<SimpleQuizRunner> createState() => _SimpleQuizRunnerState();
}

class _SimpleQuizRunnerState extends State<SimpleQuizRunner> {
  int _index = 0;
  int _score = 0;
  int _answered = 0; // preguntas contestadas (no las vistas sin contestar)
  int _points = 0; // puntos netos de este quiz (ver points.dart)
  int? _selected;
  List<int> _order = [];
  bool _finished = false;
  Timer? _timer;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _remaining = widget.durationSeconds ?? 0;
    _shuffleOptions();
    if (widget.durationSeconds != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_remaining <= 1) {
          _timer?.cancel();
          if (!_finished) _finish();
        } else {
          setState(() => _remaining--);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _shuffleOptions() {
    _order = [0, 1, 2, 3]..shuffle(Random());
    _selected = null;
  }

  QuizQuestion get _q => widget.items[_index];

  String get _id {
    final ids = widget.itemIds;
    if (ids != null && _index < ids.length) return ids[_index];
    return 'bank:${_q.topic}:${_q.question}';
  }

  Future<void> _feedback(bool correct) async {
    if (correct) {
      await SoundService.correct();
    } else {
      await SoundService.wrong();
    }
  }

  void _answer(int displayedIndex) {
    if (_selected != null) return;
    final realIndex = _order[displayedIndex];
    final correct = realIndex == _q.answer;
    final progress = ProgressService.instance;
    // Puntos por dificultad (v6): el acierto suma, el fallo resta más
    // de lo que el acierto sumaría. Se suman AL CONTESTAR, así que
    // al salir de la partida los puntos ganados se quedan (fix4,
    // punto 5). En el turno del invitado del Reto no se toca el
    // progreso: ni puntos, ni estadísticas, ni errores.
    final delta = correct
        ? pointsForCorrect(_q.difficulty)
        : pointsForWrong(_q.difficulty);
    if (widget.trackProgress) {
      progress.recordAnswer(_q.topic, correct);
      progress.addPoints(delta);
    }
    _feedback(correct);
    if (correct) {
      if (widget.trackProgress) progress.removeFailed(_id);
      setState(() {
        _selected = displayedIndex;
        _score++;
        _answered++;
        _points += delta;
      });
    } else {
      if (widget.trackProgress) {
        progress.addFailed(
            FailedEntry(id: _id, topic: _q.topic, question: _q.question));
      }
      setState(() {
        _selected = displayedIndex;
        _answered++;
        _points += delta;
      });
    }
  }

  /// Respuesta de una pregunta de cálculo (fix3, punto 7): el valor
  /// tecleado en el teclado numérico se traduce al índice de opción
  /// que le corresponde y pasa por el mismo `_answer` de siempre, con
  /// los mismos puntos y repaso de errores (las vidas son solo de los
  /// niveles, fix4, punto 5).
  void _answerNumeric(double value) {
    if (_selected != null) return;
    _answer(displayedIndexForNumericAnswer(
        typed: value, question: _q, order: _order));
  }

  void _next() {
    if (_index + 1 >= widget.items.length) {
      _finish();
    } else {
      setState(() {
        _index++;
        _shuffleOptions();
      });
    }
  }

  void _finish() {
    _timer?.cancel();
    // Se entrega con lo respondido hasta ahora, no con la lista entera:
    // en el examen con tiempo la lista no tiene fin real.
    widget.onFinished(_score, _answered);
    setState(() => _finished = true);
  }

  /// Salir en medio de una partida (fix4, punto 5): este quiz NO
  /// cuesta vidas (las vidas son solo de los niveles): salir termina
  /// la partida y los puntos ganados hasta aquí se quedan. Se pide
  /// confirmación antes de salir. De un quiz ya terminado se sale
  /// directo, sin aviso.
  void _requestExit() {
    if (_finished) {
      widget.onExit();
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('exitNoLivesTitle')),
        content: Text(tr('exitNoLivesBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('exitLevelStay')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              widget.onExit();
            },
            child: Text(tr('exitNoLivesLeave')),
          ),
        ],
      ),
    );
  }

  String get _timeText {
    final m = _remaining ~/ 60;
    final s = _remaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Colores del tema (no fijos): en claro onSurface es la tinta
    // #3C3C3C de siempre y en oscuro es casi blanco, así el título,
    // el botón Salir y la pregunta se leen en los dos temas.
    final scheme = Theme.of(context).colorScheme;
    if (_finished) {
      // En el examen con tiempo, "total" es lo respondido (la lista no
      // tiene fin); en los demás quizzes es el total de la lista.
      final total = _answered;
      final percent = total == 0 ? 0 : ((100 * _score) / total).round();
      final timed = widget.durationSeconds != null;
      final pointsText = _points >= 0 ? '+$_points' : '$_points';
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('quizResult'),
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            if (timed) ...[
              Text('${tr('timedAnswered')}: $total',
                  style: TextStyle(fontSize: 20, color: scheme.onSurface),
                  textAlign: TextAlign.center),
              Text('${tr('quizScore')}: $_score ${tr('quizOf')} $total',
                  style: TextStyle(fontSize: 20, color: scheme.onSurface),
                  textAlign: TextAlign.center),
            ] else
              Text('$_score ${tr('quizOf')} $total ${tr('quizScore')}',
                  style: TextStyle(fontSize: 20, color: scheme.onSurface),
                  textAlign: TextAlign.center),
            Text('$percent%',
                style: const TextStyle(
                    fontSize: 48, fontWeight: FontWeight.bold, color: _teal),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            // Sin cuenta no hay puntos que sumar: en el turno del
            // invitado del Reto no se muestra la línea de puntos.
            if (widget.trackProgress)
              Text('${tr('pointsWord')}: $pointsText',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface),
                  textAlign: TextAlign.center),
            const SizedBox(height: 16),
            MascotBubble(
              companion: companionForTurn(_index),
              mood: (total > 0 && _score * 5 >= total * 3)
                  ? TwinMood.happy
                  : TwinMood.soft,
              text: tr(mascotLineKey(
                  companionForTurn(_index),
                  total > 0 && _score * 5 >= total * 3
                      ? MascotLine.praise
                      : MascotLine.console,
                  _answered)),
            ),
            const SizedBox(height: 24),
            if (widget.onRepeat != null)
              ElevatedButton(
                onPressed: widget.onRepeat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                      // La familia explícita: sin ella el textStyle del
                      // styleFrom sustituye al del tema (que sí trae Roboto)
                      // y el texto quedaba sin fuente definida (en los
                      // tests se veía como una barra sólida).
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                child: Text(tr('quizRepeat')),
              ),
            if (widget.onRepeat != null) const SizedBox(height: 8),
            OutlinedButton(
                onPressed: widget.onExit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _tealDark,
                  side: const BorderSide(color: _teal, width: 2),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                      // La familia explícita: sin ella el textStyle del
                      // styleFrom sustituye al del tema (que sí trae Roboto)
                      // y el texto quedaba sin fuente definida (en los
                      // tests se veía como una barra sólida).
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                child: Text(tr('quizBack'))),
          ],
        ),
      );
    }

    final timed = widget.durationSeconds != null;
    // Bloqueo de sesión (fix2, ronda 2): mientras la partida está
    // en curso, ni el botón atrás del sistema ni la flecha de la
    // barra pueden cerrar la partida directamente: muestran el
    // aviso de Salir (sin pérdida de vida: las vidas son solo de
    // los niveles, fix4, punto 5). Terminada la partida,
    // se sale libre.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.playerName == null
                      ? (timed
                          // Sin "de N": en el examen con tiempo no hay un
                          // total fijo, la meta es responder lo máximo.
                          ? '${widget.title} · ${tr('quizQuestion')} ${_index + 1}'
                          : '${widget.title} · ${tr('quizQuestion')} ${_index + 1} ${tr('quizOf')} ${widget.items.length}')
                      : '${widget.playerName} · ${tr('quizQuestion')} ${_index + 1} ${tr('quizOf')} ${widget.items.length}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: scheme.onSurface),
                  maxLines: 2,
                ),
              ),
              if (widget.durationSeconds != null) ...[
                const SizedBox(width: 8),
                Chip(
                  backgroundColor: scheme.surfaceContainerHighest,
                  side: BorderSide(color: scheme.outlineVariant),
                  avatar: const LucideIcon(LucideIcons.timer,
                      size: 18, color: _tealDark, threeD: true),
                  label: Text(_timeText,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface)),
                ),
              ],
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _requestExit,
                // Icono 3D (fix3, punto 6): el degradado sale del
                // color del botón (onSurface del tema) heredado; el
                // glifo conserva su forma (puerta + flecha).
                icon: const LucideIcon(LucideIcons.logOut,
                    size: 20, threeD: true),
                label:
                    Text(tr('quizExit'), style: const TextStyle(fontSize: 16)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.onSurface,
                  side: BorderSide(color: scheme.outlineVariant),
                  shape: const StadiumBorder(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (timed)
            Text(
              '${tr('timedAnswered')}: $_answered · ${tr('quizScore')}: $_score · ${tr('pointsWord')}: ${_points >= 0 ? '+$_points' : '$_points'}',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: scheme.onSurface),
            )
          else
            LinearProgressIndicator(
              value: (_index + 1) / widget.items.length,
              color: _teal,
              backgroundColor: scheme.surfaceContainerHighest,
              minHeight: 8,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
          const SizedBox(height: 16),
          MascotBubble(
            companion: companionForTurn(_index),
            mood: _selected == null
                ? TwinMood.happy
                : (_order[_selected!] == _q.answer
                    ? TwinMood.happy
                    : TwinMood.soft),
            text: tr(_selected == null
                ? mascotLineKey(
                    companionForTurn(_index), MascotLine.ask, _index)
                : (_order[_selected!] == _q.answer
                    ? mascotLineKey(
                        companionForTurn(_index), MascotLine.praise, _index)
                    : mascotLineKey(
                        companionForTurn(_index), MascotLine.console, _index))),
          ),
          const SizedBox(height: 16),
          Text(_q.question,
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface)),
          const SizedBox(height: 16),
          // Pregunta de cálculo (fix3, punto 7): las 4 opciones dejan
          // paso al teclado numérico, abierto desde el principio. Las
          // conceptuales siguen con las opciones de siempre.
          if (_q.isNumeric)
            NumericKeypad(
              key: ValueKey(_id),
              unit: _q.numericUnit,
              enabled: _selected == null,
              onSubmit: _answerNumeric,
            )
          else
            for (var i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selected == null
                        ? scheme.surfaceContainerHighest
                        : (_order[i] == _q.answer
                            ? _teal
                            : (_selected == i
                                ? Colors.redAccent
                                : scheme.surfaceContainerHighest)),
                    foregroundColor: _selected != null &&
                            (_order[i] == _q.answer || _selected == i)
                        ? Colors.white
                        : scheme.onSurface,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.all(14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _answer(i),
                  child: Text(_q.options[_order[i]],
                      style: const TextStyle(fontSize: 16)),
                ),
              ),
          if (_selected != null) ...[
            const SizedBox(height: 8),
            Card(
              color: _order[_selected!] == _q.answer
                  ? _teal.withValues(alpha: 0.12)
                  : Colors.redAccent.withValues(alpha: 0.12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _order[_selected!] == _q.answer
                          ? tr('quizCorrect')
                          : '${tr('quizIncorrect')}. ${tr('quizCorrectIs')} ${_q.options[_q.answer]}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: scheme.onSurface),
                    ),
                    const SizedBox(height: 6),
                    Text(_q.explanation,
                        style: TextStyle(color: scheme.onSurface)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                    // La familia explícita: sin ella el textStyle del
                    // styleFrom sustituye al del tema (que sí trae Roboto)
                    // y el texto quedaba sin fuente definida (en los
                    // tests se veía como una barra sólida).
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              child: Text(_index + 1 >= widget.items.length
                  ? tr('quizResult')
                  : tr('quizNext')),
            ),
          ],
        ],
      ),
    );
  }
}

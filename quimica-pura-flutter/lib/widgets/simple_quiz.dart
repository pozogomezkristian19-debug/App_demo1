// Quiz reutilizable (v5): lo usan el examen con tiempo, el reto de dos
// jugadores y cualquier quiz corto. Registra las respuestas en
// ProgressService igual que el quiz de Niveles (aciertos por tema y
// errores para repasar), con sonido y vibración al contestar.
//
// - `durationSeconds`: si se pasa, hay cuenta atrás y al llegar a cero
//   se entrega el quiz automáticamente.
// - `playerName`: etiqueta del jugador que está contestando (reto).

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'lucide_icons.dart';

import '../models.dart';
import '../services/localization.dart';
import '../services/points.dart';
import '../services/progress.dart';
import '../services/sound_service.dart';
import 'twin_avatars.dart';

/// Tokens claros (paleta propia de Melli-Qui, sin verde Duolingo):
/// teal #00C2A8 como color principal, teal oscuro #00A18D.
const _teal = Color(0xFF00C2A8);
const _tealDark = Color(0xFF00A18D);
const _ink = Color(0xFF3C3C3C);
const _card = Color(0xFFF7F7F7);
const _border = Color(0xFFE8E8E8);

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
    progress.recordAnswer(_q.topic, correct);
    // Puntos por dificultad (v6): el acierto suma, el fallo resta más
    // de lo que el acierto sumaría.
    final delta = correct
        ? pointsForCorrect(_q.difficulty)
        : pointsForWrong(_q.difficulty);
    progress.addPoints(delta);
    _feedback(correct);
    if (correct) {
      progress.removeFailed(_id);
      setState(() {
        _selected = displayedIndex;
        _score++;
        _answered++;
        _points += delta;
      });
    } else {
      progress.addFailed(
          FailedEntry(id: _id, topic: _q.topic, question: _q.question));
      setState(() {
        _selected = displayedIndex;
        _answered++;
        _points += delta;
      });
    }
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

  String get _timeText {
    final m = _remaining ~/ 60;
    final s = _remaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      // En el examen con tiempo, "total" es lo respondido (la lista no
      // tiene fin); en los demás quizzes es el total de la lista.
      final total = _answered;
      final percent = total == 0 ? 0 : ((100 * _score) / total).round();
      final timed = widget.durationSeconds != null;
      final pointsText =
          _points >= 0 ? '+$_points' : '$_points';
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('quizResult'),
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _ink),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            if (timed) ...[
              Text('${tr('timedAnswered')}: $total',
                  style: const TextStyle(fontSize: 20, color: _ink),
                  textAlign: TextAlign.center),
              Text('${tr('quizScore')}: $_score ${tr('quizOf')} $total',
                  style: const TextStyle(fontSize: 20, color: _ink),
                  textAlign: TextAlign.center),
            ] else
              Text('$_score ${tr('quizOf')} $total ${tr('quizScore')}',
                  style: const TextStyle(fontSize: 20, color: _ink),
                  textAlign: TextAlign.center),
            Text('$percent%',
                style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: _teal),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('${tr('pointsWord')}: $pointsText',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _ink),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            MascotBubble(
              twinA: _index % 2 != 0,
              mood: (total > 0 && _score * 5 >= total * 3)
                  ? TwinMood.happy
                  : TwinMood.soft,
              text: tr(total > 0 && _score * 5 >= total * 3
                  ? mascotPraiseKey(_answered)
                  : mascotConsoleKey(_answered)),
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
                      fontWeight: FontWeight.bold, fontSize: 16),
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
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                child: Text(tr('quizBack'))),
          ],
        ),
      );
    }

    final timed = widget.durationSeconds != null;
    return ListView(
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
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: _ink),
                maxLines: 2,
              ),
            ),
            if (widget.durationSeconds != null) ...[
              const SizedBox(width: 8),
              Chip(
                backgroundColor: _card,
                side: const BorderSide(color: _border),
                avatar: const LucideIcon(LucideIcons.timer, size: 18, color: _tealDark),
                label: Text(_timeText,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: _ink)),
              ),
            ],
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: widget.onExit,
              icon: const LucideIcon(LucideIcons.logOut, size: 20),
              label: Text(tr('quizExit'), style: const TextStyle(fontSize: 16)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _ink,
                side: const BorderSide(color: _border),
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
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: _ink),
          )
        else
          LinearProgressIndicator(
            value: (_index + 1) / widget.items.length,
            color: _teal,
            backgroundColor: const Color(0xFFE8E8E8),
            minHeight: 8,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
        const SizedBox(height: 16),
        MascotBubble(
          twinA: _index % 2 == 0,
          mood: _selected == null
              ? TwinMood.happy
              : (_order[_selected!] == _q.answer
                  ? TwinMood.happy
                  : TwinMood.soft),
          text: tr(_selected == null
              ? mascotCheerKey(_index)
              : (_order[_selected!] == _q.answer
                  ? mascotPraiseKey(_index)
                  : mascotConsoleKey(_index))),
        ),
        const SizedBox(height: 16),
        Text(_q.question,
            style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: _ink)),
        const SizedBox(height: 16),
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selected == null
                    ? _card
                    : (_order[i] == _q.answer
                        ? _teal
                        : (_selected == i ? Colors.redAccent : _card)),
                foregroundColor: _selected != null &&
                        (_order[i] == _q.answer || _selected == i)
                    ? Colors.white
                    : _ink,
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
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: _ink),
                  ),
                  const SizedBox(height: 6),
                  Text(_q.explanation,
                      style: const TextStyle(color: _ink)),
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
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
            child: Text(_index + 1 >= widget.items.length
                ? tr('quizResult')
                : tr('quizNext')),
          ),
        ],
      ],
    );
  }
}

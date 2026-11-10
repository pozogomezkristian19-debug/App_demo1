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
import 'package:flutter/services.dart';

import '../models.dart';
import '../services/localization.dart';
import '../services/progress.dart';
import '../services/user_prefs.dart';

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
  });

  final String title;
  final List<QuizQuestion> items;
  final void Function(int score, int total) onFinished;
  final VoidCallback onExit;
  final int? durationSeconds;
  final String? playerName;
  final VoidCallback? onRepeat;

  @override
  State<SimpleQuizRunner> createState() => _SimpleQuizRunnerState();
}

class _SimpleQuizRunnerState extends State<SimpleQuizRunner> {
  int _index = 0;
  int _score = 0;
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

  String get _id => 'bank:${_q.topic}:${_q.question}';

  Future<void> _feedback(bool correct) async {
    if (!UserPrefs.soundOn) return;
    if (correct) {
      HapticFeedback.lightImpact();
      SystemSound.play(SystemSoundType.click);
    } else {
      HapticFeedback.vibrate();
    }
  }

  void _answer(int displayedIndex) {
    if (_selected != null) return;
    final realIndex = _order[displayedIndex];
    final correct = realIndex == _q.answer;
    final progress = ProgressService.instance;
    progress.recordAnswer(_q.topic, correct);
    _feedback(correct);
    if (correct) {
      progress.removeFailed(_id);
      setState(() {
        _selected = displayedIndex;
        _score++;
      });
    } else {
      progress.addFailed(
          FailedEntry(id: _id, topic: _q.topic, question: _q.question));
      setState(() => _selected = displayedIndex);
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
    widget.onFinished(_score, widget.items.length);
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
      final total = widget.items.length;
      final percent = ((100 * _score) / total).round();
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('quizResult'),
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text('$_score ${tr('quizOf')} $total ${tr('quizScore')}',
                style: const TextStyle(fontSize: 20),
                textAlign: TextAlign.center),
            Text('$percent%',
                style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.tealAccent),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            if (widget.onRepeat != null)
              ElevatedButton(
                onPressed: widget.onRepeat,
                child: Text(tr('quizRepeat')),
              ),
            if (widget.onRepeat != null) const SizedBox(height: 8),
            OutlinedButton(
                onPressed: widget.onExit, child: Text(tr('quizBack'))),
          ],
        ),
      );
    }

    final total = widget.items.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.playerName == null
                    ? '${widget.title} · ${tr('quizQuestion')} ${_index + 1} ${tr('quizOf')} $total'
                    : '${widget.playerName} · ${tr('quizQuestion')} ${_index + 1} ${tr('quizOf')} $total',
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 2,
              ),
            ),
            if (widget.durationSeconds != null) ...[
              const SizedBox(width: 8),
              Chip(
                avatar: const Icon(Icons.timer, size: 18),
                label: Text(_timeText,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: widget.onExit,
              icon: const Icon(Icons.logout, size: 20),
              label: Text(tr('quizExit'), style: const TextStyle(fontSize: 16)),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: (_index + 1) / total),
        const SizedBox(height: 16),
        Text(_q.question,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selected == null
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : (_order[i] == _q.answer
                        ? Colors.teal
                        : (_selected == i
                            ? Colors.redAccent
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest)),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.all(14),
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
                ? Colors.teal.withValues(alpha: 0.2)
                : Colors.redAccent.withValues(alpha: 0.15),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _order[_selected!] == _q.answer
                        ? tr('quizCorrect')
                        : '${tr('quizIncorrect')}. ${tr('quizCorrectIs')} ${_q.options[_q.answer]}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(_q.explanation),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _next,
            child: Text(_index + 1 >= total
                ? tr('quizResult')
                : tr('quizNext')),
          ),
        ],
      ],
    );
  }
}

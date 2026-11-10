// Cuestionario de laboratorio (v5): las 20 preguntas del tema,
// barajadas. Los errores se guardan igual que en Practicar (se repasan
// después desde "Repasar mis errores" de la pista Universidad).
// Antes vivía dentro de aprender_screen.dart; ahora es una pantalla
// propia que se abre desde Laboratorio y desde la búsqueda.

import 'dart:math';

import 'package:flutter/material.dart';

import '../data/questions.dart';
import '../models.dart';
import '../services/localization.dart';
import '../services/progress.dart';

class LabQuizPage extends StatefulWidget {
  const LabQuizPage({super.key});
  @override
  State<LabQuizPage> createState() => _LabQuizPageState();
}

class _LabQuizPageState extends State<LabQuizPage> {
  late final List<QuizQuestion> _questions;
  int _index = 0;
  int _score = 0;
  int? _selected;
  List<int> _order = [];
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _questions = allQuestions
        .where((q) => q.topic == 'laboratorio')
        .toList()
      ..shuffle(Random());
    _shuffleOptions();
  }

  void _shuffleOptions() {
    _order = [0, 1, 2, 3]..shuffle(Random());
    _selected = null;
  }

  QuizQuestion get _q => _questions[_index];

  void _answer(int displayedIndex) {
    if (_selected != null) return;
    final realIndex = _order[displayedIndex];
    final correct = realIndex == _q.answer;
    final progress = ProgressService.instance;
    progress.recordAnswer(_q.topic, correct);
    final id = 'bank:${_q.topic}:${_q.question}';
    if (correct) {
      progress.removeFailed(id);
      setState(() {
        _selected = displayedIndex;
        _score++;
      });
    } else {
      progress.addFailed(
          FailedEntry(id: id, topic: _q.topic, question: _q.question));
      setState(() => _selected = displayedIndex);
    }
  }

  void _next() {
    if (_index + 1 >= _questions.length) {
      setState(() => _finished = true);
    } else {
      setState(() {
        _index++;
        _shuffleOptions();
      });
    }
  }

  void _repeat() {
    setState(() {
      _questions.shuffle(Random());
      _index = 0;
      _score = 0;
      _finished = false;
      _shuffleOptions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _questions.length;
    return Scaffold(
      appBar: AppBar(title: Text(tr('labQuizButton'))),
      body: _finished
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr('quizResult'),
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text('$_score ${tr('quizOf')} $total ${tr('quizScore')}',
                      style: const TextStyle(fontSize: 20),
                      textAlign: TextAlign.center),
                  Text('${((100 * _score) / total).round()}%',
                      style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.tealAccent),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                      onPressed: _repeat, child: Text(tr('quizRepeat'))),
                  const SizedBox(height: 8),
                  OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(tr('quizBack'))),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${tr('labQuizButton')} · ${tr('quizQuestion')} ${_index + 1} ${tr('quizOf')} $total',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.logout, size: 20),
                      label: Text(tr('quizExit'),
                          style: const TextStyle(fontSize: 16)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: (_index + 1) / total),
                const SizedBox(height: 16),
                Text(_q.question,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                for (var i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selected == null
                            ? Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
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
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
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
            ),
    );
  }
}

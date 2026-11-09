import 'dart:math';
import 'package:flutter/material.dart';
import '../data/questions.dart';
import '../models.dart';
import '../services/progress.dart';

class PracticarScreen extends StatefulWidget {
  const PracticarScreen({super.key});
  @override
  State<PracticarScreen> createState() => _PracticarScreenState();
}

class _PracticarScreenState extends State<PracticarScreen> {
  _QuizState? _quiz;

  void _start(String testId, String title, List<QuizQuestion> questions) {
    setState(() => _quiz = _QuizState(testId: testId, title: title, questions: questions));
  }

  @override
  Widget build(BuildContext context) {
    if (_quiz != null) {
      return _QuizRunner(
        quiz: _quiz!,
        onExit: () => setState(() => _quiz = null),
      );
    }
    final progress = ProgressService.instance;
    final byTopic = <String, List<QuizQuestion>>{};
    for (final q in allQuestions) {
      byTopic.putIfAbsent(q.topic, () => []).add(q);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Practicar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text(
          'Elige un test por tema o el examen mixto con 24 preguntas de todo el temario. Cada respuesta se corrige al momento y se explica.',
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.assignment, size: 32),
            title: const Text('Examen mixto', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('24 preguntas mezcladas de todos los temas, en orden aleatorio.'),
            trailing: Text('Mejor: ${progress.bestScore('mixto')}%'),
            onTap: () {
              final pool = List<QuizQuestion>.of(allQuestions)..shuffle(Random());
              _start('mixto', 'Examen mixto', pool.take(24).toList());
            },
          ),
        ),
        const SizedBox(height: 8),
        const Text('Tests por tema', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final entry in byTopic.entries)
          Card(
            child: ListTile(
              leading: const Icon(Icons.quiz_outlined),
              title: Text(topicNames[entry.key] ?? entry.key,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${entry.value.length} preguntas'),
              trailing: Text('Mejor: ${progress.bestScore(entry.key)}%'),
              onTap: () {
                final pool = List<QuizQuestion>.of(entry.value)..shuffle(Random());
                _start(entry.key, topicNames[entry.key] ?? entry.key, pool);
              },
            ),
          ),
        const SizedBox(height: 12),
        Text(
          'Banco total: ${allQuestions.length} preguntas únicas.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _QuizState {
  _QuizState({required this.testId, required this.title, required List<QuizQuestion> questions})
      : questions = List<QuizQuestion>.of(questions);

  final String testId;
  final String title;
  final List<QuizQuestion> questions;
}

class _QuizRunner extends StatefulWidget {
  const _QuizRunner({required this.quiz, required this.onExit});
  final _QuizState quiz;
  final VoidCallback onExit;

  @override
  State<_QuizRunner> createState() => _QuizRunnerState();
}

class _QuizRunnerState extends State<_QuizRunner> {
  int _index = 0;
  int _score = 0;
  int? _selected; // índice en las opciones barajadas
  List<int> _order = [];
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _shuffleOptions();
  }

  void _shuffleOptions() {
    _order = [0, 1, 2, 3]..shuffle(Random());
    _selected = null;
  }

  QuizQuestion get _q => widget.quiz.questions[_index];

  void _answer(int displayedIndex) {
    if (_selected != null) return;
    final realIndex = _order[displayedIndex];
    setState(() {
      _selected = displayedIndex;
      if (realIndex == _q.answer) _score++;
    });
  }

  void _next() {
    if (_index + 1 >= widget.quiz.questions.length) {
      final percent =
          ((100 * _score) / widget.quiz.questions.length).round();
      ProgressService.instance.recordScore(widget.quiz.testId, percent);
      setState(() => _finished = true);
    } else {
      setState(() {
        _index++;
        _shuffleOptions();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      final total = widget.quiz.questions.length;
      final percent = ((100 * _score) / total).round();
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Resultado', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text('$_score de $total correctas', style: const TextStyle(fontSize: 20), textAlign: TextAlign.center),
            Text('$percent%', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.tealAccent), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              percent >= 80
                  ? 'Excelente, nivel de examen.'
                  : percent >= 60
                      ? 'Bien, repasa los temas fallidos en Aprender.'
                      : 'Sigue practicando: revisa cada explicación y repite el test.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _index = 0;
                  _score = 0;
                  _finished = false;
                  widget.quiz.questions.shuffle(Random());
                  _shuffleOptions();
                });
              },
              child: const Text('Repetir este test'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: widget.onExit, child: const Text('Elegir otro test')),
          ],
        ),
      );
    }

    final total = widget.quiz.questions.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${widget.quiz.title} · Pregunta ${_index + 1} de $total',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(onPressed: widget.onExit, child: const Text('Salir')),
          ],
        ),
        LinearProgressIndicator(value: (_index + 1) / total),
        const SizedBox(height: 16),
        Text(_q.question, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
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
                            : Theme.of(context).colorScheme.surfaceContainerHighest)),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.all(14),
              ),
              onPressed: () => _answer(i),
              child: Text(_q.options[_order[i]], style: const TextStyle(fontSize: 16)),
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
                    _order[_selected!] == _q.answer ? 'Correcto ✓' : 'Incorrecto. Correcta: ${_q.options[_q.answer]}',
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
            child: Text(_index + 1 >= total ? 'Ver resultado' : 'Siguiente pregunta'),
          ),
        ],
      ],
    );
  }
}

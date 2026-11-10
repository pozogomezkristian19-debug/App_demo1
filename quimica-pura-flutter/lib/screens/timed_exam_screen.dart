// Examen con tiempo (v5): simulacro de 24 preguntas en 30 minutos,
// con cuenta atrás. Al acabar el tiempo (o al terminar), se entrega
// solo y muestra el resultado.

import 'dart:math';

import 'package:flutter/material.dart';

import '../data/questions.dart';
import '../models.dart';
import '../services/localization.dart';
import '../services/progress.dart';
import '../widgets/simple_quiz.dart';

class TimedExamScreen extends StatefulWidget {
  const TimedExamScreen({super.key});
  @override
  State<TimedExamScreen> createState() => _TimedExamScreenState();
}

class _TimedExamScreenState extends State<TimedExamScreen> {
  late final List<QuizQuestion> _questions;
  var _started = false;

  @override
  void initState() {
    super.initState();
    _questions = List<QuizQuestion>.of(allQuestions)..shuffle(Random());
    _questions.length = 24;
  }

  void _recordResult(int score, int total) {
    final percent = ((100 * score) / total).round();
    ProgressService.instance.recordScore('timed', percent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('timedTitle'))),
      body: _started
          ? SimpleQuizRunner(
              title: tr('timedTitle'),
              items: _questions,
              durationSeconds: 30 * 60,
              onFinished: (score, total) => _recordResult(score, total),
              onExit: () => Navigator.of(context).pop(),
              onRepeat: () => setState(() {
                _questions.shuffle(Random());
                _started = false;
              }),
            )
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.timer, size: 64, color: Colors.teal),
                  const SizedBox(height: 16),
                  Text(
                    tr('timedTitle'),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Un simulacro como el examen de verdad: 24 preguntas de todos los temas y 30 minutos en el reloj. Cuando se acabe el tiempo, se entrega solo.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mejor resultado: ${ProgressService.instance.bestScore('timed')}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => setState(() => _started = true),
                    child: const Text('Empezar el examen'),
                  ),
                ],
              ),
            ),
    );
  }
}

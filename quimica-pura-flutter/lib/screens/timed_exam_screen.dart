// Examen con tiempo (v6): el usuario elige cuánto dura antes de
// empezar — 5, 10, 15, 20, 25 o 30 minutos — y responde LA MAYOR
// CANTIDAD de preguntas posible en ese tiempo. No hay un número fijo
// de preguntas: la lista es el banco entero (175) más preguntas nuevas
// generadas, para que no se acabe nunca antes que el tiempo. Cuando se
// acaba el tiempo, se entrega solo y el resultado muestra cuántas
// respondió, cuántas correctas y los puntos (sistema de la v6, por
// dificultad: acertar suma, fallar resta más).

import 'dart:math';

import 'package:flutter/material.dart';
import '../widgets/lucide_icons.dart';

import '../data/i18n/content_i18n.dart';
import '../data/questions.dart';
import '../models.dart';
import '../services/localization.dart';
import '../services/progress.dart';
import '../services/question_generator.dart';
import '../widgets/simple_quiz.dart';

/// Duraciones que se pueden elegir, en minutos, de 5 en 5.
const List<int> _durations = [5, 10, 15, 20, 25, 30];

/// Preguntas totales de la lista (banco + generadas): más de las que
/// nadie puede contestar en 30 minutos, para que la lista no se acabe.
const int _poolSize = 275;

/// Banco entero barajado + preguntas nuevas generadas hasta llenar la
/// lista. Devuelve las preguntas y sus ids en paralelo ('bank:...' o
/// 'gen:...'). Función pura para poder probarla (ver test/v6_logic_test.dart).
({List<QuizQuestion> questions, List<String> ids}) buildTimedPool(
    Random rng) {
  // Banco en el idioma activo, pero los ids siempre en español (regla
  // de content_i18n): se barajan los índices, no las preguntas.
  final bank = localizedAllQuestions();
  final order = List<int>.generate(allQuestions.length, (i) => i)
    ..shuffle(rng);
  final questions = [for (final i in order) bank[i]];
  final ids = <String>[
    for (final i in order)
      'bank:${allQuestions[i].topic}:${allQuestions[i].question}',
  ];
  final used = ids.toSet();
  final topics = topicGeneratorTypes.keys.toList();
  var guard = 0;
  while (questions.length < _poolSize && guard < 500) {
    guard++;
    final topic = topics[rng.nextInt(topics.length)];
    final g = generateForTopic(topic, rng);
    if (used.add(g.id)) {
      questions.add(g.question);
      ids.add(g.id);
    }
  }
  return (questions: questions, ids: ids);
}

class TimedExamScreen extends StatefulWidget {
  const TimedExamScreen({super.key});
  @override
  State<TimedExamScreen> createState() => _TimedExamScreenState();
}

class _TimedExamScreenState extends State<TimedExamScreen> {
  var _minutes = 10;
  var _started = false;
  List<QuizQuestion> _questions = const [];
  List<String> _ids = const [];

  /// Banco entero barajado + preguntas nuevas generadas hasta llenar
  /// la lista. Los ids van en paralelo ('bank:...' o 'gen:...').
  void _buildQuestions() {
    final pool = buildTimedPool(Random());
    _questions = pool.questions;
    _ids = pool.ids;
  }

  @override
  void initState() {
    super.initState();
    _buildQuestions();
  }

  void _recordResult(int score, int total) {
    if (total <= 0) return;
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
              itemIds: _ids,
              durationSeconds: _minutes * 60,
              onFinished: (score, total) => _recordResult(score, total),
              onExit: () => Navigator.of(context).pop(),
              onRepeat: () => setState(() {
                _buildQuestions();
                _started = false;
              }),
            )
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const LucideIcon(LucideIcons.timer, size: 64, color: Colors.teal),
                  const SizedBox(height: 16),
                  Text(
                    tr('timedTitle'),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('timedGoal'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tr('timedChooseDuration'),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in _durations)
                        ChoiceChip(
                          label: Text('$m ${tr('minutesShort')}',
                              style: const TextStyle(fontSize: 16)),
                          selected: _minutes == m,
                          onSelected: (_) =>
                              setState(() => _minutes = m),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '${tr('bestWord')}: ${ProgressService.instance.bestScore('timed')}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => setState(() => _started = true),
                    child: Text(tr('timedStart')),
                  ),
                ],
              ),
            ),
    );
  }
}

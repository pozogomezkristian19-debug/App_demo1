// Cuestionario de laboratorio (v5): las 20 preguntas del tema,
// barajadas. Los errores se guardan igual que en Practicar (se repasan
// después desde "Repasar mis errores" de la pista Universidad).
// Antes vivía dentro de aprender_screen.dart; ahora es una pantalla
// propia que se abre desde Laboratorio y desde la búsqueda.
// Puntos (fix4, punto 5): cada respuesta suma o resta puntos según
// la dificultad de la pregunta (+3/−5, +5/−8, +8/−12). No hay vidas
// en juego: salir a mitad no cuesta vida, solo termina el
// cuestionario y los puntos ganados hasta ahí se quedan.

import '../widgets/shadows.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import '../widgets/lucide_icons.dart';

import '../data/i18n/content_i18n.dart';
import '../data/questions.dart';
import '../models.dart';
import '../screens/calculator_screen.dart';
import '../services/localization.dart';
import '../services/numeric_answer.dart';
import '../services/points.dart';
import '../services/progress.dart';
import '../widgets/simple_quiz.dart';

class LabQuizPage extends StatefulWidget {
  const LabQuizPage({super.key});
  @override
  State<LabQuizPage> createState() => _LabQuizPageState();
}

class _LabQuizPageState extends State<LabQuizPage> {
  late List<QuizQuestion> _questions;
  // Índices en el banco original, en el mismo orden que _questions:
  // así los ids de error se construyen siempre en español (v6).
  late List<int> _idx;
  int _index = 0;
  int _score = 0;
  // Puntos del cuestionario (fix4, punto 5): se suman o restan al
  // contestar, según la dificultad de cada pregunta.
  int _points = 0;
  int? _selected;
  List<int> _order = [];
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final bank = localizedAllQuestions();
    _idx = <int>[];
    for (var i = 0; i < allQuestions.length; i++) {
      if (allQuestions[i].topic == 'laboratorio') _idx.add(i);
    }
    _idx.shuffle(Random());
    _questions = [for (final i in _idx) bank[i]];
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
    // Puntos (fix4, punto 5): fáciles +3/−5, medios +5/−8,
    // difíciles +8/−12, según la dificultad de la pregunta.
    final delta = correct
        ? pointsForCorrect(_q.difficulty)
        : pointsForWrong(_q.difficulty);
    progress.addPoints(delta);
    // Id y texto del error, siempre en español (regla de content_i18n).
    final es = allQuestions[_idx[_index]];
    final id = 'bank:${es.topic}:${es.question}';
    if (correct) {
      progress.removeFailed(id);
      setState(() {
        _selected = displayedIndex;
        _score++;
        _points += delta;
      });
    } else {
      progress.addFailed(
          FailedEntry(id: id, topic: es.topic, question: es.question));
      setState(() {
        _selected = displayedIndex;
        _points += delta;
      });
    }
  }

  /// Respuesta de una pregunta de cálculo (fix3, punto 7): el valor
  /// tecleado en el teclado numérico se traduce al índice de opción
  /// que le corresponde y pasa por el mismo `_answer` de siempre.
  /// Hoy el cuestionario es solo del banco (ninguna pregunta es de
  /// cálculo), pero si una generada llegara aquí, ya funcionaría.
  void _answerNumeric(double value) {
    if (_selected != null) return;
    _answer(displayedIndexForNumericAnswer(
        typed: value, question: _q, order: _order));
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

  /// Salir en medio del cuestionario (fix2, ronda 2; aviso sin vidas
  /// en la fix4, punto 5): las vidas son solo de los niveles, así que
  /// salir aquí no cuesta nada: termina el cuestionario y los puntos
  /// ganados hasta ahí se quedan. Se pide confirmación antes de salir.
  void _requestExit() {
    if (_finished) {
      Navigator.of(context).pop();
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
              Navigator.of(context).pop();
            },
            child: Text(tr('exitNoLivesLeave')),
          ),
        ],
      ),
    );
  }

  void _repeat() {
    setState(() {
      _idx.shuffle(Random());
      final bank = localizedAllQuestions();
      _questions = [for (final i in _idx) bank[i]];
      _index = 0;
      _score = 0;
      _points = 0;
      _finished = false;
      _shuffleOptions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _questions.length;
    // Bloqueo de sesión (fix2, ronda 2): mientras el cuestionario
    // está en curso, ni el botón atrás ni la flecha de la barra
    // pueden cerrarlo directamente: muestran el aviso de Salir sin
    // pérdida de vida (las vidas son solo de los niveles, fix4,
    // punto 5). Terminado, se sale libre.
    return PopScope(
      canPop: _finished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_finished) _requestExit();
      },
      child: Scaffold(
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
                  const SizedBox(height: 4),
                  Text(
                      '${tr('pointsWord')}: ${_points > 0 ? '+$_points' : '$_points'}',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
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
                      onPressed: _requestExit,
                      // Icono 3D (fix3, punto 6): degradado del
                      // color del botón, glifo sin cambiar.
                      icon: const LucideIcon(LucideIcons.logOut,
                          size: 20, threeD: true),
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
                const SizedBox(height: 8),
                Text(
                    '${tr('pointsWord')}: ${_points > 0 ? '+$_points' : '$_points'}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                // Botoncito de teclado (fix5, punto B, corrección
                // 00:26): sale en (casi) todas las preguntas, a un
                // ladito del texto; al tocarlo se abre la PANTALLA
                // de la calculadora (página completa, no un panel
                // inline) y al cerrarla se vuelve a la pregunta
                // intacta. Científica en las de cálculo (al volver
                // se responde con el valor), normal en las demás
                // (solo para calcular a mano).
                QuestionCalculatorButton(
                  question: Text(_q.question,
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w600)),
                  scientific: _q.isNumeric,
                  unit: _q.numericUnit,
                  onResult: _q.isNumeric ? _answerNumeric : null,
                ),
                const SizedBox(height: 16),
                // En las preguntas de cálculo las opciones dejan paso
                // al teclado (que ahora se abre con el icono); las
                // conceptuales siguen con las opciones de siempre.
                // Opciones 3D (ronda de diseño 7.0): tarjeta blanca
                // con sombra en reposo, degradado teal/rojo con
                // borde inferior oscuro al acertar/fallar (ver
                // QuizOptionButton en simple_quiz.dart).
                if (!_q.isNumeric)
                  for (var i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: QuizOptionButton(
                      text: _q.options[_order[i]],
                      state: _selected == null
                          ? QuizOptionState.normal
                          : (_order[i] == _q.answer
                              ? QuizOptionState.correct
                              : (_selected == i
                                  ? QuizOptionState.wrong
                                  : QuizOptionState.normal)),
                      // Texto legible (capturas 2026-11-10): sobre
                      // fondo claro va tinta oscura; sobre teal o
                      // rojo, blanco. Sin esto heredaba blanco.
                      textColor: _selected != null &&
                              (_order[i] == _q.answer || _selected == i)
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                      onPressed: () => _answer(i),
                    ),
                  ),
                if (_selected != null) ...[
                  const SizedBox(height: 8),
                  // Tarjeta de explicación 3D (ronda de diseño 7.0):
                  // antes era una Card plana de color liso.
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: _order[_selected!] == _q.answer
                            ? [
                                Colors.teal.withValues(alpha: 0.18),
                                Colors.teal.withValues(alpha: 0.08),
                              ]
                            : [
                                Colors.redAccent.withValues(alpha: 0.18),
                                Colors.redAccent.withValues(alpha: 0.08),
                              ],
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: (_order[_selected!] == _q.answer
                                  ? Colors.teal
                                  : Colors.redAccent)
                              .withValues(alpha: 0.45),
                          width: 3,
                        ),
                      ),
                      boxShadow: [
                        standardShadow((_order[_selected!] == _q.answer ? Colors.teal : Colors.redAccent)),
                      ],
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
      ),
    );
  }
}

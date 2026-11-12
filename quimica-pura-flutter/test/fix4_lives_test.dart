// Pruebas de la ronda #4, punto 5: VIDAS SOLO EN NIVELES.
// Las vidas se pierden SOLO en los niveles (salir a mitad de un nivel
// −1 vida; pasar el nivel +1 hasta 5; 0 vidas bloquea niveles nuevos).
// El examen con tiempo, el quiz de la tabla, el cuestionario del
// laboratorio, el repaso y el examen mixto NO quitan vidas nunca:
// usan SOLO puntos (fácil +3/−5, medio +5/−8, difícil +8/−12).
// El abandono de examen con tiempo / lab / tabla sin pérdida de vida
// ya se cubre en fix2_test.dart (checkBackWarningNoLives); aquí se
// prueban los puntos por dificultad y que 0 vidas no bloquea las
// actividades sin vidas.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/models.dart';
import 'package:quimica_pura/screens/table_quiz_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/points.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/simple_quiz.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({'melli_rules_seen_v6': true});
    await UserPrefs.load();
    await ProgressService.load();
    // Sin mock, el AudioPlayer estático de SoundService activa el
    // stream global de audioplayers y lanza MissingPluginException
    // (error asíncrono que el test reporta como fallo).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global/events'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => null,
    );
  });

  // Tres preguntas con dificultad y respuesta conocidas (la correcta
  // es el primer elemento de cada lista de opciones es la 'A', la
  // segunda la 'B' y la tercera la 'C': el orden en pantalla se
  // baraja, pero el TEXTO de la opción no cambia).
  const qEasy = QuizQuestion(
    topic: 'tabla',
    question: 'Pregunta fácil de prueba',
    options: ['A fácil', 'B fácil', 'C fácil', 'D fácil'],
    answer: 0,
    explanation: 'Por qué la A.',
    difficulty: 1,
  );
  const qMedium = QuizQuestion(
    topic: 'tabla',
    question: 'Pregunta media de prueba',
    options: ['A media', 'B media', 'C media', 'D media'],
    answer: 1,
    explanation: 'Por qué la B.',
    difficulty: 2,
  );
  const qHard = QuizQuestion(
    topic: 'tabla',
    question: 'Pregunta difícil de prueba',
    options: ['A difícil', 'B difícil', 'C difícil', 'D difícil'],
    answer: 2,
    explanation: 'Por qué la C.',
    difficulty: 3,
  );

  Future<void> pumpRunner(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: SimpleQuizRunner(
            title: 'Prueba',
            items: const [qEasy, qMedium, qHard],
            onFinished: (_, __) {},
            onExit: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> answer(WidgetTester tester, String optionText) async {
    await tester.tap(find.text(optionText));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Flujo original: tocar la opción la juzga al momento (sin
    // COMPROBAR); los puntos ya están registrados al salir de aquí.
  }

  Future<void> next(WidgetTester tester) async {
    // El cuestionario es un ListView: el botón de abajo puede
    // quedar fuera del viewport (botones 3D más altos que los
    // planos viejos) y hay que hacer scroll hasta él, como haría
    // el usuario en el teléfono.
    final nextFinder = find.text(tr('quizNext').toUpperCase());
    final nextBtn = nextFinder.evaluate().isNotEmpty
        ? nextFinder
        : find.text(tr('quizResult').toUpperCase());
    await tester.ensureVisible(nextBtn);
    await tester.pumpAndSettle();
    await tester.tap(nextBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('Tarifa de puntos por dificultad', () {
    test('fácil +3/−5, medio +5/−8, difícil +8/−12', () {
      expect(pointsForCorrect(1), 3);
      expect(pointsForWrong(1), -5);
      expect(pointsForCorrect(2), 5);
      expect(pointsForWrong(2), -8);
      expect(pointsForCorrect(3), 8);
      expect(pointsForWrong(3), -12);
    });
  });

  group('SimpleQuizRunner: puntos, no vidas', () {
    testWidgets('acierto fácil +3, fallo medio −8, acierto difícil +8; '
        'las vidas no se tocan', (tester) async {
      await pumpRunner(tester);
      final p = ProgressService.instance;
      expect(p.points, 0);
      expect(p.livesLeft, 5);

      await answer(tester, 'A fácil');
      expect(p.points, 3);
      expect(p.livesLeft, 5);
      await next(tester);

      await answer(tester, 'A media');
      expect(p.points, -5);
      expect(p.livesLeft, 5);
      await next(tester);

      await answer(tester, 'C difícil');
      expect(p.points, 3);
      expect(p.livesLeft, 5);

      // La última pregunta se cierra con el botón "RESULTADO"
      // (flujo original): al salir del bloque ya está el resultado.
      await next(tester);
      // El resultado muestra los puntos ganados en la partida.
      expect(find.text('Puntos: +3'), findsOneWidget);
      expect(p.livesLeft, 5);
      expect(tester.takeException(), isNull);
    });
  });

  group('0 vidas no bloquea las actividades sin vidas', () {
    testWidgets('con 0 vidas el quiz de la tabla se abre igual '
        '(los niveles sí están bloqueados)', (tester) async {
      final p = ProgressService.instance;
      for (var i = 0; i < 5; i++) p.loseLifeOnAbandon();
      expect(p.livesLeft, 0);
      expect(p.canStartLevel, isFalse);

      await tester.pumpWidget(
        const MaterialApp(home: TableQuizScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // El quiz está en marcha (título y pregunta visibles): nada
      // de aviso de "sin vidas" ni bloqueo.
      expect(find.text('Quiz de la tabla periódica'), findsOneWidget);
      expect(find.text('Símbolo → nombre'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

// Ronda #5, punto B (2026-11-11), corrección 00:26: calculadora en
// PANTALLA COMPLETA con Navigator.push, no panel inline.
//
// - Seguimiento 7.2: UN SOLO acceso al teclado — el campo de
//   respuesta de las preguntas de cálculo. El botoncito junto a la
//   pregunta se quitó (salía doble) y en opción múltiple NO va
//   ningún teclado.
// - La calculadora NO se abre sola y NO es un panel dentro de la
//   pregunta: en las de cálculo se abre desde el campo; al tocarlo
//   se abre la pantalla de la calculadora (página completa) y SE
//   CIERRA para responder: nunca tapa las opciones ni bloquea la
//   respuesta.
// - Numérica: "Usar resultado" en la pantalla hace pop con el valor y al
//   volver se responde con él. Opciones: sin teclado.
// - La ida y vuelta NO resetea el estado del quiz (índice, selección,
//   marcador, progreso).
// - Pregunta de cálculo -> CIENTÍFICA (log, ln, potencias, raíces,
//   notación científica); las demás no llevan calculadora.
// - Un solo componente (NumericKeypad) con el flag `scientific`.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/data/questions.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/models.dart';
import 'package:quimica_pura/screens/calculator_screen.dart';
import 'package:quimica_pura/screens/lab_quiz_screen.dart';
import 'package:quimica_pura/screens/table_quiz_screen.dart';
import 'package:quimica_pura/services/calculator.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/nav_requests.dart';
import 'package:quimica_pura/services/notification_inbox.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/question_generator.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/numeric_keypad.dart';
import 'package:quimica_pura/widgets/simple_quiz.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRobotoFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    await NotificationInbox.load();
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (call) async => null,
    );
    UserPrefs.rulesSeenV6 = true;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    await UserPrefs.saveThemeMode('claro');
    UserPrefs.isDark = false;
    UserPrefs.onboardingDone = true;
  });

  tearDown(() {
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = false;
    UserPrefs.isDark = false;
    NavRequests.startReview = false;
    NotificationInbox.resetForTests();
  });

  /// Pantalla alta (800×1600): la calculadora es alta y en la
  /// ventana de pruebas por defecto (800×600) las teclas de abajo
  /// quedarían fuera y los toques fallarían.
  void tallViewport(WidgetTester tester,
      [Size size = const Size(800, 1600)]) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  /// Toca una tecla por su texto: por el botón que la contiene, no
  /// por el texto suelto (la expresión '2' y la tecla '2' dirían lo
  /// mismo y el buscador sería ambiguo).
  Future<void> tapKey(WidgetTester tester, String label) async {
    final filled = find.widgetWithText(FilledButton, label);
    if (filled.evaluate().isNotEmpty) {
      await tester.tap(filled);
    } else {
      await tester.tap(find.widgetWithText(OutlinedButton, label));
    }
    await tester.pump();
  }

  Future<void> tapKeys(WidgetTester tester, List<String> labels) async {
    for (final label in labels) {
      await tapKey(tester, label);
    }
  }

  /// Lo que muestra el visor (no las teclas: la tecla '0' y el
  /// display '0' tienen el mismo texto).
  String displayText(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const Key('numeric-keypad-display')))
      .data!;

  String resultText(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const Key('calculator-result')))
      .data!;

  /// Cierra la pantalla de la calculadora con la X y espera a que
  /// termine la animación de vuelta.
  Future<void> closeCalculator(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('calculator-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// La pregunta de Kristian: rendimiento teórico 20 g, obtienes 15 g.
  const yieldQuestion = QuizQuestion(
    topic: 'estequiometria',
    question: 'El rendimiento teórico es 20 g y obtienes 15 g. '
        '¿Cuál es el rendimiento porcentual?',
    options: ['60 %', '75 %', '80 %', '133 %'],
    answer: 1,
    explanation: 'Rendimiento = 15 / 20 × 100 = 75 %.',
  );

  final conceptualQuestion = allQuestions.firstWhere(
      (x) => x.question.startsWith('¿Qué es el reactivo limitante?'));

  group('A19 (auditoría): −2² = −4, el menos no se liga a la base',
      () {
    test('el menos unario NO se liga antes de la potencia', () {
      // La convención matemática (y la de las calculadoras
      // científicas): −(2²) = −4, no (−2)² = 4.
      expect(evaluateExpression('−2^2'), closeTo(-4.0, 1e-9));
      expect(evaluateExpression('-2^2'), closeTo(-4.0, 1e-9));
      expect(evaluateExpression('−3^2'), closeTo(-9.0, 1e-9));
      // Con paréntesis sí es (−2)² = 4: el paréntesis manda.
      expect(evaluateExpression('(−2)^2'), closeTo(4.0, 1e-9));
      expect(evaluateExpression('(-2)^2'), closeTo(4.0, 1e-9));
      // Y 2² sigue siendo 4.
      expect(evaluateExpression('2^2'), closeTo(4.0, 1e-9));
    });

    test('siguen bien: precedencia, derecha, exponente negativo y funciones',
        () {
      expect(evaluateExpression('2+3×4'), closeTo(14.0, 1e-9));
      expect(evaluateExpression('2^3^2'), closeTo(512.0, 1e-9));
      expect(evaluateExpression('10^−3'), closeTo(0.001, 1e-12));
      expect(evaluateExpression('10^-3'), closeTo(0.001, 1e-12));
      expect(evaluateExpression('log(100)'), closeTo(2.0, 1e-9));
      expect(evaluateExpression('ln(e)'), closeTo(1.0, 1e-9));
      expect(evaluateExpression('√(16)'), closeTo(4.0, 1e-9));
      expect(evaluateExpression('1.5e-3'), closeTo(0.0015, 1e-12));
      // Regresiones del menos unario en otros sitios.
      expect(evaluateExpression('−5+3'), closeTo(-2.0, 1e-9));
      expect(evaluateExpression('2×−3'), closeTo(-6.0, 1e-9));
      expect(evaluateExpression('−log(0.01)'), closeTo(2.0, 1e-9));
      expect(evaluateExpression('2^-2'), closeTo(0.25, 1e-9));
      expect(evaluateExpression('2^2^2'), closeTo(16.0, 1e-9));
    });
  });

  group('NumericKeypad: modo científico y modo normal', () {
    Future<void> pumpKeypad(
      WidgetTester tester, {
      bool scientific = true,
      ValueChanged<double>? onSubmit,
    }) async {
      tallViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: NumericKeypad(
              unit: 'mol',
              enabled: true,
              scientific: scientific,
              onSubmit: onSubmit,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('científica (por defecto): todas las teclas y Usar resultado',
        (tester) async {
      await pumpKeypad(tester, onSubmit: (_) {});
      for (final sci in ['log', 'ln', '√', 'x²', '10^x', 'e^x', '×10^x', 'π']) {
        expect(find.widgetWithText(FilledButton, sci), findsOneWidget,
            reason: sci);
      }
      expect(find.widgetWithText(FilledButton, '^'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '('), findsOneWidget);
      expect(find.widgetWithText(FilledButton, ')'), findsOneWidget);
      expect(find.text(tr('calcUseResult')), findsOneWidget);
    });

    testWidgets('normal: sin teclas científicas, con paréntesis, sin Usar resultado',
        (tester) async {
      // onSubmit null = para calcular a mano: sin Usar resultado.
      await pumpKeypad(tester, scientific: false);
      for (final sci in ['log', 'ln', '√', 'x²', '10^x', 'e^x', '×10^x', 'π', '^']) {
        expect(find.text(sci), findsNothing, reason: sci);
      }
      for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0']) {
        expect(find.widgetWithText(FilledButton, d), findsOneWidget,
            reason: d);
      }
      for (final op in ['+', '−', '×', '÷']) {
        expect(find.widgetWithText(FilledButton, op), findsOneWidget,
            reason: op);
      }
      expect(find.widgetWithText(FilledButton, '('), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, ')'), findsOneWidget);
      expect(find.text('.'), findsOneWidget);
      expect(find.text('='), findsOneWidget);
      expect(find.text(tr('calcUseResult')), findsNothing);
    });

    testWidgets('normal: 15 ÷ 2 = 7.5 en el visor, sin entregar nada',
        (tester) async {
      await pumpKeypad(tester, scientific: false);
      await tapKeys(tester, ['1', '5', '÷', '2']);
      expect(resultText(tester), '= 7.5');
      await tapKey(tester, '=');
      expect(displayText(tester), '7.5');
      // Sin Usar resultado no hay nada que entregar: el resultado se queda
      // en el visor para leerlo a mano.
      expect(find.text(tr('calcUseResult')), findsNothing);
    });

    testWidgets('normal: paréntesis (2+3)×4 = 20', (tester) async {
      await pumpKeypad(tester, scientific: false);
      await tapKeys(tester, ['(', '2', '+', '3', ')', '×', '4', '=']);
      expect(displayText(tester), '20');
    });

    testWidgets('científica: log(100) = 2', (tester) async {
      await pumpKeypad(tester, onSubmit: (_) {});
      await tapKeys(tester, ['log', '1', '0', '0', ')', '=']);
      expect(displayText(tester), '2');
    });
  });

  group('CalculatorScreen: pantalla completa con push/pop', () {
    /// Abre la pantalla desde un botón y espera a que aparezca.
    Future<void> openScreen(
      WidgetTester tester, {
      required bool scientific,
      String? unit,
    }) async {
      tallViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  CalculatorScreen.open(
                    context,
                    scientific: scientific,
                    unit: unit,
                  );
                },
                child: const Text('Abrir calculadora'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Abrir calculadora'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('científica: título, X y teclado con log y Usar resultado',
        (tester) async {
      await openScreen(tester, scientific: true, unit: 'mol');
      expect(find.byType(CalculatorScreen), findsOneWidget);
      expect(find.text(tr('calculate')), findsOneWidget);
      expect(find.byKey(const Key('calculator-close')), findsOneWidget);
      expect(find.byType(NumericKeypad), findsOneWidget);
      expect(find.text('log'), findsOneWidget);
      expect(find.text(tr('calcUseResult')), findsOneWidget);
      expect(find.text('mol'), findsOneWidget);
    });

    testWidgets('normal: sin log ni Usar resultado', (tester) async {
      await openScreen(tester, scientific: false);
      expect(find.byType(CalculatorScreen), findsOneWidget);
      expect(find.text('log'), findsNothing);
      expect(find.text(tr('calcUseResult')), findsNothing);
      expect(find.widgetWithText(FilledButton, '7'), findsOneWidget);
    });

    testWidgets('numérica: Usar resultado hace pop con el valor',
        (tester) async {
      double? received;
      tallViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  received = await CalculatorScreen.open(
                    context,
                    scientific: true,
                    unit: 'mol',
                  );
                },
                child: const Text('Abrir calculadora'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Abrir calculadora'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tapKeys(tester, ['2', '=']);
      expect(displayText(tester), '2');
      await tapKey(tester, tr('calcUseResult'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(received, 2.0);
      expect(find.byType(CalculatorScreen), findsNothing);
    });

    testWidgets('la X cierra sin devolver nada', (tester) async {
      double? received = -1;
      tallViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  received = await CalculatorScreen.open(
                    context,
                    scientific: false,
                  );
                },
                child: const Text('Abrir calculadora'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Abrir calculadora'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CalculatorScreen), findsOneWidget);
      await tapKeys(tester, ['3', '+', '4', '=']);
      expect(displayText(tester), '7');
      await closeCalculator(tester);
      expect(received, isNull);
      expect(find.byType(CalculatorScreen), findsNothing);
      expect(find.text('Abrir calculadora'), findsOneWidget);
    });
  });

  group('QuestionCalculatorButton: icono que hace push, no panel inline',
      () {
    Future<void> pumpButton(
      WidgetTester tester, {
      required bool scientific,
      ValueChanged<double>? onResult,
    }) async {
      tallViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                QuestionCalculatorButton(
                  question: const Text('¿Pregunta de ejemplo?',
                      style: TextStyle(fontSize: 19)),
                  scientific: scientific,
                  unit: scientific ? 'mol' : null,
                  onResult: onResult,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('sin calculadora por defecto: ni inline ni pantalla',
        (tester) async {
      await pumpButton(tester, scientific: true, onResult: (_) {});
      expect(find.byKey(const Key('calculator-toggle')), findsOneWidget);
      expect(find.byType(NumericKeypad), findsNothing);
      expect(find.byType(CalculatorScreen), findsNothing);
    });

    testWidgets('tocar el icono hace PUSH a la pantalla (no panel inline)',
        (tester) async {
      await pumpButton(tester, scientific: false);
      await tester.tap(find.byKey(const Key('calculator-toggle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CalculatorScreen), findsOneWidget);
      // El teclado solo existe DENTRO de la pantalla, no en la
      // pregunta: la pregunta sigue detrás, intacta (offstage
      // mientras la pantalla la tapa: hace falta skipOffstage
      // para verla).
      expect(find.byType(NumericKeypad), findsOneWidget);
      expect(find.text('¿Pregunta de ejemplo?', skipOffstage: false),
          findsOneWidget);
      // Cerrar con la X vuelve a la pregunta, sin calculadora.
      await closeCalculator(tester);
      expect(find.byType(CalculatorScreen), findsNothing);
      expect(find.byType(NumericKeypad), findsNothing);
      expect(find.text('¿Pregunta de ejemplo?'), findsOneWidget);
    });

    testWidgets('numérica: al volver con el valor se llama a onResult',
        (tester) async {
      double? received;
      await pumpButton(tester,
          scientific: true, onResult: (v) => received = v);
      await tester.tap(find.byKey(const Key('calculator-toggle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('log'), findsOneWidget);
      await tapKeys(tester, ['2', '=']);
      await tapKey(tester, tr('calcUseResult'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(received, 2.0);
      expect(find.byType(CalculatorScreen), findsNothing);
    });
  });

  group('SimpleQuizRunner (examen con tiempo)', () {
    Future<void> pumpRunner(
      WidgetTester tester,
      List<QuizQuestion> items, {
      int? durationSeconds,
      String? playerName,
    }) async {
      tallViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: SimpleQuizRunner(
              title: 'Prueba',
              items: items,
              durationSeconds: durationSeconds,
              playerName: playerName,
              onFinished: (_, __) {},
              onExit: () {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets(
        'opción múltiple con %: sin teclado, la opción se puede tocar',
        (tester) async {
      await pumpRunner(tester, [yieldQuestion]);
      expect(find.text('75 %'), findsOneWidget);
      // Seguimiento 7.2: en opción múltiple no va ningún icono de
      // teclado ni se abre calculadora alguna.
      expect(find.byKey(const Key('calculator-toggle')), findsNothing);
      expect(find.byType(NumericKeypad), findsNothing);
      expect(find.byType(CalculatorScreen), findsNothing);
      await tester.tap(find.text('75 %'));
      await tester.pump();
      expect(find.text(tr('quizCorrect')), findsOneWidget);
    });

    testWidgets('conceptual: sin teclado', (tester) async {
      await pumpRunner(tester, [conceptualQuestion]);
      // Seguimiento 7.2: en opción múltiple no va ningún icono de
      // teclado.
      expect(find.byKey(const Key('calculator-toggle')), findsNothing);
      expect(find.byType(NumericKeypad), findsNothing);
      expect(find.byType(CalculatorScreen), findsNothing);
      await tester.tap(find.text('El que se agota primero'));
      await tester.pump();
      expect(find.text(tr('quizCorrect')), findsOneWidget);
    });

    testWidgets('pregunta de cálculo: pantalla científica y al volver '
        'se responde con el valor', (tester) async {
      final g = buildMassMoles('moles', 'H2O', 36); // 36 g / 18,02 ≈ 2 mol
      await pumpRunner(tester, [g.question]);
      expect(find.byType(NumericKeypad), findsNothing);
      // Seguimiento 7.2: la calculadora se abre desde el campo de
      // respuesta (el botoncito junto a la pregunta se quitó).
      await tester.tap(find.byKey(const Key('numeric-answer-field')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CalculatorScreen), findsOneWidget);
      expect(find.text('log'), findsOneWidget);
      expect(find.text(tr('calcUseResult')), findsOneWidget);
      await tapKeys(tester, ['2', '=']);
      expect(displayText(tester), '2');
      await tapKey(tester, tr('calcUseResult'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CalculatorScreen), findsNothing);
      expect(find.text(tr('quizCorrect')), findsOneWidget);
    });

    testWidgets('examen con tiempo: sin teclado en opción múltiple',
        (tester) async {
      await pumpRunner(tester, [yieldQuestion], durationSeconds: 300);
      expect(find.byKey(const Key('calculator-toggle')), findsNothing);
      expect(find.byType(NumericKeypad), findsNothing);
    });

    testWidgets('la ida y vuelta NO resetea el quiz: índice, selección '
        'y marcador siguen', (tester) async {
      // Seguimiento 7.2: la ida y vuelta a la calculadora solo existe
      // en pregunta de cálculo (desde el campo); en opción múltiple
      // no hay teclado.
      final g = buildMassMoles('moles', 'H2O', 36); // 36 g / 18,02 ≈ 2 mol
      await pumpRunner(tester, [g.question, conceptualQuestion]);
      // Abrir y cerrar la calculadora en la pregunta 1 sin entregar:
      // sigue la 1, sin contestar.
      await tester.tap(find.byKey(const Key('numeric-answer-field')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CalculatorScreen), findsOneWidget);
      await closeCalculator(tester);
      expect(find.text(g.question.question), findsOneWidget);
      expect(find.text(tr('quizCorrect')), findsNothing);
      // Responder la 1 con la calculadora: el marcador sube.
      await tester.tap(find.byKey(const Key('numeric-answer-field')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tapKeys(tester, ['2', '=']);
      expect(displayText(tester), '2');
      await tapKey(tester, tr('calcUseResult'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CalculatorScreen), findsNothing);
      expect(find.text(tr('quizCorrect')), findsOneWidget);
      // Pasar a la 2: sigue siendo la 2 (el índice no se reseteó) y
      // ahí no hay teclado (opción múltiple).
      await tester.tap(find.text(tr('quizNext').toUpperCase()));
      await tester.pump();
      expect(find.text(conceptualQuestion.question), findsOneWidget);
      expect(find.byKey(const Key('calculator-toggle')), findsNothing);
      // Acertar la 2: 2 de 2 (el marcador de la 1 sigue).
      await tester.tap(find.text('El que se agota primero'));
      await tester.pump();
      expect(find.text(tr('quizCorrect')), findsOneWidget);
      await tester.tap(find.text(tr('quizResult').toUpperCase()));
      await tester.pump();
      expect(find.text('2 ${tr('quizOf')} 2 ${tr('quizScore')}'),
          findsOneWidget);
    });
  });

  group('Cuestionario de laboratorio', () {
    testWidgets('sin teclado: solo opciones', (tester) async {
      tallViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const LabQuizPage(),
        ),
      );
      await tester.pump();
      // Seguimiento 7.2: el cuestionario de laboratorio es de opción
      // múltiple y no lleva calculadora.
      expect(find.byKey(const Key('calculator-toggle')), findsNothing);
      expect(find.byType(NumericKeypad), findsNothing);
      expect(find.byType(CalculatorScreen), findsNothing);
      expect(find.byType(QuizOptionButton), findsNWidgets(4));
    });
  });

  group('Quiz de la tabla', () {
    testWidgets('sin teclado: solo opciones', (tester) async {
      tallViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const TableQuizScreen(),
        ),
      );
      await tester.pump();
      // Seguimiento 7.2: el quiz de la tabla es siempre opción
      // múltiple y no lleva calculadora.
      expect(find.byKey(const Key('calculator-toggle')), findsNothing);
      expect(find.byType(NumericKeypad), findsNothing);
      expect(find.byType(CalculatorScreen), findsNothing);
      expect(find.byType(QuizOptionButton), findsNWidgets(4));
    });
  });

  group('Niveles y repaso (_QuizRunner) y pregunta del día', () {
    Future<void> pumpNiveles(
      WidgetTester tester, {
      double width = 393,
      double height = 852,
    }) async {
      tester.view.physicalSize = Size(width * 2, height * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(const MelliQuiApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
    }

    /// El nodo 1 del primer tema: el Container de 80×80 que
    /// envuelve su número (patrón de fix4_niveles_compact_test;
    /// 80 dp desde el rediseño Duolingo §3.2, antes 64).
    Rect nodeOneRect(WidgetTester tester) {
      Rect rectOf(Element e) {
        final box = e.renderObject! as RenderBox;
        return box.localToGlobal(Offset.zero) & box.size;
      }

      return tester
          .elementList(find.ancestor(
            of: find.text('1'),
            matching: find.byType(Container),
          ))
          .map(rectOf)
          .firstWhere((r) => r.width == 80.0 && r.height == 80.0);
    }

    testWidgets('nivel: sin teclado en la primera pregunta (conceptual)',
        (tester) async {
      await pumpNiveles(tester);
      await tester.tapAt(nodeOneRect(tester).center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // La primera pregunta del nivel 1 es de banco (conceptual):
      // sin teclado (seguimiento 7.2).
      expect(find.byKey(const Key('calculator-toggle')), findsNothing);
      expect(find.byType(NumericKeypad), findsNothing);
      expect(find.byType(CalculatorScreen), findsNothing);
      expect(find.textContaining('Pregunta 1 de 5'), findsOneWidget);
    });

    testWidgets('repaso de errores: sin teclado en pregunta conceptual',
        (tester) async {
      // Un error de laboratorio: tema sin generador, así el repaso
      // usa solo preguntas del banco (conceptuales, modo normal).
      final lab = allQuestions
          .firstWhere((q) => q.topic == 'laboratorio');
      ProgressService.instance.addFailed(FailedEntry(
        id: 'bank:laboratorio:${lab.question}',
        topic: 'laboratorio',
        question: lab.question,
      ));
      NavRequests.startReview = true;
      await pumpNiveles(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('calculator-toggle')), findsNothing);
      expect(find.byType(NumericKeypad), findsNothing);
      expect(find.byType(CalculatorScreen), findsNothing);
    });

  });
}

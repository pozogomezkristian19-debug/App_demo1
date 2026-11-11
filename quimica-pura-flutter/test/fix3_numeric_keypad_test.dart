// Pruebas de la ronda fix3 2026-11-10 (punto 7: teclado numérico
// dentro de la app para las preguntas de cálculo).
//
// - La tolerancia de validación (±2 % relativo, con suelo absoluto
//   de ±0,005 por el redondeo a 2 decimales del generador).
// - Qué preguntas abren el teclado (las 9 generadas de cálculo) y
//   cuáles siguen con opciones (conceptuales generadas y banco).
// - El widget NumericKeypad: teclas, borrar, limpiar, Comprobar.
// - El runner compartido (SimpleQuizRunner: examen con tiempo y reto)
//   muestra el teclado con una pregunta de cálculo y las opciones
//   con una conceptual.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/data/questions.dart';
import 'package:quimica_pura/models.dart';
import 'package:quimica_pura/services/calculator.dart';
import 'package:quimica_pura/services/numeric_answer.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/question_generator.dart';
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
  });

  /// Pantalla de teléfono alta (800×1600): la calculadora es alta y
  /// en la ventana de pruebas por defecto (800×600) las teclas de
  /// abajo quedarían fuera de la pantalla y los toques fallarían.
  void tallViewport(WidgetTester tester,
      [Size size = const Size(800, 1600)]) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Validación con tolerancia', () {
    test('el valor exacto pasa', () {
      expect(isNumericAnswerCorrect(2.0, 2.0), isTrue);
      expect(isNumericAnswerCorrect(18.02, 18.02), isTrue);
    });

    test('dentro del 2 % pasa (incluido el límite)', () {
      expect(isNumericAnswerCorrect(102.0, 100.0), isTrue);
      expect(isNumericAnswerCorrect(98.0, 100.0), isTrue);
      expect(isNumericAnswerCorrect(2.55, 2.5), isTrue);
      expect(isNumericAnswerCorrect(0.51, 0.5), isTrue);
    });

    test('fuera del 2 % falla', () {
      expect(isNumericAnswerCorrect(102.1, 100.0), isFalse);
      expect(isNumericAnswerCorrect(97.9, 100.0), isFalse);
      expect(isNumericAnswerCorrect(2.56, 2.5), isFalse);
      expect(isNumericAnswerCorrect(2.6, 2.5), isFalse);
      expect(isNumericAnswerCorrect(0.0, 2.0), isFalse);
    });

    test('decimales: 2,45 frente a 2,5 está dentro; 2,44 no', () {
      expect(isNumericAnswerCorrect(2.45, 2.5), isTrue);
      expect(isNumericAnswerCorrect(2.44, 2.5), isFalse);
    });

    test('negativos: se tolera el 2 % del valor absoluto', () {
      expect(isNumericAnswerCorrect(-5.05, -5.0), isTrue);
      expect(isNumericAnswerCorrect(-4.95, -5.0), isTrue);
      expect(isNumericAnswerCorrect(-5.2, -5.0), isFalse);
      expect(isNumericAnswerCorrect(5.0, -5.0), isFalse);
    });

    test('valor correcto cero: solo pasa casi cero', () {
      expect(isNumericAnswerCorrect(0.0, 0.0), isTrue);
      expect(isNumericAnswerCorrect(0.004, 0.0), isTrue);
      expect(isNumericAnswerCorrect(0.006, 0.0), isFalse);
    });

    test('suelo absoluto: teclear lo que muestra la pantalla pasa', () {
      // Gas ideal: n = 0,02176 mol se muestra como "0,02 mol"; el
      // 2 % no cubriría 0,02, pero el suelo de ±0,005 sí.
      expect(isNumericAnswerCorrect(0.02, 0.02176), isTrue);
      // 0,03 ya es otro orden de magnitud y debe fallar.
      expect(isNumericAnswerCorrect(0.03, 0.02176), isFalse);
      // Qc = 0,015625 se muestra como "0,016".
      expect(isNumericAnswerCorrect(0.016, 0.015625), isTrue);
    });
  });

  group('parseNumericInput', () {
    test('válidos', () {
      expect(parseNumericInput('3.5'), 3.5);
      expect(parseNumericInput('-2.5'), -2.5);
      expect(parseNumericInput('0.'), 0.0);
      expect(parseNumericInput('42'), 42.0);
      // La calculadora puede devolver notación científica.
      expect(parseNumericInput('1.5e-3'), 0.0015);
      expect(parseNumericInput('2.5e+4'), 25000.0);
    });

    test('inválidos: vacío, solo punto, solo menos, texto', () {
      expect(parseNumericInput(''), isNull);
      expect(parseNumericInput('.'), isNull);
      expect(parseNumericInput('-'), isNull);
      expect(parseNumericInput('-.'), isNull);
      expect(parseNumericInput('abc'), isNull);
      expect(parseNumericInput('1,5'), isNull);
    });
  });

  group('Calculadora científica: el evaluador', () {
    test('el ejemplo de Kristian: pH = −log[H⁺], −log(0.01) = 2', () {
      expect(evaluateExpression('−log(0.01)'), closeTo(2.0, 1e-9));
      expect(evaluateExpression('-log(0.01)'), closeTo(2.0, 1e-9));
      expect(evaluateExpression('−log(0.001)'), closeTo(3.0, 1e-9));
    });

    test('log base 10 y ln', () {
      expect(evaluateExpression('log(100)'), closeTo(2.0, 1e-9));
      expect(evaluateExpression('log(1000)'), closeTo(3.0, 1e-9));
      expect(evaluateExpression('log(10)'), closeTo(1.0, 1e-9));
      expect(evaluateExpression('ln(e)'), closeTo(1.0, 1e-9));
      expect(evaluateExpression('ln(1)'), closeTo(0.0, 1e-9));
    });

    test('raíz, potencias y 10^x', () {
      expect(evaluateExpression('√(16)'), closeTo(4.0, 1e-9));
      expect(evaluateExpression('sqrt(16)'), closeTo(4.0, 1e-9));
      expect(evaluateExpression('3^2'), closeTo(9.0, 1e-9));
      expect(evaluateExpression('10^2'), closeTo(100.0, 1e-9));
      expect(evaluateExpression('10^(2)'), closeTo(100.0, 1e-9));
      expect(evaluateExpression('e^2'), closeTo(7.389056, 1e-6));
      expect(evaluateExpression('e^0'), closeTo(1.0, 1e-9));
    });

    test('la constante π', () {
      expect(evaluateExpression('π'), closeTo(3.14159265, 1e-8));
      expect(evaluateExpression('pi'), closeTo(3.14159265, 1e-8));
      expect(evaluateExpression('2×π'), closeTo(6.28318531, 1e-8));
      expect(evaluateExpression('π^2'), closeTo(9.8696, 1e-4));
    });

    test('notación científica: 2×10^3 = 2000', () {
      expect(evaluateExpression('2×10^3'), closeTo(2000.0, 1e-9));
      expect(evaluateExpression('2*10^3'), closeTo(2000.0, 1e-9));
      expect(evaluateExpression('1.5e-3'), closeTo(0.0015, 1e-12));
      expect(evaluateExpression('5×10^-3'), closeTo(0.005, 1e-12));
    });

    test('precedencia y paréntesis', () {
      expect(evaluateExpression('2+3×4'), closeTo(14.0, 1e-9));
      expect(evaluateExpression('(2+3)×4'), closeTo(20.0, 1e-9));
      expect(evaluateExpression('1+2×3^2'), closeTo(19.0, 1e-9));
      expect(evaluateExpression('10÷4'), closeTo(2.5, 1e-9));
      expect(evaluateExpression('(10-4)÷2'), closeTo(3.0, 1e-9));
    });

    test('la potencia asocia a la derecha: 2^3^2 = 2^9 = 512', () {
      expect(evaluateExpression('2^3^2'), closeTo(512.0, 1e-9));
    });

    test('menos unario y decimales', () {
      expect(evaluateExpression('−5+3'), closeTo(-2.0, 1e-9));
      expect(evaluateExpression('2×−3'), closeTo(-6.0, 1e-9));
      expect(evaluateExpression('0.5+0.25'), closeTo(0.75, 1e-9));
      expect(evaluateExpression('.5×2'), closeTo(1.0, 1e-9));
    });

    test('expresiones no válidas devuelven null', () {
      expect(evaluateExpression(''), isNull);
      expect(evaluateExpression('2+'), isNull);
      expect(evaluateExpression('(2+3'), isNull);
      expect(evaluateExpression('2++'), isNull);
      expect(evaluateExpression('log(0)'), isNull);
      expect(evaluateExpression('log(-1)'), isNull);
      expect(evaluateExpression('ln(0)'), isNull);
      expect(evaluateExpression('√(-4)'), isNull);
      expect(evaluateExpression('1÷0'), isNull);
      expect(evaluateExpression('1/0'), isNull);
      expect(evaluateExpression('2e'), isNull);
      expect(evaluateExpression('abc'), isNull);
    });

    test('formatCalculatorResult', () {
      expect(formatCalculatorResult(2.0), '2');
      expect(formatCalculatorResult(2.5), '2.5');
      expect(formatCalculatorResult(0.3333333333), '0.333333');
      expect(formatCalculatorResult(-0.0), '0');
      expect(formatCalculatorResult(0.0000001), '1.0000e-7');
      expect(formatCalculatorResult(1000000000000.0), '1.0000e+12');
    });
  });

  group('displayedIndexForNumericAnswer', () {
    final q = QuizQuestion(
      topic: 'estequiometria',
      question: '¿Cuántos moles hay en 36 g de agua?',
      options: ['0.50 mol', '1.00 mol', '2.00 mol', '3.60 mol'],
      answer: 2,
      explanation: 'n = m/M.',
      numericAnswer: 2.0,
      numericUnit: 'mol',
    );
    const order = [3, 0, 2, 1];

    test('correcta -> el índice donde está la opción correcta', () {
      final i = displayedIndexForNumericAnswer(
          typed: 2.0, question: q, order: order);
      expect(order[i], q.answer);
    });

    test('incorrecta -> un índice donde NO está la correcta', () {
      final i = displayedIndexForNumericAnswer(
          typed: 3.6, question: q, order: order);
      expect(order[i], isNot(q.answer));
    });
  });

  group('Qué preguntas son de cálculo', () {
    test('las 9 de cálculo llevan valor numérico y su unidad', () {
      final cases = <(GeneratedQuestion, String?)>{
        (buildMolarMass('H2O'), 'g/mol'),
        (buildMassMoles('moles', 'H2O', 36), 'mol'),
        (buildMassMoles('mass', 'NaCl', 2), 'g'),
        (buildMolarity('molarity', 1.0, 500), 'M'),
        (buildMolarity('moles', 0.5, 250), 'mol'),
        (buildDilution('c2', 2.0, 100, 1000), 'M'),
        (buildDilution('v1', 2.0, 0.5, 500), 'mL'),
        (buildPh('ph', 1, 7), 'pH'),
        (buildGas('volume', 1, 27, 1), 'L'),
        (buildGas('moles', 1, 27, 10), 'mol'),
        (buildGas('pressure', 1, 27, 10), 'atm'),
        (buildStoichiometry('product', 0, 4), 'mol'),
        (buildEquilibrium(0, 1.0, 1.0, 1.0), null),
        (buildThermo(100, 0, 10), 'kJ'),
      };
      for (final (g, unit) in cases) {
        expect(g.question.isNumeric, isTrue,
            reason: g.id);
        expect(g.question.numericAnswer, isNotNull, reason: g.id);
        expect(g.question.numericUnit, unit, reason: g.id);
      }
    });

    test('masa molar del agua: 18,02 g/mol', () {
      final g = buildMolarMass('H2O');
      expect(g.question.numericAnswer, closeTo(18.02, 0.01));
    });

    test('pH de [H+] = 1×10⁻⁷: 7,00', () {
      final g = buildPh('ph', 1, 7);
      expect(g.question.numericAnswer, closeTo(7.0, 0.001));
    });

    test('el Qc es adimensional: sin unidad', () {
      final g = buildEquilibrium(0, 1.0, 1.0, 1.0);
      expect(g.question.numericAnswer, closeTo(1.0, 0.001));
      expect(g.question.numericUnit, isNull);
    });

    test('tabla y enlace son conceptuales: siguen con opciones', () {
      for (final form in ['z', 'symbol', 'mass', 'group']) {
        expect(buildPeriodic(form, 'H').question.isNumeric, isFalse,
            reason: 'periodic:$form');
      }
      expect(buildBonding('geometry', 'CH₄').question.isNumeric, isFalse);
      expect(buildBonding('bond', 'NaCl').question.isNumeric, isFalse);
    });

    test('ninguna pregunta del banco es de cálculo', () {
      for (final q in allQuestions) {
        expect(q.isNumeric, isFalse, reason: q.question);
      }
    });

    test('copyWith conserva el valor numérico (lo usa _withDifficulty)',
        () {
      final g = buildMolarMass('H2O');
      final copy = g.question.copyWith(difficulty: 1);
      expect(copy.numericAnswer, g.question.numericAnswer);
      expect(copy.numericUnit, g.question.numericUnit);
      expect(copy.isNumeric, isTrue);
    });

    test('rebuildGenerated conserva el valor numérico y la unidad', () {
      for (final g in [
        buildMassMoles('moles', 'H2O', 36),
        buildPh('ph', 3, 4),
        buildGas('volume', 2, 27, 1),
        buildThermo(200, 1, 25),
      ]) {
        final rebuilt = rebuildGenerated(g.id);
        expect(rebuilt, isNotNull, reason: g.id);
        expect(rebuilt!.question.numericAnswer,
            g.question.numericAnswer,
            reason: g.id);
        expect(rebuilt.question.numericUnit, g.question.numericUnit,
            reason: g.id);
      }
    });

    test('la opción correcta mostrada siempre está dentro de la tolerancia',
        () {
      // El usuario teclea lo que ve en la opción correcta (o en la
      // explicación): eso siempre tiene que contar como acierto.
      final rng = Random(7);
      final topics = topicGeneratorTypes.keys.toList();
      for (var n = 0; n < 300; n++) {
        final topic = topics[rng.nextInt(topics.length)];
        final g = generateForTopic(topic, rng);
        final q = g.question;
        if (!q.isNumeric) continue;
        final shown = q.options[q.answer]
            .replaceAll(RegExp(r'[^0-9.\-]'), '');
        final shownValue = double.parse(shown);
        expect(
          isNumericAnswerCorrect(shownValue, q.numericAnswer!),
          isTrue,
          reason: '${g.id}: se muestra $shown y el exacto es '
              '${q.numericAnswer}',
        );
      }
    });
  });

  group('NumericKeypad (widget)', () {
    /// Lo que muestra el campo de respuesta (no las teclas: la tecla
    /// '0' y el display '0' tienen el mismo texto).
    String displayText(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const Key('numeric-keypad-display')))
        .data!;

    /// La expresión que se va escribiendo (o la pista si está vacía).
    String expressionText(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const Key('calculator-expression')))
        .data!;

    /// La vista previa del resultado ('= 2' o '' si no es válida).
    String resultText(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const Key('calculator-result')))
        .data!;

    Future<void> pumpKeypad(
      WidgetTester tester, {
      String? unit,
      bool enabled = true,
      ValueChanged<double>? onSubmit,
    }) async {
      tallViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: NumericKeypad(
              unit: unit,
              enabled: enabled,
              onSubmit: onSubmit ?? (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    /// Toca una tecla por su texto: por el botón que la contiene, no
    /// por el texto suelto (la expresión '2' y la tecla '2' dirían
    /// lo mismo y el buscador sería ambiguo).
    Future<void> tapKey(WidgetTester tester, String label) async {
      final filled = find.widgetWithText(FilledButton, label);
      if (filled.evaluate().isNotEmpty) {
        await tester.tap(filled);
      } else {
        await tester.tap(find.widgetWithText(OutlinedButton, label));
      }
      await tester.pump();
    }

    testWidgets('muestra todas las teclas y la unidad', (tester) async {
      await pumpKeypad(tester, unit: 'mol');
      for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9']) {
        expect(find.widgetWithText(FilledButton, d), findsOneWidget);
      }
      expect(find.widgetWithText(FilledButton, '0'), findsOneWidget);
      expect(find.text('.'), findsOneWidget);
      for (final op in ['+', '−', '×', '÷', '^']) {
        expect(find.widgetWithText(FilledButton, op), findsOneWidget);
      }
      for (final sci in ['log', 'ln', '√', 'x²', '10^x', 'e^x', '×10^x', 'π']) {
        expect(find.widgetWithText(FilledButton, sci), findsOneWidget);
      }
      expect(find.widgetWithText(FilledButton, '('), findsOneWidget);
      expect(find.widgetWithText(FilledButton, ')'), findsOneWidget);
      expect(find.text('Borrar'), findsOneWidget);
      expect(find.text('Limpiar'), findsOneWidget);
      expect(find.text('='), findsOneWidget);
      expect(find.text('Comprobar'), findsOneWidget);
      expect(find.text('mol'), findsOneWidget);
      expect(displayText(tester), '0');
      expect(expressionText(tester), 'Escribe el cálculo');
      expect(resultText(tester), '');
    });

    testWidgets('sin unidad no se muestra el chip', (tester) async {
      await pumpKeypad(tester, unit: null);
      expect(find.text('mol'), findsNothing);
    });

    testWidgets('teclear 2 . 5, = y Comprobar entrega 2.5',
        (tester) async {
      double? submitted;
      await pumpKeypad(tester,
          unit: 'mol', onSubmit: (v) => submitted = v);
      await tapKey(tester, '2');
      await tapKey(tester, '.');
      await tapKey(tester, '5');
      expect(expressionText(tester), '2.5');
      expect(resultText(tester), '= 2.5');
      // Sin '=', Comprobar sigue apagado: el resultado aún no está
      // en el campo de respuesta.
      expect(displayText(tester), '0');
      await tapKey(tester, 'Comprobar');
      expect(submitted, isNull);
      await tapKey(tester, '=');
      expect(displayText(tester), '2.5');
      await tapKey(tester, 'Comprobar');
      expect(submitted, 2.5);
    });

    testWidgets('Comprobar apagado con el campo vacío', (tester) async {
      double? submitted;
      await pumpKeypad(tester,
          unit: 'mol', onSubmit: (v) => submitted = v);
      await tapKey(tester, 'Comprobar');
      expect(submitted, isNull);
    });

    testWidgets('menos al principio: −3', (tester) async {
      double? submitted;
      await pumpKeypad(tester, onSubmit: (v) => submitted = v);
      await tapKey(tester, '−');
      await tapKey(tester, '3');
      expect(expressionText(tester), '−3');
      await tapKey(tester, '=');
      expect(displayText(tester), '-3');
      await tapKey(tester, 'Comprobar');
      expect(submitted, -3.0);
    });

    testWidgets('Borrar quita un dígito; Limpiar lo quita todo',
        (tester) async {
      await pumpKeypad(tester, unit: 'g');
      await tapKey(tester, '1');
      await tapKey(tester, '2');
      expect(expressionText(tester), '12');
      await tapKey(tester, 'Borrar');
      expect(expressionText(tester), '1');
      await tapKey(tester, '2');
      await tapKey(tester, 'Limpiar');
      expect(expressionText(tester), 'Escribe el cálculo');
      expect(displayText(tester), '0');
    });

    testWidgets('desactivado: las teclas no escriben', (tester) async {
      await pumpKeypad(tester, unit: 'L', enabled: false);
      await tapKey(tester, '5');
      expect(expressionText(tester), 'Escribe el cálculo');
      expect(displayText(tester), '0');
    });
  });

  group('Calculadora científica (widget)', () {
    String displayText(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const Key('numeric-keypad-display')))
        .data!;
    String expressionText(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const Key('calculator-expression')))
        .data!;
    String resultText(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const Key('calculator-result')))
        .data!;

    Future<double?> pumpCalc(
      WidgetTester tester, {
      String? unit,
    }) async {
      tallViewport(tester);
      double? submitted;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: NumericKeypad(
              unit: unit,
              enabled: true,
              onSubmit: (v) => submitted = v,
            ),
          ),
        ),
      );
      await tester.pump();
      return submitted;
    }

    Future<void> tapKey(WidgetTester tester, String label) async {
      final filled = find.widgetWithText(FilledButton, label);
      if (filled.evaluate().isNotEmpty) {
        await tester.tap(filled);
      } else {
        await tester.tap(find.widgetWithText(OutlinedButton, label));
      }
      await tester.pump();
    }

    Future<void> tapKeys(
        WidgetTester tester, List<String> labels) async {
      for (final label in labels) {
        await tapKey(tester, label);
      }
    }

    testWidgets('pH: −log(0.01) = 2 (el ejemplo de Kristian)',
        (tester) async {
      tallViewport(tester);
      double? submitted;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: NumericKeypad(
              unit: 'pH',
              enabled: true,
              onSubmit: (v) => submitted = v,
            ),
          ),
        ),
      );
      await tester.pump();
      await tapKeys(tester, ['−', 'log', '0', '.', '0', '1', ')']);
      expect(expressionText(tester), '−log(0.01)');
      expect(resultText(tester), '= 2');
      await tapKey(tester, '=');
      expect(displayText(tester), '2');
      await tapKey(tester, 'Comprobar');
      expect(submitted, 2.0);
    });

    testWidgets('log(100) = 2 y √16 = 4', (tester) async {
      await pumpCalc(tester);
      await tapKeys(tester, ['log', '1', '0', '0', ')', '=']);
      expect(displayText(tester), '2');
      await tapKey(tester, 'Limpiar');
      await tapKeys(tester, ['√', '1', '6', ')', '=']);
      expect(displayText(tester), '4');
    });

    testWidgets('10^2 = 100 y 2×10^3 = 2000', (tester) async {
      await pumpCalc(tester);
      await tapKeys(tester, ['10^x', '2', '=']);
      expect(displayText(tester), '100');
      await tapKey(tester, 'Limpiar');
      await tapKeys(tester, ['2', '×10^x', '3', '=']);
      expect(displayText(tester), '2000');
    });

    testWidgets('paréntesis y precedencia: (2+3)×4 = 20',
        (tester) async {
      await pumpCalc(tester);
      await tapKeys(tester, ['(', '2', '+', '3', ')', '×', '4', '=']);
      expect(expressionText(tester), '(2+3)×4');
      expect(displayText(tester), '20');
    });

    testWidgets("'=' no hace nada con una expresión incompleta",
        (tester) async {
      tallViewport(tester);
      double? submitted;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: NumericKeypad(
              unit: 'mol',
              enabled: true,
              onSubmit: (v) => submitted = v,
            ),
          ),
        ),
      );
      await tester.pump();
      await tapKeys(tester, ['2', '+']);
      expect(resultText(tester), '');
      await tapKey(tester, '=');
      expect(displayText(tester), '0');
      await tapKey(tester, 'Comprobar');
      expect(submitted, isNull);
    });

    testWidgets("tras '=' un dígito empieza de nuevo y un operador sigue",
        (tester) async {
      await pumpCalc(tester);
      await tapKeys(tester, ['2', '+', '3', '=']);
      expect(displayText(tester), '5');
      await tapKeys(tester, ['×', '4', '=']);
      expect(displayText(tester), '20');
      await tapKey(tester, '7');
      expect(expressionText(tester), '7');
    });

    testWidgets("Borrar quita 'log(' entero", (tester) async {
      await pumpCalc(tester);
      await tapKeys(tester, ['log', '1', '0']);
      expect(expressionText(tester), 'log(10');
      await tapKey(tester, 'Borrar');
      expect(expressionText(tester), 'log(1');
      await tapKey(tester, 'Borrar');
      await tapKey(tester, 'Borrar');
      expect(expressionText(tester), 'Escribe el cálculo');
    });

    testWidgets('la tecla π: 2×π y π solo', (tester) async {
      await pumpCalc(tester);
      await tapKeys(tester, ['2', 'π', '=']);
      expect(displayText(tester), '6.283185');
      await tapKey(tester, 'Limpiar');
      await tapKeys(tester, ['π', '=']);
      expect(displayText(tester), '3.141593');
      expect(resultText(tester), '= 3.141593');
    });

    testWidgets(
        'a tamaño de teléfono (390×844): pregunta arriba y todo el teclado cabe sin deslizar',
        (tester) async {
      tallViewport(tester, const Size(390, 844));
      double? submitted;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Si [H⁺] = 1×10⁻² mol/L, ¿cuál es el pH?',
                  style:
                      TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                NumericKeypad(
                  unit: 'pH',
                  enabled: true,
                  onSubmit: (v) => submitted = v,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      // Sin deslizar: la pregunta se ve arriba y Comprobar abajo,
      // dentro de la pantalla (sin errores de overflow).
      expect(tester.getCenter(find.text('Comprobar')).dy, lessThan(844));
      await tapKeys(tester, ['−', 'log', '0', '.', '0', '1', ')', '=']);
      expect(displayText(tester), '2');
      await tapKey(tester, 'Comprobar');
      expect(submitted, 2.0);
    });
  });

  group('El runner decide teclado u opciones según la pregunta', () {
    Future<void> pumpRunner(
        WidgetTester tester, List<QuizQuestion> items) async {
      tallViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: SimpleQuizRunner(
              title: 'Prueba',
              items: items,
              onFinished: (_, __) {},
              onExit: () {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('pregunta de cálculo: teclado, sin opciones',
        (tester) async {
      final g = buildMassMoles('moles', 'H2O', 36);
      await pumpRunner(tester, [g.question]);
      expect(find.byType(NumericKeypad), findsOneWidget);
      expect(find.text('2.00 mol'), findsNothing);
      expect(find.text('mol'), findsOneWidget);
    });

    testWidgets('pregunta conceptual: opciones, sin teclado',
        (tester) async {
      final q = allQuestions.firstWhere(
          (x) => x.question.startsWith('¿Qué es el reactivo limitante?'));
      await pumpRunner(tester, [q]);
      expect(find.byType(NumericKeypad), findsNothing);
      expect(find.text('El que se agota primero'), findsOneWidget);
    });

    testWidgets('responder con el teclado marca acierto y muestra la explicación',
        (tester) async {
      final g = buildMassMoles('moles', 'H2O', 36); // 36 g / 18,02 ≈ 2 mol
      await pumpRunner(tester, [g.question]);
      await tester.tap(find.text('2'));
      await tester.pump();
      // Con la pantalla alta (800×1600) todo el runner cabe sin
      // deslizar, como en el teléfono.
      await tester.tap(find.widgetWithText(FilledButton, '='));
      await tester.pump();
      await tester.tap(find.text('Comprobar'));
      await tester.pump();
      expect(find.text('¡Correcto!'), findsOneWidget);
    });
  });
}

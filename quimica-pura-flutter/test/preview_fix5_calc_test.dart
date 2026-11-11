// Vistas previas de la ronda #5, punto B, corrección 00:26
// (calculadora en PANTALLA COMPLETA con Navigator.push, no panel
// inline), 2026-11-11:
// - fix5_calc_pregunta.png: la pregunta de Kristian (rendimiento
//   teórico 20 g, obtienes 15 g, opciones en %) con el botoncito de
//   teclado visible y SIN calculadora: al entrar se ven la pregunta
//   y las opciones, nada más.
// - fix5_calc_pantalla.png: la PANTALLA de la calculadora abierta, a
//   página completa (aquí la normal, para la pregunta de opciones).
// - fix5_calc_vuelta.png: vuelta a la pregunta tras responder con la
//   pantalla: pregunta de cálculo (pH) con el resultado entregado
//   desde la calculadora científica (¡Correcto!).
// Se ejecuta con --update-goldens para ESCRIBIR los PNG en
// ~/workspace/melli-qui-v6-previews/ (nombres fix5_*). Viewport
// 393x852 (dpr 2), Roboto real. Los PNG se leen y se verifican a
// mano antes de informar.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/models.dart';
import 'package:quimica_pura/screens/calculator_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/question_generator.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/numeric_keypad.dart';
import 'package:quimica_pura/widgets/simple_quiz.dart';
import 'package:quimica_pura/widgets/twin_avatars.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadRobotoFonts();
    await loadMaterialIcons();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
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
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    await UserPrefs.saveThemeMode('claro');
    UserPrefs.isDark = false;
    UserPrefs.onboardingDone = true;
  });

  tearDown(() {
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = false;
    UserPrefs.isDark = false;
  });

  Future<void> setPhone(
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
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../melli-qui-v6-previews/$name'),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
  }

  /// Calienta la caché de imágenes de los acompañantes: el PNG se
  /// decodifica de forma asíncrona y, con la caché fría, la primera
  /// captura lo pilla sin cargar.
  Future<void> warmCompanions(WidgetTester tester) async {
    final ctx = tester.element(find.byType(MaterialApp));
    for (final c in Companion.values) {
      await precacheImage(AssetImage(companionAsset(c)), ctx);
    }
    await tester.pump();
  }

  Future<void> pumpRunner(
    WidgetTester tester, {
    required String title,
    required List<QuizQuestion> items,
  }) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: SimpleQuizRunner(
            title: title,
            items: items,
            onFinished: (_, __) {},
            onExit: () {},
            // Orden de opciones fijo: sin semilla el orden es
            // aleatorio y el golden acertaría 1 de cada 24 veces.
            shuffleSeed: 7,
          ),
        ),
      ),
    );
    await settle(tester);
    await warmCompanions(tester);
  }

  /// Toca una tecla por su texto: por el botón que la contiene.
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

  // Calentamiento: decodifica las imágenes de los acompañantes ANTES
  // de la primera captura (patrón de preview_fix2_test.dart).
  testWidgets('warm-up imágenes', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Row(
            key: Key('warmup'),
            children: [
              Image(
                  image: AssetImage('assets/brenda.png'),
                  width: 40,
                  height: 40),
              Image(
                  image: AssetImage('assets/britany.png'),
                  width: 40,
                  height: 40),
              Image(
                  image: AssetImage('assets/kristian.png'),
                  width: 40,
                  height: 40),
            ],
          ),
        ),
      ),
    );
    final context = tester.element(find.byKey(const Key('warmup')));
    await tester.runAsync(() async {
      for (final name in ['brenda', 'britany', 'kristian']) {
        await precacheImage(AssetImage('assets/$name.png'), context);
      }
    });
    await settle(tester);
  });

  testWidgets(
      'fix5_calc_pregunta: rendimiento con opciones en %, botoncito '
      'de teclado visible y SIN calculadora', (tester) async {
    const q = QuizQuestion(
      topic: 'estequiometria',
      question: 'El rendimiento teórico es 20 g y obtienes 15 g. '
          '¿Cuál es el rendimiento porcentual?',
      options: ['60 %', '75 %', '80 %', '133 %'],
      answer: 1,
      explanation: 'Rendimiento = 15 / 20 × 100 = 75 %.',
    );
    await pumpRunner(tester, title: 'Estequiometría', items: [q]);
    expect(find.byKey(const Key('calculator-toggle')), findsOneWidget);
    expect(find.byType(NumericKeypad), findsNothing);
    expect(find.byType(CalculatorScreen), findsNothing);
    expect(find.text('75 %'), findsOneWidget);
    await shot(tester, 'fix5_calc_pregunta.png');
  });

  testWidgets(
      'fix5_calc_pantalla: la PANTALLA de la calculadora abierta, a '
      'página completa', (tester) async {
    const q = QuizQuestion(
      topic: 'estequiometria',
      question: 'El rendimiento teórico es 20 g y obtienes 15 g. '
          '¿Cuál es el rendimiento porcentual?',
      options: ['60 %', '75 %', '80 %', '133 %'],
      answer: 1,
      explanation: 'Rendimiento = 15 / 20 × 100 = 75 %.',
    );
    await pumpRunner(tester, title: 'Estequiometría', items: [q]);
    await tester.tap(find.byKey(const Key('calculator-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CalculatorScreen), findsOneWidget);
    // La normal: sin log ni Usar resultado; con el resultado en vivo de
    // 15 ÷ 20 × 100 ya tecleado, para que la captura enseñe el visor.
    expect(find.text('log'), findsNothing);
    expect(find.text(tr('calcUseResult')), findsNothing);
    await tapKeys(
        tester, ['1', '5', '÷', '2', '0', '×', '1', '0', '0']);
    expect(find.text('= 75'), findsOneWidget);
    await shot(tester, 'fix5_calc_pantalla.png');
  });

  testWidgets(
      'fix5_calc_vuelta: vuelta a la pregunta tras responder con la '
      'calculadora científica', (tester) async {
    final g = buildPh('ph', 1, 7); // [H+] = 1×10⁻⁷, pH = 7
    await pumpRunner(tester, title: 'Ácidos y bases', items: [g.question]);
    await tester.tap(find.byKey(const Key('calculator-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CalculatorScreen), findsOneWidget);
    expect(find.text('log'), findsOneWidget);
    // −log(0.0000001) = 7: el usuario calcula en la pantalla y
    // entrega con Usar resultado; al volver, la pregunta está contestada.
    await tapKeys(tester, ['−', 'log', '0', '.', '0', '0', '0', '0', '0',
        '0', '1', ')', '=']);
    await tapKey(tester, tr('calcUseResult'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CalculatorScreen), findsNothing);
    expect(find.text(tr('quizCorrect')), findsOneWidget);
    await shot(tester, 'fix5_calc_vuelta.png');
  });
}

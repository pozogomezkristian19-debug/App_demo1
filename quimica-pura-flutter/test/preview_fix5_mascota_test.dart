// Vistas previas fix5 — punto de la mascota en preguntas (ronda #5).
// Se ejecuta con --update-goldens para ESCRIBIR los PNG en
// ~/workspace/melli-qui-v6-previews/ (nombres fix5_*). Viewport
// 360x800 (dpr 2), Roboto real. Los PNG se leen y se verifican a
// mano antes de informar.
//
// - fix5_mascota_pregunta.png: pregunta de nivel (SimpleQuizRunner
//   real): solo foto + burbuja con el mensaje, sin ningún nombre.
// (fix6, ronda #6: el golden fix5_mascota_qotd.png se quitó con la
// pregunta del día, eliminada por completo de la app.)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/models.dart';
import 'package:quimica_pura/services/notification_inbox.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
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
    await NotificationInbox.load();
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
    // (fix5) La burbuja ya nunca muestra el saludo: siempre el
    // mensaje de la pregunta o un ánimo, así que aquí no hay que
    // marcar a ningún acompañante como "ya presentado".
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
    NotificationInbox.resetForTests();
  });

  Future<void> setPhone(
    WidgetTester tester, {
    double width = 360,
    double height = 800,
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

  /// Calienta la caché de imágenes de los tres acompañantes antes
  /// de la captura: el PNG (1600x1600) se decodifica de forma
  /// asíncrona y, con la caché fría, la primera captura de un
  /// proceso lo pilla sin cargar (círculo vacío en vez de la foto).
  /// En el teléfono la foto va empaquetada y sale siempre; el
  /// círculo vacío es solo un artefacto del render, no un bug.
  Future<void> warmCompanions(WidgetTester tester) async {
    final ctx = tester.element(find.byType(MaterialApp));
    for (final c in Companion.values) {
      await precacheImage(AssetImage(companionAsset(c)), ctx);
    }
    await tester.pump();
  }

  // Calentamiento: decodifica las imágenes de los acompañantes
  // ANTES de la primera captura (patrón de preview_fix2_test.dart).
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
      'fix5_mascota_pregunta: pregunta de nivel con la burbuja: '
      'solo foto + mensaje, sin ningún nombre', (tester) async {
    const items = [
      QuizQuestion(
        topic: 'tabla',
        question: '¿Cuál es la masa molar del agua (H₂O)?',
        options: ['18 g/mol', '16 g/mol', '20 g/mol', '10 g/mol'],
        answer: 0,
        explanation: '2·1 + 16 = 18 g/mol.',
        difficulty: 1,
      ),
      QuizQuestion(
        topic: 'tabla',
        question: '¿Cuántos moles hay en 36 g de agua?',
        options: ['1 mol', '2 mol', '3 mol', '0,5 mol'],
        answer: 1,
        explanation: '36 g / 18 g/mol = 2 mol.',
        difficulty: 2,
      ),
    ];
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: SimpleQuizRunner(
            title: 'Nivel 1',
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await warmCompanions(tester);
    // La burbuja de la pregunta: foto + mensaje, ningún nombre.
    expect(find.byType(CompanionAvatar), findsOneWidget);
    expect(find.text('Brenda'), findsNothing);
    expect(find.text('— Brenda'), findsNothing);
    await shot(tester, 'fix5_mascota_pregunta.png');
  });

}

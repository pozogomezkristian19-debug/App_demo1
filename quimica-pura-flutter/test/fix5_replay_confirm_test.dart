// Volver a un nivel YA JUGADO (Kristian 2026-11-17): tocar un
// nodo pasado pregunta "¿Volver a jugar?" antes de entrar, para
// que un toque sin querer no empiece el juego directo. El nivel
// actual (sin pasar) arranca directo, sin preguntar.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/data/i18n/content_i18n.dart';
import 'package:quimica_pura/models.dart';
import 'package:quimica_pura/screens/practicar_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
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
    SharedPreferences.setMockInitialValues({'melli_rules_seen_v6': true});
    ProgressService.track = ProgressService.trackUni;
    await UserPrefs.load();
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
    UserPrefs.rulesSeenV6 = true;
    UserPrefs.onboardingDone = true;
    // Sorteo determinista (igual que el grupo de fotos de
    // fix5_desbloqueo): las preguntas del nivel no cambian entre
    // pasadas.
    final seeded = Random(20261113);
    PracticarScreen.randomFactory = () => seeded;
    PracticarScreen.debugElapsedMsOverride = 4000;
  });

  tearDown(() {
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.onboardingDone = false;
    PracticarScreen.randomFactory = Random.new;
    PracticarScreen.debugElapsedMsOverride = null;
  });

  Future<void> setPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
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

  Future<void> warmCompanions(WidgetTester tester) async {
    final ctx = tester.element(find.byType(MaterialApp));
    for (final c in Companion.values) {
      await tester.runAsync(() async {
        await precacheImage(AssetImage(companionAsset(c)), ctx);
      });
    }
    await tester.pump();
  }

  Future<void> pumpNiveles(WidgetTester tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: PracticarScreen(onOpenScreen: (_) {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> startLevel1(WidgetTester tester) async {
    await tester.ensureVisible(find.text('1').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('1').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Pregunta 1 de 5'), findsOneWidget);
  }

  Future<void> answerCurrent(
    WidgetTester tester, {
    required bool correct,
  }) async {
    final bank = localizedAllQuestions();
    QuizQuestion? shown;
    for (final q in bank) {
      if (find.text(q.question).evaluate().isNotEmpty) {
        shown = q;
        break;
      }
    }
    expect(shown, isNotNull, reason: 'No se ve ninguna pregunta del banco');
    final q = shown!;
    final option = correct
        ? q.options[q.answer]
        : q.options.firstWhere((o) => o != q.options[q.answer]);
    await tester.tap(find.text(option).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> next(WidgetTester tester) async {
    final nextFinder = find.text(tr('quizNext').toUpperCase());
    final target = nextFinder.evaluate().isNotEmpty
        ? nextFinder
        : find.text(tr('quizResult').toUpperCase());
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  QuizQuestion _shownQuestion(WidgetTester tester) {
    final bank = localizedAllQuestions();
    for (final q in bank) {
      if (find.text(q.question).evaluate().isNotEmpty) return q;
    }
    throw StateError('No se ve ninguna pregunta del banco');
  }

  Future<void> playLevel1(
    WidgetTester tester,
    List<bool> results,
  ) async {
    assert(results.length == 5);
    for (final r in results) {
      _shownQuestion(tester);
      await answerCurrent(tester, correct: r);
      await next(tester);
    }
    await tester.pump(const Duration(seconds: 1));
  }

  /// Pasa el Nivel 1 (5/5) y vuelve al camino con VOLVER.
  Future<void> passLevel1AndBack(WidgetTester tester) async {
    await pumpNiveles(tester);
    await warmCompanions(tester);
    await startLevel1(tester);
    await playLevel1(tester, [true, true, true, true, true]);
    expect(find.text(tr('quizLevelPassed')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.tap(find.text(tr('quizBack').toUpperCase()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(ProgressService.instance.unlockedLevel('estequiometria'), 2);
    expect(find.text(tr('levelsTitle')), findsOneWidget);
  }

  /// Toca el nodo pasado (estrella blanca) del Nivel 1.
  Future<void> tapPassedNode(WidgetTester tester) async {
    final star = find.byIcon(Icons.star).first;
    await tester.ensureVisible(star);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(star);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('Volver a un nivel ya jugado pregunta antes de entrar', () {
    testWidgets('el diálogo sale y CANCELAR se queda en el camino',
        (tester) async {
      await passLevel1AndBack(tester);
      await tapPassedNode(tester);
      expect(find.text(tr('replayLevelTitle')), findsOneWidget);
      expect(find.textContaining('Ya lo superaste'), findsOneWidget);
      await shot(tester, 'fix5_replay_dialog.png');
      await tester.tap(find.text(tr('cancel').toUpperCase()));
      // La salida del diálogo necesita DOS bombeos: el primero
      // avanza la animación de cierre y el segundo desmonta la
      // ruta ya completada (un solo pump largo no basta).
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('replayLevelTitle')), findsNothing);
      expect(find.text(tr('levelsTitle')), findsOneWidget);
      expect(find.textContaining('Pregunta 1 de 5'), findsNothing);
    });

    testWidgets('JUGAR entra al nivel; el actual arranca directo',
        (tester) async {
      await passLevel1AndBack(tester);
      await tapPassedNode(tester);
      expect(find.text(tr('replayLevelTitle')), findsOneWidget);
      await tester.tap(find.text(tr('replayLevelPlay').toUpperCase()));
      // El diálogo se cierra con animación y _start arranca al
      // completarse el pop: esperar a que termine.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Pregunta 1 de 5'), findsOneWidget);
      // Se juega entero y se vuelve al camino.
      await playLevel1(tester, [true, true, true, true, true]);
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.text(tr('quizBack').toUpperCase()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      // El Nivel 2 es el actual: arranca DIRECTO, sin preguntar.
      final node2 = find.text('2').first;
      await tester.ensureVisible(node2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(node2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(tr('replayLevelTitle')), findsNothing);
      expect(find.textContaining('Pregunta 1 de 5'), findsOneWidget);
    });
  });
}

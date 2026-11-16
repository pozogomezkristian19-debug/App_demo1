// Vidas en los niveles (Kristian 2026-11-16: 10 corazones, −1 por
// fallo en un nivel; en 0 el nivel termina al avanzar). Antes estas
// pruebas vivían en mascotas_animadas_test.dart; las mascotas se
// quitaron (Kristian 2026-11-16: "déjalo como estaba") y aquí quedan
// solo las dos de vidas, con la retroalimentación de antes (texto
// plano "Incorrecto. La correcta es: X", sin banner ni destellos).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/data/i18n/content_i18n.dart';
import 'package:quimica_pura/models.dart';
import 'package:quimica_pura/screens/practicar_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  group('vidas en los niveles', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({'melli_rules_seen_v6': true});
      await UserPrefs.load();
      await ProgressService.load();
      // Sin mock, el AudioPlayer estático de SoundService activa el
      // stream global de audioplayers y lanza MissingPluginException.
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
    });

    tearDown(() {
      UserPrefs.rulesSeenV6 = false;
      UserPrefs.onboardingDone = false;
    });

    /// Viewport de teléfono real (393x852, dpr 2).
    Future<void> setPhone(WidgetTester tester) async {
      tester.view.physicalSize = const Size(393 * 2, 852 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
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

    /// Empieza el Nivel 1 del primer tema (Estequiometría).
    Future<void> startLevel1(WidgetTester tester) async {
      await tester.ensureVisible(find.text('1').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('1').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Pregunta 1 de 5'), findsOneWidget);
    }

    /// Contesta la pregunta visible (igual que en fix5_repetir).
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
      final optionBtn = find.descendant(
        of: find.byType(ElevatedButton),
        matching: find.text(option),
      );
      await tester.tap(optionBtn.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    /// Botón "SIGUIENTE" / "RESULTADO" (flujo original).
    Future<void> next(WidgetTester tester) async {
      final nextFinder = find.text(tr('quizNext').toUpperCase());
      final target = nextFinder.evaluate().isNotEmpty
          ? nextFinder
          : find.text(tr('quizResult').toUpperCase());
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    /// La pregunta que se ve ahora mismo.
    QuizQuestion shownQuestion(WidgetTester tester) {
      final bank = localizedAllQuestions();
      for (final q in bank) {
        if (find.text(q.question).evaluate().isNotEmpty) return q;
      }
      throw StateError('No se ve ninguna pregunta del banco');
    }

    testWidgets(
        'al fallar: el texto dice la solución correcta y se pierde 1 corazón',
        (tester) async {
      await pumpNiveles(tester);
      await startLevel1(tester);
      final livesBefore = ProgressService.instance.livesLeft;
      final q = shownQuestion(tester);
      await answerCurrent(tester, correct: false);
      // Retroalimentación de antes: un solo texto "Incorrecto.
      // La correcta es: X" (sin banner).
      expect(find.textContaining(tr('quizIncorrect')), findsOneWidget);
      expect(
        find.textContaining(
          '${tr('quizCorrectIs')} ${q.options[q.answer]}',
        ),
        findsOneWidget,
      );
      // Fallar una respuesta en un nivel cuesta 1 corazón
      // (Kristian 2026-11-16: 10 corazones, −1 por fallo).
      expect(ProgressService.instance.livesLeft, livesBefore - 1);
    });

    testWidgets('con 1 corazón, fallar termina el nivel en el resultado',
        (tester) async {
      await pumpNiveles(tester);
      // Dejar 1 corazón: 9 abandonos (cada uno cuesta 1 vida).
      final p = ProgressService.instance;
      for (var i = 0; i < 9; i++) {
        p.loseLifeOnAbandon();
      }
      expect(p.livesLeft, 1);
      expect(p.canStartLevel, isTrue);
      await startLevel1(tester);
      await answerCurrent(tester, correct: false);
      expect(p.livesLeft, 0);
      // Al avanzar, el nivel termina (no hay siguiente pregunta):
      // pantalla de resultado con el título de nivel fallido.
      await next(tester);
      expect(find.text(tr('quizLevelFailed')), findsOneWidget);
      expect(p.canStartLevel, isFalse);
    });
  });
}

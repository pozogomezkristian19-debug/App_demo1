// Examen por tema + trofeos (Kristian, 2026-11-14): al final de cada
// tema hay un examen de ese tema con su trofeo; al aprobarlo se gana
// el trofeo, que sale en Cuenta con el contador "ganados / temas de
// la pista" (ejemplo suyo: 5 temas y 1 ganado = 1/5). El botón de
// claro/oscuro vive en el menú lateral, no en Cuenta.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/data/topics.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/account_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

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
  });

  Future<void> pumpNiveles(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 2, 800 * 2);
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

  Future<void> pumpCuenta(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: AccountScreen(
            onOpenScreen: (_) {},
            onShowAbout: () {},
            onShowShareApp: () {},
            // La pista completa (10 temas en Uni): el contador de la
            // cabecera es "ganados/total de la pista".
            trackTopics: uniTopics,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('trofeos por tema (ProgressService)', () {
    test('sin examen: ningún trofeo; con 85 %: trofeo ganado', () {
      final p = ProgressService.instance;
      expect(p.hasTrophy('estequiometria'), isFalse);
      expect(p.trophyCount(uniTopics), 0);
      p.recordScore(ProgressService.topicExamTestId('estequiometria'), 85);
      expect(p.hasTrophy('estequiometria'), isTrue);
      expect(p.trophyCount(uniTopics), 1);
    });

    test('con 79 % no hay trofeo: el listón es 80 %', () {
      final p = ProgressService.instance;
      p.recordScore(ProgressService.topicExamTestId('gases'), 79);
      expect(p.hasTrophy('gases'), isFalse);
      expect(p.trophyCount(uniTopics), 0);
    });
  });

  group('examen por tema en Niveles', () {
    testWidgets('hay un examen por tema, todos bloqueados al empezar',
        (tester) async {
      await pumpNiveles(tester);
      // 10 temas de Universidad, cada uno con su examen bloqueado.
      expect(find.text(tr('topicExamLocked')), findsNWidgets(10));
      expect(find.textContaining('Examen de'), findsNWidgets(20));
    });

    testWidgets('al completar el tema su examen se desbloquea',
        (tester) async {
      final p = ProgressService.instance;
      for (var level = 1;
          level <= ProgressService.levelCountForTopic('estequiometria');
          level++) {
        p.recordLevelPass('estequiometria', level);
      }
      expect(p.isTopicComplete('estequiometria'), isTrue);
      await pumpNiveles(tester);
      expect(find.text(tr('topicExamLocked')), findsNWidgets(9));
      expect(
          find.text(
              'Examen de Estequiometría y el mol · 10 preguntas'),
          findsOneWidget);
    });
  });

  group('Trofeos en la cabecera de Cuenta', () {
    testWidgets('sin trofeos: 0/10 en el RESUMEN, sin tarjeta',
        (tester) async {
      await pumpCuenta(tester);
      // Sin "Mis trofeos": el contador vive en el RESUMEN del
      // perfil (Kristian, 2026-11-14). 2026-11-16 (perfil estilo
      // Duolingo): "0/10" sale dos veces en el RESUMEN — Trofeos
      // (0/10 trofeos de tema) y Logros (0/10 logros) — los dos a
      // 16 pt (el valor del RESUMEN).
      expect(find.text(tr('trophiesTitle')), findsNothing);
      expect(find.text('0/10'), findsNWidgets(2));
      expect(
          find.byWidgetPredicate((w) =>
              w is Text &&
              w.data == '0/10' &&
              w.style?.fontSize == 16),
          findsNWidgets(2));
    });

    testWidgets('con un trofeo ganado: 1/10 en el RESUMEN',
        (tester) async {
      ProgressService.instance.recordScore(
          ProgressService.topicExamTestId('estequiometria'), 85);
      await pumpCuenta(tester);
      expect(find.text(tr('trophiesTitle')), findsNothing);
      // Trofeos 1/10 (el examen del tema da el trofeo); Logros
      // sigue 0/10 (el logro "Tema completado" pide el tema
      // completo, no solo el examen).
      expect(find.text('1/10'), findsOneWidget);
      expect(find.text('0/10'), findsOneWidget);
    });
  });
}

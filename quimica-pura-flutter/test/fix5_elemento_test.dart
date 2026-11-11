// Ronda fix5, punto 2: el popup del elemento del día ya no existe.
// - Al abrir la app no sale ningún popup de elemento (ni siquiera
//   con el día "sin marcar": a propósito NO se llama a
//   markElementDayShown() en el setUp, para probar que el popup
//   no aparece aunque nada lo suprima).
// - "Cómo se juega" YA NO sale solo en la primera entrada a Niveles
//   (ronda fix5, punto 1, actualización de Kristian 2026-11-11):
//   era un diálogo que salía una vez y se guardaba en el flag
//   rulesSeenV6; ahora es una PANTALLA COMPLETA que se abre solo
//   desde la fila de Cuenta, y el auto-show (y el flag) están
//   muertos: entrar a Niveles no muestra nada, ni la primera vez
//   ni después, con el flag en true o en false.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/how_to_play_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/notification_inbox.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
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

  Future<void> setPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('abrir Home no muestra el popup del elemento del día',
      (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
    expect(find.text(tr('elementDayTitle')), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
      'primera entrada a Niveles NO muestra "Cómo se juega" '
      '(ni diálogo ni pantalla)', (tester) async {
    UserPrefs.rulesSeenV6 = false;
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(tr('howToPlayTitle')), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(HowToPlayScreen), findsNothing);
    // Sin popup de elemento tampoco: no hay NINGÚN diálogo.
    expect(find.text(tr('elementDayTitle')), findsNothing);
  });

  testWidgets(
      '"Cómo se juega" tampoco sale en la segunda entrada a Niveles',
      (tester) async {
    UserPrefs.rulesSeenV6 = false;
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
    expect(find.text(tr('howToPlayTitle')), findsNothing);
    // Segunda entrada: se vuelve a montar la app entera con las
    // mismas preferencias guardadas.
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
    expect(find.text(tr('howToPlayTitle')), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(HowToPlayScreen), findsNothing);
  });

  testWidgets('el flag rulesSeenV6 ya no dispara nada al entrar a Niveles',
      (tester) async {
    // Con el flag en true (como lo dejaría una v6 vieja que ya
    // enseñó el diálogo) tampoco sale nada: el flag está muerto.
    UserPrefs.rulesSeenV6 = true;
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
    expect(find.text(tr('howToPlayTitle')), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(HowToPlayScreen), findsNothing);
  });
}

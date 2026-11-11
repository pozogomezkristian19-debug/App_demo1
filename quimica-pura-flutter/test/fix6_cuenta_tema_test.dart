// Pruebas de la ronda fix6 (2026-11-11), ítems 3 y 4:
// - Tema por defecto = 'sistema': quien no eligió nada sigue al
//   brillo del teléfono; quien guardó 'claro' u 'oscuro' lo
//   mantiene; el legado isDark=true sigue dando 'oscuro'.
// - Cuenta reordenada: las tres primeras filas son Estadísticas,
//   Mis errores y Cómo se juega; el resto en su orden de siempre.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    UserPrefs.rulesSeenV6 = true;
    UserPrefs.onboardingDone = true;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
  });

  tearDown(() async {
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.onboardingDone = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    await UserPrefs.saveThemeMode('claro');
  });

  group('Tema por defecto = sistema (fix6, ítem 3)', () {
    test('el valor inicial en código es sistema', () {
      // Antes de cargar nada: el estático nace en 'sistema'.
      expect(UserPrefs.themeMode, 'sistema');
      expect(UserPrefs.themeModeNotifier.value, 'sistema');
    });

    test('(a) sin valor guardado el tema por defecto es sistema',
        () async {
      SharedPreferences.setMockInitialValues({});
      await UserPrefs.load();
      expect(UserPrefs.themeMode, 'sistema');
      expect(UserPrefs.themeModeNotifier.value, 'sistema');
    });

    test('(b) claro guardado se mantiene claro', () async {
      SharedPreferences.setMockInitialValues(
          {'melli_theme_mode': 'claro'});
      await UserPrefs.load();
      expect(UserPrefs.themeMode, 'claro');
    });

    test('(c) oscuro guardado se mantiene oscuro', () async {
      SharedPreferences.setMockInitialValues(
          {'melli_theme_mode': 'oscuro'});
      await UserPrefs.load();
      expect(UserPrefs.themeMode, 'oscuro');
      expect(UserPrefs.isDark, true);
    });

    test('(d) legado isDark=true da oscuro', () async {
      SharedPreferences.setMockInitialValues({'melli_dark_mode': true});
      await UserPrefs.load();
      expect(UserPrefs.themeMode, 'oscuro');
      expect(UserPrefs.isDark, true);
    });

    test('con sistema, el tema sigue al brillo del teléfono', () async {
      SharedPreferences.setMockInitialValues({});
      await UserPrefs.load();
      expect(UserPrefs.themeMode, 'sistema');
      // En el entorno de test el teléfono está claro.
      expect(UserPrefs.effectiveDark, false);
    });
  });

  group('Cuenta reordenada (fix6, ítem 4)', () {
    testWidgets('las tres primeras filas son Estadísticas, Mis errores '
        'y Cómo se juega', (tester) async {
      // Ventana alta para que el ListView construya las 13 filas.
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await UserPrefs.saveThemeMode('claro');
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: AccountScreen(
              onOpenScreen: (_) {},
              onShowAbout: () {},
              onShowShareApp: () {},
              trackTopics: const ['estequiometria'],
            ),
          ),
        ),
      );
      await tester.pump();
      // Avanza 100 ms: la tarjeta de estadísticas va en un
      // FadeSlideIn con retardo de 80 ms.
      await tester.pump(const Duration(milliseconds: 100));

      // Las filas son ListTile dentro de _Row, en orden de
      // construcción: su título dice qué fila es cada una.
      final titles = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((tile) => (tile.title as Text).data!)
          .toList();
      expect(titles.length, 13);
      expect(titles.sublist(0, 3), [
        tr('accountStats'),
        tr('accountReview'),
        tr('howToPlayTitle'),
      ]);
      // El resto sigue en su mismo orden relativo.
      expect(titles.sublist(3), [
        tr('themeTitle'),
        tr('accountLanguage'),
        tr('accountVersion'),
        tr('accountFavorites'),
        tr('accountReminder'),
        tr('accountShareProgress'),
        tr('accountShareApp'),
        tr('checkUpdateTitle'),
        tr('accountAbout'),
        tr('supportWord'),
      ]);
    });
  });
}

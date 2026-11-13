// Pruebas de la ronda fix6 (2026-11-11), ítems 3 y 4:
// - Tema por defecto = 'sistema': quien no eligió nada sigue al
//   brillo del teléfono; quien guardó 'claro' u 'oscuro' lo
//   mantiene; el legado isDark=true sigue dando 'oscuro'.
// - Cuenta reordenada (7.1, Zona H): Vincular con Google
//   (prominente, primera fila), Estadísticas, Mis errores,
//   Amigos, Tabla de posiciones, Torneo, Grupos de estudio,
//   Tienda, Acerca de, Compartir, Soporte y Ajustes; el resto
//   vive en la pantalla Ajustes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/account_screen.dart';
import 'package:quimica_pura/screens/settings_screen.dart';
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

  group('Cuenta reordenada (7.1, Zona H)', () {
    testWidgets('las filas van en el orden 7.1, con Google primera',
        (tester) async {
      // Ventana alta para que el ListView construya las 12 filas.
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

      // Las filas son tarjetas redondeadas (organización 6.3, ya
      // no ListTile): se leen por sus títulos de texto, en orden
      // de aparición en la lista. Quemia 7.1: 12 filas — Google
      // prominente la primera (puerta a todo lo online), y las 11
      // del orden pedido; Tema, Cómo se juega, Idioma, Cambiar
      // versión, Favoritos, Recordatorio, Compartir progreso y
      // Buscar actualización ya NO están aquí: viven en Ajustes.
      // (Diseño 7.0: la fila "Compartir mi progreso" se quitó;
      // compartir es automático.)
      final expectedOrder = [
        tr('accountLinkGoogle'),
        tr('accountStats'),
        tr('accountReview'),
        tr('accountFriends'),
        tr('accountLeaderboard'),
        tr('accountTournaments'),
        tr('accountGroups'),
        tr('accountShop'),
        tr('accountAbout'),
        tr('accountShareApp'),
        tr('supportWord'),
        tr('settingsTitle'),
      ];
      expect(expectedOrder.length, 12);
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .toList();
      // La fila "Compartir la app" repite su título como subtítulo
      // (menuShare): se quitan los duplicados seguidos, no las filas.
      final titles = <String>[];
      for (final data in texts.where(expectedOrder.contains)) {
        if (titles.isEmpty || titles.last != data) titles.add(data);
      }
      expect(titles, expectedOrder);
      // Las 3 primeras no cambian: Google, Estadísticas, Errores.
      expect(titles.sublist(0, 3), [
        tr('accountLinkGoogle'),
        tr('accountStats'),
        tr('accountReview'),
      ]);
      // El resto sigue el orden pedido.
      expect(titles.sublist(3), [
        tr('accountFriends'),
        tr('accountLeaderboard'),
        tr('accountTournaments'),
        tr('accountGroups'),
        tr('accountShop'),
        tr('accountAbout'),
        tr('accountShareApp'),
        tr('supportWord'),
        tr('settingsTitle'),
      ]);
      // Nada de lo que se mudó a Ajustes queda en Cuenta.
      for (final moved in [
        tr('howToPlayTitle'),
        tr('themeTitle'),
        tr('accountLanguage'),
        tr('accountVersion'),
        tr('accountFavorites'),
        tr('accountReminder'),
        tr('accountShareProgress'),
        tr('checkUpdateTitle'),
      ]) {
        expect(find.text(moved), findsNothing);
      }
    });

    testWidgets('Ajustes trae las filas mudadas, en su orden',
        (tester) async {
      // Ventana alta para que el ListView construya las 9 filas.
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
            body: SettingsScreen(
              onOpenScreen: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final expectedOrder = [
        tr('themeTitle'),
        tr('accountReminder'),
        tr('howToPlayTitle'),
        tr('checkUpdateTitle'),
        tr('accountLanguage'),
        tr('accountVersion'),
        tr('accountFavorites'),
        tr('accountShareProgress'),
      ];
      expect(expectedOrder.length, 8);
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .toList();
      final titles = <String>[];
      for (final data in texts.where(expectedOrder.contains)) {
        if (titles.isEmpty || titles.last != data) titles.add(data);
      }
      expect(titles, expectedOrder);
      expect(find.text(tr('settingsTitle')), findsOneWidget);
    });
  });
}

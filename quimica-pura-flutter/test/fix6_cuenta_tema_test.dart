// Pruebas de la ronda fix6 (2026-11-11), ítems 3 y 4:
// - Tema por defecto = 'sistema': quien no eligió nada sigue al
//   brillo del teléfono; quien guardó 'claro' u 'oscuro' lo
//   mantiene; el legado isDark=true sigue dando 'oscuro'.
// - Cuenta como PERFIL ESTILO DUOLINGO (Kristian 2026-11-16):
//   la Cuenta ya no es una pestaña con filas: es una pantalla
//   aparte con foto grande, NOMBRE DEBAJO DEL AVATAR (guía §1),
//   RESUMEN y LOGROS, y las filas de contenido que quedan en el
//   perfil son SOLO 5 (simplificación aprobada 2026-11-16):
//   Estadísticas, Amigos, Tabla de posiciones, Torneo y Canjear
//   código. Premium queda SOLO en Ajustes → SUSCRIPCIÓN, Tienda
//   se mudó a Ajustes → TIENDA y Referidos a Ajustes → CUENTA.
//   Vincular con Google, Acerca de y Compartir la app se mudaron
//   a Ajustes; la fila Ajustes la sustituye el engranaje de
//   arriba.
//   Ajustes POR CATEGORÍAS (Cuenta / Suscripción / Tienda /
//   Soporte), 14 filas: en CUENTA Vincular con Google, Tema,
//   Idioma, Recordatorios, Notificaciones, Favoritos, Compartir
//   progreso y Referidos; en SUSCRIPCIÓN Premium; en TIENDA
//   Tienda; en SOPORTE Cómo se juega, Acerca de, Compartir la app
//   y Buscar actualización.
//   Quemia 7.7: se borraron "Mis errores" (la pantalla de repaso
//   sigue, desde notificaciones/búsqueda/píldora), "Grupos de
//   estudio" y "Soporte"; en Ajustes se borró "Cambiar versión"
//   (la pista es siempre 'uni').
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/account_screen.dart';
import 'package:quimica_pura/screens/settings_screen.dart';
import 'package:quimica_pura/services/auth_service.dart';
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

  group('Cuenta como perfil estilo Duolingo (2026-11-16)', () {
    testWidgets('las filas de contenido van en orden, en el perfil',
        (tester) async {
      // Ventana alta para que el ListView construya las 8 filas.
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      // Se bombea CON sesión: Amigos, Tabla y Torneo solo salen
      // con sesión (un invitado no ve lo de buscar otra gente).
      // El falso necesita uid (si no, currentUser es null).
      final fakeAuth = FakeAuthProvider()
        ..uid = 'fake-uid'
        ..googleLinked = true;
      AuthService.setProviderForTests(fakeAuth);
      addTearDown(AuthService.resetForTests);
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
      // Avanza 200 ms: las filas van en FadeSlideIn con retardos
      // de hasta 140 ms.
      await tester.pump(const Duration(milliseconds: 200));

      // Las filas son tarjetas redondeadas (organización 6.3, ya
      // no ListTile): se leen por sus títulos de texto, en orden
      // de aparición en la lista. Perfil estilo Duolingo:
      // 7 filas — Estadísticas, Amigos, Tabla, Torneo, Tienda,
      // Premium y Canjear. Tienda y Premium volvieron de Ajustes
      // (Kristian 2026-11-16: "saca tienda y premium de
      // configuraciones, déjalo en cuenta"). Vincular con Google,
      // Acerca de, Compartir la app y Ajustes ya NO están aquí:
      // viven en Ajustes por categorías (el engranaje de arriba
      // abre Ajustes).
      final expectedOrder = [
        tr('accountStats'),
        tr('accountFriends'),
        tr('accountLeaderboard'),
        tr('accountTournaments'),
        tr('accountShop'),
        tr('accountPremium'),
        tr('accountRedeem'),
      ];
      expect(expectedOrder.length, 7);
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
      // Nada de lo que se mudó a Ajustes queda en Cuenta — y
      // tampoco el interruptor rápido "Tema": desde la 7.7
      // (Kristian 2026-11-14: "el botón de cambiar modo claro y
      // oscuro, me gusta, pero no ahí" — "En el menú lateral")
      // vive al pie del MENÚ LATERAL, en su sección "TEMA";
      // el sistema de temas sigue viviendo en Ajustes.
      expect(find.text(tr('themeTitle')), findsNothing);
      for (final moved in [
        tr('accountReferrals'),
        tr('accountLinkGoogle'),
        tr('accountAbout'),
        tr('accountShareApp'),
        tr('settingsTitle'),
        tr('howToPlayTitle'),
        tr('accountLanguage'),
        tr('accountVersion'),
        tr('accountFavorites'),
        tr('accountReminder'),
        tr('accountShareProgress'),
        tr('checkUpdateTitle'),
      ]) {
        expect(find.text(moved), findsNothing);
      }
      // (El tap del interruptor rápido vive ahora en el menú
      // lateral: lo cubre fix6_menu_test.dart.)
    });

    testWidgets('Ajustes por categorías, con las 14 filas en orden',
        (tester) async {
      // Ventana alta para que el ListView construya las 14 filas.
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

      // Secciones en orden, como Duolingo (Tienda y Premium
      // volvieron a Cuenta, 2026-11-16: ya no hay SUSCRIPCIÓN
      // ni TIENDA en Ajustes).
      final sectionOrder = [
        tr('settingsAccountSection').toUpperCase(),
        tr('settingsSupportSection').toUpperCase(),
      ];
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .toList();
      final sections = <String>[];
      for (final data in texts.where(sectionOrder.contains)) {
        if (sections.isEmpty || sections.last != data) sections.add(data);
      }
      expect(sections, sectionOrder);

      // 12 filas (sin "Cambiar versión", eliminado; la pista es
      // siempre 'uni'): 8 en CUENTA (Referidos mudado de Cuenta)
      // y 4 en SOPORTE. Premium y Tienda volvieron a Cuenta
      // (Kristian 2026-11-16).
      final expectedOrder = [
        tr('accountLinkGoogle'),
        tr('themeTitle'),
        tr('accountLanguage'),
        tr('accountReminder'),
        tr('inboxTitle'),
        tr('accountFavorites'),
        tr('accountShareProgress'),
        tr('accountReferrals'),
        tr('howToPlayTitle'),
        tr('accountAbout'),
        tr('accountShareApp'),
        tr('checkUpdateTitle'),
      ];
      expect(expectedOrder.length, 12);
      final titles = <String>[];
      for (final data in texts.where(expectedOrder.contains)) {
        if (titles.isEmpty || titles.last != data) titles.add(data);
      }
      expect(titles, expectedOrder);
      expect(find.text(tr('settingsTitle')), findsOneWidget);
    });
  });
}

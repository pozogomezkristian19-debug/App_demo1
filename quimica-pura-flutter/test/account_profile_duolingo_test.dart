// Pruebas del perfil estilo Duolingo (Kristian 2026-11-16):
// Cuenta como PANTALLA APARTE (AccountProfilePage, ruta propia)
// que se abre al tocar Cuenta en la barra de abajo, SIN la barra
// de abajo y SIN la barra de corazones de arriba; se vuelve con
// la X y con el atrás del teléfono. Dentro, el perfil organizado
// como Duolingo: nombre en la cabecera, foto grande con lapicito
// DIRECTO sobre el fondo de la pantalla (sin cuadrado ni fondo
// distinto, Kristian 2026-11-16) + @usuario · año, fila
// Niveles/Siguiendo/Seguidores, AGREGA AMIGOS + QR, RESUMEN
// (racha, puntos, trofeos, logros), LOGROS y SOLO 5 filas de
// contenido (Estadísticas, Amigos, Tabla, Torneo, Canjear;
// Tienda y Referidos se mudaron a Ajustes, Premium solo queda en
// Ajustes → SUSCRIPCIÓN). Ajustes por categorías (Cuenta /
// Suscripción / Tienda / Soporte) con todo lo que había en Cuenta
// repartido — nada se borra, solo se reorganiza.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/account_screen.dart';
import 'package:quimica_pura/screens/settings_screen.dart';
import 'package:quimica_pura/services/auth_service.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/social_avatar.dart';
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
    UserPrefs.userName = 'Kristian Pozo';
    UserPrefs.publicUsername = '';
    // Con sesión (Google vinculada): lo social sale.
    AuthService.setProviderForTests(
      FakeAuthProvider()
        ..uid = 'dev-kristian'
        ..googleLinked = true
        ..email = 'kristian@example.com'
        ..displayName = 'Kristian Pozo',
    );
  });

  tearDown(() async {
    AuthService.resetForTests();
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.onboardingDone = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.userName = '';
    UserPrefs.publicUsername = '';
    await UserPrefs.saveThemeMode('claro');
  });

  /// Avance acotado en vez de pumpAndSettle: la tarjeta de
  /// completar perfil ya NO respira en bucle (la MascotMotion se
  /// quitó con la mascota, 2026-11-16), pero el avance acotado se
  /// queda: cubre las cargas async y la transición de ruta sin
  /// depender de que todo "se asiente".
  /// 900 ms cubren las cargas async y la transición de ruta.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> pumpAccount(tester, {void Function(String key)? onOpen}) async {
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
            onOpenScreen: onOpen ?? (_) {},
            onShowAbout: () {},
            onShowShareApp: () {},
            trackTopics: const ['estequiometria'],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  group('Cuenta como pantalla aparte (AccountProfilePage)', () {
    testWidgets('X, nombre en la cabecera y engranaje a Ajustes',
        (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const ValueKey('openAccount'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AccountProfilePage(
                      onOpenScreen: opened.add,
                      onShowAbout: () {},
                      onShowShareApp: () {},
                      trackTopics: const ['estequiometria'],
                    ),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // La pantalla aparte se abre al tocar Cuenta (aquí, el
      // botón del arnés) y NO es una pestaña del cuerpo.
      await tester.tap(find.byKey(const ValueKey('openAccount')));
      await settle(tester);
      expect(find.byKey(const ValueKey('accountCloseButton')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('accountSettingsButton')),
          findsOneWidget);
      // La cabecera lleva la X, el NOMBRE centrado (como en
      // Duolingo, Kristian 2026-11-16) y el engranaje. El nombre
      // aparece UNA sola vez: ya no va debajo del avatar.
      expect(find.text('Kristian Pozo'), findsOneWidget);
      // El engranaje abre Ajustes.
      await tester.tap(find.byKey(const ValueKey('accountSettingsButton')));
      await tester.pump();
      expect(opened, ['settings']);
      // La X vuelve (cierra la ruta aparte).
      await tester.tap(find.byKey(const ValueKey('accountCloseButton')));
      await settle(tester);
      expect(find.text('abrir'), findsOneWidget);
    });

    testWidgets('la Cuenta ya no lleva padding de barra inferior',
        (tester) async {
      await pumpAccount(tester);
      final listView =
          tester.widget<ListView>(find.byType(ListView).first);
      final padding = listView.padding as EdgeInsets;
      // Pantalla aparte, sin barra abajo que tape nada: 32 pt,
      // no 64 (barra) + 16.
      expect(padding.bottom, 32);
    });
  });

  group('Perfil estilo Duolingo (AccountScreen)', () {
    testWidgets('foto grande con lapicito y @usuario (el nombre va '
        'en la cabecera, no en el cuerpo)', (tester) async {
      final opened = <String>[];
      UserPrefs.publicUsername = 'kristian';
      await pumpAccount(tester, onOpen: opened.add);
      // La foto es el avatar grande (160 dp, no 96). En tests las
      // sugerencias traen 2 bots demo (2 SocialAvatar de 48 más):
      // se busca el grande por su tamaño.
      final bigAvatar = find.byWidgetPredicate(
        (w) => w is SocialAvatar && w.size == 160,
      );
      expect(bigAvatar, findsOneWidget);
      final avatar = tester.widget<SocialAvatar>(bigAvatar);
      expect(avatar.size, 160);
      // El nombre NO va en el cuerpo: vive en la cabecera de
      // AccountProfilePage (Kristian 2026-11-16, como Duolingo).
      expect(find.text('Kristian Pozo'), findsNothing);
      // @usuario en la línea de Duolingo (sin año: el progreso
      // aún no se subió nunca en tests, así que no se inventa).
      expect(find.text('@KRISTIAN'), findsOneWidget);
      // Tocar la foto abre el editor de avatar.
      await tester.tap(find.byWidgetPredicate(
        (w) => w is SocialAvatar && w.size == 160,
      ));
      await tester.pump();
      expect(opened, ['avatar']);
    });

    testWidgets('fila Niveles / Siguiendo / Seguidores',
        (tester) async {
      await pumpAccount(tester);
      await settle(tester);
      expect(find.text(tr('accountLevels')), findsOneWidget);
      expect(find.text(tr('accountFollowing')), findsOneWidget);
      expect(find.text(tr('accountFollowers')), findsOneWidget);
      // Niveles pasados: 0 sin progreso; seguidos/seguidores: 0
      // en tests (los contadores ya cargaron: settle).
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .toList();
      expect(texts.where((t) => t == '0').length, greaterThanOrEqualTo(3));
    });

    testWidgets('invitado: solo Niveles pasados, nada de lo social',
        (tester) async {
      // Sin sesión (Kristian 2026-11-16): Siguiendo/Seguidores,
      // AGREGA AMIGOS y las sugerencias solo salen una vez
      // iniciado sesión. Niveles pasados no es social y sí sale.
      AuthService.setProviderForTests(
        FakeAuthProvider()
          ..uid = 'dev-kristian'
          ..googleLinked = false
          ..emailLinked = false,
      );
      await pumpAccount(tester);
      await settle(tester);
      expect(find.text(tr('accountLevels')), findsOneWidget);
      expect(find.text(tr('accountFollowing')), findsNothing);
      expect(find.text(tr('accountFollowers')), findsNothing);
      expect(find.text(tr('accountAddFriends').toUpperCase()), findsNothing);
      expect(find.text(tr('accountSuggestionsTitle').toUpperCase()),
          findsNothing);
    });

    testWidgets('AGREGA AMIGOS abre Amigos', (tester) async {
      final opened = <String>[];
      await pumpAccount(tester, onOpen: opened.add);
      expect(
          find.text(tr('accountAddFriends').toUpperCase()), findsOneWidget);
      await tester.tap(find.text(tr('accountAddFriends').toUpperCase()));
      await tester.pump();
      expect(opened, ['friends']);
    });

    testWidgets('RESUMEN con racha, puntos, trofeos y logros',
        (tester) async {
      await pumpAccount(tester);
      expect(find.text(tr('accountSummary').toUpperCase()), findsOneWidget);
      expect(find.text(tr('accountStreak')), findsOneWidget);
      expect(find.text(tr('accountPoints')), findsOneWidget);
      expect(find.text(tr('trophiesWord')), findsOneWidget);
      expect(find.text(tr('accountAchievements')), findsOneWidget);
      // Sin progreso: racha 0, puntos 0, trofeos 0/1, logros 0/10.
      expect(find.text('0/1'), findsOneWidget);
      expect(find.text('0/10'), findsOneWidget);
    });

    testWidgets('LOGROS con los 10 logros', (tester) async {
      await pumpAccount(tester);
      expect(
          find.text(tr('accountAchievements').toUpperCase()), findsOneWidget);
      for (final title in [
        'Primer nivel',
        'Tema completado',
        'Examen mixto superado',
        'Racha de 3 días',
        'Racha de 7 días',
        'Racha de 30 días',
        '100 aciertos',
        '500 aciertos',
        '1000 aciertos',
        'Repaso al día',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
    });

    testWidgets(
        'las filas de contenido quedan en el perfil, en orden',
        (tester) async {
      await pumpAccount(tester);
      await settle(tester);
      // 7 filas en Cuenta: Tienda y Premium volvieron de Ajustes
      // (Kristian 2026-11-16: "saca tienda y premium de
      // configuraciones, déjalo en cuenta").
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
      final titles = <String>[];
      for (final data in texts.where(expectedOrder.contains)) {
        if (titles.isEmpty || titles.last != data) titles.add(data);
      }
      expect(titles, expectedOrder);
      // Referidos sigue en Ajustes: ya NO está en Cuenta (nada
      // se borra, solo cambia de sitio).
      for (final moved in [
        tr('accountReferrals'),
        tr('accountLinkGoogle'),
        tr('accountAbout'),
        tr('accountShareApp'),
        tr('settingsTitle'),
      ]) {
        expect(find.text(moved), findsNothing, reason: moved);
      }
    });
  });

  group('Ajustes por categorías (Cuenta / Soporte)', () {
    testWidgets('las 12 filas, en orden y por secciones',
        (tester) async {
      final opened = <String>[];
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
              onOpenScreen: opened.add,
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

      // Las 12 filas, en orden: 8 en CUENTA (Referidos mudado
      // de Cuenta) y 4 en SOPORTE. Premium y Tienda volvieron a
      // Cuenta (Kristian 2026-11-16).
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

      // Acerca/Compartir llegan por claves.
      await tester.tap(find.text(tr('accountAbout')));
      await tester.pump();
      expect(opened, ['about']);
      // "Compartir la app" repite su título como subtítulo
      // (menuShare): se toca el primero.
      await tester.tap(find.text(tr('accountShareApp')).first);
      await tester.pump();
      expect(opened, ['about', 'shareApp']);
    });
  });
}

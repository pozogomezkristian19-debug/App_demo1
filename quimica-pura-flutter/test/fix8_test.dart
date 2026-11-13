// Pruebas de la ronda #8 (Quemia 6.5): filas nuevas de Cuenta
// (Tabla de posiciones, Vincular con Google), tabla de posiciones
// con medallas, barra inferior con Niveles en círculo central y
// "Continuar con Google" en onboarding. (Diseño 7.0: compartir es
// automático con Google vinculada, sin pregunta — la página de
// permiso y la fila de Cuenta se eliminaron.)
//
// La recuperación por nombre de usuario se ELIMINÓ (cambio 09:08):
// estos tests comprueban que no queda rastro de esa fila.
// El inicio con Google va NATIVO con google_sign_in (7.1): el
// selector de cuentas vive dentro de la app y la credencial (idToken)
// se entrega a Firebase Auth con linkWithCredential /
// signInWithCredential. Aquí se usa el FakeAuthProvider del
// servicio, nunca el plugin real.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/account_screen.dart';
import 'package:quimica_pura/screens/leaderboard_screen.dart';
import 'package:quimica_pura/screens/onboarding_screen.dart';
import 'package:quimica_pura/screens/practicar_screen.dart';
import 'package:quimica_pura/screens/resolver_screen.dart';
import 'package:quimica_pura/screens/tabla_screen.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/auth_service.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/duo_button.dart';
import 'package:quimica_pura/widgets/google_sign_in_button.dart';
import 'package:quimica_pura/widgets/lucide_icons.dart';
import 'package:quimica_pura/widgets/social_avatar.dart';
import 'package:quimica_pura/widgets/main_bottom_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadRobotoFonts();
    // La app completa usa Nunito (Zona A): sin cargarla, los
    // textos se dibujan con la fuente cuadrada de pruebas, las
    // filas del menú crecen y los taps por texto fallan el
    // objetivo (el menú no abre la tabla).
    await loadNunitoFonts();
  });

  late FakeAuthProvider fakeAuth;
  late InMemoryAnalyticsRepository fakeRepo;

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
    UserPrefs.userName = 'kristian';
    fakeAuth = FakeAuthProvider();
    AuthService.setProviderForTests(fakeAuth);
    fakeRepo = InMemoryAnalyticsRepository();
    AnalyticsSync.setRepositoryForTests(fakeRepo);
  });

  tearDown(() {
    AnalyticsSync.resetForTests();
    AuthService.resetForTests();
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = false;
    UserPrefs.isDark = false;
    UserPrefs.userName = '';
  });

  const tabColors = [
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
    Color(0xFF00C2A8),
    Color(0xFF3B82F6),
    Color(0xFFF97316),
  ];

  /// Entradas de prueba para la tabla (desordenadas a propósito).
  List<LeaderboardEntry> sampleEntries() => const [
        LeaderboardEntry(
            deviceId: 'd-carlos',
            username: 'carlos',
            points: 150,
            levelsPassedTotal: 6,
            streak: 3),
        LeaderboardEntry(
            deviceId: 'd-brenda',
            username: 'brenda',
            points: 320,
            levelsPassedTotal: 12,
            streak: 9),
        LeaderboardEntry(
            deviceId: 'd-me',
            username: 'kristian',
            points: 280,
            levelsPassedTotal: 10,
            streak: 7),
        LeaderboardEntry(
            deviceId: 'd-britany',
            username: 'britany',
            points: 210,
            levelsPassedTotal: 8,
            streak: 5),
      ];

  Future<void> pumpLeaderboard(
    WidgetTester tester, {
    required Stream<List<LeaderboardEntry>> stream,
    String? currentDeviceId,
  }) async {
    tester.view.physicalSize = const Size(360 * 2, 800 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: LeaderboardScreen(
          entriesStream: stream,
          currentDeviceId: currentDeviceId,
          // Quemia 7.0: la puerta de Google está en la tabla; los
          // tests de la tabla entran con Google ya vinculada
          // (la puerta se prueba aparte, en fix8_social_test).
          isGoogleLinked: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<List<String>> pumpAccount(WidgetTester tester) async {
    // Ventana alta (360x1200): la lista de Cuenta es perezosa
    // (ListView) y las filas nuevas solo se construyen si caben
    // en pantalla; con 600 px de alto quedarían fuera y los
    // finders no las verían.
    tester.view.physicalSize = const Size(360 * 2, 1200 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: AccountScreen(
            onOpenScreen: opened.add,
            onShowAbout: () {},
            onShowShareApp: () {},
            trackTopics: const ['estequiometria'],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return opened;
  }

  Future<void> pumpApp(WidgetTester tester) async {
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

  Future<void> goToProfilePage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onFinished: () {})),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text(tr('obNext').toUpperCase()));
      await tester.pumpAndSettle();
    }
  }

  group('localización (ronda #8)', () {
    test('las 6 lenguas tienen las mismas claves (con las nuevas)', () {
      final maps = AppLang.allStrings;
      expect(maps.keys.toSet(), {'es', 'en', 'fr', 'it', 'pt', 'ru'});
      final esKeys = maps['es']!.keys.toSet();
      for (final e in maps.entries) {
        expect(e.value.keys.toSet(), esKeys, reason: e.key);
      }
      for (final key in [
        'bannedTitle',
        'bannedBody',
        'bannedSupport',
        'accountLeaderboard',
        'googleContinue',
        'accountLinkGoogle',
        'accountUnlinkGoogle',
        'googleSignInFailed',
        'googleNeedInternet',
        'googleLinking',
        'lbOffline',
        'lbTitle',
        'lbEmpty',
      ]) {
        expect(maps['es']![key], isNotEmpty, reason: key);
      }
      // Textos ES exactos de los cambios 09:13.
      expect(maps['es']!['googleSignInFailed'],
          'No se pudo iniciar sesión con Google. Inténtalo de nuevo.');
      expect(maps['es']!['googleNeedInternet'],
          'Necesitas internet para vincular tu cuenta');
      expect(maps['es']!['lbOffline'],
          'Sin conexión — la tabla se actualizará cuando tengas internet');
      // Los textos ES del otro agente, exactos.
      expect(maps['es']!['bannedTitle'], 'Cuenta suspendida');
      expect(maps['es']!['bannedBody'],
          'Tu cuenta fue suspendida por el creador. Si crees que es un error, escríbeme.');
      expect(maps['es']!['bannedSupport'], 'Escribir a Soporte');
      // La recuperación por nombre ya no existe en ningún idioma.
      for (final e in maps.entries) {
        expect(e.value.containsKey('recoverTitle'), isFalse, reason: e.key);
        expect(e.value.containsKey('accountRecover'), isFalse, reason: e.key);
      }
    });
  });

  group('tabla de posiciones', () {
    testWidgets('ordena por puntos desc y pone laureles a los 3 primeros',
        (tester) async {
      await pumpLeaderboard(tester,
          stream: Stream.value(sampleEntries()), currentDeviceId: 'd-me');
      // Orden: brenda (320), kristian (280), britany (210), carlos (150).
      final yBrenda =
          tester.getCenter(find.text('brenda')).dy;
      final yKristian =
          tester.getCenter(find.text('kristian (tú)')).dy;
      final yBritany = tester.getCenter(find.text('britany')).dy;
      final yCarlos = tester.getCenter(find.text('carlos')).dy;
      expect(yBrenda, lessThan(yKristian));
      expect(yKristian, lessThan(yBritany));
      expect(yBritany, lessThan(yCarlos));
      // Laureles oro/plata/bronce en los puestos 1-3 (solo el
      // laurel, sin avatar ni corona), nada en el 4.
      expect(find.byKey(const ValueKey('leaderboard-laurel-1')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('leaderboard-laurel-2')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('leaderboard-laurel-3')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('leaderboard-medal-1')),
          findsNothing);
      expect(find.byKey(const ValueKey('leaderboard-medal-2')),
          findsNothing);
      expect(find.byKey(const ValueKey('leaderboard-medal-3')),
          findsNothing);
      expect(find.byKey(const ValueKey('leaderboard-medal-4')),
          findsNothing);
      // Sin cabecera de columnas (rediseño Duolingo 7.0): ni
      // "Puesto" ni "Niveles" ni "Puntos" ni "Racha" como texto.
      expect(find.text(tr('lbRank')), findsNothing);
      expect(find.text(tr('lbLevels')), findsNothing);
      expect(find.text(tr('pointsWord')), findsNothing);
      expect(find.text(tr('streakWord')), findsNothing);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('el usuario actual va resaltado en teal con "(tú)"',
        (tester) async {
      await pumpLeaderboard(tester,
          stream: Stream.value(sampleEntries()), currentDeviceId: 'd-me');
      expect(find.text('kristian (tú)'), findsOneWidget);
      expect(find.byKey(const ValueKey('leaderboard-me')), findsOneWidget);
      // Los demás no llevan "(tú)".
      expect(find.text('brenda (tú)'), findsNothing);
    });

    testWidgets('vacía: "Sé el primero..." y pull-to-refresh',
        (tester) async {
      await pumpLeaderboard(tester,
          stream: Stream.value(const <LeaderboardEntry>[]),
          currentDeviceId: 'd-me');
      expect(find.text(tr('lbEmpty')), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('en vivo: al llegar un usuario nuevo, sube al top',
        (tester) async {
      final controller = StreamController<List<LeaderboardEntry>>();
      addTearDown(controller.close);
      await pumpLeaderboard(tester,
          stream: controller.stream, currentDeviceId: 'd-me');
      controller.add(sampleEntries());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
          tester.getCenter(find.text('brenda')).dy,
          lessThan(tester.getCenter(find.text('kristian (tú)')).dy));
      controller.add([
        ...sampleEntries(),
        const LeaderboardEntry(
            deviceId: 'd-nuevo',
            username: 'nuevo',
            points: 500,
            levelsPassedTotal: 20,
            streak: 12),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
          tester.getCenter(find.text('nuevo')).dy,
          lessThan(tester.getCenter(find.text('brenda')).dy));
    });
  });

  group('barra inferior con Niveles en el centro', () {
    Future<void> pumpNav(
      WidgetTester tester, {
      required int selected,
      required List<int> tapped,
    }) async {
      tester.view.physicalSize = const Size(393 * 2, 852 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: const SizedBox.shrink(),
            bottomNavigationBar: MainBottomNav(
              selectedIndex: selected,
              onSelected: tapped.add,
              isDark: false,
              tabColors: tabColors,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('orden: Aprender, Resolver, Niveles, Tabla, Cuenta',
        (tester) async {
      await pumpNav(tester, selected: 2, tapped: []);
      final xs = <String, double>{
        for (final label in [
          tr('tabLearn'),
          tr('tabResolver'),
          tr('tabLevels'),
          tr('tabTable'),
          tr('accountTitle'),
        ])
          label: tester.getCenter(find.text(label)).dx,
      };
      // Quemia 7.3 (Kristian): Aprender PRIMERO y Resolver después.
      expect(xs[tr('tabLearn')]!, lessThan(xs[tr('tabResolver')]!));
      expect(xs[tr('tabResolver')]!, lessThan(xs[tr('tabLevels')]!));
      expect(xs[tr('tabLevels')]!, lessThan(xs[tr('tabTable')]!));
      expect(xs[tr('tabTable')]!, lessThan(xs[tr('accountTitle')]!));
      // Sin NavigationBar: la barra es MainBottomNav.
      expect(find.byType(MainBottomNav), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('círculo central de 60 dp teal sólido con labio',
        (tester) async {
      await pumpNav(tester, selected: 2, tapped: []);
      expect(find.byKey(const ValueKey('nav-center-levels')),
          findsOneWidget);
      final circle = find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color ==
              const Color(0xFF00C2A8) &&
          (w.decoration as BoxDecoration).gradient == null);
      expect(circle, findsOneWidget);
      expect(tester.getSize(circle).width, 60);
      expect(tester.getSize(circle).height, 60);
    });

    testWidgets('cada tap llama onSelected con el índice correcto',
        (tester) async {
      final tapped = <int>[];
      await pumpNav(tester, selected: 2, tapped: tapped);
      await tester.tap(find.text(tr('tabLearn')));
      await tester.tap(find.text(tr('tabResolver')));
      await tester.tap(find.text(tr('tabTable')));
      await tester.tap(find.text(tr('accountTitle')));
      await tester.tap(find.byKey(const ValueKey('nav-center-levels')));
      // Quemia 7.3: Aprender es el 0 y Resolver el 1 (antes al revés).
      expect(tapped, [0, 1, 3, 4, 2]);
    });

    testWidgets('la pestaña seleccionada va resaltada', (tester) async {
      // Centro seleccionado: círculo teal + etiqueta en teal y negrita.
      await pumpNav(tester, selected: 2, tapped: []);
      expect(find.byKey(const ValueKey('nav-center-levels')),
          findsOneWidget);
      final levelsText = tester.widget<Text>(find.text(tr('tabLevels')));
      expect(levelsText.style?.color, const Color(0xFF00C2A8));
      expect(levelsText.style?.fontWeight, FontWeight.bold);
      // Otra seleccionada: su etiqueta también va en teal y negrita
      // (la barra nueva usa un solo color de acción, no un color
      // por pestaña).
      // Quemia 7.3: el índice 0 es Aprender (antes Resolver).
      await pumpNav(tester, selected: 0, tapped: []);
      final learnText = tester.widget<Text>(find.text(tr('tabLearn')));
      expect(learnText.style?.color, const Color(0xFF00C2A8));
      expect(learnText.style?.fontWeight, FontWeight.bold);
    });
  });

  group('Cuenta (ronda #8)', () {
    testWidgets('las filas nuevas existen y no queda la de recuperar',
        (tester) async {
      // (Diseño 7.0) La fila "Compartir mi progreso" ya no existe:
      // compartir es automático con Google vinculada.
      await pumpAccount(tester);
      expect(find.text(tr('accountLeaderboard')), findsOneWidget);
      expect(find.text(tr('accountLinkGoogle')), findsOneWidget);
      expect(find.text('Recuperar mi progreso'), findsNothing);
      // Orden 7.1: Amigos va antes que la tabla, y la tabla antes
      // que Torneo. Idioma ya no está en Cuenta: vive en Ajustes.
      final yFriends =
          tester.getCenter(find.text(tr('accountFriends'))).dy;
      final yLeaderboard =
          tester.getCenter(find.text(tr('accountLeaderboard'))).dy;
      final yTournaments =
          tester.getCenter(find.text(tr('accountTournaments'))).dy;
      expect(yFriends, lessThan(yLeaderboard));
      expect(yLeaderboard, lessThan(yTournaments));
      expect(find.text(tr('accountLanguage')), findsNothing);
    });

    testWidgets('"Tabla de posiciones" abre la pantalla de leaderboard',
        (tester) async {
      final opened = await pumpAccount(tester);
      await tester.tap(find.text(tr('accountLeaderboard')));
      await tester.pump();
      expect(opened, ['leaderboard']);
    });

    testWidgets(
        '"Vincular con Google" sin vincular enlaza y muestra el correo',
        (tester) async {
      fakeAuth.email = 'kristian@example.com';
      fakeAuth.displayName = 'Kristian';
      await pumpAccount(tester);
      expect(find.text(tr('accountLinkGoogleSub')), findsOneWidget);
      await tester.tap(find.text(tr('accountLinkGoogle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(AuthService.isGoogleLinked, isTrue);
      expect(find.text('kristian@example.com'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'vinculada: la fila muestra el correo y ofrece desvincular',
        (tester) async {
      fakeAuth.googleLinked = true;
      // Sin uid no hay sesión (currentUser == null) y la fila no
      // muestra nada: la cuenta vinculada es una sesión.
      fakeAuth.uid = 'fake-google-uid';
      fakeAuth.email = 'kristian@example.com';
      fakeAuth.displayName = 'Kristian';
      await pumpAccount(tester);
      await tester.pump();
      expect(find.text('kristian@example.com'), findsOneWidget);
      await tester.tap(find.text(tr('accountLinkGoogle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('accountUnlinkGoogle')), findsOneWidget);
      await tester.tap(find.text(tr('accountUnlinkGoogle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(AuthService.isGoogleLinked, isFalse);
      expect(find.text(tr('accountLinkGoogleSub')), findsOneWidget);
    });
  });

  group('app completa: orden nuevo y entradas de la tabla', () {
    testWidgets('arranca en Niveles y los taps cambian de pestaña',
        (tester) async {
      await pumpApp(tester);
      expect(find.byType(PracticarScreen), findsOneWidget);
      await tester.tap(find.text(tr('tabResolver')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ResolverScreen), findsOneWidget);
      await tester.tap(find.text(tr('tabTable')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TablaScreen), findsOneWidget);
      await tester.tap(find.text(tr('accountTitle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AccountScreen), findsOneWidget);
      // Volver a Niveles por el círculo central.
      await tester.tap(find.byKey(const ValueKey('nav-center-levels')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PracticarScreen), findsOneWidget);
    });

    testWidgets('el menú tiene la tabla y la abre', (tester) async {
      await pumpApp(tester);
      tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('accountLeaderboard')), findsOneWidget);
      await tester.tap(find.text(tr('accountLeaderboard')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(LeaderboardScreen), findsOneWidget);
      expect(find.text(tr('lbTitle')), findsWidgets);
    });
  });

  group('onboarding: "Continuar con Google"', () {
    testWidgets('el botón está debajo del nombre y el género',
        (tester) async {
      await goToProfilePage(tester);
      expect(find.text(tr('obProfileTitle')), findsOneWidget);
      await tester.ensureVisible(find.text('Google'));
      await tester.pumpAndSettle();
      expect(find.text('Google'), findsOneWidget);
      // La G de Google es el icono en colores, no un texto 'G'.
      expect(find.byType(GoogleGIcon), findsOneWidget);
      // Es opcional: el "Siguiente" sigue ahí.
      expect(find.text(tr('obNext').toUpperCase()), findsOneWidget);
    });

    testWidgets('al tocarlo, prellena el nombre con el de Google',
        (tester) async {
      fakeAuth.displayName = 'Kristian';
      fakeAuth.email = 'kristian@example.com';
      await goToProfilePage(tester);
      await tester.ensureVisible(find.text('Google'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Google'));
      // El enlace completa (fakeAuth rápido) sin dejar que dispare
      // el avance automático de 1,5 s del flujo de Google: estos
      // pumps no avanzan el reloj hasta 1,5 s.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(AuthService.isGoogleLinked, isTrue);
      // Flujo de Google, paso 0 ("Ya has iniciado sesión"): el
      // nombre de Google se muestra como texto (ya no en el campo
      // del perfil, que queda atrás).
      expect(find.text('Kristian'), findsOneWidget);
      // Avance automático al género: se adelanta el reloj 1,6 s
      // (el temporizador es de 1,5 s).
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.text(tr('obGoogleChooseGender')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('si el nombre ya está escrito, Google no lo pisa',
        (tester) async {
      fakeAuth.displayName = 'Kristian';
      await goToProfilePage(tester);
      await tester.enterText(find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == tr('obNameHint')), 'MiNombre');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Google'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Google'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      // Paso 0: se muestra el nombre ESCRITO, no el de Google.
      expect(find.text('MiNombre'), findsOneWidget);
      expect(find.text('Kristian'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.text(tr('obGoogleChooseGender')), findsOneWidget);
    });
  });

  group('tabla sin internet (regla 2)', () {
    testWidgets('Firebase no disponible: estado tranquilo, sin rojo',
        (tester) async {
      // Modo avión simulado: sin repositorio y sin Firebase listo.
      AnalyticsSync.resetForTests();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const LeaderboardScreen(isGoogleLinked: true),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('lbOffline')), findsOneWidget);
      expect(find.text(tr('lbEmpty')), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el stream con error también muestra el estado tranquilo',
        (tester) async {
      await pumpLeaderboard(tester,
          stream: Stream<List<LeaderboardEntry>>.error(
              StateError('sin red')),
          currentDeviceId: 'd-me');
      expect(find.text(tr('lbOffline')), findsOneWidget);
      expect(find.text(tr('lbEmpty')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'los 3 primeros solo el laurel; del 4º en adelante el avatar de inicial con su marco de rango',
        (tester) async {
      await pumpLeaderboard(tester,
          stream: Stream.value(sampleEntries()), currentDeviceId: 'd-me');
      // Rango por puesto (puntos: brenda 320, kristian 280, britany
      // 210, carlos 150): los 3 primeros llevan SOLO su laurel
      // (ronda 2b) — sin avatar con inicial y sin corona — y el 4º
      // su avatar teal con su inicial.
      expect(find.byKey(const ValueKey('leaderboard-laurel-1')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('leaderboard-laurel-2')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('leaderboard-laurel-3')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('social-avatar-brenda')),
          findsNothing);
      expect(find.byKey(const ValueKey('social-avatar-kristian')),
          findsNothing);
      expect(find.byKey(const ValueKey('social-avatar-britany')),
          findsNothing);
      // El 4º sí lleva su avatar de inicial con su marco de rango.
      expect(find.byKey(const ValueKey('social-avatar-carlos')),
          findsOneWidget);
      int rankOf(String username) => tester
          .widget<SocialAvatar>(find.ancestor(
              of: find.byKey(ValueKey('social-avatar-$username')),
              matching: find.byType(SocialAvatar)))
          .rank!;
      expect(rankOf('carlos'), 4);
      // Sin corona en la tabla: el laurel del 1º la sustituye.
      expect(
          find.byWidgetPredicate(
              (w) => w is LucideIcon && w.icon == LucideIcons.crown),
          findsNothing);
    });
  });

  group('Google sin internet y con fallo (09:13 + regla 2)', () {
    testWidgets('Cuenta sin internet: una sola línea, sin diálogo',
        (tester) async {
      // El enlace falla (sin red) y Firebase no está listo.
      fakeAuth.failAnonymous = true;
      final opened = await pumpAccount(tester);
      expect(opened, isEmpty);
      await tester.tap(find.text(tr('accountLinkGoogle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('googleNeedInternet')), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(AuthService.isGoogleLinked, isFalse);
      // No se queda en carga: la fila vuelve a su subtítulo normal.
      expect(find.text(tr('accountLinkGoogleSub')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Cuenta con Firebase listo y fallo: mensaje de sesión',
        (tester) async {
      fakeAuth.failAnonymous = true;
      AnalyticsSync.markFirebaseReady();
      await pumpAccount(tester);
      await tester.tap(find.text(tr('accountLinkGoogle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('googleSignInFailed')), findsOneWidget);
      expect(find.text(tr('googleNeedInternet')), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('onboarding sin internet: línea bajo el botón, sin colgarse',
        (tester) async {
      fakeAuth.failAnonymous = true;
      await goToProfilePage(tester);
      await tester.ensureVisible(find.text('Google'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Google'));
      await tester.pumpAndSettle();
      expect(find.text(tr('googleNeedInternet')), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      final field = tester.widget<TextField>(find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == tr('obNameHint')));
      expect(field.controller?.text, '');
      // El botón sigue habilitado: se puede reintentar.
      final button = tester
          .widget<DuoButton>(find.byWidgetPredicate((w) =>
              w is DuoButton &&
              w.label == 'Google'));
      expect(button.onPressed, isNotNull);
      // Reintento: sigue sin colgarse ni duplicar el error.
      await tester.tap(find.text('Google'));
      await tester.pumpAndSettle();
      expect(find.text(tr('googleNeedInternet')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('onboarding con Firebase listo y fallo: mensaje de sesión',
        (tester) async {
      fakeAuth.failAnonymous = true;
      AnalyticsSync.markFirebaseReady();
      await goToProfilePage(tester);
      await tester.ensureVisible(find.text('Google'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Google'));
      await tester.pumpAndSettle();
      expect(find.text(tr('googleSignInFailed')), findsOneWidget);
      expect(find.text(tr('googleNeedInternet')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('onboarding en carga: botón deshabilitado con spinner',
        (tester) async {
      final slow = _SlowFakeAuth();
      AuthService.setProviderForTests(slow);
      await goToProfilePage(tester);
      await tester.ensureVisible(find.text('Google'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Google'));
      await tester.pump();
      // En carga: deshabilitado y con spinner; sin error.
      var button = tester
          .widget<DuoButton>(find.byWidgetPredicate((w) =>
              w is DuoButton &&
              w.label == 'Google'));
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(tr('googleNeedInternet')), findsNothing);
      // Segundo toque ignorado: solo una llamada al servicio.
      await tester.tap(find.text('Google'),
          warnIfMissed: false);
      expect(slow.linkCalls, 1);
      // Completa con éxito: entra al flujo de Google y avanza solo
      // al género (el paso 0 "Ya has iniciado sesión" dura 1,5 s).
      slow.googleLinked = true;
      slow.linkCompleter.complete(true);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.text(tr('obGoogleChooseGender')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Cuenta en carga: "Vinculando…" y un solo intento',
        (tester) async {
      final slow = _SlowFakeAuth();
      AuthService.setProviderForTests(slow);
      await pumpAccount(tester);
      await tester.tap(find.text(tr('accountLinkGoogle')));
      await tester.pump();
      expect(find.text(tr('googleLinking')), findsOneWidget);
      await tester.tap(find.text(tr('accountLinkGoogle')),
          warnIfMissed: false);
      expect(slow.linkCalls, 1);
      slow.googleLinked = true;
      slow.linkCompleter.complete(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('lento@example.com'), findsOneWidget);
      expect(find.text(tr('googleLinking')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('regla 1: lo online, fuera de las pantallas de estudio', () {
    testWidgets('las pantallas de estudio no llevan nada online',
        (tester) async {
      await pumpApp(tester);
      // Niveles: sin tabla, sin Google.
      expect(
          find.descendant(
              of: find.byType(PracticarScreen),
              matching: find.text(tr('accountLeaderboard'))),
          findsNothing);
      expect(
          find.descendant(
              of: find.byType(PracticarScreen),
              matching: find.text(tr('googleContinue'))),
          findsNothing);
      // Resolver: lo mismo.
      await tester.tap(find.text(tr('tabResolver')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ResolverScreen), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(ResolverScreen),
              matching: find.text(tr('accountLeaderboard'))),
          findsNothing);
      expect(
          find.descendant(
              of: find.byType(ResolverScreen),
              matching: find.text(tr('googleContinue'))),
          findsNothing);
    });
  });
}

/// Proveedor de auth falso con enlace lento (para probar el estado
/// de carga): linkWithGoogle() no completa hasta que el test
/// resuelva [linkCompleter].
class _SlowFakeAuth implements AuthProvider {
  final Completer<bool> linkCompleter = Completer<bool>();
  var linkCalls = 0;
  String? uid = 'fake-anon-uid';
  String? email = 'lento@example.com';
  String? displayName = 'Lento';
  bool googleLinked = false;

  @override
  String? get lastGoogleError => null;

  @override
  Future<String?> ensureAnonymous() async => uid;

  @override
  Future<bool> linkWithGoogle() {
    linkCalls++;
    return linkCompleter.future;
  }

  @override
  Future<bool> signInWithGoogle() async => false;

  @override
  Future<bool> unlinkGoogle() async {
    googleLinked = false;
    email = null;
    displayName = null;
    return true;
  }

  @override
  AuthUserInfo? get currentUser => uid == null
      ? null
      : AuthUserInfo(
          uid: uid!,
          email: email,
          displayName: displayName,
          googleLinked: googleLinked,
        );
}


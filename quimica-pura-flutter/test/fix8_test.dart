// Pruebas de la ronda #8 (Quemia 6.5): filas nuevas de Cuenta
// (Tabla de posiciones, Vincular con Google), tabla de posiciones
// con medallas, barra inferior con Niveles en círculo central y
// "Continuar con Google" en onboarding. (Diseño 7.0: compartir es
// automático con Google vinculada, sin pregunta — la página de
// permiso y la fila de Cuenta se eliminaron.)
//
// La recuperación por nombre de usuario se ELIMINÓ (cambio 09:08):
// estos tests comprueban que no queda rastro de esa fila.
// (2026-11-16, perfil estilo Duolingo) Cuenta es ahora una
// pantalla aparte (AccountProfilePage) y "Vincular con Google"
// vive en Ajustes, sección CUENTA: los tests de Google montan
// SettingsScreen (pumpSettings); los de Cuenta montan el perfil.
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
import 'package:quimica_pura/screens/loading_screen.dart';
import 'package:quimica_pura/screens/onboarding_screen.dart';
import 'package:quimica_pura/screens/practicar_screen.dart';
import 'package:quimica_pura/screens/resolver_screen.dart';
import 'package:quimica_pura/screens/settings_screen.dart';
import 'package:quimica_pura/screens/tabla_screen.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/auth_service.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/otp_service.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/social_service.dart';
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
    // Sin esto, el nombre reclamado por un test anterior sobrevive
    // en el estático y la pantalla de elegir usuario se salta en
    // los tests siguientes (Kristian 2026-11-15).
    UserPrefs.publicUsername = '';
    fakeAuth = FakeAuthProvider();
    AuthService.setProviderForTests(fakeAuth);
    fakeRepo = InMemoryAnalyticsRepository();
    AnalyticsSync.setRepositoryForTests(fakeRepo);
    // La Cuenta carga sugerencias y conteos de seguir desde el
    // servicio social: repo en memoria con demo (si no, iría al
    // Firestore real y los conteos no serían deterministas).
    SocialService.setRepositoryForTests(
        InMemorySocialRepository(seedDemo: true));
  });

  tearDown(() {
    AnalyticsSync.resetForTests();
    SocialService.resetForTests();
    AuthService.resetForTests();
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = false;
    UserPrefs.isDark = false;
    UserPrefs.userName = '';
    UserPrefs.publicUsername = '';
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
    // Ventana alta (360x3000): la lista de Cuenta es perezosa
    // (ListView) y las filas solo se construyen si caben en
    // pantalla; con 1200 px de alto las filas quedaban fuera y los
    // finders no las veían (la pantalla creció con la zona del
    // avatar, el banner, la tarjeta de completar perfil, las
    // sugerencias, el RESUMEN y los LOGROS).
    tester.view.physicalSize = const Size(360 * 2, 3000 * 2);
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
    await tester.pump(const Duration(milliseconds: 200));
    return opened;
  }

  Future<List<String>> pumpSettings(WidgetTester tester) async {
    // Ajustes (2026-11-16, perfil estilo Duolingo): la fila
    // "Vincular con Google" vive aquí, en la sección CUENTA.
    // Ventana alta como pumpAccount: la lista es perezosa y las
    // filas solo se construyen si caben en pantalla.
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
          body: SettingsScreen(onOpenScreen: opened.add),
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

  Future<void> goToRegisterPage(WidgetTester tester) async {
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
    // Quemia 7.7 (rediseño 2026-11-13): sin pantalla de idioma (la
    // app coge el idioma del sistema) y sin barra de progreso; el
    // inicio es Bienvenida -> Elección -> la gemela -> cómo supo ->
    // cuánta química sabe -> meta diaria -> Notificaciones -> la
    // racha -> aviso "¡No pierdas tu progreso!" -> Registro. En
    // Notificaciones el permiso está negado en pruebas: sale "Ir a
    // Ajustes" y al cerrarlo se avanza a la racha.
    await tester.tap(find.text(tr('obContinue').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obCreateProfile').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obVamos').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obSourceInstagram')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obContinue').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obLevel1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obContinue').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obGoal10')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obGoalSave').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obNotifEnable').toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text('Ir a Ajustes'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obStreakStart').toUpperCase()));
    await tester.pumpAndSettle();
    // Aviso "¡No pierdas tu progreso!" (Duolingo) antes del registro.
    expect(find.text(tr('obNudgeTitle')), findsOneWidget);
    await tester.tap(find.text(tr('obContinue').toUpperCase()));
    await tester.pumpAndSettle();
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

    testWidgets(
        'idioma del sistema: sin idioma guardado coge el del teléfono; '
        'si no está soportado, español', (tester) async {
      // Quemia 7.7 (Kristian 2026-11-13): la app ya no pide el idioma
      // al instalar; lo coge del sistema. El idioma guardado manda
      // siempre (eso se prueba en AppLang.load, no aquí).
      final binding = tester.binding;
      binding.platformDispatcher.localeTestValue = const Locale('en', 'US');
      addTearDown(binding.platformDispatcher.clearLocaleTestValue);
      expect(AppLang.systemLanguage(), 'en');
      binding.platformDispatcher.localeTestValue = const Locale('fr', 'FR');
      expect(AppLang.systemLanguage(), 'fr');
      binding.platformDispatcher.localeTestValue = const Locale('de', 'DE');
      expect(AppLang.systemLanguage(), 'es');
      binding.platformDispatcher.localeTestValue = const Locale('pt', 'BR');
      expect(AppLang.systemLanguage(), 'pt');
      // load() con idioma guardado usa el guardado, no el sistema.
      AppLang.code = 'es';
      UserPrefs.languageSet = true;
      UserPrefs.language = 'es';
      await AppLang.load();
      expect(AppLang.code, 'es');
      UserPrefs.languageSet = false;
    });
  });

  group('tabla de posiciones', () {
    testWidgets('ordena por puntos desc y pone laureles a los 3 primeros',
        (tester) async {
      await pumpLeaderboard(tester,
          stream: Stream.value(sampleEntries()), currentDeviceId: 'd-me');
      // Orden: brenda (320), kristian (280), britany (210), carlos (150).
      final yBrenda = tester.getCenter(find.text('brenda')).dy;
      final yKristian = tester.getCenter(find.text('kristian (tú)')).dy;
      final yBritany = tester.getCenter(find.text('britany')).dy;
      final yCarlos = tester.getCenter(find.text('carlos')).dy;
      expect(yBrenda, lessThan(yKristian));
      expect(yKristian, lessThan(yBritany));
      expect(yBritany, lessThan(yCarlos));
      // Laureles oro/plata/bronce en los puestos 1-3 (solo el
      // laurel, sin avatar ni corona), nada en el 4.
      expect(
          find.byKey(const ValueKey('leaderboard-laurel-1')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('leaderboard-laurel-2')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('leaderboard-laurel-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('leaderboard-medal-1')), findsNothing);
      expect(find.byKey(const ValueKey('leaderboard-medal-2')), findsNothing);
      expect(find.byKey(const ValueKey('leaderboard-medal-3')), findsNothing);
      expect(find.byKey(const ValueKey('leaderboard-medal-4')), findsNothing);
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

    testWidgets('vacía: "Sé el primero..." y pull-to-refresh', (tester) async {
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
      expect(tester.getCenter(find.text('brenda')).dy,
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
      expect(tester.getCenter(find.text('nuevo')).dy,
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
      expect(find.byKey(const ValueKey('nav-center-levels')), findsOneWidget);
      final circle = find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == const Color(0xFF00C2A8) &&
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
      expect(find.byKey(const ValueKey('nav-center-levels')), findsOneWidget);
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
      // (2026-11-16, perfil estilo Duolingo) "Vincular con Google"
      // ya NO está en Cuenta: vive en Ajustes, sección CUENTA.
      // (2026-11-16) En Cuenta quedan 7 filas: Estadísticas,
      // Amigos, Tabla de posiciones, Torneo, Tienda, Premium y
      // Canjear código. Tienda y Premium volvieron de Ajustes
      // (Kristian 2026-11-16). Se bombea CON sesión: Amigos,
      // Tabla y Torneo solo salen con sesión (un invitado no ve
      // lo de buscar otra gente). El falso necesita uid (si no,
      // currentUser es null y no hay sesión aunque googleLinked
      // sea true).
      fakeAuth.uid = 'fake-uid';
      fakeAuth.googleLinked = true;
      await pumpAccount(tester);
      expect(find.text(tr('accountLeaderboard')), findsOneWidget);
      expect(find.text(tr('accountLinkGoogle')), findsNothing);
      expect(find.text('Recuperar mi progreso'), findsNothing);
      // Orden: Estadísticas, Amigos, Tabla, Torneo, Tienda,
      // Premium, Canjear. Idioma ya no está en Cuenta: vive en
      // Ajustes.
      final yStats = tester.getCenter(find.text(tr('accountStats'))).dy;
      final yFriends = tester.getCenter(find.text(tr('accountFriends'))).dy;
      final yLeaderboard =
          tester.getCenter(find.text(tr('accountLeaderboard'))).dy;
      final yTournaments =
          tester.getCenter(find.text(tr('accountTournaments'))).dy;
      final yShop = tester.getCenter(find.text(tr('accountShop'))).dy;
      final yPremium = tester.getCenter(find.text(tr('accountPremium'))).dy;
      final yRedeem = tester.getCenter(find.text(tr('accountRedeem'))).dy;
      expect(yStats, lessThan(yFriends));
      expect(yFriends, lessThan(yLeaderboard));
      expect(yLeaderboard, lessThan(yTournaments));
      expect(yTournaments, lessThan(yShop));
      expect(yShop, lessThan(yPremium));
      expect(yPremium, lessThan(yRedeem));
      expect(find.text(tr('accountLanguage')), findsNothing);
      // Referidos sigue en Ajustes (no volvió con Tienda/Premium).
      expect(find.text(tr('accountReferrals')), findsNothing);
    });

    testWidgets('"Tabla de posiciones" abre la pantalla de leaderboard',
        (tester) async {
      // La fila solo sale con sesión (un invitado no ve lo de
      // buscar otra gente).
      fakeAuth.uid = 'fake-uid';
      fakeAuth.googleLinked = true;
      final opened = await pumpAccount(tester);
      await tester.tap(find.text(tr('accountLeaderboard')));
      await tester.pump();
      expect(opened, ['leaderboard']);
    });

    testWidgets(
        '"Vincular con Google" sin vincular enlaza y muestra el correo',
        (tester) async {
      // 2026-11-16: la fila vive en Ajustes (sección CUENTA).
      fakeAuth.email = 'kristian@example.com';
      fakeAuth.displayName = 'Kristian';
      await pumpSettings(tester);
      expect(find.text(tr('accountLinkGoogleSub')), findsOneWidget);
      await tester.tap(find.text(tr('accountLinkGoogle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(AuthService.isGoogleLinked, isTrue);
      expect(find.text('kristian@example.com'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('vinculada: la fila muestra el correo y ofrece desvincular',
        (tester) async {
      // 2026-11-16: la fila vive en Ajustes (sección CUENTA).
      fakeAuth.googleLinked = true;
      // Sin uid no hay sesión (currentUser == null) y la fila no
      // muestra nada: la cuenta vinculada es una sesión.
      fakeAuth.uid = 'fake-google-uid';
      fakeAuth.email = 'kristian@example.com';
      fakeAuth.displayName = 'Kristian';
      await pumpSettings(tester);
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
      // 2026-11-16 (perfil estilo Duolingo): tocar Cuenta ABRE
      // OTRA PANTALLA (AccountProfilePage), sin navbar; la pestaña
      // de abajo se queda en la anterior (Tabla).
      expect(find.byType(AccountProfilePage), findsOneWidget);
      expect(find.byType(AccountScreen), findsOneWidget);
      expect(find.byType(MainBottomNav), findsNothing);
      // La X cierra el perfil y vuelve a la app.
      await tester.tap(find.byKey(const ValueKey('accountCloseButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AccountProfilePage), findsNothing);
      // Volver a Niveles por el círculo central.
      await tester.tap(find.byKey(const ValueKey('nav-center-levels')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PracticarScreen), findsOneWidget);
    });

    testWidgets('el menú tiene la tabla y la abre', (tester) async {
      // El menú solo enseña la tabla con sesión (un invitado no
      // ve lo de buscar otra gente). Con contraseña puesta
      // (emailLinked): si no, HomeScreen programa el
      // recordatorio de contraseña y su timeout de 3 s para
      // copiar el icono queda pendiente en la zona falsa y el
      // test falla por temporizador (no por la app: en el
      // teléfono real ese timeout se resuelve solo).
      fakeAuth.uid = 'fake-uid';
      fakeAuth.googleLinked = true;
      fakeAuth.emailLinked = true;
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
    testWidgets('el registro es Google y correo, sin nombre ni género',
        (tester) async {
      await goToRegisterPage(tester);
      expect(find.text(tr('obRegisterTitle')), findsOneWidget);
      await tester
          .ensureVisible(find.text(tr('obRegisterGoogle').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obRegisterGoogle').toUpperCase()), findsOneWidget);
      expect(find.text(tr('obRegisterEmail').toUpperCase()), findsOneWidget);
      // La G de Google es el icono en colores, no un texto 'G'.
      expect(find.byType(GoogleGIcon), findsOneWidget);
      // Nada de campo de nombre ni de género (Kristian 2026-11-13).
      expect(find.byType(TextField), findsNothing);
      expect(find.text(tr('obFemale')), findsNothing);
      expect(find.text(tr('obMale')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('al tocar Google, va directo al referido sin pantalla '
        'de usuario', (tester) async {
      // (2026-11-16, lote de perfil: Kristian REVIRTIÓ su orden del
      // 2026-11-15) La pantalla "Elige tu nombre de usuario" YA NO
      // está en el registro: tras Google se va directo al referido
      // y el nombre se pone después, en Cuenta ("¡Completa tu
      // perfil!"). El nombre NO se reclama aquí.
      fakeAuth.displayName = 'Kristian';
      fakeAuth.email = 'kristian@example.com';
      await goToRegisterPage(tester);
      await tester
          .ensureVisible(find.text(tr('obRegisterGoogle').toUpperCase()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obRegisterGoogle').toUpperCase()));
      // El enlace completa (fakeAuth rápido) sin dejar que dispare
      // el avance automático de 1,5 s del flujo de Google: estos
      // pumps no avanzan el reloj hasta 1,5 s.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(AuthService.isGoogleLinked, isTrue);
      // Flujo de Google, paso 0 ("Ya has iniciado sesión"): el
      // nombre de Google se muestra como texto.
      expect(find.text('Kristian'), findsOneWidget);
      // Avance automático al referido (paso 1): se adelanta el
      // reloj 1,6 s (el temporizador es de 1,5 s). SIN pantalla de
      // usuario de por medio; el género no se pregunta.
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();
      expect(find.text(tr('obUsernameTitle')), findsNothing);
      expect(find.text(tr('obReferralTitle')), findsOneWidget);
      expect(UserPrefs.publicUsername, '');
      expect(tester.takeException(), isNull);
    });
  });

  group('onboarding: registro por correo + OTP + inicio de sesión', () {
    late FakeOtpTransport fakeOtp;

    setUp(() {
      fakeOtp = FakeOtpTransport();
      OtpService.setTransportForTests(fakeOtp);
    });

    tearDown(() {
      OtpService.resetForTests();
    });

    Future<void> enterHint(
        WidgetTester tester, String hint, String text) async {
      await tester.enterText(
        find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.hintText == hint),
        text,
      );
      await tester.pumpAndSettle();
    }

    Future<void> enterOtp(WidgetTester tester, String code) async {
      final boxes = find.byType(TextField);
      expect(boxes, findsNWidgets(6));
      for (var i = 0; i < 6; i++) {
        await tester.enterText(boxes.at(i), code[i]);
      }
      await tester.pumpAndSettle();
    }

    /// Camina el flujo del correo hasta la pantalla del OTP
    /// (correo -> contraseña -> nombre -> CREA TU PERFIL).
    Future<void> goToOtpStep(WidgetTester tester) async {
      await goToRegisterPage(tester);
      await tester.tap(find.text(tr('obRegisterEmail').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obEmailTitle')), findsOneWidget);
      await enterHint(tester, tr('obEmailFieldHint'), 'jorge@example.com');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obPasswordTitle')), findsOneWidget);
      await enterHint(tester, tr('obPasswordHint'), 'Secreto123!');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obNameTitle')), findsOneWidget);
      await enterHint(tester, tr('obFirstNameHint'), 'Jorge');
      await enterHint(tester, tr('obLastNameHint'), 'Pozo');
      await tester.tap(find.text(tr('obCreateProfile').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obOtpTitle')), findsOneWidget);
    }

    testWidgets('correo -> contraseña -> nombre -> OTP -> referido',
        (tester) async {
      await goToOtpStep(tester);
      // El falso manda '123456' al correo.
      expect(
          fakeOtp.lastCode('jorge@example.com', OtpPurpose.register), '123456');
      await enterOtp(tester, '123456');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      // La cuenta quedó enlazada y se va DIRECTO al referido
      // (2026-11-16: la pantalla de elegir usuario ya no está en
      // el registro; el nombre se pone después, en Cuenta).
      expect(AuthService.isEmailLinked, isTrue);
      expect(find.text(tr('obUsernameTitle')), findsNothing);
      expect(find.text(tr('obReferralTitle')), findsOneWidget);
      expect(UserPrefs.publicUsername, '');
      expect(tester.takeException(), isNull);
    });

    testWidgets('OTP incorrecto: error y no se avanza', (tester) async {
      await goToOtpStep(tester);
      await enterOtp(tester, '000000');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obOtpInvalid')), findsOneWidget);
      expect(find.text(tr('obOtpTitle')), findsOneWidget);
      expect(AuthService.isEmailLinked, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'correo ya tomado (enlace tardío): pantalla entera y "Entrar" abre el inicio con el correo puesto',
        (tester) async {
      // La cuenta ya existe con OTRA contraseña: el enlace falla y
      // el motivo que queda es que el correo ya está tomado. El
      // índice no tiene ese correo, así que no se sabe si tiene
      // contraseña: lo seguro es ofrecer entrar, nunca ponerle una.
      fakeAuth.simulateEmailAlreadyInUse = true;
      fakeAuth.emailAccounts['jorge@example.com'] = 'OtraClave9!';
      await goToOtpStep(tester);
      await enterOtp(tester, '123456');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      // Pantalla entera (Kristian 2026-11-15), no un cuadradito.
      expect(find.text(tr('obTakenTitle')), findsOneWidget);
      expect(find.text(tr('obTakenUnknownBody')), findsOneWidget);
      expect(find.text('jorge@example.com'), findsOneWidget);
      expect(find.text(tr('obTakenSetPassword').toUpperCase()), findsNothing);
      expect(find.text(tr('obTakenSignIn').toUpperCase()), findsOneWidget);
      expect(find.text(tr('obEmailTakenGoogle').toUpperCase()), findsOneWidget);
      expect(AuthService.isEmailLinked, isFalse);
      await tester.tap(find.text(tr('obTakenSignIn').toUpperCase()));
      await tester.pumpAndSettle();
      // El inicio de sesión trae el correo ya puesto.
      expect(find.text(tr('obSignInTitle')), findsOneWidget);
      expect(find.text('jorge@example.com'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('correo ya tomado: "Entrar con Google" entra con esa cuenta',
        (tester) async {
      fakeAuth.simulateEmailAlreadyInUse = true;
      fakeAuth.emailAccounts['jorge@example.com'] = 'OtraClave9!';
      fakeAuth.displayName = 'Jorge';
      await goToOtpStep(tester);
      await enterOtp(tester, '123456');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obTakenTitle')), findsOneWidget);
      await tester.tap(find.text(tr('obEmailTakenGoogle').toUpperCase()));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      // Se entró con Google: el flujo corto muestra el nombre.
      expect(AuthService.isGoogleLinked, isTrue);
      expect(find.text('Jorge'), findsOneWidget);
      // El avance automático de 1,5 s del flujo de Google: se
      // adelanta el reloj para que no quede un temporizador
      // pendiente y se avanza DIRECTO al referido (2026-11-16:
      // sin pantalla de usuario en el registro).
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();
      expect(find.text(tr('obUsernameTitle')), findsNothing);
      expect(find.text(tr('obReferralTitle')), findsOneWidget);
      expect(UserPrefs.publicUsername, '');
      expect(tester.takeException(), isNull);
    });

    testWidgets('si el código no se manda: error claro, sin colgarse',
        (tester) async {
      fakeOtp.failSend = true;
      await goToRegisterPage(tester);
      await tester.tap(find.text(tr('obRegisterEmail').toUpperCase()));
      await tester.pumpAndSettle();
      await enterHint(tester, tr('obEmailFieldHint'), 'jorge@example.com');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      await enterHint(tester, tr('obPasswordHint'), 'Secreto123!');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      await enterHint(tester, tr('obFirstNameHint'), 'Jorge');
      await enterHint(tester, tr('obLastNameHint'), 'Pozo');
      await tester.tap(find.text(tr('obCreateProfile').toUpperCase()));
      await tester.pumpAndSettle();
      // Sigue en el nombre, con el error (la función OTP no está
      // desplegada todavía: el falso simula ese fallo).
      expect(find.text(tr('obOtpNotSent')), findsOneWidget);
      expect(find.text(tr('obNameTitle')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la contraseña débil no deja continuar: se ven las 5 reglas',
        (tester) async {
      await goToRegisterPage(tester);
      await tester.tap(find.text(tr('obRegisterEmail').toUpperCase()));
      await tester.pumpAndSettle();
      await enterHint(tester, tr('obEmailFieldHint'), 'jorge@example.com');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obPasswordTitle')), findsOneWidget);
      // Débil: minúsculas y números, sin mayúscula ni especial
      // (Kristian 2026-11-13: nada de contraseñas fáciles).
      await enterHint(tester, tr('obPasswordHint'), 'secreto123');
      expect(find.text(tr('obPasswordReqLength')), findsOneWidget);
      expect(find.text(tr('obPasswordReqUpper')), findsOneWidget);
      expect(find.text(tr('obPasswordReqLower')), findsOneWidget);
      expect(find.text(tr('obPasswordReqNumber')), findsOneWidget);
      expect(find.text(tr('obPasswordReqSpecial')), findsOneWidget);
      // CONTINUAR no avanza: se sigue en la contraseña.
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obPasswordTitle')), findsOneWidget);
      expect(find.text(tr('obNameTitle')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la contraseña fuerte sí deja continuar', (tester) async {
      await goToRegisterPage(tester);
      await tester.tap(find.text(tr('obRegisterEmail').toUpperCase()));
      await tester.pumpAndSettle();
      await enterHint(tester, tr('obEmailFieldHint'), 'jorge@example.com');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      await enterHint(tester, tr('obPasswordHint'), 'Secreto123!');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obNameTitle')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'inicio de sesión con correo va directo a la principal sin preguntas',
        (tester) async {
      fakeAuth.emailAccounts['jorge@example.com'] = 'Secreto123!';
      var finished = false;
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onFinished: () => finished = true)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obEnterAccount')));
      await tester.pumpAndSettle();
      expect(find.text(tr('obSignInTitle')), findsOneWidget);
      await enterHint(tester, tr('obEmailHint'), 'jorge@example.com');
      await enterHint(tester, tr('obPasswordHint'), 'Secreto123!');
      await tester.tap(find.text(tr('obSignInButton').toUpperCase()));
      await tester.pumpAndSettle();
      // Entrar con la cuenta (Kristian 2026-11-15): va directo
      // a la principal, sin preguntas. Las preguntas quedan
      // solo en crear cuenta.
      expect(finished, isTrue);
      expect(find.text(tr('obSourceTitle')), findsNothing);
      expect(find.text(tr('obLevelTitle')), findsNothing);
      expect(find.text(tr('obGoalTitle')), findsNothing);
      expect(find.text(tr('obNotifTitle')), findsNothing);
      expect(UserPrefs.userName, 'Jorge');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'inicio de sesión con Google va directo a la principal sin preguntas',
        (tester) async {
      fakeAuth.displayName = 'Kristian';
      fakeAuth.email = 'kristian@example.com';
      var finished = false;
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onFinished: () => finished = true)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obEnterAccount')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obSignInWithGoogle').toUpperCase()));
      // El enlace completa (fakeAuth rápido) sin dejar que dispare
      // el avance automático de 1,5 s: estos pumps no avanzan el
      // reloj hasta 1,5 s.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(AuthService.isGoogleLinked, isTrue);
      // "Ya has iniciado sesión" con el nombre de Google.
      expect(find.text('Kristian'), findsOneWidget);
      // Avance automático (1,5 s): desde entrar NO pide referido
      // ni preguntas — va directo a la principal.
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();
      expect(finished, isTrue);
      expect(find.text(tr('obReferralTitle')), findsNothing);
      expect(find.text(tr('obSourceTitle')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('inicio de sesión con contraseña mala: error, sin entrar',
        (tester) async {
      fakeAuth.emailAccounts['jorge@example.com'] = 'Secreto123!';
      var finished = false;
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onFinished: () => finished = true)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obEnterAccount')));
      await tester.pumpAndSettle();
      await enterHint(tester, tr('obEmailHint'), 'jorge@example.com');
      await enterHint(tester, tr('obPasswordHint'), 'otra123');
      await tester.tap(find.text(tr('obSignInButton').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obSignInFailed')), findsOneWidget);
      expect(finished, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('olvidó la contraseña: correo -> enlace de Firebase',
        (tester) async {
      var finished = false;
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onFinished: () => finished = true)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obEnterAccount')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obForgotPassword').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obResetTitle')), findsOneWidget);
      await enterHint(tester, tr('obEmailFieldHint'), 'jorge@example.com');
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      // Confirmación del enlace + el falso registró el envío.
      expect(find.text(tr('obResetLinkSent')), findsOneWidget);
      expect(find.text('jorge@example.com'), findsOneWidget);
      expect(fakeAuth.resetEmailsSent, contains('jorge@example.com'));
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      // Vuelve al inicio de sesión con el mensaje de éxito.
      expect(find.text(tr('obSignInTitle')), findsOneWidget);
      expect(find.text(tr('obResetLinkSent')), findsOneWidget);
      expect(finished, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('onboarding: inicio rediseñado (bienvenida -> elección)', () {
    Future<void> goToChoicePage(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onFinished: () {})),
      );
      await tester.pumpAndSettle();
      // La primera pantalla es la Bienvenida (sin barra de progreso
      // y sin pantalla de idioma): su botón es "Continuar".
      expect(find.text(tr('obWelcome')), findsOneWidget);
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obChoiceTitle')), findsOneWidget);
    }

    testWidgets('la elección ofrece los 3 caminos', (tester) async {
      await goToChoicePage(tester);
      expect(find.text(tr('obCreateProfile').toUpperCase()), findsOneWidget);
      expect(find.text(tr('obEnterAccount')), findsOneWidget);
      expect(find.text(tr('obOffline').toUpperCase()), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('crear perfil -> la gemela se presenta -> Vamos -> preguntas',
        (tester) async {
      await goToChoicePage(tester);
      await tester.tap(find.text(tr('obCreateProfile').toUpperCase()));
      await tester.pumpAndSettle();
      // Brenda se presenta en su bocadillo (no el búho de Duolingo).
      expect(find.text(tr('obBrendaHello')), findsOneWidget);
      expect(find.text(tr('obVamos').toUpperCase()), findsOneWidget);
      await tester.tap(find.text(tr('obVamos').toUpperCase()));
      await tester.pumpAndSettle();
      // "Vamos" lleva a las preguntas de crear cuenta (no al
      // Perfil directo): primero "¿Cómo supiste de Quemia?".
      expect(find.text(tr('obSourceTitle')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la flecha de la gemela vuelve a la elección', (tester) async {
      await goToChoicePage(tester);
      await tester.tap(find.text(tr('obCreateProfile').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obBrendaHello')), findsOneWidget);
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(find.text(tr('obChoiceTitle')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('invitado: nombre + meta diaria -> principal', (tester) async {
      var finished = false;
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onFinished: () => finished = true)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obOffline').toUpperCase()));
      await tester.pumpAndSettle();
      // Paso 1: solo el nombre (un campo, sin apellido ni correo).
      expect(find.text(tr('obNameTitle')), findsOneWidget);
      expect(finished, isFalse);
      await tester.enterText(
        find.byWidgetPredicate((w) =>
            w is TextField && w.decoration?.hintText == tr('obFirstNameHint')),
        'Jorge',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      // Paso 2: la meta diaria (10 min ya elegido por defecto).
      expect(find.text(tr('obGoalTitle')), findsOneWidget);
      await tester.tap(find.text(tr('obOfflineStart').toUpperCase()));
      await tester.pumpAndSettle();
      expect(finished, isTrue);
      expect(UserPrefs.onboardingDone, isTrue);
      expect(UserPrefs.userName, 'Jorge');
      expect(UserPrefs.dailyGoalMinutes, 10);
      expect(tester.takeException(), isNull);
    });
  });

  group('onboarding: pantalla de carga tras el inicio', () {
    testWidgets('muestra la animación y "Cargando…"', (tester) async {
      // Quemia 7.7 (Kristian 2026-11-14): después de pasar
      // cualquiera de las 3 formas de empezar se muestra la
      // animación de carga y al terminar se carga Niveles.
      tester.view.physicalSize = const Size(393 * 2, 852 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        const MaterialApp(home: LoadingScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text(tr('loading')), findsOneWidget);
      expect(find.byType(LoadingScreen), findsOneWidget);
    });
  });

  group(
      'onboarding: crear cuenta (cómo supo -> cuánto sabe -> meta -> '
      'notificaciones -> racha -> perfil)', () {
    Future<void> goToMascotPage(WidgetTester tester) async {
      // Superficie de teléfono (393x852, como el Redmi de Kristian):
      // a 800x600 las 5 opciones del nivel no caben y la última no
      // se construye (ListView perezoso).
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
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obCreateProfile').toUpperCase()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obVamos').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obSourceTitle')), findsOneWidget);
    }

    testWidgets('las 3 preguntas se guardan y el flujo llega al perfil',
        (tester) async {
      await goToMascotPage(tester);
      // 1) "¿Cómo supiste de Quemia?": sin elegir, el botón está
      // deshabilitado y no se avanza (el toque no llega a nada).
      await tester.tap(find.text(tr('obContinue').toUpperCase()),
          warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text(tr('obSourceTitle')), findsOneWidget);
      await tester.tap(find.text(tr('obSourceInstagram')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      expect(UserPrefs.heardFrom, 'instagram');
      // 2) "¿Cuánta química sabes?": 5 niveles con barritas.
      expect(find.text(tr('obLevelTitle')), findsOneWidget);
      expect(find.text(tr('obLevel0')), findsOneWidget);
      expect(find.text(tr('obLevel4')), findsOneWidget);
      await tester.tap(find.text(tr('obLevel2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      expect(UserPrefs.chemLevel, 2);
      // 3) Meta diaria: 4 opciones (3/10/15/30); por defecto 10.
      expect(find.text(tr('obGoalTitle')), findsOneWidget);
      expect(find.text(tr('obGoal3')), findsOneWidget);
      expect(find.text(tr('obGoal30')), findsOneWidget);
      await tester.tap(find.text(tr('obGoal15')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obGoalSave').toUpperCase()));
      await tester.pumpAndSettle();
      expect(UserPrefs.dailyGoalMinutes, 15);
      // 4) Notificaciones (la misma página de siempre): el permiso
      // está negado en pruebas, sale "Ir a Ajustes" y al cerrarlo
      // se avanza a la racha (ya NO termina el flujo aquí).
      expect(find.text(tr('obNotifEnable').toUpperCase()), findsOneWidget);
      await tester.tap(find.text(tr('obNotifEnable').toUpperCase()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      // 5) "¡Una nueva racha!": número gigante + "día de racha",
      // la semana con hoy marcado (naranja con ✓).
      expect(find.text(tr('obStreakTitle')), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text(tr('obStreakDayLabel')), findsOneWidget);
      final todayLetter = tr([
        'obDayMon',
        'obDayTue',
        'obDayWed',
        'obDayThu',
        'obDayFri',
        'obDaySat',
        'obDaySun',
      ][DateTime.now().weekday - 1]);
      expect(find.text(todayLetter), findsWidgets);
      await tester.tap(find.text(tr('obStreakStart').toUpperCase()));
      await tester.pumpAndSettle();
      // 6) Aviso "¡No pierdas tu progreso!" y 7) Registro (Google
      // y correo, como Duolingo; sin nombre ni género y sin edad).
      expect(find.text(tr('obNudgeTitle')), findsOneWidget);
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obRegisterTitle')), findsOneWidget);
      expect(find.text(tr('obRegisterGoogle').toUpperCase()), findsOneWidget);
      expect(find.text(tr('obRegisterEmail').toUpperCase()), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'la elección "ya tengo una cuenta" abre el inicio de sesión: '
        'sin campos en la elección, sin Facebook', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onFinished: () {})),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obContinue').toUpperCase()));
      await tester.pumpAndSettle();
      // Solo el botón "Entrar con mi cuenta": ningún campo de
      // correo / contraseña ni botón de Facebook en la elección.
      expect(find.text(tr('obEnterAccount')), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('Facebook'), findsNothing);
      expect(find.textContaining('contraseña'), findsNothing);
      // Al tocarlo se abre "Ingresa tus datos" (Duolingo): correo
      // + contraseña, "¿Has olvidado tu contraseña?" y Google.
      await tester.tap(find.text(tr('obEnterAccount')));
      await tester.pumpAndSettle();
      expect(find.text(tr('obSignInTitle')), findsOneWidget);
      expect(find.text(tr('obForgotPassword').toUpperCase()), findsOneWidget);
      expect(find.text(tr('obSignInWithGoogle').toUpperCase()), findsOneWidget);
      expect(find.textContaining('Facebook'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'desde Cuenta: empieza en la elección, sin "sin '
        'conexión", con "Volver" que cancela', (tester) async {
      var cancelled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(
            fromAccount: true,
            onFinished: () {},
            onCancel: () => cancelled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Empieza directo en la elección (sin Bienvenida).
      expect(find.text(tr('obChoiceTitle')), findsOneWidget);
      expect(find.text(tr('obWelcome')), findsNothing);
      // "Sin conexión" no sale (ya está sin conexión): sale Volver.
      expect(find.text(tr('obOffline').toUpperCase()), findsNothing);
      expect(find.text(tr('obBack').toUpperCase()), findsOneWidget);
      await tester.tap(find.text(tr('obBack').toUpperCase()));
      await tester.pumpAndSettle();
      expect(cancelled, isTrue);
      expect(tester.takeException(), isNull);
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
          stream: Stream<List<LeaderboardEntry>>.error(StateError('sin red')),
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
      expect(
          find.byKey(const ValueKey('leaderboard-laurel-1')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('leaderboard-laurel-2')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('leaderboard-laurel-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('social-avatar-brenda')), findsNothing);
      expect(
          find.byKey(const ValueKey('social-avatar-kristian')), findsNothing);
      expect(find.byKey(const ValueKey('social-avatar-britany')), findsNothing);
      // El 4º sí lleva su avatar de inicial con su marco de rango.
      expect(
          find.byKey(const ValueKey('social-avatar-carlos')), findsOneWidget);
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
    testWidgets('Ajustes sin internet: una sola línea, sin diálogo',
        (tester) async {
      // El enlace falla (sin red) y Firebase no está listo.
      // 2026-11-16: la fila "Vincular con Google" vive en
      // Ajustes, sección CUENTA (antes en Cuenta).
      fakeAuth.failAnonymous = true;
      final opened = await pumpSettings(tester);
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

    testWidgets('Ajustes con Firebase listo y fallo: mensaje de sesión',
        (tester) async {
      // 2026-11-16: la fila "Vincular con Google" vive en Ajustes.
      fakeAuth.failAnonymous = true;
      AnalyticsSync.markFirebaseReady();
      await pumpSettings(tester);
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
      await goToRegisterPage(tester);
      await tester
          .ensureVisible(find.text(tr('obRegisterGoogle').toUpperCase()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obRegisterGoogle').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('googleNeedInternet')), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      // El botón de Google sigue habilitado: se puede reintentar
      // (hay DOS DuoButton con etiqueta vacía — Google y correo —;
      // el de Google es el primero).
      final button = tester.widget<DuoButton>(
          find.byWidgetPredicate((w) => w is DuoButton && w.label == '').first);
      expect(button.onPressed, isNotNull);
      // Reintento: sigue sin colgarse ni duplicar el error.
      await tester.tap(find.text(tr('obRegisterGoogle').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('googleNeedInternet')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('onboarding con Firebase listo y fallo: mensaje de sesión',
        (tester) async {
      fakeAuth.failAnonymous = true;
      AnalyticsSync.markFirebaseReady();
      await goToRegisterPage(tester);
      await tester
          .ensureVisible(find.text(tr('obRegisterGoogle').toUpperCase()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obRegisterGoogle').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('googleSignInFailed')), findsOneWidget);
      expect(find.text(tr('googleNeedInternet')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('onboarding en carga: botón deshabilitado con spinner',
        (tester) async {
      final slow = _SlowFakeAuth();
      AuthService.setProviderForTests(slow);
      await goToRegisterPage(tester);
      await tester
          .ensureVisible(find.text(tr('obRegisterGoogle').toUpperCase()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('obRegisterGoogle').toUpperCase()));
      await tester.pump();
      // En carga: deshabilitado y con spinner; sin error (el botón
      // de Google es el primero de los dos DuoButton con etiqueta
      // vacía — Google y correo).
      var button = tester.widget<DuoButton>(
          find.byWidgetPredicate((w) => w is DuoButton && w.label == '').first);
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(tr('googleNeedInternet')), findsNothing);
      // Segundo toque ignorado: solo una llamada al servicio.
      await tester.tap(find.text(tr('obRegisterGoogle').toUpperCase()),
          warnIfMissed: false);
      expect(slow.linkCalls, 1);
      // Completa con éxito: entra al flujo de Google y avanza solo
      // al referido (el paso 0 "Ya has iniciado sesión" dura
      // 1,5 s); de ahí a notificaciones con Continuar (2026-11-16:
      // sin pantalla de usuario en el registro; el género no se
      // pregunta).
      slow.googleLinked = true;
      slow.linkCompleter.complete(true);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();
      expect(find.text(tr('obUsernameTitle')), findsNothing);
      expect(find.text(tr('obReferralTitle')), findsOneWidget);
      await tester.tap(find.text(tr('obNext').toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(tr('obNotifEnable').toUpperCase()), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Ajustes en carga: "Vinculando…" y un solo intento',
        (tester) async {
      // 2026-11-16: la fila "Vincular con Google" vive en Ajustes.
      final slow = _SlowFakeAuth();
      AuthService.setProviderForTests(slow);
      await pumpSettings(tester);
      await tester.tap(find.text(tr('accountLinkGoogle')));
      await tester.pump();
      expect(find.text(tr('googleLinking')), findsOneWidget);
      await tester.tap(find.text(tr('accountLinkGoogle')), warnIfMissed: false);
      expect(slow.linkCalls, 1);
      slow.googleLinked = true;
      slow.linkCompleter.complete(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('lento@example.com'), findsOneWidget);
      expect(find.text(tr('googleLinking')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Ajustes sin perfil: la fila de Google abre el mismo '
        'flujo de inicio (elección, sin "sin conexión")', (tester) async {
      // Sin perfil local (entró "sin conexión"): el setUp de fix8
      // pone userName='kristian', así que se limpia aquí para
      // simular que no hay perfil guardado.
      // 2026-11-16: la fila "Vincular con Google" vive en Ajustes.
      UserPrefs.userName = '';
      UserPrefs.publicUsername = '';
      await pumpSettings(tester);
      await tester.tap(find.text(tr('accountLinkGoogle')));
      await tester.pumpAndSettle();
      // Empieza en la elección (crear perfil / entrar con Google).
      expect(find.text(tr('obChoiceTitle')), findsOneWidget);
      expect(find.text(tr('obCreateProfile').toUpperCase()), findsOneWidget);
      expect(find.text(tr('obEnterAccount')), findsOneWidget);
      // "Sin conexión" no sale (ya está sin conexión): sale Volver.
      expect(find.text(tr('obOffline').toUpperCase()), findsNothing);
      expect(find.text(tr('obBack').toUpperCase()), findsOneWidget);
      // Volver cierra el flujo y vuelve a Ajustes. Pumps explícitos
      // (no pumpAndSettle): tras el pop de ruta, pumpAndSettle no
      // termina en este árbol (como en el resto de tests de Ajustes,
      // que usan pump con duración).
      await tester.tap(find.text(tr('obBack').toUpperCase()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(tr('obChoiceTitle')), findsNothing);
      expect(find.text(tr('accountLinkGoogle')), findsOneWidget);
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
  String? get lastEmailError => null;

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
  Future<bool> linkWithEmail(String email, String password) async => false;

  @override
  Future<bool> linkPassword(String email, String password) async => false;

  @override
  Future<bool> signInWithEmail(String email, String password) async => false;

  @override
  Future<bool> sendPasswordResetEmail(String email) async => false;

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

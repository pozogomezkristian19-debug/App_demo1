// Vistas previas de la ronda #8 (Quemia 7.0). Se ejecuta con
// --update-goldens para ESCRIBIR los PNG en
// ~/workspace/melli-qui-v6-previews/ (nombres fix8_*). Viewport
// 393x852 (dpr 2), Roboto real + MaterialIcons reales. Las pantallas
// sueltas se montan con una réplica fiel del tema claro
// (melliLightTheme); la app real, con MelliQuiApp. Los PNG se leen
// y se verifican a mano antes de informar.
//
// - fix8_navbar: Niveles con la barra nueva (círculo central).
// - fix8_leaderboard: tabla con los 12 usuarios demo (laureles).
// - fix8_onboarding_google: perfil con "Continuar con Google".
// - fix8_onboarding_nombre: la pantalla del nombre y el género
//   rediseñada (diseño 7.0). La página de permiso de analítica se
//   quitó: compartir es automático, sin pregunta.
// - fix8_amigos: amigos + sección "Mis duelos" (retado) + sección
//   "Solicitudes" (ronda 2d: una entrante con Confirmar/Eliminar y
//   una enviada con "Solicitud enviada" + Cancelar).
// - fix8_duelo_espera: "Esperando a tu amigo…" tras jugar.
// - fix8_duelo_resultado: resultado con el ganador resaltado.
// - fix8_duelo_desconexion: "[nombre] perdió el internet" + opciones.
// - fix8_torneos: torneos activos y próximos.
// - fix8_tienda: tienda con 2000 puntos.
// - fix8_grupos: grupos con el grupo semilla.
// - fix8_tabla_vacia / fix8_amigos_vacios / fix8_torneos_vacios /
//   fix8_grupos_vacios: estados vacíos bonitos.
// - fix8_duelo_vacio: duelo al azar buscando rival.
// - fix8_puerta_tabla / fix8_puerta_duelo: puerta de Google.
// - fix8_torneo_sin_conexion: entregar sin internet (aviso tranquilo).
// - fix8_soporte: ventanita de Soporte con hilo respondido +
//   WhatsApp encendido (número remoto).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/duel_screen.dart';
import 'package:quimica_pura/screens/friends_screen.dart';
import 'package:quimica_pura/screens/groups_screen.dart';
import 'package:quimica_pura/screens/leaderboard_screen.dart';
import 'package:quimica_pura/screens/onboarding_screen.dart';
import 'package:quimica_pura/screens/shop_screen.dart';
import 'package:quimica_pura/screens/support_screen.dart';
import 'package:quimica_pura/screens/tournaments_screen.dart';
import 'package:quimica_pura/services/accent.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/social_service.dart';
import 'package:quimica_pura/services/support_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/brand_logo.dart';
import 'package:quimica_pura/widgets/twin_avatars.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'test_helpers.dart';

/// Réplica fiel del tema claro de MelliQuiApp (ver
/// preview_fix2_test.dart): teal #00C2A8 con acento Verde.
ThemeData melliLightTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.light(
        primary: AppAccent.primary,
        onPrimary: Colors.white,
        secondary:
            AppAccent.isViolet ? BrandColors.teal : BrandColors.violet,
        surface: Colors.white,
        onSurface: BrandColors.ink,
        surfaceContainerHighest: BrandColors.cardGray,
        error: const Color(0xFFEF4444),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: BrandColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: BrandColors.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.10),
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      // Como en el tema real: el Divider no es negro.
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE8E8E8),
        thickness: 1,
      ),
      // Estilos de botón REALES de la app (main.dart, tema claro):
      // píldora teal con borde inferior oscuro (efecto 3D) y
      // contorno blanco con borde teal de 2 px. Sin ellos, el
      // preview dibuja los botones morados por defecto de
      // Material 3 (ese era el "feo" de los previews de la 7.0).
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppAccent.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppAccent.primary.withValues(alpha: 0.40),
          elevation: 2,
          shadowColor: AppAccent.primaryDark,
          surfaceTintColor: Colors.transparent,
          shape: DuoPillBorder(edgeColor: AppAccent.primaryDark),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w800),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppAccent.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppAccent.primary.withValues(alpha: 0.40),
          elevation: 2,
          shadowColor: AppAccent.primaryDark,
          surfaceTintColor: Colors.transparent,
          shape: DuoPillBorder(edgeColor: AppAccent.primaryDark),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppAccent.primary,
          backgroundColor: Colors.white,
          side: BorderSide(color: AppAccent.primary, width: 2),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppAccent.primary,
          textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 15,
              fontWeight: FontWeight.w700),
        ),
      ),
      // Como en el tema real: interruptor teal, no violeta.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppAccent.primary
                : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppAccent.primary.withValues(alpha: 0.45)
                : Colors.black.withValues(alpha: 0.12)),
      ),
    );

/// Fake del plugin de notificaciones (mismo patrón que
/// preview_fix6_test.dart): permiso concedido, sin programar nada.
class _Fix8PreviewFake extends AndroidFlutterLocalNotificationsPlugin
    with MockPlatformInterfaceMixin {
  @override
  Future<bool> initialize({
    required AndroidInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
  }) async =>
      true;

  @override
  Future<bool?> requestNotificationsPermission() async => true;

  @override
  Future<bool?> requestExactAlarmsPermission() async => true;

  @override
  Future<bool?> areNotificationsEnabled() async => true;

  @override
  Future<bool?> openAppNotificationSettings() async => true;

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    String? payload,
    AndroidNotificationDetails? notificationDetails,
  }) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
    AndroidNotificationDetails? notificationDetails,
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.exact,
  }) async {}
}

/// Fake de SupportService para el preview de la ventanita: un hilo
/// respondido + uno abierto, y el interruptor de WhatsApp encendido
/// con un número remoto distinto del de por defecto.
class _PreviewSupportFake implements SupportService {
  final _messages = <SupportMessage>[
    SupportMessage(
      id: 'm1',
      authorUid: 'uid-kristian',
      username: 'kristian',
      message: 'No me sale el balanceo de la reacción del hierro',
      createdAt: DateTime(2026, 11, 11, 10, 0),
      status: 'respondido',
      reply: 'Revisa los coeficientes del oxígeno primero: ¡eso lo '
          'destraba casi siempre!',
      replyAt: DateTime(2026, 11, 11, 11, 0),
    ),
    SupportMessage(
      id: 'm2',
      authorUid: 'uid-kristian',
      username: 'kristian',
      message: 'Hola, ¿cuándo hay torneo nuevo?',
      createdAt: DateTime(2026, 11, 11, 9, 30),
      status: 'abierto',
    ),
  ];

  @override
  Future<bool> sendMessage(String text) async {
    _messages.insert(
      0,
      SupportMessage(
        id: 'm${_messages.length}',
        authorUid: 'uid-kristian',
        username: 'kristian',
        message: text,
        createdAt: DateTime.now(),
        status: 'abierto',
      ),
    );
    return true;
  }

  @override
  Future<List<SupportMessage>> fetchMyMessages() async =>
      List.unmodifiable(_messages);

  @override
  Stream<List<SupportMessage>> watchMyMessages() async* {
    yield List.unmodifiable(_messages);
  }

  @override
  Future<SupportSettings> fetchSupportSettings() async =>
      const SupportSettings(
          supportNumber: '+53 5 9999999', showWhatsApp: true);

  @override
  Future<List<SupportMessage>> pendingMessages() async => const [];

  @override
  Future<int> pendingCount() async => 0;

  @override
  void listenForReplies() {}

  @override
  Future<void> checkRepliesNow() async {}

  @override
  Future<int> retryPendingSupport() async => 0;

  @override
  void resetForTests() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadRobotoFonts();
    await loadMaterialIcons();
    // La app completa usa Nunito: sin cargarla, la captura de la
    // barra inferior sale con el texto en bloques sólidos y no se
    // puede leer (mismo cambio que en preview_fix6_test).
    await loadNunitoFonts();
  });

  late InMemorySocialRepository repo;

  setUp(() async {
    // La frase de la burbuja de la mascota rota con un estado
    // global: sin reiniciarla, el golden depende de qué tests
    // corrieron antes en el mismo proceso.
    resetMascotLineRotationForTesting();
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (call) async => 'America/Havana',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (call.method == 'getTemporaryDirectory') return '/tmp';
        return null;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.melliqui/battery_settings'),
      (call) async {
        if (call.method == 'isIgnoringBatteryOptimizations') return false;
        return true;
      },
    );
    FlutterLocalNotificationsPlatform.instance = _Fix8PreviewFake();
    UserPrefs.rulesSeenV6 = true;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    await UserPrefs.saveThemeMode('claro');
    UserPrefs.isDark = false;
    UserPrefs.onboardingDone = true;
    UserPrefs.userName = 'kristian';
    repo = InMemorySocialRepository(seedDemo: true);
    SocialService.setRepositoryForTests(repo);
    AnalyticsSync.resetForTests();
    // La tabla real está "lista": con lista vacía se ve el estado
    // vacío bonito, no el de sin conexión.
    AnalyticsSync.markFirebaseReady();
  });

  tearDown(() {
    SocialService.resetForTests();
    AnalyticsSync.resetForTests();
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = false;
    UserPrefs.isDark = false;
    UserPrefs.userName = '';
  });

  Future<void> setPhone(
    WidgetTester tester, {
    double width = 393,
    double height = 852,
  }) async {
    tester.view.physicalSize = Size(width * 2, height * 2);
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

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
  }

  /// Tres pumps: los streams sociales pasan por dos controladores
  /// asíncronos, así que un evento necesita más de un frame.
  Future<void> socialSettle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Precarga las imágenes de los compañeros. OJO: sin runAsync la
  /// decodificación real del motor nunca completa sobre la caché
  /// fría y el test se queda colgado (diag2: 90 s sin avanzar) —
  /// fix6 lo evita con su test warm-up previo; aquí se hace dentro
  /// del propio helper.
  Future<void> warmCompanions(WidgetTester tester) async {
    final ctx = tester.element(find.byType(MaterialApp));
    for (final c in Companion.values) {
      await tester.runAsync(() async {
        await precacheImage(AssetImage(companionAsset(c)), ctx);
      });
    }
    await tester.pump();
  }

  /// Precarga las imágenes del podio (los laureles de oro/plata/
  /// bronce que envió Kristian) y la G de Google. Igual que
  /// warmCompanions: sin runAsync la decodificación real nunca
  /// completa sobre la caché fría y las imágenes salen en blanco
  /// en la captura.
  Future<void> warmLaurels(WidgetTester tester) async {
    final ctx = tester.element(find.byType(MaterialApp));
    for (final asset in [
      'assets/laurel_oro.png',
      'assets/laurel_plata.png',
      'assets/laurel_bronce.png',
      'assets/google_g.png',
    ]) {
      await tester.runAsync(() async {
        await precacheImage(AssetImage(asset), ctx);
      });
    }
    await tester.pump();
  }

  /// Precarga las fotos de avatar premium de la tienda (ronda 2e).
  /// Igual que warmLaurels: sin runAsync las imágenes salen en
  /// blanco en la captura.
  Future<void> warmAvatars(WidgetTester tester) async {
    final ctx = tester.element(find.byType(MaterialApp));
    for (final asset in [
      'assets/avatar_dorado.png',
      'assets/avatar_violeta.png',
      'assets/avatar_teal.png',
    ]) {
      await tester.runAsync(() async {
        await precacheImage(AssetImage(asset), ctx);
      });
    }
    await tester.pump();
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
  }

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: melliLightTheme(),
        home: screen,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Responde bien las 5 preguntas del duelo/torneo (flujo
  /// original: tocar la opción la juzga al momento; SIGUIENTE o
  /// RESULTADO avanza).
  Future<void> answerAllCorrectly(WidgetTester tester) async {
    const answers = ['2.00 mol', '74.10 g/mol', '20 L', '1.51×10²³', '300 K'];
    for (final answer in answers) {
      await tester.tap(find.text(answer));
      await socialSettle(tester);
      // El cuestionario es un ListView: el botón de abajo puede
      // quedar fuera del viewport (botones 3D más altos) y hay que
      // hacer scroll hasta él, como haría el usuario.
      final nextFinder = find.text(tr('quizNext').toUpperCase());
      final next = nextFinder.evaluate().isNotEmpty
          ? nextFinder
          : find.text(tr('quizResult').toUpperCase());
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await socialSettle(tester);
    }
  }

  /// Los 12 usuarios demo de la tabla (mismos que el servicio).
  List<LeaderboardEntry> leaderboard12() => kDemoSocialUsers
      .map((f) => LeaderboardEntry(
            deviceId: f.deviceId,
            username: f.username,
            points: f.points,
            levelsPassedTotal: f.levelsPassedTotal,
            streak: f.streak,
            avatarId: f.avatarId,
          ))
      .toList();

  Future<void> goToProfilePage(WidgetTester tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: melliLightTheme(),
        home: OnboardingScreen(onFinished: () {}),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text(tr('obNext').toUpperCase()));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('fix8_navbar: Niveles con la barra nueva', (tester) async {
    await pumpApp(tester);
    await warmCompanions(tester);
    await shot(tester, 'fix8_navbar.png');
  });

  testWidgets('fix8_leaderboard: tabla con los 12 usuarios demo',
      (tester) async {
    await pumpScreen(
        tester,
        LeaderboardScreen(
          entriesStream: Stream.value(leaderboard12()),
          currentDeviceId: 'dev-kristian',
          isGoogleLinked: true,
        ));
    await socialSettle(tester);
    expect(find.text('sofia'), findsOneWidget);
    // La fila del usuario actual muestra "kristian (tú)" en un
    // solo Text (leaderboard_screen.dart:280).
    expect(find.textContaining('kristian'), findsOneWidget);
    // Precarga del podio: sin ella los laureles salen
    // en blanco en la captura (caché de imágenes fría).
    await warmLaurels(tester);
    await shot(tester, 'fix8_leaderboard.png');
  });

  testWidgets('fix8_onboarding_google: perfil con Google',
      (tester) async {
    await goToProfilePage(tester);
    expect(find.text(tr('googleContinue').toUpperCase()), findsOneWidget);
    await warmLaurels(tester);
    await shot(tester, 'fix8_onboarding_google.png');
  });

  testWidgets('fix8_onboarding_nombre: nombre y género rediseñados',
      (tester) async {
    await goToProfilePage(tester);
    expect(find.text(tr('obProfileTitle')), findsOneWidget);
    expect(find.text(tr('obFemale')), findsOneWidget);
    expect(find.text(tr('obMale')), findsOneWidget);
    await warmLaurels(tester);
    await shot(tester, 'fix8_onboarding_nombre.png');
  });

  testWidgets('fix8_amigos: amigos + Mis duelos (retado)', (tester) async {
    repo.simulateIncomingDuel('valeria');
    // Solicitudes (ronda 2d): una entrante de daniel y una enviada
    // a rosa, para que se vea la sección con Confirmar/Eliminar y
    // "Solicitud enviada" + Cancelar.
    repo.simulateIncomingFriendRequest('daniel');
    repo.simulateSentFriendRequest('rosa');
    await pumpScreen(tester, const FriendsScreen(isGoogleLinked: true));
    await socialSettle(tester);
    expect(find.text(tr('myDuelsTitle')), findsOneWidget);
    expect(find.text('laura'), findsOneWidget);
    expect(find.text(tr('friendsRequestsTitle')), findsOneWidget);
    expect(find.text('daniel'), findsOneWidget);
    expect(find.text('rosa'), findsOneWidget);
    expect(find.text(tr('friendsRequestAccept').toUpperCase()),
        findsOneWidget);
    expect(find.text(tr('friendsRequestReject').toUpperCase()),
        findsOneWidget);
    expect(find.text(tr('friendsRequestCancel').toUpperCase()),
        findsOneWidget);
    // Precarga de los avatares premium (laura/sofia): sin ella la
    // foto sale en blanco en la captura.
    await warmAvatars(tester);
    await shot(tester, 'fix8_amigos.png');
  });

  testWidgets('fix8_duelo_espera: esperando a tu amigo', (tester) async {
    final match = (await SocialService.createDuel(opponentUsername: 'laura'))!;
    await pumpScreen(
        tester, DuelScreen(initialMatch: match, isGoogleLinked: true));
    await tester.tap(find.text(tr('duelStart').toUpperCase()));
    await socialSettle(tester);
    await answerAllCorrectly(tester);
    expect(find.text(tr('duelWaiting')), findsOneWidget);
    await shot(tester, 'fix8_duelo_espera.png');
  });

  testWidgets('fix8_duelo_resultado: ganador resaltado', (tester) async {
    final match = (await SocialService.createDuel(opponentUsername: 'laura'))!;
    await pumpScreen(
        tester, DuelScreen(initialMatch: match, isGoogleLinked: true));
    await tester.tap(find.text(tr('duelStart').toUpperCase()));
    await socialSettle(tester);
    await answerAllCorrectly(tester);
    repo.simulateOpponentFinishes(match.matchId, 3);
    await socialSettle(tester);
    expect(find.text(tr('duelYouWin')), findsOneWidget);
    await shot(tester, 'fix8_duelo_resultado.png');
  });

  testWidgets('fix8_duelo_desconexion: "[nombre] perdió el internet"',
      (tester) async {
    final match = (await SocialService.createDuel(opponentUsername: 'laura'))!;
    await pumpScreen(
        tester, DuelScreen(initialMatch: match, isGoogleLinked: true));
    await tester.tap(find.text(tr('duelStart').toUpperCase()));
    await socialSettle(tester);
    repo.simulateOpponentDisconnects(match.matchId);
    await socialSettle(tester);
    expect(
        find.text(tr('duelOpponentOffline').replaceFirst('%s', 'laura')),
        findsOneWidget);
    await shot(tester, 'fix8_duelo_desconexion.png');
  });

  testWidgets('fix8_torneos: activos y próximos', (tester) async {
    await pumpScreen(tester, const TournamentsScreen(isGoogleLinked: true));
    await socialSettle(tester);
    expect(find.text('Torneo de Estequiometría'), findsOneWidget);
    await shot(tester, 'fix8_torneos.png');
  });

  testWidgets('fix8_tienda: tienda con 2000 puntos', (tester) async {
    ProgressService.instance.addPoints(2000);
    await pumpScreen(tester, const ShopScreen(isGoogleLinked: true));
    await socialSettle(tester);
    expect(find.text('Coral'), findsOneWidget);
    // Precarga de los avatares premium: sin ella salen en blanco.
    await warmAvatars(tester);
    await shot(tester, 'fix8_tienda.png');
  });

  testWidgets('fix8_grupos: grupos con el grupo semilla', (tester) async {
    await pumpScreen(tester, const GroupsScreen(isGoogleLinked: true));
    await socialSettle(tester);
    expect(find.text('Químicos nocturnos'), findsOneWidget);
    await shot(tester, 'fix8_grupos.png');
  });

  testWidgets('fix8_tabla_vacia: "sé el primero"', (tester) async {
    await pumpScreen(
        tester,
        LeaderboardScreen(
          entriesStream: Stream.value(<LeaderboardEntry>[]),
          currentDeviceId: 'dev-kristian',
          isGoogleLinked: true,
        ));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(tr('lbEmpty')), findsOneWidget);
    // Precarga de Brenda: sin ella la mascota del vacío sale en
    // blanco en la captura (caché de imágenes fría).
    await warmCompanions(tester);
    await shot(tester, 'fix8_tabla_vacia.png');
  });

  testWidgets('fix8_amigos_vacios: sin amigos', (tester) async {
    repo = InMemorySocialRepository(seedDemo: false);
    SocialService.setRepositoryForTests(repo);
    await pumpScreen(tester, const FriendsScreen(isGoogleLinked: true));
    await socialSettle(tester);
    expect(find.text(tr('friendsEmpty')), findsOneWidget);
    await shot(tester, 'fix8_amigos_vacios.png');
  });

  testWidgets('fix8_torneos_vacios: sin torneos', (tester) async {
    repo = InMemorySocialRepository(seedDemo: false);
    SocialService.setRepositoryForTests(repo);
    await pumpScreen(tester, const TournamentsScreen(isGoogleLinked: true));
    await socialSettle(tester);
    expect(find.text(tr('tournEmpty')), findsOneWidget);
    await shot(tester, 'fix8_torneos_vacios.png');
  });

  testWidgets('fix8_grupos_vacios: sin grupos', (tester) async {
    repo = InMemorySocialRepository(seedDemo: false);
    SocialService.setRepositoryForTests(repo);
    await pumpScreen(tester, const GroupsScreen(isGoogleLinked: true));
    await socialSettle(tester);
    expect(find.text(tr('groupsEmpty')), findsOneWidget);
    await shot(tester, 'fix8_grupos_vacios.png');
  });

  testWidgets('fix8_duelo_vacio: buscando rival al azar', (tester) async {
    await pumpScreen(
        tester, const DuelScreen(random: true, isGoogleLinked: true));
    expect(find.text(tr('duelFindingOpponent')), findsOneWidget);
    await shot(tester, 'fix8_duelo_vacio.png');
    // Dejar que expire el temporizador de 400 ms del rival al azar:
    // si el test termina antes, el framework protesta por el Timer
    // pendiente al desmontar el árbol.
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('fix8_puerta_tabla: puerta de Google en la tabla',
      (tester) async {
    await pumpScreen(
        tester, const LeaderboardScreen(isGoogleLinked: false));
    expect(find.text(tr('onlineNeedGoogle')), findsOneWidget);
    await shot(tester, 'fix8_puerta_tabla.png');
  });

  testWidgets('fix8_puerta_duelo: puerta de Google en el duelo',
      (tester) async {
    await pumpScreen(tester, const DuelScreen(isGoogleLinked: false));
    expect(find.text(tr('onlineNeedGoogle')), findsOneWidget);
    await shot(tester, 'fix8_puerta_duelo.png');
  });

  testWidgets('fix8_torneo_sin_conexion: entregar sin internet',
      (tester) async {
    repo.onlineFlag = false;
    await pumpScreen(
        tester,
        const TournamentDetailScreen(
            tournamentId: 't1', isGoogleLinked: true));
    await socialSettle(tester);
    // El botón del detalle es DuoButton (§1.4): la etiqueta llega
    // en mayúsculas (como en la lista y como espera
    // fix8_social_test); el localizador va en mayúsculas también.
    await tester.tap(find.text(tr('tournPlay').toUpperCase()));
    await socialSettle(tester);
    await answerAllCorrectly(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(tr('tournOfflineScore')), findsOneWidget);
    // Precarga de los avatares premium (sofia/laura en la
    // clasificación): sin ella la foto sale en blanco.
    await warmAvatars(tester);
    await shot(tester, 'fix8_torneo_sin_conexion.png');
  });

  testWidgets('fix8_soporte: ventanita con hilo y WhatsApp', (tester) async {
    await pumpScreen(
      tester,
      SupportScreen(
        isGoogleLinked: true,
        service: _PreviewSupportFake(),
      ),
    );
    await socialSettle(tester);
    expect(find.text('No me sale el balanceo de la reacción del hierro'),
        findsOneWidget);
    expect(find.textContaining('¿Prefieres WhatsApp?'), findsOneWidget);
    await shot(tester, 'fix8_soporte.png');
  });
}

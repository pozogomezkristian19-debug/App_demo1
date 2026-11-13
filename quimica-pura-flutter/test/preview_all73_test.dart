// Vistas previas de TODAS las pantallas de Quemia 7.3 (44 pantallas
// × claro/oscuro = 88 fotos). Se ejecuta con --update-goldens para
// ESCRIBIR los PNG en ~/workspace/melli-qui-v6-previews/ (nombres
// foto73_all_<pantalla>_claro.png / _oscuro.png). Viewport 393x852
// (dpr 2), Roboto + MaterialIcons + Nunito reales. Las pantallas
// sueltas se montan con la réplica fiel del tema (melliLightTheme /
// melliDarkTheme, copiadas de preview_quemia73_test.dart, con
// inputDecorationTheme para que las fotos sean fieles al teléfono);
// la app completa, con MelliQuiApp. Los PNG se leen y se verifican
// a mano antes de informar. NO se envían a Kristian desde aquí.
//
// Lo que la 7.3 cambió y estas fotos reflejan:
// - Barra Aprender-Resolver-[Niveles]-Tabla-Cuenta.
// - Tabla: búsqueda debajo de las pestañas, dentro del scroll, con
//   huecos generosos (12 dp de la divisoria, 12 dp a los chips,
//   8 dp de los chips a la rejilla); chips compactos 36 dp;
//   campo de búsqueda de 44 dp. La página sigue cabiendo a
//   400x852 sin desplazar.
// - Teclados sencillo/científico según la dificultad; "Usar
//   resultado" y CANJEAR con letra blanca sobre teal oscuro
//   cuando están deshabilitados.
// - Constantes con campos redondeados (sin líneas rústicas).
// - Tienda online con Marcos; fila Referidos en Cuenta y en el menú
//   (Invitar/Canjear tienen sus propias fotos foto73_referidos_*).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quimica_pura/data/i18n/content_i18n.dart';
import 'package:quimica_pura/data/topics.dart';
import 'package:quimica_pura/models.dart';
import 'package:quimica_pura/widgets/brand_logo.dart';
import 'package:quimica_pura/widgets/element_sheet.dart';
import 'package:quimica_pura/widgets/lucide_icons.dart';
import 'package:quimica_pura/widgets/simple_quiz.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/account_screen.dart';
import 'package:quimica_pura/screens/aprender_screen.dart';
import 'package:quimica_pura/screens/avatar_editor_screen.dart';
import 'package:quimica_pura/screens/branches_screen.dart';
import 'package:quimica_pura/screens/calculator_screen.dart';
import 'package:quimica_pura/screens/compare_screen.dart';
import 'package:quimica_pura/screens/constants_screen.dart';
import 'package:quimica_pura/screens/favorites_screen.dart';
import 'package:quimica_pura/screens/formula_screen.dart';
import 'package:quimica_pura/screens/friends_screen.dart';
import 'package:quimica_pura/screens/glossary_screen.dart';
import 'package:quimica_pura/screens/groups_screen.dart';
import 'package:quimica_pura/screens/how_to_play_screen.dart';
import 'package:quimica_pura/screens/lab_screen.dart';
import 'package:quimica_pura/screens/lab_sim_screen.dart';
import 'package:quimica_pura/screens/language_screen.dart';
import 'package:quimica_pura/screens/leaderboard_screen.dart';
import 'package:quimica_pura/screens/notes_screen.dart';
import 'package:quimica_pura/screens/notifications_screen.dart';
import 'package:quimica_pura/screens/onboarding_screen.dart';
import 'package:quimica_pura/screens/practicar_screen.dart';
import 'package:quimica_pura/screens/reference_tables_screen.dart';
import 'package:quimica_pura/screens/reminder_screen.dart';
import 'package:quimica_pura/screens/resolver_screen.dart';
import 'package:quimica_pura/screens/settings_screen.dart';
import 'package:quimica_pura/screens/shop_screen.dart';
import 'package:quimica_pura/screens/stats_screen.dart';
import 'package:quimica_pura/screens/support_screen.dart';
import 'package:quimica_pura/screens/tabla_screen.dart';
import 'package:quimica_pura/screens/table_quiz_screen.dart';
import 'package:quimica_pura/screens/theme_screen.dart';
import 'package:quimica_pura/screens/timed_exam_screen.dart';
import 'package:quimica_pura/screens/topic_detail_screen.dart';
import 'package:quimica_pura/screens/tournaments_screen.dart';
import 'package:quimica_pura/screens/version_screen.dart';
import 'package:quimica_pura/services/accent.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/nav_requests.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/question_generator.dart';
import 'package:quimica_pura/services/social_service.dart';
import 'package:quimica_pura/services/update_check.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'test_helpers.dart';

/// Datos de la actualización 7.3 para el diálogo (la misma
/// estructura que version.json): el diálogo muestra la versión
/// nueva tal cual, como en la foto72 ("Versión 7.2 disponible").
const _updateInfo73 = UpdateInfo(
  latest: '7.3',
  apkUrl: 'https://example.com/app.apk',
  notes: 'Tienda con marcos y catálogo en línea; sistema de '
      'referidos; teclados según la dificultad; la tabla con más '
      'aire; constantes con campos redondeados.',
  force: false,
);

/// Réplica fiel del tema claro de MelliQuiApp (ver
/// preview_fix8_test.dart): teal #00C2A8 con acento Verde.
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
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5E5E5), width: 2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE8E8E8),
        thickness: 1,
      ),
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
      // Campo Duolingo §1.6 (igual que el tema real de la app en
      // main.dart): sin esto los campos salían con la línea rústica
      // de Material en las fotos, aunque en el teléfono se ven bien.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        constraints: const BoxConstraints(minHeight: 56),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF84D8FF), width: 2),
        ),
      ),
    );

/// Réplica compacta del tema oscuro de MelliQuiApp (_darkTheme en
/// main.dart): fondo #131F24 en Verde / #17112A en Violeta.
ThemeData melliDarkTheme() {
  final violet = AppAccent.isViolet;
  final bg = violet ? const Color(0xFF17112A) : const Color(0xFF131F24);
  final surface =
      violet ? const Color(0xFF241B3D) : const Color(0xFF1F2C34);
  final onSurface =
      violet ? const Color(0xFFEDE9F7) : const Color(0xFFE6F4EE);
  final primary =
      violet ? BrandColors.violetLight : BrandColors.mintLight;
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: ColorScheme.dark(
      primary: primary,
      onPrimary: bg,
      secondary: violet ? BrandColors.violet : BrandColors.mint,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest:
          violet ? const Color(0xFF2E2350) : const Color(0xFF1B3A31),
      error: const Color(0xFFFF4B4B),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF37464F), width: 2),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.white.withValues(alpha: 0.12),
      thickness: 1,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: violet ? BrandColors.violet : BrandColors.teal,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor:
            violet ? BrandColors.violetDeep : BrandColors.tealDark,
        surfaceTintColor: Colors.transparent,
        shape: DuoPillBorder(
            edgeColor:
                violet ? BrandColors.violetDeep : BrandColors.tealDark),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(
            fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
    // Campo Duolingo §1.6 (igual que el tema real de la app en
    // main.dart): sin esto los campos salían con la línea rústica
    // de Material en las fotos, aunque en el teléfono se ven bien.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: violet ? const Color(0xFF1C1533) : const Color(0xFF0F241E),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      constraints: const BoxConstraints(minHeight: 56),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF37464F), width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF37464F), width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF84D8FF), width: 2),
      ),
    ),
  );
}
/// Fake del plugin de notificaciones: permiso concedido, sin
/// programar nada (patrón de preview_fix8_test.dart).
class _All73PreviewFake extends AndroidFlutterLocalNotificationsPlugin
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
  Future<List<AndroidNotificationChannel>?> getNotificationChannels() async =>
      [];

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadRobotoFonts();
    await loadMaterialIcons();
    await loadNunitoFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    ProgressService.track = ProgressService.trackUni;
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
    FlutterLocalNotificationsPlatform.instance = _All73PreviewFake();
    UserPrefs.rulesSeenV6 = true;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    await UserPrefs.saveThemeMode('claro');
    UserPrefs.isDark = false;
    UserPrefs.onboardingDone = true;
    UserPrefs.userName = 'kristian';
    UserPrefs.track = 'uni';
    SocialService.setRepositoryForTests(InMemorySocialRepository());
    AnalyticsSync.resetForTests();
    AnalyticsSync.markFirebaseReady();
  });

  tearDown(() {
    SocialService.resetForTests();
    AnalyticsSync.resetForTests();
    NavRequests.startReview = false;
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = false;
    UserPrefs.isDark = false;
    UserPrefs.userName = '';
    UserPrefs.publicUsername = '';
  });

  Future<void> setPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> shot(WidgetTester tester, String name) async {
    // Las imágenes de assets se decodifican de forma asíncrona:
    // sin estos pumps la captura sale con el hueco en blanco.
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../melli-qui-v6-previews/$name'),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    bool dark = false,
  }) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? melliDarkTheme() : melliLightTheme(),
        home: screen,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
  }

  /// App completa en modo oscuro (el setUp deja el tema en claro).
  Future<void> pumpAppDark(WidgetTester tester) async {
    await UserPrefs.saveThemeMode('oscuro');
    UserPrefs.isDark = true;
    await pumpApp(tester);
  }

  /// Abre la hoja del elemento buscándolo por su símbolo.
  Future<void> openElementSheet(
      WidgetTester tester, String symbol) async {
    await tester.tap(find.text(symbol).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Abre la calculadora desde un botón (patrón foto73).
  Future<void> openCalculator(
    WidgetTester tester, {
    required bool scientific,
    String unit = 'mol',
    bool dark = false,
  }) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? melliDarkTheme() : melliLightTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                CalculatorScreen.open(
                  context,
                  scientific: scientific,
                  submitResult: true,
                  unit: unit,
                );
              },
              child: const Text('Abrir calculadora'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Abrir calculadora'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CalculatorScreen), findsOneWidget);
  }

  /// Toca una tecla de la calculadora por su etiqueta.
  Future<void> tapCalcKey(WidgetTester tester, String label) async {
    final filled = find.widgetWithText(FilledButton, label);
    final target =
        filled.evaluate().isNotEmpty ? filled : find.widgetWithText(OutlinedButton, label);
    await tester.tap(target);
    await tester.pump();
  }

  /// Los 12 usuarios demo para la tabla de posiciones.
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

  /// Precarga de los laureles del podio (sin esto salen en blanco).
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

  /// Siembra 3 errores para el repaso (foto errores).
  void seedReviewErrors() {
    for (var i = 0; i < 3; i++) {
      ProgressService.instance.addFailed(FailedEntry(
        id: 'all73-review-$i',
        topic: 'bach-estequiometria',
        question: 'Pregunta de repaso ${i + 1}',
        level: 1,
      ));
    }
  }

  // Calentamiento: decodifica las imágenes ANTES de la primera
  // captura, esperando la decodificación de verdad con runAsync +
  // precacheImage (patrón de preview_quemia73_test.dart).
  testWidgets('warm-up imágenes', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: melliLightTheme(),
        home: const Scaffold(
          body: Row(
            key: Key('warmup'),
            children: [
              Image(image: AssetImage('assets/google_g.png'),
                  width: 40, height: 40),
              Image(image: AssetImage('assets/app_icon.png'),
                  width: 40, height: 40),
              Image(image: AssetImage('assets/ring_logo.png'),
                  width: 40, height: 40),
              Image(image: AssetImage('assets/brenda.png'),
                  width: 40, height: 40),
              Image(image: AssetImage('assets/britany.png'),
                  width: 40, height: 40),
              Image(image: AssetImage('assets/kristian.png'),
                  width: 40, height: 40),
              Image(image: AssetImage('assets/logo.png'),
                  width: 40, height: 40),
            ],
          ),
        ),
      ),
    );
    final context = tester.element(find.byKey(const Key('warmup')));
    await tester.runAsync(() async {
      for (final name in [
        'google_g',
        'app_icon',
        'ring_logo',
        'brenda',
        'britany',
        'kristian',
        'logo',
        'avatar_default',
        'avatar_dorado',
        'avatar_violeta',
        'avatar_teal',
      ]) {
        await precacheImage(AssetImage('assets/$name.png'), context);
      }
    });
    await settle(tester);
  });

  group('all73 acerca', () {
    Future<void> openAbout(WidgetTester tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Cuenta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // "Acerca de Quemia" queda debajo del pliegue de Cuenta: hay
      // que bajar dentro de su ListView para que se construya.
      await tester.scrollUntilVisible(
        find.text('Acerca de Quemia'),
        300,
        scrollable: find.descendant(
          of: find.byType(AccountScreen),
          matching: find.byWidgetPredicate((w) =>
              w is Scrollable &&
              w.axisDirection == AxisDirection.down),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Acerca de Quemia'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Quemia'), findsWidgets);
    }

    testWidgets('foto73_all_acerca_claro', (tester) async {
      await openAbout(tester);
      await shot(tester, 'foto73_all_acerca_claro.png');
    });

    testWidgets('foto73_all_acerca_oscuro', (tester) async {
      await UserPrefs.saveThemeMode('oscuro');
      UserPrefs.isDark = true;
      await openAbout(tester);
      await shot(tester, 'foto73_all_acerca_oscuro.png');
    });
  });

  group('all73 ajustes', () {
    testWidgets('foto73_all_ajustes_claro', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: SettingsScreen(onOpenScreen: (_) {}),
        ),
      );
      await shot(tester, 'foto73_all_ajustes_claro.png');
    });

    testWidgets('foto73_all_ajustes_oscuro', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: SettingsScreen(onOpenScreen: (_) {}),
        ),
        dark: true,
      );
      await shot(tester, 'foto73_all_ajustes_oscuro.png');
    });
  });

  group('all73 amigos', () {
    testWidgets('foto73_all_amigos_claro', (tester) async {
      // Nombre ya reclamado (Kristian, 2026-11-13): en la foto se
      // ve el nombre real con COPIAR activo, no el mensaje pendiente.
      UserPrefs.publicUsername = 'Kristian';
      await pumpScreen(
        tester,
        const Scaffold(body: FriendsScreen(isGoogleLinked: true)),
      );
      await shot(tester, 'foto73_all_amigos_claro.png');
    });

    testWidgets('foto73_all_amigos_oscuro', (tester) async {
      UserPrefs.publicUsername = 'Kristian';
      await pumpScreen(
        tester,
        const Scaffold(body: FriendsScreen(isGoogleLinked: true)),
        dark: true,
      );
      await shot(tester, 'foto73_all_amigos_oscuro.png');
    });
  });

  group('all73 aprender', () {
    testWidgets('foto73_all_aprender_claro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: AprenderScreen()),
      );
      await shot(tester, 'foto73_all_aprender_claro.png');
    });

    testWidgets('foto73_all_aprender_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: AprenderScreen()),
        dark: true,
      );
      await shot(tester, 'foto73_all_aprender_oscuro.png');
    });
  });

  group('all73 avatar', () {
    testWidgets('foto73_all_avatar_claro', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: AvatarEditorScreen(onOpenScreen: (_) {}),
        ),
      );
      await shot(tester, 'foto73_all_avatar_claro.png');
    });

    testWidgets('foto73_all_avatar_oscuro', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: AvatarEditorScreen(onOpenScreen: (_) {}),
        ),
        dark: true,
      );
      await shot(tester, 'foto73_all_avatar_oscuro.png');
    });
  });

  group('all73 bandeja', () {
    testWidgets('foto73_all_bandeja_claro', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: NotificationsScreen(onOpenScreen: (_) {}),
        ),
      );
      await shot(tester, 'foto73_all_bandeja_claro.png');
    });

    testWidgets('foto73_all_bandeja_oscuro', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: NotificationsScreen(onOpenScreen: (_) {}),
        ),
        dark: true,
      );
      await shot(tester, 'foto73_all_bandeja_oscuro.png');
    });
  });

  group('all73 calculadora', () {
    // Como en la foto72: científica con −log(0.01) tecleado y el
    // resultado 2 en el visor; "Usar resultado" habilitado.
    Future<void> openWorked(WidgetTester tester, {bool dark = false}) async {
      await openCalculator(tester,
          scientific: true, unit: 'pH', dark: dark);
      for (final label in ['−', 'log', '0', '.', '0', '1', ')', '=']) {
        await tapCalcKey(tester, label);
      }
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('2'), findsWidgets);
    }

    testWidgets('foto73_all_calculadora_claro', (tester) async {
      await openWorked(tester);
      await shot(tester, 'foto73_all_calculadora_claro.png');
    });

    testWidgets('foto73_all_calculadora_oscuro', (tester) async {
      await openWorked(tester, dark: true);
      await shot(tester, 'foto73_all_calculadora_oscuro.png');
    });
  });

  group('all73 como_se_juega', () {
    testWidgets('foto73_all_como_se_juega_claro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: HowToPlayScreen()),
      );
      await shot(tester, 'foto73_all_como_se_juega_claro.png');
    });

    testWidgets('foto73_all_como_se_juega_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: HowToPlayScreen()),
        dark: true,
      );
      await shot(tester, 'foto73_all_como_se_juega_oscuro.png');
    });
  });

  group('all73 comparar', () {
    testWidgets('foto73_all_comparar_claro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: CompareScreen()),
      );
      await shot(tester, 'foto73_all_comparar_claro.png');
    });

    testWidgets('foto73_all_comparar_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: CompareScreen()),
        dark: true,
      );
      await shot(tester, 'foto73_all_comparar_oscuro.png');
    });
  });

  group('all73 constantes', () {
    testWidgets('foto73_all_constantes_claro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: ConstantsScreen()),
      );
      await shot(tester, 'foto73_all_constantes_claro.png');
    });

    testWidgets('foto73_all_constantes_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: ConstantsScreen()),
        dark: true,
      );
      await shot(tester, 'foto73_all_constantes_oscuro.png');
    });
  });

  group('all73 cuaderno', () {
    testWidgets('foto73_all_cuaderno_claro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: NotesScreen()),
      );
      await shot(tester, 'foto73_all_cuaderno_claro.png');
    });

    testWidgets('foto73_all_cuaderno_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: NotesScreen()),
        dark: true,
      );
      await shot(tester, 'foto73_all_cuaderno_oscuro.png');
    });
  });

  group('all73 cuenta', () {
    Future<void> pumpCuenta(WidgetTester tester, {bool dark = false}) async {
      // Nombre ya reclamado (Kristian, 2026-11-13): la tarjeta de
      // Cuenta muestra "Usuario: Kristian" con su botoncito de
      // copiar; sin esto la línea no saldría en la foto (en la app
      // real se reclama al iniciar sesión con Google).
      UserPrefs.publicUsername = 'Kristian';
      await pumpScreen(
        tester,
        AccountScreen(
          onOpenScreen: (_) {},
          onShowAbout: () {},
          onShowShareApp: () {},
          trackTopics: const ['estequiometria'],
        ),
        dark: dark,
      );
      await tester.runAsync(() async {
        final ctx = tester.element(find.byType(AccountScreen));
        await precacheImage(const AssetImage('assets/kristian.png'), ctx);
        for (final name in ['brenda', 'britany']) {
          await precacheImage(AssetImage('assets/$name.png'), ctx);
        }
      });
      await settle(tester);
    }

    testWidgets('foto73_all_cuenta_claro', (tester) async {
      await pumpCuenta(tester);
      await shot(tester, 'foto73_all_cuenta_claro.png');
    });

    testWidgets('foto73_all_cuenta_oscuro', (tester) async {
      await pumpCuenta(tester, dark: true);
      await shot(tester, 'foto73_all_cuenta_oscuro.png');
    });
  });

  group('all73 detalle_elemento', () {
    Future<void> openMoscovio(WidgetTester tester,
        {bool dark = false}) async {
      await pumpScreen(tester, const Scaffold(body: TablaScreen()),
          dark: dark);
      await tester.enterText(find.byType(TextField).first, 'Moscovio');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await openElementSheet(tester, 'Mc');
      expect(
        find.descendant(
          of: find.byType(ElementSheet),
          matching: find.text('Moscovio'),
        ),
        findsOneWidget,
      );
    }

    testWidgets('foto73_all_detalle_elemento_claro', (tester) async {
      await openMoscovio(tester);
      await shot(tester, 'foto73_all_detalle_elemento_claro.png');
    });

    testWidgets('foto73_all_detalle_elemento_oscuro', (tester) async {
      await openMoscovio(tester, dark: true);
      await shot(tester, 'foto73_all_detalle_elemento_oscuro.png');
    });
  });

  group('all73 detalle_tema', () {
    testWidgets('foto73_all_detalle_tema_claro', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(body: TopicDetailScreen(topic: topics.first)),
      );
      await shot(tester, 'foto73_all_detalle_tema_claro.png');
    });

    testWidgets('foto73_all_detalle_tema_oscuro', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(body: TopicDetailScreen(topic: topics.first)),
        dark: true,
      );
      await shot(tester, 'foto73_all_detalle_tema_oscuro.png');
    });
  });

  group('all73 dialogo_actualizar', () {
    Future<void> openDialog(WidgetTester tester) async {
      await pumpApp(tester);
      final context = tester.element(find.byType(Scaffold).first);
      UpdateCheckService.showUpdateDialog(context, _updateInfo73);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('actualización'), findsOneWidget);
    }

    testWidgets('foto73_all_dialogo_actualizar_claro', (tester) async {
      await openDialog(tester);
      await shot(tester, 'foto73_all_dialogo_actualizar_claro.png');
    });

    testWidgets('foto73_all_dialogo_actualizar_oscuro', (tester) async {
      await UserPrefs.saveThemeMode('oscuro');
      UserPrefs.isDark = true;
      await openDialog(tester);
      await shot(tester, 'foto73_all_dialogo_actualizar_oscuro.png');
    });
  });

  group('all73 errores', () {
    Future<void> openReview(WidgetTester tester, {bool dark = false}) async {
      seedReviewErrors();
      NavRequests.startReview = true;
      await pumpScreen(
        tester,
        Scaffold(body: PracticarScreen(onOpenScreen: (_) {})),
        dark: dark,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Repasar mis errores'), findsOneWidget);
    }

    testWidgets('foto73_all_errores_claro', (tester) async {
      await openReview(tester);
      await shot(tester, 'foto73_all_errores_claro.png');
    });

    testWidgets('foto73_all_errores_oscuro', (tester) async {
      await openReview(tester, dark: true);
      await shot(tester, 'foto73_all_errores_oscuro.png');
    });
  });

  group('all73 estadisticas', () {
    testWidgets('foto73_all_estadisticas_claro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(
          body: StatsScreen(trackTopics: ['estequiometria']),
        ),
      );
      await shot(tester, 'foto73_all_estadisticas_claro.png');
    });

    testWidgets('foto73_all_estadisticas_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(
          body: StatsScreen(trackTopics: ['estequiometria']),
        ),
        dark: true,
      );
      await shot(tester, 'foto73_all_estadisticas_oscuro.png');
    });
  });

  group('all73 examen_pregunta', () {
    Future<void> startExam(WidgetTester tester, {bool dark = false}) async {
      await pumpScreen(tester, const Scaffold(body: TimedExamScreen()),
          dark: dark);
      await tester.tap(find.text('Empezar el examen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Pregunta'), findsWidgets);
    }

    testWidgets('foto73_all_examen_pregunta_claro', (tester) async {
      await startExam(tester);
      await shot(tester, 'foto73_all_examen_pregunta_claro.png');
    });

    testWidgets('foto73_all_examen_pregunta_oscuro', (tester) async {
      await startExam(tester, dark: true);
      await shot(tester, 'foto73_all_examen_pregunta_oscuro.png');
    });
  });

  group('all73 examen_tiempo', () {
    testWidgets('foto73_all_examen_tiempo_claro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: TimedExamScreen()),
      );
      await shot(tester, 'foto73_all_examen_tiempo_claro.png');
    });

    testWidgets('foto73_all_examen_tiempo_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: TimedExamScreen()),
        dark: true,
      );
      await shot(tester, 'foto73_all_examen_tiempo_oscuro.png');
    });
  });

  group('all73 favoritos', () {
    testWidgets('foto73_all_favoritos_claro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: FavoritesScreen()),
      );
      await shot(tester, 'foto73_all_favoritos_claro.png');
    });

    testWidgets('foto73_all_favoritos_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: FavoritesScreen()),
        dark: true,
      );
      await shot(tester, 'foto73_all_favoritos_oscuro.png');
    });
  });

  group('all73 formulario', () {
    testWidgets('foto73_all_formulario_claro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: FormulaScreen()),
      );
      await shot(tester, 'foto73_all_formulario_claro.png');
    });

    testWidgets('foto73_all_formulario_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: FormulaScreen()),
        dark: true,
      );
      await shot(tester, 'foto73_all_formulario_oscuro.png');
    });
  });

  group('all73 glosario', () {
    testWidgets('foto73_all_glosario_claro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: GlossaryScreen()),
      );
      await shot(tester, 'foto73_all_glosario_claro.png');
    });

    testWidgets('foto73_all_glosario_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: GlossaryScreen()),
        dark: true,
      );
      await shot(tester, 'foto73_all_glosario_oscuro.png');
    });
  });

  group('all73 grupos', () {
    testWidgets('foto73_all_grupos_claro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: GroupsScreen(isGoogleLinked: true)),
      );
      await shot(tester, 'foto73_all_grupos_claro.png');
    });

    testWidgets('foto73_all_grupos_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: GroupsScreen(isGoogleLinked: true)),
        dark: true,
      );
      await shot(tester, 'foto73_all_grupos_oscuro.png');
    });
  });

  group('all73 idioma', () {
    testWidgets('foto73_all_idioma_claro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: LanguageScreen()),
      );
      await shot(tester, 'foto73_all_idioma_claro.png');
    });

    testWidgets('foto73_all_idioma_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: LanguageScreen()),
        dark: true,
      );
      await shot(tester, 'foto73_all_idioma_oscuro.png');
    });
  });

  group('all73 laboratorio', () {
    testWidgets('foto73_all_laboratorio_claro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: LabScreen()),
      );
      await shot(tester, 'foto73_all_laboratorio_claro.png');
    });

    testWidgets('foto73_all_laboratorio_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: LabScreen()),
        dark: true,
      );
      await shot(tester, 'foto73_all_laboratorio_oscuro.png');
    });
  });

  group('all73 menu', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byWidgetPredicate(
          (w) => w is LucideIcon && w.icon == LucideIcons.menu));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Drawer), findsOneWidget);
    }

    testWidgets('foto73_all_menu_claro', (tester) async {
      await pumpApp(tester);
      await openMenu(tester);
      await shot(tester, 'foto73_all_menu_claro.png');
    });

    testWidgets('foto73_all_menu_oscuro', (tester) async {
      await pumpAppDark(tester);
      await openMenu(tester);
      await shot(tester, 'foto73_all_menu_oscuro.png');
    });
  });

  group('all73 niveles', () {
    testWidgets('foto73_all_niveles_claro', (tester) async {
      await pumpApp(tester);
      await shot(tester, 'foto73_all_niveles_claro.png');
    });

    testWidgets('foto73_all_niveles_oscuro', (tester) async {
      await pumpAppDark(tester);
      await shot(tester, 'foto73_all_niveles_oscuro.png');
    });
  });

  group('all73 onboarding', () {
    testWidgets('foto73_all_onboarding_claro', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(body: OnboardingScreen(onFinished: () {})),
      );
      await shot(tester, 'foto73_all_onboarding_claro.png');
    });

    testWidgets('foto73_all_onboarding_oscuro', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(body: OnboardingScreen(onFinished: () {})),
        dark: true,
      );
      await shot(tester, 'foto73_all_onboarding_oscuro.png');
    });
  });

  group('all73 pregunta_multiple', () {
    QuizQuestion mcQuestion() =>
        localizedAllQuestions().firstWhere((q) => q.options.length == 4);

    testWidgets('foto73_all_pregunta_multiple_claro', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: SimpleQuizRunner(
            title: 'Estequiometría · Nivel 1',
            items: [mcQuestion()],
            onFinished: (_, __) {},
            onExit: () {},
          ),
        ),
      );
      await shot(tester, 'foto73_all_pregunta_multiple_claro.png');
    });

    testWidgets('foto73_all_pregunta_multiple_oscuro', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: SimpleQuizRunner(
            title: 'Estequiometría · Nivel 1',
            items: [mcQuestion()],
            onFinished: (_, __) {},
            onExit: () {},
          ),
        ),
        dark: true,
      );
      await shot(tester, 'foto73_all_pregunta_multiple_oscuro.png');
    });
  });

  group('all73 pregunta_numerica', () {
    testWidgets('foto73_all_pregunta_numerica_claro', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: SimpleQuizRunner(
            title: 'Ácido-base · Nivel 1',
            items: [buildPh('ph', 1, 2).question],
            onFinished: (_, __) {},
            onExit: () {},
          ),
        ),
      );
      await shot(tester, 'foto73_all_pregunta_numerica_claro.png');
    });

    testWidgets('foto73_all_pregunta_numerica_oscuro', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: SimpleQuizRunner(
            title: 'Ácido-base · Nivel 1',
            items: [buildPh('ph', 1, 2).question],
            onFinished: (_, __) {},
            onExit: () {},
          ),
        ),
        dark: true,
      );
      await shot(tester, 'foto73_all_pregunta_numerica_oscuro.png');
    });
  });

  group('all73 quiz_tabla', () {
    testWidgets('foto73_all_quiz_tabla_claro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: TableQuizScreen()),
      );
      await shot(tester, 'foto73_all_quiz_tabla_claro.png');
    });

    testWidgets('foto73_all_quiz_tabla_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: TableQuizScreen()),
        dark: true,
      );
      await shot(tester, 'foto73_all_quiz_tabla_oscuro.png');
    });
  });

  group('all73 ramas', () {
    testWidgets('foto73_all_ramas_claro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: BranchesScreen()),
      );
      await shot(tester, 'foto73_all_ramas_claro.png');
    });

    testWidgets('foto73_all_ramas_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: BranchesScreen()),
        dark: true,
      );
      await shot(tester, 'foto73_all_ramas_oscuro.png');
    });
  });

  group('all73 recordatorios', () {
    testWidgets('foto73_all_recordatorios_claro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: ReminderScreen()),
      );
      await shot(tester, 'foto73_all_recordatorios_claro.png');
    });

    testWidgets('foto73_all_recordatorios_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: ReminderScreen()),
        dark: true,
      );
      await shot(tester, 'foto73_all_recordatorios_oscuro.png');
    });
  });

  group('all73 resolver', () {
    testWidgets('foto73_all_resolver_claro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: ResolverScreen()),
      );
      await shot(tester, 'foto73_all_resolver_claro.png');
    });

    testWidgets('foto73_all_resolver_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: ResolverScreen()),
        dark: true,
      );
      await shot(tester, 'foto73_all_resolver_oscuro.png');
    });
  });

  group('all73 resultado', () {
    // Como en la foto72: 1 pregunta, acierto, resultado 100%.
    Future<void> playOne(WidgetTester tester, {bool dark = false}) async {
      final q =
          localizedAllQuestions().firstWhere((q) => q.options.length == 4);
      await pumpScreen(
        tester,
        Scaffold(
          body: SimpleQuizRunner(
            title: 'Estequiometría · Nivel 1',
            items: [q],
            onFinished: (_, __) {},
            onExit: () {},
          ),
        ),
        dark: dark,
      );
      await tester.tap(find.text(q.options[q.answer]).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final nextFinder = find.text(tr('quizNext').toUpperCase());
      final target = nextFinder.evaluate().isNotEmpty
          ? nextFinder
          : find.text(tr('quizResult').toUpperCase());
      await tester.tap(target);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(tr('quizResult')), findsOneWidget);
    }

    testWidgets('foto73_all_resultado_claro', (tester) async {
      await playOne(tester);
      await shot(tester, 'foto73_all_resultado_claro.png');
    });

    testWidgets('foto73_all_resultado_oscuro', (tester) async {
      await playOne(tester, dark: true);
      await shot(tester, 'foto73_all_resultado_oscuro.png');
    });
  });

  group('all73 simulador_lab', () {
    testWidgets('foto73_all_simulador_lab_claro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: LabSimScreen()),
      );
      await shot(tester, 'foto73_all_simulador_lab_claro.png');
    });

    testWidgets('foto73_all_simulador_lab_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: LabSimScreen()),
        dark: true,
      );
      await shot(tester, 'foto73_all_simulador_lab_oscuro.png');
    });
  });

  group('all73 soporte', () {
    testWidgets('foto73_all_soporte_claro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: SupportScreen()),
      );
      await shot(tester, 'foto73_all_soporte_claro.png');
    });

    testWidgets('foto73_all_soporte_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: SupportScreen()),
        dark: true,
      );
      await shot(tester, 'foto73_all_soporte_oscuro.png');
    });
  });

  group('all73 tabla', () {
    testWidgets('foto73_all_tabla_claro', (tester) async {
      await pumpScreen(tester, const Scaffold(body: TablaScreen()));
      await shot(tester, 'foto73_all_tabla_claro.png');
    });

    testWidgets('foto73_all_tabla_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: TablaScreen()),
        dark: true,
      );
      await shot(tester, 'foto73_all_tabla_oscuro.png');
    });
  });

  group('all73 tabla_posiciones', () {
    Future<void> pumpBoard(WidgetTester tester, {bool dark = false}) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: LeaderboardScreen(
            entriesStream: Stream.value(leaderboard12()),
            currentDeviceId: 'dev-kristian',
            isGoogleLinked: true,
          ),
        ),
        dark: dark,
      );
      await settle(tester);
      await warmLaurels(tester);
    }

    testWidgets('foto73_all_tabla_posiciones_claro', (tester) async {
      await pumpBoard(tester);
      await shot(tester, 'foto73_all_tabla_posiciones_claro.png');
    });

    testWidgets('foto73_all_tabla_posiciones_oscuro', (tester) async {
      await pumpBoard(tester, dark: true);
      await shot(tester, 'foto73_all_tabla_posiciones_oscuro.png');
    });
  });

  group('all73 tablas_referencia', () {
    testWidgets('foto73_all_tablas_referencia_claro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: ReferenceTablesScreen()),
      );
      await shot(tester, 'foto73_all_tablas_referencia_claro.png');
    });

    testWidgets('foto73_all_tablas_referencia_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: ReferenceTablesScreen()),
        dark: true,
      );
      await shot(tester, 'foto73_all_tablas_referencia_oscuro.png');
    });
  });

  group('all73 tema', () {
    testWidgets('foto73_all_tema_claro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: ThemeScreen()),
      );
      await shot(tester, 'foto73_all_tema_claro.png');
    });

    testWidgets('foto73_all_tema_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: ThemeScreen()),
        dark: true,
      );
      await shot(tester, 'foto73_all_tema_oscuro.png');
    });
  });

  group('all73 tienda', () {
    testWidgets('foto73_all_tienda_claro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: ShopScreen(isGoogleLinked: true)),
      );
      await shot(tester, 'foto73_all_tienda_claro.png');
    });

    testWidgets('foto73_all_tienda_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: ShopScreen(isGoogleLinked: true)),
        dark: true,
      );
      await shot(tester, 'foto73_all_tienda_oscuro.png');
    });
  });

  group('all73 torneo', () {
    testWidgets('foto73_all_torneo_claro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: TournamentsScreen(isGoogleLinked: true)),
      );
      await shot(tester, 'foto73_all_torneo_claro.png');
    });

    testWidgets('foto73_all_torneo_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: TournamentsScreen(isGoogleLinked: true)),
        dark: true,
      );
      await shot(tester, 'foto73_all_torneo_oscuro.png');
    });
  });

  group('all73 version', () {
    testWidgets('foto73_all_version_claro', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(body: VersionScreen(onVersionChanged: () {})),
      );
      await shot(tester, 'foto73_all_version_claro.png');
    });

    testWidgets('foto73_all_version_oscuro', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(body: VersionScreen(onVersionChanged: () {})),
        dark: true,
      );
      await shot(tester, 'foto73_all_version_oscuro.png');
    });
  });
}

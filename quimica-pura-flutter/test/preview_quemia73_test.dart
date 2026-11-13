// Vistas previas de Quemia 7.3 (los 13 puntos). Se ejecuta con
// --update-goldens para ESCRIBIR los PNG en
// ~/workspace/melli-qui-v6-previews/ (nombres foto73_*). Viewport
// 393x852 (dpr 2), Roboto + MaterialIcons + Nunito reales. Las
// pantallas sueltas se montan con una réplica fiel del tema claro
// (melliLightTheme, copiado de preview_fix8_test.dart) o del oscuro
// (melliDarkTheme, réplica de _darkTheme en main.dart); la app
// completa, con MelliQuiApp. Los PNG se leen y se verifican a mano
// antes de informar.
//
// - foto73_boton_google_claro / _oscuro: botón "Continuar con
//   Google" arreglado (P2: la G ya no tapa la C).
// - foto73_splash_claro / _oscuro: SplashScreen (P3: el splash
//   nativo no se puede fotografiar en un test de widgets; esta es
//   la pantalla que sigue al splash nativo).
// - foto73_stats: Mis estadísticas, cápsula de vidas compacta (P6).
// - foto73_tabla_abajo_claro / _oscuro: tabla bajada del todo,
//   leyenda completa por encima de Comparar/Quiz (P7).
// - foto73_elemento_claro / _oscuro: Moscovio abierto, fondo
//   difuminado (P8).
// - foto73_barra: app completa, orden Aprender, Resolver, Niveles,
//   Tabla, Cuenta (P9).
// - foto73_constantes: conversor primero (P10).
// - foto73_menu_conversor: menú lateral, "Constantes y
//   conversiones" primera de Referencia (P10).
// - foto73_teclado_sencillo / _cientifico: calculadora según
//   dificultad (P11).
// - foto73_tabla_violeta: chips de la tabla en violeta (P12).
// - foto73_tabla_verde_oscuro: tabla en verde oscuro (P12).
// - foto73_ajustes_version: Ajustes, "Versión instalada: 1.0" (P13).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quimica_pura/widgets/brand_logo.dart';
import 'package:quimica_pura/widgets/element_sheet.dart';
import 'package:quimica_pura/widgets/google_sign_in_button.dart';
import 'package:quimica_pura/widgets/lucide_icons.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/calculator_screen.dart';
import 'package:quimica_pura/screens/constants_screen.dart';
import 'package:quimica_pura/screens/settings_screen.dart';
import 'package:quimica_pura/screens/splash_screen.dart';
import 'package:quimica_pura/screens/stats_screen.dart';
import 'package:quimica_pura/screens/tabla_screen.dart';
import 'package:quimica_pura/services/accent.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/social_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'test_helpers.dart';

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
class _Q73PreviewFake extends AndroidFlutterLocalNotificationsPlugin
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
    FlutterLocalNotificationsPlatform.instance = _Q73PreviewFake();
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
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = false;
    UserPrefs.isDark = false;
    UserPrefs.userName = '';
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
    // Las imágenes de assets (G de Google, anillo del splash) se
    // decodifican de forma asíncrona: sin estos pumps la captura
    // sale con el hueco en blanco (la foto73_boton_google_claro
    // salió sin la G y las dos de splash sin el anillo). Con 4 s
    // de pumps la imagen ya está pintada al capturar.
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

  /// Tabla bajada del todo (P7): arrastra el scroll hasta el final.
  Future<void> scrollTablaToBottom(WidgetTester tester) async {
    final scrollable = find.byType(SingleChildScrollView).first;
    await tester.drag(scrollable, const Offset(0, -10000));
    await tester.pumpAndSettle();
    expect(find.text('118 elementos.'), findsOneWidget);
  }

  /// Abre la hoja del elemento buscándolo por su símbolo (P8).
  Future<void> openElementSheet(
      WidgetTester tester, String symbol) async {
    await tester.tap(find.text(symbol).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  // Calentamiento: decodifica las imágenes (G de Google, anillo
  // del splash en claro y oscuro, gemelas) ANTES de la primera
  // captura, esperando la decodificación de verdad con runAsync +
  // precacheImage. Sin esto, la primera pantalla salía con la
  // imagen vacía: con solo hacer pump, la decodificación seguía
  // pendiente al capturar (la foto73_boton_google_claro salió sin
  // la G y las dos de splash sin el anillo).
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
      ]) {
        await precacheImage(AssetImage('assets/$name.png'), context);
      }
    });
    await settle(tester);
  });

  group('foto73 botón Google (P2)', () {
    testWidgets('foto73_boton_google_claro', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: GoogleSignInButton(onPressed: () {}),
            ),
          ),
        ),
      );
      await shot(tester, 'foto73_boton_google_claro.png');
    });

    testWidgets('foto73_boton_google_oscuro', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: GoogleSignInButton(onPressed: () {}),
            ),
          ),
        ),
        dark: true,
      );
      await shot(tester, 'foto73_boton_google_oscuro.png');
    });
  });

  group('foto73 splash (P3)', () {
    testWidgets('foto73_splash_claro', (tester) async {
      await pumpScreen(
        tester,
        SplashScreen(
          onDone: () {},
          holdDuration: const Duration(seconds: 60),
        ),
      );
      await shot(tester, 'foto73_splash_claro.png');
    });

    testWidgets('foto73_splash_oscuro', (tester) async {
      await pumpScreen(
        tester,
        SplashScreen(
          onDone: () {},
          holdDuration: const Duration(seconds: 60),
        ),
        dark: true,
      );
      await shot(tester, 'foto73_splash_oscuro.png');
    });
  });

  group('foto73 estadísticas (P6)', () {
    testWidgets('foto73_stats', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: StatsScreen(trackTopics: const ['estequiometria']),
        ),
      );
      await shot(tester, 'foto73_stats.png');
    });
  });

  group('foto73 tabla abajo (P7)', () {
    testWidgets('foto73_tabla_abajo_claro', (tester) async {
      await pumpScreen(tester, const Scaffold(body: TablaScreen()));
      await scrollTablaToBottom(tester);
      await shot(tester, 'foto73_tabla_abajo_claro.png');
    });

    testWidgets('foto73_tabla_abajo_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: TablaScreen()),
        dark: true,
      );
      await scrollTablaToBottom(tester);
      await shot(tester, 'foto73_tabla_abajo_oscuro.png');
    });
  });

  group('foto73 elemento con fondo difuminado (P8)', () {
    testWidgets('foto73_elemento_claro', (tester) async {
      await pumpScreen(tester, const Scaffold(body: TablaScreen()));
      // Moscovio (Z=115) está al final: buscarlo filtra la tabla.
      await tester.enterText(
          find.byType(TextField).first, 'Moscovio');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await openElementSheet(tester, 'Mc');
      // 'Moscovio' aparece 2 veces en el árbol: el título de la
      // hoja y el texto escrito en el buscador. La guarda busca el
      // título DENTRO de la hoja (la hoja está abierta).
      expect(
        find.descendant(
          of: find.byType(ElementSheet),
          matching: find.text('Moscovio'),
        ),
        findsOneWidget,
      );
      await shot(tester, 'foto73_elemento_claro.png');
    });

    testWidgets('foto73_elemento_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: TablaScreen()),
        dark: true,
      );
      await tester.enterText(
          find.byType(TextField).first, 'Moscovio');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await openElementSheet(tester, 'Mc');
      // 'Moscovio' aparece 2 veces en el árbol: el título de la
      // hoja y el texto escrito en el buscador. La guarda busca el
      // título DENTRO de la hoja (la hoja está abierta).
      expect(
        find.descendant(
          of: find.byType(ElementSheet),
          matching: find.text('Moscovio'),
        ),
        findsOneWidget,
      );
      await shot(tester, 'foto73_elemento_oscuro.png');
    });
  });

  group('foto73 barra y menú (P9, P10)', () {
    testWidgets('foto73_barra', (tester) async {
      await pumpApp(tester);
      expect(find.text('Aprender'), findsOneWidget);
      expect(find.text('Resolver'), findsOneWidget);
      await shot(tester, 'foto73_barra.png');
    });

    testWidgets('foto73_menu_conversor', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byWidgetPredicate(
          (w) => w is LucideIcon && w.icon == LucideIcons.menu));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // 'Constantes y conversiones' está en la sección Referencia,
      // abajo del todo del menú: hay que bajar dentro del cajón
      // para que se construya. scrollUntilVisible exige un
      // Scrollable, no un ListView (pasar el ListView rompe con
      // "ListView is not a subtype of Scrollable"): se busca el
      // Scrollable VERTICAL dentro del Drawer (el ListView del
      // cajón es el único scrollable vertical que hay ahí).
      await tester.scrollUntilVisible(
        find.text('Constantes y conversiones'),
        300,
        scrollable: find.descendant(
          of: find.byType(Drawer),
          matching: find.byWidgetPredicate((w) =>
              w is Scrollable &&
              w.axisDirection == AxisDirection.down),
        ),
      );
      await tester.pump();
      expect(find.text('Constantes y conversiones'), findsOneWidget);
      await shot(tester, 'foto73_menu_conversor.png');
    });
  });

  group('foto73 constantes (P10)', () {
    testWidgets('foto73_constantes', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: ConstantsScreen()),
      );
      await shot(tester, 'foto73_constantes.png');
    });
  });

  group('foto73 teclados (P11)', () {
    Future<void> openCalculator(
      WidgetTester tester, {
      required bool scientific,
    }) async {
      await setPhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: melliLightTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  CalculatorScreen.open(
                    context,
                    scientific: scientific,
                    submitResult: true,
                    unit: 'mol',
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

    testWidgets('foto73_teclado_sencillo', (tester) async {
      await openCalculator(tester, scientific: false);
      expect(find.text('log'), findsNothing);
      await shot(tester, 'foto73_teclado_sencillo.png');
    });

    testWidgets('foto73_teclado_cientifico', (tester) async {
      await openCalculator(tester, scientific: true);
      expect(find.text('log'), findsOneWidget);
      await shot(tester, 'foto73_teclado_cientifico.png');
    });
  });

  group('foto73 acento (P12)', () {
    testWidgets('foto73_tabla_violeta', (tester) async {
      UserPrefs.themeAccent = 'violeta';
      UserPrefs.themeAccentNotifier.value = 'violeta';
      await pumpScreen(tester, const Scaffold(body: TablaScreen()));
      final chip =
          tester.widget<ChoiceChip>(find.byType(ChoiceChip).first);
      expect(chip.selectedColor, BrandColors.violet);
      await shot(tester, 'foto73_tabla_violeta.png');
    });

    testWidgets('foto73_tabla_verde_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: TablaScreen()),
        dark: true,
      );
      await shot(tester, 'foto73_tabla_verde_oscuro.png');
    });
  });

  group('foto73 versión (P13)', () {
    testWidgets('foto73_ajustes_version', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: SettingsScreen(onOpenScreen: (_) {}),
        ),
      );
      expect(find.textContaining('Versión instalada: 1.0'),
          findsOneWidget);
      await shot(tester, 'foto73_ajustes_version.png');
    });
  });
}

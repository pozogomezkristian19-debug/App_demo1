// Auditoría Zona F (2026-11-12): contraste en AMBOS temas + acento
// Verde↔Violeta + wrap de Dalton. Se ejecuta con --update-goldens
// para ESCRIBIR los PNG en ~/workspace/melli-qui-v6-previews/
// (nombres zonef_*). Viewport 393x852 (dpr 2), Nunito real.
// La app completa se monta con MelliQuiApp (tema REAL, no réplica);
// las pantallas sueltas, con réplicas fieles claro/oscuro que leen
// AppAccent (igual que main.dart). Los PNG se leen a mano antes de
// informar. NO es un test de goldens estables: sus capturas son solo
// para la auditoría visual de esta zona.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quimica_pura/data/periodic_table.dart';
import 'package:quimica_pura/data/topics.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/calculator_screen.dart';
import 'package:quimica_pura/screens/duel_screen.dart';
import 'package:quimica_pura/screens/friends_screen.dart';
import 'package:quimica_pura/screens/groups_screen.dart';
import 'package:quimica_pura/screens/lab_sim_screen.dart';
import 'package:quimica_pura/screens/leaderboard_screen.dart';
import 'package:quimica_pura/screens/notes_screen.dart';
import 'package:quimica_pura/screens/practicar_screen.dart';
import 'package:quimica_pura/screens/shop_screen.dart';
import 'package:quimica_pura/screens/support_screen.dart';
import 'package:quimica_pura/screens/timed_exam_screen.dart';
import 'package:quimica_pura/screens/topic_detail_screen.dart';
import 'package:quimica_pura/screens/tournaments_screen.dart';
import 'package:quimica_pura/services/accent.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/social_service.dart';
import 'package:quimica_pura/services/support_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/brand_logo.dart';
import 'package:quimica_pura/widgets/element_sheet.dart';
import 'package:quimica_pura/widgets/twin_avatars.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'test_helpers.dart';

/// Réplica fiel del tema claro real (main.dart _lightTheme, ver
/// preview_fix8_test.dart): primario = AppAccent.primary.
ThemeData zfLightTheme() => ThemeData(
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
        error: const Color(0xFFFF4B4B),
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
        color: Color(0xFFE5E5E5),
        thickness: 1,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(AppAccent.primary),
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(8),
        thumbVisibility: WidgetStateProperty.all(true),
        trackVisibility: WidgetStateProperty.all(false),
        crossAxisMargin: 2,
        minThumbLength: 48,
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
              fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w800),
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
              fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppAccent.primary,
          backgroundColor: Colors.white,
          side: BorderSide(color: AppAccent.primary, width: 2),
          shape: DuoPillBorder(
              edgeColor: AppAccent.primary.withValues(alpha: 0.30)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
              fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppAccent.primary,
          textStyle: const TextStyle(
              fontFamily: 'Roboto', fontSize: 15, fontWeight: FontWeight.w700),
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
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
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
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: BrandColors.ink,
        contentTextStyle: TextStyle(
            fontFamily: 'Roboto', color: Colors.white, fontSize: 15),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppAccent.primary,
        linearTrackColor: BrandColors.cardGray,
      ),
      textTheme: const TextTheme(
        bodyMedium:
            TextStyle(fontSize: 16, height: 1.45, color: BrandColors.ink),
        bodyLarge:
            TextStyle(fontSize: 17, height: 1.45, color: BrandColors.ink),
        titleMedium: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700, color: BrandColors.ink),
        titleLarge: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800, color: BrandColors.ink),
      ).apply(fontFamily: 'Roboto'),
    );

/// Réplica fiel del tema oscuro real (main.dart _darkTheme): fondo
/// y primario siguen al acento (menta/violeta claro).
ThemeData zfDarkTheme() {
  final violet = AppAccent.isViolet;
  final bg = violet ? const Color(0xFF17112A) : const Color(0xFF131F24);
  final surface = violet ? const Color(0xFF241B3D) : const Color(0xFF1F2C34);
  final onSurface =
      violet ? const Color(0xFFEDE9F7) : const Color(0xFFE6F4EE);
  final primary = violet ? BrandColors.violetLight : BrandColors.mintLight;
  final secondary = violet ? BrandColors.violet : BrandColors.mint;
  final containerHighest =
      violet ? const Color(0xFF2E2350) : const Color(0xFF1B3A31);
  final buttonBg = violet ? BrandColors.violet : BrandColors.teal;
  final buttonShadow =
      violet ? BrandColors.violetDeep : BrandColors.tealDark;
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: ColorScheme.dark(
      primary: primary,
      onPrimary: bg,
      secondary: secondary,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: containerHighest,
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
    dividerTheme: const DividerThemeData(
      color: Color(0xFF37464F),
      thickness: 1,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(primary),
      thickness: WidgetStateProperty.all(6),
      radius: const Radius.circular(8),
      thumbVisibility: WidgetStateProperty.all(true),
      trackVisibility: WidgetStateProperty.all(false),
      crossAxisMargin: 2,
      minThumbLength: 48,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonBg,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: buttonShadow,
        surfaceTintColor: Colors.transparent,
        shape: DuoPillBorder(edgeColor: buttonShadow),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(
            fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: buttonBg,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: buttonShadow,
        surfaceTintColor: Colors.transparent,
        shape: DuoPillBorder(edgeColor: buttonShadow),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(
            fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        backgroundColor: surface,
        side: BorderSide(color: buttonBg, width: 2),
        shape: DuoPillBorder(edgeColor: primary.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(
            fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: const TextStyle(
            fontFamily: 'Roboto', fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? primary : Colors.white),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? primary.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: violet ? const Color(0xFF1C1533) : const Color(0xFF0F241E),
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
    snackBarTheme: SnackBarThemeData(
      backgroundColor: onSurface,
      contentTextStyle:
          TextStyle(fontFamily: 'Roboto', color: bg, fontSize: 15),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primary,
      linearTrackColor: containerHighest,
    ),
    textTheme: TextTheme(
      bodyMedium: TextStyle(fontSize: 16, height: 1.45, color: onSurface),
      bodyLarge: TextStyle(fontSize: 17, height: 1.45, color: onSurface),
      titleMedium: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600, color: onSurface),
      titleLarge: TextStyle(
          fontSize: 22, fontWeight: FontWeight.bold, color: onSurface),
    ).apply(fontFamily: 'Roboto'),
  );
}

class _ZfNotificationsFake extends AndroidFlutterLocalNotificationsPlugin
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
    String? body,
    String? payload,
    AndroidNotificationDetails? notificationDetails,
    String? title,
  }) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> zonedSchedule({
    required int id,
    String? body,
    required tz.TZDateTime scheduledDate,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
    AndroidNotificationDetails? notificationDetails,
    String? title,
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.exact,
  }) async {}
}

class _ZfSupportFake implements SupportService {
  final _messages = <SupportMessage>[
    SupportMessage(
      id: 'm1',
      authorUid: 'uid-kristian',
      username: 'kristian',
      message: 'No me sale el balanceo de la reacción del hierro',
      createdAt: DateTime(2026, 11, 11, 10, 0),
      status: 'respondido',
      reply: 'Revisa los coeficientes del oxígeno primero.',
      replyAt: DateTime(2026, 11, 11, 11, 0),
    ),
  ];

  @override
  Future<bool> sendMessage(String text) async => true;

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
    await loadNunitoFonts();
  });

  late InMemorySocialRepository repo;

  setUp(() async {
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
    FlutterLocalNotificationsPlatform.instance = _ZfNotificationsFake();
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

  Future<void> socialSettle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> warmCompanions(WidgetTester tester) async {
    final ctx = tester.element(find.byType(MaterialApp));
    for (final c in Companion.values) {
      await tester.runAsync(() async {
        await precacheImage(AssetImage(companionAsset(c)), ctx);
      });
    }
    await tester.pump();
  }

  /// App REAL con el acento y el modo pedidos.
  Future<void> pumpAppCombo(
    WidgetTester tester, {
    required String accent,
    required String mode,
  }) async {
    UserPrefs.themeAccent = accent;
    UserPrefs.themeAccentNotifier.value = accent;
    await UserPrefs.saveThemeMode(mode);
    UserPrefs.isDark = mode == 'oscuro';
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
  }

  /// Pantalla suelta con la réplica del tema (claro u oscuro), que
  /// lee el acento actual de AppAccent.
  Future<void> pumpScreenCombo(
    WidgetTester tester,
    Widget screen, {
    required String accent,
    required bool dark,
  }) async {
    UserPrefs.themeAccent = accent;
    UserPrefs.themeAccentNotifier.value = accent;
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? zfDarkTheme() : zfLightTheme(),
        darkTheme: zfDarkTheme(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: screen,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> goTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  // ---- App real: Aprender en las 4 combinaciones (el caso de la
  // captura: violeta+claro = píldoras violetas, barra teal). ----
  testWidgets('zonef_aprender_violeta_claro', (tester) async {
    await pumpAppCombo(tester, accent: 'violeta', mode: 'claro');
    await goTab(tester, tr('tabLearn'));
    await warmCompanions(tester);
    await shot(tester, 'zonef_aprender_violeta_claro.png');
  });

  testWidgets('zonef_aprender_verde_claro', (tester) async {
    await pumpAppCombo(tester, accent: 'verde', mode: 'claro');
    await goTab(tester, tr('tabLearn'));
    await warmCompanions(tester);
    await shot(tester, 'zonef_aprender_violeta_claro.png'.replaceAll('violeta', 'verde'));
  });

  testWidgets('zonef_aprender_violeta_oscuro', (tester) async {
    await pumpAppCombo(tester, accent: 'violeta', mode: 'oscuro');
    await goTab(tester, tr('tabLearn'));
    await warmCompanions(tester);
    await shot(tester, 'zonef_aprender_violeta_oscuro.png');
  });

  testWidgets('zonef_aprender_verde_oscuro', (tester) async {
    await pumpAppCombo(tester, accent: 'verde', mode: 'oscuro');
    await goTab(tester, tr('tabLearn'));
    await warmCompanions(tester);
    await shot(tester, 'zonef_aprender_verde_oscuro.png');
  });

  testWidgets('zonef_niveles_violeta_oscuro', (tester) async {
    await pumpAppCombo(tester, accent: 'violeta', mode: 'oscuro');
    await warmCompanions(tester);
    await shot(tester, 'zonef_niveles_violeta_oscuro.png');
  });

  testWidgets('zonef_niveles_verde_claro', (tester) async {
    await pumpAppCombo(tester, accent: 'verde', mode: 'claro');
    await warmCompanions(tester);
    await shot(tester, 'zonef_niveles_verde_claro.png');
  });

  // Banner del título más largo del camino (alcance 8, 2026-11-12):
  // "DISOLUCIONES Y CONCENTRACIÓN" (28 caracteres, el título más
  // largo de los 10 temas Uni + 4 Bach del camino de niveles) no
  // debe partir ninguna palabra ni cortarse: el FittedBox lo
  // reduce hasta que quepa en el banner. Sin excepciones de
  // desbordamiento. NOTA: 'fisicoquimica' (46 caracteres) es solo
  // un tema de contenido de Aprender y NO tiene banner de camino,
  // así que no se puede probar aquí; el mecanismo es el mismo para
  // todos los títulos.
  testWidgets('zonef_banner_disoluciones_violeta_claro',
      (tester) async {
    await pumpAppCombo(tester, accent: 'violeta', mode: 'claro');
    await warmCompanions(tester);
    final title = find.text('DISOLUCIONES Y CONCENTRACIÓN');
    await tester.scrollUntilVisible(title, 400, maxScrolls: 60);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await shot(tester, 'zonef_banner_disoluciones_violeta_claro.png');
  });

  testWidgets('zonef_cuenta_violeta_oscuro', (tester) async {
    await pumpAppCombo(tester, accent: 'violeta', mode: 'oscuro');
    await goTab(tester, tr('accountTitle'));
    await warmCompanions(tester);
    await shot(tester, 'zonef_cuenta_violeta_oscuro.png');
  });

  testWidgets('zonef_cuenta_verde_claro', (tester) async {
    await pumpAppCombo(tester, accent: 'verde', mode: 'claro');
    await goTab(tester, tr('accountTitle'));
    await warmCompanions(tester);
    await shot(tester, 'zonef_cuenta_verde_claro.png');
  });

  testWidgets('zonef_tema_violeta_oscuro', (tester) async {
    await pumpAppCombo(tester, accent: 'violeta', mode: 'oscuro');
    await goTab(tester, tr('accountTitle'));
    // La fila Tema ya NO vive en Cuenta (reorganización de la
    // Zona H, 2026-11-12): ahora está dentro de Ajustes, la
    // última fila de la lista (hay que bajar hasta ella).
    await tester.scrollUntilVisible(
        find.text(tr('settingsTitle')), 200);
    await tester.tap(find.text(tr('settingsTitle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(tr('themeTitle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await shot(tester, 'zonef_tema_violeta_oscuro.png');
  });

  testWidgets('zonef_tema_verde_claro', (tester) async {
    await pumpAppCombo(tester, accent: 'verde', mode: 'claro');
    await goTab(tester, tr('accountTitle'));
    await tester.scrollUntilVisible(
        find.text(tr('settingsTitle')), 200);
    await tester.tap(find.text(tr('settingsTitle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(tr('themeTitle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await shot(tester, 'zonef_tema_verde_claro.png');
  });

  testWidgets('zonef_tabla_violeta_claro', (tester) async {
    await pumpAppCombo(tester, accent: 'violeta', mode: 'claro');
    await goTab(tester, tr('tabTable'));
    await shot(tester, 'zonef_tabla_violeta_claro.png');
  });

  testWidgets('zonef_tabla_violeta_oscuro', (tester) async {
    await pumpAppCombo(tester, accent: 'violeta', mode: 'oscuro');
    await goTab(tester, tr('tabTable'));
    await shot(tester, 'zonef_tabla_violeta_oscuro.png');
  });

  testWidgets('zonef_resolver_violeta_oscuro', (tester) async {
    await pumpAppCombo(tester, accent: 'violeta', mode: 'oscuro');
    await goTab(tester, tr('tabResolver'));
    await shot(tester, 'zonef_resolver_violeta_oscuro.png');
  });

  testWidgets('zonef_glosario_violeta_oscuro', (tester) async {
    await pumpAppCombo(tester, accent: 'violeta', mode: 'oscuro');
    await goTab(tester, tr('tabLearn'));
    await tester.tap(find.text(tr('glossaryTitle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await shot(tester, 'zonef_glosario_violeta_oscuro.png');
  });

  testWidgets('zonef_topico_violeta_oscuro', (tester) async {
    await pumpAppCombo(tester, accent: 'violeta', mode: 'oscuro');
    await goTab(tester, tr('tabLearn'));
    final topic = topics
        .where((t) => t.slug != 'organica' && t.slug != 'laboratorio')
        .first;
    final topicFinder = find.text(topic.title);
    await tester.scrollUntilVisible(topicFinder, 300);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(topicFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await shot(tester, 'zonef_topico_violeta_oscuro.png');
  });

  // ---- Pregunta de nivel (burbuja mascota + opciones), oscuro
  // violeta y claro verde. ----
  testWidgets('zonef_pregunta_violeta_oscuro', (tester) async {
    await pumpScreenCombo(
      tester,
      Scaffold(body: PracticarScreen(onOpenScreen: (_) {})),
      accent: 'violeta',
      dark: true,
    );
    await warmCompanions(tester);
    final node = find.text('1').first;
    await tester.ensureVisible(node);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(node);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await warmCompanions(tester);
    await shot(tester, 'zonef_pregunta_violeta_oscuro.png');
  });

  testWidgets('zonef_pregunta_verde_claro', (tester) async {
    await pumpScreenCombo(
      tester,
      Scaffold(body: PracticarScreen(onOpenScreen: (_) {})),
      accent: 'verde',
      dark: false,
    );
    await warmCompanions(tester);
    final node = find.text('1').first;
    await tester.ensureVisible(node);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(node);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await warmCompanions(tester);
    await shot(tester, 'zonef_pregunta_verde_claro.png');
  });

  // ---- Pantallas sueltas: oscuro violeta (peor caso de contraste)
  // y claro violeta (caso del acento). ----
  testWidgets('zonef_tienda_violeta_oscuro', (tester) async {
    ProgressService.instance.addPoints(2000);
    await pumpScreenCombo(
      tester,
      const ShopScreen(isGoogleLinked: true),
      accent: 'violeta',
      dark: true,
    );
    await socialSettle(tester);
    await shot(tester, 'zonef_tienda_violeta_oscuro.png');
  });

  testWidgets('zonef_tienda_violeta_claro', (tester) async {
    ProgressService.instance.addPoints(2000);
    await pumpScreenCombo(
      tester,
      const ShopScreen(isGoogleLinked: true),
      accent: 'violeta',
      dark: false,
    );
    await socialSettle(tester);
    await shot(tester, 'zonef_tienda_violeta_claro.png');
  });

  testWidgets('zonef_amigos_violeta_oscuro', (tester) async {
    await pumpScreenCombo(
      tester,
      const FriendsScreen(isGoogleLinked: true),
      accent: 'violeta',
      dark: true,
    );
    await socialSettle(tester);
    await shot(tester, 'zonef_amigos_violeta_oscuro.png');
  });

  testWidgets('zonef_torneos_violeta_oscuro', (tester) async {
    await pumpScreenCombo(
      tester,
      const TournamentsScreen(isGoogleLinked: true),
      accent: 'violeta',
      dark: true,
    );
    await socialSettle(tester);
    await shot(tester, 'zonef_torneos_violeta_oscuro.png');
  });

  testWidgets('zonef_grupos_violeta_oscuro', (tester) async {
    await pumpScreenCombo(
      tester,
      const GroupsScreen(isGoogleLinked: true),
      accent: 'violeta',
      dark: true,
    );
    await socialSettle(tester);
    await shot(tester, 'zonef_grupos_violeta_oscuro.png');
  });

  testWidgets('zonef_tabla_pos_violeta_oscuro', (tester) async {
    final entries = kDemoSocialUsers
        .map((f) => LeaderboardEntry(
              deviceId: f.deviceId,
              username: f.username,
              points: f.points,
              levelsPassedTotal: f.levelsPassedTotal,
              streak: f.streak,
              avatarId: f.avatarId,
            ))
        .toList();
    await pumpScreenCombo(
      tester,
      LeaderboardScreen(
        entriesStream: Stream.value(entries),
        currentDeviceId: 'dev-kristian',
        isGoogleLinked: true,
      ),
      accent: 'violeta',
      dark: true,
    );
    await socialSettle(tester);
    await shot(tester, 'zonef_tabla_pos_violeta_oscuro.png');
  });

  testWidgets('zonef_soporte_violeta_oscuro', (tester) async {
    await pumpScreenCombo(
      tester,
      SupportScreen(isGoogleLinked: true, service: _ZfSupportFake()),
      accent: 'violeta',
      dark: true,
    );
    await socialSettle(tester);
    await shot(tester, 'zonef_soporte_violeta_oscuro.png');
  });

  testWidgets('zonef_duelo_violeta_oscuro', (tester) async {
    await pumpScreenCombo(
      tester,
      const DuelScreen(random: true, isGoogleLinked: true),
      accent: 'violeta',
      dark: true,
    );
    await tester.pump(const Duration(milliseconds: 600));
    await shot(tester, 'zonef_duelo_violeta_oscuro.png');
  });

  testWidgets('zonef_calculadora_violeta_oscuro', (tester) async {
    await pumpScreenCombo(
      tester,
      const CalculatorScreen(scientific: true),
      accent: 'violeta',
      dark: true,
    );
    await shot(tester, 'zonef_calculadora_violeta_oscuro.png');
  });

  testWidgets('zonef_labsim_violeta_oscuro', (tester) async {
    await pumpScreenCombo(
      tester,
      const LabSimScreen(),
      accent: 'violeta',
      dark: true,
    );
    await shot(tester, 'zonef_labsim_violeta_oscuro.png');
  });

  testWidgets('zonef_examen_violeta_oscuro', (tester) async {
    await pumpScreenCombo(
      tester,
      const TimedExamScreen(),
      accent: 'violeta',
      dark: true,
    );
    await tester.tap(find.text(tr('timedStart')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await shot(tester, 'zonef_examen_violeta_oscuro.png');
  });

  testWidgets('zonef_topico_detalle_violeta_claro', (tester) async {
    await pumpScreenCombo(
      tester,
      TopicDetailScreen(topic: topics.first),
      accent: 'violeta',
      dark: false,
    );
    await shot(tester, 'zonef_topico_detalle_violeta_claro.png');
  });

  testWidgets('zonef_cuaderno_violeta_oscuro', (tester) async {
    await pumpScreenCombo(
      tester,
      const NotesScreen(),
      accent: 'violeta',
      dark: true,
    );
    await shot(tester, 'zonef_cuaderno_violeta_oscuro.png');
  });

  // Hoja de detalle del elemento (Plata/Ag) — Alcance 5: debe
  // ser OPACA en claro y en oscuro (antes el degradado a primario
  // al 6 % dejaba ver la tabla a través). Se abre desde un botón
  // en una pantalla mínima con la réplica del tema.
  Future<void> pumpElementSheet(
    WidgetTester tester, {
    required String accent,
    required bool dark,
  }) async {
    UserPrefs.themeAccent = accent;
    UserPrefs.themeAccentNotifier.value = accent;
    await setPhone(tester);
    final silver = allElements.firstWhere((e) => e.atomicNumber == 47);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? zfDarkTheme() : zfLightTheme(),
        darkTheme: zfDarkTheme(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showElementSheet(context, silver),
                child: const Text('ABRIR'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('ABRIR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('zonef_elemento_violeta_claro', (tester) async {
    await pumpElementSheet(tester, accent: 'violeta', dark: false);
    await shot(tester, 'zonef_elemento_violeta_claro.png');
  });

  testWidgets('zonef_elemento_violeta_oscuro', (tester) async {
    await pumpElementSheet(tester, accent: 'violeta', dark: true);
    await shot(tester, 'zonef_elemento_violeta_oscuro.png');
  });

  // Recordatorios: ZONA G (2026-11-12) — no se audita aquí.
}

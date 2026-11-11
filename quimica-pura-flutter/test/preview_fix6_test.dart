// Vistas previas de la ronda #6 (Quemia 6.3). Se ejecuta con
// --update-goldens para ESCRIBIR los PNG en
// ~/workspace/melli-qui-v6-previews/ (nombres fix6_*). Viewport
// 393x852 (dpr 2), Roboto real + MaterialIcons reales. Las pantallas
// de la app real se montan con MelliQuiApp; las sueltas, con una
// réplica fiel de su tema claro (melliLightTheme, como en
// preview_fix2_test.dart). Los PNG se leen y se verifican a mano
// antes de informar.
// - fix6_niveles: Niveles SOLO con el camino (sin pregunta del día,
//   sin "Practicar de otra forma").
// - fix6_niveles_dark: Niveles en oscuro.
// - fix6_cuenta: Cuenta reordenada (Estadísticas, Mis errores,
//   Cómo se juega primero).
// - fix6_menu: menú hamburguesa rediseñado, en claro.
// - fix6_menu_dark: menú hamburguesa rediseñado, en oscuro.
// - fix6_reto: Reto con el jugador 1 fijo ("kristian (tú)", sin
//   campo editable) y el jugador 2 vacío.
// - fix6_recordatorios: Recordatorios con la sección de diagnóstico
//   visible (permiso, próxima, última, "Probar un aviso ahora",
//   batería).
// - fix6_resolver: Resolver solo con los solvers (sin simulador ni
//   formulario rápido).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/challenge_screen.dart';
import 'package:quimica_pura/screens/reminder_screen.dart';
import 'package:quimica_pura/services/accent.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/notification_inbox.dart';
import 'package:quimica_pura/services/notification_service.dart';
import 'package:quimica_pura/services/progress.dart';
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
    );

/// Fake del plugin de notificaciones para la vista previa de
/// Recordatorios (mismo patrón que preview_fix5_notifications_test.dart):
/// permiso concedido, sin programar nada de verdad.
class _Fix6PreviewFake extends AndroidFlutterLocalNotificationsPlugin
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadRobotoFonts();
    await loadMaterialIcons();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    await NotificationInbox.load();
    NotificationService.resetForTests();
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
    // Batería optimizada (el caso de Xiaomi): la tarjeta de
    // diagnóstico dice "Optimizado: puede retrasar los avisos".
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.melliqui/battery_settings'),
      (call) async {
        if (call.method == 'isIgnoringBatteryOptimizations') return false;
        return true;
      },
    );
    FlutterLocalNotificationsPlatform.instance = _Fix6PreviewFake();
    UserPrefs.rulesSeenV6 = true;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    await UserPrefs.saveThemeMode('claro');
    UserPrefs.isDark = false;
    UserPrefs.onboardingDone = true;
    UserPrefs.userName = 'kristian';
  });

  tearDown(() {
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = false;
    UserPrefs.isDark = false;
    UserPrefs.userName = '';
    NotificationInbox.resetForTests();
    NotificationService.resetForTests();
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

  Future<void> warmCompanions(WidgetTester tester) async {
    final ctx = tester.element(find.byType(MaterialApp));
    for (final c in Companion.values) {
      await precacheImage(AssetImage(companionAsset(c)), ctx);
    }
    await tester.pump();
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
  }

  Future<void> pumpDarkApp(WidgetTester tester) async {
    await UserPrefs.saveThemeMode('oscuro');
    UserPrefs.isDark = true;
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
  }

  Future<void> openDrawer(WidgetTester tester) async {
    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  // Calentamiento: decodifica las imágenes de los acompañantes ANTES
  // de la primera captura.
  testWidgets('warm-up imágenes', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Row(
            key: Key('warmup'),
            children: [
              Image(
                  image: AssetImage('assets/brenda.png'),
                  width: 40,
                  height: 40),
              Image(
                  image: AssetImage('assets/britany.png'),
                  width: 40,
                  height: 40),
              Image(
                  image: AssetImage('assets/kristian.png'),
                  width: 40,
                  height: 40),
              Image(
                  image: AssetImage('assets/whatsapp.png'),
                  width: 40,
                  height: 40),
            ],
          ),
        ),
      ),
    );
    final context = tester.element(find.byKey(const Key('warmup')));
    await tester.runAsync(() async {
      for (final name in ['brenda', 'britany', 'kristian']) {
        await precacheImage(AssetImage('assets/$name.png'), context);
      }
    });
    await settle(tester);
  });

  testWidgets('fix6_niveles: Niveles solo con el camino', (tester) async {
    await pumpApp(tester);
    expect(find.text('Pregunta del día'), findsNothing);
    expect(find.text(tr('practiceOtherWays')), findsNothing);
    await warmCompanions(tester);
    await shot(tester, 'fix6_niveles.png');
  });

  testWidgets('fix6_niveles_dark: Niveles en oscuro', (tester) async {
    await pumpDarkApp(tester);
    expect(find.text('Pregunta del día'), findsNothing);
    expect(find.text(tr('practiceOtherWays')), findsNothing);
    await warmCompanions(tester);
    await shot(tester, 'fix6_niveles_dark.png');
  });

  testWidgets('fix6_cuenta: Cuenta reordenada', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text(tr('accountTitle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Las tres primeras filas, en orden.
    final tiles = tester.widgetList<ListTile>(find.byType(ListTile));
    final titles =
        tiles.map((t) => (t.title as Text).data!).toList();
    expect(titles.sublist(0, 3), [
      tr('accountStats'),
      tr('accountReview'),
      tr('howToPlayTitle'),
    ]);
    await shot(tester, 'fix6_cuenta.png');
  });

  testWidgets('fix6_menu: menú hamburguesa rediseñado, en claro',
      (tester) async {
    await pumpApp(tester);
    await openDrawer(tester);
    expect(find.text('Quemia'), findsOneWidget);
    expect(find.text(tr('notesTitle')), findsNothing);
    await shot(tester, 'fix6_menu.png');
  });

  testWidgets('fix6_menu_dark: menú hamburguesa rediseñado, en oscuro',
      (tester) async {
    await pumpDarkApp(tester);
    await openDrawer(tester);
    expect(find.text('Quemia'), findsOneWidget);
    expect(find.text(tr('notesTitle')), findsNothing);
    await shot(tester, 'fix6_menu_dark.png');
  });

  testWidgets('fix6_reto: Reto con el jugador 1 fijo', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: melliLightTheme(),
        home: const Scaffold(body: ChallengeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('kristian (tú)'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await shot(tester, 'fix6_reto.png');
  });

  testWidgets('fix6_recordatorios: Recordatorios con el diagnóstico',
      (tester) async {
    // Próximo aviso fijo (mañana, 09:15): el golden es estable.
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final next =
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 15);
    SharedPreferences.setMockInitialValues({
      'melli_reminder_on': true,
      'melli_notif_next': next.toIso8601String(),
    });
    await UserPrefs.load();
    // Un aviso ya enviado, para que "Último aviso enviado" tenga
    // hora (hace 30 minutos: sale "hoy, HH:MM").
    final sent = DateTime.now().subtract(const Duration(minutes: 30));
    await NotificationInbox.add(
      id: 'reminder-${sent.millisecondsSinceEpoch}',
      kind: InboxKind.reminder,
      title: 'Hora de repasar',
      body: 'Tenías un recordatorio pendiente.',
    );
    await setPhone(tester);
    await tester.pumpWidget(
      const MaterialApp(home: ReminderScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Diagnóstico'), findsOneWidget);
    expect(find.text('Próximo aviso'), findsOneWidget);
    expect(find.text('Último aviso enviado'), findsOneWidget);
    expect(find.text('Ahorro de batería'), findsOneWidget);
    expect(find.text(tr('notifTest')), findsOneWidget);
    await shot(tester, 'fix6_recordatorios.png');
  });

  testWidgets('fix6_resolver: Resolver solo con los solvers',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text(tr('tabResolver')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(tr('labSimTitle')), findsNothing);
    expect(find.text(tr('menuFormulas')), findsNothing);
    await shot(tester, 'fix6_resolver.png');
  });
}

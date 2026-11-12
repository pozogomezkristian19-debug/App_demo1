// Vistas previas de la ronda #5, punto 1 (Quemia 6.2):
// notificaciones (fix5, punto 1).
// - fix5_notif_onboarding.png: pantalla de permiso del onboarding
//   ("Activar recordatorios", un solo botón).
// - fix5_notif_recordatorios_ok.png: Recordatorios con el permiso
//   concedido: interruptor ON, estado "concedido" y próximo aviso.
// - fix5_notif_recordatorios_no.png: Recordatorios con el permiso
//   denegado: interruptor OFF y estado "denegado" (sin próximo
//   aviso inventado).
// - fix5_notif_ajustes.png: el diálogo "Ir a Ajustes" con su texto
//   corto (ya no explica la ruta a mano).
// Se ejecuta con --update-goldens para ESCRIBIR los PNG en
// ~/workspace/melli-qui-v6-previews/ (nombres fix5_notif_*).
// Viewport 360x800 (dpr 2), Roboto real. Los PNG se leen y se
// verifican a mano antes de informar.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quimica_pura/screens/onboarding_screen.dart';
import 'package:quimica_pura/screens/reminder_screen.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'test_helpers.dart';

/// Fake del plugin de notificaciones para las vistas previas.
class _Fix5PreviewFake extends AndroidFlutterLocalNotificationsPlugin
    with MockPlatformInterfaceMixin {
  _Fix5PreviewFake({required this.permissionGranted});

  bool permissionGranted;

  @override
  Future<bool> initialize({
    required AndroidInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
  }) async =>
      true;

  @override
  Future<bool?> requestNotificationsPermission() async =>
      permissionGranted;

  @override
  Future<bool?> requestExactAlarmsPermission() async => true;

  @override
  Future<bool?> areNotificationsEnabled() async => permissionGranted;

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
    await UserPrefs.load();
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
      const MethodChannel('xyz.luan/audioplayers.global/events'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => null,
    );
    FlutterLocalNotificationsPlatform.instance =
        _Fix5PreviewFake(permissionGranted: true);
  });

  Future<void> setPhone(
    WidgetTester tester, {
    double width = 360,
    double height = 800,
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

  Future<void> pumpReminders(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ReminderScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Lleva el onboarding hasta la pantalla de permiso de
  /// notificaciones (después del nombre, antes del idioma).
  Future<void> goToNotificationsPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onFinished: () {})),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('SIGUIENTE'));
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byType(TextField), 'Kristian');
    await tester.tap(find.text('Masculino'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SIGUIENTE'));
    await tester.pumpAndSettle();
  }

  testWidgets('fix5_notif_onboarding: pantalla de permiso del '
      'onboarding', (tester) async {
    await setPhone(tester);
    await goToNotificationsPage(tester);
    await shot(tester, 'fix5_notif_onboarding.png');
  });

  testWidgets('fix5_notif_recordatorios_ok: Recordatorios con el '
      'permiso concedido', (tester) async {
    // Hora fija (mañana, 09:15): el golden es estable entre
    // corridas (con "ahora + 35 min" la hora cambiaba y el golden
    // fallaba al comparar).
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final next =
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 15);
    SharedPreferences.setMockInitialValues({
      'melli_reminder_on': true,
      'melli_notif_next': next.toIso8601String(),
    });
    await UserPrefs.load();
    await setPhone(tester);
    await pumpReminders(tester);
    await shot(tester, 'fix5_notif_recordatorios_ok.png');
  });

  testWidgets('fix5_notif_recordatorios_no: Recordatorios con el '
      'permiso denegado', (tester) async {
    FlutterLocalNotificationsPlatform.instance =
        _Fix5PreviewFake(permissionGranted: false);
    final next = DateTime.now().add(const Duration(minutes: 35));
    SharedPreferences.setMockInitialValues({
      'melli_reminder_on': true,
      'melli_notif_next': next.toIso8601String(),
    });
    await UserPrefs.load();
    await setPhone(tester);
    await pumpReminders(tester);
    await shot(tester, 'fix5_notif_recordatorios_no.png');
  });

  testWidgets('fix5_notif_ajustes: diálogo "Ir a Ajustes" con texto '
      'corto', (tester) async {
    FlutterLocalNotificationsPlatform.instance =
        _Fix5PreviewFake(permissionGranted: false);
    await setPhone(tester);
    await pumpReminders(tester);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, 'fix5_notif_ajustes.png');
  });
}

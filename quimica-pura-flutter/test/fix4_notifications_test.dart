// Pruebas de la ronda #4, punto 3: notificaciones denegadas.
// Cuando el permiso está denegado, la app ya no se queda en el toast
// "No se pudo activar: falta el permiso de notificaciones": muestra un
// diálogo que explica y ofrece "Ir a Ajustes" (abre los ajustes de
// notificaciones de la app con el propio plugin, sin dependencia ni
// código nativo nuevo). El flujo cubre el interruptor de Recordatorios,
// el botón "Probar un aviso ahora" y el diálogo en sí. El diálogo NO
// tiene "Ahora no": solo "Cerrar" e "Ir a Ajustes".
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quimica_pura/screens/reminder_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/notification_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/notification_settings_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'test_helpers.dart';

/// Fake del plugin de notificaciones: simula el permiso (concedido o
/// negado, según el test) y anota si se pidió abrir los ajustes.
/// `areNotificationsEnabled` y `openAppNotificationSettings` se
/// sobrescriben aquí: en la implementación real van por el canal
/// nativo 'flutter_local_notifications', y sin sobrescribirlas la
/// llamada se quedaría colgada en pruebas.
class _Fix4FakeNotifications extends AndroidFlutterLocalNotificationsPlugin
    with MockPlatformInterfaceMixin {
  _Fix4FakeNotifications({required this.permissionGranted});

  bool permissionGranted;

  /// ¿Se pidió abrir los ajustes de notificaciones de la app?
  bool settingsOpened = false;

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
  Future<bool?> openAppNotificationSettings() async {
    settingsOpened = true;
    return true;
  }

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
  setUpAll(loadRobotoFonts);

  late _Fix4FakeNotifications fake;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'melli_rules_seen_v6': true});
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
    // Permiso NEGADO por defecto (cada test de concedido lo cambia).
    fake = _Fix4FakeNotifications(permissionGranted: false);
    FlutterLocalNotificationsPlatform.instance = fake;
  });

  group('Servicio: permiso denegado', () {
    test('isPermissionGranted es false con el permiso denegado', () async {
      expect(await NotificationService.isPermissionGranted, isFalse);
      fake.permissionGranted = true;
      expect(await NotificationService.isPermissionGranted, isTrue);
    });

    test('requestPermission devuelve false si sigue denegado', () async {
      expect(await NotificationService.requestPermission(), isFalse);
      fake.permissionGranted = true;
      expect(await NotificationService.requestPermission(), isTrue);
    });

    test('openNotificationSettings abre los ajustes y devuelve true',
        () async {
      expect(await NotificationService.openNotificationSettings(), isTrue);
      expect(fake.settingsOpened, isTrue);
    });

    test('enable() devuelve false con el permiso denegado (no programa '
        'nada)', () async {
      expect(await NotificationService.enable(), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('melli_notif_next'), isNull);
    });
  });

  group('Diálogo de Ajustes (widget)', () {
    /// Pantalla con un botón que abre el diálogo y anota el resultado
    /// en [results] (sin depender de un rebuild: la variable local
    /// dentro del Builder no repintaría sola).
    Future<void> pumpDialogOpener(
        WidgetTester tester, List<bool> results) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  results.add(await showNotificationSettingsDialog(context));
                },
                child: const Text('Abrir diálogo'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Abrir diálogo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('notifSettingsTitle')), findsOneWidget);
      expect(find.text(tr('notifSettingsBody')), findsOneWidget);
      // Sin "Ahora no": solo Cerrar e Ir a Ajustes.
      expect(find.text('Ahora no'), findsNothing);
      expect(find.text(tr('notifSettingsClose')), findsOneWidget);
      expect(find.text(tr('notifGoSettings')), findsOneWidget);
    }

    testWidgets('"Ir a Ajustes" abre los ajustes y devuelve true',
        (tester) async {
      final results = <bool>[];
      await pumpDialogOpener(tester, results);
      await tester.tap(find.text(tr('notifGoSettings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(results, [true]);
      expect(fake.settingsOpened, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Cerrar" cierra sin abrir ajustes y devuelve false',
        (tester) async {
      final results = <bool>[];
      await pumpDialogOpener(tester, results);
      await tester.tap(find.text(tr('notifSettingsClose')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(results, [false]);
      expect(fake.settingsOpened, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('Recordatorios: el interruptor y la prueba', () {
    Future<void> pumpReminders(WidgetTester tester) async {
      // Ventana ALTA (800x1400): la tarjeta nueva de canales
      // (corrección ronda #7) alarga la lista y, con el alto por
      // defecto (600), el botón de prueba quedaba fuera del área
      // construida del ListView y find.text no lo encontraba.
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        const MaterialApp(home: ReminderScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('con el permiso denegado, el interruptor muestra el '
        'diálogo de Ajustes y queda apagado', (tester) async {
      await pumpReminders(tester);
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isFalse);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('notifSettingsTitle')), findsOneWidget);
      await tester.tap(find.text(tr('notifGoSettings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(fake.settingsOpened, isTrue);
      // El interruptor sigue apagado: el permiso no se concedió.
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Probar un aviso ahora" con el permiso denegado muestra '
        'el diálogo (no dice "enviado")', (tester) async {
      await pumpReminders(tester);
      await tester.tap(find.text(tr('notifTest').toUpperCase()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('notifSettingsTitle')), findsOneWidget);
      expect(find.text(tr('notifSent')), findsNothing);
      await tester.tap(find.text(tr('notifSettingsClose')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(fake.settingsOpened, isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}

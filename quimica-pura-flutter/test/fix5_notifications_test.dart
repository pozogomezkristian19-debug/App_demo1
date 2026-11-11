// Pruebas de la ronda #5, punto 1 (Quemia 6.2): notificaciones.
//
// Causas verificadas (ver lib/services/notification_service.dart):
//  1. enable() pedía las alarmas exactas con requestExactAlarmsPermission()
//     justo después del diálogo del permiso: en Android 12+ eso abre
//     los Ajustes del sistema ("Alarmas y recordatorios"), y eso era
//     lo que Kristian veía como "una explicación de cómo activar" en
//     vez de una petición. Ahora ya NO se piden ni se consultan: al
//     programar se prueban las exactas (el plugin falla antes de
//     programar si no están concedidas) y se vuelve a inexactas.
//  2. Denegación permanente: tras dos negativas el sistema ya no muestra
//     su diálogo y requestPermission() devuelve false en el acto; el
//     único camino es "Ir a Ajustes", de un toque y con texto corto, y
//     al volver se re-comprueba y se activa solo (en el onboarding
//     faltaba ese re-chequeo).
//  3. Al concederse el permiso no salía ningún aviso: ahora enable()
//     dispara UNA notificación inmediata de confirmación para que se
//     VEA que funciona.
//  4. El interruptor de Recordatorios reflejaba solo la preferencia
//     guardada: si el permiso se revocaba en Ajustes, seguía en ON.
//     Ahora refleja el permiso real y la pantalla muestra su estado.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quimica_pura/screens/onboarding_screen.dart';
import 'package:quimica_pura/screens/reminder_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/notification_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/notification_settings_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'test_helpers.dart';

/// Fake del plugin de notificaciones: simula el permiso (concedido o
/// negado), si las alarmas exactas están concedidas, y anota cada
/// llamada (petición de alarmas exactas, avisos mostrados, alarmas
/// programadas, apertura de ajustes). Como el plugin real,
/// zonedSchedule con modo exacto LANZA si las alarmas exactas no
/// están concedidas (antes de programar nada): así se prueba el
/// repliegue a inexactas de _scheduleOne.
class _Fix5FakeNotifications extends AndroidFlutterLocalNotificationsPlugin
    with MockPlatformInterfaceMixin {
  _Fix5FakeNotifications({required this.permissionGranted});

  bool permissionGranted;

  /// ¿Las alarmas exactas están concedidas?
  bool canScheduleExact = true;

  /// ¿requestNotificationsPermission() lanza una excepción?
  bool requestThrows = false;

  /// ¿Se pidió abrir los ajustes de notificaciones de la app?
  bool settingsOpened = false;

  /// ¿Se llamó a requestExactAlarmsPermission() (la que abre los
  /// Ajustes del sistema)? En fix5 NO debe llamarse nunca.
  bool exactAlarmsRequested = false;

  /// Avisos inmediatos mostrados (id, título, cuerpo).
  final shown = <({int id, String? title, String? body})>[];

  /// Alarmas programadas con éxito con zonedSchedule().
  var zonedScheduled = 0;

  @override
  Future<bool> initialize({
    required AndroidInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
  }) async =>
      true;

  @override
  Future<bool?> requestNotificationsPermission() async {
    if (requestThrows) {
      throw PlatformException(code: 'PERMISSION_REQUEST_IN_PROGRESS');
    }
    return permissionGranted;
  }

  @override
  Future<bool?> requestExactAlarmsPermission() async {
    exactAlarmsRequested = true;
    return true;
  }

  @override
  Future<bool?> areNotificationsEnabled() async => permissionGranted;

  @override
  Future<bool?> openAppNotificationSettings() async {
    settingsOpened = true;
    return true;
  }

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    String? payload,
    AndroidNotificationDetails? notificationDetails,
  }) async {
    shown.add((id: id, title: title, body: body));
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
  }) async {
    if (scheduleMode == AndroidScheduleMode.exactAllowWhileIdle &&
        !canScheduleExact) {
      throw PlatformException(code: 'exact_alarms_not_permitted');
    }
    zonedScheduled++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  late _Fix5FakeNotifications fake;

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
    // Permiso CONCEDIDO por defecto (cada test de negado lo cambia).
    fake = _Fix5FakeNotifications(permissionGranted: true);
    FlutterLocalNotificationsPlatform.instance = fake;
  });

  tearDown(() {
    AppLang.code = 'es';
  });

  group('Cadenas nuevas (6 idiomas)', () {
    test('notifEnabledConfirm, notifPermGranted y notifPermDenied existen '
        'en los 6 idiomas y no están vacías', () {
      const keys = [
        'notifEnabledConfirm',
        'notifPermGranted',
        'notifPermDenied',
        'notifSettingsBody',
      ];
      for (final lang in ['es', 'en', 'fr', 'it', 'pt', 'ru']) {
        for (final key in keys) {
          final value = AppLang.allStrings[lang]?[key];
          expect(value, isNotNull, reason: '$lang: falta $key');
          expect(value!.trim(), isNotEmpty, reason: '$lang: $key vacío');
        }
      }
    });

    test('el diálogo de Ajustes ya no explica la ruta a mano (texto '
        'corto)', () {
      AppLang.code = 'es';
      expect(tr('notifSettingsBody').contains('Apps →'), isFalse);
      expect(tr('notifSettingsBody').contains('Ir a Ajustes'), isTrue);
      expect(tr('notifSettingsBody').length, lessThan(90));
    });
  });

  group('Servicio: activar con el permiso concedido', () {
    test('enable() NO abre los Ajustes de alarmas exactas: las exactas '
        'se prueban al programar, no se piden', () async {
      expect(await NotificationService.enable(), isTrue);
      expect(fake.exactAlarmsRequested, isFalse,
          reason: 'requestExactAlarmsPermission abre los Ajustes del '
              'sistema: ya no se llama');
      expect(NotificationService.exactAlarmsOn, isTrue);
      expect(NotificationService.scheduleMode,
          AndroidScheduleMode.exactAllowWhileIdle);
    });

    test('enable() con alarmas exactas no concedidas usa inexactas '
        'sin abrir Ajustes (el primer intento exacto falla y se '
        'reprograma)', () async {
      fake.canScheduleExact = false;
      expect(await NotificationService.enable(), isTrue);
      expect(fake.exactAlarmsRequested, isFalse);
      expect(NotificationService.exactAlarmsOn, isFalse);
      expect(NotificationService.scheduleMode,
          AndroidScheduleMode.inexactAllowWhileIdle);
      // La tanda sale igual: 3 avisos programados (el primero, tras
      // fallar en exacto, se reprogramó inexacto).
      expect(fake.zonedScheduled, 3);
    });

    test('enable() con el permiso concedido dispara UNA notificación '
        'de confirmación inmediata', () async {
      expect(await NotificationService.enable(), isTrue);
      expect(fake.shown, hasLength(1));
      expect(fake.shown.single.id, 9998);
      expect(fake.shown.single.title, 'Quemia');
      expect(fake.shown.single.body, tr('notifEnabledConfirm'));
      expect(UserPrefs.reminderOn, isTrue);
      expect(fake.zonedScheduled, 3);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('melli_notif_next'), isNotNull);
    });

    test('sendEnabledConfirmation() muestra el aviso y devuelve true',
        () async {
      expect(await NotificationService.sendEnabledConfirmation(), isTrue);
      expect(fake.shown, hasLength(1));
      expect(fake.shown.single.body, tr('notifEnabledConfirm'));
    });
  });

  group('Servicio: permiso denegado', () {
    test('enable() devuelve false, no programa nada ni confirma',
        () async {
      fake.permissionGranted = false;
      expect(await NotificationService.enable(), isFalse);
      expect(fake.shown, isEmpty);
      expect(fake.zonedScheduled, 0);
      expect(UserPrefs.reminderOn, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('melli_notif_next'), isNull);
    });

    test('scheduleNext sin permiso no programa nada y borra la tanda '
        'vieja', () async {
      fake.permissionGranted = false;
      final next = DateTime.now().add(const Duration(minutes: 30));
      SharedPreferences.setMockInitialValues({
        'melli_notif_next': next.toIso8601String(),
      });
      expect(await NotificationService.scheduleNext(), isEmpty);
      expect(fake.zonedScheduled, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('melli_notif_next'), isNull);
    });

    test('scheduleNext con permiso programa 3 avisos (primero en '
        '20-50 min)', () async {
      final scheduled = await NotificationService.scheduleNext();
      expect(scheduled, hasLength(3));
      expect(fake.zonedScheduled, 3);
      final now = DateTime.now();
      final firstGap = scheduled.first.difference(now).inMinutes;
      expect(firstGap, greaterThanOrEqualTo(19));
      expect(firstGap, lessThanOrEqualTo(51));
      for (var i = 1; i < scheduled.length; i++) {
        final gap =
            scheduled[i].difference(scheduled[i - 1]).inMinutes;
        expect(gap, greaterThanOrEqualTo(60));
        expect(gap, lessThanOrEqualTo(181));
      }
    });
  });

  group('Servicio: la petición no puede mentir', () {
    test('requestPermission devuelve false si la petición lanza una '
        'excepción (antes devolvía true)', () async {
      fake.requestThrows = true;
      expect(await NotificationService.requestPermission(), isFalse);
      expect(await NotificationService.enable(), isFalse);
      expect(UserPrefs.reminderOn, isFalse);
      expect(fake.shown, isEmpty);
    });

    test('isPermissionGranted y requestPermission coinciden con el '
        'permiso denegado', () async {
      fake.permissionGranted = false;
      expect(await NotificationService.isPermissionGranted, isFalse);
      expect(await NotificationService.requestPermission(), isFalse);
      fake.permissionGranted = true;
      expect(await NotificationService.isPermissionGranted, isTrue);
      expect(await NotificationService.requestPermission(), isTrue);
    });
  });

  group('Diálogo de Ajustes (widget)', () {
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
  });

  group('Recordatorios: el interruptor refleja el permiso real', () {
    Future<void> pumpReminders(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ReminderScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('permiso concedido + recordatorios ON: interruptor ON, '
        'estado "concedido" y próximo aviso visible', (tester) async {
      final next = DateTime.now().add(const Duration(minutes: 35));
      SharedPreferences.setMockInitialValues({
        'melli_reminder_on': true,
        'melli_notif_next': next.toIso8601String(),
      });
      await UserPrefs.load();
      await pumpReminders(tester);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(find.text(tr('notifPermGranted')), findsOneWidget);
      expect(find.text(tr('notifPermDenied')), findsNothing);
      expect(find.text('Próximo aviso'), findsOneWidget);
      final timeStr =
          '${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')}';
      expect(find.textContaining(timeStr), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('permiso revocado con recordatorios ON: el interruptor '
        'queda APAGADO, estado "denegado" y sin próximo aviso',
        (tester) async {
      fake.permissionGranted = false;
      final next = DateTime.now().add(const Duration(minutes: 35));
      SharedPreferences.setMockInitialValues({
        'melli_reminder_on': true,
        'melli_notif_next': next.toIso8601String(),
      });
      await UserPrefs.load();
      await pumpReminders(tester);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(find.text(tr('notifPermDenied')), findsOneWidget);
      expect(find.text(tr('notifPermGranted')), findsNothing);
      expect(find.text('Próximo aviso'), findsNothing);
      // Reconciliado: la preferencia ya no dice que están activos.
      expect(UserPrefs.reminderOn, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('al activar el interruptor con permiso concedido sale '
        'la confirmación inmediata y el interruptor queda ON',
        (tester) async {
      await pumpReminders(tester);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      await tester.tap(find.byType(Switch));
      // scheduleNext copia el icono grande (tope de 3 s en pruebas).
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(find.text(tr('notifPermGranted')), findsOneWidget);
      expect(fake.exactAlarmsRequested, isFalse);
      expect(
          fake.shown
              .where((s) => s.body == tr('notifEnabledConfirm')),
          hasLength(1));
      expect(UserPrefs.reminderOn, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('al activar el interruptor con permiso denegado sale '
        'el diálogo (texto corto) y el interruptor queda OFF',
        (tester) async {
      fake.permissionGranted = false;
      await pumpReminders(tester);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('notifSettingsTitle')), findsOneWidget);
      expect(find.text(tr('notifSettingsBody')), findsOneWidget);
      expect(find.text(tr('notifPermDenied')), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(fake.shown, isEmpty);
      await tester.tap(find.text(tr('notifGoSettings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(fake.settingsOpened, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Probar un aviso ahora" con el permiso denegado muestra '
        'el diálogo (no dice "enviado")', (tester) async {
      fake.permissionGranted = false;
      await pumpReminders(tester);
      await tester.tap(find.text(tr('notifTest')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('notifSettingsTitle')), findsOneWidget);
      expect(find.text(tr('notifSent')), findsNothing);
      expect(fake.shown, isEmpty);
      await tester.tap(find.text(tr('notifSettingsClose')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(fake.settingsOpened, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('al volver de Ajustes con el permiso ya concedido, los '
        'recordatorios se activan solos', (tester) async {
      fake.permissionGranted = false;
      await pumpReminders(tester);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(tr('notifGoSettings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(fake.settingsOpened, isTrue);
      // El usuario concede en Ajustes y vuelve a la app.
      fake.permissionGranted = true;
      tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(UserPrefs.reminderOn, isTrue);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(
          fake.shown
              .where((s) => s.body == tr('notifEnabledConfirm')),
          hasLength(1));
      expect(tester.takeException(), isNull);
    });
  });

  group('Onboarding: pedir directo y re-chequear al volver', () {
    /// Lleva el onboarding hasta la pantalla de permiso de
    /// notificaciones (después del nombre, antes del idioma).
    Future<void> goToNotificationsPage(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onFinished: () {})),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();
      }
      await tester.enterText(find.byType(TextField), 'Kristian');
      await tester.tap(find.text('Masculino'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
    }

    testWidgets('con el permiso concedido, "Activar recordatorios" '
        'dispara la confirmación y avanza al idioma', (tester) async {
      await goToNotificationsPage(tester);
      expect(find.text('Activar recordatorios'), findsOneWidget);
      await tester.tap(find.text('Activar recordatorios'));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Finalizar'), findsOneWidget);
      expect(UserPrefs.reminderOn, isTrue);
      expect(fake.exactAlarmsRequested, isFalse);
      expect(
          fake.shown
              .where((s) => s.body == tr('notifEnabledConfirm')),
          hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('con el permiso denegado, sale "Ir a Ajustes" y al '
        'volver con el permiso dado se activa solo', (tester) async {
      fake.permissionGranted = false;
      await goToNotificationsPage(tester);
      await tester.tap(find.text('Activar recordatorios'));
      await tester.pumpAndSettle();
      expect(find.text('Ir a Ajustes'), findsOneWidget);
      await tester.tap(find.text('Ir a Ajustes'));
      await tester.pumpAndSettle();
      expect(fake.settingsOpened, isTrue);
      // Todavía NO se avanzó: si se avanzara, el PageView destruye
      // esta página y el re-chequeo al volver no podría dispararse.
      expect(find.text('Activar recordatorios'), findsOneWidget);
      expect(find.text('Finalizar'), findsNothing);
      // El usuario concede en Ajustes y vuelve a la app.
      fake.permissionGranted = true;
      tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(UserPrefs.reminderOn, isTrue);
      expect(find.text('Finalizar'), findsOneWidget);
      expect(
          fake.shown
              .where((s) => s.body == tr('notifEnabledConfirm')),
          hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('con el permiso denegado y "Cerrar" en el diálogo, '
        'se avanza igual al idioma sin activar nada', (tester) async {
      fake.permissionGranted = false;
      await goToNotificationsPage(tester);
      await tester.tap(find.text('Activar recordatorios'));
      await tester.pumpAndSettle();
      expect(find.text('Ir a Ajustes'), findsOneWidget);
      await tester.tap(find.text(tr('notifSettingsClose')));
      await tester.pumpAndSettle();
      expect(find.text('Finalizar'), findsOneWidget);
      expect(UserPrefs.reminderOn, isFalse);
      expect(fake.settingsOpened, isFalse);
      expect(fake.shown, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}

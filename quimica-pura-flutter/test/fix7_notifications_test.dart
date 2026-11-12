// Pruebas de la ronda #7 (Quemia 6.4): el botón "Probar un aviso
// ahora" de Recordatorios, ahora honesto.
//
// Bug de la 6.3: con el permiso denegado de forma permanente, el
// usuario iba a Ajustes, lo concedía y volvía... y el aviso nunca
// se mandaba solo: había que tocar "Probar un aviso ahora" otra vez
// y nada se lo decía. Además sendTest() devolvía void y la pantalla
// decía "Aviso enviado" aunque el show() hubiera fallado.
//
// Arreglos que se prueban aquí (ver
// lib/services/notification_service.dart y
// lib/screens/reminder_screen.dart):
//  1. Aviso pendiente: al mandar al usuario a Ajustes desde el botón
//     de prueba, se marca el pendiente (markTestPending) y, al volver
//     con el permiso concedido, _recheckPermission manda la prueba
//     SOLA (sin encender los recordatorios) y muestra
//     tr('notifSent'). El pendiente se consume una sola vez.
//  2. sendTest honesto: devuelve Future<bool> — true solo si el
//     show() completó sin lanzar; si lanza, false, sin registrar
//     hora de envío, y la pantalla muestra tr('notifTestFailedSystem')
//     (nunca tr('notifSent')).
//  3. Canal propio: la prueba 9999 y la confirmación 9998 usan el
//     canal 'quemia_prueba_avisos' con Importance.high; los
//     programados siguen en 'melli_study_reminders'.
//  4. init() que falla no impide la prueba: sendTest() sigue
//     devolviendo true y el 9999 sale.
//  5. Canal bloqueado: isTestChannelBlocked() detecta el canal de
//     prueba con Importance.none.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quimica_pura/screens/reminder_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/notification_inbox.dart';
import 'package:quimica_pura/services/notification_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'test_helpers.dart';

/// Fake del plugin de notificaciones para la ronda #7: el de fix6
/// (_Fix6FakeNotifications), EXTENDIDO para lo nuevo:
///  - anota los notificationDetails de show() ([shownDetails]) y de
///    zonedSchedule() ([scheduledDetails]): canal e importancia, para
///    verificar que la prueba y la confirmación usan el canal propio
///    y que los programados siguen en el suyo;
///  - override de getNotificationChannels() (plural: la 23.0.0 NO
///    tiene getNotificationChannel(id) en singular; el servicio
///    busca el canal de prueba en esa lista): devuelve [channels],
///    con importancia configurable por test;
///  - flag [showThrows]: show() lanza, para simular un fallo del
///    sistema al mostrar el aviso.
class _Fix7FakeNotifications extends AndroidFlutterLocalNotificationsPlugin
    with MockPlatformInterfaceMixin {
  _Fix7FakeNotifications({required this.permissionGranted});

  bool permissionGranted;

  /// ¿Las alarmas exactas están concedidas?
  bool canScheduleExact = true;

  /// ¿Se llamó a requestNotificationsPermission()?
  bool requestCalled = false;

  /// ¿initialize() lanza una excepción?
  bool initializeThrows = false;

  /// ¿show() lanza una excepción (fallo del sistema)?
  bool showThrows = false;

  /// ¿Se abrió los ajustes de notificaciones de la app?
  bool settingsOpened = false;

  /// Canales que devuelve getNotificationChannels().
  List<AndroidNotificationChannel> channels = const [];

  /// Avisos inmediatos mostrados (id, título, cuerpo).
  final shown = <({int id, String? title, String? body})>[];

  /// Detalles de cada show(): canal e importancia.
  final shownDetails =
      <({int id, String? channelId, Importance? importance})>[];

  /// Detalles de cada zonedSchedule(): canal e importancia.
  final scheduledDetails =
      <({int id, String? channelId, Importance? importance})>[];

  /// Alarmas programadas con éxito con zonedSchedule().
  var zonedScheduled = 0;

  /// Modos con los que se programó (para comprobar el repliegue).
  final scheduledModes = <AndroidScheduleMode>[];

  @override
  Future<bool> initialize({
    required AndroidInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
  }) async {
    if (initializeThrows) {
      throw PlatformException(code: 'INIT_FAILED');
    }
    return true;
  }

  @override
  Future<bool?> requestNotificationsPermission() async {
    requestCalled = true;
    return permissionGranted;
  }

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
  Future<List<AndroidNotificationChannel>?> getNotificationChannels() async =>
      channels;

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    String? payload,
    AndroidNotificationDetails? notificationDetails,
  }) async {
    if (showThrows) {
      throw PlatformException(code: 'SHOW_FAILED');
    }
    shown.add((id: id, title: title, body: body));
    shownDetails.add((
      id: id,
      channelId: notificationDetails?.channelId,
      importance: notificationDetails?.importance,
    ));
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
    scheduledModes.add(scheduleMode);
    scheduledDetails.add((
      id: id,
      channelId: notificationDetails?.channelId,
      importance: notificationDetails?.importance,
    ));
    zonedScheduled++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  late _Fix7FakeNotifications fake;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserPrefs.load();
    NotificationInbox.resetForTests();
    // Servicio "frío" en cada test: sin inicializar y sin alarmas
    // exactas (como al abrir la app por primera vez).
    NotificationService.resetForTests();
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
    fake = _Fix7FakeNotifications(permissionGranted: true);
    FlutterLocalNotificationsPlatform.instance = fake;
  });

  tearDown(() {
    AppLang.code = 'es';
  });

  Future<void> pumpReminders(WidgetTester tester) async {
    // Ventana ALTA (800x1400): con el alto por defecto (600) el
    // botón de prueba quedaba fuera del área construida del
    // ListView y find.text no lo encontraba. La pantalla
    // simplificada es corta, pero se mantiene el alto por si el
    // teclado o los snackbars empujan el contenido.
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

  group('Ronda #7 (1): aviso pendiente tras ir a Ajustes', () {
    testWidgets('con permiso denegado, tocar la prueba → Ajustes → '
        'volver con permiso → el 9999 se manda SOLO', (tester) async {
      fake.permissionGranted = false;
      await pumpReminders(tester);
      expect(fake.shown, isEmpty);

      // Tocar el botón de prueba con el permiso denegado: sale el
      // diálogo de Ajustes (no dice "enviado").
      await tester.tap(find.text(tr('notifTest').toUpperCase()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('notifSettingsTitle')), findsOneWidget);
      expect(find.text(tr('notifSent')), findsNothing);
      expect(fake.shown, isEmpty);

      // "Ir a Ajustes": se abre los ajustes y queda el aviso
      // pendiente ("al volver... se enviará solo").
      await tester.tap(find.text(tr('notifGoSettings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(fake.settingsOpened, isTrue);
      expect(find.text(tr('notifTestPending')), findsOneWidget);

      // El usuario concede el permiso en Ajustes y vuelve a la app.
      fake.permissionGranted = true;
      tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed);
      // La copia del icono grande tiene un tope de 3 s en pruebas.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // El aviso se mandó SOLO, una sola vez, con su snackbar, y
      // queda registrada la hora de último envío.
      expect(
          fake.shown.where((s) => s.id == 9999), hasLength(1),
          reason: 'la prueba pendiente se envía una sola vez, no en '
              'bucle ni al volver otra vez');
      expect(find.text(tr('notifSent')), findsOneWidget);
      expect(find.text(tr('notifTestPending')), findsNothing);
      final got = await NotificationService.lastReminderSentTime();
      expect(got, isNotNull);
      expect(
          DateTime.now().difference(got!).inMinutes.abs(), lessThanOrEqualTo(1));
      // La prueba NO enciende los recordatorios: solo se pidió
      // probar, no activar (el pendiente de confirmación no se
      // marcó).
      expect(UserPrefs.reminderOn, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('si al volver el permiso sigue denegado, el pendiente '
        'se descarta y no se manda nada', (tester) async {
      fake.permissionGranted = false;
      await pumpReminders(tester);
      await tester.tap(find.text(tr('notifTest').toUpperCase()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(tr('notifGoSettings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('notifTestPending')), findsOneWidget);
      // Vuelve SIN conceder el permiso.
      tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(fake.shown, isEmpty);
      expect(find.text(tr('notifSent')), findsNothing);
      expect(await NotificationService.lastReminderSentTime(), isNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('Ronda #7 (2): sendTest honesto', () {
    testWidgets('sendTest devuelve false si show() lanza y no registra '
        'hora', (tester) async {
      fake.showThrows = true;
      final future = NotificationService.sendTest();
      // La copia del icono grande tiene un tope de 3 s en pruebas.
      await tester.pump(const Duration(seconds: 4));
      expect(await future, isFalse);
      expect(fake.shown, isEmpty);
      expect(await NotificationService.lastReminderSentTime(), isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('con show() fallando, el botón muestra el fallo y nunca '
        '"Aviso enviado"', (tester) async {
      fake.showThrows = true;
      await pumpReminders(tester);
      await tester.tap(find.text(tr('notifTest').toUpperCase()));
      // La copia del icono grande tiene un tope de 3 s en pruebas.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('notifTestFailedSystem')), findsOneWidget);
      expect(find.text(tr('notifSent')), findsNothing);
      expect(fake.shown, isEmpty);
      expect(await NotificationService.lastReminderSentTime(), isNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('Ronda #7 (3): canal propio de prueba', () {
    testWidgets('la prueba 9999 y la confirmación 9998 usan '
        "'quemia_prueba_avisos' con Importance.high", (tester) async {
      final testFuture = NotificationService.sendTest();
      // La copia del icono grande tiene un tope de 3 s en pruebas.
      await tester.pump(const Duration(seconds: 4));
      expect(await testFuture, isTrue);
      expect(await NotificationService.sendEnabledConfirmation(), isTrue);

      final test9999 =
          fake.shownDetails.firstWhere((s) => s.id == 9999);
      expect(test9999.channelId, 'quemia_prueba_avisos');
      expect(test9999.importance, Importance.high);
      final conf9998 =
          fake.shownDetails.firstWhere((s) => s.id == 9998);
      expect(conf9998.channelId, 'quemia_prueba_avisos');
      expect(conf9998.importance, Importance.high);
      // Ni la prueba ni la confirmación tocan el canal de repaso.
      for (final d in fake.shownDetails) {
        expect(d.channelId, isNot('melli_study_reminders'));
      }
      expect(tester.takeException(), isNull);
    });

    test('los recordatorios programados siguen en '
        "'melli_study_reminders'", () async {
      final scheduled =
          await NotificationService.scheduleNext(rng: Random(7));
      expect(scheduled, hasLength(3));
      expect(fake.zonedScheduled, 3);
      expect(fake.scheduledDetails, hasLength(3));
      for (final d in fake.scheduledDetails) {
        expect(d.channelId, 'melli_study_reminders',
            reason: 'los programados NO se mueven al canal de prueba');
        expect(d.importance, Importance.defaultImportance);
      }
    });
  });

  group('Ronda #7 (4): init() que falla no impide la prueba', () {
    testWidgets('con init() fallido, sendTest devuelve true y el 9999 '
        'sale', (tester) async {
      fake.initializeThrows = true;
      final future = NotificationService.sendTest();
      // La copia del icono grande tiene un tope de 3 s en pruebas.
      await tester.pump(const Duration(seconds: 4));
      expect(await future, isTrue);
      expect(fake.shown.map((s) => s.id), contains(9999));
      final got = await NotificationService.lastReminderSentTime();
      expect(got, isNotNull);
      expect(
          DateTime.now().difference(got!).inMinutes.abs(), lessThanOrEqualTo(1));
      expect(tester.takeException(), isNull);
    });
  });

  group('Ronda #7 (5): canal de prueba bloqueado', () {
    test('canal de prueba con Importance.none → bloqueado', () async {
      fake.channels = const [
        AndroidNotificationChannel(
          'quemia_prueba_avisos',
          'Aviso de prueba',
          importance: Importance.none,
        ),
      ];
      expect(await NotificationService.isTestChannelBlocked(), isTrue);
    });

    test('canal de prueba con Importance.high → no bloqueado', () async {
      fake.channels = const [
        AndroidNotificationChannel(
          'quemia_prueba_avisos',
          'Aviso de prueba',
          importance: Importance.high,
        ),
      ];
      expect(await NotificationService.isTestChannelBlocked(), isFalse);
    });

    test('sin canal de prueba (aún no se envió ningún aviso inmediato) '
        '→ no bloqueado', () async {
      fake.channels = const [];
      expect(await NotificationService.isTestChannelBlocked(), isFalse);
    });

    test('otro canal bloqueado no afecta al de prueba', () async {
      fake.channels = const [
        AndroidNotificationChannel(
          'melli_study_reminders',
          'Recordatorios de estudio',
          importance: Importance.none,
        ),
      ];
      expect(await NotificationService.isTestChannelBlocked(), isFalse);
    });
  });

  group('Ronda #7 (6): canal de recordatorios bloqueado', () {
    test('canal de recordatorios con Importance.none → bloqueado',
        () async {
      fake.channels = const [
        AndroidNotificationChannel(
          'melli_study_reminders',
          'Recordatorios de estudio',
          importance: Importance.none,
        ),
      ];
      expect(await NotificationService.isRemindersChannelBlocked(), isTrue);
    });

    test('canal de recordatorios con Importance.high → no bloqueado',
        () async {
      fake.channels = const [
        AndroidNotificationChannel(
          'melli_study_reminders',
          'Recordatorios de estudio',
          importance: Importance.high,
        ),
      ];
      expect(
          await NotificationService.isRemindersChannelBlocked(), isFalse);
    });

    test('sin canal de recordatorios (aún no se programó ningún aviso) '
        '→ no bloqueado', () async {
      fake.channels = const [];
      expect(
          await NotificationService.isRemindersChannelBlocked(), isFalse);
    });

    test('otro canal bloqueado no afecta al de recordatorios', () async {
      fake.channels = const [
        AndroidNotificationChannel(
          'quemia_prueba_avisos',
          'Aviso de prueba',
          importance: Importance.none,
        ),
      ];
      expect(
          await NotificationService.isRemindersChannelBlocked(), isFalse);
    });
  });

}

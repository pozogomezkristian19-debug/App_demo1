// Pruebas de la Zona G (Quemia 7.1): la prueba de aviso con
// resultado TIPADO.
//
// Bug que se arrastra desde la 6.3: tocar "Probar un aviso ahora"
// enseñaba el genérico "No se pudo enviar el aviso: error del
// sistema" y la prueba NUNCA llegaba al teléfono de Kristian, sin
// que el código guardara NINGUNA pista de qué fallaba: sendTest()
// tragaba todas las excepciones con `catch (_) { return false; }`.
//
// Diagnóstico verificado en el fuente de
// flutter_local_notifications 23.0.0 (ver
// lib/services/notification_service.dart, cabecera de sendTest):
// el show() de Java NO tiene try/catch alrededor de
// NotificationManagerCompat.notify: sin POST_NOTIFICATIONS, el
// notify() lanza SecurityException; un icono no válido llega como
// PlatformException invalid_icon / invalid_large_icon. Un canal
// bloqueado (Importance.none) NO lanza: el aviso se descarta en
// silencio. Y los chequeos previos mentían: isPermissionGranted y
// _isChannelBlocked usaban un tope de 100 ms y, al expirar,
// asumían "sí" / "no bloqueado".
//
// Arreglos que se prueban aquí (falsos del plugin, como en la
// ronda #7: lo que se simula es la EXCEPCIÓN que lanzaría el
// sistema, no el teléfono):
//  1. Clasificación del error de show(): SecurityException /
//     POST_NOTIFICATIONS / permiso → permissionDenied; invalid_*
//     u otro → pluginError con el texto real recortado.
//  2. sendTestDetailed(): permiso denegado (comprobación estricta)
//     → permissionDenied SIN llamar a show(); canal bloqueado →
//     channelBlocked SIN llamar a show(); si no se puede comprobar
//     el permiso, se intenta igual y es el show() el que decide.
//  3. El botón: permissionDenied o channelBlocked → diálogo de
//     Ajustes ("Ir a Ajustes"); pluginError → snackbar con el
//     texto real del error, SIN diálogo de Ajustes y SIN el
//     genérico "error del sistema".
//  4. Contraste de la intro: ya no es el #4B4B4B fijo (ilegible
//     en oscuro) sino el onSurface del tema.
//  5. sendTest() sigue siendo el envoltorio bool de siempre
//     (compatibilidad con _recheckPermission y con las pruebas
//     de la ronda #7).
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

/// Fake del plugin para la Zona G: como el de la ronda #7, pero
/// con la excepción de show() configurable (cualquier Object: es
/// lo que se clasifica) y con la respuesta de
/// areNotificationsEnabled separable de la de
/// requestNotificationsPermission (para simular que la
/// comprobación estricta dice "no" aunque la petición dijera
/// "sí", o que no se puede comprobar).
class _Fix9FakeNotifications extends AndroidFlutterLocalNotificationsPlugin
    with MockPlatformInterfaceMixin {
  _Fix9FakeNotifications({required this.permissionGranted});

  bool permissionGranted;

  /// ¿Las alarmas exactas están concedidas?
  bool canScheduleExact = true;

  /// ¿Se llamó a requestNotificationsPermission()?
  bool requestCalled = false;

  /// Respuesta de areNotificationsEnabled() cuando NO es null:
  /// si es null, se usa [permissionGranted]. Con
  /// [returnNullEnabled] true, devuelve null (no se pudo
  /// comprobar).
  bool? enabledOverride;

  /// ¿areNotificationsEnabled() devuelve null?
  bool returnNullEnabled = false;

  /// Excepción que lanza show() (null = no lanza).
  Object? showError;

  /// ¿Se abrió los ajustes de notificaciones de la app?
  bool settingsOpened = false;

  /// Canales que devuelve getNotificationChannels().
  List<AndroidNotificationChannel> channels = const [];

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
    requestCalled = true;
    return permissionGranted;
  }

  @override
  Future<bool?> requestExactAlarmsPermission() async => true;

  @override
  Future<bool?> areNotificationsEnabled() async {
    if (returnNullEnabled) return null;
    return enabledOverride ?? permissionGranted;
  }

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
    final error = showError;
    if (error != null) throw error;
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

  late _Fix9FakeNotifications fake;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserPrefs.load();
    NotificationInbox.resetForTests();
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
    fake = _Fix9FakeNotifications(permissionGranted: true);
    FlutterLocalNotificationsPlatform.instance = fake;
  });

  tearDown(() {
    AppLang.code = 'es';
  });

  Future<void> pumpReminders(WidgetTester tester) async {
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

  group('Zona G (1): clasificar el error de show() (falsos)', () {
    test('PlatformException SecurityException → permissionDenied', () {
      final result = NotificationService.resultForShowError(
        PlatformException(
          code: 'SecurityException',
          message: 'Posting notification without permission',
        ),
      );
      expect(result.outcome, NotificationTestOutcome.permissionDenied);
      expect(result.detail, contains('SecurityException'));
      expect(result.sent, isFalse);
    });

    test('Exception genérica con texto SecurityException y '
        'POST_NOTIFICATIONS → permissionDenied', () {
      final result = NotificationService.resultForShowError(
        Exception(
          'java.lang.SecurityException: Caller needs permission '
          'android.permission.POST_NOTIFICATIONS to post',
        ),
      );
      expect(result.outcome, NotificationTestOutcome.permissionDenied);
    });

    test("PlatformException invalid_icon → pluginError con el "
        "código y el mensaje reales", () {
      final result = NotificationService.resultForShowError(
        PlatformException(
          code: 'invalid_icon',
          message: 'The drawable ic_notif_bell could not be found',
        ),
      );
      expect(result.outcome, NotificationTestOutcome.pluginError);
      expect(
        result.detail,
        'invalid_icon: The drawable ic_notif_bell could not be found',
      );
    });

    test('PlatformException sin mensaje → pluginError con el '
        "código ('PlatformException(SHOW_FAILED)')", () {
      final result = NotificationService.resultForShowError(
        PlatformException(code: 'SHOW_FAILED'),
      );
      expect(result.outcome, NotificationTestOutcome.pluginError);
      expect(result.detail, 'PlatformException(SHOW_FAILED)');
    });

    test('MissingPluginException (plugin sin registrar) → '
        'pluginError, no permissionDenied', () {
      final result = NotificationService.resultForShowError(
        MissingPluginException('No implementation found for show'),
      );
      expect(result.outcome, NotificationTestOutcome.pluginError);
      expect(result.detail, contains('MissingPluginException'));
    });

    test('un mensaje larguísimo se recorta a 120 caracteres + …', () {
      final result = NotificationService.resultForShowError(
        PlatformException(code: 'ERR', message: 'x' * 200),
      );
      expect(result.outcome, NotificationTestOutcome.pluginError);
      expect(result.detail, isNotNull);
      expect(result.detail!.length, lessThanOrEqualTo(121));
      expect(result.detail, endsWith('…'));
    });
  });

  group('Zona G (2): sendTestDetailed con falsas del plugin', () {
    testWidgets('show() lanza SecurityException → permissionDenied, '
        'sin anotar hora de envío', (tester) async {
      fake.showError = PlatformException(
        code: 'SecurityException',
        message: 'Posting notification without permission',
      );
      final future = NotificationService.sendTestDetailed();
      // La copia del icono grande tiene un tope de 3 s en pruebas.
      await tester.pump(const Duration(seconds: 4));
      final result = await future;
      expect(result.outcome, NotificationTestOutcome.permissionDenied);
      expect(fake.shown, isEmpty);
      expect(await NotificationService.lastReminderSentTime(), isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('show() lanza invalid_icon → pluginError con el '
        'texto real', (tester) async {
      fake.showError = PlatformException(
        code: 'invalid_icon',
        message: 'The drawable ic_notif_bell could not be found',
      );
      final future = NotificationService.sendTestDetailed();
      await tester.pump(const Duration(seconds: 4));
      final result = await future;
      expect(result.outcome, NotificationTestOutcome.pluginError);
      expect(
        result.detail,
        'invalid_icon: The drawable ic_notif_bell could not be found',
      );
      expect(fake.shown, isEmpty);
      expect(await NotificationService.lastReminderSentTime(), isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la comprobación estricta dice "no" aunque la '
        'petición dijera "sí" → permissionDenied SIN llamar a '
        'show()', (tester) async {
      // Simulado: requestNotificationsPermission() diría que sí,
      // pero areNotificationsEnabled() dice que no (el caso del
      // teléfono: la comprobación laxa de 100 ms mentía "sí").
      fake.enabledOverride = false;
      final future = NotificationService.sendTestDetailed();
      await tester.pump(const Duration(seconds: 1));
      final result = await future;
      expect(result.outcome, NotificationTestOutcome.permissionDenied);
      expect(fake.shown, isEmpty,
          reason: 'con el permiso denegado de verdad, el show() ni '
              'se intenta: en API 33+ lanzaría SecurityException');
      expect(tester.takeException(), isNull);
    });

    testWidgets('canal de prueba bloqueado → channelBlocked SIN '
        'llamar a show()', (tester) async {
      fake.channels = const [
        AndroidNotificationChannel(
          'quemia_prueba_avisos',
          'Aviso de prueba',
          importance: Importance.none,
        ),
      ];
      final future = NotificationService.sendTestDetailed();
      await tester.pump(const Duration(seconds: 1));
      final result = await future;
      expect(result.outcome, NotificationTestOutcome.channelBlocked);
      expect(fake.shown, isEmpty,
          reason: 'con el canal bloqueado el show() no lanzaría y '
              'la pantalla mentiría diciendo "Aviso enviado"');
      expect(tester.takeException(), isNull);
    });

    testWidgets('si el permiso no se puede comprobar, se intenta '
        'igual y el show() decide', (tester) async {
      fake.returnNullEnabled = true;
      final future = NotificationService.sendTestDetailed();
      await tester.pump(const Duration(seconds: 4));
      final result = await future;
      expect(result.outcome, NotificationTestOutcome.sent);
      expect(fake.shown.map((s) => s.id), contains(9999));
      expect(await NotificationService.lastReminderSentTime(), isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sendTest() (bool, compatibilidad) sigue siendo '
        'false si show() lanza y true si sale', (tester) async {
      fake.showError = PlatformException(code: 'SHOW_FAILED');
      final failing = NotificationService.sendTest();
      await tester.pump(const Duration(seconds: 4));
      expect(await failing, isFalse);

      fake.showError = null;
      NotificationService.resetForTests();
      final ok = NotificationService.sendTest();
      await tester.pump(const Duration(seconds: 4));
      expect(await ok, isTrue);
      expect(fake.shown.map((s) => s.id), contains(9999));
      expect(tester.takeException(), isNull);
    });
  });

  group('Zona G (3): el botón ofrece Ajustes cuando el sistema '
      'bloquea', () {
    testWidgets('show() lanza SecurityException → diálogo de '
        'Ajustes y, al ir, aviso pendiente (nunca el genérico)',
        (tester) async {
      fake.showError = PlatformException(
        code: 'SecurityException',
        message: 'Posting notification without permission',
      );
      await pumpReminders(tester);
      await tester.tap(find.text(tr('notifTest').toUpperCase()));
      // La copia del icono grande tiene un tope de 3 s en pruebas.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('notifSettingsTitle')), findsOneWidget);
      expect(find.text(tr('notifSent')), findsNothing);
      expect(find.text(tr('notifTestFailedSystem')), findsNothing);

      await tester.tap(find.text(tr('notifGoSettings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(fake.settingsOpened, isTrue);
      expect(find.text(tr('notifTestPending')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('show() lanza invalid_icon → snackbar con el error '
        'real, SIN diálogo de Ajustes', (tester) async {
      fake.showError = PlatformException(
        code: 'invalid_icon',
        message: 'The drawable ic_notif_bell could not be found',
      );
      await pumpReminders(tester);
      await tester.tap(find.text(tr('notifTest').toUpperCase()));
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
          find.text(tr('notifTestFailedDetail').replaceFirst(
            '{detail}',
            'invalid_icon: The drawable ic_notif_bell could not be '
                'found',
          )),
          findsOneWidget);
      expect(find.text(tr('notifSettingsTitle')), findsNothing);
      expect(find.text(tr('notifTestFailedSystem')), findsNothing);
      expect(find.text(tr('notifSent')), findsNothing);
      expect(fake.settingsOpened, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('canal de prueba bloqueado → mensaje de canal + '
        'diálogo de Ajustes', (tester) async {
      fake.channels = const [
        AndroidNotificationChannel(
          'quemia_prueba_avisos',
          'Aviso de prueba',
          importance: Importance.none,
        ),
      ];
      await pumpReminders(tester);
      await tester.tap(find.text(tr('notifTest').toUpperCase()));
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('notifTestFailedChannel')), findsOneWidget);
      expect(find.text(tr('notifSettingsTitle')), findsOneWidget);
      expect(find.text(tr('notifSent')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('si el show() sale, el botón sigue diciendo '
        '"Aviso enviado"', (tester) async {
      await pumpReminders(tester);
      await tester.tap(find.text(tr('notifTest').toUpperCase()));
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('notifSent')), findsOneWidget);
      expect(find.text(tr('notifSettingsTitle')), findsNothing);
      expect(fake.shown.map((s) => s.id), contains(9999));
      expect(tester.takeException(), isNull);
    });
  });

  group('Zona G (4): contraste de la intro', () {
    testWidgets('en tema oscuro la intro NO es el #4B4B4B fijo '
        'sino el onSurface del tema', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const ReminderScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final intro = tester.widget<Text>(find.text(tr('notifExplain')));
      expect(intro.style?.color, isNotNull);
      expect(intro.style!.color, isNot(const Color(0xFF4B4B4B)));
      expect(
        intro.style!.color,
        ThemeData.dark().colorScheme.onSurface,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Zona G (5): regla general — la confirmación 9998 y el '
      'reenvío pendiente tienen el mismo arreglo', () {
    test('la confirmación también clasifica: SecurityException → '
        'permissionDenied, y el envoltorio bool sigue siendo false',
        () async {
      fake.showError = PlatformException(
        code: 'SecurityException',
        message: 'Posting notification without permission',
      );
      final result =
          await NotificationService.sendEnabledConfirmationDetailed();
      expect(result.outcome, NotificationTestOutcome.permissionDenied);
      expect(
          await NotificationService.sendEnabledConfirmation(), isFalse);
      expect(fake.shown, isEmpty);
      expect(await NotificationService.lastReminderSentTime(), isNull);
    });

    test('la confirmación también clasifica: invalid_icon → '
        'pluginError con el texto real', () async {
      fake.showError = PlatformException(
        code: 'invalid_icon',
        message: 'The drawable ic_notif_bell could not be found',
      );
      final result =
          await NotificationService.sendEnabledConfirmationDetailed();
      expect(result.outcome, NotificationTestOutcome.pluginError);
      expect(
        result.detail,
        'invalid_icon: The drawable ic_notif_bell could not be found',
      );
      expect(fake.shown, isEmpty);
    });

    test('la confirmación con el canal bloqueado → channelBlocked '
        'SIN llamar a show()', () async {
      fake.channels = const [
        AndroidNotificationChannel(
          'quemia_prueba_avisos',
          'Aviso de prueba',
          importance: Importance.none,
        ),
      ];
      final result =
          await NotificationService.sendEnabledConfirmationDetailed();
      expect(result.outcome, NotificationTestOutcome.channelBlocked);
      expect(fake.shown, isEmpty);
    });

    test('la confirmación con todo bien → sent (y el envoltorio '
        'bool true)', () async {
      final result =
          await NotificationService.sendEnabledConfirmationDetailed();
      expect(result.outcome, NotificationTestOutcome.sent);
      expect(
          await NotificationService.sendEnabledConfirmation(), isTrue);
      expect(fake.shown.map((s) => s.id), contains(9998));
      expect(await NotificationService.lastReminderSentTime(), isNotNull);
    });

    testWidgets('el reenvío pendiente que sigue fallando al volver '
        'de Ajustes dice LA CAUSA (no se calla)', (tester) async {
      fake.permissionGranted = false;
      fake.showError = PlatformException(
        code: 'SecurityException',
        message: 'Posting notification without permission',
      );
      await pumpReminders(tester);
      await tester.tap(find.text(tr('notifTest').toUpperCase()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('notifSettingsTitle')), findsOneWidget);
      await tester.tap(find.text(tr('notifGoSettings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(fake.settingsOpened, isTrue);
      expect(find.text(tr('notifTestPending')), findsOneWidget);

      // Vuelve de Ajustes con el permiso concedido, pero el show()
      // sigue lanzando SecurityException: el reenvío pendiente
      // falla y la pantalla debe decir que es el permiso, no
      // quedarse callada ni decir "Aviso enviado".
      fake.permissionGranted = true;
      tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('notifTestFailedPerm')), findsOneWidget);
      expect(find.text(tr('notifSent')), findsNothing);
      expect(find.text(tr('notifTestFailedSystem')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

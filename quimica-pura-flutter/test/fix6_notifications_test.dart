// Pruebas de la ronda #6, punto 2 (Quemia 6.3): notificaciones.
//
// Causa principal verificada (ver lib/services/notification_service.dart
// y android/app/src/main/AndroidManifest.xml): la app NO declaraba
// los receivers que flutter_local_notifications 23.0.0 exige para
// mostrar notificaciones PROGRAMADAS (README del plugin,
// "AndroidManifest.xml setup"): sin ScheduledNotificationReceiver,
// la alarma de AlarmManager dispara un broadcast a un componente
// que no existe en el manifiesto y el sistema lo descarta en
// silencio: la tanda se guardaba, la pantalla decía "Próximo
// aviso", pero NADA llegaba nunca. Los avisos inmediatos
// (confirmación 9998, prueba 9999) sí pueden llegar, porque van
// directos al NotificationManager. Sin RECEIVE_BOOT_COMPLETED ni
// ScheduledNotificationBootReceiver, tras reiniciar no se
// reprogramaba nada hasta abrir la app.
//
// Diagnóstico (ronda #6, QUITADO en la simplificación de la ronda
// #7): la pantalla mostraba el permiso real, el próximo aviso, el
// ÚLTIMO aviso enviado y el estado del ahorro de batería. La
// pantalla simplificada solo tiene introducción, interruptor y
// botón de prueba; el comportamiento (canal propio, prueba honesta,
// aviso pendiente) sigue igual.
//
// Ruta de petición (ronda #6, 02:18 — "la app nunca pide permiso"):
// la cadena del toque al diálogo está completa; el único retorno
// temprano que podía tragarse la petición era el gate de init() en
// requestPermission() (y en la confirmación 9998 y sendTest()): si
// init() fallaba, se devolvía false SIN llamar al plugin. Ahora la
// petición va directo al plugin y el init() solo se asegura
// después de concedido. Causa más probable en el teléfono: la
// denegación permanente (negó en el onboarding de la 6.0/6.1;
// Android 13+ ya no muestra el diálogo): ningún código puede
// forzar el diálogo; el único camino es "Ir a Ajustes".
import 'dart:io';
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
import 'package:quimica_pura/widgets/notification_settings_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'test_helpers.dart';

/// Fake del plugin de notificaciones (mismo patrón que el de fix5):
/// simula el permiso (concedido o negado), si las alarmas exactas
/// están concedidas, y anota cada llamada. Como el plugin real,
/// zonedSchedule con modo exacto LANZA si las alarmas exactas no
/// están concedidas (antes de programar nada): así se prueba el
/// repliegue a inexactas de _scheduleOne. Además anota si se pidió
/// el permiso ([requestCalled]) y puede hacer fallar initialize()
/// ([initializeThrows]) para probar que la ruta de petición no
/// depende de init() (ronda #6, 02:18: "la app nunca pide permiso").
class _Fix6FakeNotifications extends AndroidFlutterLocalNotificationsPlugin
    with MockPlatformInterfaceMixin {
  _Fix6FakeNotifications({required this.permissionGranted});

  bool permissionGranted;

  /// ¿Las alarmas exactas están concedidas?
  bool canScheduleExact = true;

  /// ¿Se llamó a requestNotificationsPermission() (la petición
  /// nativa que muestra el diálogo del sistema)?
  bool requestCalled = false;

  /// ¿initialize() lanza una excepción (para simular un init()
  /// fallido)?
  bool initializeThrows = false;

  /// ¿Se abrió los ajustes de notificaciones de la app?
  bool settingsOpened = false;

  /// Avisos inmediatos mostrados (id, título, cuerpo).
  final shown = <({int id, String? title, String? body})>[];

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
    scheduledModes.add(scheduleMode);
    zonedScheduled++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  late _Fix6FakeNotifications fake;

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
    fake = _Fix6FakeNotifications(permissionGranted: true);
    FlutterLocalNotificationsPlatform.instance = fake;
  });

  tearDown(() {
    AppLang.code = 'es';
  });

  group('Manifiesto: los receivers del plugin están declarados', () {
    test('RECEIVE_BOOT_COMPLETED y los 3 receivers existen (la causa '
        'de que no llegara nada)', () {
      final file = File('android/app/src/main/AndroidManifest.xml');
      expect(file.existsSync(), isTrue,
          reason: 'el test corre desde la raíz del proyecto');
      final xml = file.readAsStringSync();
      // Sin este permiso, tras reiniciar no se reprograma nada.
      expect(xml, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
      // Sin este receiver, la alarma programada dispara un broadcast
      // a un componente que no existe y el sistema lo descarta: la
      // tanda se guarda y la pantalla dice "Próximo aviso", pero el
      // aviso NUNCA se muestra.
      expect(
          xml,
          contains(
              'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver'));
      // Sin este, tras reiniciar no se reprograman los avisos.
      expect(
          xml,
          contains(
              'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver'));
      expect(xml, contains('android.intent.action.BOOT_COMPLETED'));
      // Sin este, la acción "Repasar ahora" no hace nada.
      expect(
          xml,
          contains(
              'com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver'));
    });
  });

  group('Servicio: estado del permiso', () {
    test('isPermissionGranted refleja el permiso real', () async {
      expect(await NotificationService.isPermissionGranted, isTrue);
      fake.permissionGranted = false;
      expect(await NotificationService.isPermissionGranted, isFalse);
    });
  });

  group('Servicio: la ruta de petición (ronda #6, 02:18 — "la app '
      'nunca pide permiso")', () {
    test('requestPermission() pide el permiso aunque el servicio no '
        'esté inicializado (sin gate de init())', () async {
      // Servicio frío: resetForTests() en el setUp deja _ready en
      // false. Antes, requestPermission() exigía init() con éxito
      // y, si fallaba, devolvía false SIN llamar al plugin: el
      // diálogo del sistema no se pedía nunca.
      expect(await NotificationService.requestPermission(), isTrue);
      expect(fake.requestCalled, isTrue,
          reason: 'la petición nativa (el diálogo del sistema) debe '
              'intentarse siempre, aunque init() no haya corrido');
    });

    test('requestPermission() intenta la petición aunque el permiso '
        'esté denegado (el sistema decide si muestra el diálogo)',
        () async {
      fake.permissionGranted = false;
      expect(await NotificationService.requestPermission(), isFalse);
      expect(fake.requestCalled, isTrue,
          reason: 'denegado no es "no pedido": la petición se hizo '
              'y el sistema devolvió false en el acto (denegación '
              'permanente: el único camino es "Ir a Ajustes")');
    });

    testWidgets('enable() con init() fallido sigue pidiendo el '
        'permiso, programa la tanda y confirma', (tester) async {
      fake.initializeThrows = true;
      final future = NotificationService.enable();
      // La copia del icono grande tiene un tope de 3 s en pruebas.
      await tester.pump(const Duration(seconds: 4));
      expect(await future, isTrue);
      // La petición se hizo (init() fallido no se la tragó).
      expect(fake.requestCalled, isTrue);
      expect(UserPrefs.reminderOn, isTrue);
      expect(fake.zonedScheduled, 3);
      // La confirmación (unawaited en enable()) también sale
      // aunque init() falle.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(fake.shown.map((s) => s.id), contains(9998));
      expect(tester.takeException(), isNull);
    });

    testWidgets('sendEnabledConfirmation() sale aunque init() falle',
        (tester) async {
      fake.initializeThrows = true;
      expect(await NotificationService.sendEnabledConfirmation(), isTrue);
      expect(fake.shown.map((s) => s.id), contains(9998));
      expect(tester.takeException(), isNull);
    });
  });

  group('Servicio: próxima notificación', () {
    test('nextNotificationTime devuelve el primer aviso futuro', () async {
      final now = DateTime.now();
      final past = now.subtract(const Duration(hours: 1));
      final next = now.add(const Duration(minutes: 30));
      final later = now.add(const Duration(hours: 3));
      SharedPreferences.setMockInitialValues({
        'melli_notif_next':
            '${past.toIso8601String()},${next.toIso8601String()},${later.toIso8601String()}',
      });
      final got = await NotificationService.nextNotificationTime();
      expect(got, isNotNull);
      expect(got!.difference(next).inSeconds.abs(), lessThanOrEqualTo(1));
    });

    test('nextNotificationTime es null sin tanda programada', () async {
      SharedPreferences.setMockInitialValues({'melli_notif_next': ''});
      expect(await NotificationService.nextNotificationTime(), isNull);
    });
  });

  group('Servicio: último aviso enviado', () {
    test('lastReminderSentTime es null si nunca se envió nada', () async {
      expect(await NotificationService.lastReminderSentTime(), isNull);
    });

    test('lastReminderSentTime lee la hora programada de la bandeja '
        '(no la de la reconciliación)', () async {
      final sent = DateTime.now().subtract(const Duration(hours: 2));
      await NotificationInbox.add(
        id: 'reminder-${sent.millisecondsSinceEpoch}',
        kind: InboxKind.reminder,
        title: 'Hora de repasar',
        body: 'Tenías un recordatorio pendiente.',
      );
      final got = await NotificationService.lastReminderSentTime();
      expect(got, isNotNull);
      expect(got!.difference(sent).inSeconds.abs(), lessThanOrEqualTo(1));
    });

    test('lastReminderSentTime ignora las entradas que no son '
        'recordatorios', () async {
      final sent = DateTime.now().subtract(const Duration(hours: 2));
      await NotificationInbox.add(
        id: 'reminder-${sent.millisecondsSinceEpoch}',
        kind: InboxKind.reminder,
        title: 'Hora de repasar',
        body: 'Tenías un recordatorio pendiente.',
      );
      // Un logro más reciente no es un aviso enviado.
      await NotificationInbox.add(
        id: 'achievement-algo',
        kind: InboxKind.achievement,
        title: 'Logro',
        body: 'Desbloqueado.',
      );
      final got = await NotificationService.lastReminderSentTime();
      expect(got, isNotNull);
      expect(got!.difference(sent).inSeconds.abs(), lessThanOrEqualTo(1));
    });

    test('sendEnabledConfirmation registra la hora del envío', () async {
      expect(await NotificationService.sendEnabledConfirmation(), isTrue);
      expect(fake.shown.map((s) => s.id), contains(9998));
      final got = await NotificationService.lastReminderSentTime();
      expect(got, isNotNull);
      expect(
          DateTime.now().difference(got!).inMinutes.abs(), lessThanOrEqualTo(1));
    });

    testWidgets('sendTest envía el aviso 9999 y registra la hora',
        (tester) async {
      final future = NotificationService.sendTest();
      // La copia del icono grande tiene un tope de 3 s en pruebas.
      await tester.pump(const Duration(seconds: 4));
      // Ronda #7: sendTest() devuelve Future<bool>: true solo si el
      // show() completó sin lanzar.
      expect(await future, isTrue);
      expect(fake.shown.map((s) => s.id), contains(9999));
      final body =
          fake.shown.firstWhere((s) => s.id == 9999).body;
      // El aviso puede ser una plantilla genérica o el mensaje del tema
      // más débil (1 de cada 3 veces, _pickMessage): en ambos casos
      // es un aviso válido.
      expect(
        NotificationService.messageTemplates('es').contains(body) ||
            (body?.startsWith('Toca repasar ') ?? false),
        isTrue,
        reason: body,
      );
      final got = await NotificationService.lastReminderSentTime();
      expect(got, isNotNull);
      expect(
          DateTime.now().difference(got!).inMinutes.abs(), lessThanOrEqualTo(1));
      expect(tester.takeException(), isNull);
    });
  });

  group('Servicio: intervalos de programación', () {
    test('scheduleNext: primero en 20-50 min, luego 61-180 min',
        () async {
      final scheduled =
          await NotificationService.scheduleNext(rng: Random(7));
      expect(scheduled, hasLength(3));
      expect(fake.zonedScheduled, 3);
      final now = DateTime.now();
      final firstGap = scheduled.first.difference(now).inMinutes;
      expect(firstGap, greaterThanOrEqualTo(19));
      expect(firstGap, lessThanOrEqualTo(51));
      for (var i = 1; i < scheduled.length; i++) {
        final gap = scheduled[i].difference(scheduled[i - 1]).inMinutes;
        expect(gap, greaterThanOrEqualTo(60));
        expect(gap, lessThanOrEqualTo(181));
      }
    });
  });

  group('Servicio: repliegue a inexactas sin alarmas exactas', () {
    test('sin alarmas exactas, la tanda sale inexacta y llega igual',
        () async {
      fake.canScheduleExact = false;
      expect(await NotificationService.enable(), isTrue);
      expect(NotificationService.exactAlarmsOn, isFalse);
      expect(NotificationService.scheduleMode,
          AndroidScheduleMode.inexactAllowWhileIdle);
      // La tanda sale igual: 3 avisos (el primero, tras fallar en
      // exacto, se reprogramó inexacto).
      expect(fake.zonedScheduled, 3);
      expect(
          fake.scheduledModes,
          everyElement(
              AndroidScheduleMode.inexactAllowWhileIdle));
    });
  });

  group('Pantalla Recordatorios simplificada', () {
    Future<void> pumpReminders(WidgetTester tester) async {
      // Ventana ALTA (800x1400): con el alto por defecto (600) el
      // botón de prueba quedaba fuera del área construida del
      // ListView y find.text no lo encontraba.
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

    testWidgets('solo se ven la introducción, el interruptor y el '
        'botón de prueba (nada de diagnóstico)', (tester) async {
      SharedPreferences.setMockInitialValues({'melli_reminder_on': true});
      await UserPrefs.load();
      await pumpReminders(tester);
      expect(find.text(tr('notifExplain')), findsOneWidget);
      expect(find.text(tr('notifOn')), findsOneWidget);
      expect(find.text(tr('notifTest').toUpperCase()), findsOneWidget);
      expect(find.text('Diagnóstico'), findsNothing);
      expect(find.text('Próximo aviso'), findsNothing);
      expect(find.text('Sin avisos programados'), findsNothing);
      expect(find.text('Último aviso enviado'), findsNothing);
      expect(find.text('Ahorro de batería'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Probar un aviso ahora" envía el aviso (9999) y '
        'muestra "Aviso enviado"', (tester) async {
      await pumpReminders(tester);
      await tester.tap(find.text(tr('notifTest').toUpperCase()));
      // La copia del icono grande tiene un tope de 3 s en pruebas.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(fake.shown.map((s) => s.id), contains(9999));
      expect(find.text(tr('notifSent')), findsOneWidget);
      // La hora queda registrada en el servicio (ya no se muestra
      // en la pantalla simplificada).
      final got = await NotificationService.lastReminderSentTime();
      expect(got, isNotNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('Diálogo de Ajustes: pasos de batería de Xiaomi', () {
    testWidgets('el diálogo menciona la batería y el inicio '
        'automático', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await showNotificationSettingsDialog(context);
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
      expect(find.textContaining('Ahorro de batería'), findsOneWidget);
      expect(find.textContaining('Sin restricciones'), findsOneWidget);
      expect(find.textContaining('Inicio automático'), findsOneWidget);
      expect(find.text(tr('notifGoSettings')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Textos de la pantalla simplificada en los 6 idiomas', () {
    testWidgets('introducción, interruptor y botón existen en los 6 '
        'idiomas y no aparece el diagnóstico', (tester) async {
      SharedPreferences.setMockInitialValues({'melli_reminder_on': true});
      await UserPrefs.load();
      for (final lang in ['es', 'en', 'fr', 'it', 'pt', 'ru']) {
        AppLang.code = lang;
        // Clave distinta por idioma: sin ella, pumpWidget con el
        // MISMO widget const reutiliza el árbol y la pantalla no se
        // reconstruye en el idioma nuevo.
        await tester.pumpWidget(
          MaterialApp(
            home: ReminderScreen(key: ValueKey(lang)),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text(tr('notifExplain')), findsOneWidget,
            reason: '$lang: falta la introducción');
        expect(find.text(tr('notifOn')), findsOneWidget,
            reason: '$lang: falta el interruptor encendido');
        expect(find.text(tr('notifTest').toUpperCase()), findsOneWidget,
            reason: '$lang: falta el botón de prueba');
        if (lang == 'es') {
          expect(find.text('Diagnóstico'), findsNothing);
          expect(find.text('Próximo aviso'), findsNothing);
          expect(find.text('Ahorro de batería'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      }
    });
  });
}

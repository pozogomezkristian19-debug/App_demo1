// Recordatorio de estudio con nombre + cuenta atrás (Kristian
// 2026-11-16, captura de Duolingo 15 nov 21:53: "¡Jorge, ven por
// una lección!" + "2:06:16" para medianoche): la notificación de
// Quemia llama al usuario por su nombre y dice el tiempo que le
// queda en el día para no perder la racha, calculado para la hora
// de envío. ESTE aviso es texto estático una vez puesto (Android
// no hace tic-tac en el texto); la cuenta atrás EN VIVO es otro
// aviso (LiveCountdown, test/live_countdown_test.dart): cronómetro
// en cuenta atrás hasta medianoche, en curso, y en Android 16+
// Live Update en Hyper Island.
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/notification_service.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake mínimo del plugin (patrón fix7): anota los show() y
/// responde a permiso/canales como concedido y no bloqueado.
class _ReminderFakeNotifications
    extends AndroidFlutterLocalNotificationsPlugin
    with MockPlatformInterfaceMixin {
  /// Avisos inmediatos mostrados (id, título, cuerpo).
  final shown = <({int id, String? title, String? body})>[];

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
  Future<bool?> areNotificationsEnabled() async => true;

  @override
  Future<List<AndroidNotificationChannel>?> getNotificationChannels() async =>
      const [];

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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ReminderFakeNotifications fake;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    await UserPrefs.load();
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
    fake = _ReminderFakeNotifications();
    FlutterLocalNotificationsPlatform.instance = fake;
    addTearDown(() {
      AppLang.code = 'es';
      UserPrefs.userName = '';
      ProgressService.instance.practiceDays.clear();
    });
  });

  /// Días de práctica: ayer sí, hoy no → racha 1 en juego.
  void atRisk() {
    final yesterday =
        DateTime.now().subtract(const Duration(days: 1));
    ProgressService.instance.practiceDays
      ..clear()
      ..add(ProgressService.dateKey(yesterday));
    expect(ProgressService.instance.streakNow, 1);
  }

  group('título: llama por el nombre (6 idiomas)', () {
    test('con nombre', () {
      expect(NotificationService.reminderTitle('Jorge', 'es'),
          '¡Jorge, ven por una lección!');
      expect(NotificationService.reminderTitle('Jorge', 'en'),
          'Jorge, come get a lesson!');
      expect(NotificationService.reminderTitle('Jorge', 'fr'),
          'Jorge, viens faire une leçon !');
      expect(NotificationService.reminderTitle('Jorge', 'it'),
          'Jorge, vieni a fare una lezione!');
      expect(NotificationService.reminderTitle('Jorge', 'pt'),
          'Jorge, vem fazer uma lição!');
      expect(NotificationService.reminderTitle('Jorge', 'ru'),
          'Jorge, иди на урок!');
    });

    test('sin nombre (null o vacío)', () {
      expect(NotificationService.reminderTitle(null, 'es'),
          '¡Ven por una lección!');
      expect(NotificationService.reminderTitle('', 'en'),
          'Come get a lesson!');
      expect(NotificationService.reminderTitle(null, 'ru'), 'Иди на урок!');
    });
  });

  group('cuenta atrás hasta medianoche', () {
    test('21:53:44 → "2 h 6 min" (el caso de la captura de Duolingo: '
        'a las 21:53 quedaban 2:06:16)', () {
      final from = DateTime(2026, 11, 15, 21, 53, 44);
      expect(NotificationService.timeLeftText(from, 'es'), '2 h 6 min');
      expect(NotificationService.timeLeftText(from, 'ru'), '2 ч 6 мин');
    });

    test('bordes: 23:30 → "30 min", 22:00 → "2 h", 00:00 → "24 h"',
        () {
      expect(NotificationService.timeLeftText(
              DateTime(2026, 11, 15, 23, 30), 'es'),
          '30 min');
      expect(NotificationService.timeLeftText(
              DateTime(2026, 11, 15, 23, 30), 'ru'),
          '30 мин');
      expect(NotificationService.timeLeftText(
              DateTime(2026, 11, 15, 22, 0), 'es'),
          '2 h');
      expect(NotificationService.timeLeftText(
              DateTime(2026, 11, 15, 0, 0), 'es'),
          '24 h');
    });

    test('23:59:30 → "menos de un minuto" (6 idiomas)', () {
      final from = DateTime(2026, 11, 15, 23, 59, 30);
      expect(NotificationService.timeLeftText(from, 'es'),
          'menos de un minuto');
      expect(NotificationService.timeLeftText(from, 'en'),
          'less than a minute');
      expect(NotificationService.timeLeftText(from, 'fr'),
          "moins d'une minute");
      expect(NotificationService.timeLeftText(from, 'it'),
          'meno di un minuto');
      expect(NotificationService.timeLeftText(from, 'pt'),
          'menos de um minuto');
      expect(NotificationService.timeLeftText(from, 'ru'), 'меньше минуты');
    });

    test('cuerpo con cuenta atrás en es/en/ru', () {
      final fire = DateTime(2026, 11, 15, 21, 53, 44);
      expect(NotificationService.streakCountdownBody(fire, 'es'),
          'Te quedan 2 h 6 min para no perder tu racha');
      expect(NotificationService.streakCountdownBody(fire, 'en'),
          'You have 2 h 6 min left to keep your streak');
      expect(NotificationService.streakCountdownBody(fire, 'ru'),
          'Осталось 2 ч 6 мин, чтобы не потерять серию');
    });
  });

  group('reminderContent: cuándo sale la cuenta atrás', () {
    // La hora de envío es HOY a las 21:53:44 (quedan 2 h 6 min):
    // la racha está en juego si hoy aún no se practicó. Un
    // fireTime en otro día rompería la comparación con
    // practiceDays (que es de hoy/ayer).
    final todayAt2153 = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      21,
      53,
      44,
    );

    test('racha en juego → cuerpo con cuenta atrás + título con nombre',
        () {
      UserPrefs.userName = 'Jorge Pozo';
      atRisk();
      final content = NotificationService.reminderContent(
        fireTime: todayAt2153,
      );
      expect(content.title, '¡Jorge, ven por una lección!');
      expect(content.body,
          'Te quedan 2 h 6 min para no perder tu racha');
    });

    test('ya practicó hoy → mensaje variado, nunca la cuenta atrás',
        () {
      UserPrefs.userName = 'Jorge Pozo';
      ProgressService.instance.practiceDays
        ..clear()
        ..add(ProgressService.dateKey(DateTime.now()));
      final content = NotificationService.reminderContent(
        fireTime: todayAt2153,
      );
      expect(content.title, '¡Jorge, ven por una lección!');
      expect(content.body,
          isNot('Te quedan 2 h 6 min para no perder tu racha'));
      expect(content.body, isNotEmpty);
    });

    test('sin racha (0 días) → mensaje variado', () {
      ProgressService.instance.practiceDays.clear();
      expect(ProgressService.instance.streakNow, 0);
      final content = NotificationService.reminderContent(
        fireTime: todayAt2153,
      );
      expect(content.body,
          isNot('Te quedan 2 h 6 min para no perder tu racha'));
      expect(content.body, isNotEmpty);
    });

    test('invitado ("Invitado" o sin nombre) → título sin nombre', () {
      atRisk();
      UserPrefs.userName = 'Invitado';
      final guest = NotificationService.reminderContent(
        fireTime: todayAt2153,
      );
      expect(guest.title, '¡Ven por una lección!');
      expect(guest.body, 'Te quedan 2 h 6 min para no perder tu racha');
      UserPrefs.userName = '';
      final noName = NotificationService.reminderContent(
        fireTime: todayAt2153,
      );
      expect(noName.title, '¡Ven por una lección!');
    });
  });

  group('cableado: lo que se prueba (9999) es lo que llega', () {
    test('con racha en juego, la prueba 9999 lleva nombre + cuenta atrás',
        () async {
      UserPrefs.userName = 'Jorge Pozo';
      atRisk();
      final result = await NotificationService.sendTestDetailed();
      expect(result.sent, isTrue);
      expect(fake.shown.length, 1);
      final shown = fake.shown.single;
      expect(shown.id, 9999);
      expect(shown.title, contains('Jorge'));
      // La cuenta se calcula para la hora de envío (ahora): el
      // cuerpo es "Te quedan … para no perder tu racha" con el
      // tiempo real que queda hoy.
      expect(shown.body, startsWith('Te quedan '));
      expect(shown.body, contains('para no perder tu racha'));
    });

    test('sin racha, la prueba 9999 lleva el mensaje variado', () async {
      UserPrefs.userName = 'Jorge Pozo';
      ProgressService.instance.practiceDays.clear();
      final result = await NotificationService.sendTestDetailed();
      expect(result.sent, isTrue);
      final shown = fake.shown.single;
      expect(shown.id, 9999);
      expect(shown.title, contains('Jorge'));
      expect(shown.body, isNot(contains('para no perder tu racha')));
    });
  });
}

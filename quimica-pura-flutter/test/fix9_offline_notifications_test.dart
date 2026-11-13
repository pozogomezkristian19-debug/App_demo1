// Pruebas de la Zona G2 (Quemia 7.1): la separación en DOS CAPAS
// de notificaciones.
//
//   1. SIN INTERNET (local, del teléfono): recordatorios de estudio
//      (61-180 min), la prueba de aviso, la confirmación al activar
//      y los avisos de logros/racha. Se programan y se muestran con
//      flutter_local_notifications, sin tocar Firebase, FCM ni la
//      red. El trabajo FCM de las zonas D1/D2/D3 no debe haberlos
//      roto ni haberlos hecho depender de la red.
//   2. CON FIREBASE (push FCM, necesita internet): solicitudes,
//      duelos, respuestas de soporte y avisos del admin. Si llegan
//      mientras no hay internet (o el push no llega), al abrir la
//      app aparecen en la bandeja por sincronización, sin depender
//      del push: syncFriendRequestInbox / syncDuelInbox /
//      syncToInbox (y SupportService.listenForReplies, que ya lo
//      hacía).
//
// Cómo se prueba lo "sin internet" aquí: este archivo NO importa
// firebase_core, NO llama a Firebase.initializeApp() y NO arranca
// PushService.init() en la mayoría de pruebas — en el proceso de
// test no existe Firebase en absoluto, igual que en el teléfono en
// modo avión (sin Firebase no hay token, ni FCM, ni red). Si la
// prueba de aviso o la tanda se enviaran igual, la ruta local no
// depende de Firebase. La prueba de PushService.init() comprueba
// además que un FCM no disponible (todo lanza) no rompe lo local:
// init() debe terminar sin lanzar y lo local seguir funcionando
// después.
//
// El falso del plugin es el mismo patrón de la Zona G (fix9): lo
// que se simula es el plugin local, no el teléfono.

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/notification_inbox.dart';
import 'package:quimica_pura/services/notification_service.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/push_service.dart';
import 'package:quimica_pura/services/social_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'test_helpers.dart';

/// Falso mínimo del plugin local (Zona G): permiso concedido,
/// show() que anota y zonedSchedule() que cuenta. Sin Firebase,
/// sin red, sin nada más.
class _OfflineFakeNotifications
    extends AndroidFlutterLocalNotificationsPlugin
    with MockPlatformInterfaceMixin {
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
    zonedScheduled++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  late _OfflineFakeNotifications fake;
  late InMemorySocialRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserPrefs.load();
    AppLang.code = 'es';
    await ProgressService.load();
    NotificationInbox.resetForTests();
    NotificationService.resetForTests();
    PushService.resetForTests();
    AnalyticsSync.resetForTests();
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
    fake = _OfflineFakeNotifications();
    FlutterLocalNotificationsPlatform.instance = fake;
    repo = InMemorySocialRepository(seedDemo: true);
    SocialService.setRepositoryForTests(repo);
    UserPrefs.userName = 'kristian';
  });

  tearDown(() {
    SocialService.resetForTests();
    AnalyticsSync.resetForTests();
    PushService.resetForTests();
    AppLang.code = 'es';
    UserPrefs.userName = '';
  });

  group('Zona G2 (1): lo local funciona sin Firebase ni FCM', () {
    testWidgets('la prueba de aviso se envía sin Firebase '
        'inicializado y sin arrancar PushService', (tester) async {
      // En este proceso no existe Firebase: ningún test de este
      // archivo llama a Firebase.initializeApp() ni a
      // PushService.init(). Si la prueba sale igual, su ruta
      // (permiso + canal + show local) no toca Firebase/FCM/red.
      final future = NotificationService.sendTestDetailed();
      // La copia del icono grande tiene un tope de 3 s en pruebas.
      await tester.pump(const Duration(seconds: 4));
      final result = await future;
      expect(result.outcome, NotificationTestOutcome.sent);
      expect(fake.shown.map((s) => s.id), contains(9999));
      expect(tester.takeException(), isNull);
    });

    testWidgets('la confirmación al activar también se envía sin '
        'Firebase ni FCM', (tester) async {
      final future = NotificationService.sendEnabledConfirmationDetailed();
      await tester.pump(const Duration(seconds: 4));
      final result = await future;
      expect(result.outcome, NotificationTestOutcome.sent);
      expect(fake.shown.map((s) => s.id), contains(9998));
      expect(tester.takeException(), isNull);
    });

    testWidgets('la tanda de recordatorios se programa sin Firebase '
        'ni FCM (3 avisos)', (tester) async {
      // OJO (lección de esta zona): en testWidgets el tiempo es
      // falso y los temporizadores solo avanzan con pump(): la
      // copia del icono grande lleva un tope de 3 s y el
      // rootBundle.load de un asset que no existe en tests no se
      // resuelve solo, así que esperar el futuro SIN bombear deja
      // la prueba colgada para siempre. Patrón de la Zona G:
      // arrancar el futuro, bombear y luego esperar.
      final initFuture = NotificationService.init();
      await tester.pump(const Duration(seconds: 4));
      expect(await initFuture, isTrue);
      final future = NotificationService.scheduleNext();
      await tester.pump(const Duration(seconds: 4));
      final scheduled = await future;
      expect(scheduled, hasLength(3));
      expect(fake.zonedScheduled, 3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PushService.init() con FCM no disponible termina '
        'sin lanzar y lo local sigue funcionando después',
        (tester) async {
      // FCM no disponible: sin Firebase inicializado, cada paso de
      // init() lanza y se traga dentro (try/catch + timeouts).
      // No debe lanzar, no debe colgar y no debe romper lo local.
      // El tope exterior de _ensurePermission es de 15 s: se
      // bombean 20 s para que dispare aunque alguna llamada no
      // respondiera nunca.
      final pushFuture = PushService.init();
      await tester.pump(const Duration(seconds: 20));
      await pushFuture;
      final testFuture = NotificationService.sendTestDetailed();
      await tester.pump(const Duration(seconds: 4));
      expect((await testFuture).outcome, NotificationTestOutcome.sent);
      expect(fake.shown.map((s) => s.id), contains(9999));
      final initFuture = NotificationService.init();
      await tester.pump(const Duration(seconds: 4));
      expect(await initFuture, isTrue);
      final scheduleFuture = NotificationService.scheduleNext();
      await tester.pump(const Duration(seconds: 4));
      final scheduled = await scheduleFuture;
      expect(scheduled, hasLength(3));
      expect(fake.zonedScheduled, 3);
      expect(tester.takeException(), isNull);
    });
  });

  group('Zona G2 (2): al abrir, la bandeja se sincroniza sin push', () {
    test('una solicitud entrante aparece en la bandeja con '
        'syncFriendRequestInbox', () async {
      final req = repo.simulateIncomingFriendRequest('valeria');
      expect(req, isNotNull);
      await SocialService.syncFriendRequestInbox();
      final entry = NotificationInbox.entries.firstWhere(
        (e) => e.id == 'friend-request-${req!.id}',
      );
      expect(entry.kind, InboxKind.friendRequest);
      // Segunda sincronización: sin duplicados.
      await SocialService.syncFriendRequestInbox();
      expect(
        NotificationInbox.entries
            .where((e) => e.id == 'friend-request-${req!.id}')
            .length,
        1,
      );
    });

    test('un reto de duelo entrante aparece en la bandeja con '
        'syncDuelInbox', () async {
      final duel = repo.simulateIncomingDuel('Ana');
      await SocialService.syncDuelInbox();
      final entry = NotificationInbox.entries.firstWhere(
        (e) => e.id == 'duel-challenge-${duel.matchId}',
      );
      expect(entry.kind, InboxKind.duel);
      // Segunda sincronización: sin duplicados.
      await SocialService.syncDuelInbox();
      expect(
        NotificationInbox.entries
            .where((e) => e.id == 'duel-challenge-${duel.matchId}')
            .length,
        1,
      );
    });

    test('syncDuelInbox no duplica un reto que ya llegó por push '
        '(mismo id)', () async {
      final duel = repo.simulateIncomingDuel('Ana');
      // El push ya dejó su entrada (mismo id que usa la sync).
      await NotificationInbox.addIfAbsent(
        id: 'duel-challenge-${duel.matchId}',
        kind: InboxKind.duel,
        title: '¡Te retaron a un duelo!',
        body: 'Ana te retó a un duelo en Quemia.',
        data: {'duelId': duel.matchId, 'pushType': 'duel_challenge'},
      );
      await SocialService.syncDuelInbox();
      expect(
        NotificationInbox.entries
            .where((e) => e.id == 'duel-challenge-${duel.matchId}')
            .length,
        1,
      );
    });

    test('un duelo saliente (yo reté) no deja entrada de reto',
        () async {
      // Sin duelos entrantes simulados, la sync no inventa nada.
      await SocialService.syncDuelInbox();
      expect(
        NotificationInbox.entries
            .where((e) => e.kind == InboxKind.duel),
        isEmpty,
      );
    });
  });
}

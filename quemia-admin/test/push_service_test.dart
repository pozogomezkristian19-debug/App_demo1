// Push FCM del panel de admin: lógica de enrutado, contenido de la
// notificación y guardado del token (con fakes, sin Firebase real).
//
// Sigue el estilo de owner_bootstrap_test.dart: FakeAdminsRepository de
// repositories.dart + fakes locales de mensajería y notificador.

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quemia_admin/design.dart';
import 'package:quemia_admin/push_service.dart';
import 'package:quemia_admin/repositories.dart';

import 'test_data.dart';

NotificationSettings _settings(AuthorizationStatus status) =>
    NotificationSettings(
      alert: AppleNotificationSetting.notSupported,
      announcement: AppleNotificationSetting.notSupported,
      authorizationStatus: status,
      badge: AppleNotificationSetting.notSupported,
      carPlay: AppleNotificationSetting.notSupported,
      lockScreen: AppleNotificationSetting.notSupported,
      notificationCenter: AppleNotificationSetting.notSupported,
      showPreviews: AppleShowPreviewSetting.notSupported,
      timeSensitive: AppleNotificationSetting.notSupported,
      criticalAlert: AppleNotificationSetting.notSupported,
      sound: AppleNotificationSetting.notSupported,
      providesAppNotificationSettings: AppleNotificationSetting.notSupported,
    );

class FakeMessagingClient implements MessagingClient {
  String? token = 'fake-fcm-token-1';
  AuthorizationStatus status = AuthorizationStatus.notDetermined;
  RemoteMessage? initialMessage;
  var requestPermissionCalls = 0;

  final _tokenRefresh = StreamController<String>.broadcast();
  final _onMessage = StreamController<RemoteMessage>.broadcast();
  final _onOpened = StreamController<RemoteMessage>.broadcast();

  void emitTokenRefresh(String token) => _tokenRefresh.add(token);
  void emitMessage(RemoteMessage message) => _onMessage.add(message);
  void emitOpened(RemoteMessage message) => _onOpened.add(message);

  Future<void> close() async {
    await _tokenRefresh.close();
    await _onMessage.close();
    await _onOpened.close();
  }

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => _tokenRefresh.stream;

  @override
  Stream<RemoteMessage> get onMessage => _onMessage.stream;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp => _onOpened.stream;

  @override
  Future<RemoteMessage?> getInitialMessage() async => initialMessage;

  @override
  Future<NotificationSettings> getNotificationSettings() async =>
      _settings(status);

  @override
  Future<NotificationSettings> requestPermission() async {
    requestPermissionCalls++;
    return _settings(AuthorizationStatus.authorized);
  }
}

class FakePushNotifier implements PushNotifier {
  final List<({String title, String body, String type})> shown = [];
  String? launchType;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> show({
    required String title,
    required String body,
    required String type,
  }) async {
    shown.add((title: title, body: body, type: type));
  }

  @override
  Future<String?> launchPayload() async => launchType;
}

PushService _service({
  required FakeAdminsRepository admins,
  required FakeMessagingClient messaging,
  required FakePushNotifier notifier,
}) =>
    PushService(admins: admins, messaging: messaging, notifier: notifier);

void main() {
  setUp(() {
    PushService.pendingSection.value = null;
  });

  tearDown(() {
    PushService.pendingSection.value = null;
  });

  group('enrutado por tipo de push', () {
    test('nuevo usuario -> Usuarios', () {
      expect(sectionForPushType('admin_new_user'), AdminSection.usuarios);
    });

    test('nuevo reporte -> Reportes', () {
      expect(sectionForPushType('admin_new_report'), AdminSection.reportes);
    });

    test('nuevo mensaje de soporte -> Soporte', () {
      expect(sectionForPushType('admin_new_support'), AdminSection.soporte);
    });

    test('tipo desconocido o nulo -> no navega', () {
      expect(sectionForPushType('otro'), isNull);
      expect(sectionForPushType(null), isNull);
      expect(sectionForPushType(''), isNull);
    });
  });

  group('contenido de la notificación', () {
    test('el payload de notificación manda sobre los fallbacks', () {
      final content = contentForMessage(
        const {'type': 'admin_new_user'},
        notificationTitle: 'Se unió laura',
        notificationBody: 'Laura se registró hace un momento.',
      );
      expect(content.title, 'Se unió laura');
      expect(content.body, 'Laura se registró hace un momento.');
    });

    test('mensaje de solo datos: usa title/body del data', () {
      final content = contentForMessage(const {
        'type': 'admin_new_report',
        'title': 'Reporte nuevo',
        'body': 'Miguel reportó una pregunta.',
      });
      expect(content.title, 'Reporte nuevo');
      expect(content.body, 'Miguel reportó una pregunta.');
    });

    test('mensaje de solo datos sin textos: fallbacks en español', () {
      expect(
        contentForMessage(const {'type': 'admin_new_user'}).title,
        'Nuevo usuario',
      );
      expect(
        contentForMessage(const {'type': 'admin_new_report'}).title,
        'Nueva pregunta reportada',
      );
      expect(
        contentForMessage(const {'type': 'admin_new_support'}).title,
        'Nuevo mensaje de soporte',
      );
      expect(
        contentForMessage(const {'type': 'admin_new_support'}).body,
        'Un usuario escribió a soporte.',
      );
    });

    test('tipo desconocido: texto genérico del panel', () {
      final content = contentForMessage(const {'type': 'raro'});
      expect(content.title, 'Quemia Admin');
    });
  });

  group('guardado del token FCM', () {
    test('registerAdmin guarda el token en el documento del admin', () async {
      final admins = FakeAdminsRepository([ownerRecord()]);
      final messaging = FakeMessagingClient();
      final notifier = FakePushNotifier();
      final service = _service(
        admins: admins,
        messaging: messaging,
        notifier: notifier,
      );

      await service.registerAdmin(ownerUid);

      expect(admins.fcmTokenFor(ownerUid), 'fake-fcm-token-1');
      expect(admins.fcmTokenUpdatedAtFor(ownerUid), isNotNull);
      // No se escribe nada en otros documentos.
      expect(admins.fcmTokenFor(adminUid), isNull);
      await messaging.close();
    });

    test('sin token no se escribe nada', () async {
      final admins = FakeAdminsRepository([ownerRecord()]);
      final messaging = FakeMessagingClient()..token = null;
      final service = _service(
        admins: admins,
        messaging: messaging,
        notifier: FakePushNotifier(),
      );

      await service.registerAdmin(ownerUid);

      expect(admins.fcmTokenFor(ownerUid), isNull);
      await messaging.close();
    });

    test('onTokenRefresh vuelve a guardar el token nuevo', () async {
      final admins = FakeAdminsRepository([ownerRecord()]);
      final messaging = FakeMessagingClient();
      final service = _service(
        admins: admins,
        messaging: messaging,
        notifier: FakePushNotifier(),
      );

      await service.registerAdmin(ownerUid);
      messaging.emitTokenRefresh('fake-fcm-token-2');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(admins.fcmTokenFor(ownerUid), 'fake-fcm-token-2');
      await messaging.close();
    });

    test('tras unregisterAdmin el refresh ya no guarda', () async {
      final admins = FakeAdminsRepository([ownerRecord()]);
      final messaging = FakeMessagingClient();
      final service = _service(
        admins: admins,
        messaging: messaging,
        notifier: FakePushNotifier(),
      );

      await service.registerAdmin(ownerUid);
      service.unregisterAdmin();
      messaging.emitTokenRefresh('fake-fcm-token-2');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(admins.fcmTokenFor(ownerUid), 'fake-fcm-token-1');
      await messaging.close();
    });
  });

  group('permiso de notificaciones', () {
    test('notDetermined -> se pide UNA vez', () async {
      final messaging = FakeMessagingClient()
        ..status = AuthorizationStatus.notDetermined;
      final service = _service(
        admins: FakeAdminsRepository(),
        messaging: messaging,
        notifier: FakePushNotifier(),
      );

      await service.init();

      expect(messaging.requestPermissionCalls, 1);
      await messaging.close();
    });

    test('ya autorizado -> no se vuelve a pedir', () async {
      final messaging = FakeMessagingClient()
        ..status = AuthorizationStatus.authorized;
      final service = _service(
        admins: FakeAdminsRepository(),
        messaging: messaging,
        notifier: FakePushNotifier(),
      );

      await service.init();

      expect(messaging.requestPermissionCalls, 0);
      await messaging.close();
    });

    test('ya denegado -> no se vuelve a pedir', () async {
      final messaging = FakeMessagingClient()
        ..status = AuthorizationStatus.denied;
      final service = _service(
        admins: FakeAdminsRepository(),
        messaging: messaging,
        notifier: FakePushNotifier(),
      );

      await service.init();

      expect(messaging.requestPermissionCalls, 0);
      await messaging.close();
    });
  });

  group('mensajes en primer plano y toques', () {
    test('onMessage muestra la notificación local con el tipo', () async {
      final messaging = FakeMessagingClient();
      final notifier = FakePushNotifier();
      final service = _service(
        admins: FakeAdminsRepository(),
        messaging: messaging,
        notifier: notifier,
      );
      await service.init();

      messaging.emitMessage(
        const RemoteMessage(
          data: {'type': 'admin_new_report'},
          notification: RemoteNotification(
            title: 'Reporte nuevo',
            body: 'Sofía reportó una pregunta.',
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(notifier.shown.length, 1);
      expect(notifier.shown.single.title, 'Reporte nuevo');
      expect(notifier.shown.single.body, 'Sofía reportó una pregunta.');
      expect(notifier.shown.single.type, 'admin_new_report');
      await messaging.close();
    });

    test('onMessage de solo datos usa los fallbacks en español', () async {
      final messaging = FakeMessagingClient();
      final notifier = FakePushNotifier();
      final service = _service(
        admins: FakeAdminsRepository(),
        messaging: messaging,
        notifier: notifier,
      );
      await service.init();

      messaging.emitMessage(
        const RemoteMessage(data: {'type': 'admin_new_support'}),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(notifier.shown.length, 1);
      expect(notifier.shown.single.title, 'Nuevo mensaje de soporte');
      expect(notifier.shown.single.type, 'admin_new_support');
      await messaging.close();
    });

    test('onMessageOpenedApp enruta a la sección del push', () async {
      final messaging = FakeMessagingClient();
      final service = _service(
        admins: FakeAdminsRepository(),
        messaging: messaging,
        notifier: FakePushNotifier(),
      );
      await service.init();

      messaging.emitOpened(
        const RemoteMessage(data: {'type': 'admin_new_support'}),
      );
      await Future<void>.delayed(Duration.zero);

      expect(PushService.pendingSection.value, AdminSection.soporte);
      await messaging.close();
    });

    test('getInitialMessage enruta al abrir desde un push', () async {
      final messaging = FakeMessagingClient()
        ..initialMessage = const RemoteMessage(
          data: {'type': 'admin_new_user'},
        );
      final service = _service(
        admins: FakeAdminsRepository(),
        messaging: messaging,
        notifier: FakePushNotifier(),
      );

      await service.init();

      expect(PushService.pendingSection.value, AdminSection.usuarios);
      await messaging.close();
    });

    test('toque en notificación local enruta por su payload', () {
      PushService.onLocalNotificationTap(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: 'admin_new_report',
        ),
      );
      expect(PushService.pendingSection.value, AdminSection.reportes);
    });

    test('toque con payload desconocido no navega', () {
      PushService.onLocalNotificationTap(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: 'otro',
        ),
      );
      expect(PushService.pendingSection.value, isNull);
    });
  });
}

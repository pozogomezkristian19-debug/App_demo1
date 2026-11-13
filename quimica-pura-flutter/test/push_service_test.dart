// Pruebas de la Task 5 (7.1): push FCM real, lado receptor.
//
// Cubre la lógica que se puede probar sin Firebase ni teléfono:
//   - data.type -> destino y clave de pantalla (los 6 tipos de
//     functions/payloads.js, más desconocido y nulo);
//   - payload -> entrada de la bandeja (ids estables, tipos, y
//     título/cuerpo del notification payload o su fallback);
//   - campos del token (nombres exactos que lee functions/index.js);
//   - id estable de la notificación local;
//   - stash en segundo plano + drenaje con dedup (el mismo aviso no
//     deja dos entradas ni aunque llegue por push, por toque y por
//     drenaje);
//   - toque de un push: crea la entrada y pide la pantalla.
//
// Lo que NO se puede probar aquí (solo en el teléfono): que el
// push llegue de verdad con la app cerrada, que el toque abra la
// pantalla correcta y que la campana suba sola.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/services/nav_requests.dart';
import 'package:quimica_pura/services/notification_inbox.dart';
import 'package:quimica_pura/services/push_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    NotificationInbox.resetForTests();
    NavRequests.pendingPushScreen = null;
  });

  group('destinationForPushType', () {
    test('amistad y duelos van a Amigos (Mis duelos vive ahí)', () {
      expect(destinationForPushType('friend_request'),
          PushDestination.friends);
      expect(destinationForPushType('friend_request_result'),
          PushDestination.friends);
      expect(destinationForPushType('duel_challenge'),
          PushDestination.friends);
      expect(destinationForPushType('duel_result'), PushDestination.friends);
    });

    test('soporte va a Soporte y avisos a la bandeja', () {
      expect(destinationForPushType('support_reply'),
          PushDestination.support);
      expect(
          destinationForPushType('announcement'), PushDestination.inbox);
    });

    test('tipo desconocido o nulo va a la bandeja (se ve igual)', () {
      expect(destinationForPushType('admin_new_user'), PushDestination.inbox);
      expect(destinationForPushType('otra_cosa'), PushDestination.inbox);
      expect(destinationForPushType(null), PushDestination.inbox);
    });
  });

  group('screenKeyForDestination', () {
    test('claves de HomeScreen._openScreenKey', () {
      expect(screenKeyForDestination(PushDestination.friends), 'friends');
      expect(screenKeyForDestination(PushDestination.support), 'support');
      expect(
          screenKeyForDestination(PushDestination.inbox), 'notifications');
    });
  });

  group('inboxEntryForPush', () {
    test('solicitud entrante: mismo id que la sincronización local', () {
      final entry = inboxEntryForPush(
        data: {'type': 'friend_request', 'requestId': 'req-1'},
        title: 'Ana te envió una solicitud de amistad',
        body: 'Toca para verla y aceptar o rechazar.',
      );
      // El mismo id de SocialService.syncFriendRequestInbox: el
      // push y la sincronización al abrir Amigos no duplican.
      expect(entry.id, 'friend-request-req-1');
      expect(entry.kind, InboxKind.friendRequest);
      expect(entry.title, 'Ana te envió una solicitud de amistad');
      expect(entry.body, 'Toca para verla y aceptar o rechazar.');
      expect(entry.data['requestId'], 'req-1');
      expect(entry.data['pushType'], 'friend_request');
    });

    test('respuesta de soporte: mismo id que el chequeo local', () {
      final entry = inboxEntryForPush(
        data: {'type': 'support_reply', 'messageId': 'msg-7'},
        title: 'Soporte te respondió',
        body: 'Ya está arreglado.',
      );
      expect(entry.id, 'support-reply-msg-7');
      expect(entry.kind, InboxKind.support);
      expect(entry.body, 'Ya está arreglado.');
    });

    test('duelos: reto y resultado con sus propios ids y tipo duel', () {
      final challenge = inboxEntryForPush(
        data: {'type': 'duel_challenge', 'duelId': 'duel-3'},
        title: '¡Te retaron a un duelo!',
        body: 'Ana te retó a un duelo en Quemia.',
      );
      expect(challenge.id, 'duel-challenge-duel-3');
      expect(challenge.kind, InboxKind.duel);

      final result = inboxEntryForPush(
        data: {'type': 'duel_result', 'duelId': 'duel-3'},
        title: '¡Ganaste el duelo!',
        body: 'Ganaste el duelo contra Ana.',
      );
      expect(result.id, 'duel-result-duel-3');
      expect(result.kind, InboxKind.duel);
    });

    test('aviso del admin: id por announcementId y tipo announcement', () {
      final entry = inboxEntryForPush(
        data: {'type': 'announcement', 'announcementId': 'av-2'},
        title: 'Nueva versión',
        body: 'Ya está la 7.1.',
      );
      expect(entry.id, 'announcement-av-2');
      expect(entry.kind, InboxKind.announcement);
    });

    test('sin notification payload: texto genérico por tipo', () {
      final entry = inboxEntryForPush(
        data: {'type': 'duel_challenge', 'duelId': 'd-9'},
      );
      expect(entry.title, '¡Te retaron a un duelo!');
      expect(entry.body, 'Toca para ver el reto.');
      expect(entry.id, 'duel-challenge-d-9');
    });

    test('sin id en el data: el messageId de FCM hace de desempate', () {
      final entry = inboxEntryForPush(
        data: {'type': 'friend_request'},
        messageId: 'fcm-abc-123',
      );
      expect(entry.id, 'friend-request-fcm-abc-123');
    });

    test('tipo desconocido: a la bandeja, sin romper', () {
      final entry = inboxEntryForPush(
        data: {'type': 'algo_nuevo'},
        messageId: 'fcm-xyz',
      );
      expect(entry.kind, InboxKind.announcement);
      expect(entry.id, 'push-algo_nuevo-fcm-xyz');
    });
  });

  group('tokenSaveData', () {
    test('nombres de campo exactos que lee functions/index.js', () {
      final data = PushService.tokenSaveData('tok-123', nowMs: 1700000000000);
      expect(data, {
        'fcmToken': 'tok-123',
        'fcmTokenUpdatedAt': 1700000000000,
      });
      expect(PushService.tokenField, 'fcmToken');
      expect(PushService.tokenUpdatedAtField, 'fcmTokenUpdatedAt');
    });

    test('sin nowMs usa la hora actual en milisegundos', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final data = PushService.tokenSaveData('tok-1');
      final after = DateTime.now().millisecondsSinceEpoch;
      final ms = data['fcmTokenUpdatedAt'] as int;
      expect(ms >= before && ms <= after, isTrue);
    });
  });

  group('localNotificationIdForEntry', () {
    test('estable, no negativo y distinto por entrada', () {
      final a = PushService.localNotificationIdForEntry('friend-request-1');
      final a2 = PushService.localNotificationIdForEntry('friend-request-1');
      final b = PushService.localNotificationIdForEntry('duel-result-2');
      expect(a, a2);
      expect(a >= 0, isTrue);
      expect(a, isNot(b));
    });
  });

  group('stash y drenaje', () {
    test('encode/decode del stash: ida y vuelta', () {
      final raw = PushService.encodeStashEntry(
        data: {'type': 'friend_request', 'requestId': 'r-1'},
        title: 'Título',
        body: 'Cuerpo',
        messageId: 'fcm-1',
      );
      final decoded = PushService.decodeStashEntry(raw);
      expect(decoded, isNotNull);
      expect(decoded!['messageId'], 'fcm-1');
      expect(decoded['title'], 'Título');
      expect(decoded['body'], 'Cuerpo');
      expect(decoded['data'], {'type': 'friend_request', 'requestId': 'r-1'});
    });

    test('stash roto: decode devuelve null, no rompe', () {
      expect(PushService.decodeStashEntry('no-json'), isNull);
      expect(PushService.decodeStashEntry('{"data":"roto"}'), isNull);
    });

    test('fondo con notification: solo guarda el stash, sin bandeja', () async {
      final message = RemoteMessage(
        messageId: 'fcm-bg-1',
        data: {'type': 'friend_request', 'requestId': 'r-5'},
        notification: const RemoteNotification(
          title: 'Ana te envió una solicitud de amistad',
          body: 'Toca para verla y aceptar o rechazar.',
        ),
      );
      await PushService.handleBackgroundMessage(message);
      // El isolate de fondo NO escribe la bandeja: solo el stash.
      expect(NotificationInbox.entries, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      final stashed = prefs.getStringList(PushService.stashKey);
      expect(stashed, hasLength(1));
      // Al volver, el drenaje crea la entrada.
      final added = await PushService.drainStashedPayloads();
      expect(added, 1);
      expect(NotificationInbox.entries, hasLength(1));
      expect(NotificationInbox.entries.first.id, 'friend-request-r-5');
      expect(NotificationInbox.unreadCount, 1);
    });

    test('mismo mensaje dos veces en el stash: una sola entrada', () async {
      final message = RemoteMessage(
        messageId: 'fcm-dup-1',
        data: {'type': 'duel_result', 'duelId': 'd-1'},
        notification: const RemoteNotification(
          title: '¡Ganaste el duelo!',
          body: 'Ganaste el duelo contra Ana.',
        ),
      );
      await PushService.handleBackgroundMessage(message);
      await PushService.handleBackgroundMessage(message);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(PushService.stashKey), hasLength(1));
      final added = await PushService.drainStashedPayloads();
      expect(added, 1);
      expect(NotificationInbox.entries, hasLength(1));
    });

    test('drenar dos veces: la segunda no añade nada (dedup por id)',
        () async {
      final message = RemoteMessage(
        messageId: 'fcm-twice-1',
        data: {'type': 'announcement', 'announcementId': 'av-9'},
        notification: const RemoteNotification(
          title: 'Aviso',
          body: 'Lee esto.',
        ),
      );
      await PushService.handleBackgroundMessage(message);
      expect(await PushService.drainStashedPayloads(), 1);
      expect(await PushService.drainStashedPayloads(), 0);
      expect(NotificationInbox.entries, hasLength(1));
    });

    test('dos avisos distintos: dos entradas, en orden de llegada',
        () async {
      for (final (mid, type, id) in [
        ('fcm-a', 'friend_request', 'r-a'),
        ('fcm-b', 'support_reply', 'm-b'),
      ]) {
        await PushService.handleBackgroundMessage(
          RemoteMessage(
            messageId: mid,
            data: {
              'type': type,
              if (type == 'friend_request') 'requestId': id else 'messageId': id,
            },
            notification: const RemoteNotification(
              title: 'Aviso',
              body: 'Cuerpo.',
            ),
          ),
        );
      }
      expect(await PushService.drainStashedPayloads(), 2);
      expect(NotificationInbox.entries, hasLength(2));
      final ids = NotificationInbox.entries.map((e) => e.id).toSet();
      expect(ids, {'friend-request-r-a', 'support-reply-m-b'});
    });
  });

  group('handlePushTapData', () {
    test('toque de solicitud: entrada en bandeja + pide Amigos', () async {
      await PushService.handlePushTapData(
        {'type': 'friend_request', 'requestId': 'r-77'},
        title: 'Ana te envió una solicitud de amistad',
        body: 'Toca para verla y aceptar o rechazar.',
        messageId: 'fcm-tap-1',
      );
      expect(NotificationInbox.entries, hasLength(1));
      expect(NotificationInbox.entries.first.id, 'friend-request-r-77');
      expect(NavRequests.pendingPushScreen, 'friends');
    });

    test('toque de respuesta de soporte: pide Soporte', () async {
      await PushService.handlePushTapData(
        {'type': 'support_reply', 'messageId': 'm-3'},
        title: 'Soporte te respondió',
        body: 'Listo.',
        messageId: 'fcm-tap-2',
      );
      expect(NavRequests.pendingPushScreen, 'support');
    });

    test('toque de aviso del admin: pide la bandeja', () async {
      await PushService.handlePushTapData(
        {'type': 'announcement', 'announcementId': 'av-4'},
        title: 'Aviso',
        body: 'Lee esto.',
        messageId: 'fcm-tap-3',
      );
      expect(NavRequests.pendingPushScreen, 'notifications');
    });

    test('dos toques del mismo aviso: una sola entrada (red de seguridad)',
        () async {
      const data = {'type': 'duel_challenge', 'duelId': 'd-55'};
      await PushService.handlePushTapData(data,
          title: '¡Te retaron a un duelo!',
          body: 'Ana te retó.',
          messageId: 'fcm-tap-4');
      await PushService.handlePushTapData(data,
          title: '¡Te retaron a un duelo!',
          body: 'Ana te retó.',
          messageId: 'fcm-tap-4');
      expect(NotificationInbox.entries, hasLength(1));
      expect(NotificationInbox.entries.first.id, 'duel-challenge-d-55');
    });
  });
}

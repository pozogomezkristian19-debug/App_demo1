// Tests de amigos POR SOLICITUD (ronda 2d, Quemia 7.0): enviar,
// confirmar, eliminar, cancelar, anti-duplicado, sin internet y
// la bandeja de notificaciones sin duplicados.
//
// Todo contra InMemorySocialRepository (sin Firestore real): lo
// online de verdad (red, Firestore, latencias, reglas) NO queda
// probado aquí — ver el informe final.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/friends_screen.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/notification_inbox.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/social_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late InMemorySocialRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    NotificationInbox.resetForTests();
    await ProgressService.load();
    UserPrefs.userName = 'kristian';
    repo = InMemorySocialRepository(seedDemo: true);
    SocialService.setRepositoryForTests(repo);
    AnalyticsSync.resetForTests();
  });

  tearDown(() {
    SocialService.resetForTests();
    AnalyticsSync.resetForTests();
    UserPrefs.userName = '';
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(360, 1000),
  }) async {
    tester.view.physicalSize = Size(size.width * 2, size.height * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: screen,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> _settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  bool _isFriend(String deviceId) =>
      repo.currentFriends.any((f) => f.deviceId == deviceId);

  group('solicitudes de amistad', () {
    test('enviar: llega como solicitud, no como amigo directo',
        () async {
      final result = await SocialService.sendFriendRequest('valeria');
      expect(result, FriendRequestResult.sent);
      expect(_isFriend('dev-valeria'), isFalse);
      final sent = await SocialService.sentFriendRequests();
      expect(sent.length, 1);
      expect(sent.first.receiverUsername, 'valeria');
      expect(sent.first.status, 'pendiente');
      expect(await SocialService.incomingFriendRequests(), isEmpty);
    });

    test('enviar dos veces: sin duplicado', () async {
      expect(await SocialService.sendFriendRequest('valeria'),
          FriendRequestResult.sent);
      expect(await SocialService.sendFriendRequest('valeria'),
          FriendRequestResult.alreadySent);
      expect((await SocialService.sentFriendRequests()).length, 1);
    });

    test('validaciones: a mí mismo, inexistente y ya amigo', () async {
      expect(await SocialService.sendFriendRequest('kristian'),
          FriendRequestResult.self);
      expect(await SocialService.sendFriendRequest('nadie123'),
          FriendRequestResult.notFound);
      // laura ya es amiga en la semilla (demo).
      expect(await SocialService.sendFriendRequest('laura'),
          FriendRequestResult.alreadyFriends);
    });

    test('si ya me envió una: incomingPending, no otra salida',
        () async {
      repo.simulateIncomingFriendRequest('daniel');
      expect(await SocialService.sendFriendRequest('daniel'),
          FriendRequestResult.incomingPending);
      expect(await SocialService.sentFriendRequests(), isEmpty);
      expect((await SocialService.incomingFriendRequests()).length, 1);
    });

    test('confirmar: los dos quedan amigos y la bandeja avisa una vez',
        () async {
      final req = repo.simulateIncomingFriendRequest('daniel')!;
      // La bandeja se sincroniza al abrir Amigos, ANTES de confirmar:
      // una entrada por solicitud entrante pendiente.
      await SocialService.syncFriendRequestInbox();
      expect(NotificationInbox.entries.length, 1);
      expect(NotificationInbox.entries.first.kind,
          InboxKind.friendRequest);
      expect(NotificationInbox.entries.first.title,
          'daniel te envió una solicitud de amistad');
      expect(NotificationInbox.unreadCount, 1);

      expect(await SocialService.acceptFriendRequest(req.id), isTrue);
      expect(_isFriend('dev-daniel'), isTrue);
      // Yo quedo en la lista de amigos del remitente.
      expect(repo.otherSideFriends['dev-daniel'], contains('dev-kristian'));
      expect(await SocialService.incomingFriendRequests(), isEmpty);

      // Sincronizar de nuevo NO duplica (una entrada por solicitud).
      await SocialService.syncFriendRequestInbox();
      expect(NotificationInbox.entries.length, 1);
      expect(NotificationInbox.unreadCount, 1);

      // Y no vuelve a marcar como no leída una que ya se leyó.
      await NotificationInbox.markRead(
          NotificationInbox.entries.first.id);
      await SocialService.syncFriendRequestInbox();
      expect(NotificationInbox.entries.length, 1);
      expect(NotificationInbox.entries.first.read, isTrue);
      expect(NotificationInbox.unreadCount, 0);
    });

    test('confirmar dos veces: la segunda falla', () async {
      final req = repo.simulateIncomingFriendRequest('daniel')!;
      expect(await SocialService.acceptFriendRequest(req.id), isTrue);
      expect(await SocialService.acceptFriendRequest(req.id), isFalse);
    });

    test('eliminar: desaparece y no son amigos', () async {
      final req = repo.simulateIncomingFriendRequest('rosa')!;
      await SocialService.rejectFriendRequest(req.id);
      expect(await SocialService.incomingFriendRequests(), isEmpty);
      expect(_isFriend('dev-rosa'), isFalse);
      expect(repo.currentFriendRequests
          .firstWhere((r) => r.id == req.id)
          .status, 'rechazada');
    });

    test('cancelar la enviada: desaparece', () async {
      await SocialService.sendFriendRequest('valeria');
      final sent = await SocialService.sentFriendRequests();
      expect(sent.length, 1);
      await SocialService.cancelFriendRequest(sent.first.id);
      expect(await SocialService.sentFriendRequests(), isEmpty);
      expect(_isFriend('dev-valeria'), isFalse);
    });

    test('quitar a un amigo de solicitud: no vuelve solo', () async {
      final req = repo.simulateIncomingFriendRequest('daniel')!;
      await SocialService.acceptFriendRequest(req.id);
      expect(_isFriend('dev-daniel'), isTrue);
      await SocialService.removeFriend('dev-daniel');
      expect(_isFriend('dev-daniel'), isFalse);
      // La solicitud aceptada quedó rechazada: la amistad no
      // reaparece sola al recargar.
      expect(repo.currentFriendRequests
          .firstWhere((r) => r.id == req.id)
          .status, 'rechazada');
    });

    test('sin internet: se encola y se envía sola al volver', () async {
      repo.onlineFlag = false;
      expect(await SocialService.sendFriendRequest('valeria'),
          FriendRequestResult.queued);
      expect(repo.queuedRequestUsernames, contains('valeria'));
      expect(await SocialService.sentFriendRequests(), isEmpty);

      // Reintentar sin internet no la pierde ni la duplica.
      expect(await SocialService.retryPendingFriendRequests(), 0);
      expect(repo.queuedRequestUsernames, ['valeria']);

      repo.onlineFlag = true;
      expect(await SocialService.retryPendingFriendRequests(), 1);
      expect(repo.queuedRequestUsernames, isEmpty);
      expect((await SocialService.sentFriendRequests()).length, 1);
      expect((await SocialService.sentFriendRequests())
          .first
          .receiverUsername, 'valeria');
    });

    testWidgets('la sección Solicitudes: confirmar, eliminar y cancelar',
        (tester) async {
      repo.simulateIncomingFriendRequest('daniel');
      repo.simulateSentFriendRequest('rosa');
      await pumpScreen(tester, const FriendsScreen(isGoogleLinked: true));
      await _settle(tester);
      expect(find.text(tr('friendsRequestsTitle')), findsOneWidget);
      expect(find.text('daniel'), findsOneWidget);
      expect(find.text('rosa'), findsOneWidget);
      expect(find.text(tr('friendsRequestAccept').toUpperCase()),
          findsOneWidget);
      expect(find.text(tr('friendsRequestReject').toUpperCase()),
          findsOneWidget);
      expect(find.text(tr('friendsRequestCancel').toUpperCase()),
          findsOneWidget);
      // Un pendiente NO se puede retar: Retar solo existe en la
      // fila de amigo confirmado.
      expect(find.text(tr('friendsChallenge').toUpperCase()),
          findsNWidgets(3));

      await tester.tap(find.text(tr('friendsRequestAccept').toUpperCase()));
      await _settle(tester);
      // daniel ya es amigo (una sola vez: la fila de solicitud se
      // fue y quedó la de amigo) y la sección sigue por rosa.
      expect(find.text('daniel'), findsOneWidget);
      expect(find.text(tr('friendsRequestsTitle')), findsOneWidget);
      expect(find.text(tr('friendsRequestAccepted')), findsOneWidget);

      await tester.tap(find.text(tr('friendsRequestCancel').toUpperCase()));
      await _settle(tester);
      expect(find.text('rosa'), findsNothing);
      expect(find.text(tr('friendsRequestsTitle')), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('enviar desde la pantalla: aviso tranquilo, sin diálogo',
        (tester) async {
      await pumpScreen(tester, const FriendsScreen(isGoogleLinked: true));
      await tester.enterText(
          find.widgetWithText(TextField, tr('friendsAddHint')), 'valeria');
      await tester.tap(find.text(tr('friendsAddButton').toUpperCase()));
      await _settle(tester);
      expect(find.text(tr('friendsRequestSentOk')), findsOneWidget);
      expect(find.text('valeria'), findsOneWidget);
      expect(find.text(tr('friendsRequestSentLabel')), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}

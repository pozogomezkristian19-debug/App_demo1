// Tests del sistema de Soporte (7.0): envío con cola offline,
// respuestas del admin en la bandeja local y ajustes remotos de
// WhatsApp. Todo contra los falsos en memoria, nunca Firebase real.
//
// API vigente (la que usa la ventanita de Soporte): singleton
// SupportService.instance con sendMessage / fetchMyMessages /
// watchMyMessages / fetchSupportSettings / listenForReplies, y
// campos canónicos authorUid, username, message, createdAt
// (Timestamp), status, reply (null), replyAt (null) — los mismos
// que lee la app de admin.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/auth_service.dart';
import 'package:quimica_pura/services/notification_inbox.dart';
import 'package:quimica_pura/services/support_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

late InMemoryAnalyticsRepository fake;
late FakeAuthProvider authFake;

final SupportService support = SupportService.instance;

/// Cambia de "teléfono": uid de Auth + nombre, con Google vinculada.
void usePhone(String uid, String username) {
  authFake.uid = uid;
  authFake.googleLinked = true;
  UserPrefs.userName = username;
}

Future<void> seedMyMessage({
  String id = 'msg-1',
  String authorUid = 'uid-a',
  String status = 'abierto',
  String? reply,
  DateTime? createdAt,
}) async {
  final now = DateTime.now();
  await fake.setDoc('support_messages', id, <String, dynamic>{
    'authorUid': authorUid,
    'username': 'kristian',
    'message': 'No me cargan los niveles',
    'createdAt': Timestamp.fromDate(createdAt ?? now),
    'status': status,
    'reply': reply,
    'replyAt': reply == null ? null : Timestamp.fromDate(now),
  });
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    AnalyticsSync.resetForTests();
    AuthService.resetForTests();
    NotificationInbox.resetForTests();
    support.resetForTests();
    fake = InMemoryAnalyticsRepository();
    authFake = FakeAuthProvider();
    AnalyticsSync.setRepositoryForTests(fake);
    AuthService.setProviderForTests(authFake);
    UserPrefs.userName = 'kristian';
    UserPrefs.track = 'uni';
    await AuthService.ensureAnonymous();
    await AnalyticsSync.init();
  });

  tearDown(() {
    support.resetForTests();
    AnalyticsSync.resetForTests();
    AuthService.resetForTests();
    NotificationInbox.resetForTests();
  });

  group('envío de mensajes', () {
    test('sin Google no se envía nada ni se encola', () async {
      authFake.uid = 'uid-a';
      authFake.googleLinked = false;
      expect(await support.sendMessage('Hola, ayuda'), isFalse);
      expect(await support.pendingCount(), 0);
      expect(await support.retryPendingSupport(), 0);
      expect(fake.docs['support_messages'], isNull);
    });

    test('envío correcto: documento con estado abierto', () async {
      usePhone('uid-a', 'kristian');
      expect(await support.sendMessage('  No me cargan los niveles '),
          isTrue);
      final docs = await fake.queryDocs('support_messages');
      expect(docs, hasLength(1));
      final doc = docs.first;
      expect(doc['authorUid'], 'uid-a');
      expect(doc['username'], 'kristian');
      expect(doc['message'], 'No me cargan los niveles');
      expect(doc['status'], 'abierto');
      expect(doc['reply'], isNull);
      expect(doc['replyAt'], isNull);
      expect(doc['createdAt'], isA<Timestamp>());
      final mine = await support.fetchMyMessages();
      expect(mine, hasLength(1));
      expect(mine.first.id, doc['id']);
      expect(mine.first.isAnswered, isFalse);
    });

    test('mensaje vacío no se envía ni se encola', () async {
      usePhone('uid-a', 'kristian');
      expect(await support.sendMessage('   '), isFalse);
      expect(await support.sendMessage(''), isFalse);
      expect(await support.pendingCount(), 0);
      expect(await fake.queryDocs('support_messages'), isEmpty);
    });

    test('sin internet: se guarda en local y se envía al volver',
        () async {
      usePhone('uid-a', 'kristian');
      fake.failAll = true;
      expect(await support.sendMessage('Ayuda con el nivel 3'), isFalse);
      expect(await support.pendingCount(), 1);
      final pending = await support.pendingMessages();
      expect(pending.first.message, 'Ayuda con el nivel 3');
      // El mensaje no se perdió: al volver internet se envía solo.
      fake.failAll = false;
      expect(await support.retryPendingSupport(), 1);
      expect(await support.pendingCount(), 0);
      final docs = await fake.queryDocs('support_messages');
      expect(docs, hasLength(1));
      expect(docs.first['message'], 'Ayuda con el nivel 3');
      expect(docs.first['status'], 'abierto');
    });

    test('dos mensajes encolados se envían los dos', () async {
      usePhone('uid-a', 'kristian');
      fake.failAll = true;
      await support.sendMessage('Primero');
      await support.sendMessage('Segundo');
      expect(await support.pendingCount(), 2);
      fake.failAll = false;
      expect(await support.retryPendingSupport(), 2);
      expect(await support.pendingCount(), 0);
      final mine = await support.fetchMyMessages();
      expect(mine.map((m) => m.message).toList(),
          containsAll(['Primero', 'Segundo']));
    });

    test('mis mensajes: solo los míos, del más nuevo al más viejo',
        () async {
      usePhone('uid-a', 'kristian');
      final now = DateTime.now();
      await seedMyMessage(
          id: 'msg-viejo',
          createdAt: now.subtract(const Duration(hours: 2)));
      await seedMyMessage(id: 'msg-nuevo', createdAt: now);
      await seedMyMessage(id: 'msg-otro', authorUid: 'uid-otro');
      final mine = await support.fetchMyMessages();
      expect(mine.map((m) => m.id).toList(), ['msg-nuevo', 'msg-viejo']);
    });
  });

  group('respuestas del admin en la bandeja', () {
    test('respuesta nueva: aviso en la bandeja, una sola vez', () async {
      usePhone('uid-a', 'kristian');
      await seedMyMessage(status: 'respondido', reply: 'Hola, lo miro hoy');
      expect(NotificationInbox.entries, isEmpty);
      await support.checkRepliesNow();
      expect(NotificationInbox.entries, hasLength(1));
      final entry = NotificationInbox.entries.first;
      expect(entry.kind, InboxKind.support);
      expect(entry.body, 'Hola, lo miro hoy');
      expect(entry.read, isFalse);
      expect(NotificationInbox.unreadCount, 1);
      expect(entry.data['supportMessageId'], 'msg-1');
      // La segunda revisión no duplica el aviso.
      await support.checkRepliesNow();
      expect(NotificationInbox.entries, hasLength(1));
      final mine = await support.fetchMyMessages();
      expect(mine.first.isAnswered, isTrue);
      expect(mine.first.reply, 'Hola, lo miro hoy');
    });

    test('mensaje abierto o sin texto: sin aviso', () async {
      usePhone('uid-a', 'kristian');
      await seedMyMessage(status: 'abierto');
      await support.checkRepliesNow();
      expect(NotificationInbox.entries, isEmpty);
      await seedMyMessage(id: 'msg-2', status: 'respondido', reply: '   ');
      await support.checkRepliesNow();
      expect(NotificationInbox.entries, isEmpty);
    });

    test('la respuesta de OTRO usuario no es mía', () async {
      usePhone('uid-a', 'kristian');
      await seedMyMessage(
          authorUid: 'uid-otro', status: 'respondido', reply: 'Hola');
      await support.checkRepliesNow();
      expect(NotificationInbox.entries, isEmpty);
    });

    test('watchMyMessages emite la lista cuando llega la respuesta',
        () async {
      usePhone('uid-a', 'kristian');
      SupportService.watchPollInterval =
          const Duration(milliseconds: 100);
      final emissions = <List<SupportMessage>>[];
      final sub = support.watchMyMessages().listen(emissions.add);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await seedMyMessage(status: 'respondido', reply: 'Ya lo revisé');
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await sub.cancel();
      expect(emissions.last, hasLength(1));
      expect(emissions.last.first.reply, 'Ya lo revisé');
      expect(emissions.last.first.isAnswered, isTrue);
    });

    test('SupportMessage.fromMap es defensivo', () {
      expect(SupportMessage.fromMap('', {}), isNull);
      expect(
          SupportMessage.fromMap('m',
              {'authorUid': 'u', 'message': 'x'}),
          isNull);
      expect(
          SupportMessage.fromMap('m', {
            'authorUid': 'u',
            'message': '  ',
            'createdAt': Timestamp.fromDate(DateTime.now()),
          }),
          isNull);
      final m = SupportMessage.fromMap('m', {
        'authorUid': 'u',
        'message': 'Hola',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
      expect(m, isNotNull);
      expect(m!.status, 'abierto');
      expect(m.reply, isNull);
      expect(m.isAnswered, isFalse);
    });
  });

  group('ajustes remotos de Soporte (settings/app)', () {
    test('valores por defecto sin documento remoto', () async {
      final s = await support.fetchSupportSettings();
      expect(s.supportNumber, '+5356519431');
      expect(s.showWhatsApp, isFalse);
    });

    test('valores remotos: número e interruptor aplicados', () async {
      fake.settings = <String, dynamic>{
        'supportNumber': '+53 5 1112233',
        'showWhatsApp': true,
      };
      final s = await support.fetchSupportSettings();
      expect(s.supportNumber, '+53 5 1112233');
      expect(s.showWhatsApp, isTrue);
    });

    test('valores remotos rotos: mandan los locales', () async {
      fake.settings = <String, dynamic>{
        'supportNumber': '',
        'showWhatsApp': 'sí',
      };
      var s = await support.fetchSupportSettings();
      expect(s.supportNumber, '+5356519431');
      expect(s.showWhatsApp, isFalse);
      fake.settings = <String, dynamic>{
        'supportNumber': 5356519431,
        'showWhatsApp': 1,
      };
      s = await support.fetchSupportSettings();
      expect(s.supportNumber, '+5356519431');
      expect(s.showWhatsApp, isFalse);
    });

    test('fallo al leer settings: mandan los locales', () async {
      fake.settings = <String, dynamic>{
        'supportNumber': '+53 5 1112233',
        'showWhatsApp': true,
      };
      fake.failSettings = true;
      final s = await support.fetchSupportSettings();
      expect(s.supportNumber, '+5356519431');
      expect(s.showWhatsApp, isFalse);
    });
  });
}

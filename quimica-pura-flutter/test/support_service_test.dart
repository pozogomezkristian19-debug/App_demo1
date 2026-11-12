// Tests del sistema de Soporte (Quemia 7.0, Kristian 09:52): envío
// con cola offline, respuestas del admin en la bandeja local,
// ajustes remotos y puerta de identidad (Google). Todo contra los
// falsos en memoria, nunca Firebase real. Las fechas de los
// documentos sembrados van como Timestamp, que es lo que escribe
// la app de admin (y lo que escribe este servicio).

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

/// Sesión anónima sola: sin Google vinculada (puerta cerrada).
void useAnonymousOnly(String uid) {
  authFake.uid = uid;
  authFake.googleLinked = false;
  UserPrefs.userName = 'kristian';
}

/// Siembra un mensaje mío en 'support_messages' (como lo escribiría
/// la app: campos canónicos, createdAt como Timestamp).
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
    'replyAt': reply == null
        ? null
        : Timestamp.fromDate(now),
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
    test('envío correcto: documento con los campos canónicos', () async {
      usePhone('uid-a', 'kristian');
      expect(
          await support.sendMessage('  No me cargan los niveles '), isTrue);
      final docs = await fake.queryDocs('support_messages');
      expect(docs, hasLength(1));
      final doc = docs.first;
      expect(doc['authorUid'], 'uid-a');
      expect(doc['username'], 'kristian');
      expect(doc['message'], 'No me cargan los niveles');
      expect(doc['status'], 'abierto');
      expect(doc['reply'], isNull);
      expect(doc['replyAt'], isNull);
      // createdAt como Timestamp (lo que lee la app de admin).
      expect(doc['createdAt'], isA<Timestamp>());
      final mine = await support.fetchMyMessages();
      expect(mine, hasLength(1));
      expect(mine.first.id, doc['id']);
      expect(mine.first.isAnswered, isFalse);
      expect(mine.first.hasReply, isFalse);
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
      // La cola local se puede leer como mensajes (la ventanita
      // los muestra mientras no hay red).
      final pending = await support.pendingMessages();
      expect(pending, hasLength(1));
      expect(pending.first.message, 'Ayuda con el nivel 3');
      expect(pending.first.status, 'abierto');
      // Nada en Firestore todavía: el mensaje no se perdió, solo
      // espera a que vuelva internet (la lectura directa al falso
      // lanzaría con failAll, así que se comprueba vía el servicio).
      expect(await support.fetchMyMessages(), isEmpty);
      fake.failAll = false;
      expect(await support.retryPendingSupport(), 1);
      expect(await support.pendingCount(), 0);
      final docs = await fake.queryDocs('support_messages');
      expect(docs, hasLength(1));
      expect(docs.first['message'], 'Ayuda con el nivel 3');
      expect(docs.first['status'], 'abierto');
      expect(docs.first['authorUid'], 'uid-a');
      expect(docs.first['createdAt'], isA<Timestamp>());
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

    test('reintento sin internet: el mensaje sigue en la cola',
        () async {
      usePhone('uid-a', 'kristian');
      fake.failAll = true;
      await support.sendMessage('Ayuda');
      expect(await support.retryPendingSupport(), 0);
      expect(await support.pendingCount(), 1);
    });

    test('fetchMyMessages: solo los míos, del más nuevo al más viejo',
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

    test('watchMyMessages emite la lista y se actualiza en vivo',
        () async {
      usePhone('uid-a', 'kristian');
      await seedMyMessage();
      SupportService.watchPollInterval =
          const Duration(milliseconds: 60);
      final emissions = <List<SupportMessage>>[];
      final sub = support.watchMyMessages().listen(emissions.add);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await seedMyMessage(id: 'msg-2');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await sub.cancel();
      expect(emissions, isNotEmpty);
      expect(emissions.first, hasLength(1));
      expect(emissions.last, hasLength(2));
      expect(emissions.last.map((m) => m.id).toList(),
          containsAll(['msg-1', 'msg-2']));
    });
  });

  group('puerta de identidad: sin Google no se envía nada', () {
    test('sendMessage devuelve false y no toca Firestore ni la cola',
        () async {
      useAnonymousOnly('uid-a');
      expect(await support.sendMessage('Hola, ayuda'), isFalse);
      expect(await support.pendingCount(), 0);
      expect(await support.retryPendingSupport(), 0);
      expect(fake.docs['support_messages'], isNull);
      expect(await support.fetchMyMessages(), isEmpty);
    });

    test('sin Google, la escucha de respuestas no avisa', () async {
      useAnonymousOnly('uid-a');
      await seedMyMessage(status: 'respondido', reply: 'Hola');
      await support.checkRepliesNow();
      expect(NotificationInbox.entries, isEmpty);
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
      // Ni después de un "reinicio" (se pierde la memoria, queda
      // la lista guardada en local).
      support.resetForTests();
      await support.checkRepliesNow();
      expect(NotificationInbox.entries, hasLength(1));
      final mine = await support.fetchMyMessages();
      expect(mine.first.isAnswered, isTrue);
      expect(mine.first.reply, 'Hola, lo miro hoy');
      expect(mine.first.replyAt, isNotNull);
    });

    test('mensaje abierto o respuesta vacía: sin aviso', () async {
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

    test('listenForReplies avisa al arrancar (chequeo inmediato)',
        () async {
      usePhone('uid-a', 'kristian');
      await seedMyMessage(status: 'respondido', reply: 'Ya lo revisé');
      support.listenForReplies();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(NotificationInbox.entries, hasLength(1));
      expect(NotificationInbox.entries.first.body, 'Ya lo revisé');
    });
  });

  group('ajustes remotos (settings/app)', () {
    test('sin documento remoto: valores por defecto', () async {
      usePhone('uid-a', 'kristian');
      final s = await support.fetchSupportSettings();
      expect(s.supportNumber, '+5356519431');
      expect(s.showWhatsApp, isFalse);
    });

    test('valores remotos: se usan y quedan en caché', () async {
      usePhone('uid-a', 'kristian');
      fake.settings = <String, dynamic>{
        'supportNumber': '+53 5 1112233',
        'showWhatsApp': true,
      };
      var s = await support.fetchSupportSettings();
      expect(s.supportNumber, '+53 5 1112233');
      expect(s.showWhatsApp, isTrue);
      // Sin remoto, la caché sigue mandando.
      fake.settings = null;
      s = await support.fetchSupportSettings();
      expect(s.supportNumber, '+53 5 1112233');
      expect(s.showWhatsApp, isTrue);
    });

    test('remoto parcial: mezcla con lo cacheado', () async {
      usePhone('uid-a', 'kristian');
      fake.settings = <String, dynamic>{
        'supportNumber': '+53 5 1112233',
        'showWhatsApp': true,
      };
      await support.fetchSupportSettings();
      fake.settings = <String, dynamic>{'showWhatsApp': false};
      final s = await support.fetchSupportSettings();
      expect(s.supportNumber, '+53 5 1112233');
      expect(s.showWhatsApp, isFalse);
    });

    test('valores remotos rotos: mandan los valores por defecto',
        () async {
      usePhone('uid-a', 'kristian');
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

    test('fallo al leer settings: mandan la caché o los locales',
        () async {
      usePhone('uid-a', 'kristian');
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

  group('SupportMessage.fromMap es defensivo', () {
    test('sin lo mínimo, null; con lo mínimo, abierto', () {
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
        'username': 'kristian',
        'message': 'Hola',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
      expect(m, isNotNull);
      expect(m!.status, 'abierto');
      expect(m.reply, isNull);
      expect(m.isAnswered, isFalse);
    });

    test('acepta createdAt en milisegundos y reply con texto', () {
      final m = SupportMessage.fromMap('m', {
        'authorUid': 'u',
        'message': 'Hola',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'status': 'respondido',
        'reply': 'Listo',
        'replyAt': DateTime.now().millisecondsSinceEpoch,
      });
      expect(m, isNotNull);
      expect(m!.isAnswered, isTrue);
      expect(m.reply, 'Listo');
    });

    test('acepta los alias viejos (uid / createdAtMs / repliedAtMs)',
        () {
      final m = SupportMessage.fromMap('m', {
        'uid': 'u',
        'message': 'Hola',
        'createdAtMs': 2000,
        'status': 'respondido',
        'reply': 'Listo',
        'repliedAtMs': 3000,
      });
      expect(m, isNotNull);
      expect(m!.authorUid, 'u');
      expect(m.createdAt.millisecondsSinceEpoch, 2000);
      expect(m.replyAt!.millisecondsSinceEpoch, 3000);
    });
  });
}

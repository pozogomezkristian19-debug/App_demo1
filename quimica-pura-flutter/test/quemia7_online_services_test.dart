// Tests de la capa online de Quemia 7.0 (fakes, nunca Firebase real).
//
// Cubre: puerta de identidad (Google), duelos (flujo completo con
// dos teléfonos, desempate por tiempo, empate, abandono,
// desconexión 60 s / 24 h, encolado offline), torneos (mejor
// puntaje, clasificación, premio top 3, ejemplo local), amigos,
// grupos, reportes, avisos, tienda, contenido remoto y el puente
// FirestoreSocialRepository. La app nunca cuelga: todo con
// timeout de 5 s (OnlineCommon).

import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/announcements_service.dart';
import 'package:quimica_pura/services/auth_service.dart';
import 'package:quimica_pura/services/duels_service.dart';
import 'package:quimica_pura/services/firestore_social_repository.dart';
import 'package:quimica_pura/services/friends_groups_service.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/remote_content_service.dart';
import 'package:quimica_pura/services/reports_service.dart';
import 'package:quimica_pura/services/shop_service.dart';
import 'package:quimica_pura/services/social_service.dart';
import 'package:quimica_pura/services/tournaments_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/fake_users.dart';

late InMemoryAnalyticsRepository fake;
late FakeAuthProvider authFake;
late FirestoreSocialRepository bridge;

/// Cambia de "teléfono": uid de Auth + nombre de usuario.
/// La sesión de Google queda vinculada (puerta abierta).
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

void seedFixture() => FakeUsers.seed(fake);

int get myPoints => ProgressService.instance.points;
int get myLives => ProgressService.instance.livesLeft;

/// Siembra un torneo en el falso con fechas relativas a ahora
/// (offsetMs negativo = pasado). Devuelve el id.
Future<String> seedTournament({
  required String id,
  required int startOffsetMs,
  required int endOffsetMs,
  int prizePoints = 50,
}) async {
  final example = TournamentsService.exampleTournament();
  await fake.setDoc('tournaments', id, <String, dynamic>{
    'id': id,
    'title': 'Torneo de prueba',
    'topic': 'estequiometria',
    'startAtMs':
        DateTime.now().millisecondsSinceEpoch + startOffsetMs,
    'endAtMs': DateTime.now().millisecondsSinceEpoch + endOffsetMs,
    'questionIds': example.questionIds,
    'prizePoints': prizePoints,
  });
  return id;
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    AnalyticsSync.resetForTests();
    AuthService.resetForTests();
    fake = InMemoryAnalyticsRepository();
    authFake = FakeAuthProvider();
    AnalyticsSync.setRepositoryForTests(fake);
    AuthService.setProviderForTests(authFake);
    ProgressService.track = ProgressService.trackUni;
    await ProgressService.load();
    UserPrefs.userName = 'kristian';
    UserPrefs.track = 'uni';
    await AuthService.ensureAnonymous();
    await AnalyticsSync.init();
    bridge = FirestoreSocialRepository();
  });

  tearDown(() {
    AnalyticsSync.resetForTests();
    AuthService.resetForTests();
  });

  group('puerta de identidad (09:19): sin Google no hay nada online',
      () {
    test('onlinePlayAllowed refleja Google, no la sesión anónima',
        () async {
      expect(AnalyticsSync.onlinePlayAllowed, isFalse);
      expect(AnalyticsSync.needsGoogle, isTrue);
      await AuthService.linkWithGoogle();
      expect(AnalyticsSync.onlinePlayAllowed, isTrue);
      expect(AnalyticsSync.needsGoogle, isFalse);
    });

    test(
        'sin Google todos los servicios devuelven vacío y no tocan Firestore',
        () async {
      useAnonymousOnly('uid-a');
      seedFixture();
      // Foto del repo ANTES de las llamadas: la puerta no debe
      // escribir nada más allá del fixture sembrado por el test.
      final beforeUsers = Map<String, dynamic>.from(fake.users);
      expect(await DuelService.createDuel(
          rivalUid: 'fake-laura', rivalName: 'laura'), isNull);
      expect(await DuelService.createRandomDuel(), isNull);
      expect(await DuelService.getDuel('cualquier'), isNull);
      expect(await DuelService.myOpenDuels(), isEmpty);
      expect(await TournamentsService.listTournaments(), isEmpty);
      expect(await TournamentsService.submitScore('t1', score: 3),
          isFalse);
      expect(await FriendsGroupsService.myFriends(), isEmpty);
      expect(await FriendsGroupsService.addFriendByUsername('laura'),
          isFalse);
      expect(await FriendsGroupsService.createGroup('Grupo'), isNull);
      expect(await FriendsGroupsService.joinGroupByCode('ABCDEF'),
          isNull);
      expect(
          await ReportsService.reportQuestion(
              questionId: 'gen-x', note: 'dudosa'),
          isFalse);
      expect(await AnnouncementsService.fetchAnnouncements(), isEmpty);
      expect(await AnnouncementsService.latestAnnouncement(), isNull);
      expect(await ShopService.syncPurchase('avatar_dorado'), isFalse);
      expect(await ShopService.cloudPurchases(), isEmpty);
      expect(await RemoteContentService.refreshRemoteContent(), 0);
      // Y no se escribió nada en el repo.
      expect(fake.users, beforeUsers);
      expect(fake.docs, isEmpty);
    });

    test('con Google vinculada todo opera normal', () async {
      usePhone('fake-kristian', 'kristian');
      seedFixture();
      expect(
          await FriendsGroupsService.addFriendByUsername('laura'), isTrue);
      expect(await FriendsGroupsService.myFriends(), hasLength(1));
    });

    test('el puente también respeta la puerta', () async {
      useAnonymousOnly('uid-a');
      seedFixture();
      expect(await bridge.online, isFalse);
      expect(await bridge.friends(), isEmpty);
      expect(await bridge.tournaments(), isEmpty);
      expect(await bridge.shopItems(), isEmpty);
      final searching = await bridge.createDuel(opponentUsername: 'laura');
      expect(searching.matchId, isEmpty);
      expect(searching.phase, DuelPhase.searching);
      usePhone('fake-kristian', 'kristian');
      expect(await bridge.online, isTrue);
      expect(await bridge.shopItems(), isNotEmpty);
    });
  });

  group('duelos online: flujo completo con dos teléfonos', () {
    test('retar → mismo set de 5 → ambos responden → ganador +10',
        () async {
      usePhone('uid-a', 'kristian');
      final duel = await DuelService.createDuel(
          rivalUid: 'uid-b', rivalName: 'miguel');
      expect(duel, isNotNull);
      expect(duel!.questionIds, hasLength(5));
      expect(duel.questionIds.toSet(), hasLength(5));
      expect(duel.status, 'waiting');

      // Ambos teléfonos reciben las MISMAS 5 preguntas.
      final questionsA = DuelService.questionsForDuel(duel);
      expect(questionsA, hasLength(5));
      usePhone('uid-b', 'miguel');
      final duelB = await DuelService.getDuel(duel.id);
      expect(duelB, isNotNull);
      final questionsB = DuelService.questionsForDuel(duelB!);
      expect(
          questionsB.map((q) => q.question).toList(),
          questionsA.map((q) => q.question).toList());
      expect(
          questionsB.map((q) => q.options).toList(),
          questionsA.map((q) => q.options).toList());
      expect(
          questionsB.map((q) => q.answer).toList(),
          questionsA.map((q) => q.answer).toList());

      // A responde 5/5 en 60 s; B responde 3/5 en 45 s.
      usePhone('uid-a', 'kristian');
      expect(
          await DuelService.submitResult(duel.id,
              correct: 5, timeMs: 60000),
          isTrue);
      var current = await DuelService.getDuel(duel.id);
      expect(current!.status, 'playing');
      expect(current.finishedResults, contains('uid-a'));
      expect(current.finishedResults, isNot(contains('uid-b')));

      usePhone('uid-b', 'miguel');
      expect(
          await DuelService.submitResult(duel.id,
              correct: 3, timeMs: 45000),
          isTrue);
      current = await DuelService.getDuel(duel.id);
      expect(current!.status, 'finished');
      expect(current.winnerUid, 'uid-a');
      expect(current.forfeit, isFalse);

      // El ganador cobra en SU teléfono cuando se entera.
      usePhone('uid-a', 'kristian');
      expect(myPoints, 0);
      expect(await DuelService.claimWinnerPoints(duel.id), isTrue);
      expect(myPoints, DuelService.duelWinnerPoints); // +10
      expect(await DuelService.claimWinnerPoints(duel.id), isFalse);
      expect(myPoints, DuelService.duelWinnerPoints); // una sola vez
    });

    test('desempate por tiempo: mismos aciertos gana el más rápido',
        () async {
      usePhone('uid-a', 'kristian');
      final duel = await DuelService.createDuel(
          rivalUid: 'uid-b', rivalName: 'miguel');
      expect(
          await DuelService.submitResult(duel!.id,
              correct: 4, timeMs: 60000),
          isTrue);
      usePhone('uid-b', 'miguel');
      expect(
          await DuelService.submitResult(duel.id,
              correct: 4, timeMs: 30000),
          isTrue);
      final current = await DuelService.getDuel(duel.id);
      expect(current!.status, 'finished');
      expect(current.winnerUid, 'uid-b');
      // El ganador (yo, en este teléfono) ya cobró al cerrarse
      // el duelo: el cobro es idempotente.
      expect(myPoints, 10);
      expect(await DuelService.claimWinnerPoints(duel.id), isFalse);
      expect(myPoints, 10);
    });

    test('empate exacto: sin ganador y sin puntos', () async {
      usePhone('uid-a', 'kristian');
      final duel = await DuelService.createDuel(
          rivalUid: 'uid-b', rivalName: 'miguel');
      expect(
          await DuelService.submitResult(duel!.id,
              correct: 4, timeMs: 30000),
          isTrue);
      usePhone('uid-b', 'miguel');
      expect(
          await DuelService.submitResult(duel.id,
              correct: 4, timeMs: 30000),
          isTrue);
      final current = await DuelService.getDuel(duel.id);
      expect(current!.status, 'finished');
      expect(current.winnerUid, isNull);
      expect(await DuelService.claimWinnerPoints(duel.id), isFalse);
      expect(myPoints, 0);
    });

    test('dos jugadores no se pisan el resultado (fusión profunda)',
        () async {
      usePhone('uid-a', 'kristian');
      final duel = await DuelService.createDuel(
          rivalUid: 'uid-b', rivalName: 'miguel');
      await DuelService.submitResult(duel!.id, correct: 5, timeMs: 1000);
      usePhone('uid-b', 'miguel');
      await DuelService.submitResult(duel.id, correct: 2, timeMs: 2000);
      final current = await DuelService.getDuel(duel.id);
      expect(current!.finishedResults.keys, containsAll(['uid-a', 'uid-b']));
      expect(current.finishedResults['uid-a']!.correct, 5);
      expect(current.finishedResults['uid-b']!.correct, 2);
    });

    test('rival al azar: si nadie comparte, null (estado vacío)', () async {
      usePhone('uid-a', 'kristian');
      // Solo yo en el repo.
      expect(await DuelService.createRandomDuel(), isNull);
      seedFixture();
      final duel = await DuelService.createRandomDuel();
      expect(duel, isNotNull);
      expect(duel!.playerA, 'uid-a');
      expect(duel.playerB, isNot('uid-a'));
      expect(duel.questionIds, hasLength(5));
    });

    test('myOpenDuels lista mis duelos activos y se vacía al terminar',
        () async {
      usePhone('uid-a', 'kristian');
      expect(await DuelService.myOpenDuels(), isEmpty);
      final duel = await DuelService.createDuel(
          rivalUid: 'uid-b', rivalName: 'miguel');
      final open = await DuelService.myOpenDuels();
      expect(open, hasLength(1));
      expect(open.first.id, duel!.id);
      // El retado también lo ve.
      usePhone('uid-b', 'miguel');
      expect(await DuelService.myOpenDuels(), hasLength(1));
      await DuelService.submitResult(duel.id, correct: 5, timeMs: 1000);
      usePhone('uid-a', 'kristian');
      await DuelService.submitResult(duel.id, correct: 4, timeMs: 1000);
      expect(await DuelService.myOpenDuels(), isEmpty);
    });

    test('20 duelos seguidos: todos con 5 preguntas distintas', () async {
      usePhone('uid-a', 'kristian');
      for (var i = 0; i < 20; i++) {
        final duel = await DuelService.createDuel(
            rivalUid: 'uid-b', rivalName: 'miguel');
        expect(duel, isNotNull);
        expect(duel!.questionIds.toSet(), hasLength(5));
      }
    });
  });

  group('duelos: desconexión del rival (09:17)', () {
    test('rival en silencio 60 s → se ve desconectado → gano por abandono',
        () async {
      usePhone('uid-a', 'kristian');
      final duel = await DuelService.createDuel(
          rivalUid: 'uid-b', rivalName: 'miguel');
      await DuelService.submitResult(duel!.id, correct: 4, timeMs: 30000);
      var current = await DuelService.getDuel(duel.id);
      expect(current!.rivalDisconnected('uid-a'), isFalse);

      // El rival late una vez y luego deja de actualizar.
      final now = DateTime.now().millisecondsSinceEpoch;
      final heartbeatAt = now - 61000;
      usePhone('uid-b', 'miguel');
      await DuelService.heartbeat(duel.id);
      // Retrocedo su actividad 61 s (el falso guarda el instante real).
      final doc = await fake.getDoc('duels', duel.id);
      final results = Map<String, dynamic>.from(
          doc!['results'] as Map<String, dynamic>);
      final mine = Map<String, dynamic>.from(results['uid-b'] as Map);
      mine['lastActivityMs'] = heartbeatAt;
      results['uid-b'] = mine;
      await fake.setDoc('duels', duel.id, {'results': results});

      usePhone('uid-a', 'kristian');
      current = await DuelService.getDuel(duel.id);
      expect(current!.rivalDisconnected('uid-a', nowMs: now), isTrue);
      expect(current.rivalDisconnected('uid-a', nowMs: heartbeatAt + 30000),
          isFalse);
      expect(current.rivalName('uid-a'), 'miguel');
      expect(
          DuelService.canClaimForfeit(current, nowMs: now), isTrue);
      expect(myPoints, 0);
      expect(myLives, 5);
      expect(await DuelService.claimForfeitWin(duel.id), isTrue);
      current = await DuelService.getDuel(duel.id);
      expect(current!.status, 'finished');
      expect(current.winnerUid, 'uid-a');
      expect(current.forfeit, isTrue);
      // Gané por abandono: +10 puntos y SIN perder vidas.
      expect(myPoints, 10);
      expect(myLives, 5);
    });

    test('rival que nunca jugó: abandono solo tras 24 h', () async {
      usePhone('uid-a', 'kristian');
      final duel = await DuelService.createDuel(
          rivalUid: 'uid-b', rivalName: 'miguel');
      await DuelService.submitResult(duel!.id, correct: 4, timeMs: 30000);
      final current = await DuelService.getDuel(duel.id);
      final created = current!.createdAtMs;
      expect(DuelService.canClaimForfeit(current, nowMs: created + 3600000),
          isFalse);
      expect(
          DuelService.canClaimForfeit(current,
              nowMs: created + 24 * 3600000 + 1000),
          isTrue);
      // Con el reloj real aún no pasaron 24 h: no se puede reclamar.
      expect(await DuelService.claimForfeitWin(duel.id), isFalse);
    });

    test('sin haber terminado yo, no puedo reclamar abandono', () async {
      usePhone('uid-a', 'kristian');
      final duel = await DuelService.createDuel(
          rivalUid: 'uid-b', rivalName: 'miguel');
      final current = await DuelService.getDuel(duel!.id);
      expect(DuelService.canClaimForfeit(current!), isFalse);
      expect(await DuelService.claimForfeitWin(duel.id), isFalse);
    });

    test('cancelar: sin penalización, puntos y vidas intactos', () async {
      usePhone('uid-a', 'kristian');
      final duel = await DuelService.createDuel(
          rivalUid: 'uid-b', rivalName: 'miguel');
      expect(myPoints, 0);
      expect(myLives, 5);
      expect(await DuelService.cancelDuel(duel!.id), isTrue);
      final current = await DuelService.getDuel(duel.id);
      expect(current!.status, 'cancelled');
      expect(current.winnerUid, isNull);
      expect(myPoints, 0);
      expect(myLives, 5);
      expect(await DuelService.cancelDuel(duel.id), isFalse);
    });

    test('sin internet a mitad: la partida local se guarda y se sincroniza',
        () async {
      usePhone('uid-a', 'kristian');
      final duel = await DuelService.createDuel(
          rivalUid: 'uid-b', rivalName: 'miguel');
      await DuelService.submitResult(duel!.id, correct: 5, timeMs: 30000);

      // El rival se queda sin red a mitad de partida.
      usePhone('uid-b', 'miguel');
      fake.failAll = true;
      expect(
          await DuelService.submitResult(duel.id,
              correct: 3, timeMs: 45000),
          isFalse);
      expect(await DuelService.pendingCount(), 1);
      final saved = await DuelService.loadLocalGame(duel.id);
      expect(saved, isNotNull);
      expect(saved!.correct, 3);
      expect(saved.finished, isTrue);

      // Vuelve internet: reintento y el resultado aparece.
      fake.failAll = false;
      expect(await DuelService.retryPendingDuels(), 1);
      expect(await DuelService.pendingCount(), 0);
      expect(await DuelService.loadLocalGame(duel.id), isNull);
      final current = await DuelService.getDuel(duel.id);
      expect(current!.status, 'finished');
      expect(current.finishedResults['uid-b']!.correct, 3);
      expect(current.winnerUid, 'uid-a');
    });
  });

  group('torneos', () {
    test('ejemplo local: válido, activo, 5 preguntas reconstruibles',
        () async {
      final t = TournamentsService.exampleTournament();
      expect(t.title, isNotEmpty);
      expect(t.isActive, isTrue);
      expect(t.questionIds, hasLength(5));
      expect(t.questionIds.toSet(), hasLength(5));
      final questions = t.questions;
      expect(questions, hasLength(5));
      for (final q in questions) {
        expect(q.options, hasLength(4));
        expect(q.answer, inInclusiveRange(0, 3));
      }
      expect(t.prizePoints, TournamentsService.prizeFirst);
    });

    test('entrar → jugar → mejor puntaje solo mejora → clasificación',
        () async {
      final id = await seedTournament(
          id: 't-activo', startOffsetMs: -86400000, endOffsetMs: 6 * 86400000);
      usePhone('fake-kristian', 'kristian');
      final list = await TournamentsService.listTournaments();
      expect(list, hasLength(1));
      expect(list.first.id, id);
      expect(await TournamentsService.myScore(id), isNull);
      expect(await TournamentsService.leaderboard(id), isEmpty);

      expect(await TournamentsService.submitScore(id, score: 3), isTrue);
      var mine = await TournamentsService.myScore(id);
      expect(mine!.bestScore, 3);
      // Un peor puntaje no borra el mejor.
      expect(await TournamentsService.submitScore(id, score: 2), isTrue);
      mine = await TournamentsService.myScore(id);
      expect(mine!.bestScore, 3);
      // Y un mejor puntaje sí lo sube.
      expect(await TournamentsService.submitScore(id, score: 4), isTrue);
      mine = await TournamentsService.myScore(id);
      expect(mine!.bestScore, 4);

      usePhone('fake-laura', 'laura');
      expect(await TournamentsService.submitScore(id, score: 5), isTrue);
      final ranking = await TournamentsService.leaderboard(id);
      expect(ranking, hasLength(2));
      expect(ranking.first.uid, 'fake-laura');
      expect(ranking.first.bestScore, 5);
      expect(ranking.last.uid, 'fake-kristian');
      expect(ranking.last.bestScore, 4);
    });

    test('sin torneos: lista vacía, nunca error', () async {
      usePhone('fake-kristian', 'kristian');
      expect(await TournamentsService.listTournaments(), isEmpty);
      expect(await TournamentsService.leaderboard('t-inexistente'), isEmpty);
      expect(await TournamentsService.getTournament('t-inexistente'),
          isNull);
    });

    test('premio top 3 al terminar: puntos + medalla, una sola vez',
        () async {
      final id = await seedTournament(
          id: 't-terminado',
          startOffsetMs: -8 * 86400000,
          endOffsetMs: -86400000);
      usePhone('fake-laura', 'laura');
      await TournamentsService.submitScore(id, score: 5, timeMs: 60000);
      usePhone('fake-kristian', 'kristian');
      await TournamentsService.submitScore(id, score: 4, timeMs: 90000);
      usePhone('fake-miguel', 'miguel');
      await TournamentsService.submitScore(id, score: 2, timeMs: 60000);
      usePhone('fake-daniel', 'daniel');
      await TournamentsService.submitScore(id, score: 1, timeMs: 60000);

      // El 2.º cobra 30 y queda la medalla; el 4.º no cobra nada.
      usePhone('fake-kristian', 'kristian');
      expect(myPoints, 0);
      expect(await TournamentsService.claimPrizesIfEnded(id),
          TournamentsService.prizeSecond);
      expect(myPoints, TournamentsService.prizeSecond);
      final medals = await TournamentsService.myMedals();
      expect(medals, hasLength(1));
      expect(medals.first['place'], 2);
      expect(medals.first['prizePoints'],
          TournamentsService.prizeSecond);
      expect(await TournamentsService.claimPrizesIfEnded(id), 0);
      expect(myPoints, TournamentsService.prizeSecond);

      // El 4.º no cobra nada: el reclamo devuelve 0 y los puntos
      // no se mueven (el progreso local es único por proceso en
      // el test, por eso se compara contra el valor anterior).
      usePhone('fake-daniel', 'daniel');
      final pointsBefore = myPoints;
      expect(await TournamentsService.claimPrizesIfEnded(id), 0);
      expect(myPoints, pointsBefore);
    });

    test('claimAllEndedPrizes cobra todos los terminados de una vez',
        () async {
      final id1 = await seedTournament(
          id: 't-fin-1',
          startOffsetMs: -8 * 86400000,
          endOffsetMs: -86400000);
      final id2 = await seedTournament(
          id: 't-fin-2',
          startOffsetMs: -8 * 86400000,
          endOffsetMs: -86400000);
      usePhone('fake-kristian', 'kristian');
      await TournamentsService.submitScore(id1, score: 5);
      await TournamentsService.submitScore(id2, score: 5);
      expect(await TournamentsService.claimAllEndedPrizes(),
          2 * TournamentsService.prizeFirst);
      expect(myPoints, 2 * TournamentsService.prizeFirst);
      expect(await TournamentsService.claimAllEndedPrizes(), 0);
    });

    test('puntaje sin internet: se encola y se sincroniza al volver',
        () async {
      final id = await seedTournament(
          id: 't-activo', startOffsetMs: -86400000, endOffsetMs: 6 * 86400000);
      usePhone('fake-kristian', 'kristian');
      fake.failAll = true;
      expect(await TournamentsService.submitScore(id, score: 4), isFalse);
      expect(await TournamentsService.pendingCount(), 1);
      fake.failAll = false;
      expect(await TournamentsService.retryPendingScores(), 1);
      expect(await TournamentsService.pendingCount(), 0);
      final mine = await TournamentsService.myScore(id);
      expect(mine!.bestScore, 4);
    });
  });

  group('amigos', () {
    test('agregar por username: solo si comparte y existe', () async {
      usePhone('fake-kristian', 'kristian');
      seedFixture();
      expect(await FriendsGroupsService.addFriendByUsername('laura'),
          isTrue);
      expect(await FriendsGroupsService.addFriendByUsername('laura'),
          isTrue); // idempotente
      expect(await FriendsGroupsService.isFriend('fake-laura'), isTrue);
      // Pedro existe pero no comparte: no se puede agregar.
      expect(await FriendsGroupsService.addFriendByUsername('pedro'),
          isFalse);
      expect(await FriendsGroupsService.addFriendByUsername('noexiste'),
          isFalse);
      expect(await FriendsGroupsService.addFriendByUsername('kristian'),
          isFalse); // yo mismo no
      final friends = await FriendsGroupsService.myFriends();
      expect(friends, hasLength(1));
      expect(friends.first.username, 'laura');
      expect(friends.first.points, 1420);
      expect(friends.first.levelsPassedTotal, 28);
      expect(friends.first.streak, 15);
      expect(await FriendsGroupsService.removeFriend('fake-laura'), isTrue);
      expect(await FriendsGroupsService.myFriends(), isEmpty);
    });

    test('lista de amigos ordenada por puntos, solo los que comparten',
        () async {
      usePhone('fake-kristian', 'kristian');
      seedFixture();
      await FriendsGroupsService.addFriendByUsername('miguel'); // 980
      await FriendsGroupsService.addFriendByUsername('sofia'); // 1580
      await FriendsGroupsService.addFriendByUsername('rosa'); // 1020
      final friends = await FriendsGroupsService.myFriends();
      expect(
          friends.map((f) => f.username).toList(),
          ['sofia', 'rosa', 'miguel']);
    });

    test('sin amigos: lista vacía, nunca error', () async {
      usePhone('fake-kristian', 'kristian');
      seedFixture();
      expect(await FriendsGroupsService.myFriends(), isEmpty);
    });
  });

  group('grupos de estudio', () {
    test('crear → código de 6 → unirse por código → progreso de miembros',
        () async {
      usePhone('fake-kristian', 'kristian');
      seedFixture();
      final group =
          await FriendsGroupsService.createGroup('Químicos nocturnos');
      expect(group, isNotNull);
      expect(group!.code, hasLength(6));
      expect(group.code, matches(RegExp(r'^[A-Z2-9]{6}$')));
      expect(group.memberUids, contains('fake-kristian'));
      expect(await FriendsGroupsService.myGroups(), hasLength(1));

      usePhone('fake-laura', 'laura');
      final joined = await FriendsGroupsService.joinGroupByCode(
          group.code.toLowerCase()); // insensible a mayúsculas
      expect(joined, isNotNull);
      expect(joined!.id, group.id);
      final members =
          await FriendsGroupsService.groupMembersProgress(group.id);
      expect(members.map((m) => m.username).toList(),
          containsAll(['kristian', 'laura']));
      // La que se unió también lo ve en sus grupos.
      expect(await FriendsGroupsService.myGroups(), hasLength(1));
      usePhone('fake-kristian', 'kristian');
      expect(await FriendsGroupsService.myGroups(), hasLength(1));
    });

    test('código erróneo: null; códigos distintos entre grupos', () async {
      usePhone('fake-kristian', 'kristian');
      final a = await FriendsGroupsService.createGroup('Grupo A');
      final b = await FriendsGroupsService.createGroup('Grupo B');
      expect(a!.code, isNot(b!.code));
      expect(await FriendsGroupsService.joinGroupByCode('ZZZZZZ'), isNull);
      expect(await FriendsGroupsService.joinGroupByCode('  '), isNull);
    });

    test('salir del grupo quita de ambos lados', () async {
      usePhone('fake-kristian', 'kristian');
      seedFixture();
      final group = await FriendsGroupsService.createGroup('Grupo C');
      usePhone('fake-laura', 'laura');
      await FriendsGroupsService.joinGroupByCode(group!.code);
      expect(await FriendsGroupsService.leaveGroup(group.id), isTrue);
      expect(await FriendsGroupsService.myGroups(), isEmpty);
      usePhone('fake-kristian', 'kristian');
      final members =
          await FriendsGroupsService.groupMembersProgress(group.id);
      expect(members.map((m) => m.username).toList(), ['kristian']);
    });
  });

  group('reportes, avisos y tienda', () {
    test('reportar pregunta: se escribe y sin nota no se envía', () async {
      usePhone('fake-kristian', 'kristian');
      expect(
          await ReportsService.reportQuestion(
              questionId: 'gen-1', note: 'la opción B también vale'),
          isTrue);
      expect(
          await ReportsService.reportQuestion(
              questionId: 'gen-1', note: '   '),
          isFalse);
      final docs = await fake.queryDocs('reports');
      expect(docs, hasLength(1));
      expect(docs.first['questionId'], 'gen-1');
      expect(docs.first['uid'], 'fake-kristian');
    });

    test('reporte sin internet: se encola y se reintenta', () async {
      usePhone('fake-kristian', 'kristian');
      fake.failAll = true;
      expect(
          await ReportsService.reportQuestion(
              questionId: 'gen-2', note: 'datos incompletos'),
          isFalse);
      expect(await ReportsService.pendingCount(), 1);
      fake.failAll = false;
      expect(await ReportsService.retryPendingReports(), 1);
      expect(await ReportsService.pendingCount(), 0);
      final docs = await fake.queryDocs('reports');
      expect(docs, hasLength(1));
      expect(docs.first['note'], 'datos incompletos');
    });

    test('avisos: solo los activos; sin avisos, lista vacía', () async {
      usePhone('fake-kristian', 'kristian');
      expect(await AnnouncementsService.fetchAnnouncements(), isEmpty);
      expect(await AnnouncementsService.latestAnnouncement(), isNull);
      final now = DateTime.now().millisecondsSinceEpoch;
      await fake.setDoc('announcements', 'a1', {
        'title': 'Torneo nuevo',
        'body': 'Este fin de semana.',
        'createdAtMs': now,
        'active': true,
      });
      await fake.setDoc('announcements', 'a2', {
        'title': 'Aviso viejo',
        'body': 'Ya pasó.',
        'createdAtMs': now - 1000,
        'active': false,
      });
      final all = await AnnouncementsService.fetchAnnouncements();
      expect(all, hasLength(1));
      expect(all.first.title, 'Torneo nuevo');
      expect((await AnnouncementsService.latestAnnouncement())!.title,
          'Torneo nuevo');
    });

    test('tienda: la compra se sincroniza y se recupera en otro teléfono',
        () async {
      usePhone('fake-kristian', 'kristian');
      expect(await ShopService.syncPurchase('avatar_dorado'), isTrue);
      expect(await ShopService.cloudPurchases(), ['avatar_dorado']);
      // La compra no pisa el resto del documento.
      final doc = await fake.getUser('fake-kristian');
      expect(doc!['purchases'], ['avatar_dorado']);
      // En otro teléfono (mismo uid tras recuperar) se lee igual.
      expect(await ShopService.cloudPurchases(), ['avatar_dorado']);
    });

    test('compra sin internet: encolada y sincronizada al volver',
        () async {
      usePhone('fake-kristian', 'kristian');
      fake.failAll = true;
      expect(await ShopService.syncPurchase('badge_star'), isFalse);
      expect(await ShopService.pendingCount(), 1);
      fake.failAll = false;
      expect(await ShopService.retryPendingPurchases(), 1);
      expect(await ShopService.pendingCount(), 0);
      expect(await ShopService.cloudPurchases(), ['badge_star']);
    });
  });

  group('contenido remoto (editor del admin)', () {
    test('validación: 4 opciones, 1 correcta, texto no vacío', () {
      expect(
          RemoteQuestion.fromMap({
            'question': '¿Masa molar de H2O?',
            'options': ['18 g/mol', '16 g/mol', '20 g/mol', '2 g/mol'],
            'answer': 0,
            'difficulty': 2,
            'explanation': '2×1.01 + 16.00',
          }),
          isNotNull);
      // 3 opciones: inválida.
      expect(
          RemoteQuestion.fromMap({
            'question': '¿Masa molar de H2O?',
            'options': ['18 g/mol', '16 g/mol', '20 g/mol'],
            'answer': 0,
          }),
          isNull);
      // Opciones repetidas: inválida.
      expect(
          RemoteQuestion.fromMap({
            'question': '¿Masa molar de H2O?',
            'options': ['18 g/mol', '18 g/mol', '20 g/mol', '2 g/mol'],
            'answer': 0,
          }),
          isNull);
      // Respuesta fuera de rango: inválida.
      expect(
          RemoteQuestion.fromMap({
            'question': '¿Masa molar de H2O?',
            'options': ['18 g/mol', '16 g/mol', '20 g/mol', '2 g/mol'],
            'answer': 4,
          }),
          isNull);
      // Sin texto: inválida.
      expect(
          RemoteQuestion.fromMap({
            'question': '  ',
            'options': ['18 g/mol', '16 g/mol', '20 g/mol', '2 g/mol'],
            'answer': 0,
          }),
          isNull);
      // Dificultad mala: se corrige a 2, la pregunta vale.
      final fixed = RemoteQuestion.fromMap({
        'question': '¿Masa molar de H2O?',
        'options': ['18 g/mol', '16 g/mol', '20 g/mol', '2 g/mol'],
        'answer': 0,
        'difficulty': 9,
      });
      expect(fixed, isNotNull);
      expect(fixed!.difficulty, 2);
    });

    test('refresco remoto: lo válido se guarda, lo inválido no', () async {
      usePhone('fake-kristian', 'kristian');
      await fake.setDoc('levels', 'estequiometria_1', {
        'topic': 'estequiometria',
        'level': 1,
        'questions': [
          {
            'question': '¿Masa molar de H2O?',
            'options': ['18 g/mol', '16 g/mol', '20 g/mol', '2 g/mol'],
            'answer': 0,
            'difficulty': 1,
            'explanation': '2×1.01 + 16.00 = 18.02',
          },
        ],
      });
      await fake.setDoc('levels', 'gases_1', {
        'topic': 'gases',
        'level': 1,
        'questions': [
          {
            'question': 'Mala',
            'options': ['a', 'b'],
            'answer': 0,
          },
        ],
      });
      expect(
          await RemoteContentService.refreshRemoteContent(force: true), 1);
      final remote = await RemoteContentService.questionsForLevel(
        'estequiometria',
        1,
        localFallback: const [],
      );
      expect(remote, hasLength(1));
      expect(remote.first.question, contains('H2O'));
      // El nivel inválido cae al contenido local.
      final fallback = await RemoteContentService.questionsForLevel(
        'gases',
        1,
        localFallback: const [],
      );
      expect(fallback, isEmpty);
    });

    test('sin internet el refresco no borra la caché ni falla', () async {
      usePhone('fake-kristian', 'kristian');
      await fake.setDoc('levels', 'estequiometria_1', {
        'topic': 'estequiometria',
        'level': 1,
        'questions': [
          {
            'question': '¿Masa molar de H2O?',
            'options': ['18 g/mol', '16 g/mol', '20 g/mol', '2 g/mol'],
            'answer': 0,
            'difficulty': 1,
          },
        ],
      });
      expect(
          await RemoteContentService.refreshRemoteContent(force: true), 1);
      fake.failAll = true;
      expect(
          await RemoteContentService.refreshRemoteContent(force: true), 0);
      fake.failAll = false;
      final cached = await RemoteContentService.questionsForLevel(
        'estequiometria',
        1,
        localFallback: const [],
      );
      expect(cached, hasLength(1));
      await RemoteContentService.resetForTests();
    });
  });

  group('puente FirestoreSocialRepository', () {
    test('crear duelo desde el puente: intro con las 5 preguntas', () async {
      usePhone('fake-kristian', 'kristian');
      seedFixture();
      final state = await bridge.createDuel(opponentUsername: 'miguel');
      expect(state.matchId, isNotEmpty);
      expect(state.opponentName, 'miguel');
      expect(state.phase, DuelPhase.intro);
      expect(state.questions, hasLength(5));
      final duel = await DuelService.getDuel(state.matchId);
      expect(duel, isNotNull);
      expect(duel!.playerA, 'fake-kristian');
      expect(duel.playerB, 'fake-miguel');
    });

    test('duelStream emite el duelo y el abandono tras cancelar', () async {
      usePhone('fake-kristian', 'kristian');
      seedFixture();
      final created = await bridge.createDuel(opponentUsername: 'miguel');
      final emissions = <DuelState>[];
      final sub = bridge.duelStream(created.matchId).listen(emissions.add);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(emissions, isNotEmpty);
      expect(emissions.last.matchId, created.matchId);
      await bridge.cancelDuel(created.matchId);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await sub.cancel();
      expect(emissions.last.phase, DuelPhase.abandoned);
    });

    test('submitDuelScore registra el resultado y cierra el duelo',
        () async {
      usePhone('fake-kristian', 'kristian');
      seedFixture();
      final created = await bridge.createDuel(opponentUsername: 'miguel');
      await bridge.submitDuelScore(created.matchId, 5);
      usePhone('fake-miguel', 'miguel');
      await bridge.submitDuelScore(created.matchId, 3);
      final duel = await DuelService.getDuel(created.matchId);
      expect(duel!.status, 'finished');
      expect(duel.winnerUid, 'fake-kristian');
      usePhone('fake-kristian', 'kristian');
      expect(await DuelService.claimWinnerPoints(created.matchId), isTrue);
      expect(myPoints, 10);
    });

    test('torneos del puente: lista, unión y mejor puntaje', () async {
      final id = await seedTournament(
          id: 't-puente', startOffsetMs: -86400000, endOffsetMs: 6 * 86400000);
      usePhone('fake-kristian', 'kristian');
      var infos = await bridge.tournaments();
      expect(infos, hasLength(1));
      expect(infos.first.id, id);
      expect(infos.first.joined, isFalse);
      await bridge.joinTournament(id);
      await bridge.submitTournamentScore(id, 4);
      infos = await bridge.tournaments();
      expect(infos.first.joined, isTrue);
      expect(infos.first.myBestScore, 4);
    });

    test('grupos del puente: crear y unirse por código', () async {
      usePhone('fake-kristian', 'kristian');
      final created = await bridge.createGroup('Estudio nocturno');
      expect(created.id, isNotEmpty);
      expect(created.inviteCode, hasLength(6));
      usePhone('fake-laura', 'laura');
      final joined = await bridge.joinGroup(created.inviteCode);
      expect(joined, isNotNull);
      expect(joined!.id, created.id);
      final groups = await bridge.groups();
      expect(groups, hasLength(1));
      await bridge.leaveGroup(created.id);
      expect(await bridge.groups(), isEmpty);
    });
  });

  group('fixture de 12 usuarios falsos', () {
    test('los 12 con cifras creíbles, un privado y niveles repartidos',
        () {
      final docs = FakeUsers.build(now: DateTime(2026, 11, 11));
      expect(docs, hasLength(12));
      expect(FakeUsers.usernames, hasLength(12));
      expect(FakeUsers.usernames.first, 'kristian');
      final byName = {for (final d in docs) d['username'] as String: d};
      expect(byName['sofia']!['points'], 1580);
      expect(byName['kristian']!['points'], 1240);
      expect(byName['andres']!['points'], 670);
      // Niveles pasados = suma de bach + uni, y cada tema con
      // desbloqueado = pasados + 1.
      for (final d in docs) {
        final passed = d['levelsPassed'] as Map<String, dynamic>;
        final total = (passed['bach'] as int) + (passed['uni'] as int);
        expect(d['points'], greaterThan(total * 10));
        final levels = d['levels'] as Map<String, dynamic>;
        var sum = 0;
        for (final track in levels.values) {
          for (final unlocked in (track as Map<String, dynamic>).values) {
            sum += (unlocked as int) - 1;
          }
        }
        expect(sum, total);
        expect((d['practiceDays'] as List).length, d['streak']);
      }
      // Pedro es el único privado (no sale en la tabla pública).
      expect(byName['pedro']!['shared'], isFalse);
      expect(
          docs.where((d) => d['shared'] == true), hasLength(11));
      expect(byName['laura']!['shared'], isTrue);
    });

    test('seed siembra los 12 en el repositorio falso', () {
      seedFixture();
      expect(fake.users, hasLength(12));
      final laura = fake.users['fake-laura']!;
      expect(laura['username'], 'laura');
      expect(laura['points'], 1420);
      expect(laura['levelsPassed']['bach'], 11);
      expect(laura['levelsPassed']['uni'], 17);
    });
  });
}

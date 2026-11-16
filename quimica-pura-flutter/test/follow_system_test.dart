// Tests del lote seguir (2026-11-16): seguir/seguidores,
// sugerencias con rotación diaria, perfil público con datos
// reales, reportar usuario, bloquear, QR y la regresión del bug
// gris (streams multi-escucha con replay).
//
// Todo contra repositorios en memoria o el falso de Analytics
// (sin Firestore real ni cuentas reales): lo online de verdad
// (red, Firestore, latencias, reglas) NO queda probado aquí.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/auth_service.dart';
import 'package:quimica_pura/services/firestore_social_repository.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/reports_service.dart';
import 'package:quimica_pura/services/social_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('seguir (en memoria)', () {
    late InMemorySocialRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ProgressService.load();
      UserPrefs.userName = 'kristian';
      UserPrefs.publicUsername = 'kristian';
      repo = InMemorySocialRepository(seedDemo: true);
      SocialService.setRepositoryForTests(repo);
    });

    tearDown(() {
      SocialService.resetForTests();
      UserPrefs.userName = '';
      UserPrefs.publicUsername = '';
    });

    test('sigo a X: mi Siguiendo +1 y sus Seguidores +1; al dejar, vuelven',
        () async {
      expect(await SocialService.followingCount('dev-kristian'), 0);
      expect(await SocialService.followersCount('dev-laura'), 0);
      expect(await SocialService.followUser('dev-laura'), isTrue);
      expect(await SocialService.followingCount('dev-kristian'), 1);
      expect(await SocialService.followersCount('dev-laura'), 1);
      expect(await SocialService.isFollowing('dev-laura'), isTrue);
      expect(await SocialService.isFollowedBy('dev-laura'), isFalse);
      expect(await SocialService.isMutualFollow('dev-laura'), isFalse);
      // Seguir dos veces: false, sin duplicar.
      expect(await SocialService.followUser('dev-laura'), isFalse);
      expect(await SocialService.followingCount('dev-kristian'), 1);
      expect(await SocialService.followersCount('dev-laura'), 1);
      // Dejo de seguir: vuelven a 0.
      expect(await SocialService.unfollowUser('dev-laura'), isTrue);
      expect(await SocialService.followingCount('dev-kristian'), 0);
      expect(await SocialService.followersCount('dev-laura'), 0);
      expect(await SocialService.isFollowing('dev-laura'), isFalse);
    });

    test('no puedo seguirme a mí mismo ni a quien no existe', () async {
      expect(await SocialService.followUser('dev-kristian'), isFalse);
      expect(await SocialService.followUser('dev-nadie'), isFalse);
      expect(await SocialService.followingCount('dev-kristian'), 0);
    });

    test('sin red: seguir devuelve false', () async {
      repo.onlineFlag = false;
      expect(await SocialService.followUser('dev-laura'), isFalse);
      expect(await SocialService.followingCount('dev-kristian'), 0);
    });

    test('listas de seguidos/seguidores con datos reales', () async {
      await SocialService.followUser('dev-laura');
      await SocialService.followUser('dev-sofia');
      final following =
          await SocialService.followingList('dev-kristian');
      expect(following.map((f) => f.username), containsAll(['laura', 'sofia']));
      final laura = following.firstWhere((f) => f.username == 'laura');
      expect(laura.points, 1420);
      expect(laura.levelsPassedTotal, 28);
      expect(laura.streak, 15);
      final followers = await SocialService.followersList('dev-laura');
      expect(followers.map((f) => f.username), ['kristian']);
      expect(followers.first.points, 1240);
      expect(await SocialService.followingList('dev-nadie'), isEmpty);
    });

    test('mutuo = amigos: los dos se siguen', () async {
      await SocialService.followUser('dev-laura');
      expect(await SocialService.isMutualFollow('dev-laura'), isFalse);
      repo.simulateFollowFrom('dev-laura');
      expect(await SocialService.isFollowedBy('dev-laura'), isTrue);
      expect(await SocialService.isMutualFollow('dev-laura'), isTrue);
    });

    test('al enviar solicitud sigo al destinatario', () async {
      final result = await SocialService.sendFriendRequest('valeria');
      expect(result, FriendRequestResult.sent);
      expect(await SocialService.isFollowing('dev-valeria'), isTrue);
      expect(await SocialService.followingCount('dev-kristian'), 1);
    });

    test('al aceptar una solicitud, el que acepta sigue de vuelta',
        () async {
      final req = repo.simulateIncomingFriendRequest('miguel');
      expect(req, isNotNull);
      expect(await SocialService.acceptFriendRequest(req!.id), isTrue);
      expect(await SocialService.isFollowing('dev-miguel'), isTrue);
      // Y quedó amigo en los dos sentidos (como antes).
      expect(
          repo.currentFriends.any((f) => f.deviceId == 'dev-miguel'), isTrue);
      expect(repo.otherSideFriends['dev-miguel'], contains('dev-kristian'));
    });

    test('reparación perezosa: al leer mis amigos aseguro mis edges',
        () async {
      // Amigos sembrados (laura, miguel, sofia) sin edges todavía.
      expect(await SocialService.followingCount('dev-kristian'), 0);
      final friends = await SocialService.friends();
      expect(friends.map((f) => f.username),
          containsAll(['laura', 'miguel', 'sofia']));
      expect(await SocialService.followingCount('dev-kristian'), 3);
      expect(await SocialService.isFollowing('dev-laura'), isTrue);
      expect(await SocialService.isFollowing('dev-miguel'), isTrue);
      expect(await SocialService.isFollowing('dev-sofia'), isTrue);
    });

    test('QR: el contenido es quemia:user:<username>', () {
      expect(profileQrData('laura'), 'quemia:user:laura');
      expect(profileQrData('kristian'), 'quemia:user:kristian');
    });
  });

  group('sugerencias (en memoria)', () {
    late InMemorySocialRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ProgressService.load();
      UserPrefs.userName = 'kristian';
      repo = InMemorySocialRepository(seedDemo: true);
      SocialService.setRepositoryForTests(repo);
    });

    tearDown(() {
      SocialService.resetForTests();
      UserPrefs.userName = '';
    });

    test('misma fecha -> mismo orden; días distintos -> rota', () async {
      final day1 = DateTime(2026, 11, 16);
      final a = await SocialService.friendSuggestions(on: day1);
      final b = await SocialService.friendSuggestions(on: day1);
      expect(a.map((f) => f.username).toList(),
          b.map((f) => f.username).toList());
      // En 10 días distintos el orden no es siempre el mismo (la
      // rotación cambia): con 8 candidatos, que los 10 días den el
      // mismo par en el mismo orden es casi imposible por azar.
      final orders = <String>{};
      for (var i = 0; i < 10; i++) {
        final s = await SocialService.friendSuggestions(
            on: day1.add(Duration(days: i)));
        orders.add(s.map((f) => f.username).join(','));
      }
      expect(orders.length, greaterThan(1));
      // 2 personas, sin amigos (laura/miguel/sofia) ni yo.
      expect(a.length, 2);
      expect(a.map((f) => f.username), isNot(contains('kristian')));
      expect(a.map((f) => f.username),
          isNot(containsAll(['laura', 'miguel', 'sofia'])));
    });

    test('la X descarta solo ese día', () async {
      final day1 = DateTime(2026, 11, 16);
      final day2 = DateTime(2026, 11, 17);
      final first = await SocialService.friendSuggestions(on: day1);
      expect(first, isNotEmpty);
      final dismissed = first.first.username;
      await SocialService.dismissSuggestion(first.first.deviceId, on: day1);
      final again = await SocialService.friendSuggestions(on: day1);
      expect(again.map((f) => f.username), isNot(contains(dismissed)));
      // Al día siguiente vuelve a poder salir.
      final next = await SocialService.friendSuggestions(on: day2);
      final poolNext = <String>{};
      for (var i = 0; i < 10; i++) {
        final s = await SocialService.friendSuggestions(
            on: day2.add(Duration(days: i)));
        poolNext.addAll(s.map((f) => f.username));
      }
      expect(next.map((f) => f.username).toList(), isNotEmpty);
      expect(poolNext, contains(dismissed));
    });

    test('sin red: sugerencias vacías', () async {
      repo.onlineFlag = false;
      expect(await SocialService.friendSuggestions(), isEmpty);
    });
  });

  group('perfil público (en memoria)', () {
    late InMemorySocialRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ProgressService.load();
      UserPrefs.userName = 'Kristian Pozo';
      UserPrefs.publicUsername = 'kristian';
      repo = InMemorySocialRepository(seedDemo: true);
      SocialService.setRepositoryForTests(repo);
    });

    tearDown(() {
      SocialService.resetForTests();
      UserPrefs.userName = '';
      UserPrefs.publicUsername = '';
    });

    test('perfil de otro con datos reales (niveles/puntos/racha)',
        () async {
      final p = await SocialService.publicProfile('dev-laura');
      expect(p, isNotNull);
      expect(p!.uid, 'dev-laura');
      expect(p.username, 'laura');
      expect(p.displayName, 'laura');
      expect(p.points, 1420);
      expect(p.levelsPassedTotal, 28);
      expect(p.streak, 15);
      expect(p.isBot, isFalse);
      // Logros derivados: pasó niveles y practicó 15 días seguidos.
      expect(p.achievementsWon, contains('firstLevel'));
      expect(p.achievementsWon, contains('streak3'));
      expect(p.achievementsWon, contains('streak7'));
      expect(p.achievementsWon, isNot(contains('reviewClear')));
      expect(p.achievementsWon, isNot(contains('streak30')));
    });

    test('semana vacía sin historial; con datos tras registrar puntos',
        () async {
      final before = await SocialService.publicProfile('dev-kristian');
      expect(before, isNotNull);
      expect(before!.dailyPoints, isEmpty);
      ProgressService.instance.addPoints(40);
      final after = await SocialService.publicProfile('dev-kristian');
      expect(after, isNotNull);
      final today = ProgressService.dateKey(DateTime.now());
      expect(after!.dailyPoints[today], 40);
      // Gastar puntos no resta del día.
      ProgressService.instance.addPoints(-15);
      final afterSpend = await SocialService.publicProfile('dev-kristian');
      expect(afterSpend!.dailyPoints[today], 40);
      expect(afterSpend.points, 25);
    });

    test('logros correct100/mixedPass desde datos locales', () async {
      // 120 aciertos: 120 respuestas correctas en un tema.
      for (var i = 0; i < 120; i++) {
        ProgressService.instance.recordAnswer('estequiometria', true);
      }
      ProgressService.instance.recordScore('mixto', 85);
      final p = await SocialService.publicProfile('dev-kristian');
      expect(p, isNotNull);
      expect(p!.achievementsWon, contains('correct100'));
      expect(p.achievementsWon, contains('mixedPass'));
      expect(p.achievementsWon, isNot(contains('correct500')));
    });

    test('usuario inexistente: null', () async {
      expect(await SocialService.publicProfile('dev-nadie'), isNull);
    });
  });

  group('reportar y bloquear (en memoria)', () {
    late InMemorySocialRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ProgressService.load();
      UserPrefs.userName = 'kristian';
      repo = InMemorySocialRepository(seedDemo: true);
      SocialService.setRepositoryForTests(repo);
    });

    tearDown(() {
      SocialService.resetForTests();
      UserPrefs.userName = '';
    });

    test('reportar: el doc lleva createdAt Timestamp + type user',
        () async {
      expect(await SocialService.reportUser('dev-laura', 'spam'), isTrue);
      expect(repo.userReports.length, 1);
      final doc = repo.userReports.first;
      expect(doc['type'], 'user');
      expect(doc['reportedUid'], 'dev-laura');
      expect(doc['reportedUsername'], 'laura');
      expect(doc['questionId'], '');
      expect(doc['note'], 'spam');
      expect(doc['status'], 'open');
      expect(doc['createdAt'], isA<Timestamp>());
      expect(doc['createdAtMs'], isA<int>());
      // A mí mismo no se puede.
      expect(await SocialService.reportUser('dev-kristian', 'x'), isFalse);
      expect(repo.userReports.length, 1);
    });

    test('bloquear: desaparece de sugerencias y de amigos; persiste',
        () async {
      // laura es amiga sembrada y candidata a sugerencia no (es
      // amiga); valeria no es amiga: sale en sugerencias.
      final suggestions =
          await SocialService.friendSuggestions(on: DateTime(2026, 11, 16));
      expect(
          suggestions.map((f) => f.username), isNot(contains('laura')));
      await SocialService.blockUser('dev-laura');
      expect(await SocialService.isBlocked('dev-laura'), isTrue);
      expect(await SocialService.blockedUids(), ['dev-laura']);
      // Desaparece de amigos...
      final friends = await SocialService.friends();
      expect(friends.map((f) => f.deviceId), isNot(contains('dev-laura')));
      // ...y de las listas de seguimiento: sigo a sofia y la
      // bloqueo; ya no sale (miguel sigue ahí: la reparación
      // perezosa de friends() lo siguió y no está bloqueado).
      await SocialService.followUser('dev-sofia');
      await SocialService.blockUser('dev-sofia');
      final following = await SocialService.followingList('dev-kristian');
      expect(following.map((f) => f.deviceId),
          isNot(contains('dev-sofia')));
      expect(
          following.map((f) => f.deviceId), contains('dev-miguel'));
      // Persiste: un repositorio nuevo lo sigue viendo (espejo local).
      final repo2 = InMemorySocialRepository(seedDemo: true);
      expect(await repo2.isBlocked('dev-laura'), isTrue);
      expect(await repo2.blockedUids(),
          containsAll(['dev-laura', 'dev-sofia']));
      // Al desbloquear vuelve.
      await SocialService.unblockUser('dev-laura');
      expect(await SocialService.isBlocked('dev-laura'), isFalse);
      final friendsBack = await SocialService.friends();
      expect(friendsBack.map((f) => f.deviceId), contains('dev-laura'));
    });

    test('bloqueado no sale en sugerencias', () async {
      final day = DateTime(2026, 11, 16);
      // Bloqueo a todos los candidatos posibles uno a uno y
      // compruebo que ninguno sale.
      for (final u in kDemoSocialUsers) {
        if (u.deviceId == 'dev-kristian') continue;
        await SocialService.blockUser(u.deviceId);
      }
      expect(await SocialService.friendSuggestions(on: day), isEmpty);
    });
  });

  group('streams multi-escucha (bug gris)', () {
    late InMemorySocialRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ProgressService.load();
      UserPrefs.userName = 'kristian';
      repo = InMemorySocialRepository(seedDemo: true);
      SocialService.setRepositoryForTests(repo);
    });

    tearDown(() {
      SocialService.resetForTests();
      UserPrefs.userName = '';
    });

    test('friendsStream: dos escuchas sobre LA MISMA instancia', () async {
      final stream = repo.friendsStream();
      final first = await stream.first;
      final second = await stream.first;
      expect(first.length, 3);
      expect(second.length, 3);
      // Dos escuchas a la vez: las dos reciben el valor actual.
      final both = await Future.wait([stream.first, stream.first]);
      expect(both[0].length, 3);
      expect(both[1].length, 3);
      // Por la fachada (con handleError): igual.
      final facade = SocialService.friendsStream();
      expect((await facade.first).length, 3);
      expect((await facade.first).length, 3);
    });

    test('friendsStream: la actualización llega a quien ya escucha',
        () async {
      final stream = repo.friendsStream();
      final events = <List<FriendEntry>>[];
      final sub = stream.listen(events.add);
      await Future<void>.delayed(Duration.zero);
      await repo.addFriend('valeria');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(events.length, greaterThanOrEqualTo(2));
      expect(events.last.map((f) => f.username), contains('valeria'));
    });

    test('tournamentsStream: dos escuchas sobre LA MISMA instancia',
        () async {
      final stream = repo.tournamentsStream();
      expect((await stream.first).length, 3);
      expect((await stream.first).length, 3);
    });

    test('duelStream: dos escuchas sobre LA MISMA instancia', () async {
      final duel = await repo.createDuel(opponentUsername: 'laura');
      final stream = repo.duelStream(duel.matchId);
      final first = await stream.first;
      final second = await stream.first;
      expect(first.opponentName, 'laura');
      expect(second.opponentName, 'laura');
    });
  });

  group('seguir + perfil + reporte (Firestore falso)', () {
    late InMemoryAnalyticsRepository fake;
    late FakeAuthProvider authFake;

    String dayKey(int daysAgo) => ProgressService.dateKey(
        DateTime.now().subtract(Duration(days: daysAgo)));

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      AnalyticsSync.resetForTests();
      AuthService.resetForTests();
      await ProgressService.load();
      UserPrefs.userName = 'kristian';
      UserPrefs.publicUsername = 'kristian';
      fake = InMemoryAnalyticsRepository();
      authFake = FakeAuthProvider()
        ..uid = 'uid-me'
        ..googleLinked = true
        ..displayName = 'Kristian';
      AnalyticsSync.setRepositoryForTests(fake);
      AuthService.setProviderForTests(authFake);
      SocialService.setRepositoryForTests(FirestoreSocialRepository());
      // Yo.
      fake.users['uid-me'] = {
        'username': 'kristian',
        'shared': true,
        'points': 100,
        'levelsPassed': {'bach': 1, 'uni': 2},
        'streak': 3,
        'friends': <String>[],
      };
      // Usuaria real: niveles como MAPA, joinedAt INT, 7 días de
      // práctica seguidos, trofeo, correctTotal y mixedBest.
      fake.users['uid-laura'] = {
        'username': 'laura',
        'shared': true,
        'points': 500,
        'levelsPassed': {'bach': 3, 'uni': 5},
        'levels': {
          'uni': {'estequiometria': 3},
        },
        'streak': 7,
        'practiceDays': [
          for (var i = 6; i >= 0; i--) dayKey(i),
        ],
        'trophies': {
          'uni': ['estequiometria'],
        },
        'joinedAt': 1700000000000,
        'correctTotal': 150,
        'mixedBest': 85,
        'dailyPoints': {dayKey(0): 20, dayKey(1): 15},
        'track': 'uni',
      };
      // Bot: niveles como INT, sin joinedAt ni username ausente no
      // (tiene username), con shared.
      fake.users['uid-bot1'] = {
        'username': 'bot1',
        'shared': true,
        'points': 300,
        'levelsPassed': 12,
        'streak': 2,
        'isBot': true,
      };
      // Sin shared: nunca sale en sugerencias.
      fake.users['uid-privado'] = {
        'username': 'privado',
        'shared': false,
        'points': 999,
        'levelsPassed': 50,
        'streak': 30,
      };
      // Más candidatos con shared (para que la rotación se note).
      for (final entry in {
        'uid-ana': 'ana',
        'uid-luis': 'luis',
        'uid-maria': 'maria',
      }.entries) {
        fake.users[entry.key] = {
          'username': entry.value,
          'shared': true,
          'points': 200,
          'levelsPassed': 5,
          'streak': 1,
        };
      }
    });

    tearDown(() {
      SocialService.resetForTests();
      AnalyticsSync.resetForTests();
      AuthService.resetForTests();
      UserPrefs.userName = '';
      UserPrefs.publicUsername = '';
    });

    test('seguir/dejar de seguir con contadores reales', () async {
      expect(await SocialService.followUser('uid-laura'), isTrue);
      expect(await SocialService.followingCount('uid-me'), 1);
      expect(await SocialService.followersCount('uid-laura'), 1);
      expect(await SocialService.followUser('uid-laura'), isFalse);
      expect(await SocialService.unfollowUser('uid-laura'), isTrue);
      expect(await SocialService.followingCount('uid-me'), 0);
      expect(await SocialService.followersCount('uid-laura'), 0);
      // El doc del edge existe con el id y los campos del contrato.
      await SocialService.followUser('uid-bot1');
      final edge = fake.docs['follows']?['uid-me_uid-bot1'];
      expect(edge, isNotNull);
      expect(edge!['followerUid'], 'uid-me');
      expect(edge['followingUid'], 'uid-bot1');
      expect(edge['createdAtMs'], isA<int>());
    });

    test('listas de seguidos/seguidores con datos reales', () async {
      await SocialService.followUser('uid-laura');
      await SocialService.followUser('uid-bot1');
      final following = await SocialService.followingList('uid-me');
      expect(following.map((f) => f.username),
          containsAll(['laura', 'bot1']));
      final laura = following.firstWhere((f) => f.username == 'laura');
      expect(laura.points, 500);
      expect(laura.levelsPassedTotal, 8);
      expect(laura.streak, 7);
      final followers = await SocialService.followersList('uid-laura');
      expect(followers.map((f) => f.username), ['kristian']);
    });

    test('sugerencias: rotación diaria, bots incluidos, privado fuera',
        () async {
      final day1 = DateTime(2026, 11, 16);
      final a = await SocialService.friendSuggestions(on: day1);
      final b = await SocialService.friendSuggestions(on: day1);
      expect(a.map((f) => f.username).toList(),
          b.map((f) => f.username).toList());
      expect(a.map((f) => f.username), isNot(contains('privado')));
      expect(a.map((f) => f.username), isNot(contains('kristian')));
      // En 10 días distintos el orden no es siempre el mismo.
      final orders = <String>{};
      for (var i = 0; i < 10; i++) {
        final s = await SocialService.friendSuggestions(
            on: day1.add(Duration(days: i)));
        orders.add(s.map((f) => f.username).join(','));
      }
      expect(orders.length, greaterThan(1));
      // El bot puede salir en sugerencias.
      final seen = <String>{};
      for (var i = 0; i < 10; i++) {
        final s = await SocialService.friendSuggestions(
            on: day1.add(Duration(days: i)));
        seen.addAll(s.map((f) => f.username));
      }
      expect(seen, contains('bot1'));
    });

    test('invitado (sin Google): sin sugerencias (solo con sesión)',
        () async {
      // Sin Google vinculada (Kristian 2026-11-16): las
      // sugerencias solo salen una vez iniciado sesión. Seguir
      // sigue exigiendo Google.
      authFake.googleLinked = false;
      final day1 = DateTime(2026, 11, 16);
      final s = await SocialService.friendSuggestions(on: day1);
      expect(s, isEmpty);
      expect(await SocialService.followUser('uid-laura'), isFalse);
    });

    test('perfil público tolera mapa/INT y deriva logros', () async {
      final p = await SocialService.publicProfile('uid-laura');
      expect(p, isNotNull);
      expect(p!.uid, 'uid-laura');
      expect(p.username, 'laura');
      expect(p.joinedAtMs, 1700000000000);
      expect(p.levelsPassedTotal, 8);
      expect(p.points, 500);
      expect(p.streak, 7);
      expect(p.trophiesWon, 1);
      expect(p.dailyPoints[dayKey(0)], 20);
      expect(p.dailyPoints[dayKey(1)], 15);
      expect(p.achievementsWon, contains('firstLevel'));
      expect(p.achievementsWon, contains('streak3'));
      expect(p.achievementsWon, contains('streak7'));
      expect(p.achievementsWon, contains('mixedPass'));
      expect(p.achievementsWon, contains('correct100'));
      expect(p.achievementsWon, isNot(contains('reviewClear')));
      expect(p.achievementsWon, isNot(contains('correct500')));
      // Bot: niveles INT, sin joinedAt (0), sin días.
      final bot = await SocialService.publicProfile('uid-bot1');
      expect(bot, isNotNull);
      expect(bot!.levelsPassedTotal, 12);
      expect(bot.joinedAtMs, 0);
      expect(bot.isBot, isTrue);
      expect(bot.achievementsWon, contains('firstLevel'));
      // No existe: null.
      expect(await SocialService.publicProfile('uid-nadie'), isNull);
    });

    test('reportar usuario crea el doc con createdAt Timestamp',
        () async {
      expect(await SocialService.reportUser('uid-laura', 'acoso'), isTrue);
      final docs = fake.docs['reports']?.values.toList() ?? [];
      expect(docs.length, 1);
      final doc = docs.first;
      expect(doc['type'], 'user');
      expect(doc['reportedUid'], 'uid-laura');
      expect(doc['reportedUsername'], 'laura');
      expect(doc['questionId'], '');
      expect(doc['note'], 'acoso');
      expect(doc['uid'], 'uid-me');
      expect(doc['status'], 'open');
      expect(doc['createdAt'], isA<Timestamp>());
      expect(doc['createdAtMs'], isA<int>());
      // También directo en ReportsService.
      expect(
          await ReportsService.reportUser(
              uid: 'uid-bot1', reason: 'spam'),
          isTrue);
      expect(fake.docs['reports']?.length, 2);
    });

    test('bloquear persiste en doc + espejo y filtra listas', () async {
      await SocialService.followUser('uid-laura');
      await SocialService.blockUser('uid-laura');
      expect(await SocialService.isBlocked('uid-laura'), isTrue);
      expect(await SocialService.blockedUids(), ['uid-laura']);
      expect(
          (fake.users['uid-me']?['blockedUids'] as List?) ?? [],
          contains('uid-laura'));
      expect(await SocialService.followingList('uid-me'), isEmpty);
      final suggestions =
          await SocialService.friendSuggestions(on: DateTime(2026, 11, 16));
      expect(suggestions.map((f) => f.username), isNot(contains('laura')));
      await SocialService.unblockUser('uid-laura');
      expect(await SocialService.isBlocked('uid-laura'), isFalse);
      expect(
          (fake.users['uid-me']?['blockedUids'] as List?) ?? [],
          isNot(contains('uid-laura')));
    });
  });

  group('dailyPoints en la nube (falso de Analytics)', () {
    late InMemoryAnalyticsRepository fake;
    late FakeAuthProvider authFake;

    setUp(() async {
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
      UserPrefs.publicUsername = 'kristian';
      UserPrefs.track = 'uni';
      await AuthService.ensureAnonymous();
      await AnalyticsSync.init();
      authFake.googleLinked = true;
    });

    tearDown(() {
      AnalyticsSync.resetForTests();
      AuthService.resetForTests();
      UserPrefs.userName = '';
      UserPrefs.publicUsername = '';
    });

    test('uploadProgress sube dailyPoints + correctTotal + mixedBest',
        () async {
      ProgressService.instance.addPoints(30);
      ProgressService.instance.recordAnswer('estequiometria', true);
      ProgressService.instance.recordScore('mixto', 85);
      await AnalyticsSync.uploadProgress(force: true);
      final doc = fake.users['fake-anon-uid'];
      expect(doc, isNotNull);
      final today = ProgressService.dateKey(DateTime.now());
      expect((doc!['dailyPoints'] as Map)[today], 30);
      expect(doc['correctTotal'], 1);
      expect(doc['mixedBest'], 85);
      // La bajada (restore) recupera los puntos del día.
      final before = ProgressService.instance.dailyPoints[today];
      expect(before, 30);
      expect(await AnalyticsSync.restoreFromCloud(), isTrue);
      expect(ProgressService.instance.dailyPoints[today], 30);
    });
  });
}

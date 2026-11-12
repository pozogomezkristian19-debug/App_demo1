// Tests de la analítica Firebase + Auth (ronda fix8, versión 6.5).
// Todo corre contra los falsos en memoria: NUNCA Firebase real
// (ni google_sign_in: el flujo de Google es solo Firebase Auth).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/auth_service.dart';
import 'package:quimica_pura/services/points.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/remote_tuning.dart';
import 'package:quimica_pura/services/update_check.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repositorio que cuelga para siempre (simula modo avión con una
/// red que no responde): ninguna llamada debe colgarse gracias a los
/// timeouts de 5 s.
class HangingAnalyticsRepository implements AnalyticsRepository {
  @override
  Future<Map<String, dynamic>?> getUser(String deviceId) =>
      Completer<Map<String, dynamic>?>().future;

  @override
  Future<void> setUser(String deviceId, Map<String, dynamic> data) =>
      Completer<void>().future;

  @override
  Stream<List<Map<String, dynamic>>> leaderboard() =>
      const Stream.empty();

  @override
  Future<Map<String, dynamic>?> getSettings() =>
      Completer<Map<String, dynamic>?>().future;

  @override
  Future<Map<String, dynamic>?> getDoc(String collection, String docId) =>
      Completer<Map<String, dynamic>?>().future;

  @override
  Future<void> setDoc(String collection, String docId,
          Map<String, dynamic> data,
          {bool merge = true}) =>
      Completer<void>().future;

  @override
  Future<String> createDoc(
          String collection, Map<String, dynamic> data) =>
      Completer<String>().future;

  @override
  Future<List<Map<String, dynamic>>> queryDocs(
    String collection, {
    String? whereField,
    Object? isEqualTo,
    String? orderByField,
    bool descending = false,
    int? limit,
  }) =>
      Completer<List<Map<String, dynamic>>>().future;

  @override
  Stream<Map<String, dynamic>?> watchDoc(
          String collection, String docId) =>
      Completer<Map<String, dynamic>?>().future.asStream();

  @override
  Future<void> addToArray(
          String collection, String docId, String field, Object value) =>
      Completer<void>().future;

  @override
  Future<void> removeFromArray(
          String collection, String docId, String field, Object value) =>
      Completer<void>().future;

  @override
  Future<bool> ping(String collection, String docId) =>
      Completer<bool>().future;
}

void main() {
  late InMemoryAnalyticsRepository fake;
  late FakeAuthProvider authFake;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AnalyticsSync.resetForTests();
    AuthService.resetForTests();
    RemoteTuning.resetForTests();
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
  });

  tearDown(() {
    AnalyticsSync.resetForTests();
    AuthService.resetForTests();
    RemoteTuning.resetForTests();
  });

  test('auth anónima con fake: el uid es la identidad del documento',
      () async {
    expect(AuthService.currentUid, 'fake-anon-uid');
    expect(AnalyticsSync.deviceId, 'fake-anon-uid');
  });

  test('id temporal estable en prefs y distinto del uid', () async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString('melli_analytics_device_id');
    expect(legacy, isNotNull);
    expect(legacy, isNot(AnalyticsSync.deviceId));
    await AnalyticsSync.init();
    expect(prefs.getString('melli_analytics_device_id'), legacy);
  });

  test('link con Google no cambia el uid', () async {
    final before = AnalyticsSync.deviceId;
    expect(await AuthService.linkWithGoogle(), isTrue);
    expect(AuthService.isGoogleLinked, isTrue);
    expect(AuthService.googleEmail, 'test@example.com');
    expect(AuthService.googleDisplayName, 'Test');
    expect(AuthService.currentUid, before);
    expect(AnalyticsSync.deviceId, before);
  });

  test('unlinkGoogle desvincula', () async {
    await AuthService.linkWithGoogle();
    expect(AuthService.isGoogleLinked, isTrue);
    expect(await AuthService.unlinkGoogle(), isTrue);
    expect(AuthService.isGoogleLinked, isFalse);
    expect(AuthService.googleEmail, isNull);
  });

  test('sin internet la sesión anónima falla y manda el id temporal',
      () async {
    authFake.uid = null;
    authFake.failAnonymous = true;
    expect(await AuthService.ensureAnonymous(), isNull);
    expect(AuthService.currentUid, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(AnalyticsSync.deviceId,
        prefs.getString('melli_analytics_device_id'));
    await AnalyticsSync.uploadProgress(force: true);
    expect(fake.users, isEmpty);
  });

  test('migración: el documento temporal se copia al uid una sola vez',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final legacyId = prefs.getString('melli_analytics_device_id')!;
    expect(legacyId, isNot(AnalyticsSync.deviceId));
    // Documento viejo bajo el id temporal.
    fake.users[legacyId] = {
      'username': 'kristian',
      'points': 77,
      'joinedAt': 111,
    };
    // La migración del setUp ya marcó el flag: quitarlo para simular
    // la primera apertura con uid.
    await prefs.remove('melli_analytics_migrated_to_uid');
    await AnalyticsSync.init();
    expect(fake.users[AnalyticsSync.deviceId]?['points'], 77);
    // Segunda vez: ya no se vuelve a copiar.
    fake.users[legacyId] = {
      'username': 'kristian',
      'points': 99,
      'joinedAt': 111,
    };
    await AnalyticsSync.init();
    expect(fake.users[AnalyticsSync.deviceId]?['points'], 77);
  });

  test('subida con fake: snapshot con usuario, niveles, puntos y versión',
      () async {
    ProgressService.instance.addPoints(10);
    ProgressService.instance.recordLevelPass('estequiometria', 1);
    expect(ProgressService.instance.unlockedLevel('estequiometria'), 2);

    // (7.0) La subida exige Google vinculada: sin ella no sube nada.
    // (Diseño 7.0) Con Google vinculada compartir es AUTOMÁTICO:
    // no hay permiso que dar, el documento sube con shared: true.
    await AuthService.linkWithGoogle();
    await AnalyticsSync.uploadProgress(force: true);

    final doc = fake.users[AnalyticsSync.deviceId];
    expect(doc, isNotNull);
    expect(doc!['username'], 'kristian');
    expect(doc['points'], 10);
    expect(doc['track'], 'uni');
    expect(doc['appVersion'], kAppVersion);
    expect(doc['shared'], isTrue);
    expect(doc['joinedAt'], isA<int>());
    expect(doc['lastActive'], isA<int>());
    final levelsPassed = doc['levelsPassed'] as Map;
    expect(levelsPassed['uni'], 1);
    expect(levelsPassed['bach'], 0);
    final levels = doc['levels'] as Map;
    expect((levels['uni'] as Map)['estequiometria'], 2);
  });

  test('debounce: sin force no se sube antes de 60 s; con force sí',
      () async {
    await AuthService.linkWithGoogle();
    await AnalyticsSync.uploadProgress(force: true);
    expect(fake.users[AnalyticsSync.deviceId]!['points'], 0);

    ProgressService.instance.addPoints(5);
    await AnalyticsSync.uploadProgress();
    expect(fake.users[AnalyticsSync.deviceId]!['points'], 0);

    await AnalyticsSync.uploadProgress(force: true);
    expect(fake.users[AnalyticsSync.deviceId]!['points'], 5);
  });

  test('sin Google vinculada no se sube nada, ni con force '
      '(puerta de identidad 7.0)', () async {
    // La puerta es Google, no un permiso: sin Google vinculada,
    // nada sale del teléfono.
    ProgressService.instance.addPoints(7);
    await AnalyticsSync.uploadProgress(force: true);
    expect(fake.users, isEmpty);
  });

  test('con Google vinculada: la subida se COMPARTE (shared: true) '
      'y aparece en la tabla', () async {
    // Diseño 7.0: compartir es automático, sin pregunta.
    await AuthService.linkWithGoogle();
    ProgressService.instance.addPoints(7);
    await AnalyticsSync.uploadProgress(force: true);
    final doc = fake.users[AnalyticsSync.deviceId];
    expect(doc, isNotNull);
    expect(doc!['shared'], isTrue);
    expect(doc['points'], 7);
    final entries = await AnalyticsSync.leaderboardStream().first;
    expect(entries.map((e) => e.username), contains('kristian'));
  });

  test('con Google enlazado: respaldo compartido y en la tabla', () async {
    await AuthService.linkWithGoogle();
    ProgressService.instance.addPoints(12);
    await AnalyticsSync.backupToCloud(force: true);
    final doc = fake.users[AnalyticsSync.deviceId];
    expect(doc, isNotNull);
    expect(doc!['shared'], isTrue);
    expect(doc['points'], 12);
    final entries = await AnalyticsSync.leaderboardStream().first;
    expect(entries.map((e) => e.username), contains('kristian'));
  });

  test('sin repositorio (Firebase no listo) la subida es no-op', () async {
    AnalyticsSync.resetForTests();
    await AnalyticsSync.init();
    // Sin repositorio inyectado ni Firebase listo: no hay dónde subir
    // y no se lanza nada.
    expect(fake.users, isEmpty);
  });

  test('banned true/false y bannedNotifier', () async {
    expect(await AnalyticsSync.fetchBanned(), isFalse);
    expect(AnalyticsSync.bannedNotifier.value, isFalse);

    fake.users[AnalyticsSync.deviceId] = {'banned': true};
    expect(await AnalyticsSync.fetchBanned(), isTrue);
    expect(AnalyticsSync.bannedNotifier.value, isTrue);

    fake.users[AnalyticsSync.deviceId] = {'banned': false};
    expect(await AnalyticsSync.fetchBanned(), isFalse);
    expect(AnalyticsSync.bannedNotifier.value, isFalse);
  });

  test('restoreFromCloud descarga el documento del uid y lo aplica',
      () async {
    final today = ProgressService.dateKey(DateTime.now());
    final yesterday = ProgressService.dateKey(
        DateTime.now().subtract(const Duration(days: 1)));
    fake.users[AnalyticsSync.deviceId] = {
      'username': 'kristian',
      'points': 42,
      'levels': {
        'uni': {'estequiometria': 3, 'gases': 2},
        'bach': {'bach-gases': 4},
      },
      'practiceDays': [today, yesterday],
    };

    expect(await AnalyticsSync.restoreFromCloud(), isTrue);

    expect(ProgressService.instance.unlockedLevel('estequiometria'), 3);
    expect(ProgressService.instance.unlockedLevel('gases'), 2);
    expect(ProgressService.instance.points, 42);
    expect(ProgressService.instance.streakNow, 2);

    // La pista bach también se guardó en prefs, sin cambiar la actual.
    final snap = await ProgressService.trackSnapshot('bach');
    expect(snap.levels['bach-gases'], 4);
    expect(ProgressService.track, 'uni');
  });

  test('restoreFromCloud sin documento devuelve false', () async {
    expect(await AnalyticsSync.restoreFromCloud(), isFalse);
  });

  test('applyRecovered nunca baja el progreso local', () async {
    ProgressService.instance.addPoints(100);
    ProgressService.instance.recordLevelPass('estequiometria', 1);
    expect(ProgressService.instance.unlockedLevel('estequiometria'), 2);

    await AnalyticsSync.applyRecovered(<String, dynamic>{
      'points': 10,
      'levels': {
        'uni': {'estequiometria': 1},
      },
      'practiceDays': <String>[],
    });

    expect(ProgressService.instance.points, 100);
    expect(ProgressService.instance.unlockedLevel('estequiometria'), 2);
  });

  test('teléfono nuevo: signInWithGoogle entra en el uid de la cuenta '
      'y restaura', () async {
    // Teléfono 1: progreso bajo uid-1.
    fake.users['uid-1'] = {
      'username': 'kristian',
      'points': 42,
      'levels': {
        'uni': {'estequiometria': 3},
      },
      'practiceDays': <String>[],
    };
    // Teléfono 2: anónimo uid-2; la cuenta de Google ya existe en uid-1.
    authFake.uid = 'uid-2';
    authFake.googleUid = 'uid-1';

    expect(await AnalyticsSync.signInGoogleAndRestore(), isTrue);
    expect(AuthService.currentUid, 'uid-1');
    expect(AnalyticsSync.deviceId, 'uid-1');
    expect(ProgressService.instance.points, 42);
    expect(ProgressService.instance.unlockedLevel('estequiometria'), 3);
  });

  test('linkGoogleAndRestore con el mismo uid: enlaza sin restaurar',
      () async {
    fake.users['fake-anon-uid'] = {
      'username': 'kristian',
      'points': 33,
      'levels': {
        'uni': {'gases': 2},
      },
      'practiceDays': <String>[],
    };
    expect(await AnalyticsSync.linkGoogleAndRestore(), isTrue);
    expect(AuthService.isGoogleLinked, isTrue);
    // El uid no cambió: no hace falta restaurar; el progreso local
    // sigue en 0 y el respaldo NO pisa el documento remoto (fusión
    // por máximo: sigue en 33).
    expect(ProgressService.instance.points, 0);
    expect(fake.users['fake-anon-uid']?['points'], 33);
  });

  test('link con fallback credential-already-in-use: entra en el uid y '
      'restaura', () async {
    fake.users['uid-1'] = {
      'username': 'kristian',
      'points': 42,
      'levels': {
        'uni': {'estequiometria': 3},
      },
      'practiceDays': <String>[],
    };
    authFake.uid = 'uid-2';
    authFake.googleUid = 'uid-1';
    authFake.simulateAlreadyInUse = true;

    expect(await AnalyticsSync.linkGoogleAndRestore(), isTrue);
    expect(AuthService.currentUid, 'uid-1');
    expect(AnalyticsSync.deviceId, 'uid-1');
    expect(ProgressService.instance.points, 42);
    expect(ProgressService.instance.unlockedLevel('estequiometria'), 3);
  });

  test('link con fallo total devuelve false sin lanzar', () async {
    authFake.failLink = true;
    expect(await AuthService.linkWithGoogle(), isFalse);
    expect(await AnalyticsSync.linkGoogleAndRestore(), isFalse);
    expect(AuthService.isGoogleLinked, isFalse);
    // Nada se rompió: el progreso local sigue.
    ProgressService.instance.addPoints(5);
    expect(ProgressService.instance.points, 5);
  });

  test('modo avión: el estudio funciona, nada cuelga y la subida queda '
      'pendiente', () async {
    // Usuario con Google vinculada: en la app real la sesión de
    // Firebase Auth persiste en el teléfono, así que offline sigue
    // habiendo uid + Google (el inicio anónimo que cuelga es el de
    // una instalación nueva, que se prueba aparte).
    await AuthService.linkWithGoogle();
    expect(AuthService.isGoogleLinked, isTrue);

    // Sin internet: la red cuelga.
    AnalyticsSync.setRepositoryForTests(HangingAnalyticsRepository());

    // El estudio funciona 100% offline.
    ProgressService.instance.addPoints(10);
    ProgressService.instance.recordLevelPass('estequiometria', 1);
    expect(ProgressService.instance.points, 10);
    expect(levelPassed(4, 5), isTrue);

    // La subida no cuelga (timeouts de 5 s) y queda pendiente.
    await AnalyticsSync.uploadProgress(force: true);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('melli_analytics_pending_upload'), isTrue);

    // Vuelve internet: el repositorio ya responde y el reintento sube.
    AnalyticsSync.setRepositoryForTests(fake);
    await AnalyticsSync.retryPending();
    expect(fake.users[AnalyticsSync.deviceId]?['points'], 10);
    expect(prefs.getBool('melli_analytics_pending_upload'), isFalse);
  });

  test('modo avión: banned y ajustes remotos no cuelgan (timeout 5 s)',
      () async {
    AnalyticsSync.setRepositoryForTests(HangingAnalyticsRepository());
    final results = await Future.wait([
      AnalyticsSync.fetchBanned(),
      AnalyticsSync.fetchRemoteSettings(),
    ]);
    expect(results[0], isFalse);
    expect(results[1], isEmpty);
    // Sin ajustes remotos mandan los locales.
    await AnalyticsSync.applyRemoteSettings();
    expect(levelPassed(4, 5), isTrue);
    expect(pointsForCorrect(1), 3);
  });

  test('modo avión: el inicio anónimo colgado se corta con timeout',
      () async {
    authFake.uid = null;
    authFake.hangAnonymous = true;
    final sw = Stopwatch()..start();
    expect(await AuthService.ensureAnonymous(), isNull);
    sw.stop();
    expect(sw.elapsed.inSeconds, lessThan(10));
    expect(AuthService.currentUid, isNull);
  });

  // (Diseño 7.0) Los documentos antiguos con shared == false
  // (de cuando compartir era una pregunta) siguen fuera de la tabla.
  test('leaderboard: orden por puntos, sin baneados ni privados antiguos',
      () async {
    // (7.0) La tabla exige Google vinculada.
    await AuthService.linkWithGoogle();
    fake.users['a'] = {
      'username': 'ana',
      'points': 100,
      'streak': 3,
      'levelsPassed': {'bach': 2, 'uni': 3},
    };
    fake.users['b'] = {
      'username': 'baneado',
      'points': 200,
      'streak': 9,
      'levelsPassed': {'bach': 9, 'uni': 9},
      'banned': true,
    };
    fake.users['c'] = {
      'username': 'luis',
      'points': 50,
      'streak': 1,
      'levelsPassed': {'bach': 0, 'uni': 1},
    };
    fake.users['d'] = {
      'username': 'privado',
      'points': 150,
      'streak': 5,
      'levelsPassed': {'bach': 1, 'uni': 1},
      'shared': false,
    };

    final entries = await AnalyticsSync.leaderboardStream().first;
    expect(entries.map((e) => e.username).toList(), ['ana', 'luis']);
    expect(entries.first.points, 100);
    expect(entries.first.levelsPassedTotal, 5);
    expect(entries.first.streak, 3);
    expect(entries.last.levelsPassedTotal, 1);
  });

  test('fetchRemoteSettings + applyRemoteSettings cambia los valores',
      () async {
    fake.settings = {
      'passRequired': 5,
      'maxLives': 3,
      'pointsCorrect': {'1': 10, '2': 20, '3': 30},
      'pointsWrong': {'1': -10, '2': -20, '3': -30},
    };

    final fetched = await AnalyticsSync.fetchRemoteSettings();
    expect(fetched['passRequired'], 5);
    await AnalyticsSync.applyRemoteSettings();

    expect(levelPassed(4, 5), isFalse);
    expect(levelPassed(5, 5), isTrue);
    expect(pointsForCorrect(1), 10);
    expect(pointsForCorrect(2), 20);
    expect(pointsForCorrect(3), 30);
    expect(pointsForWrong(1), -10);
    expect(pointsForWrong(3), -30);
    expect(maxLives, 3);
  });

  test('fetchRemoteSettings con fallo: mandan los valores locales',
      () async {
    fake.failSettings = true;
    expect(await AnalyticsSync.fetchRemoteSettings(), isEmpty);

    await AnalyticsSync.applyRemoteSettings();
    expect(levelPassed(4, 5), isTrue);
    expect(levelPassed(3, 5), isFalse);
    expect(pointsForCorrect(1), 3);
    expect(pointsForCorrect(2), 5);
    expect(pointsForCorrect(3), 8);
    expect(pointsForWrong(1), -5);
    expect(pointsForWrong(2), -8);
    expect(pointsForWrong(3), -12);
    expect(maxLives, 5);
  });

  test('ajustes remotos rotos no rompen los locales', () async {
    fake.settings = {
      'passRequired': 99,
      'maxLives': 0,
      'pointsCorrect': {'1': 'diez'},
    };
    await AnalyticsSync.applyRemoteSettings();
    expect(levelPassed(4, 5), isTrue);
    expect(pointsForCorrect(1), 3);
    expect(maxLives, 5);
  });
}

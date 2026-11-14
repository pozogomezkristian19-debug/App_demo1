// Simulación de DOS TELÉFONOS (Quemia 7.3): Kristian invita a
// Laura, Laura canjea, pasa el Nivel 1, Kristian cobra; y los dos
// juegan el mismo torneo. Todo contra los falsos en memoria (el
// MISMO backend compartido para los dos teléfonos): NUNCA Firebase
// real. Esto es lo que Kristian pidió: probar que el sistema de
// referidos, las invitaciones y los torneos funcionan entre dos
// usuarios de verdad, no solo en un teléfono solo.
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/auth_service.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/referral_service.dart';
import 'package:quimica_pura/services/social_service.dart';
import 'package:quimica_pura/services/tournaments_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late InMemoryAnalyticsRepository fake;
  late FakeAuthProvider authFake;
  late InMemorySocialRepository socialRepo;

  /// Cambia de teléfono: el usuario activo pasa a ser [uid]/[name].
  /// El backend (fake) es EL MISMO para los dos, como el Firestore
  /// real: lo que escribe un teléfono lo ve el otro.
  Future<void> comoUsuario({
    required String uid,
    required String name,
    String gender = 'Femenino',
  }) async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    UserPrefs.userName = name;
    UserPrefs.userGender = gender;
    UserPrefs.publicUsername = '';
    UserPrefs.track = 'uni';
    SocialService.resetForTests();
    authFake.uid = uid;
    authFake.googleLinked = true;
    authFake.email = '$uid@example.com';
    authFake.displayName = name;
    // El repo social es el mismo objeto para los dos teléfonos.
    SocialService.setRepositoryForTests(socialRepo);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AnalyticsSync.resetForTests();
    AuthService.resetForTests();
    fake = InMemoryAnalyticsRepository();
    authFake = FakeAuthProvider();
    AnalyticsSync.setRepositoryForTests(fake);
    AuthService.setProviderForTests(authFake);
    socialRepo = InMemorySocialRepository(seedDemo: true);
    SocialService.setRepositoryForTests(socialRepo);
    ProgressService.track = ProgressService.trackUni;
    await ProgressService.load();
    UserPrefs.track = 'uni';
    await AuthService.ensureAnonymous();
    await authFake.linkWithGoogle();
  });

  tearDown(() {
    AnalyticsSync.resetForTests();
    AuthService.resetForTests();
    SocialService.resetForTests();
    UserPrefs.publicUsername = '';
  });

  test('Teléfono A invita, teléfono B canjea y pasa el Nivel 1', () async {
    // Teléfono A (Kristian): se registra y saca su código.
    await comoUsuario(uid: 'kristian-uid', name: 'Kristian');
    final nombreA = await ReferralService.ensureUniqueUsername();
    expect(nombreA, 'Kristian');
    final codigoA = await ReferralService.ensureMyCode();
    expect(codigoA.length, 6);
    expect(codigoA, isNotEmpty);

    // Teléfono B (Laura): se registra y canjea el código de A.
    await comoUsuario(uid: 'laura-uid', name: 'Laura');
    final nombreB = await ReferralService.ensureUniqueUsername();
    expect(nombreB, 'Laura');
    expect(await ReferralService.redeemCode(codigoA), RedeemResult.ok);

    // El canje quedó guardado y enlaza a los dos.
    final rows = await fake.queryDocs('referrals',
        whereField: 'code', isEqualTo: codigoA);
    expect(rows.length, 1);
    expect(rows.first['status'], 'pending');
    expect(rows.first['inviterUid'], 'kristian-uid');
    expect(rows.first['inviteeUid'], 'laura-uid');
    expect(rows.first['inviteeUsername'], 'Laura');

    // Laura pasa el Nivel 1 y gana +20 (solo una vez, solo Nivel 1).
    expect(ProgressService.instance.points, 0);
    await ReferralService.maybeRewardInviteeOnLevelPass(2);
    expect(ProgressService.instance.points, 0);
    await ReferralService.maybeRewardInviteeOnLevelPass(1);
    expect(ProgressService.instance.points, 20);
    await ReferralService.maybeRewardInviteeOnLevelPass(1);
    expect(ProgressService.instance.points, 20);

    // Teléfono A (Kristian) abre Invitar y cobra +50 por Laura.
    await comoUsuario(uid: 'kristian-uid', name: 'Kristian');
    final claim = await ReferralService.claimInviterRewards();
    expect(claim.newReferrals, ['Laura']);
    expect(ProgressService.instance.points, 50);
    final state = await ReferralService.loadState();
    expect(state.referralsCount, 1);
    expect(state.lastInvitee, 'Laura');
    // Cobrar de nuevo no vuelve a pagar.
    final again = await ReferralService.claimInviterRewards();
    expect(again.hasNews, isFalse);
    expect(ProgressService.instance.points, 50);

    // La tabla de los que más invitan muestra a Kristian primero.
    final top = await ReferralService.topReferrers();
    expect(top, isNotEmpty);
    expect(top.first.username, 'Kristian');
    expect(top.first.referralsCount, 1);
  });

  test('Teléfono B no puede canjear su propio código ni dos veces', () async {
    await comoUsuario(uid: 'kristian-uid', name: 'Kristian');
    final codigoA = await ReferralService.ensureMyCode();
    await comoUsuario(uid: 'laura-uid', name: 'Laura');
    final codigoB = await ReferralService.ensureMyCode();
    expect(await ReferralService.redeemCode(codigoB), RedeemResult.ownCode);
    expect(await ReferralService.redeemCode(codigoA), RedeemResult.ok);
    expect(await ReferralService.redeemCode(codigoA),
        RedeemResult.alreadyRedeemed);
    expect(await ReferralService.redeemCode('ZZZZZZ'),
        RedeemResult.alreadyRedeemed);
  });

  test('Tres invitados: Kristian llega al hito 3 y gana el Embajador',
      () async {
    await comoUsuario(uid: 'kristian-uid', name: 'Kristian');
    final codigoA = await ReferralService.ensureMyCode();
    // Tres teléfonos distintos canjean el código de Kristian.
    for (final (uid, name) in [
      ('laura-uid', 'Laura'),
      ('carlos-uid', 'Carlos'),
      ('sofia-uid', 'Sofia'),
    ]) {
      await comoUsuario(uid: uid, name: name);
      expect(await ReferralService.redeemCode(codigoA), RedeemResult.ok);
      await ReferralService.maybeRewardInviteeOnLevelPass(1);
    }
    // Kristian cobra: 3 x 50 = 150 + hito 3 (avatar Embajador).
    await comoUsuario(uid: 'kristian-uid', name: 'Kristian');
    final claim = await ReferralService.claimInviterRewards();
    expect(claim.newReferrals, ['Laura', 'Carlos', 'Sofia']);
    expect(claim.newMilestones, [3]);
    expect(ProgressService.instance.points, 150);
    expect(await SocialService.isOwned('avatar_embajador'), isTrue);
    final state = await ReferralService.loadState();
    expect(state.referralsCount, 3);
    expect(state.milestonesGranted, contains(3));
  });

  test('Torneo: los dos teléfonos juegan y la tabla los ordena', () async {
    // El torneo existe en el repo compartido (como lo crea el
    // agente en Firestore). Activo ahora mismo.
    final now = DateTime.now().millisecondsSinceEpoch;
    await fake.setDoc('tournaments', 't-sim', <String, dynamic>{
      'id': 't-sim',
      'title': 'Torneo de Estequiometría',
      'topic': 'estequiometria',
      'startAtMs': now - 1000,
      'endAtMs': now + 3600000,
      'questionIds': <String>[],
      'prizePoints': 50,
    }, merge: false);

    // Teléfono A (Kristian) juega y saca 20.
    await comoUsuario(uid: 'kristian-uid', name: 'Kristian');
    expect(await TournamentsService.submitScore('t-sim', score: 20), isTrue);
    final mio = await TournamentsService.myScore('t-sim');
    expect(mio, isNotNull);
    expect(mio!.bestScore, 20);

    // Teléfono B (Laura) juega y saca 15. Su mejor es SOLO el suyo.
    await comoUsuario(uid: 'laura-uid', name: 'Laura');
    expect(await TournamentsService.submitScore('t-sim', score: 15), isTrue);
    final deLaura = await TournamentsService.myScore('t-sim');
    expect(deLaura, isNotNull);
    expect(deLaura!.bestScore, 15);

    // Volver a Kristian: su 20 sigue intacto (no lo pisó Laura).
    await comoUsuario(uid: 'kristian-uid', name: 'Kristian');
    final mioDeNuevo = await TournamentsService.myScore('t-sim');
    expect(mioDeNuevo!.bestScore, 20);
    // Y si Kristian juega peor, su mejor NO baja.
    await TournamentsService.submitScore('t-sim', score: 10);
    expect((await TournamentsService.myScore('t-sim'))!.bestScore, 20);

    // La tabla tiene a los dos, Kristian primero con 20.
    final tabla = await TournamentsService.leaderboard('t-sim');
    expect(tabla.length, 2);
    expect(tabla.first.username, 'Kristian');
    expect(tabla.first.bestScore, 20);
    expect(tabla.last.username, 'Laura');
    expect(tabla.last.bestScore, 15);
  });
}

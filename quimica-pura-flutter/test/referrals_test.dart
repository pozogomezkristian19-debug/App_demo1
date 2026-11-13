// Tests de referidos (Quemia 7.3): códigos, canje, premio del
// Nivel 1, cobro del invitador, hitos, usernames únicos y tabla.
// Todo contra los falsos en memoria: NUNCA Firebase real.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/auth_service.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/referral_rewards.dart';
import 'package:quimica_pura/services/referral_service.dart';
import 'package:quimica_pura/services/social_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late InMemoryAnalyticsRepository fake;
  late FakeAuthProvider authFake;

  Future<void> setUpUser({
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
    authFake.email = 'test@example.com';
    authFake.displayName = name;
  }

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
    UserPrefs.userName = 'Vanessa';
    UserPrefs.userGender = 'Femenino';
    UserPrefs.publicUsername = '';
    UserPrefs.track = 'uni';
    SocialService.resetForTests();
    await AuthService.ensureAnonymous();
    await authFake.linkWithGoogle();
  });

  tearDown(() {
    AnalyticsSync.resetForTests();
    AuthService.resetForTests();
    SocialService.resetForTests();
    UserPrefs.publicUsername = '';
  });

  test('el código tiene 6 caracteres del alfabeto permitido', () {
    final seen = <String>{};
    for (var i = 0; i < 20; i++) {
      final code = generateReferralCode();
      expect(code.length, 6);
      expect(code, matches(RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$')));
      seen.add(code);
    }
    // Aleatorio de verdad: 20 códigos no salen todos iguales.
    expect(seen.length, greaterThan(15));
  });

  test('ensureMyCode crea el código y lo recuerda', () async {
    final code = await ReferralService.ensureMyCode();
    expect(code.length, 6);
    expect(await ReferralService.ensureMyCode(), code);
    final doc = await fake.getDoc('referral_codes', code);
    expect(doc?['uid'], 'fake-anon-uid');
    expect(doc?['maxUses'], 10);
    final user = await fake.getUser('fake-anon-uid');
    expect(user?['referralCode'], code);
  });

  test('ensureMyCode sin Google devuelve vacío', () async {
    authFake.googleLinked = false;
    expect(await ReferralService.ensureMyCode(), '');
  });

  test('username único: el primero se queda el nombre, el segundo lleva sufijo',
      () async {
    expect(await ReferralService.ensureUniqueUsername(), 'Vanessa');
    expect(UserPrefs.publicUsername, 'Vanessa');
    // El saludo NO cambia: sigue "Bienvenida Vanessa".
    expect(UserPrefs.greeting, 'Bienvenida Vanessa');
    expect(UserPrefs.userName, 'Vanessa');

    // Segundo teléfono, mismo nombre.
    await setUpUser(uid: 'user-b', name: 'Vanessa');
    final second = await ReferralService.ensureUniqueUsername();
    expect(second, matches(RegExp(r'^Vanessa\d{4}$')));
    expect(UserPrefs.greeting, 'Bienvenida Vanessa');
    final reserved =
        await fake.getDoc('usernames', second.toLowerCase());
    expect(reserved?['uid'], 'user-b');
  });

  test('redeemCode rechaza formatos malos', () async {
    expect(await ReferralService.redeemCode('ABC'),
        RedeemResult.invalid);
    expect(await ReferralService.redeemCode('ABCDEF!'),
        RedeemResult.invalid);
    expect(await ReferralService.redeemCode(''), RedeemResult.invalid);
  });

  test('redeemCode con código inexistente devuelve notFound', () async {
    expect(await ReferralService.redeemCode('Q8M4K2'),
        RedeemResult.notFound);
  });

  test('redeemCode con el propio código devuelve ownCode', () async {
    final code = await ReferralService.ensureMyCode();
    expect(await ReferralService.redeemCode(code), RedeemResult.ownCode);
  });

  test('redeemCode ok y ya no deja canjear otro', () async {
    final code = await ReferralService.ensureMyCode();
    // Segundo teléfono: el invitado.
    await setUpUser(uid: 'invitee-uid', name: 'Carlos', gender: 'Masculino');
    expect(await ReferralService.redeemCode(code), RedeemResult.ok);
    final rows = await fake.queryDocs('referrals',
        whereField: 'code', isEqualTo: code);
    expect(rows.length, 1);
    expect(rows.first['status'], 'pending');
    expect(rows.first['inviteeUid'], 'invitee-uid');
    expect(rows.first['inviteeUsername'], 'Carlos');
    final user = await fake.getUser('invitee-uid');
    expect(user?['referredBy'], code);
    expect(await ReferralService.redeemCode('AAAAAA'),
        RedeemResult.alreadyRedeemed);
  });

  test('redeemCode agotado a los 10 usos', () async {
    const code = 'Q8M4K2';
    await fake.setDoc('referral_codes', code, {
      'uid': 'inviter-uid',
      'createdAtMs': 1,
      'maxUses': 10,
    }, merge: false);
    for (var i = 0; i < 10; i++) {
      await fake.createDoc('referrals', {
        'code': code,
        'inviterUid': 'inviter-uid',
        'inviteeUid': 'guest-$i',
        'inviteeUsername': 'Guest$i',
        'status': 'rewarded',
        'inviterRewarded': true,
        'createdAtMs': 1,
      });
    }
    expect(await ReferralService.redeemCode(code),
        RedeemResult.exhausted);
  });

  test('maybeRewardInviteeOnLevelPass: solo el Nivel 1 y solo una vez',
      () async {
    final code = await ReferralService.ensureMyCode();
    await setUpUser(uid: 'invitee-uid', name: 'Carlos', gender: 'Masculino');
    expect(await ReferralService.redeemCode(code), RedeemResult.ok);
    expect(ProgressService.instance.points, 0);

    await ReferralService.maybeRewardInviteeOnLevelPass(2);
    expect(ProgressService.instance.points, 0);

    await ReferralService.maybeRewardInviteeOnLevelPass(1);
    expect(ProgressService.instance.points, 20);
    final rows = await fake.queryDocs('referrals',
        whereField: 'code', isEqualTo: code);
    expect(rows.first['status'], 'rewarded');
    final user = await fake.getUser('invitee-uid');
    expect(user?['referralRewarded'], true);

    // Segunda vez no vuelve a pagar.
    await ReferralService.maybeRewardInviteeOnLevelPass(1);
    expect(ProgressService.instance.points, 20);
  });

  test('claimInviterRewards paga +50, cuenta y es idempotente', () async {
    const code = 'Q8M4K2';
    await fake.setDoc('referral_codes', code, {
      'uid': 'fake-anon-uid',
      'createdAtMs': 1,
      'maxUses': 10,
    }, merge: false);
    await fake.createDoc('referrals', {
      'code': code,
      'inviterUid': 'fake-anon-uid',
      'inviteeUid': 'invitee-uid',
      'inviteeUsername': 'Carlos',
      'status': 'rewarded',
      'inviterRewarded': false,
      'createdAtMs': 1,
    });

    final claim = await ReferralService.claimInviterRewards();
    expect(claim.newReferrals, ['Carlos']);
    expect(ProgressService.instance.points, 50);
    final state = await ReferralService.loadState();
    expect(state.referralsCount, 1);
    expect(state.lastInvitee, 'Carlos');
    final rows = await fake.queryDocs('referrals',
        whereField: 'code', isEqualTo: code);
    expect(rows.first['inviterRewarded'], true);

    // Segunda vez no vuelve a pagar.
    final again = await ReferralService.claimInviterRewards();
    expect(again.hasNews, isFalse);
    expect(ProgressService.instance.points, 50);
  });

  test('hito 3 regala el avatar Embajador', () async {
    const code = 'Q8M4K2';
    for (var i = 0; i < 3; i++) {
      await fake.createDoc('referrals', {
        'code': code,
        'inviterUid': 'fake-anon-uid',
        'inviteeUid': 'guest-$i',
        'inviteeUsername': 'Guest$i',
        'status': 'rewarded',
        'inviterRewarded': false,
        'createdAtMs': 1,
      });
    }
    final claim = await ReferralService.claimInviterRewards();
    expect(claim.newMilestones, [3]);
    expect(ProgressService.instance.points, 150);
    expect(await SocialService.isOwned('avatar_embajador'), isTrue);
    expect(SocialService.avatarAssetForId('avatar_embajador'),
        'assets/avatar_embajador.png');
    final state = await ReferralService.loadState();
    expect(state.milestonesGranted, contains(3));
  });

  test('hito 10 regala la Leyenda + 200 puntos', () async {
    const code = 'Q8M4K2';
    for (var i = 0; i < 10; i++) {
      await fake.createDoc('referrals', {
        'code': code,
        'inviterUid': 'fake-anon-uid',
        'inviteeUid': 'guest-$i',
        'inviteeUsername': 'Guest$i',
        'status': 'rewarded',
        'inviterRewarded': false,
        'createdAtMs': 1,
      });
    }
    final claim = await ReferralService.claimInviterRewards();
    expect(claim.newMilestones, [3, 5, 10]);
    // 10 x 50 del cobro + 200 del hito 10.
    expect(ProgressService.instance.points, 700);
    expect(await SocialService.isOwned('avatar_leyenda'), isTrue);
    expect(await SocialService.isOwned('theme_embajador'), isTrue);
    expect(await SocialService.isOwned('badge_embajador'), isTrue);
    // El tema se equipa y tiñe el acento de dorado.
    await SocialService.equipItem(kThemeEmbajador);
    expect(SocialService.equippedThemeColor, const Color(0xFFF59E0B));
  });

  test('topReferrers ordena por referidos y excluye ceros', () async {
    await fake.setUser('u1', {'username': 'Ana', 'referralsCount': 5});
    await fake.setUser('u2', {'username': 'Luis', 'referralsCount': 12});
    await fake.setUser('u3', {'username': 'Mia', 'referralsCount': 0});
    await fake.setUser('u4', {'username': 'Leo'});
    final top = await ReferralService.topReferrers();
    expect(top.map((t) => t.username).toList(), ['Luis', 'Ana']);
    expect(top.first.referralsCount, 12);
  });

  test('loadState sin Google devuelve needsGoogle', () async {
    authFake.googleLinked = false;
    final state = await ReferralService.loadState();
    expect(state.needsGoogle, isTrue);
  });

  test('loadState restaura el conteo desde la nube en un teléfono nuevo',
      () async {
    const code = 'Q8M4K2';
    await fake.setDoc('referral_codes', code, {
      'uid': 'fake-anon-uid',
      'createdAtMs': 1,
      'maxUses': 10,
    }, merge: false);
    await fake.setUser('fake-anon-uid', {
      'username': 'Vanessa',
      'referralCode': code,
      'referralsCount': 4,
      'referralMilestones': ['3'],
      'referralLastInvitee': 'Carlos',
    });
    for (var i = 0; i < 2; i++) {
      await fake.createDoc('referrals', {
        'code': code,
        'inviterUid': 'fake-anon-uid',
        'inviteeUid': 'guest-$i',
        'inviteeUsername': 'Guest$i',
        'status': 'rewarded',
        'inviterRewarded': true,
        'createdAtMs': 1,
      });
    }
    final state = await ReferralService.loadState();
    expect(state.code, code);
    expect(state.referralsCount, 4);
    expect(state.milestonesGranted, [3]);
    expect(state.lastInvitee, 'Carlos');
    expect(state.usesLeft, 8);
  });

  test('localState enseña lo guardado sin tocar la red (7.5)', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('referral_my_code', 'Q8M4K2');
    await prefs.setInt('referral_count', 2);
    await prefs.setStringList('referral_milestones', ['3']);
    await prefs.setString('referral_last_invitee', 'Carlos');
    final state = await ReferralService.localState();
    expect(state.code, 'Q8M4K2');
    expect(state.referralsCount, 2);
    expect(state.milestonesGranted, [3]);
    expect(state.lastInvitee, 'Carlos');
    expect(state.offline, isTrue);
    expect(state.needsGoogle, isFalse);
  });

  test('loadState cobra una sola vez y trae el aviso en el estado (7.5)',
      () async {
    const code = 'Q8M4K2';
    await fake.createDoc('referrals', {
      'code': code,
      'inviterUid': 'fake-anon-uid',
      'inviteeUid': 'guest-1',
      'inviteeUsername': 'Carlos',
      'status': 'rewarded',
      'inviterRewarded': false,
      'createdAtMs': 1,
    });
    final first = await ReferralService.loadState();
    expect(first.claim, isNotNull);
    expect(first.claim!.hasNews, isTrue);
    expect(first.claim!.newReferrals, ['Carlos']);
    expect(ProgressService.instance.points, 50);
    // Segunda carga: ya cobrado, no vuelve a pagar.
    final second = await ReferralService.loadState();
    expect(second.claim, isNotNull);
    expect(second.claim!.hasNews, isFalse);
    expect(ProgressService.instance.points, 50);
  });

  test('ShopItem referralOnly sobrevive al mapa', () {
    final item = kAvatarEmbajador;
    expect(item.referralOnly, isTrue);
    final back = ShopItem.fromMap(item.toMap(), item.id);
    expect(back, item);
    expect(ShopItem.fromMap(kShopCatalog.first.toMap()), isNotNull);
    expect(
        ShopItem.fromMap(kShopCatalog.first.toMap())!.referralOnly, isFalse);
  });
}

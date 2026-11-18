// Premium REAL (solo web): servicio en vivo contra un Firestore
// falso en memoria.
// - Al aprobar en Admin (premiumExpiresAt en users/{uid}), la app
//   pasa a Premium AL INSTANTE sin reabrir.
// - Al denegar, la solicitud muestra el estado y la razón.
// - Al cambiar settings/app, los precios se actualizan en vivo.
// - Al llegar el vencimiento a cero, el Premium se quita solo.
// - La solicitud se crea con screenshotData (base64) y
//   screenshotUrl/screenshotPath en '' (sin Storage: el bucket no
//   existe).

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/auth_service.dart';
import 'package:quimica_pura/services/premium.dart';
import 'package:quimica_pura/services/premium_service.dart';
import 'package:quimica_pura/services/remote_tuning.dart';
import 'package:quimica_pura/services/user_prefs.dart';

void main() {
  late InMemoryAnalyticsRepository repo;
  late FakeAuthProvider fakeAuth;

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 100));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = InMemoryAnalyticsRepository();
    AnalyticsSync.setRepositoryForTests(repo);
    RemoteTuning.resetForTests();
    PremiumService.resetForTests();
    UserPrefs.userName = 'tester';
    UserPrefs.publicUsername = '';
    // Cambio 6: enviar una solicitud exige sesión. Los tests de
    // envío simulan un usuario con Google enlazada; el caso
    // invitado tiene su propio test abajo.
    fakeAuth = FakeAuthProvider()
      ..uid = 'uid-test'
      ..googleLinked = true;
    AuthService.setProviderForTests(fakeAuth);
    PremiumService.instance.start(uidOverride: 'uid-test');
    await settle();
  });

  tearDown(() {
    PremiumService.resetForTests();
    AnalyticsSync.resetForTests();
    RemoteTuning.resetForTests();
    AuthService.resetForTests();
  });

  test('sin vencimiento no hay premium', () {
    expect(PremiumService.isPremiumNow, isFalse);
    expect(PremiumFlags.isPremium, isFalse);
  });

  test('aprobar en Admin activa el premium al instante', () async {
    await repo.setDoc('users', 'uid-test', {
      'premiumExpiresAt': DateTime.now().add(const Duration(days: 30)),
      'premiumPlan': '1m',
    });
    await settle();
    expect(PremiumService.isPremiumNow, isTrue);
    expect(PremiumFlags.isPremium, isTrue);
    expect(PremiumFlags.plan, '1m');
    expect(PremiumService.expiresNotifier.value, isNotNull);
  });

  test('vencimiento pasado no activa el premium', () async {
    await repo.setDoc('users', 'uid-test', {
      'premiumExpiresAt': DateTime.now().subtract(const Duration(days: 1)),
      'premiumPlan': '1m',
    });
    await settle();
    expect(PremiumService.isPremiumNow, isFalse);
  });

  test('el premium se quita solo al llegar a cero', () async {
    await repo.setDoc('users', 'uid-test', {
      'premiumExpiresAt': DateTime.now().add(const Duration(seconds: 2)),
      'premiumPlan': '1m',
    });
    await settle();
    expect(PremiumService.isPremiumNow, isTrue);
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(PremiumService.isPremiumNow, isFalse);
    expect(PremiumFlags.isPremium, isFalse);
  });

  test('enviar solicitud crea paymentRequests en pending', () async {
    final ok = await PremiumService.instance.submitPaymentRequest(
      plan: '3m',
      screenshotData: 'data:image/jpeg;base64,AAA',
    );
    expect(ok, isTrue);
    await settle();
    final docs = repo.docs['paymentRequests']!;
    expect(docs.length, 1);
    final data = docs.values.first;
    expect(data['uid'], 'uid-test');
    expect(data['username'], 'tester');
    expect(data['plan'], '3m');
    expect(data['amount'], 600);
    expect(data['status'], 'pending');
    expect(data['reason'], '');
    expect(data['screenshotData'], 'data:image/jpeg;base64,AAA');
    // Sin Storage (bucket inexistente): estos campos van vacíos.
    expect(data['screenshotUrl'], '');
    expect(data['screenshotPath'], '');
    expect(data['reviewedAt'], isNull);
    expect(data['reviewedBy'], isNull);
    final latest = PremiumService.latestRequestNotifier.value;
    expect(latest, isNotNull);
    expect(latest!.isPending, isTrue);
    expect(latest.plan, '3m');
  });

  test('reintento tras tiempo agotado adopta la solicitud ya creada',
      () async {
    // Conexión lenta (2026-11-17): el primer intento escribe en el
    // servidor pero la respuesta se pierde (tiempo agotado). El
    // reintento NO debe crear otra solicitud: adopta la pendiente
    // que ya existe para el mismo plan.
    repo.createDocTimeoutsAfterWrite = 1;
    final ok = await PremiumService.instance.submitPaymentRequest(
      plan: '1m',
      screenshotData: 'data:image/jpeg;base64,AAA',
    );
    expect(ok, isTrue);
    await settle();
    final docs = repo.docs['paymentRequests']!;
    expect(docs.length, 1);
    expect(PremiumService.instance.lastSubmitError, isNull);
    final latest = PremiumService.latestRequestNotifier.value;
    expect(latest, isNotNull);
    expect(latest!.isPending, isTrue);
    expect(latest.plan, '1m');
  });

  test('invitado (sin sesión) no puede enviar solicitud', () async {
    // Cambio 6: sin sesión no hay pago. El invitado tiene uid
    // (anónimo) pero ni Google ni correo enlazados.
    fakeAuth.googleLinked = false;
    fakeAuth.emailLinked = false;
    expect(PremiumService.isSignedIn, isFalse);
    final ok = await PremiumService.instance.submitPaymentRequest(
      plan: '1m',
      screenshotData: 'data:image/jpeg;base64,AAA',
    );
    expect(ok, isFalse);
    expect(repo.docs['paymentRequests']?.length ?? 0, 0);
  });

  test('plan inválido no crea solicitud', () async {
    final ok = await PremiumService.instance.submitPaymentRequest(
      plan: '6m',
      screenshotData: 'data:image/jpeg;base64,AAA',
    );
    expect(ok, isFalse);
    expect(repo.docs['paymentRequests']?.length ?? 0, 0);
  });

  test('denegar en Admin muestra el estado y la razón en vivo', () async {
    await PremiumService.instance.submitPaymentRequest(
      plan: '1m',
      screenshotData: 'data:image/jpeg;base64,AAA',
    );
    await settle();
    final id = repo.docs['paymentRequests']!.keys.first;
    await repo.setDoc('paymentRequests', id, {
      'status': 'denied',
      'reason': 'Captura borrosa',
    });
    await settle();
    final latest = PremiumService.latestRequestNotifier.value;
    expect(latest, isNotNull);
    expect(latest!.isDenied, isTrue);
    expect(latest.reason, 'Captura borrosa');
    expect(PremiumService.isPremiumNow, isFalse);
  });

  test('aprobar la solicitud + el usuario activa el premium', () async {
    await PremiumService.instance.submitPaymentRequest(
      plan: '12m',
      screenshotData: 'data:image/jpeg;base64,AAA',
    );
    await settle();
    final id = repo.docs['paymentRequests']!.keys.first;
    await repo.setDoc('paymentRequests', id, {'status': 'approved'});
    await repo.setDoc('users', 'uid-test', {
      'premiumExpiresAt': DateTime.now().add(const Duration(days: 365)),
      'premiumPlan': '12m',
    });
    await settle();
    expect(PremiumService.latestRequestNotifier.value!.isApproved, isTrue);
    expect(PremiumService.isPremiumNow, isTrue);
    expect(PremiumFlags.plan, '12m');
  });

  test('cambiar settings/app actualiza precios y tarjeta en vivo', () async {
    await repo.setDoc('settings', 'app', {
      'planPrices': {'1m': 300, '3m': 700, '12m': 2000},
      'transfermovilCard': '9225 9999 8888 7777',
      'transfermovilNumber': '5355555555',
      'paymentDetails': 'Titular: Quemia',
    });
    await settle();
    expect(RemoteTuning.planPrices,
        {'1m': 300, '3m': 700, '12m': 2000});
    expect(RemoteTuning.transfermovilCard, '9225 9999 8888 7777');
    expect(RemoteTuning.transfermovilIsExample, isFalse);
    expect(PremiumService.settingsVersion.value, greaterThan(0));
  });

  test('en móvil el servicio escucha igual que en web', () async {
    PremiumService.resetForTests();
    PremiumService.instance.start(uidOverride: 'uid-test');
    await repo.setDoc('users', 'uid-test', {
      'premiumExpiresAt': DateTime.now().add(const Duration(days: 30)),
      'premiumPlan': '1m',
    });
    await settle();
    expect(PremiumService.isPremiumNow, isTrue);
    expect(PremiumService.hasPaidPremium, isTrue);
  });
}

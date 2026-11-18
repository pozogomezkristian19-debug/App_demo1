// Compra de puntos REAL (2026-11-17, Kristian: que funcione de
// verdad, no solo diseño): la solicitud va a Firestore
// (colección `pointsRequests`) y el Admin la aprueba o niega.
// Todo contra los falsos en memoria: NUNCA Firebase real.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/auth_service.dart';
import 'package:quimica_pura/services/points_purchase_service.dart';
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
    PointsPurchaseService.resetForTests();
    UserPrefs.userName = 'tester';
    UserPrefs.publicUsername = '';
    // Enviar una solicitud exige sesión: los tests de envío simulan
    // un usuario con Google enlazada; el caso invitado tiene su
    // propio test abajo.
    fakeAuth = FakeAuthProvider()
      ..uid = 'uid-test'
      ..googleLinked = true;
    AuthService.setProviderForTests(fakeAuth);
    PointsPurchaseService.instance.start(uidOverride: 'uid-test');
    await settle();
  });

  tearDown(() {
    PointsPurchaseService.resetForTests();
    AnalyticsSync.resetForTests();
    AuthService.resetForTests();
  });

  test('el envío crea una solicitud con los 12 campos del contrato',
      () async {
    final ok = await PointsPurchaseService.instance.submitPointsRequest(
      pack: kPointsPacks[1],
      screenshotData: 'data:image/jpeg;base64,AAA',
    );
    expect(ok, isTrue);
    expect(
        PointsPurchaseService.instance.lastSubmitError, isNull);
    await settle();
    final docs = repo.docs['pointsRequests']!;
    expect(docs.length, 1);
    final doc = docs.values.first;
    expect(doc['uid'], 'uid-test');
    expect(doc['username'], 'tester');
    expect(doc['points'], 1200);
    expect(doc['amount'], 100);
    expect(doc['screenshotData'], 'data:image/jpeg;base64,AAA');
    expect(doc['screenshotUrl'], '');
    expect(doc['screenshotPath'], '');
    expect(doc['status'], 'pending');
    expect(doc['reason'], '');
    expect(doc['createdAt'], isNotNull);
    expect(doc['reviewedAt'], isNull);
    expect(doc['reviewedBy'], isNull);
    final latest = PointsPurchaseService.latestRequestNotifier.value;
    expect(latest, isNotNull);
    expect(latest!.isPending, isTrue);
    expect(latest.points, 1200);
  });

  test('reintento tras tiempo agotado adopta la solicitud ya creada',
      () async {
    // Conexión lenta (igual que Premium): el primer intento escribe
    // en el servidor pero la respuesta se pierde (tiempo agotado).
    // El reintento NO debe crear otra solicitud: adopta la
    // pendiente que ya existe para el mismo paquete.
    repo.createDocTimeoutsAfterWrite = 1;
    final ok = await PointsPurchaseService.instance.submitPointsRequest(
      pack: kPointsPacks[1],
      screenshotData: 'data:image/jpeg;base64,AAA',
    );
    expect(ok, isTrue);
    await settle();
    final docs = repo.docs['pointsRequests']!;
    expect(docs.length, 1);
    expect(
        PointsPurchaseService.instance.lastSubmitError, isNull);
    final latest = PointsPurchaseService.latestRequestNotifier.value;
    expect(latest, isNotNull);
    expect(latest!.isPending, isTrue);
    expect(latest.points, 1200);
  });

  test('invitado (sin sesión) no puede enviar solicitud', () async {
    // Sin sesión no hay compra. El invitado tiene uid (anónimo)
    // pero ni Google ni correo enlazados.
    fakeAuth.googleLinked = false;
    fakeAuth.emailLinked = false;
    expect(PointsPurchaseService.isSignedIn, isFalse);
    final ok = await PointsPurchaseService.instance.submitPointsRequest(
      pack: kPointsPacks[1],
      screenshotData: 'data:image/jpeg;base64,AAA',
    );
    expect(ok, isFalse);
    expect(repo.docs['pointsRequests']?.length ?? 0, 0);
  });

  test('paquete inválido no crea solicitud', () async {
    final ok = await PointsPurchaseService.instance.submitPointsRequest(
      pack: const PointsPack(999, 999),
      screenshotData: 'data:image/jpeg;base64,AAA',
    );
    expect(ok, isFalse);
    expect(
        PointsPurchaseService.instance.lastSubmitError, 'bad-pack');
    expect(repo.docs['pointsRequests']?.length ?? 0, 0);
  });

  test('negar en Admin muestra el estado y la razón en vivo', () async {
    await PointsPurchaseService.instance.submitPointsRequest(
      pack: kPointsPacks[0],
      screenshotData: 'data:image/jpeg;base64,AAA',
    );
    await settle();
    final id = repo.docs['pointsRequests']!.keys.first;
    await repo.setDoc('pointsRequests', id, {
      'status': 'denied',
      'reason': 'Captura borrosa',
    });
    await settle();
    final latest = PointsPurchaseService.latestRequestNotifier.value;
    expect(latest, isNotNull);
    expect(latest!.isDenied, isTrue);
    expect(latest.reason, 'Captura borrosa');
    expect(latest.points, 500);
  });

  test('aprobar en Admin muestra la solicitud aprobada en vivo',
      () async {
    await PointsPurchaseService.instance.submitPointsRequest(
      pack: kPointsPacks[2],
      screenshotData: 'data:image/jpeg;base64,AAA',
    );
    await settle();
    final id = repo.docs['pointsRequests']!.keys.first;
    await repo.setDoc('pointsRequests', id, {'status': 'approved'});
    await settle();
    final latest = PointsPurchaseService.latestRequestNotifier.value;
    expect(latest, isNotNull);
    expect(latest!.isApproved, isTrue);
    expect(latest.points, 3000);
  });
}

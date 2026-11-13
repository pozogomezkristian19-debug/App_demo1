// Sin conexión: Firestore falso que falla -> cada pantalla muestra el
// estado tranquilo "Sin conexión" + botón Reintentar. NINGÚN diálogo de
// error, NINGÚN banner rojo, NINGÚN bloqueo ni cierre.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quemia_admin/models.dart';
import 'package:quemia_admin/repositories.dart';
import 'package:quemia_admin/screens.dart';

import 'test_data.dart';

/// Simula la falta de conexión: todas las llamadas fallan.
class FailingUsersRepository implements UsersRepository {
  @override
  Future<List<AppUser>> listUsers() async =>
      throw Exception('Sin conexión a internet');

  @override
  Future<AppUser?> getUser(String id) async =>
      throw Exception('Sin conexión a internet');

  @override
  Future<void> setBan(
    String id, {
    required bool banned,
    String reason = '',
    String bannedBy = '',
  }) async => throw Exception('Sin conexión a internet');

  @override
  Future<void> updateProgress(
    String id, {
    int? points,
    int? streak,
    int? lives,
  }) async => throw Exception('Sin conexión a internet');
}

class FailingAdminsRepository implements AdminsRepository {
  @override
  Future<AdminRecord?> resolveAdmin({
    required String uid,
    required String email,
  }) async => throw Exception('Sin conexión a internet');

  @override
  Future<AdminRecord> ensureOwner({
    required String uid,
    required String email,
    String displayName = '',
  }) async =>
      throw Exception('Sin conexión a internet');

  @override
  Future<List<AdminRecord>> listAdmins() async =>
      throw Exception('Sin conexión a internet');

  @override
  Future<AdminRecord> inviteByEmail({
    required String email,
    String displayName = '',
    required String createdBy,
  }) async => throw Exception('Sin conexión a internet');

  @override
  Future<void> updatePermissions(String uid, AdminPermissions p) async =>
      throw Exception('Sin conexión a internet');

  @override
  Future<void> deleteAdmin(String uid) async =>
      throw Exception('Sin conexión a internet');

  @override
  Future<void> saveFcmToken(String uid, String token) async =>
      throw Exception('Sin conexión a internet');
}

class FailingSettingsRepository implements SettingsRepository {
  @override
  Future<RemoteSettings> load() async =>
      throw Exception('Sin conexión a internet');

  @override
  Future<void> save(RemoteSettings settings) async =>
      throw Exception('Sin conexión a internet');
}

AdminService _ownerService() => AdminService(
  me: ownerRecord(),
  users: FailingUsersRepository(),
  admins: FailingAdminsRepository(),
  settings: FailingSettingsRepository(),
);

Future<void> _pump(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: quemiaAdminTheme(),
      home: Scaffold(body: screen),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectCalmState() {
  expect(find.text('Sin conexión'), findsOneWidget);
  expect(find.text('Reintentar'), findsOneWidget);
  expect(find.textContaining('Error'), findsNothing);
  expect(find.byType(AlertDialog), findsNothing);
}

void main() {
  group('sin conexión (estado tranquilo)', () {
    testWidgets('Panel muestra "Sin conexión" y Reintentar', (tester) async {
      await _pump(
        tester,
        DashboardScreen(users: FailingUsersRepository(), me: ownerRecord()),
      );
      _expectCalmState();
      // Reintentar no rompe nada: sigue en el estado tranquilo.
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      _expectCalmState();
    });

    testWidgets('Usuarios muestra "Sin conexión" y Reintentar', (tester) async {
      await _pump(
        tester,
        UsersScreen(
          users: FailingUsersRepository(),
          service: _ownerService(),
          me: ownerRecord(),
        ),
      );
      _expectCalmState();
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      _expectCalmState();
    });

    testWidgets('Admins muestra "Sin conexión" y Reintentar', (tester) async {
      await _pump(
        tester,
        AdminsScreen(
          admins: FailingAdminsRepository(),
          service: _ownerService(),
          me: ownerRecord(),
        ),
      );
      _expectCalmState();
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      _expectCalmState();
    });

    testWidgets('Ajustes muestra "Sin conexión" y Reintentar', (tester) async {
      await _pump(
        tester,
        SettingsScreen(
          settings: FailingSettingsRepository(),
          service: _ownerService(),
          me: ownerRecord(),
        ),
      );
      _expectCalmState();
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      _expectCalmState();
    });

    test(
      'las llamadas que fallan lanzan, la UI es la que las atrapa',
      () async {
        final service = _ownerService();
        await expectLater(service.users.listUsers(), throwsException);
        await expectLater(service.settings.load(), throwsException);
        await expectLater(
          service.banUser(seedUsers().first, 'motivo'),
          throwsException,
        );
      },
    );
  });
}

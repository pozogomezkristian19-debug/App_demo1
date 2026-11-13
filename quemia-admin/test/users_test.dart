// Lista de usuarios con Firestore falso + ban y quitar baneo.

import 'package:flutter_test/flutter_test.dart';
import 'package:quemia_admin/repositories.dart';

import 'test_data.dart';

void main() {
  group('usuarios (fake)', () {
    test('lista ordenada por fecha de unión (más reciente primero)', () async {
      final users = FakeUsersRepository(seedUsers());
      final list = await users.listUsers();
      expect(list.length, 12);
      expect(list.first.username, 'rosa'); // unida hace 1 día
      expect(list.last.username, 'kristian'); // unido hace 40 días
      expect(
        list.map((u) => u.username),
        containsAll([
          'kristian',
          'laura',
          'miguel',
          'sofia',
          'daniel',
          'valeria',
          'pedro',
          'camila',
          'yordanis',
          'lucia',
          'andres',
          'rosa',
        ]),
      );
    });

    test('el baneado viene marcado con su motivo', () async {
      final users = FakeUsersRepository(seedUsers());
      final list = await users.listUsers();
      final banned = list.where((u) => u.banned).toList();
      expect(banned.length, 1);
      expect(banned.first.username, 'pedro');
      expect(banned.first.bannedReason, 'Trampas en el examen');
    });

    test('banear escribe banned + motivo; quitar baneo lo limpia', () async {
      final users = FakeUsersRepository(seedUsers());
      final service = AdminService(
        me: ownerRecord(),
        users: users,
        admins: FakeAdminsRepository(),
        settings: FakeSettingsRepository(),
      );

      final laura = (await users.listUsers()).firstWhere(
        (u) => u.username == 'laura',
      );
      await service.banUser(laura, 'Spam en el chat');
      final banned = (await users.getUser(laura.id))!;
      expect(banned.banned, isTrue);
      expect(banned.bannedReason, 'Spam en el chat');
      expect(banned.bannedAt, isNotNull);

      await service.unbanUser(banned);
      final unbanned = (await users.getUser(laura.id))!;
      expect(unbanned.banned, isFalse);
      expect(unbanned.bannedReason, '');
    });

    test('activos hoy = lastActive en las últimas 24 h', () {
      final users = seedUsers();
      final byName = {for (final u in users) u.username: u};
      expect(byName['kristian']!.activeToday, isTrue); // hace 2 h
      expect(byName['valeria']!.activeToday, isTrue); // ahora mismo
      expect(byName['sofia']!.activeToday, isFalse); // hace 26 h
      expect(byName['daniel']!.activeToday, isFalse); // hace 3 días
      expect(users.where((u) => u.activeToday).length, 8);
    });

    test('banear sin motivo no se permite', () async {
      final users = FakeUsersRepository(seedUsers());
      final service = AdminService(
        me: ownerRecord(),
        users: users,
        admins: FakeAdminsRepository(),
        settings: FakeSettingsRepository(),
      );
      final laura = (await users.listUsers()).firstWhere(
        (u) => u.username == 'laura',
      );
      await expectLater(service.banUser(laura, '   '), throwsArgumentError);
      await expectLater(service.banUser(laura, ''), throwsArgumentError);
      expect((await users.getUser(laura.id))!.banned, isFalse);
    });

    test('banear guarda motivo, quién y el historial', () async {
      final users = FakeUsersRepository(seedUsers());
      final service = AdminService(
        me: ownerRecord(),
        users: users,
        admins: FakeAdminsRepository(),
        settings: FakeSettingsRepository(),
      );
      final laura = (await users.listUsers()).firstWhere(
        (u) => u.username == 'laura',
      );
      await service.banUser(laura, 'Spam en el chat');
      final banned = (await users.getUser(laura.id))!;
      expect(banned.banned, isTrue);
      expect(banned.bannedReason, 'Spam en el chat');
      expect(banned.bannedBy, ownerEmail);
      expect(banned.banHistory.length, 1);
      expect(banned.banHistory.first.action, 'ban');
      expect(banned.banHistory.first.reason, 'Spam en el chat');
      expect(banned.banHistory.first.by, ownerEmail);

      await service.unbanUser(banned, reason: 'Perdonado');
      final unbanned = (await users.getUser(laura.id))!;
      expect(unbanned.banned, isFalse);
      expect(unbanned.bannedAt, isNull);
      expect(unbanned.bannedBy, '');
      expect(unbanned.banHistory.length, 2);
      expect(unbanned.banHistory.last.action, 'unban');
      expect(unbanned.banHistory.last.reason, 'Perdonado');
    });

    test('editar progreso: puntos, racha y vidas', () async {
      final users = FakeUsersRepository(seedUsers());
      final service = AdminService(
        me: ownerRecord(),
        users: users,
        admins: FakeAdminsRepository(),
        settings: FakeSettingsRepository(),
      );
      final laura = (await users.listUsers()).firstWhere(
        (u) => u.username == 'laura',
      );
      final updated = await service.editUserProgress(
        laura,
        points: 500,
        streak: 9,
        lives: 4,
      );
      expect(updated.points, 500);
      expect(updated.streak, 9);
      expect(updated.lives, 4);
      final stored = (await users.getUser(laura.id))!;
      expect(stored.points, 500);
      expect(stored.streak, 9);
      expect(stored.lives, 4);
    });

    test('editar progreso: solo cambia lo que se pasa', () async {
      final users = FakeUsersRepository(seedUsers());
      final service = AdminService(
        me: ownerRecord(),
        users: users,
        admins: FakeAdminsRepository(),
        settings: FakeSettingsRepository(),
      );
      final laura = (await users.listUsers()).firstWhere(
        (u) => u.username == 'laura',
      );
      final updated = await service.editUserProgress(laura, points: 100);
      expect(updated.points, 100);
      expect(updated.streak, laura.streak);
      expect(updated.lives, isNull);
    });

    test('editar progreso: validación de valores', () async {
      final users = FakeUsersRepository(seedUsers());
      final service = AdminService(
        me: ownerRecord(),
        users: users,
        admins: FakeAdminsRepository(),
        settings: FakeSettingsRepository(),
      );
      final laura = (await users.listUsers()).firstWhere(
        (u) => u.username == 'laura',
      );
      await expectLater(
        service.editUserProgress(laura, points: -1),
        throwsArgumentError,
      );
      await expectLater(
        service.editUserProgress(laura, streak: -2),
        throwsArgumentError,
      );
      await expectLater(
        service.editUserProgress(laura, lives: 6),
        throwsArgumentError,
      );
      await expectLater(
        service.editUserProgress(laura, lives: -1),
        throwsArgumentError,
      );
    });

    test('editar progreso: sin permiso no se puede', () async {
      final users = FakeUsersRepository(seedUsers());
      final service = AdminService(
        me: readOnlyAdminRecord(),
        users: users,
        admins: FakeAdminsRepository(),
        settings: FakeSettingsRepository(),
      );
      final laura = (await users.listUsers()).firstWhere(
        (u) => u.username == 'laura',
      );
      await expectLater(
        service.editUserProgress(laura, points: 10),
        throwsA(isA<PermissionDenied>()),
      );
    });

    test('nivel medio del panel', () async {
      final users = FakeUsersRepository(seedUsers());
      final list = await users.listUsers();
      final total = list
          .map((u) => u.totalLevelsPassed)
          .reduce((a, b) => a + b);
      expect(total, 71);
      expect(total / list.length, closeTo(71 / 12, 0.001));
    });
  });
}

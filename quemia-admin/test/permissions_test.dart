// Matriz de permisos: dueño todo; admin sin banUsers no puede banear;
// sin manageAdmins no puede tocar permisos ni admins; nadie se auto-concede
// permisos ni toca al dueño.

import 'package:flutter_test/flutter_test.dart';
import 'package:quemia_admin/models.dart';
import 'package:quemia_admin/repositories.dart';

import 'test_data.dart';

AdminService serviceFor(AdminRecord me) => AdminService(
  me: me,
  users: FakeUsersRepository(seedUsers()),
  admins: FakeAdminsRepository([ownerRecord(), readOnlyAdminRecord()]),
  settings: FakeSettingsRepository(),
);

void main() {
  group('matriz de permisos', () {
    test('el dueño lo puede todo', () {
      final owner = ownerRecord();
      expect(owner.canViewUsers(), isTrue);
      expect(owner.canViewProgress(), isTrue);
      expect(owner.canBanUsers(), isTrue);
      expect(owner.canManageAdmins(), isTrue);
    });

    test('admin sin banUsers NO puede banear ni quitar baneos', () async {
      final service = serviceFor(readOnlyAdminRecord());
      final user = seedUsers().first;
      await expectLater(
        service.banUser(user, 'motivo'),
        throwsA(isA<PermissionDenied>()),
      );
      await expectLater(
        service.unbanUser(user),
        throwsA(isA<PermissionDenied>()),
      );
      // Y el usuario sigue sin banear.
      final after = (await service.users.listUsers()).first;
      expect(after.banned, isFalse);
    });

    test('admin con banUsers SÍ puede banear', () async {
      final withBan = AdminRecord(
        uid: 'uid-ban',
        email: 'ban@gmail.com',
        role: 'admin',
        permissions: const AdminPermissions(
          viewUsers: true,
          viewProgress: true,
          banUsers: true,
        ),
        createdBy: ownerEmail,
      );
      final service = serviceFor(withBan);
      final user = seedUsers().first;
      await service.banUser(user, 'motivo');
      final after = (await service.users.getUser(user.id))!;
      expect(after.banned, isTrue);
    });

    test('admin sin manageAdmins NO puede invitar ni tocar permisos', () async {
      final service = serviceFor(readOnlyAdminRecord());
      await expectLater(
        service.inviteAdmin(email: 'otro@gmail.com'),
        throwsA(isA<PermissionDenied>()),
      );
      await expectLater(
        service.setAdminPermissions(
          readOnlyAdminRecord(),
          const AdminPermissions(viewUsers: true, banUsers: true),
        ),
        throwsA(isA<PermissionDenied>()),
      );
      await expectLater(
        service.removeAdmin(readOnlyAdminRecord()),
        throwsA(isA<PermissionDenied>()),
      );
    });

    test('nadie puede concederse a sí mismo permisos que no tiene', () async {
      // Admin con manageAdmins pero sin banUsers intenta auto-darse banUsers.
      final me = AdminRecord(
        uid: 'uid-mgr',
        email: 'mgr@gmail.com',
        role: 'admin',
        permissions: const AdminPermissions(
          viewUsers: true,
          viewProgress: true,
          manageAdmins: true,
        ),
        createdBy: ownerEmail,
      );
      final service = AdminService(
        me: me,
        users: FakeUsersRepository(),
        admins: FakeAdminsRepository([me]),
        settings: FakeSettingsRepository(),
      );
      await expectLater(
        service.setAdminPermissions(
          me,
          const AdminPermissions(
            viewUsers: true,
            viewProgress: true,
            banUsers: true,
            manageAdmins: true,
          ),
        ),
        throwsA(isA<PermissionDenied>()),
      );
      // Quitarse un permiso propio sí se permite (no es concederse nada).
      await service.setAdminPermissions(
        me,
        const AdminPermissions(viewUsers: true, viewProgress: true),
      );
    });

    test('nadie puede tocar al dueño: ni permisos ni eliminarlo', () async {
      final service = serviceFor(ownerRecord());
      await expectLater(
        service.setAdminPermissions(ownerRecord(), AdminPermissions.readOnly),
        throwsA(isA<PermissionDenied>()),
      );
      await expectLater(
        service.removeAdmin(ownerRecord()),
        throwsA(isA<PermissionDenied>()),
      );
    });

    test('nadie puede eliminarse a sí mismo', () async {
      final me = AdminRecord(
        uid: 'uid-mgr',
        email: 'mgr@gmail.com',
        role: 'admin',
        permissions: const AdminPermissions(
          viewUsers: true,
          viewProgress: true,
          banUsers: true,
          manageAdmins: true,
        ),
        createdBy: ownerEmail,
      );
      final service = AdminService(
        me: me,
        users: FakeUsersRepository(),
        admins: FakeAdminsRepository([me]),
        settings: FakeSettingsRepository(),
      );
      await expectLater(
        service.removeAdmin(me),
        throwsA(isA<PermissionDenied>()),
      );
    });

    test('el dueño puede cambiar permisos y eliminar a otro admin', () async {
      final admins = FakeAdminsRepository([
        ownerRecord(),
        readOnlyAdminRecord(),
      ]);
      final service = AdminService(
        me: ownerRecord(),
        users: FakeUsersRepository(),
        admins: admins,
        settings: FakeSettingsRepository(),
      );
      await service.setAdminPermissions(
        readOnlyAdminRecord(),
        const AdminPermissions(viewUsers: true, banUsers: true),
      );
      final updated = (await admins.listAdmins()).firstWhere(
        (a) => a.uid == adminUid,
      );
      expect(updated.permissions.banUsers, isTrue);

      await service.removeAdmin(readOnlyAdminRecord());
      expect(await admins.listAdmins(), hasLength(1));
    });
  });
}

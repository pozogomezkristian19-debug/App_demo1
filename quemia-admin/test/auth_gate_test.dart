// Puerta de auth: entra quien está en 'admins', se rechaza a quien no está,
// y una invitación por correo se adopta al entrar con Google.

import 'package:flutter_test/flutter_test.dart';
import 'package:quemia_admin/models.dart';
import 'package:quemia_admin/repositories.dart';

import 'test_data.dart';

void main() {
  group('puerta de auth (resolveAdmin)', () {
    test('el dueño listado entra', () async {
      final admins = FakeAdminsRepository([ownerRecord()]);
      final found = await admins.resolveAdmin(uid: ownerUid, email: ownerEmail);
      expect(found, isNotNull);
      expect(found!.isOwner, isTrue);
      expect(found.canBanUsers(), isTrue);
      expect(found.canManageAdmins(), isTrue);
    });

    test('un admin listado entra con sus permisos', () async {
      final admins = FakeAdminsRepository([readOnlyAdminRecord()]);
      final found = await admins.resolveAdmin(uid: adminUid, email: adminEmail);
      expect(found, isNotNull);
      expect(found!.isOwner, isFalse);
      expect(found.canViewUsers(), isTrue);
      expect(found.canBanUsers(), isFalse);
      expect(found.canManageAdmins(), isFalse);
    });

    test('quien NO está listado es rechazado (null)', () async {
      final admins = FakeAdminsRepository([ownerRecord()]);
      final found = await admins.resolveAdmin(
        uid: 'intruso-uid',
        email: 'intruso@gmail.com',
      );
      expect(found, isNull);
    });

    test('una invitación por correo se adopta al entrar con Google', () async {
      final admins = FakeAdminsRepository();
      await admins.inviteByEmail(
        email: 'nuevo@gmail.com',
        createdBy: ownerEmail,
      );
      // Antes de entrar, solo existe el pendiente (id = correo).
      final before = await admins.listAdmins();
      expect(before.length, 1);
      expect(before.first.pending, isTrue);

      final found = await admins.resolveAdmin(
        uid: 'nuevo-uid-789',
        email: 'Nuevo@Gmail.com',
      );
      expect(found, isNotNull);
      expect(found!.uid, 'nuevo-uid-789');
      expect(found.pending, isFalse);
      expect(found.permissions.viewUsers, isTrue);
      expect(found.permissions.banUsers, isFalse);

      // El pendiente ya no existe: quedó adoptado bajo el uid.
      final after = await admins.listAdmins();
      expect(after.length, 1);
      expect(after.first.uid, 'nuevo-uid-789');
    });

    test('el correo del dueño es el primer admin', () {
      final owner = ownerRecord();
      expect(owner.email, ownerEmail);
      expect(owner.role, 'owner');
      expect(owner.permissions, AdminPermissions.all);
    });
  });
}

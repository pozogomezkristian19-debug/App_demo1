// Arranque sin fricción del dueño: pozogomezkristian19@gmail.com entra
// directo como dueño aunque 'admins' esté vacía (la app crea su documento);
// cualquier otra cuenta sin registro no entra.

import 'package:flutter_test/flutter_test.dart';
import 'package:quemia_admin/models.dart';
import 'package:quemia_admin/repositories.dart';

import 'test_data.dart';

void main() {
  group('arranque del dueño', () {
    test('la constante del dueño es su correo', () {
      expect(kOwnerEmail, 'pozogomezkristian19@gmail.com');
      expect(kOwnerEmail, ownerEmail);
    });

    test('dueño con admins vacía entra directo y se crea su documento', () async {
      final admins = FakeAdminsRepository();
      expect(await admins.listAdmins(), isEmpty);

      final record = await resolveAdminRecord(
        admins: admins,
        uid: ownerUid,
        email: ownerEmail,
        displayName: 'Kristian',
      );

      expect(record, isNotNull);
      expect(record!.isOwner, isTrue);
      expect(record.email, ownerEmail);
      expect(record.permissions, AdminPermissions.all);
      expect(record.canBanUsers(), isTrue);
      expect(record.canManageAdmins(), isTrue);

      // El documento quedó creado en 'admins'.
      final list = await admins.listAdmins();
      expect(list.length, 1);
      expect(list.first.uid, ownerUid);
      expect(list.first.role, 'owner');
    });

    test('el dueño vuelve a entrar sin duplicar su documento', () async {
      final admins = FakeAdminsRepository();
      await resolveAdminRecord(
        admins: admins,
        uid: ownerUid,
        email: ownerEmail,
      );
      await resolveAdminRecord(
        admins: admins,
        uid: ownerUid,
        email: ownerEmail,
      );
      expect((await admins.listAdmins()).length, 1);
    });

    test('otra cuenta con admins vacía NO entra (null)', () async {
      final admins = FakeAdminsRepository();
      final record = await resolveAdminRecord(
        admins: admins,
        uid: 'intruso-uid',
        email: 'intruso@gmail.com',
      );
      expect(record, isNull);
      expect(await admins.listAdmins(), isEmpty);
    });

    test('otra cuenta con admins ya creada tampoco entra si no está', () async {
      final admins = FakeAdminsRepository([ownerRecord()]);
      final record = await resolveAdminRecord(
        admins: admins,
        uid: 'intruso-uid',
        email: 'intruso@gmail.com',
      );
      expect(record, isNull);
    });

    test('el dueño agrega a otro admin y ese admin entra con sus permisos',
        () async {
      final admins = FakeAdminsRepository();
      final service = AdminService(
        me: ownerRecord(),
        users: FakeUsersRepository(),
        admins: admins,
        settings: FakeSettingsRepository(),
      );

      // El dueño lo agrega por correo (invitación pendiente).
      await service.inviteAdmin(email: adminEmail);

      // El nuevo admin entra con su cuenta de Google: la invitación se
      // adopta y entra con permisos solo de lectura.
      final record = await resolveAdminRecord(
        admins: admins,
        uid: adminUid,
        email: adminEmail,
        displayName: 'Ayudante',
      );
      expect(record, isNotNull);
      expect(record!.isOwner, isFalse);
      expect(record.canViewUsers(), isTrue);
      expect(record.canBanUsers(), isFalse);
      expect(record.canManageAdmins(), isFalse);
    });
  });
}

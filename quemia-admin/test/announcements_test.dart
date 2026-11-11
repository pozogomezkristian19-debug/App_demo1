// Avisos: publicar, activar/desactivar y eliminar, con permiso.

import 'package:flutter_test/flutter_test.dart';
import 'package:quemia_admin/models.dart';
import 'package:quemia_admin/repositories.dart';

import 'test_data.dart';

AdminService serviceFor(AdminRecord me) => AdminService(
  me: me,
  users: FakeUsersRepository(),
  admins: FakeAdminsRepository(),
  settings: FakeSettingsRepository(),
  announcements: FakeAnnouncementsRepository(seedAnnouncements()),
);

void main() {
  group('avisos', () {
    test('publicar un aviso lo guarda activo y primero en la lista', () async {
      final service = serviceFor(ownerRecord());
      final created = await service.publishAnnouncement(
        title: 'Torneo de Química',
        body: 'Este viernes, ¡no faltes!',
      );
      expect(created.active, isTrue);
      expect(created.createdBy, ownerEmail);

      final list = await service.announcements.listAnnouncements();
      expect(list.length, 3);
      expect(list.first.title, 'Torneo de Química');
    });

    test('título o mensaje vacío no se publica', () async {
      final service = serviceFor(ownerRecord());
      await expectLater(
        service.publishAnnouncement(title: '  ', body: 'Algo'),
        throwsArgumentError,
      );
      await expectLater(
        service.publishAnnouncement(title: 'Algo', body: ''),
        throwsArgumentError,
      );
      expect((await service.announcements.listAnnouncements()).length, 2);
    });

    test('desactivar y eliminar un aviso', () async {
      final service = serviceFor(ownerRecord());
      await service.setAnnouncementActive('ann-1', false);
      var list = await service.announcements.listAnnouncements();
      expect(list.firstWhere((a) => a.id == 'ann-1').active, isFalse);

      await service.deleteAnnouncement('ann-1');
      list = await service.announcements.listAnnouncements();
      expect(list.length, 1);
      expect(list.map((a) => a.id), isNot(contains('ann-1')));
    });

    test('admin sin manageAdmins NO puede publicar avisos', () async {
      final service = serviceFor(readOnlyAdminRecord());
      await expectLater(
        service.publishAnnouncement(title: 'X', body: 'Y'),
        throwsA(isA<PermissionDenied>()),
      );
      await expectLater(
        service.setAnnouncementActive('ann-1', false),
        throwsA(isA<PermissionDenied>()),
      );
      await expectLater(
        service.deleteAnnouncement('ann-1'),
        throwsA(isA<PermissionDenied>()),
      );
    });
  });
}

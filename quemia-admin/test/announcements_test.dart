// Avisos: publicar, activar/desactivar y eliminar, con permiso.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quemia_admin/models.dart';
import 'package:quemia_admin/repositories.dart';
import 'package:quemia_admin/screens.dart';

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

    test('publicar con push guarda sendPush en el aviso', () async {
      final service = serviceFor(ownerRecord());
      final created = await service.publishAnnouncement(
        title: 'Torneo de Química',
        body: 'Este viernes, ¡no faltes!',
        sendPush: true,
      );
      expect(created.sendPush, isTrue);
      final list = await service.announcements.listAnnouncements();
      expect(list.first.sendPush, isTrue);
    });

    test('publicar sin push deja sendPush en falso', () async {
      final service = serviceFor(ownerRecord());
      final created = await service.publishAnnouncement(
        title: 'Torneo de Química',
        body: 'Este viernes, ¡no faltes!',
      );
      expect(created.sendPush, isFalse);
    });

    testWidgets('los dos botones publican con el push que les toca', (
      tester,
    ) async {
      // Superficie alta: la lista de avisos es un ListView y la tarjeta con
      // «Enviado como push» solo se construye si entra en la pantalla.
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final announcements = FakeAnnouncementsRepository(seedAnnouncements());
      final service = AdminService(
        me: ownerRecord(),
        users: FakeUsersRepository(),
        admins: FakeAdminsRepository(),
        settings: FakeSettingsRepository(),
        announcements: announcements,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: quemiaAdminTheme(),
          home: Scaffold(
            body: AnnouncementsScreen(
              service: service,
              announcements: announcements,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Torneo');
      await tester.enterText(
        find.byType(TextField).at(1),
        'Este viernes, ¡no faltes!',
      );
      await tester.tap(find.text('Publicar y avisar a todos'));
      await tester.pumpAndSettle();
      expect(find.text('Aviso publicado y enviado a todos.'), findsOneWidget);
      var list = await announcements.listAnnouncements();
      expect(list.first.sendPush, isTrue);
      expect(list.first.title, 'Torneo');
      // Dejar que el primer aviso desaparezca: el segundo se encola detrás.
      await tester.pump(const Duration(seconds: 5));

      await tester.enterText(find.byType(TextField).at(0), 'Mantenimiento');
      await tester.enterText(find.byType(TextField).at(1), 'El domingo.');
      await tester.tap(find.text('Publicar aviso'));
      await tester.pumpAndSettle();
      expect(find.text('Aviso publicado para todos.'), findsOneWidget);
      list = await announcements.listAnnouncements();
      expect(list.first.sendPush, isFalse);
      expect(list.first.title, 'Mantenimiento');
      expect(find.text('Enviado como push'), findsOneWidget);
    });
  });
}

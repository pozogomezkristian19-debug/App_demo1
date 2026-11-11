// Reportes: lista (abiertos primero) y marcar como arreglado.

import 'package:flutter_test/flutter_test.dart';
import 'package:quemia_admin/models.dart';
import 'package:quemia_admin/repositories.dart';

import 'test_data.dart';

AdminService serviceFor(AdminRecord me) => AdminService(
  me: me,
  users: FakeUsersRepository(),
  admins: FakeAdminsRepository(),
  settings: FakeSettingsRepository(),
  reports: FakeReportsRepository(seedReports()),
);

void main() {
  group('reportes', () {
    test('lista: abiertos primero, más recientes primero', () async {
      final service = serviceFor(ownerRecord());
      final list = await service.reports.listReports();
      expect(list.length, 6);
      expect(list.where((r) => !r.isFixed).length, 5);
      expect(list.take(5).every((r) => !r.isFixed), isTrue);
      expect(list.last.isFixed, isTrue);
      expect(list.first.id, 'rep-1'); // el abierto más reciente (5 h)
    });

    test('marcar como arreglado cambia el estado y reordena', () async {
      final service = serviceFor(ownerRecord());
      final report = (await service.reports.listReports()).first;
      await service.markReportFixed(report);
      final list = await service.reports.listReports();
      expect(list.firstWhere((r) => r.id == report.id).isFixed, isTrue);
      // Ya no está entre los abiertos.
      expect(list.first.isFixed, isFalse);
      expect(list.where((r) => !r.isFixed).length, 4);
    });

    test('admin sin manageAdmins NO puede marcar reportes', () async {
      final service = serviceFor(readOnlyAdminRecord());
      final report = (await service.reports.listReports()).first;
      await expectLater(
        service.markReportFixed(report),
        throwsA(isA<PermissionDenied>()),
      );
      final after = (await service.reports.listReports()).first;
      expect(after.isFixed, isFalse);
    });
  });
}

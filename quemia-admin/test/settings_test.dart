// Ajustes remotos (settings/app): lectura con valores por defecto y guardado.

import 'package:flutter_test/flutter_test.dart';
import 'package:quemia_admin/models.dart';
import 'package:quemia_admin/repositories.dart';

import 'test_data.dart';

void main() {
  group('ajustes remotos', () {
    test(
      'sin documento, se leen los valores por defecto de Quemia 6.x',
      () async {
        final settings = FakeSettingsRepository();
        final loaded = await settings.load();
        expect(loaded.passThreshold, 4);
        expect(loaded.pointsEasyGain, 3);
        expect(loaded.pointsEasyLoss, -5);
        expect(loaded.pointsMediumGain, 5);
        expect(loaded.pointsMediumLoss, -8);
        expect(loaded.pointsHardGain, 8);
        expect(loaded.pointsHardLoss, -12);
        expect(loaded.maxLives, 5);
      },
    );

    test('guardar y volver a leer devuelve los nuevos valores', () async {
      final settings = FakeSettingsRepository();
      await settings.save(
        const RemoteSettings(
          passThreshold: 3,
          pointsEasyGain: 4,
          pointsEasyLoss: -4,
          maxLives: 4,
        ),
      );
      final loaded = await settings.load();
      expect(loaded.passThreshold, 3);
      expect(loaded.pointsEasyGain, 4);
      expect(loaded.pointsEasyLoss, -4);
      expect(loaded.pointsMediumGain, 5); // no tocado, sigue el defecto
      expect(loaded.maxLives, 4);
    });

    test('el servicio valida antes de guardar', () async {
      final service = AdminService(
        me: ownerRecord(),
        users: FakeUsersRepository(),
        admins: FakeAdminsRepository(),
        settings: FakeSettingsRepository(),
      );
      await expectLater(
        service.saveSettings(const RemoteSettings(passThreshold: 0)),
        throwsArgumentError,
      );
      await expectLater(
        service.saveSettings(const RemoteSettings(passThreshold: 6)),
        throwsArgumentError,
      );
      await expectLater(
        service.saveSettings(const RemoteSettings(maxLives: 0)),
        throwsArgumentError,
      );
      // Valores válidos sí se guardan y quedan persistidos en el fake.
      await service.saveSettings(const RemoteSettings(passThreshold: 5));
      expect((await service.settings.load()).passThreshold, 5);
    });

    test('admin sin manageAdmins NO puede guardar ajustes', () async {
      final service = AdminService(
        me: readOnlyAdminRecord(),
        users: FakeUsersRepository(),
        admins: FakeAdminsRepository(),
        settings: FakeSettingsRepository(),
      );
      await expectLater(
        service.saveSettings(const RemoteSettings(passThreshold: 2)),
        throwsA(isA<PermissionDenied>()),
      );
      expect((await service.settings.load()).passThreshold, 4);
    });

    test('fromMap tolera un documento parcial', () {
      final s = RemoteSettings.fromMap({'passThreshold': 2});
      expect(s.passThreshold, 2);
      expect(s.maxLives, 5);
      expect(s.pointsHardGain, 8);
    });
  });
}

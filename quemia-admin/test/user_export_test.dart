import 'package:flutter_test/flutter_test.dart';
import 'package:quemia_admin/models.dart';
import 'package:quemia_admin/user_export.dart';

AppUser testUser({
  String username = 'Ana',
  String id = 'uid1',
  DateTime? joinedAt,
  DateTime? lastActive,
  int levelsBachPassed = 3,
  int levelsUniPassed = 2,
  int points = 150,
  int streak = 7,
  String track = 'bach',
  String appVersion = '7.0',
  bool banned = false,
  String bannedReason = '',
}) {
  return AppUser(
    id: id,
    username: username,
    joinedAt: joinedAt ?? DateTime(2026, 10, 5, 9, 15),
    lastActive: lastActive ?? DateTime(2026, 11, 12, 20, 45),
    levelsBachPassed: levelsBachPassed,
    levelsUniPassed: levelsUniPassed,
    points: points,
    streak: streak,
    track: track,
    appVersion: appVersion,
    banned: banned,
    bannedReason: bannedReason,
  );
}

void main() {
  group('buildUsersCsv', () {
    test('cabecera exacta', () {
      expect(
        buildUsersCsv(<AppUser>[]),
        '\uFEFF'
        'Nombre;UID;Niveles Bachillerato;Niveles Universidad;Niveles totales;'
        'Puntos;Racha (días);Última actividad;Se unió;Pista;Versión;Baneado;'
        'Motivo del baneo',
      );
    });

    test('una fila exacta con fechas fijas', () {
      final csv = buildUsersCsv(<AppUser>[testUser()]);
      final lines = csv.split('\n');
      expect(lines, hasLength(2));
      expect(
        lines[1],
        'Ana;uid1;3;2;5;150;7;2026-11-12 20:45;2026-10-05 09:15;'
        'Bachillerato;7.0;No;',
      );
    });

    test('escapa nombre con ; y comillas', () {
      final csv = buildUsersCsv(
        <AppUser>[testUser(username: 'Ana; "La" Química')],
      );
      final lines = csv.split('\n');
      expect(
        lines[1],
        '"Ana; ""La"" Química";uid1;3;2;5;150;7;2026-11-12 20:45;'
        '2026-10-05 09:15;Bachillerato;7.0;No;',
      );
    });

    test('lista vacía devuelve solo la cabecera', () {
      final csv = buildUsersCsv(<AppUser>[]);
      expect(csv.split('\n'), hasLength(1));
      expect(csv, '\uFEFF$usersCsvHeader');
    });

    test('baneado Sí con su motivo', () {
      final csv = buildUsersCsv(
        <AppUser>[
          testUser(banned: true, bannedReason: 'Trampa en duelos'),
        ],
      );
      final lines = csv.split('\n');
      expect(
        lines[1],
        'Ana;uid1;3;2;5;150;7;2026-11-12 20:45;2026-10-05 09:15;'
        'Bachillerato;7.0;Sí;Trampa en duelos',
      );
    });

    test('BOM presente al inicio', () {
      final csv = buildUsersCsv(<AppUser>[testUser()]);
      expect(csv.codeUnitAt(0), 0xFEFF);
      expect(csv, startsWith('\uFEFF'));
    });

    test('pista Universidad para track uni', () {
      final csv = buildUsersCsv(<AppUser>[testUser(track: 'uni')]);
      expect(csv.split('\n')[1], contains(';Universidad;'));
    });
  });

  group('usersCsvFileName', () {
    test('formato quemia-usuarios-AAAAMMDD.csv', () {
      expect(
        usersCsvFileName(DateTime(2026, 11, 12)),
        'quemia-usuarios-20261112.csv',
      );
    });
  });
}

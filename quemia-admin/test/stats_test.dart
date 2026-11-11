// Estadísticas del Panel calculadas de los 12 usuarios de ejemplo y los
// reportes de ejemplo.

import 'package:flutter_test/flutter_test.dart';
import 'package:quemia_admin/stats.dart';

import 'test_data.dart';

void main() {
  group('estadísticas', () {
    test('totales y activos', () {
      final stats = computeStats(users: seedUsers(), reports: seedReports());
      expect(stats.totalUsers, 12);
      expect(stats.activeToday, 8);
      expect(stats.avgLevel, closeTo(71 / 12, 0.001));
    });

    test('activos por día (tramos de 24 h, últimos 7 días)', () {
      final stats = computeStats(users: seedUsers(), reports: seedReports());
      // Hoy: kristian, laura, miguel, valeria, yordanis, lucia, andres, rosa.
      // Ayer: sofia. Hace 2 d: camila. Hace 3 d: daniel. Pedro, hace 10 d,
      // queda fuera de la ventana de 7 días.
      expect(stats.activePerDay, [8, 1, 1, 1, 0, 0, 0]);
    });

    test('nivel donde más se atascan: Bachillerato Nivel 6 (4 usuarios)', () {
      final stats = computeStats(users: seedUsers(), reports: seedReports());
      expect(stats.stuckLevelLabel, 'Bachillerato · Nivel 6');
      expect(stats.stuckCount, 4);
    });

    test('preguntas con más fallos: las más reportadas y abiertas', () {
      final stats = computeStats(users: seedUsers(), reports: seedReports());
      expect(stats.mostFailed.length, 2);
      expect(stats.mostFailed[0].questionId, 'est-3');
      expect(stats.mostFailed[0].count, 3);
      expect(stats.mostFailed[1].questionId, 'red-1');
      expect(stats.mostFailed[1].count, 2);
      // El reporte arreglado (est-1) no cuenta.
      expect(
        stats.mostFailed.map((f) => f.questionId),
        isNot(contains('est-1')),
      );
    });

    test('versiones de la app', () {
      final stats = computeStats(users: seedUsers(), reports: seedReports());
      expect(stats.versionCounts.length, 2);
      expect(stats.versionCounts[0].key, '6.3');
      expect(stats.versionCounts[0].value, 9);
      expect(stats.versionCounts[1].key, '6.2');
      expect(stats.versionCounts[1].value, 3);
    });

    test('sin usuarios no se rompe', () {
      final stats = computeStats(users: [], reports: []);
      expect(stats.totalUsers, 0);
      expect(stats.activePerDay, [0, 0, 0, 0, 0, 0, 0]);
      expect(stats.stuckLevelLabel, '');
      expect(stats.mostFailed, isEmpty);
      expect(stats.versionCounts, isEmpty);
    });
  });
}

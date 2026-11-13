// Estadísticas del Panel calculadas de los 12 usuarios de ejemplo y los
// reportes de ejemplo.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quemia_admin/models.dart';
import 'package:quemia_admin/repositories.dart';
import 'package:quemia_admin/screens.dart';
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

  group('racha en riesgo', () {
    final now = DateTime(2026, 11, 13, 10, 0);

    AppUser riskUser(
      String username,
      DateTime lastActive,
      int streak, {
      bool banned = false,
    }) => AppUser(
      id: 'u-$username',
      username: username,
      joinedAt: now.subtract(const Duration(days: 30)),
      lastActive: lastActive,
      levelsBachPassed: 3,
      levelsUniPassed: 0,
      points: 50,
      streak: streak,
      track: 'bach',
      appVersion: '6.3',
      banned: banned,
    );

    test('racha con última entrada hoy no está en riesgo', () {
      final users = [
        riskUser('ana', DateTime(2026, 11, 13, 8, 0), 5),
      ];
      expect(streakAtRisk(users, now: now), isEmpty);
    });

    test('racha con última entrada ayer sí, con 1 día sin entrar', () {
      final users = [
        riskUser('ana', DateTime(2026, 11, 12, 20, 0), 5),
      ];
      final atRisk = streakAtRisk(users, now: now);
      expect(atRisk.length, 1);
      expect(atRisk.first.user.username, 'ana');
      expect(atRisk.first.daysAway, 1);
    });

    test('racha en 0 no está en riesgo aunque lleve días sin entrar', () {
      final users = [
        riskUser('ana', DateTime(2026, 11, 5, 9, 0), 0),
      ];
      expect(streakAtRisk(users, now: now), isEmpty);
    });

    test('ordenados por días sin entrar, del que más lleva al que menos', () {
      final users = [
        riskUser('ana', DateTime(2026, 11, 12, 9, 0), 2),
        riskUser('luis', DateTime(2026, 11, 8, 9, 0), 7),
        riskUser('marta', DateTime(2026, 11, 10, 9, 0), 4),
      ];
      final atRisk = streakAtRisk(users, now: now);
      expect(
        atRisk.map((e) => e.user.username),
        ['luis', 'marta', 'ana'],
      );
      expect(atRisk.map((e) => e.daysAway), [5, 3, 1]);
    });

    test('un baneado con racha también aparece (su ficha se revisa igual)', () {
      final users = [
        riskUser('ana', DateTime(2026, 11, 11, 9, 0), 3, banned: true),
      ];
      expect(streakAtRisk(users, now: now).length, 1);
    });
  });

  group('racha en riesgo (panel)', () {
    testWidgets('el Panel muestra la sección con los usuarios en riesgo', (
      tester,
    ) async {
      // Superficie alta: la sección queda bajo el pliegue del Panel.
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: quemiaAdminTheme(),
          home: Scaffold(
            body: DashboardScreen(
              users: FakeUsersRepository(seedUsers()),
              reports: FakeReportsRepository(seedReports()),
              me: ownerRecord(),
              onNavigate: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('RACHA EN RIESGO'), findsOneWidget);
      // Sofía (26 h sin entrar, racha 12) y Camila (48 h, racha 1) están
      // en riesgo a cualquier hora del día.
      expect(find.textContaining('sin entrar desde hace'), findsWidgets);
    });
  });
}

// Estadísticas del Panel, calculadas solo con los datos que ya existen en
// Firestore. Cálculo puro (sin Firebase) para poder probarlo con fakes.
//
// Fuentes:
//  - Activos por día y versiones de la app: colección 'users' (lastActive,
//    appVersion). Los días se cuentan en tramos de 24 h (día 0 = últimas
//    24 h), determinista en tests.
//  - Nivel donde más se atascan: también de 'users'. Es un PROXY: el nivel
//    actual de cada usuario es (niveles superados en su pista + 1); el más
//    repetido es donde más usuarios están parados. Cuando la app principal
//    envíe telemetría de intentos por nivel, este cálculo se puede afinar
//    con intentos fallidos reales.
//  - Preguntas con más fallos: PROXY a partir de la colección 'reports':
//    las preguntas más reportadas son las que más problemas dan. Cuando la
//    app principal envíe intentos fallidos por pregunta, se sustituye por
//    el conteo real.

import 'models.dart';

class FailedQuestion {
  const FailedQuestion({
    required this.questionId,
    required this.questionText,
    required this.count,
  });

  final String questionId;
  final String questionText;
  final int count;
}

class AdminStats {
  const AdminStats({
    required this.totalUsers,
    required this.activeToday,
    required this.avgLevel,
    required this.activePerDay,
    required this.stuckLevelLabel,
    required this.stuckCount,
    required this.mostFailed,
    required this.versionCounts,
  });

  final int totalUsers;
  final int activeToday;
  final double avgLevel;

  /// Activos por tramo de 24 h, 7 días: [0] = últimas 24 h, [6] = hace 6 días.
  final List<int> activePerDay;

  /// Etiqueta del nivel con más usuarios parados, p. ej.
  /// "Bachillerato · Nivel 6". Vacía si no hay usuarios.
  final String stuckLevelLabel;
  final int stuckCount;

  /// Preguntas más reportadas (más fallos), ordenadas de más a menos.
  final List<FailedQuestion> mostFailed;

  /// Versiones de la app instaladas, ordenadas de más a menos uso.
  /// Cada entrada es (versión, nº de usuarios).
  final List<MapEntry<String, int>> versionCounts;
}

/// Usuarios a punto de perder la racha: tienen racha mayor que 0 pero no
/// han entrado hoy (última actividad anterior al día actual). Se ordenan
/// por días sin entrar, de más a menos: el primero es el más urgente.
/// Cálculo puro (sin Firebase) para poder probarlo con fakes. Los días se
/// cuentan por fecha de calendario (no por tramos de 24 h): entrar ayer y
/// no entrar hoy ya es 1 día sin entrar.
List<({AppUser user, int daysAway})> streakAtRisk(
  List<AppUser> users, {
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final today = DateTime(ref.year, ref.month, ref.day);
  final atRisk = <({AppUser user, int daysAway})>[];
  for (final u in users) {
    if (u.streak <= 0) continue;
    final lastDay = DateTime(
      u.lastActive.year,
      u.lastActive.month,
      u.lastActive.day,
    );
    final daysAway = today.difference(lastDay).inDays;
    if (daysAway >= 1) atRisk.add((user: u, daysAway: daysAway));
  }
  atRisk.sort((a, b) => b.daysAway.compareTo(a.daysAway));
  return atRisk;
}

AdminStats computeStats({
  required List<AppUser> users,
  List<QuestionReport> reports = const [],
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();

  // Activos por día (tramos de 24 h).
  final activePerDay = List<int>.filled(7, 0);
  var activeToday = 0;
  for (final u in users) {
    final days = ref.difference(u.lastActive).inHours ~/ 24;
    if (days >= 0 && days < 7) activePerDay[days]++;
    if (u.activeToday) activeToday++;
  }

  final avgLevel = users.isEmpty
      ? 0.0
      : users.map((u) => u.totalLevelsPassed).reduce((a, b) => a + b) /
            users.length;

  // Nivel donde más se atascan (proxy por progreso): nivel actual =
  // superados en su pista + 1.
  String stuckLabel = '';
  var stuckCount = 0;
  if (users.isNotEmpty) {
    final counts = <String, int>{};
    for (final u in users) {
      final passed = u.track == 'uni' ? u.levelsUniPassed : u.levelsBachPassed;
      final label =
          '${u.track == 'uni' ? 'Universidad' : 'Bachillerato'} · Nivel ${passed + 1}';
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final top = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    stuckLabel = top.first.key;
    stuckCount = top.first.value;
  }

  // Preguntas con más fallos (proxy: más reportadas).
  final reportCounts = <String, int>{};
  final reportText = <String, String>{};
  for (final r in reports) {
    if (r.isFixed) continue;
    reportCounts[r.questionId] = (reportCounts[r.questionId] ?? 0) + 1;
    if (r.questionText.isNotEmpty) {
      reportText[r.questionId] = r.questionText;
    }
  }
  final mostFailed =
      reportCounts.entries
          .map(
            (e) => FailedQuestion(
              questionId: e.key,
              questionText: reportText[e.key] ?? e.key,
              count: e.value,
            ),
          )
          .toList()
        ..sort((a, b) => b.count.compareTo(a.count));

  // Versiones de la app.
  final versions = <String, int>{};
  for (final u in users) {
    versions[u.appVersion] = (versions[u.appVersion] ?? 0) + 1;
  }
  final versionCounts = versions.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return AdminStats(
    totalUsers: users.length,
    activeToday: activeToday,
    avgLevel: avgLevel,
    activePerDay: activePerDay,
    stuckLevelLabel: stuckLabel,
    stuckCount: stuckCount,
    mostFailed: mostFailed,
    versionCounts: versionCounts,
  );
}

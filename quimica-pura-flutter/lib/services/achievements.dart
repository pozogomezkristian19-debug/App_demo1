// Logros y medallas (v5). Se muestran en Mis estadísticas con su estado
// (desbloqueado o bloqueado). La comprobación es pura lógica sobre
// ProgressService, así se puede probar sin Flutter.

import '../widgets/lucide_icons.dart';

import 'progress.dart';

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
  });

  final String id;
  final String title;
  final String body;
  final LucideIconData icon;
}

const List<Achievement> allAchievements = [
  Achievement(
    id: 'firstLevel',
    title: 'Primer nivel',
    body: 'Pasa tu primer nivel con 4 de 5.',
    icon: LucideIcons.target,
  ),
  Achievement(
    id: 'topicDone',
    title: 'Tema completado',
    body: 'Completa todos los niveles de un tema.',
    icon: LucideIcons.trophy,
  ),
  Achievement(
    id: 'mixedPass',
    title: 'Examen mixto superado',
    body: 'Pasa el examen final con 80 % o más.',
    icon: LucideIcons.graduationCap,
  ),
  Achievement(
    id: 'streak3',
    title: 'Racha de 3 días',
    body: 'Practica 3 días seguidos.',
    icon: LucideIcons.flame,
  ),
  Achievement(
    id: 'streak7',
    title: 'Racha de 7 días',
    body: 'Practica una semana seguida.',
    icon: LucideIcons.flame,
  ),
  Achievement(
    id: 'streak30',
    title: 'Racha de 30 días',
    body: 'Practica un mes seguido.',
    icon: LucideIcons.flame,
  ),
  Achievement(
    id: 'correct100',
    title: '100 aciertos',
    body: 'Acierta 100 preguntas en esta versión.',
    icon: LucideIcons.circleCheck,
  ),
  Achievement(
    id: 'correct500',
    title: '500 aciertos',
    body: 'Acierta 500 preguntas en esta versión.',
    icon: LucideIcons.circleCheck,
  ),
  Achievement(
    id: 'correct1000',
    title: '1000 aciertos',
    body: 'Acierta 1000 preguntas en esta versión.',
    icon: LucideIcons.circleCheck,
  ),
  Achievement(
    id: 'reviewClear',
    title: 'Repaso al día',
    body: 'Deja la lista de errores en cero.',
    icon: LucideIcons.rotateCcw,
  ),
  Achievement(
    id: 'qotd7',
    title: 'Pregunta del día ×7',
    body: 'Contesta la pregunta del día 7 días distintos.',
    icon: LucideIcons.calendar,
  ),
];

/// ¿Está desbloqueado este logro? `trackTopics` son los temas de la
/// pista actual, en orden.
bool achievementUnlocked(
    String id, ProgressService p, List<String> trackTopics) {
  switch (id) {
    case 'firstLevel':
      // Pasado = desbloqueo (auditoría A5, fix5 ronda #5): la nota
      // guardada es PONDERADA y un 4/5 fallando la difícil guarda
      // 76 %, así que la nota no dice si se pasó; unlockedLevels
      // sí (cualquier tema con el nivel 2 abierto = un nivel
      // pasado por conteo, igual que el desbloqueo).
      return p.unlockedLevels.values.any((u) => u > 1);
    case 'topicDone':
      return trackTopics.any(p.isTopicComplete);
    case 'mixedPass':
      return p.bestScore('mixto') >= 80;
    case 'streak3':
      return p.streakBest >= 3;
    case 'streak7':
      return p.streakBest >= 7;
    case 'streak30':
      return p.streakBest >= 30;
    case 'correct100':
      return p.totalCorrect >= 100;
    case 'correct500':
      return p.totalCorrect >= 500;
    case 'correct1000':
      return p.totalCorrect >= 1000;
    case 'reviewClear':
      return p.everFailed && p.failedCount == 0;
    case 'qotd7':
      return p.qotdDays.length >= 7;
    default:
      return false;
  }
}

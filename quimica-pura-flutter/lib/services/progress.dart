// Progreso en memoria (sin dependencias externas).
// Se mantiene durante la sesión de la app. Si en el futuro se quiere
// persistencia entre visitas, aquí es donde se conectaría
// SharedPreferences, sin tocar las pantallas.

class ProgressService {
  ProgressService._();
  static final ProgressService instance = ProgressService._();

  final Set<String> masteredTopics = <String>{};
  final Map<String, int> bestScores = <String, int>{}; // testId -> mejor %

  bool isMastered(String slug) => masteredTopics.contains(slug);

  void toggleMastered(String slug) {
    if (masteredTopics.contains(slug)) {
      masteredTopics.remove(slug);
    } else {
      masteredTopics.add(slug);
    }
  }

  int bestScore(String testId) => bestScores[testId] ?? 0;

  void recordScore(String testId, int percent) {
    if (percent > bestScore(testId)) bestScores[testId] = percent;
  }
}

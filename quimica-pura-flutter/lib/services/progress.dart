// Progreso con memoria: todo se guarda en el teléfono con
// SharedPreferences (igual que el nombre, el género y el tema claro/oscuro).
// Al cerrar y volver a abrir la app, el progreso sigue ahí:
// mejor puntuación por test y por nivel, temas dominados, nivel
// desbloqueado por tema, aciertos por tema y la lista de errores.
//
// Se carga una vez en main() con ProgressService.load(), junto con
// UserPrefs.load(). Las pantallas siguen usando la misma API de antes.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Una pregunta fallada, guardada para repasarla después.
/// - Banco: id 'bank:<tema>:<texto de la pregunta>'.
/// - Generada: id 'gen:<tipo>:<forma>:<parámetros>' (se reconstruye
///   exactamente con el generador).
class FailedEntry {
  const FailedEntry({
    required this.id,
    required this.topic,
    required this.question,
  });

  final String id;
  final String topic;
  final String question; // texto de la pregunta

  Map<String, dynamic> toJson() =>
      {'id': id, 'topic': topic, 'question': question};

  factory FailedEntry.fromJson(Map<String, dynamic> json) => FailedEntry(
        id: json['id'] as String,
        topic: json['topic'] as String,
        question: json['question'] as String,
      );
}

class ProgressService {
  ProgressService._();
  static final ProgressService instance = ProgressService._();

  /// Pista (track) actual: 'uni' (Universidad) o 'bach' (Bachillerato).
  /// Cada pista tiene sus propias claves, así el progreso nunca se mezcla.
  /// La pista 'uni' conserva las claves históricas sin prefijo, para que
  /// el progreso ya guardado siga intacto.
  static const String trackUni = 'uni';
  static const String trackBach = 'bach';
  static String track = trackUni;

  /// Clave de guardado para un sufijo, según la pista actual.
  static String _key(String suffix) =>
      track == trackBach ? 'melli_progress_bach_$suffix' : 'melli_progress_$suffix';

  SharedPreferences? _prefs;

  final Set<String> masteredTopics = <String>{};
  final Map<String, int> bestScores = <String, int>{}; // testId -> mejor %
  final Map<String, int> unlockedLevels = <String, int>{}; // tema -> nivel
  final Map<String, int> _topicCorrect = <String, int>{};
  final Map<String, int> _topicTotal = <String, int>{};
  final List<FailedEntry> _failed = <FailedEntry>[];

  /// Carga el progreso guardado. Llamar en main() antes de runApp.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    instance._prefs = prefs;
    instance._readAll(prefs);
  }

  /// Cambia de pista y vuelve a leer el progreso guardado de esa pista.
  static Future<void> setTrack(String t) async {
    if (t != trackBach && t != trackUni) return;
    if (t == track) return;
    track = t;
    final prefs = instance._prefs ?? await SharedPreferences.getInstance();
    instance._prefs = prefs;
    instance._readAll(prefs);
  }

  void _readAll(SharedPreferences prefs) {
    masteredTopics
      ..clear()
      ..addAll(prefs.getStringList(_key('mastered')) ?? <String>[]);
    bestScores
      ..clear()
      ..addAll(_readIntMap(prefs.getString(_key('best'))));
    unlockedLevels
      ..clear()
      ..addAll(_readIntMap(prefs.getString(_key('levels'))));
    _topicCorrect.clear();
    _topicTotal.clear();
    final stats = _readJson(prefs.getString(_key('stats')));
    stats.forEach((topic, v) {
      if (v is Map) {
        _topicCorrect[topic] = (v['c'] as num?)?.toInt() ?? 0;
        _topicTotal[topic] = (v['t'] as num?)?.toInt() ?? 0;
      }
    });
    _failed
      ..clear()
      ..addAll(_readFailed(prefs.getString(_key('failed'))));
  }

  static Map<String, dynamic> _readJson(String? raw) {
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Map<String, int> _readIntMap(String? raw) {
    final out = <String, int>{};
    _readJson(raw).forEach((k, v) {
      if (v is num) out[k] = v.toInt();
    });
    return out;
  }

  static List<FailedEntry> _readFailed(String? raw) {
    if (raw == null || raw.isEmpty) return <FailedEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <FailedEntry>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(FailedEntry.fromJson)
          .toList();
    } catch (_) {
      return <FailedEntry>[];
    }
  }

  void _save() {
    final prefs = _prefs;
    if (prefs == null) return; // aún no se cargó: nada que guardar
    prefs.setStringList(_key('mastered'), masteredTopics.toList());
    prefs.setString(_key('best'), jsonEncode(bestScores));
    prefs.setString(_key('levels'), jsonEncode(unlockedLevels));
    final stats = <String, Map<String, int>>{};
    for (final topic in _topicTotal.keys) {
      stats[topic] = {
        'c': _topicCorrect[topic] ?? 0,
        't': _topicTotal[topic] ?? 0,
      };
    }
    prefs.setString(_key('stats'), jsonEncode(stats));
    prefs.setString(
        _key('failed'), jsonEncode(_failed.map((e) => e.toJson()).toList()));
  }

  // ---- Temas dominados (Aprender) ----

  bool isMastered(String slug) => masteredTopics.contains(slug);

  void toggleMastered(String slug) {
    if (masteredTopics.contains(slug)) {
      masteredTopics.remove(slug);
    } else {
      masteredTopics.add(slug);
    }
    _save();
  }

  // ---- Mejor puntuación por test / nivel ----

  int bestScore(String testId) => bestScores[testId] ?? 0;

  void recordScore(String testId, int percent) {
    if (percent > bestScore(testId)) {
      bestScores[testId] = percent;
      _save();
    }
  }

  // ---- Niveles por tema ----

  /// Nivel más alto desbloqueado del tema. El nivel 1 siempre está abierto.
  int unlockedLevel(String topic) => unlockedLevels[topic] ?? 1;

  /// Marca el nivel como superado y desbloquea el siguiente.
  void recordLevelPass(String topic, int level) {
    final next = level + 1;
    if (next > unlockedLevel(topic)) {
      unlockedLevels[topic] = next;
      _save();
    }
  }

  // ---- Aciertos por tema (sistema adaptativo) ----

  /// Registra una respuesta de un tema. Se guarda en cada respuesta.
  void recordAnswer(String topic, bool correct) {
    _topicTotal[topic] = (_topicTotal[topic] ?? 0) + 1;
    if (correct) _topicCorrect[topic] = (_topicCorrect[topic] ?? 0) + 1;
    _save();
  }

  int topicCorrect(String topic) => _topicCorrect[topic] ?? 0;

  int topicTotal(String topic) => _topicTotal[topic] ?? 0;

  /// Precisión del tema (0.0 a 1.0) o null si aún no hay intentos.
  double? accuracy(String topic) {
    final total = _topicTotal[topic] ?? 0;
    if (total == 0) return null;
    return (_topicCorrect[topic] ?? 0) / total;
  }

  /// Temas ordenados del más débil al más fuerte. Sin intentos, un tema
  /// vale 0.5 (neutro); los temas con errores pendientes pesan más.
  List<String> weakestTopics(List<String> allTopics) {
    double score(String topic) {
      final acc = accuracy(topic) ?? 0.5;
      final failedHere = _failed.where((f) => f.topic == topic).length;
      return acc - 0.05 * (failedHere > 5 ? 5 : failedHere);
    }

    final sorted = List<String>.of(allTopics)
      ..sort((a, b) => score(a).compareTo(score(b)));
    return sorted;
  }

  // ---- Errores para repasar ----

  List<FailedEntry> get failedEntries => List.unmodifiable(_failed);

  int get failedCount => _failed.length;

  List<FailedEntry> failedForTopic(String topic) =>
      _failed.where((f) => f.topic == topic).toList();

  bool isFailed(String id) => _failed.any((f) => f.id == id);

  void addFailed(FailedEntry entry) {
    if (isFailed(entry.id)) return;
    _failed.add(entry);
    _save();
  }

  void removeFailed(String id) {
    final before = _failed.length;
    _failed.removeWhere((f) => f.id == id);
    if (_failed.length != before) _save();
  }
}

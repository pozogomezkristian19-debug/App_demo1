// Progreso con memoria: todo se guarda en el teléfono con
// SharedPreferences (igual que el nombre, el género y el tema claro/oscuro).
// Al cerrar y volver a abrir la app, el progreso sigue ahí:
// mejor puntuación por test y por nivel, temas dominados, nivel
// desbloqueado por tema, aciertos por tema y la lista de errores.
//
// v5: además guarda los días de práctica (para la racha), los días en
// que se pasó un nivel (meta diaria), los días con pregunta del día
// contestada, y la fecha de cada error (repaso inteligente: los errores
// de días anteriores resurgen solos al día siguiente).
//
// Se carga una vez en main() con ProgressService.load(), junto con
// UserPrefs.load(). Las pantallas siguen usando la misma API de antes.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/questions.dart';
import 'points.dart';
import 'question_generator.dart';

/// Una pregunta fallada, guardada para repasarla después.
/// - Banco: id 'bank:<tema>:<texto de la pregunta>'.
/// - Generada: id 'gen:<tipo>:<forma>:<parámetros>' (se reconstruye
///   exactamente con el generador).
/// - `failedDate`: día en que se falló ('yyyy-MM-dd'), para el repaso
///   inteligente. Las entradas viejas (sin fecha) se tratan como
///   pendientes de repaso.
/// - `level`: nivel del tema en el que se falló (0 = no se sabe): el
///   repaso se organiza POR NIVEL, no en una lista global.
/// - `reviewStreak`: aciertos seguidos en el repaso de variantes de
///   esta entrada (hacen falta 3 para darla por superada).
class FailedEntry {
  const FailedEntry({
    required this.id,
    required this.topic,
    required this.question,
    this.failedDate,
    this.level = 0,
    this.reviewStreak = 0,
  });

  final String id;
  final String topic;
  final String question; // texto de la pregunta
  final String? failedDate; // 'yyyy-MM-dd' o null (entrada vieja)
  final int level;
  final int reviewStreak;

  Map<String, dynamic> toJson() => {
        'id': id,
        'topic': topic,
        'question': question,
        if (failedDate != null) 'd': failedDate,
        if (level != 0) 'l': level,
        if (reviewStreak != 0) 'rs': reviewStreak,
      };

  factory FailedEntry.fromJson(Map<String, dynamic> json) => FailedEntry(
        id: json['id'] as String,
        topic: json['topic'] as String,
        question: json['question'] as String,
        failedDate: json['d'] as String?,
        level: (json['l'] as num?)?.toInt() ?? 0,
        reviewStreak: (json['rs'] as num?)?.toInt() ?? 0,
      );

  FailedEntry copyWith({int? reviewStreak}) => FailedEntry(
        id: id,
        topic: topic,
        question: question,
        failedDate: failedDate,
        level: level,
        reviewStreak: reviewStreak ?? this.reviewStreak,
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

  /// Claves sin pista: la racha, la meta diaria y la pregunta del día
  /// son de la persona, no de la pista.
  static const _kPracticeDays = 'melli_progress_days';
  static const _kLevelPassDays = 'melli_progress_level_days';
  static const _kQotdDays = 'melli_progress_qotd_days';
  static const _kEverFailed = 'melli_progress_ever_failed';

  /// Saldo total de puntos (sin pista: los puntos son de la persona,
  /// no de la pista). Ver points.dart para la tabla por dificultad.
  static const _kPoints = 'melli_progress_points';

  /// Vidas (v6): cuántas quedan y de qué día son. Sin pista: las vidas
  /// son de la persona, no de la pista.
  static const _kLives = 'melli_progress_lives';
  static const _kLivesDate = 'melli_progress_lives_date';

  /// Búsquedas recientes (v6): las últimas 5 consultas, en orden.
  static const _kRecentSearches = 'melli_progress_recent_searches';

  /// Día en que se mostró el elemento del día como popup (v6): solo
  /// una vez al día, al abrir la app.
  static const _kElementDayShown = 'melli_progress_element_day_shown';

  SharedPreferences? _prefs;

  final Set<String> masteredTopics = <String>{};
  final Map<String, int> bestScores = <String, int>{}; // testId -> mejor %
  final Map<String, int> unlockedLevels = <String, int>{}; // tema -> nivel
  final Map<String, int> _topicCorrect = <String, int>{};
  final Map<String, int> _topicTotal = <String, int>{};
  final List<FailedEntry> _failed = <FailedEntry>[];

  /// Días ('yyyy-MM-dd') con al menos una respuesta contestada.
  final Set<String> practiceDays = <String>{};

  /// Días ('yyyy-MM-dd') en los que se pasó al menos un nivel.
  final Set<String> levelPassDays = <String>{};

  /// Días ('yyyy-MM-dd') con la pregunta del día contestada.
  final Set<String> qotdDays = <String>{};

  /// true desde la primera vez que se falla una pregunta (para el logro
  /// de "repaso al día": no vale empezar con cero errores).
  bool everFailed = false;

  /// Saldo total de puntos (puede bajar si se falla mucho).
  int _pointsBalance = 0;

  int get points => _pointsBalance;

  /// Suma (o resta, si delta es negativo) puntos al saldo total.
  void addPoints(int delta) {
    _pointsBalance += delta;
    _save();
  }

  // ---- Vidas (v6) ----

  /// Aviso de cambio de vidas: la AppBar escucha este notificador
  /// para actualizar el chip de vidas (corazón + número) sin tener
  /// que reconstruir toda la pantalla. Solo avisa, no cambia la
  /// lógica: las vidas se siguen guardando igual.
  static final ValueNotifier<int> livesNotifier = ValueNotifier<int>(0);

  static void _bumpLives() => livesNotifier.value++;

  int _livesLeft = 5;
  String? _livesDate;

  /// Vidas que quedan hoy (5 al empezar cada día nuevo).
  int get livesLeft {
    if (_livesDate != dateKey(DateTime.now())) return maxLives;
    return _livesLeft.clamp(0, maxLives);
  }

  /// ¿Se puede empezar un nivel hoy?
  bool get canStartLevel => livesLeft > 0;

  /// Cuándo se reponen las vidas (mañana), para el mensaje de 0 vidas.
  String get livesRefillLabel => 'mañana';

  /// Abandonar un nivel en curso cuesta 1 vida.
  void loseLifeOnAbandon() {
    final today = dateKey(DateTime.now());
    if (_livesDate != today) {
      _livesDate = today;
      _livesLeft = maxLives;
    }
    if (_livesLeft > 0) _livesLeft--;
    _save();
    _bumpLives();
  }

  /// Ganar un nivel COMPLETO restaura 1 vida, hasta el máximo de 5.
  /// Devuelve true si se restauró una vida (si ya tenía 5, no suma
  /// nada). Fallar un nivel terminado no quita ni devuelve vida: solo
  /// se llama cuando el nivel se aprueba.
  bool restoreLifeOnPass() {
    final today = dateKey(DateTime.now());
    if (_livesDate != today) {
      _livesDate = today;
      _livesLeft = maxLives;
      _save();
      _bumpLives();
      return false;
    }
    if (_livesLeft >= maxLives) return false;
    _livesLeft++;
    _save();
    _bumpLives();
    return true;
  }

  // ---- Búsquedas recientes (v6) ----

  final List<String> _recentSearches = <String>[];

  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  /// Guarda una consulta como reciente (sin duplicados, como mucho 5).
  void recordSearch(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    _recentSearches.remove(q);
    _recentSearches.insert(0, q);
    if (_recentSearches.length > 5) {
      _recentSearches.removeRange(5, _recentSearches.length);
    }
    _save();
  }

  // ---- Elemento del día como popup (v6) ----

  /// ¿Ya se mostró el popup del elemento del día hoy?
  bool get elementDayShownToday {
    final shown = _prefs?.getString(_kElementDayShown);
    return shown == dateKey(DateTime.now());
  }

  void markElementDayShown() {
    _prefs?.setString(_kElementDayShown, dateKey(DateTime.now()));
  }

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
    // Migración v6 (una sola vez): con la regla vieja (4/5 = 80 %) un
    // nivel pasado guardaba 80; con la nueva (nota sobre 5 > 4,0) el
    // aprobado empieza en 81. Sin esto, un nivel pasado con 80 se
    // vería como suspendido.
    for (final k in bestScores.keys.toList()) {
      if (k.startsWith('level:') && bestScores[k] == 80) {
        bestScores[k] = 81;
      }
    }
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
    // Datos sin pista: se leen igual en cualquier pista.
    practiceDays
      ..clear()
      ..addAll(prefs.getStringList(_kPracticeDays) ?? <String>[]);
    levelPassDays
      ..clear()
      ..addAll(prefs.getStringList(_kLevelPassDays) ?? <String>[]);
    qotdDays
      ..clear()
      ..addAll(prefs.getStringList(_kQotdDays) ?? <String>[]);
    everFailed = prefs.getBool(_kEverFailed) ?? false;
    _pointsBalance = prefs.getInt(_kPoints) ?? 0;
    _livesLeft = prefs.getInt(_kLives) ?? maxLives;
    _livesDate = prefs.getString(_kLivesDate);
    _recentSearches
      ..clear()
      ..addAll(prefs.getStringList(_kRecentSearches) ?? <String>[]);
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
    prefs.setStringList(_kPracticeDays, practiceDays.toList());
    prefs.setStringList(_kLevelPassDays, levelPassDays.toList());
    prefs.setStringList(_kQotdDays, qotdDays.toList());
    prefs.setBool(_kEverFailed, everFailed);
    prefs.setInt(_kPoints, _pointsBalance);
    prefs.setInt(_kLives, _livesLeft);
    if (_livesDate != null) prefs.setString(_kLivesDate, _livesDate!);
    prefs.setStringList(_kRecentSearches, _recentSearches);
  }

  // ---- Fechas y racha (lógica pura, comprobable sin Flutter) ----

  /// 'yyyy-MM-dd' de un día (hora local).
  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Racha actual: días seguidos con práctica, contando desde hoy si ya
  /// se practicó hoy, o desde ayer si todavía no.
  static int currentStreak(Set<String> days, DateTime today) {
    var streak = 0;
    var d = today;
    if (!days.contains(dateKey(d))) d = d.subtract(const Duration(days: 1));
    while (days.contains(dateKey(d))) {
      streak++;
      d = d.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Racha más larga de todas las guardadas.
  static int bestStreak(Set<String> days) {
    if (days.isEmpty) return 0;
    final sorted = days.toList()..sort();
    var best = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      final prev = DateTime.parse(sorted[i - 1]);
      final curr = DateTime.parse(sorted[i]);
      if (curr.difference(prev).inDays == 1) {
        run++;
        if (run > best) best = run;
      } else {
        run = 1;
      }
    }
    return best;
  }

  int get streakNow => currentStreak(practiceDays, DateTime.now());
  int get streakBest => bestStreak(practiceDays);

  /// Niveles pasados hoy (meta diaria: 1 nivel al día).
  int levelsPassedToday() =>
      levelPassDays.contains(dateKey(DateTime.now())) ? 1 : 0;

  /// ¿La meta diaria de hoy ya está hecha?
  bool get dailyGoalDone => levelsPassedToday() >= 1;

  // ---- Niveles por tema ----

  /// Niveles que tiene un tema: banco en grupos de 5 + 2 niveles extra
  /// solo con preguntas generadas (los temas sin generador — orgánica y
  /// laboratorio — solo tienen niveles de banco).
  static int levelCountForTopic(String topic) {
    final bank = allQuestions.where((q) => q.topic == topic).length;
    final base = (bank / 5).ceil();
    if (!topicGeneratorTypes.containsKey(topic)) return base;
    return base + 2;
  }

  /// ¿El tema está completo? (todos sus niveles pasados).
  bool isTopicComplete(String topic) =>
      unlockedLevel(topic) > levelCountForTopic(topic);

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

  /// Marca el nivel como superado y desbloquea el siguiente. También
  /// marca hoy como día con nivel pasado (meta diaria).
  void recordLevelPass(String topic, int level) {
    final next = level + 1;
    if (next > unlockedLevel(topic)) {
      unlockedLevels[topic] = next;
    }
    levelPassDays.add(dateKey(DateTime.now()));
    _save();
  }

  // ---- Aciertos por tema (sistema adaptativo) ----

  /// Registra una respuesta de un tema. Se guarda en cada respuesta.
  /// También marca hoy como día de práctica (racha).
  void recordAnswer(String topic, bool correct) {
    _topicTotal[topic] = (_topicTotal[topic] ?? 0) + 1;
    if (correct) _topicCorrect[topic] = (_topicCorrect[topic] ?? 0) + 1;
    practiceDays.add(dateKey(DateTime.now()));
    _save();
  }

  int topicCorrect(String topic) => _topicCorrect[topic] ?? 0;

  int topicTotal(String topic) => _topicTotal[topic] ?? 0;

  /// Totales de la pista actual (para Mis estadísticas).
  int get totalCorrect =>
      _topicCorrect.values.fold(0, (a, b) => a + b);
  int get totalAnswered =>
      _topicTotal.values.fold(0, (a, b) => a + b);

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

  // ---- Pregunta del día ----

  bool qotdAnsweredOn(DateTime d) => qotdDays.contains(dateKey(d));

  void recordQotd(DateTime d) {
    qotdDays.add(dateKey(d));
    _save();
  }

  // ---- Errores para repasar ----

  List<FailedEntry> get failedEntries => List.unmodifiable(_failed);

  int get failedCount => _failed.length;

  List<FailedEntry> failedForTopic(String topic) =>
      _failed.where((f) => f.topic == topic).toList();

  /// Errores que toca repasar hoy: los de días anteriores (o sin fecha,
  /// que son viejos) resurgen solos. Los de hoy aún no.
  List<FailedEntry> dueFailed() {
    final today = dateKey(DateTime.now());
    return _failed
        .where((f) => f.failedDate == null || f.failedDate!.compareTo(today) < 0)
        .toList();
  }

  bool isFailed(String id) => _failed.any((f) => f.id == id);

  void addFailed(FailedEntry entry) {
    if (isFailed(entry.id)) return;
    everFailed = true;
    _failed.add(FailedEntry(
      id: entry.id,
      topic: entry.topic,
      question: entry.question,
      failedDate: entry.failedDate ?? dateKey(DateTime.now()),
      level: entry.level,
    ));
    _save();
  }

  void removeFailed(String id) {
    final before = _failed.length;
    _failed.removeWhere((f) => f.id == id);
    if (_failed.length != before) _save();
  }

  /// Grupos de errores por (tema, nivel), para el repaso por niveles:
  /// cada grupo es un fallo de un nivel concreto, con sus entradas.
  List<({String topic, int level, List<FailedEntry> entries})>
      failedGroups() {
    final map = <String, List<FailedEntry>>{};
    for (final f in _failed) {
      map.putIfAbsent('${f.topic}|${f.level}', () => []).add(f);
    }
    final out = <({String topic, int level, List<FailedEntry> entries})>[];
    for (final e in map.entries) {
      final parts = e.key.split('|');
      out.add((
        topic: parts[0],
        level: int.tryParse(parts[1]) ?? 0,
        entries: e.value
      ));
    }
    out.sort((a, b) {
      final c = a.topic.compareTo(b.topic);
      return c != 0 ? c : a.level.compareTo(b.level);
    });
    return out;
  }

  /// Una respuesta del repaso de variantes de una entrada: el acierto
  /// suma racha y el fallo la pone a cero. Con 3 aciertos SEGUIDOS la
  /// entrada se da por superada y se borra. Devuelve true si se borró.
  bool recordReviewAnswer(String id, bool correct) {
    final i = _failed.indexWhere((f) => f.id == id);
    if (i < 0) return false;
    if (correct) {
      final streak = _failed[i].reviewStreak + 1;
      if (streak >= 3) {
        _failed.removeAt(i);
        _save();
        return true;
      }
      _failed[i] = _failed[i].copyWith(reviewStreak: streak);
    } else {
      _failed[i] = _failed[i].copyWith(reviewStreak: 0);
    }
    _save();
    return false;
  }

  // ---- Foto de otra pista (Mis estadísticas muestra las dos) ----

  /// Lee de SharedPreferences el progreso guardado de una pista, sin
  /// cambiar la pista actual. Devuelve mejores puntuaciones y niveles
  /// desbloqueados de esa pista.
  static Future<({Map<String, int> best, Map<String, int> levels})>
      trackSnapshot(String t) async {
    final prefs = await SharedPreferences.getInstance();
    String key(String suffix) => t == trackBach
        ? 'melli_progress_bach_$suffix'
        : 'melli_progress_$suffix';
    return (
      best: _readIntMap(prefs.getString(key('best'))),
      levels: _readIntMap(prefs.getString(key('levels'))),
    );
  }
}

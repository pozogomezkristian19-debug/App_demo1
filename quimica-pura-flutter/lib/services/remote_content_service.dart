// Contenido remoto (7.0): el editor del admin publica preguntas
// en la colección 'levels' (documento '<tema>_<nivel>'), y la app
// las usa en vez del banco local cuando son válidas. La UI de
// preguntas sigue igual: solo cambia la fuente de datos.
//
// Documento 'levels/<tema>_<nivel>':
//   {topic, level, questions: [{question, options: [4], answer: 0..3,
//     difficulty: 1..3, explanation}]}
//
// VALIDACIÓN: cada pregunta tiene que tener texto no vacío, 4
// opciones no vacías y distintas, y la respuesta en 0..3 (exacto
// 1 correcta: el índice). La pregunta inválida se descarta (no el
// documento entero); si no queda ninguna válida, manda el banco
// local. Sin internet (o sin Google vinculada) también manda el
// local: la app nunca espera a la red dentro del estudio.
//
// Cómo funciona: main() refresca el contenido en segundo plano al
// abrir la app y al volver a primer plano (refreshRemoteContent);
// el contenido válido queda cacheado en local (prefs) y
// questionsForLevel lo devuelve sin tocar la red. El estudio
// funciona 100% offline con el banco local.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'analytics_sync.dart';
import 'online_common.dart';

/// Una pregunta remota ya validada.
class RemoteQuestion {
  const RemoteQuestion({
    required this.question,
    required this.options,
    required this.answer,
    required this.difficulty,
    required this.explanation,
  });

  final String question;
  final List<String> options;
  final int answer;
  final int difficulty;
  final String explanation;

  QuizQuestion toQuizQuestion(String topic) => QuizQuestion(
        topic: topic,
        question: question,
        options: options,
        answer: answer,
        explanation: explanation,
        difficulty: difficulty,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'question': question,
        'options': options,
        'answer': answer,
        'difficulty': difficulty,
        'explanation': explanation,
      };

  /// null si la pregunta no es válida (texto vacío, sin 4 opciones
  /// distintas, o respuesta fuera de 0..3). La dificultad inválida
  /// no tumba la pregunta: cae a 2 (media).
  static RemoteQuestion? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final question = raw['question']?.toString().trim() ?? '';
    if (question.isEmpty) return null;
    final rawOptions = raw['options'];
    if (rawOptions is! List || rawOptions.length != 4) return null;
    final options = <String>[];
    for (final o in rawOptions) {
      final text = o?.toString().trim() ?? '';
      if (text.isEmpty) return null;
      options.add(text);
    }
    if (options.toSet().length != 4) return null;
    final answer = raw['answer'];
    if (answer is! num) return null;
    final answerInt = answer.toInt();
    if (answerInt < 0 || answerInt > 3) return null;
    var difficulty = 2;
    final rawDiff = raw['difficulty'];
    if (rawDiff is num) {
      final d = rawDiff.toInt();
      if (d >= 1 && d <= 3) difficulty = d;
    }
    return RemoteQuestion(
      question: question,
      options: options,
      answer: answerInt,
      difficulty: difficulty,
      explanation: raw['explanation']?.toString() ?? '',
    );
  }

  /// Valida una lista cruda: devuelve solo las preguntas válidas.
  static List<RemoteQuestion> validateAll(Object? raw) {
    final out = <RemoteQuestion>[];
    if (raw is List) {
      for (final item in raw) {
        final q = RemoteQuestion.fromMap(item);
        if (q != null) out.add(q);
      }
    }
    return out;
  }
}

class RemoteContentService {
  RemoteContentService._();

  /// Caché local del contenido remoto validado (prefs, JSON):
  /// clave '<tema>_<nivel>' → lista de preguntas.
  static const String _cacheKey = 'melli_remote_content_v1';

  /// Mínimo entre refrescos en segundo plano (salvo force): 1 h.
  static const Duration _minRefreshGap = Duration(hours: 1);
  static DateTime? _lastRefresh;

  static AnalyticsRepository get _repo => AnalyticsSync.repository;

  /// Preguntas del nivel: las remotas validadas y cacheadas si las
  /// hay; si no, [localFallback] (el banco local, que es el
  /// respaldo). NUNCA toca la red: solo lee la caché local. El
  /// refresco en segundo plano lo hace main().
  static Future<List<QuizQuestion>> questionsForLevel(
    String topic,
    int level, {
    required List<QuizQuestion> localFallback,
  }) async {
    final cached = await cachedQuestions(topic, level);
    if (cached.isNotEmpty) return cached;
    return localFallback;
  }

  /// Preguntas remotas cacheadas del nivel (vacío si no hay).
  static Future<List<QuizQuestion>> cachedQuestions(
      String topic, int level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return [];
      final entry = decoded['${topic}_$level'];
      if (entry is! List) return [];
      final out = <QuizQuestion>[];
      for (final item in entry) {
        final q = RemoteQuestion.fromMap(item);
        if (q != null) out.add(q.toQuizQuestion(topic));
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  /// Refresca la caché con el contenido remoto (segundo plano):
  /// descarga todos los documentos 'levels', valida cada pregunta
  /// y guarda las válidas. Si un documento no trae preguntas
  /// válidas, su entrada de caché queda vacía (manda el local).
  /// Sin Google o sin red no hace nada (y no borra la caché).
  /// Devuelve cuántas preguntas válidas se guardaron.
  static Future<int> refreshRemoteContent({bool force = false}) async {
    if (!OnlineCommon.allowed) return 0;
    final now = DateTime.now();
    if (!force &&
        _lastRefresh != null &&
        now.difference(_lastRefresh!) < _minRefreshGap) {
      return 0;
    }
    _lastRefresh = now;
    final docs = await OnlineCommon.call(
        () => _repo.queryDocs('levels', limit: 200));
    if (docs == null) return 0;
    var total = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      final cache = <String, dynamic>{};
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) cache.addAll(Map<String, dynamic>.from(decoded));
      }
      for (final doc in docs) {
        final topic = doc['topic']?.toString() ?? '';
        final level = (doc['level'] as num?)?.toInt();
        if (topic.isEmpty || level == null) continue;
        final valid = RemoteQuestion.validateAll(doc['questions']);
        total += valid.length;
        cache['${topic}_$level'] =
            valid.map((q) => q.toMap()).toList();
      }
      await prefs.setString(_cacheKey, jsonEncode(cache));
    } catch (_) {
      return 0;
    }
    return total;
  }

  /// Solo para tests: limpia la caché y el reloj de refresco.
  static Future<void> resetForTests() async {
    _lastRefresh = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (_) {
      // Sin almacenamiento no hay caché que limpiar.
    }
  }
}

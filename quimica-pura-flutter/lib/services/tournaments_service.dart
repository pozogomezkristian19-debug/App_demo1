// Torneos (7.0): lectura de la colección 'tournaments' + mejor
// puntaje por usuario. Los torneos REALES los crea el agente
// principal después desde Firebase: ESTE servicio NO escribe
// torneos — solo los lee y guarda el puntaje de cada usuario.
//
// Flujo: entrar → jugar el set (las preguntas del torneo, las
// mismas para todos, reconstruidas desde sus ids) → mejor puntaje
// guardado → clasificación → al terminar, los 3 primeros reciben
// premio (puntos) + medalla en el perfil.
//
// Puntaje: el número de aciertos del set (el mismo "score" que
// muestra la pantalla del torneo: aciertos de total). El mejor
// puntaje guardado es el mayor; el desempate es el menor tiempo
// total (la pantalla aún no mide el tiempo de juego: de momento
// los empates exactos comparten puesto).
//
// Premios (constantes): 1º +50 puntos, 2º +30, 3º +15. Se reclaman
// con [claimPrizesIfEnded] cuando el torneo terminó: es idempotente
// (una sola vez por torneo, marca en prefs) y solo toca MI puntaje
// y MIS puntos locales: la clasificación es pública, pero el premio
// lo cobra cada uno en su teléfono. La medalla queda guardada en
// local (prefs) y en mi documento de puntaje ('medalPlace') para
// que el perfil la muestre.
//
// Reglas: sin Google vinculada no hay torneos (puerta de
// identidad); sin internet el juego local no se pierde (el mejor
// puntaje se encola y se sincroniza al volver) y la lista vacía
// nunca es un error (si no hay torneos, lista vacía).
import 'dart:convert';
import 'dart:math';

import '../models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_sync.dart';
import 'auth_service.dart';
import 'online_common.dart';
import 'progress.dart';
import 'question_generator.dart';
import 'user_prefs.dart';

/// Un torneo (solo lectura desde Firestore).
class Tournament {
  const Tournament({
    required this.id,
    required this.title,
    required this.topic,
    required this.startAtMs,
    required this.endAtMs,
    required this.questionIds,
    required this.prizePoints,
  });

  final String id;
  final String title;
  final String topic;
  final int startAtMs;
  final int endAtMs;
  final List<String> questionIds;

  /// Premio en puntos para el 1º (los premios 2º/3º son las
  /// constantes [TournamentsService.prizeSecond]/[prizeThird]).
  final int prizePoints;

  bool get isActive {
    final now = DateTime.now().millisecondsSinceEpoch;
    return now >= startAtMs && now <= endAtMs;
  }

  bool get isEnded => DateTime.now().millisecondsSinceEpoch > endAtMs;

  bool get isUpcoming =>
      DateTime.now().millisecondsSinceEpoch < startAtMs;

  /// Las preguntas del torneo, reconstruidas desde sus ids (las
  /// mismas para todos). Nunca toca la red.
  List<QuizQuestion> get questions {
    final out = <QuizQuestion>[];
    for (final id in questionIds) {
      final g = rebuildGenerated(id);
      if (g != null) out.add(g.question);
    }
    return out;
  }

  static Tournament? fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final id = raw['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    final rawIds = raw['questionIds'];
    final ids = <String>[];
    if (rawIds is List) {
      for (final v in rawIds) {
        if (v is String && v.isNotEmpty) ids.add(v);
      }
    }
    return Tournament(
      id: id,
      title: raw['title']?.toString() ?? '',
      topic: raw['topic']?.toString() ?? '',
      startAtMs: (raw['startAtMs'] as num?)?.toInt() ?? 0,
      endAtMs: (raw['endAtMs'] as num?)?.toInt() ?? 0,
      questionIds: ids,
      prizePoints: (raw['prizePoints'] as num?)?.toInt() ??
          TournamentsService.prizeFirst,
    );
  }
}

/// Mejor puntaje de un usuario en un torneo.
class TournamentScore {
  const TournamentScore({
    required this.tournamentId,
    required this.uid,
    required this.username,
    required this.bestScore,
    required this.bestCorrect,
    required this.bestTimeMs,
    required this.updatedAtMs,
    required this.lastActivityMs,
    this.medalPlace,
    this.prizePoints,
  });

  final String tournamentId;
  final String uid;
  final String username;
  final int bestScore;
  final int bestCorrect;
  final int bestTimeMs;
  final int updatedAtMs;
  final int lastActivityMs;

  /// Puesto premiado (1, 2 o 3) si el torneo terminó y se cobró.
  final int? medalPlace;
  final int? prizePoints;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'tournamentId': tournamentId,
        'uid': uid,
        'username': username,
        'bestScore': bestScore,
        'bestCorrect': bestCorrect,
        'bestTimeMs': bestTimeMs,
        'updatedAtMs': updatedAtMs,
        'lastActivityMs': lastActivityMs,
        if (medalPlace != null) 'medalPlace': medalPlace,
        if (prizePoints != null) 'prizePoints': prizePoints,
      };

  static TournamentScore? fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final tid = raw['tournamentId']?.toString() ?? '';
    final uid = raw['uid']?.toString() ?? '';
    if (tid.isEmpty || uid.isEmpty) return null;
    return TournamentScore(
      tournamentId: tid,
      uid: uid,
      username: raw['username']?.toString() ?? '',
      bestScore: (raw['bestScore'] as num?)?.toInt() ?? 0,
      bestCorrect: (raw['bestCorrect'] as num?)?.toInt() ?? 0,
      bestTimeMs: (raw['bestTimeMs'] as num?)?.toInt() ?? 0,
      updatedAtMs: (raw['updatedAtMs'] as num?)?.toInt() ?? 0,
      lastActivityMs: (raw['lastActivityMs'] as num?)?.toInt() ?? 0,
      medalPlace: (raw['medalPlace'] as num?)?.toInt(),
      prizePoints: (raw['prizePoints'] as num?)?.toInt(),
    );
  }
}

class TournamentsService {
  TournamentsService._();

  /// Premios del torneo: 1º +50, 2º +30, 3º +15 puntos.
  static const int prizeFirst = 50;
  static const int prizeSecond = 30;
  static const int prizeThird = 15;

  static const String _pendingKey =
      'melli_online_pending_tournament_scores';
  static const String _prizeClaimedPrefix = 'melli_tournament_prize_';
  static const String _medalsKey = 'melli_tournament_medals';

  static AnalyticsRepository get _repo => AnalyticsSync.repository;
  static String get _me => AuthService.currentUid ?? '';
  static String get _myName => UserPrefs.userName;

  /// Torneos, del más reciente al más viejo. Sin Google o sin red:
  /// lista vacía (nunca un error). [activeOnly] deja solo los que
  /// están en curso.
  static Future<List<Tournament>> listTournaments({
    bool activeOnly = false,
  }) async {
    if (!OnlineCommon.allowed) return [];
    final docs = await OnlineCommon.call(() => _repo.queryDocs(
          'tournaments',
          orderByField: 'startAtMs',
          descending: true,
        ));
    if (docs == null) return [];
    final out = <Tournament>[];
    for (final d in docs) {
      final t = Tournament.fromMap(d);
      if (t == null) continue;
      if (activeOnly && !t.isActive) continue;
      out.add(t);
    }
    return out;
  }

  /// Cobra los premios de TODOS los torneos terminados en los que
  /// quedé entre los 3 primeros. Barrido de inicio (main.dart):
  /// el premio no depende de abrir la pantalla del torneo.
  /// Devuelve el total de puntos cobrados. Idempotente.
  static Future<int> claimAllEndedPrizes() async {
    if (!OnlineCommon.allowed) return 0;
    final tournaments = await listTournaments();
    var total = 0;
    for (final t in tournaments) {
      if (t.isEnded) {
        total += await claimPrizesIfEnded(t.id);
      }
    }
    return total;
  }

  /// Un torneo por id. Null sin Google, si no existe o sin red.
  static Future<Tournament?> getTournament(String tournamentId) async {
    if (!OnlineCommon.allowed || tournamentId.isEmpty) return null;
    final doc = await OnlineCommon.call(
        () => _repo.getDoc('tournaments', tournamentId));
    return Tournament.fromMap(doc);
  }

  /// Mi mejor puntaje en el torneo. Null si aún no jugué.
  static Future<TournamentScore?> myScore(String tournamentId) async {
    if (!OnlineCommon.allowed || _me.isEmpty || tournamentId.isEmpty) {
      return null;
    }
    final doc = await OnlineCommon.call(
        () => _repo.getDoc('tournament_scores', _scoreDocId(tournamentId)));
    return TournamentScore.fromMap(doc);
  }

  /// Guarda mi mejor puntaje (solo si mejora el que ya tengo).
  /// [score] = aciertos del set; [timeMs] = tiempo total (0 si la
  /// pantalla no lo midió: los empates exactos comparten puesto).
  /// Devuelve true si quedó sincronizado; false si quedó encolado
  /// para cuando vuelva internet (el juego local no se pierde).
  static Future<bool> submitScore(
    String tournamentId, {
    required int score,
    int timeMs = 0,
  }) async {
    if (!OnlineCommon.allowed || _me.isEmpty || tournamentId.isEmpty) {
      return false;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final current = await myScore(tournamentId);
    if (current != null &&
        (score < current.bestScore ||
            (score == current.bestScore &&
                timeMs >= current.bestTimeMs))) {
      // No mejora el mejor: no se escribe nada.
      return true;
    }
    final ok = await OnlineCommon.write(() => _repo.setDoc(
          'tournament_scores',
          _scoreDocId(tournamentId),
          <String, dynamic>{
            'tournamentId': tournamentId,
            'uid': _me,
            'username': _myName,
            'bestScore': score,
            'bestCorrect': score,
            'bestTimeMs': timeMs,
            'updatedAtMs': now,
            'lastActivityMs': now,
          },
        ));
    if (!ok) {
      await OnlineCommon.enqueue(_pendingKey, <String, dynamic>{
        'tournamentId': tournamentId,
        'uid': _me,
        'username': _myName,
        'score': score,
        'timeMs': timeMs,
        'updatedAtMs': now,
      });
      return false;
    }
    return true;
  }

  /// Clasificación del torneo: mejor puntaje primero, desempate el
  /// menor tiempo. Sin Google o sin red: lista vacía.
  static Future<List<TournamentScore>> leaderboard(
    String tournamentId, {
    int limit = 100,
  }) async {
    if (!OnlineCommon.allowed || tournamentId.isEmpty) return [];
    final docs = await OnlineCommon.call(() => _repo.queryDocs(
          'tournament_scores',
          whereField: 'tournamentId',
          isEqualTo: tournamentId,
          orderByField: 'bestScore',
          descending: true,
          limit: limit,
        ));
    if (docs == null) return [];
    final scores = <TournamentScore>[];
    for (final d in docs) {
      final s = TournamentScore.fromMap(d);
      if (s != null) scores.add(s);
    }
    // El desempate es el menor tiempo: el orden por puntaje ya
    // viene del servidor; en igualdad de puntos manda el tiempo.
    scores.sort((a, b) {
      final byScore = b.bestScore.compareTo(a.bestScore);
      if (byScore != 0) return byScore;
      return a.bestTimeMs.compareTo(b.bestTimeMs);
    });
    return scores;
  }

  /// Si el torneo terminó y quedé entre los 3 primeros, cobra mi
  /// premio (puntos locales + sync) y guarda la medalla. Devuelve
  /// los puntos cobrados (0 si no hay premio o si ya se cobró).
  /// Idempotente y sin lanzar nunca.
  static Future<int> claimPrizesIfEnded(String tournamentId) async {
    if (!OnlineCommon.allowed || _me.isEmpty || tournamentId.isEmpty) {
      return 0;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('$_prizeClaimedPrefix$tournamentId') == true) {
        return 0;
      }
      final tournament = await getTournament(tournamentId);
      if (tournament == null || !tournament.isEnded) return 0;
      final ranking = await leaderboard(tournamentId);
      final place = ranking.indexWhere((s) => s.uid == _me) + 1;
      if (place < 1 || place > 3) return 0;
      final prize = _prizeForPlace(place, tournament);
      await prefs.setBool('$_prizeClaimedPrefix$tournamentId', true);
      await _recordMedal(tournamentId, place, prize);
      final ok = await OnlineCommon.write(() => _repo.setDoc(
            'tournament_scores',
            _scoreDocId(tournamentId),
            <String, dynamic>{
              'medalPlace': place,
              'prizePoints': prize,
            },
          ));
      if (!ok) {
        // El premio local ya está cobrado; la medalla en la nube se
        // reintentará al sincronizar compras/puntaje (no se pierde).
      }
      try {
        ProgressService.instance.addPoints(prize);
      } catch (_) {
        // Sin progreso local no hay puntos que dar.
      }
      AnalyticsSync.uploadProgress(force: true);
      return prize;
    } catch (_) {
      return 0;
    }
  }

  static int _prizeForPlace(int place, Tournament t) {
    switch (place) {
      case 1:
        return t.prizePoints;
      case 2:
        return prizeSecond;
      case 3:
        return prizeThird;
      default:
        return 0;
    }
  }

  /// Medallas cobradas (para el perfil): [{tournamentId, place,
  /// prize}]. Solo lectura local.
  static Future<List<Map<String, dynamic>>> myMedals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_medalsKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _recordMedal(
      String tournamentId, int place, int prize) async {
    try {
      final medals = await myMedals();
      if (medals.any((m) => m['tournamentId'] == tournamentId)) return;
      medals.add(<String, dynamic>{
        'tournamentId': tournamentId,
        'place': place,
        'prizePoints': prize,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_medalsKey, jsonEncode(medals));
    } catch (_) {
      // Sin almacenamiento no se guarda la medalla local.
    }
  }

  /// Latido durante el torneo: actualiza mi última actividad en
  /// mi documento de puntaje (solo si ya tengo uno: la actividad
  /// empieza con el primer envío). Así el resto ve que sigo ahí.
  static Future<void> heartbeat(String tournamentId) async {
    if (!OnlineCommon.allowed || _me.isEmpty || tournamentId.isEmpty) {
      return;
    }
    final current = await myScore(tournamentId);
    if (current == null) return;
    await OnlineCommon.write(() => _repo.setDoc(
          'tournament_scores',
          _scoreDocId(tournamentId),
          <String, dynamic>{
            'lastActivityMs': DateTime.now().millisecondsSinceEpoch,
          },
        ));
  }

  /// Reintenta los puntajes que quedaron pendientes sin internet.
  static Future<int> retryPendingScores() async {
    if (!OnlineCommon.allowed || _me.isEmpty) return 0;
    final items = await OnlineCommon.pending(_pendingKey);
    var done = 0;
    for (var i = items.length - 1; i >= 0; i--) {
      final item = items[i];
      final tid = item['tournamentId']?.toString() ?? '';
      final uid = item['uid']?.toString() ?? '';
      if (tid.isEmpty || uid != _me) continue;
      final ok = await submitScore(
        tid,
        score: (item['score'] as num?)?.toInt() ?? 0,
        timeMs: (item['timeMs'] as num?)?.toInt() ?? 0,
      );
      if (ok) {
        await OnlineCommon.removeAt(_pendingKey, i);
        done++;
      }
    }
    return done;
  }

  static Future<int> pendingCount() =>
      OnlineCommon.pendingCount(_pendingKey);

  static String _scoreDocId(String tournamentId) => '${tournamentId}_$_me';

  /// Torneo de ejemplo LOCAL (para tests y previews): no se escribe
  /// en Firestore. Los torneos reales los crea el agente principal.
  static Tournament exampleTournament({DateTime? now}) {
    final anchor = now ?? DateTime.now();
    final start = anchor.subtract(const Duration(days: 1));
    final end = anchor.add(const Duration(days: 6));
    final rng = Random(20261111);
    final ids = <String>{};
    while (ids.length < 5) {
      ids.add(
          generateForTopic('estequiometria', rng).id);
    }
    return Tournament(
      id: 'local-ejemplo-estequiometria',
      title: 'Torneo de Estequiometría',
      topic: 'estequiometria',
      startAtMs: start.millisecondsSinceEpoch,
      endAtMs: end.millisecondsSinceEpoch,
      questionIds: ids.toList(),
      prizePoints: prizeFirst,
    );
  }
}

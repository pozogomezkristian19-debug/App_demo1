// Duelos online 1 contra 1 (7.0): cada jugador en su teléfono,
// Firestore colección 'duels'.
//
// Flujo: retar → los dos reciben las MISMAS 5 preguntas (el
// documento guarda los 5 ids generados + seed; cada teléfono las
// reconstruye con rebuildGenerated, sin descargarlas) → cada uno
// responde en su teléfono → se registra el resultado → se dan los
// puntos → pantalla de ganador.
//
// Reglas:
//   - Ganador = más aciertos; empate = el más rápido (menos tiempo
//     total). Empate exacto (mismos aciertos y mismo tiempo) =
//     empate, sin ganador y sin puntos.
//   - El ganador suma [duelWinnerPoints] puntos locales + sync.
//     Los duelos NUNCA quitan vidas ni puntos: cancelar o perder
//     no cuesta nada (las vidas son solo de los niveles).
//   - Sin Google vinculada no se puede jugar (puerta de identidad):
//     los métodos devuelven null/false/lista vacía sin error.
//   - Sin internet no se pierde la partida: el resultado se guarda
//     en local (la partida jugada, en prefs) y se encola para
//     sincronizar cuando vuelva internet (retryPendingDuels).
//   - Las escrituras tocan SOLO el documento del duelo propio (su
//     entrada en 'results' + estado) y el doc propio. Nunca el doc
//     de otro usuario.
//
// Desconexión del rival (Kristian 09:17): cada jugador actualiza
// su última actividad en el documento del duelo (al responder y
// con latido periódico, [heartbeat]). Si la última actividad del
// rival supera [forfeitIdleTimeout] (60 s) durante una partida
// activa, el estado pasa a "rival desconectado" con su nombre
// ([Duel.rivalDisconnected]). El jugador que queda puede esperar a
// que vuelva o terminar ganando por abandono ([claimForfeitWin]),
// sin perder vidas ni puntos. Si el rival nunca jugó, el abandono
// se puede reclamar tras [forfeitWaitTimeout] (24 h). Si el
// desconectado vuelve, su partida local está guardada y se
// sincroniza (retryPendingDuels).
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

/// Resultado de un jugador en un duelo.
class DuelResult {
  const DuelResult({
    required this.correct,
    required this.timeMs,
    required this.finishedAtMs,
    required this.lastActivityMs,
  });

  final int correct;
  final int timeMs;
  final int finishedAtMs;
  final int lastActivityMs;

  /// ¿Terminó su juego? El latido ([DuelService.heartbeat]) deja
  /// una entrada con solo lastActivityMs: no es un resultado.
  bool get isFinished => finishedAtMs > 0;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'correct': correct,
        'timeMs': timeMs,
        'finishedAtMs': finishedAtMs,
        'lastActivityMs': lastActivityMs,
      };

  static DuelResult? fromMap(Object? raw) {
    if (raw is! Map) return null;
    return DuelResult(
      correct: (raw['correct'] as num?)?.toInt() ?? 0,
      timeMs: (raw['timeMs'] as num?)?.toInt() ?? 0,
      finishedAtMs: (raw['finishedAtMs'] as num?)?.toInt() ?? 0,
      lastActivityMs: (raw['lastActivityMs'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Un duelo. Estados: waiting (creado, nadie ha jugado), playing
/// (al menos uno ha jugado), finished, cancelled.
class Duel {
  const Duel({
    required this.id,
    required this.playerA,
    required this.playerB,
    required this.playerAName,
    required this.playerBName,
    required this.questionIds,
    required this.seed,
    required this.status,
    required this.createdAtMs,
    required this.results,
    required this.winnerUid,
    required this.forfeit,
  });

  final String id;
  final String playerA;
  final String playerB;
  final String playerAName;
  final String playerBName;
  final List<String> questionIds;
  final int seed;
  final String status;
  final int createdAtMs;
  final Map<String, DuelResult> results;
  final String? winnerUid;
  final bool forfeit;

  bool get isFinished => status == 'finished';
  bool get isCancelled => status == 'cancelled';
  bool get isActive => status == 'waiting' || status == 'playing';

  /// El uid del rival de [myUid], o null si no soy jugador.
  String? rivalUid(String myUid) {
    if (myUid == playerA) return playerB;
    if (myUid == playerB) return playerA;
    return null;
  }

  /// El nombre del rival de [myUid] (para el mensaje en pantalla).
  String rivalName(String myUid) {
    if (myUid == playerA) return playerBName;
    if (myUid == playerB) return playerAName;
    return '';
  }

  DuelResult? resultOf(String uid) => results[uid];

  /// Solo los resultados terminados (sin las entradas de latido).
  Map<String, DuelResult> get finishedResults {
    final out = <String, DuelResult>{};
    results.forEach((uid, r) {
      if (r.isFinished) out[uid] = r;
    });
    return out;
  }

  /// ¿El rival está desconectado? Lo está si jugó (tiene actividad)
  /// y lleva más de [threshold] sin actualizar durante una partida
  /// activa, sin haber terminado. Si nunca tuvo actividad, no es
  /// desconexión: es que aún no ha venido (ver [forfeitWaitTimeout]).
  /// Una entrada de latido (sin terminar) cuenta como actividad,
  /// no como resultado.
  bool rivalDisconnected(
    String myUid, {
    Duration threshold = DuelService.forfeitIdleTimeout,
    int? nowMs,
  }) {
    if (!isActive) return false;
    final rival = rivalUid(myUid);
    if (rival == null) return false;
    final activity = results[rival];
    if (activity == null) return false;
    if (activity.isFinished) return false;
    if (activity.lastActivityMs <= 0) return false;
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return now - activity.lastActivityMs > threshold.inMilliseconds;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'playerA': playerA,
        'playerB': playerB,
        'playerAName': playerAName,
        'playerBName': playerBName,
        'questionIds': questionIds,
        'seed': seed,
        'status': status,
        'createdAtMs': createdAtMs,
        'results': results.map((k, v) => MapEntry(k, v.toMap())),
        'winnerUid': winnerUid,
        'forfeit': forfeit,
      };

  static Duel? fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final id = raw['id']?.toString() ?? '';
    final a = raw['playerA']?.toString() ?? '';
    final b = raw['playerB']?.toString() ?? '';
    if (id.isEmpty || a.isEmpty || b.isEmpty) return null;
    final results = <String, DuelResult>{};
    final rawResults = raw['results'];
    if (rawResults is Map) {
      rawResults.forEach((uid, r) {
        final parsed = DuelResult.fromMap(r);
        if (parsed != null) results[uid.toString()] = parsed;
      });
    }
    final rawIds = raw['questionIds'];
    final ids = <String>[];
    if (rawIds is List) {
      for (final v in rawIds) {
        if (v is String && v.isNotEmpty) ids.add(v);
      }
    }
    return Duel(
      id: id,
      playerA: a,
      playerB: b,
      playerAName: raw['playerAName']?.toString() ?? '',
      playerBName: raw['playerBName']?.toString() ?? '',
      questionIds: ids,
      seed: (raw['seed'] as num?)?.toInt() ?? 0,
      status: raw['status']?.toString() ?? 'waiting',
      createdAtMs: (raw['createdAtMs'] as num?)?.toInt() ?? 0,
      results: results,
      winnerUid: raw['winnerUid']?.toString(),
      forfeit: raw['forfeit'] == true,
    );
  }
}

/// Partida jugada en local (para no perderla si cae internet a mitad
/// de duelo): respuestas dadas, aciertos y tiempo. Se guarda tras
/// cada respuesta y se borra al sincronizar el resultado.
class LocalDuelGame {
  const LocalDuelGame({
    required this.duelId,
    required this.answers,
    required this.correct,
    required this.timeMs,
    required this.finished,
  });

  final String duelId;

  /// Índice de la opción elegida por pregunta (-1 = sin responder).
  final List<int> answers;
  final int correct;
  final int timeMs;
  final bool finished;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'duelId': duelId,
        'answers': answers,
        'correct': correct,
        'timeMs': timeMs,
        'finished': finished,
      };

  static LocalDuelGame? fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final answers = <int>[];
    final rawAnswers = raw['answers'];
    if (rawAnswers is List) {
      for (final v in rawAnswers) {
        if (v is num) answers.add(v.toInt());
      }
    }
    return LocalDuelGame(
      duelId: raw['duelId']?.toString() ?? '',
      answers: answers,
      correct: (raw['correct'] as num?)?.toInt() ?? 0,
      timeMs: (raw['timeMs'] as num?)?.toInt() ?? 0,
      finished: raw['finished'] == true,
    );
  }
}

class DuelService {
  DuelService._();

  /// Puntos que gana el ganador de un duelo (local + sync).
  static const int duelWinnerPoints = 10;

  /// Preguntas por duelo.
  static const int duelQuestionsCount = 5;

  /// El rival se considera desconectado si lleva más de 60 s sin
  /// actualizar su actividad durante una partida activa.
  static const Duration forfeitIdleTimeout = Duration(seconds: 60);

  /// Si el rival nunca jugó, el abandono se puede reclamar tras 24 h
  /// de espera (la partida no se queda congelada).
  static const Duration forfeitWaitTimeout = Duration(hours: 24);

  static const String _pendingKey = 'melli_online_pending_duel_results';
  static const String _localGamePrefix = 'melli_local_duel_';
  static const String _prizePrefix = 'melli_duel_prize_';

  static AnalyticsRepository get _repo => AnalyticsSync.repository;
  static String get _me => AuthService.currentUid ?? '';
  static String get _myName => UserPrefs.userName;

  /// Temas de los que salen las 5 preguntas del duelo (mezcla de
  /// los que tienen generador; orgánica y laboratorio no tienen).
  static const List<String> duelTopics = [
    'estequiometria',
    'gases',
    'disoluciones',
    'acido-base',
    'equilibrio',
    'termo-cinetica',
    'tabla',
    'enlace',
  ];

  /// Crea un duelo contra [rivalUid]. Las 5 preguntas se generan con
  /// el generador/banco (mezcla de temas) y se guardan por id, así
  /// los dos juegan exactamente lo mismo. Devuelve null sin Google,
  /// sin rival o si falla la red.
  static Future<Duel?> createDuel({
    required String rivalUid,
    required String rivalName,
    List<String>? topics,
  }) async {
    if (!OnlineCommon.allowed || _me.isEmpty) return null;
    if (rivalUid.isEmpty || rivalUid == _me) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    final seed = Random().nextInt(1 << 30);
    final ids = _generateQuestionIds(seed: seed, topics: topics);
    if (ids.length < duelQuestionsCount) return null;
    final data = <String, dynamic>{
      'playerA': _me,
      'playerB': rivalUid,
      'playerAName': _myName,
      'playerBName': rivalName,
      'questionIds': ids,
      'seed': seed,
      'status': 'waiting',
      'createdAtMs': now,
      'results': <String, dynamic>{},
      'winnerUid': null,
      'forfeit': false,
    };
    final id = await OnlineCommon.call(
        () => _repo.createDoc('duels', data));
    if (id == null) return null;
    return Duel.fromMap(<String, dynamic>{'id': id, ...data});
  }

  /// Crea un duelo contra un usuario al azar entre los que dieron
  /// permiso de compartir (shared == true) y no están baneados.
  /// Devuelve null sin Google, si no hay nadie más (estado vacío,
  /// no error) o si falla la red.
  static Future<Duel?> createRandomDuel({List<String>? topics}) async {
    if (!OnlineCommon.allowed || _me.isEmpty) return null;
    final users = await OnlineCommon.call(() => _repo.queryDocs(
          'users',
          whereField: 'shared',
          isEqualTo: true,
          limit: 50,
        ));
    if (users == null) return null;
    final candidates = users.where((u) {
      final uid = u['id']?.toString() ?? u['deviceId']?.toString() ?? '';
      if (uid.isEmpty || uid == _me) return false;
      if (u['banned'] == true) return false;
      return true;
    }).toList();
    if (candidates.isEmpty) return null;
    final pick = candidates[Random().nextInt(candidates.length)];
    final rivalUid =
        pick['id']?.toString() ?? pick['deviceId']?.toString() ?? '';
    final rivalName = pick['username']?.toString() ?? '';
    return createDuel(rivalUid: rivalUid, rivalName: rivalName, topics: topics);
  }

  /// Mis duelos abiertos (soy jugador A o B y siguen activos),
  /// del más reciente al más viejo. Es la lista de "mis duelos"
  /// para que el retado abra el suyo (la UI aún no la muestra).
  /// Vacío sin Google o sin red.
  static Future<List<Duel>> myOpenDuels() async {
    if (!OnlineCommon.allowed || _me.isEmpty) return [];
    final asA = await OnlineCommon.call(() => _repo.queryDocs(
          'duels',
          whereField: 'playerA',
          isEqualTo: _me,
          limit: 50,
        ));
    final asB = await OnlineCommon.call(() => _repo.queryDocs(
          'duels',
          whereField: 'playerB',
          isEqualTo: _me,
          limit: 50,
        ));
    final byId = <String, Duel>{};
    for (final docs in [asA, asB]) {
      if (docs == null) continue;
      for (final d in docs) {
        final duel = Duel.fromMap(d);
        if (duel != null && duel.isActive) byId[duel.id] = duel;
      }
    }
    final out = byId.values.toList();
    out.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return out;
  }

  /// Duelos míos ya TERMINADOS (Zona G2, capa sin push): igual que
  /// [myOpenDuels] pero con los terminados, para que la bandeja se
  /// sincronice al abrir la app con el resultado aunque el push no
  /// llegara. Sin Google o sin internet, vacío.
  static Future<List<Duel>> myFinishedDuels() async {
    if (!OnlineCommon.allowed || _me.isEmpty) return [];
    final asA = await OnlineCommon.call(() => _repo.queryDocs(
          'duels',
          whereField: 'playerA',
          isEqualTo: _me,
          limit: 50,
        ));
    final asB = await OnlineCommon.call(() => _repo.queryDocs(
          'duels',
          whereField: 'playerB',
          isEqualTo: _me,
          limit: 50,
        ));
    final byId = <String, Duel>{};
    for (final docs in [asA, asB]) {
      if (docs == null) continue;
      for (final d in docs) {
        final duel = Duel.fromMap(d);
        if (duel != null && duel.isFinished) byId[duel.id] = duel;
      }
    }
    final out = byId.values.toList();
    out.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return out;
  }

  /// Lee un duelo por id. Null sin Google, si no existe o sin red.
  static Future<Duel?> getDuel(String duelId) async {
    if (!OnlineCommon.allowed || duelId.isEmpty) return null;
    final doc = await OnlineCommon.call(
        () => _repo.getDoc('duels', duelId));
    return Duel.fromMap(doc);
  }

  /// Sigue un duelo en vivo (la UI ve si el rival responde, se
  /// desconecta o termina). Sin Google emite null una vez.
  static Stream<Duel?> watchDuel(String duelId) {
    if (!OnlineCommon.allowed || duelId.isEmpty) {
      return Stream<Duel?>.value(null);
    }
    return _repo
        .watchDoc('duels', duelId)
        .map((doc) => Duel.fromMap(doc))
        .handleError((_) => null);
  }

  /// Las 5 preguntas del duelo, reconstruidas desde sus ids (las
  /// mismas para los dos jugadores). Nunca toca la red.
  static List<QuizQuestion> questionsForDuel(Duel duel) {
    final out = <QuizQuestion>[];
    for (final id in duel.questionIds) {
      final g = rebuildGenerated(id);
      if (g != null) out.add(g.question);
    }
    return out;
  }

  /// Envía mi resultado (aciertos y tiempo total en ms). Guarda la
  /// partida en local primero (por si cae internet a mitad), escribe
  /// mi entrada en 'results' (fusión profunda: no pisa la del
  /// rival) y, si los dos ya terminaron, cierra el duelo con el
  /// ganador. Devuelve true si quedó sincronizado; false si quedó
  /// encolado en local para reintentarlo (sin perder la partida) o
  /// si el duelo ya no está activo (terminó o se canceló).
  static Future<bool> submitResult(
    String duelId, {
    required int correct,
    required int timeMs,
  }) async {
    if (!OnlineCommon.allowed || _me.isEmpty || duelId.isEmpty) {
      return false;
    }
    // Si la lectura falla (sin red) no se puede saber si el duelo
    // sigue activo: se intenta escribir igual y, si la escritura
    // también falla, el resultado queda encolado (no se pierde).
    // Si la lectura sale bien y el duelo ya no está activo (o yo
    // ya terminé), no se escribe nada.
    var readFailed = false;
    Duel? duel;
    try {
      final doc = await _repo
          .getDoc('duels', duelId)
          .timeout(OnlineCommon.timeout);
      duel = Duel.fromMap(doc);
    } catch (_) {
      readFailed = true;
    }
    if (!readFailed) {
      if (duel == null || !duel.isActive) return false;
      if (duel.finishedResults.containsKey(_me)) return false;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    // La partida local queda guardada ANTES de intentar la
    // escritura: si se cae la red a mitad del envío, el juego
    // no se pierde (el reintento lo sincroniza). Si la UI ya
    // guardó sus respuestas, esa versión (más rica) manda.
    if (await loadLocalGame(duelId) == null) {
      await saveLocalGame(LocalDuelGame(
        duelId: duelId,
        answers: const [-1, -1, -1, -1, -1],
        correct: correct,
        timeMs: timeMs,
        finished: true,
      ));
    }
    final myResult = DuelResult(
      correct: correct,
      timeMs: timeMs,
      finishedAtMs: now,
      lastActivityMs: now,
    );
    final ok = await OnlineCommon.write(() => _repo.setDoc(
          'duels',
          duelId,
          <String, dynamic>{
            'status': 'playing',
            'results': {
              _me: myResult.toMap(),
            },
          },
        ));
    if (!ok) {
      await OnlineCommon.enqueue(_pendingKey, <String, dynamic>{
        'duelId': duelId,
        'uid': _me,
        'correct': correct,
        'timeMs': timeMs,
        'finishedAtMs': now,
      });
      return false;
    }
    await clearLocalGame(duelId);
    await _finishIfComplete(duelId);
    return true;
  }

  /// Si los dos resultados están y el duelo sigue abierto, lo
  /// cierra con el ganador (o empate) y da los puntos al ganador.
  /// Idempotente: si ya está cerrado, no hace nada. Devuelve true
  /// si el duelo quedó terminado (o ya lo estaba).
  static Future<bool> finishIfComplete(String duelId) async {
    if (!OnlineCommon.allowed || duelId.isEmpty) return false;
    final duel = await getDuel(duelId);
    if (duel == null || !duel.isActive) return duel?.isFinished ?? false;
    if (duel.finishedResults.length < 2) return false;
    return _finishDuel(duel);
  }

  static Future<bool> _finishIfComplete(String duelId) async =>
      finishIfComplete(duelId);

  /// Calcula el ganador y cierra el duelo. No lanza nunca.
  static Future<bool> _finishDuel(Duel duel) async {
    final winner = _computeWinner(duel);
    final ok = await OnlineCommon.write(() => _repo.setDoc(
          'duels',
          duel.id,
          <String, dynamic>{
            'status': 'finished',
            'winnerUid': winner,
            'forfeit': false,
          },
        ));
    if (!ok) return false;
    if (winner != null && winner == _me) {
      await claimWinnerPoints(duel.id);
    }
    return true;
  }

  /// Ganador: más aciertos; empate → menos tiempo. null = empate
  /// exacto (mismos aciertos y mismo tiempo). Solo cuenta los
  /// resultados terminados (las entradas de latido no son resultados).
  static String? _computeWinner(Duel duel) {
    final done = duel.finishedResults;
    final a = done[duel.playerA];
    final b = done[duel.playerB];
    if (a == null || b == null) return null;
    if (a.correct != b.correct) {
      return a.correct > b.correct ? duel.playerA : duel.playerB;
    }
    if (a.timeMs != b.timeMs) {
      return a.timeMs < b.timeMs ? duel.playerA : duel.playerB;
    }
    return null;
  }

  /// ¿Puedo reclamar la victoria por abandono? Solo en partida
  /// activa, si yo ya terminé mi juego y el rival no: o lleva más
  /// de 60 s sin actividad (se desconectó a mitad), o nunca jugó
  /// y pasaron 24 h desde la creación. Pura (sin red) para que la
  /// UI la use antes de mostrar el botón.
  static bool canClaimForfeit(Duel duel, {int? nowMs}) {
    if (!duel.isActive) return false;
    final rival = duel.rivalUid(_me);
    if (rival == null) return false;
    final done = duel.finishedResults;
    if (!done.containsKey(_me)) return false;
    if (done.containsKey(rival)) return false;
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final activity = duel.results[rival]?.lastActivityMs;
    if (activity != null && activity > 0) {
      return now - activity > forfeitIdleTimeout.inMilliseconds;
    }
    // El rival nunca jugó: solo tras 24 h de espera.
    return now - duel.createdAtMs > forfeitWaitTimeout.inMilliseconds;
  }

  /// Termina la partida ganando por abandono (el rival se
  /// desconectó o nunca vino). El ganador suma los puntos del
  /// duelo; nadie pierde vidas ni puntos. Devuelve false si aún
  /// no se puede reclamar (falta tiempo o yo no he terminado).
  static Future<bool> claimForfeitWin(String duelId) async {
    if (!OnlineCommon.allowed || _me.isEmpty || duelId.isEmpty) {
      return false;
    }
    final duel = await getDuel(duelId);
    if (duel == null) return false;
    if (!canClaimForfeit(duel)) return false;
    final ok = await OnlineCommon.write(() => _repo.setDoc(
          'duels',
          duelId,
          <String, dynamic>{
            'status': 'finished',
            'winnerUid': _me,
            'forfeit': true,
          },
        ));
    if (!ok) return false;
    await claimWinnerPoints(duelId);
    return true;
  }

  /// Cancela el duelo (mientras no esté terminado): sin ganador,
  /// sin pérdida de vidas ni de puntos para nadie. Solo la puede
  /// pedir un jugador del duelo.
  static Future<bool> cancelDuel(String duelId) async {
    if (!OnlineCommon.allowed || _me.isEmpty || duelId.isEmpty) {
      return false;
    }
    final duel = await getDuel(duelId);
    if (duel == null || !duel.isActive) return false;
    if (duel.rivalUid(_me) == null) return false;
    return OnlineCommon.write(() => _repo.setDoc(
          'duels',
          duelId,
          <String, dynamic>{'status': 'cancelled'},
        ));
  }

  /// Latido: actualiza mi última actividad en el duelo (la UI lo
  /// llama cada ~30 s mientras juego y al responder). Así el rival
  /// sabe que sigo ahí. No hace nada sin Google o sin red.
  static Future<void> heartbeat(String duelId) async {
    if (!OnlineCommon.allowed || _me.isEmpty || duelId.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await OnlineCommon.write(() => _repo.setDoc(
          'duels',
          duelId,
          <String, dynamic>{
            'results': {
              _me: <String, dynamic>{'lastActivityMs': now},
            },
          },
        ));
  }

  /// Reintenta los resultados que quedaron pendientes sin internet.
  /// Devuelve cuántos se sincronizaron.
  static Future<int> retryPendingDuels() async {
    if (!OnlineCommon.allowed || _me.isEmpty) return 0;
    final items = await OnlineCommon.pending(_pendingKey);
    var done = 0;
    for (var i = items.length - 1; i >= 0; i--) {
      final item = items[i];
      final duelId = item['duelId']?.toString() ?? '';
      final uid = item['uid']?.toString() ?? '';
      if (duelId.isEmpty || uid != _me) continue;
      final ok = await OnlineCommon.write(() => _repo.setDoc(
            'duels',
            duelId,
            <String, dynamic>{
              'status': 'playing',
              'results': {
                uid: <String, dynamic>{
                  'correct': item['correct'],
                  'timeMs': item['timeMs'],
                  'finishedAtMs': item['finishedAtMs'],
                  'lastActivityMs': item['finishedAtMs'],
                },
              },
            },
          ));
      if (ok) {
        await OnlineCommon.removeAt(_pendingKey, i);
        await clearLocalGame(duelId);
        await _finishIfComplete(duelId);
        done++;
      }
    }
    return done;
  }

  /// ¿Cuántos resultados pendientes hay? (Para avisar en silencio.)
  static Future<int> pendingCount() =>
      OnlineCommon.pendingCount(_pendingKey);

  // ---- Partida local (no se pierde si cae internet a mitad) ----

  /// Guarda la partida jugada en local tras cada respuesta.
  static Future<void> saveLocalGame(LocalDuelGame game) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          '$_localGamePrefix${game.duelId}', jsonEncode(game.toMap()));
    } catch (_) {
      // Sin almacenamiento no se puede guardar: el juego sigue.
    }
  }

  /// Lee la partida guardada en local (null = no hay ninguna).
  static Future<LocalDuelGame?> loadLocalGame(String duelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_localGamePrefix$duelId');
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return LocalDuelGame.fromMap(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  /// Borra la partida local (tras sincronizar el resultado).
  static Future<void> clearLocalGame(String duelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_localGamePrefix$duelId');
    } catch (_) {
      // Sin almacenamiento no se puede borrar: no pasa nada.
    }
  }

  // ---- Generación del set (5 preguntas, sin duplicados) ----

  static List<String> _generateQuestionIds({
    required int seed,
    List<String>? topics,
  }) {
    final rng = Random(seed);
    final pool = (topics == null || topics.isEmpty) ? duelTopics : topics;
    final ids = <String>{};
    var guard = 0;
    while (ids.length < duelQuestionsCount && guard < 100) {
      guard++;
      final topic = pool[rng.nextInt(pool.length)];
      final g = generateForTopic(topic, rng);
      ids.add(g.id);
    }
    return ids.toList();
  }

  /// Cobra mis puntos de ganador de un duelo terminado, una sola
  /// vez por duelo: los +10 se dan en el teléfono DEL GANADOR
  /// cuando este se entera de que ganó, no en el teléfono que
  /// cierra el duelo (que puede ser el del rival). Idempotente.
  /// Devuelve true solo si esta llamada dio los puntos.
  static Future<bool> claimWinnerPoints(String duelId) async {
    if (!OnlineCommon.allowed || _me.isEmpty || duelId.isEmpty) {
      return false;
    }
    final duel = await getDuel(duelId);
    if (duel == null || !duel.isFinished || duel.winnerUid != _me) {
      return false;
    }
    var already = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      already = prefs.getBool('$_prizePrefix$duelId') == true;
      if (!already) {
        await prefs.setBool('$_prizePrefix$duelId', true);
      }
    } catch (_) {
      return false;
    }
    if (already) return false;
    try {
      ProgressService.instance.addPoints(duelWinnerPoints);
    } catch (_) {
      // Sin progreso local no hay puntos que dar: el duelo ya quedó.
    }
    // La subida es best-effort y lleva su propia puerta (Google).
    AnalyticsSync.uploadProgress(force: true);
    return true;
  }
}

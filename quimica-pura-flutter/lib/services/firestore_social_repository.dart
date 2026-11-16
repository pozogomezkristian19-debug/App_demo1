// Backend Firestore de la capa social (7.0): implementa el
// contrato SocialRepository de lib/services/social_service.dart
// (del agente B) sobre los servicios Firebase de la 7.0. La UI
// sigue llamando a la fachada SocialService; el repositorio por
// defecto es el falso en memoria y main() instala ESTE cuando hay
// backend.
//
// Notas de mapeo (honestas, para B y para el informe):
//   - online: Google vinculada + ping al servidor (sin Google o
//     sin red, false). La UI muestra sus estados tranquilos.
//   - createDuel: si no hay rival (al azar sin nadie, o sin red),
//     devuelve un DuelState en 'searching' con matchId vacío: la
//     pantalla muestra "buscando rival" y se puede cancelar. La
//     pantalla no tiene estado de error para esto.
//   - duelStream: emite SOLO cuando cambia algo que importa
//     (terminal, rival terminó, su puntaje, conectado/desconectado).
//     La fase no terminal es: yo terminé → 'waiting'; si no,
//     'playing'. La UI pone 'playing' localmente al empezar; el
//     stream nunca la devuelve a 'intro' (si lo hiciera, el quiz
//     se desmontaría y se perdería la partida). El latido lo corre
//     el propio stream mientras está suscrito (cada 30 s), así el
//     rival sabe que sigo ahí; la desconexión se re-evalúa cada
//     15 s (sin cambios en el documento no hay emisión nueva).
//   - Desempate por tiempo: la UI no pasa el tiempo de juego (el
//     SimpleQuizRunner no lo expone), así que el tiempo es desde
//     que se abrió la pantalla del duelo hasta enviar el resultado
//     (incluye la intro): aproximado, pero igual para los dos.
//   - Torneos: el puntaje es el número de aciertos (el mismo
//     "score" de la pantalla). La pantalla aún no mide el tiempo:
//     los empates exactos comparten puesto. 'joined' se guarda en
//     mi doc (campo 'tournamentsJoined'). Los torneos terminados
//     no se listan (la lista es activos + próximos), pero al
//     listarlos se reclaman los premios si quedé entre los 3.
//   - Tienda: el catálogo es REMOTO (Firestore 'shop_items',
//     RemoteShopCatalog, con caché y respaldo offline); la
//     fachada ya no usa `shopItems()` del repositorio. Lo que se
//     sincroniza es la PROPIEDAD ('purchases' en mi doc) y lo
//     EQUIPADO (tema/avatar/insignia/marco, campos
//     'equippedTheme'/'equippedAvatar'/'equippedBadge'/
//     'equippedFrame').
//   - Amigos: la lista muestra solo a los que dieron permiso.
import 'dart:async';

import '../data/topics.dart';
import 'analytics_sync.dart';
import 'auth_service.dart';
import 'duels_service.dart';
import 'friends_groups_service.dart' as fg;
import 'online_common.dart';
import 'presence_service.dart';
import 'progress.dart';
import 'reports_service.dart';
import 'shop_service.dart';
import 'social_service.dart';
import 'tournaments_service.dart';
import 'user_prefs.dart';

class FirestoreSocialRepository implements SocialRepository {
  /// Instante (ms) en que se abrió cada duelo (para el desempate
  /// por tiempo, aproximado: incluye la intro).
  final Map<String, int> _matchStartedAtMs = {};

  /// Latidos y re-evaluaciones activos por duelo suscrito.
  final Map<String, Timer> _duelTimers = {};

  /// Último estado emitido de cada duelo suscrito (para el replay
  /// al suscribirse: cada listener nuevo recibe el valor actual).
  final Map<String, DuelState> _duelLastEmitted = {};

  /// Uids a los que ya se les aseguró el edge de seguimiento en
  /// esta sesión (reparación perezosa de amigos -> follows).
  final Set<String> _followRepairDone = {};

  String get _me => AuthService.currentUid ?? '';

  // ---- Conexión ----

  @override
  Future<bool> get online async {
    if (!OnlineCommon.allowed || _me.isEmpty) return false;
    try {
      return await AnalyticsSync.repository
          .ping('users', _me)
          .timeout(OnlineCommon.timeout);
    } catch (_) {
      return false;
    }
  }

  // ---- Amigos ----

  @override
  Future<List<FriendEntry>> friends() async {
    final list = await fg.FriendsGroupsService.myFriends();
    final blocked = await _myBlockedUids();
    final out = <FriendEntry>[];
    for (final f in list) {
      if (blocked.contains(f.uid)) continue;
      out.add(await _toFriendEntry(f));
    }
    // Reparación perezosa: aseguro MIS edges hacia cada amigo
    // actual (cada usuario solo escribe SUS propios edges; una vez
    // por amigo en esta sesión).
    for (final f in out) {
      if (_followRepairDone.add(f.deviceId)) {
        unawaited(_ensureFollowEdge(f.deviceId));
      }
    }
    return out;
  }

  Future<FriendEntry> _toFriendEntry(fg.FriendProgress f) async {
    String? badgeId;
    String? avatarId;
    final doc = await OnlineCommon.call(
        () => AnalyticsSync.repository.getDoc('users', f.uid));
    final purchases = <String>[];
    final rawPurchases = doc?['purchases'];
    if (rawPurchases is List) {
      for (final v in rawPurchases) {
        if (v is String && v.isNotEmpty) purchases.add(v);
      }
    }
    // Lo equipado no se sincroniza en la 7.0 (solo la propiedad):
    // se muestra lo primero comprado de cada tipo.
    badgeId = doc?['equippedBadge']?.toString();
    badgeId ??= purchases.firstWhere(
      (p) => p.startsWith('badge_'),
      orElse: () => '',
    );
    if (badgeId.isEmpty) badgeId = null;
    var avatarIdRaw = doc?['equippedAvatar']?.toString();
    avatarIdRaw ??= purchases.firstWhere(
      (p) => p.startsWith('avatar_'),
      orElse: () => '',
    );
    if (avatarIdRaw.isNotEmpty) avatarId = avatarIdRaw;
    // Trofeos (examen por tema, Kristian 2026-11-14): los demás ven
    // cuántos trofeos lleva el amigo, de los temas de SU pista.
    var trophiesWon = 0;
    var trophiesTotal = 0;
    final friendTrack = doc?['track']?.toString();
    final friendTopics =
        friendTrack == ProgressService.trackBach ? bachTopics : uniTopics;
    trophiesTotal = friendTopics.length;
    final rawTrophies = doc?['trophies'];
    if (rawTrophies is Map) {
      final list = rawTrophies[friendTrack == ProgressService.trackBach
          ? ProgressService.trackBach
          : ProgressService.trackUni];
      if (list is List) {
        trophiesWon =
            list.where((v) => v is String && friendTopics.contains(v)).length;
      }
    }
    return FriendEntry(
      deviceId: f.uid,
      username: f.username,
      points: f.points,
      levelsPassedTotal: f.levelsPassedTotal,
      streak: f.streak,
      badgeId: badgeId,
      avatarId: avatarId,
      lastSeenMs: f.lastSeenMs,
      isBot: f.isBot,
      trophiesWon: trophiesWon,
      trophiesTotal: trophiesTotal,
    );
  }

  /// Multi-escucha con replay (arreglo del bug gris 2026-11-16):
  /// cada listener recibe la lista actual al suscribirse. Con
  /// Stream.fromFuture (single-subscription) el segundo listen
  /// sobre LA MISMA instancia lanzaba StateError y la pantalla
  /// quedaba gris. Con Stream.multi broadcast no; tampoco vale
  /// asBroadcastStream() a secas sobre un fromFuture, porque el
  /// listener tardío pierde el valor ya emitido y vería 0 amigos.
  @override
  Stream<List<FriendEntry>> friendsStream() {
    return Stream<List<FriendEntry>>.multi((ctrl) async {
      try {
        ctrl.add(await friends());
      } catch (_) {
        ctrl.add(<FriendEntry>[]);
      }
      await ctrl.close();
    }, isBroadcast: true);
  }

  @override
  Future<FriendEntry?> findUserByUsername(String username) async {
    final name = username.trim();
    if (!OnlineCommon.allowed || _me.isEmpty || name.isEmpty) return null;
    if (name == UserPrefs.userName) return null;
    final docs =
        await OnlineCommon.call(() => AnalyticsSync.repository.queryDocs(
              'users',
              whereField: 'username',
              isEqualTo: name,
              limit: 5,
            ));
    if (docs == null) return null;
    for (final d in docs) {
      final f = fg.FriendProgress.fromUserDoc(d);
      if (f == null) continue;
      if (f.uid == _me) continue;
      return _toFriendEntry(f);
    }
    return null;
  }

  @override
  Future<List<FriendEntry>> searchUsers(String query) async {
    final q = query.trim();
    if (q.isEmpty || !OnlineCommon.allowed || _me.isEmpty) return [];
    // Sin correo: la búsqueda es SOLO por nombre de usuario
    // (Kristian 2026-11-15: quitó la búsqueda por correo). Un
    // texto con '@' no es un nombre válido: no devuelve nada.
    // Prefijo de nombre sin mayúsculas: la colección 'usernames'
    // tiene la clave en minúscula y da el uid (rango sobre el id,
    // índice automático, sin índice compuesto). Solo usuarios que
    // compartieron ('shared') y sin vetar (lo comprueba
    // FriendProgress.fromUserDoc).
    final prefix = q.toLowerCase();
    // 1) Nombre de usuario exacto → solo ese perfil (Kristian
    // 2026-11-15), aunque otros nombres compartan el prefijo.
    final exactDoc = await OnlineCommon.call(
        () => AnalyticsSync.repository.getDoc('usernames', prefix));
    final exactUid = exactDoc?['uid']?.toString() ?? '';
    if (exactUid.isNotEmpty && exactUid != _me) {
      final userDoc = await OnlineCommon.call(
          () => AnalyticsSync.repository.getDoc('users', exactUid));
      final f = fg.FriendProgress.fromUserDoc(userDoc);
      if (f != null) return [await _toFriendEntry(f)];
      // El nombre exacto existe pero ese perfil no se comparte
      // (en la búsqueda por prefijo tampoco saldría): nada que
      // mostrar.
      return [];
    }
    // 2) Sin coincidencia exacta: todos los prefijos relacionados.
    final nameDocs = await OnlineCommon.call(() => AnalyticsSync.repository
        .queryDocsByIdPrefix('usernames', prefix, limit: 10));
    if (nameDocs == null) return [];
    final out = <FriendEntry>[];
    for (final d in nameDocs) {
      final uid = d['uid']?.toString() ?? '';
      if (uid.isEmpty || uid == _me) continue;
      final userDoc = await OnlineCommon.call(
          () => AnalyticsSync.repository.getDoc('users', uid));
      final f = fg.FriendProgress.fromUserDoc(userDoc);
      if (f == null) continue;
      out.add(await _toFriendEntry(f));
      if (out.length >= 10) break;
    }
    return out;
  }

  @override
  Future<bool> addFriend(String username) =>
      fg.FriendsGroupsService.addFriendByUsername(username);

  @override
  Future<void> removeFriend(String deviceId) async {
    await fg.FriendsGroupsService.removeFriend(deviceId);
  }

  // --- Solicitudes de amistad (ronda 2d) ---

  @override
  Future<FriendRequestResult> sendFriendRequest(String username) async {
    final result =
        await fg.FriendsGroupsService.sendFriendRequest(username);
    if (result == FriendRequestResult.sent) {
      // Al enviar la solicitud, el remitente SIGUE al destinatario
      // (amigos = seguimiento mutuo, lote seguir). Best-effort: si
      // el seguimiento falla, la solicitud ya quedó enviada.
      try {
        final target = await findUserByUsername(username);
        if (target != null) await followUser(target.deviceId);
      } catch (_) {}
    }
    return result;
  }

  @override
  Future<List<FriendRequest>> incomingFriendRequests() =>
      fg.FriendsGroupsService.incomingFriendRequests();

  @override
  Future<List<FriendRequest>> sentFriendRequests() =>
      fg.FriendsGroupsService.sentFriendRequests();

  @override
  Future<bool> acceptFriendRequest(String requestId) async {
    // El remitente de la solicitud, antes de aceptarla: al
    // aceptar, el que acepta SIGUE de vuelta.
    var senderUid = '';
    try {
      final incoming =
          await fg.FriendsGroupsService.incomingFriendRequests();
      for (final r in incoming) {
        if (r.id == requestId) {
          senderUid = r.senderUid;
          break;
        }
      }
    } catch (_) {}
    final ok =
        await fg.FriendsGroupsService.acceptFriendRequest(requestId);
    if (ok && senderUid.isNotEmpty) {
      try {
        await followUser(senderUid);
      } catch (_) {}
    }
    return ok;
  }

  @override
  Future<void> rejectFriendRequest(String requestId) async {
    await fg.FriendsGroupsService.rejectFriendRequest(requestId);
  }

  @override
  Future<void> cancelFriendRequest(String requestId) async {
    await fg.FriendsGroupsService.cancelFriendRequest(requestId);
  }

  @override
  Future<int> retryPendingFriendRequests() =>
      fg.FriendsGroupsService.retryPendingFriendRequests();

  // ---- Duelos ----

  @override
  Future<DuelState> createDuel(
      {String? opponentUsername, bool random = false}) async {
    Duel? duel;
    String? offlineName;
    if (random) {
      duel = await DuelService.createRandomDuel();
    } else {
      final name = (opponentUsername ?? '').trim();
      final rival = name.isEmpty ? null : await findUserByUsername(name);
      if (rival != null) {
        // Retar exige rival en línea (corrección de Kristian
        // 2026-11-13). El rival ya trae su último latido en la
        // entrada (sin lectura extra): si es REAL y no está en
        // línea, no se crea el duelo y la pantalla avisa. Los bots
        // quedan exentos (siempre disponibles).
        if (!rival.isBot && !PresenceService.isOnline(rival.lastSeenMs)) {
          offlineName = rival.username;
        } else {
          duel = await DuelService.createDuel(
            rivalUid: rival.deviceId,
            rivalName: rival.username,
          );
        }
      }
    }
    if (duel == null) {
      // Rival sin conexión: la pantalla avisa "[nombre] no está en
      // línea" en vez de quedarse en "buscando rival" para siempre.
      // Sin rival o sin red: "buscando rival" (se puede cancelar).
      if (offlineName != null) {
        return DuelState(
          matchId: '',
          opponentName: offlineName,
          phase: DuelPhase.searching,
          questions: const [],
          offlineOpponent: offlineName,
        );
      }
      return const DuelState(
        matchId: '',
        opponentName: '',
        phase: DuelPhase.searching,
        questions: [],
      );
    }
    _matchStartedAtMs[duel.id] = DateTime.now().millisecondsSinceEpoch;
    return DuelState(
      matchId: duel.id,
      opponentName: duel.rivalName(_me),
      phase: DuelPhase.intro,
      questions: DuelService.questionsForDuel(duel),
    );
  }

  @override
  Stream<DuelState> duelStream(String matchId) {
    if (matchId.isEmpty) {
      // También multi-escucha: Stream.value es single-subscription
      // y el segundo listen lanzaría StateError igual.
      return Stream<DuelState>.multi((ctrl) {
        ctrl.add(const DuelState(
          matchId: '',
          opponentName: '',
          phase: DuelPhase.searching,
          questions: [],
        ));
        ctrl.close();
      }, isBroadcast: true);
    }
    _matchStartedAtMs.putIfAbsent(
        matchId, () => DateTime.now().millisecondsSinceEpoch);
    // Multi-escucha con replay (arreglo del bug gris 2026-11-16):
    // cada listener recibe el último estado al suscribirse y luego
    // las actualizaciones. El callback corre por listener (su
    // propio watch + latido); al cancelar se limpia lo suyo.
    return Stream<DuelState>.multi((ctrl) {
      StreamSubscription<Duel?>? docSub;
      var tick = 0;
      var closed = false;
      DuelState? lastEmitted = _duelLastEmitted[matchId];
      Future<void> emitFromDoc(Duel? duel) async {
        if (duel == null || closed) return;
        // El ganador cobra sus puntos en SU teléfono cuando se entera
        // de que ganó (no en el del rival que cerró el duelo).
        if (duel.isFinished && duel.winnerUid == _me) {
          unawaited(DuelService.claimWinnerPoints(duel.id));
        }
        final next = _mapDuel(duel, lastEmitted);
        if (next == null) return;
        lastEmitted = next;
        _duelLastEmitted[matchId] = next;
        ctrl.add(next);
      }

      // Replay: el estado actual, antes de que llegue el watch.
      if (lastEmitted != null) ctrl.add(lastEmitted!);
      docSub = DuelService.watchDuel(matchId).listen(
        emitFromDoc,
        onError: (_) {},
      );
      _duelTimers[matchId]?.cancel();
      _duelTimers[matchId] = Timer.periodic(
        const Duration(seconds: 15),
        (_) async {
          tick++;
          // Latido cada 30 s: el rival sabe que sigo ahí.
          if (tick.isEven) {
            await DuelService.heartbeat(matchId);
          }
          // La desconexión depende del reloj, no del documento:
          // se re-evalúa aunque nadie escriba.
          final duel = await DuelService.getDuel(matchId);
          await emitFromDoc(duel);
        },
      );
      ctrl.onCancel = () async {
        closed = true;
        _duelTimers.remove(matchId)?.cancel();
        await docSub?.cancel();
      };
    }, isBroadcast: true);
  }

  /// Mapea un duelo a DuelState. Devuelve null si no cambió nada
  /// que importe (para no re-emitir en cada latido y no pisar la
  /// fase local de la UI).
  DuelState? _mapDuel(Duel duel, DuelState? last) {
    final me = _me;
    final rival = duel.rivalUid(me);
    final myResult = duel.finishedResults[me];
    final rivalResult = rival == null ? null : duel.finishedResults[rival];
    final now = DateTime.now().millisecondsSinceEpoch;
    final connected = !duel.rivalDisconnected(me, nowMs: now);
    final phase = duel.isFinished
        ? DuelPhase.finished
        : duel.isCancelled
            ? DuelPhase.abandoned
            : myResult != null
                ? DuelPhase.waiting
                : DuelPhase.playing;
    final next = DuelState(
      matchId: duel.id,
      opponentName: duel.rivalName(me),
      phase: phase,
      questions: DuelService.questionsForDuel(duel),
      myScore: myResult?.correct ?? 0,
      opponentScore: rivalResult?.correct ?? 0,
      opponentAnswered: rivalResult != null,
      opponentConnected: connected,
      wonByForfeit: duel.forfeit && duel.winnerUid == me,
      myTimeMs: myResult?.timeMs ?? 0,
      opponentTimeMs: rivalResult?.timeMs ?? 0,
      // El ganador lo decide el servicio (por tiempo en empate):
      // winnerUid null con los dos terminados = empate exacto.
      winnerIsMe: duel.winnerUid == null ? null : duel.winnerUid == me,
    );
    if (last != null &&
        last.phase == next.phase &&
        last.myScore == next.myScore &&
        last.opponentScore == next.opponentScore &&
        last.opponentAnswered == next.opponentAnswered &&
        last.opponentConnected == next.opponentConnected &&
        last.wonByForfeit == next.wonByForfeit &&
        last.winnerIsMe == next.winnerIsMe &&
        last.myTimeMs == next.myTimeMs &&
        last.opponentTimeMs == next.opponentTimeMs) {
      return null;
    }
    return next;
  }

  @override
  Future<void> submitDuelScore(String matchId, int score,
      {int timeMs = 0}) async {
    if (matchId.isEmpty) return;
    // El tiempo REAL de juego lo mide la pantalla (desde "Empezar"
    // hasta terminar) y llega aquí; sin él se usa el tiempo desde
    // que se abrió el duelo.
    final started = _matchStartedAtMs[matchId];
    final elapsed =
        started == null ? 0 : DateTime.now().millisecondsSinceEpoch - started;
    final realTime = timeMs > 0 ? timeMs : elapsed;
    await DuelService.submitResult(matchId, correct: score, timeMs: realTime);
  }

  @override
  Future<void> forfeitDuel(String matchId) async {
    if (matchId.isEmpty) return;
    await DuelService.claimForfeitWin(matchId);
  }

  @override
  Future<void> cancelDuel(String matchId) async {
    if (matchId.isEmpty) return;
    _duelLastEmitted.remove(matchId);
    await DuelService.cancelDuel(matchId);
  }

  /// Un duelo por id como DuelState (para la futura lista de "mis
  /// duelos": el retado abre el suyo desde ahí). Null si no existe
  /// o si no soy jugador.
  static Future<DuelState?> duelStateFor(String duelId) async {
    final duel = await DuelService.getDuel(duelId);
    if (duel == null) return null;
    final me = AuthService.currentUid ?? '';
    if (duel.rivalUid(me) == null) return null;
    final myResult = duel.finishedResults[me];
    final rival = duel.rivalUid(me);
    final rivalResult = rival == null ? null : duel.finishedResults[rival];
    final phase = duel.isFinished
        ? DuelPhase.finished
        : duel.isCancelled
            ? DuelPhase.abandoned
            : myResult != null
                ? DuelPhase.waiting
                : DuelPhase.intro;
    return DuelState(
      matchId: duel.id,
      opponentName: duel.rivalName(me),
      phase: phase,
      questions: DuelService.questionsForDuel(duel),
      myScore: myResult?.correct ?? 0,
      opponentScore: rivalResult?.correct ?? 0,
      opponentAnswered: rivalResult != null,
      opponentConnected: !duel.rivalDisconnected(me),
      wonByForfeit: duel.forfeit && duel.winnerUid == me,
      myTimeMs: myResult?.timeMs ?? 0,
      opponentTimeMs: rivalResult?.timeMs ?? 0,
      winnerIsMe: duel.winnerUid == null ? null : duel.winnerUid == me,
      // El creador es playerA: si yo soy playerB, el duelo llegó.
      incoming: duel.playerB == me,
    );
  }

  /// Mis duelos abiertos (para que el retado abra el suyo).
  @override
  Future<List<DuelState>> myOpenDuels() async {
    final duels = await DuelService.myOpenDuels();
    final out = <DuelState>[];
    for (final d in duels) {
      final state = await duelStateFor(d.id);
      if (state != null) out.add(state);
    }
    return out;
  }

  // ---- Torneos ----

  @override
  Future<List<TournamentInfo>> tournaments() => _loadTournamentInfos();

  /// Multi-escucha con replay (arreglo del bug gris 2026-11-16):
  /// cada listener recibe la lista actual al suscribirse y luego
  /// un refresco cada 30 s. El generador async* anterior era
  /// single-subscription: el segundo listen sobre LA MISMA
  /// instancia lanzaba StateError.
  @override
  Stream<List<TournamentInfo>> tournamentsStream() {
    return Stream<List<TournamentInfo>>.multi((ctrl) {
      StreamSubscription<void>? tickSub;
      var closed = false;
      Future<void> load() async {
        if (closed) return;
        try {
          ctrl.add(await _loadTournamentInfos());
        } catch (_) {
          // Sin red: no se emite nada nuevo (la pantalla conserva
          // lo último que vio).
        }
      }

      ctrl.onCancel = () async {
        closed = true;
        await tickSub?.cancel();
      };
      unawaited(load());
      tickSub = Stream.periodic(const Duration(seconds: 30)).listen((_) {
        unawaited(load());
      });
    }, isBroadcast: true);
  }

  Future<List<TournamentInfo>> _loadTournamentInfos() async {
    final tournaments = await TournamentsService.listTournaments();
    if (tournaments.isEmpty) return [];
    // Premios de torneos terminados (idempotente): si quedé entre
    // los 3, se cobra aquí mismo.
    for (final t in tournaments) {
      if (t.isEnded) {
        unawaited(TournamentsService.claimPrizesIfEnded(t.id));
      }
    }
    final myDoc = await OnlineCommon.call(
        () => AnalyticsSync.repository.getDoc('users', _me));
    final joined = <String>{};
    final rawJoined = myDoc?['tournamentsJoined'];
    if (rawJoined is List) {
      for (final v in rawJoined) {
        if (v is String) joined.add(v);
      }
    }
    final out = <TournamentInfo>[];
    for (final t in tournaments) {
      if (t.isEnded) continue; // La lista es activos + próximos.
      final myScore = await TournamentsService.myScore(t.id);
      final ranking = await TournamentsService.leaderboard(t.id);
      out.add(TournamentInfo(
        id: t.id,
        title: t.title,
        topic: t.topic,
        dateRange: _dateRange(t.startAtMs, t.endAtMs),
        questionCount: t.questionIds.length,
        prizePoints: t.prizePoints,
        entryFee: t.entryFee,
        status: t.isActive ? 'active' : 'upcoming',
        myBestScore: myScore?.bestScore,
        joined: joined.contains(t.id) || myScore != null,
        ranking: ranking
            .map((s) => FriendEntry(
                  deviceId: s.uid,
                  username: s.username,
                  points: s.bestScore,
                  levelsPassedTotal: s.bestCorrect,
                  streak: 0,
                ))
            .toList(),
      ));
    }
    return out;
  }

  static String _dateRange(int startMs, int endMs) {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final a = DateTime.fromMillisecondsSinceEpoch(startMs);
    final b = DateTime.fromMillisecondsSinceEpoch(endMs);
    if (a.month == b.month) {
      return '${a.day}–${b.day} ${months[b.month - 1]}';
    }
    return '${a.day} ${months[a.month - 1]} – ${b.day} ${months[b.month - 1]}';
  }

  @override
  Future<bool> joinTournament(String id, {int? newPointsBalance}) async {
    if (!OnlineCommon.allowed || _me.isEmpty || id.isEmpty) return false;
    final ok = await OnlineCommon.write(() => AnalyticsSync.repository
        .addToArray('users', _me, 'tournamentsJoined', id));
    if (!ok) return false;
    if (newPointsBalance != null) {
      // La entrada ya se descontó en local: se escribe el saldo
      // nuevo en el doc (el campo 'points' está permitido). Si esto
      // falla, no pasa nada grave: el próximo uploadProgress vuelve
      // a subir el saldo local.
      await OnlineCommon.write(() => AnalyticsSync.repository
          .setDoc('users', _me, <String, dynamic>{'points': newPointsBalance}));
    }
    return true;
  }

  @override
  Future<bool> leaveTournament(String id) async {
    if (!OnlineCommon.allowed || _me.isEmpty || id.isEmpty) return false;
    return OnlineCommon.write(() => AnalyticsSync.repository
        .removeFromArray('users', _me, 'tournamentsJoined', id));
  }

  @override
  Future<TournamentInfo?> submitTournamentScore(String id, int score,
      {int timeMs = 0}) async {
    if (id.isEmpty) return null;
    await TournamentsService.submitScore(id, score: score, timeMs: timeMs);
    final all = await _loadTournamentInfos();
    for (final t in all) {
      if (t.id == id) return t;
    }
    // El torneo terminó (ya no se lista): no hay info que devolver,
    // pero el puntaje quedó guardado.
    return null;
  }

  // ---- Tienda ----

  @override
  Future<List<ShopItem>> shopItems() async =>
      OnlineCommon.allowed ? kShopCatalog : <ShopItem>[];

  @override
  Future<void> syncPurchase(String itemId) async {
    await ShopService.syncPurchase(itemId);
  }

  @override
  Future<void> syncEquipped(String kind, String? itemId) async {
    await ShopService.syncEquipped(kind, itemId);
  }

  // ---- Grupos ----

  @override
  Future<List<StudyGroup>> groups() async {
    final list = await fg.FriendsGroupsService.myGroups();
    final out = <StudyGroup>[];
    for (final g in list) {
      out.add(await _toStudyGroup(g));
    }
    return out;
  }

  Future<StudyGroup> _toStudyGroup(fg.StudyGroup g) async {
    final members = await fg.FriendsGroupsService.groupMembersProgress(g.id);
    return StudyGroup(
      id: g.id,
      name: g.name,
      inviteCode: g.code,
      members: members
          .map((m) => FriendEntry(
                deviceId: m.uid,
                username: m.username,
                points: m.points,
                levelsPassedTotal: m.levelsPassedTotal,
                streak: m.streak,
              ))
          .toList(),
    );
  }

  @override
  Future<StudyGroup> createGroup(String name) async {
    final g = await fg.FriendsGroupsService.createGroup(name);
    if (g != null) return _toStudyGroup(g);
    // Sin red o sin Google: el contrato del repositorio pide un
    // grupo, así que se devuelve uno vacío (la UI muestra su
    // estado tranquilo). El nombre se conserva para reintentarlo.
    return StudyGroup(
      id: '',
      name: name.trim().isEmpty ? 'Mi grupo' : name.trim(),
      inviteCode: '',
      members: const [],
    );
  }

  @override
  Future<StudyGroup?> joinGroup(String code) async {
    final g = await fg.FriendsGroupsService.joinGroupByCode(code);
    if (g == null) return null;
    return _toStudyGroup(g);
  }

  @override
  Future<void> leaveGroup(String id) async {
    await fg.FriendsGroupsService.leaveGroup(id);
  }

  // ---- Reportes ----

  @override
  Future<void> reportQuestion(String questionId, String reason) async {
    await ReportsService.reportQuestion(questionId: questionId, note: reason);
  }

  // ---- Seguir / seguidores (lote seguir, 2026-11-16) ----
  // Colección 'follows', doc '<seguidor>_<seguido>' con
  // {followerUid, followingUid, createdAtMs}. Los contadores se
  // calculan leyendo los edges (sin contadores guardados).

  String _followDocId(String followerUid, String followingUid) =>
      '${followerUid}_$followingUid';

  /// Asegura MI edge hacia [uid] (reparación perezosa de amigos).
  /// Best-effort, nunca lanza.
  Future<void> _ensureFollowEdge(String uid) async {
    if (!OnlineCommon.allowed || _me.isEmpty || uid.isEmpty || uid == _me) {
      return;
    }
    await OnlineCommon.write(() => AnalyticsSync.repository.setDoc(
          'follows',
          _followDocId(_me, uid),
          <String, dynamic>{
            'followerUid': _me,
            'followingUid': uid,
            'createdAtMs': DateTime.now().millisecondsSinceEpoch,
          },
        ));
  }

  @override
  Future<bool> followUser(String uid) async {
    if (!OnlineCommon.allowed || _me.isEmpty || uid.isEmpty || uid == _me) {
      return false;
    }
    final id = _followDocId(_me, uid);
    final existing = await OnlineCommon.call(
        () => AnalyticsSync.repository.getDoc('follows', id));
    if (existing != null) return false;
    return OnlineCommon.write(() => AnalyticsSync.repository.setDoc(
          'follows',
          id,
          <String, dynamic>{
            'followerUid': _me,
            'followingUid': uid,
            'createdAtMs': DateTime.now().millisecondsSinceEpoch,
          },
        ));
  }

  @override
  Future<bool> unfollowUser(String uid) async {
    if (!OnlineCommon.allowed || _me.isEmpty || uid.isEmpty || uid == _me) {
      return false;
    }
    return OnlineCommon.write(() => AnalyticsSync.repository
        .deleteDoc('follows', _followDocId(_me, uid)));
  }

  @override
  Future<bool> isFollowing(String uid) async {
    if (!OnlineCommon.allowed || _me.isEmpty || uid.isEmpty || uid == _me) {
      return false;
    }
    final doc = await OnlineCommon.call(() =>
        AnalyticsSync.repository.getDoc('follows', _followDocId(_me, uid)));
    return doc != null;
  }

  @override
  Future<bool> isFollowedBy(String uid) async {
    if (!OnlineCommon.allowed || _me.isEmpty || uid.isEmpty || uid == _me) {
      return false;
    }
    final doc = await OnlineCommon.call(() =>
        AnalyticsSync.repository.getDoc('follows', _followDocId(uid, _me)));
    return doc != null;
  }

  @override
  Future<bool> isMutualFollow(String uid) async {
    if (!OnlineCommon.allowed || _me.isEmpty || uid.isEmpty || uid == _me) {
      return false;
    }
    final following = await isFollowing(uid);
    if (!following) return false;
    return isFollowedBy(uid);
  }

  @override
  Future<int> followingCount(String uid) async {
    if (!OnlineCommon.allowed || uid.isEmpty) return 0;
    final docs = await OnlineCommon.call(() =>
        AnalyticsSync.repository.queryDocs('follows',
            whereField: 'followerUid', isEqualTo: uid));
    return docs?.length ?? 0;
  }

  @override
  Future<int> followersCount(String uid) async {
    if (!OnlineCommon.allowed || uid.isEmpty) return 0;
    final docs = await OnlineCommon.call(() =>
        AnalyticsSync.repository.queryDocs('follows',
            whereField: 'followingUid', isEqualTo: uid));
    return docs?.length ?? 0;
  }

  @override
  Future<List<FriendEntry>> followingList(String uid) async {
    if (!OnlineCommon.allowed || uid.isEmpty) return <FriendEntry>[];
    final docs = await OnlineCommon.call(() =>
        AnalyticsSync.repository.queryDocs('follows',
            whereField: 'followerUid', isEqualTo: uid, limit: 200));
    if (docs == null) return <FriendEntry>[];
    return _entriesForFollowDocs(docs, 'followingUid');
  }

  @override
  Future<List<FriendEntry>> followersList(String uid) async {
    if (!OnlineCommon.allowed || uid.isEmpty) return <FriendEntry>[];
    final docs = await OnlineCommon.call(() =>
        AnalyticsSync.repository.queryDocs('follows',
            whereField: 'followingUid', isEqualTo: uid, limit: 200));
    if (docs == null) return <FriendEntry>[];
    return _entriesForFollowDocs(docs, 'followerUid');
  }

  /// Resuelve los uids del otro lado de los edges a FriendEntry
  /// (con datos de perfil). Un usuario bloqueado por mí no sale.
  Future<List<FriendEntry>> _entriesForFollowDocs(
      List<Map<String, dynamic>> docs, String otherField) async {
    final blocked = await _myBlockedUids();
    final out = <FriendEntry>[];
    for (final d in docs) {
      final otherUid = d[otherField]?.toString() ?? '';
      if (otherUid.isEmpty || blocked.contains(otherUid)) {
        continue;
      }
      final userDoc = await OnlineCommon.call(
          () => AnalyticsSync.repository.getDoc('users', otherUid));
      final f = fg.FriendProgress.fromUserDoc(userDoc);
      if (f == null) continue;
      out.add(await _toFriendEntry(f));
    }
    out.sort((a, b) => b.points.compareTo(a.points));
    return out;
  }

  // ---- Sugerencias (rotación diaria determinista) ----

  @override
  Future<List<FriendEntry>> friendSuggestions({DateTime? on}) async {
    // Sugerencias SOLO con sesión (Kristian 2026-11-16): sin
    // Google ni correo vinculados no hay nada que sugerir. La
    // puerta es la misma que la de seguir (OnlineCommon.allowed
    // = con sesión vinculada). Sin _me no hay ni siquiera sesión
    // anónima: no hay nada que sugerir.
    if (!OnlineCommon.allowed || _me.isEmpty) return <FriendEntry>[];
    final day = on ?? DateTime.now();
    final docs = await OnlineCommon.call(() =>
        AnalyticsSync.repository.queryDocs('users',
            whereField: 'shared', isEqualTo: true, limit: 100));
    if (docs == null) return <FriendEntry>[];
    final blocked = await _myBlockedUids();
    final dismissed = await loadDismissedSuggestions(day);
    final friendIds =
        (await fg.FriendsGroupsService.myFriends()).map((f) => f.uid).toSet();
    // Los ya seguidos tampoco se sugieren: al seguir, la tarjeta
    // se desliza y la sustituye la siguiente (pulido 2026-11-16).
    final followingIds =
        (await followingList(_me)).map((f) => f.deviceId).toSet();
    final pool = <FriendEntry>[];
    for (final d in docs) {
      final f = fg.FriendProgress.fromUserDoc(d);
      if (f == null) continue;
      if (f.uid == _me) continue;
      if (friendIds.contains(f.uid)) continue;
      if (followingIds.contains(f.uid)) continue;
      if (blocked.contains(f.uid)) continue;
      if (dismissed.contains(f.uid)) continue;
      pool.add(await _toFriendEntry(f));
    }
    // Los bots tienen docs reales con shared: también salen.
    return shuffleForDate(pool, day).take(2).toList();
  }

  @override
  Future<void> dismissSuggestion(String uid, {DateTime? on}) async {
    await dismissSuggestionLocal(uid, on ?? DateTime.now());
  }

  // ---- Perfil público (datos 100 % reales) ----

  @override
  Future<PublicProfile?> publicProfile(String uid) async {
    if (!OnlineCommon.allowed || _me.isEmpty || uid.isEmpty) return null;
    final doc = await OnlineCommon.call(
        () => AnalyticsSync.repository.getDoc('users', uid));
    if (doc == null) return null;
    return PublicProfile.fromUserDoc(
      doc,
      viewerUid: _me,
      followingCount: await followingCount(uid),
      followersCount: await followersCount(uid),
      isFollowing: await isFollowing(uid),
      isFollowedBy: await isFollowedBy(uid),
    );
  }

  // ---- Reportar y bloquear usuarios ----

  @override
  Future<bool> reportUser(String uid, String reason) async {
    return ReportsService.reportUser(uid: uid, reason: reason);
  }

  /// Mis bloqueados: el campo 'blockedUids' de mi documento +
  /// el espejo local (para filtrar sin internet). Antes de leer,
  /// se aplican las operaciones de bloqueo pendientes sin internet
  /// (ver [blockUser]): así el documento y el espejo convergen.
  Future<Set<String>> _myBlockedUids() async {
    await _syncPendingBlockOps();
    final out = <String>{};
    out.addAll(await loadBlockedMirror());
    final doc = await OnlineCommon.call(
        () => AnalyticsSync.repository.getDoc('users', _me));
    final raw = doc?['blockedUids'];
    if (raw is List) {
      for (final v in raw) {
        if (v is String && v.isNotEmpty) out.add(v);
      }
    }
    return out;
  }

  /// Cola local de bloqueos/desbloqueos sin internet (JSON).
  static const String _pendingBlockOpsKey = 'social_blocked_pending_ops';

  /// Aplica las operaciones de bloqueo pendientes (al volver la
  /// conexión). Best-effort, nunca lanza.
  Future<void> _syncPendingBlockOps() async {
    if (!OnlineCommon.allowed || _me.isEmpty) return;
    try {
      final items = await OnlineCommon.pending(_pendingBlockOpsKey);
      for (var i = items.length - 1; i >= 0; i--) {
        final item = items[i];
        final op = item['op']?.toString() ?? '';
        final uid = item['uid']?.toString() ?? '';
        if (uid.isEmpty || (op != 'block' && op != 'unblock')) {
          await OnlineCommon.removeAt(_pendingBlockOpsKey, i);
          continue;
        }
        final ok = op == 'block'
            ? await OnlineCommon.write(() => AnalyticsSync.repository
                .addToArray('users', _me, 'blockedUids', uid))
            : await OnlineCommon.write(() => AnalyticsSync.repository
                .removeFromArray('users', _me, 'blockedUids', uid));
        if (ok) await OnlineCommon.removeAt(_pendingBlockOpsKey, i);
      }
    } catch (_) {}
  }

  @override
  Future<bool> blockUser(String uid) async {
    if (uid.isEmpty || uid == _me) return false;
    final mirror = await loadBlockedMirror()..add(uid);
    await saveBlockedMirror(mirror);
    if (!OnlineCommon.allowed || _me.isEmpty) {
      // Sin internet: queda en el espejo y en la cola; al volver
      // la conexión se escribe en el documento (_syncPendingBlockOps).
      await OnlineCommon.enqueue(
          _pendingBlockOpsKey, {'op': 'block', 'uid': uid});
      return true;
    }
    await OnlineCommon.write(() => AnalyticsSync.repository
        .addToArray('users', _me, 'blockedUids', uid));
    return true;
  }

  @override
  Future<bool> unblockUser(String uid) async {
    if (uid.isEmpty) return false;
    final mirror = await loadBlockedMirror()..remove(uid);
    await saveBlockedMirror(mirror);
    if (!OnlineCommon.allowed || _me.isEmpty) {
      await OnlineCommon.enqueue(
          _pendingBlockOpsKey, {'op': 'unblock', 'uid': uid});
      return true;
    }
    await OnlineCommon.write(() => AnalyticsSync.repository
        .removeFromArray('users', _me, 'blockedUids', uid));
    return true;
  }

  @override
  Future<bool> isBlocked(String uid) async {
    if (uid.isEmpty) return false;
    return (await _myBlockedUids()).contains(uid);
  }

  @override
  Future<List<String>> blockedUids() async {
    final out = (await _myBlockedUids()).toList()..sort();
    return out;
  }
}

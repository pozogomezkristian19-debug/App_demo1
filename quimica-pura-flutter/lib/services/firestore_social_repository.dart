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

import 'analytics_sync.dart';
import 'auth_service.dart';
import 'duels_service.dart';
import 'friends_groups_service.dart' as fg;
import 'online_common.dart';
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
    final out = <FriendEntry>[];
    for (final f in list) {
      out.add(await _toFriendEntry(f));
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
    return FriendEntry(
      deviceId: f.uid,
      username: f.username,
      points: f.points,
      levelsPassedTotal: f.levelsPassedTotal,
      streak: f.streak,
      badgeId: badgeId,
      avatarId: avatarId,
    );
  }

  @override
  Stream<List<FriendEntry>> friendsStream() {
    return Stream<List<FriendEntry>>.fromFuture(friends())
        .handleError((_) => <FriendEntry>[]);
  }

  @override
  Future<FriendEntry?> findUserByUsername(String username) async {
    final name = username.trim();
    if (!OnlineCommon.allowed || _me.isEmpty || name.isEmpty) return null;
    if (name == UserPrefs.userName) return null;
    final docs = await OnlineCommon.call(() =>
        AnalyticsSync.repository.queryDocs(
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
  Future<bool> addFriend(String username) =>
      fg.FriendsGroupsService.addFriendByUsername(username);

  @override
  Future<void> removeFriend(String deviceId) async {
    await fg.FriendsGroupsService.removeFriend(deviceId);
  }

  // --- Solicitudes de amistad (ronda 2d) ---

  @override
  Future<FriendRequestResult> sendFriendRequest(String username) =>
      fg.FriendsGroupsService.sendFriendRequest(username);

  @override
  Future<List<FriendRequest>> incomingFriendRequests() =>
      fg.FriendsGroupsService.incomingFriendRequests();

  @override
  Future<List<FriendRequest>> sentFriendRequests() =>
      fg.FriendsGroupsService.sentFriendRequests();

  @override
  Future<bool> acceptFriendRequest(String requestId) =>
      fg.FriendsGroupsService.acceptFriendRequest(requestId);

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
    if (random) {
      duel = await DuelService.createRandomDuel();
    } else {
      final name = (opponentUsername ?? '').trim();
      final rival = name.isEmpty ? null : await findUserByUsername(name);
      if (rival != null) {
        duel = await DuelService.createDuel(
          rivalUid: rival.deviceId,
          rivalName: rival.username,
        );
      }
    }
    if (duel == null) {
      // Sin rival o sin red: la pantalla no tiene estado de error,
      // así que se devuelve "buscando rival" (se puede cancelar).
      return const DuelState(
        matchId: '',
        opponentName: '',
        phase: DuelPhase.searching,
        questions: [],
      );
    }
    _matchStartedAtMs[duel.id] =
        DateTime.now().millisecondsSinceEpoch;
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
      return Stream<DuelState>.value(const DuelState(
        matchId: '',
        opponentName: '',
        phase: DuelPhase.searching,
        questions: [],
      ));
    }
    _matchStartedAtMs.putIfAbsent(
        matchId, () => DateTime.now().millisecondsSinceEpoch);
    late final StreamController<DuelState> ctrl;
    StreamSubscription<Duel?>? docSub;
    var tick = 0;
    DuelState? lastEmitted;
    Future<void> emitFromDoc(Duel? duel) async {
      if (duel == null || ctrl.isClosed) return;
      // El ganador cobra sus puntos en SU teléfono cuando se entera
      // de que ganó (no en el del rival que cerró el duelo).
      if (duel.isFinished && duel.winnerUid == _me) {
        unawaited(DuelService.claimWinnerPoints(duel.id));
      }
      final next = _mapDuel(duel, lastEmitted);
      if (next == null) return;
      lastEmitted = next;
      ctrl.add(next);
    }

    ctrl = StreamController<DuelState>(
      onListen: () {
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
      },
      onCancel: () async {
        _duelTimers.remove(matchId)?.cancel();
        await docSub?.cancel();
      },
    );
    return ctrl.stream;
  }

  /// Mapea un duelo a DuelState. Devuelve null si no cambió nada
  /// que importe (para no re-emitir en cada latido y no pisar la
  /// fase local de la UI).
  DuelState? _mapDuel(Duel duel, DuelState? last) {
    final me = _me;
    final rival = duel.rivalUid(me);
    final myResult = duel.finishedResults[me];
    final rivalResult =
        rival == null ? null : duel.finishedResults[rival];
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
      winnerIsMe:
          duel.winnerUid == null ? null : duel.winnerUid == me,
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
    final elapsed = started == null
        ? 0
        : DateTime.now().millisecondsSinceEpoch - started;
    final realTime = timeMs > 0 ? timeMs : elapsed;
    await DuelService.submitResult(
        matchId, correct: score, timeMs: realTime);
  }

  @override
  Future<void> forfeitDuel(String matchId) async {
    if (matchId.isEmpty) return;
    await DuelService.claimForfeitWin(matchId);
  }

  @override
  Future<void> cancelDuel(String matchId) async {
    if (matchId.isEmpty) return;
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
    final rivalResult =
        rival == null ? null : duel.finishedResults[rival];
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

  @override
  Stream<List<TournamentInfo>> tournamentsStream() async* {
    yield await _loadTournamentInfos();
    // La clasificación se refresca sola cada 30 s mientras la
    // pantalla está abierta.
    await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
      yield await _loadTournamentInfos();
    }
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
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    final a = DateTime.fromMillisecondsSinceEpoch(startMs);
    final b = DateTime.fromMillisecondsSinceEpoch(endMs);
    if (a.month == b.month) {
      return '${a.day}–${b.day} ${months[b.month - 1]}';
    }
    return '${a.day} ${months[a.month - 1]} – ${b.day} ${months[b.month - 1]}';
  }

  @override
  Future<void> joinTournament(String id) async {
    if (!OnlineCommon.allowed || _me.isEmpty || id.isEmpty) return;
    await OnlineCommon.write(() => AnalyticsSync.repository
        .addToArray('users', _me, 'tournamentsJoined', id));
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
    final members =
        await fg.FriendsGroupsService.groupMembersProgress(g.id);
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
    await ReportsService.reportQuestion(
        questionId: questionId, note: reason);
  }
}

// Amigos y grupos de estudio (7.0), Firestore. Capa de datos: la
// UI llama a la fachada SocialService (lib/services/social_service.dart,
// del agente B), que usa FirestoreSocialRepository como backend.
//
// Amigos POR SOLICITUD (ronda 2d): agregar por nombre ya no añade
// directo — envía una solicitud (colección 'friend_requests') que el
// otro confirma o elimina; solo al confirmar los dos quedan amigos
// (cada uno en la 'friends' del otro). La lista de amigos vive en el
// doc propio ('users/<uid>', campo 'friends'): no se toca nunca el
// doc de otro usuario, SALVO al confirmar una solicitud, que añade
// solo MI propio uid a la 'friends' del remitente (regla estrecha
// en firestore.rules). La lista de progreso de amigos muestra solo
// a los amigos que dieron permiso (shared == true) y no están
// baneados.
//
// Grupos: crear grupo (nombre + código de invitación generado de 6
// letras) y unirse con el código; leer el progreso de los miembros.
// SIN chat. El grupo guarda memberUids; cada usuario guarda sus
// grupos en su propio doc (campo 'groups'). Unirse usa arrayUnion
// (dos personas a la vez no se pisan la lista).
//
// Reglas: sin Google vinculada no hay amigos ni grupos (puerta de
// identidad); sin internet, lista vacía / false, nunca un error.
import 'dart:math';

import 'analytics_sync.dart';
import 'auth_service.dart';
import 'online_common.dart';
import 'social_service.dart';
import 'user_prefs.dart';

/// Progreso de un amigo (o de un miembro de un grupo) para
/// mostrarlo en la lista.
class FriendProgress {
  const FriendProgress({
    required this.uid,
    required this.username,
    required this.points,
    required this.levelsPassedTotal,
    required this.streak,
  });

  final String uid;
  final String username;
  final int points;
  final int levelsPassedTotal;
  final int streak;

  static FriendProgress? fromUserDoc(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final uid = raw['id']?.toString() ?? raw['deviceId']?.toString() ?? '';
    if (uid.isEmpty) return null;
    if (raw['banned'] == true) return null;
    if (raw['shared'] != true) return null;
    final levels = raw['levelsPassed'];
    var total = 0;
    if (levels is Map) {
      levels.forEach((_, v) {
        if (v is num) total += v.toInt();
      });
    } else if (levels is num) {
      total = levels.toInt();
    }
    return FriendProgress(
      uid: uid,
      username: raw['username']?.toString() ?? '',
      points: (raw['points'] as num?)?.toInt() ?? 0,
      levelsPassedTotal: total,
      streak: (raw['streak'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Un grupo de estudio.
class StudyGroup {
  const StudyGroup({
    required this.id,
    required this.name,
    required this.code,
    required this.ownerUid,
    required this.memberUids,
    required this.createdAtMs,
  });

  final String id;
  final String name;
  final String code;
  final String ownerUid;
  final List<String> memberUids;
  final int createdAtMs;

  static StudyGroup? fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final id = raw['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    final members = <String>[];
    final rawMembers = raw['memberUids'];
    if (rawMembers is List) {
      for (final v in rawMembers) {
        if (v is String && v.isNotEmpty) members.add(v);
      }
    }
    return StudyGroup(
      id: id,
      name: raw['name']?.toString() ?? '',
      code: raw['code']?.toString() ?? '',
      ownerUid: raw['ownerUid']?.toString() ?? '',
      memberUids: members,
      createdAtMs: (raw['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class FriendsGroupsService {
  FriendsGroupsService._();

  static AnalyticsRepository get _repo => AnalyticsSync.repository;
  static String get _me => AuthService.currentUid ?? '';
  static String get _myName => UserPrefs.userName;

  /// Código de invitación: 6 letras sin caracteres confusos
  /// (sin 0/O, 1/I/l) para dictarlo por voz o escribirlo a mano.
  static const String _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const int _codeLength = 6;

  // ---- Amigos ----

  /// Mis amigos con su progreso (solo los que dieron permiso de
  /// compartir y no están baneados). Vacío si no tengo amigos, sin
  /// Google o sin internet: nunca un error.
  ///
  /// La lista es la unión de mi 'friends' con los amigos de las
  /// solicitudes 'aceptada' en los dos sentidos: al confirmar, los
  /// dos quedan amigos aunque la escritura espejo en el documento
  /// del otro aún no haya llegado (la solicitud aceptada es la
  /// prueba de la amistad).
  static Future<List<FriendProgress>> myFriends() async {
    if (!OnlineCommon.allowed || _me.isEmpty) return [];
    final myDoc = await OnlineCommon.call(() => _repo.getDoc('users', _me));
    final ids = _stringList(myDoc?['friends']).toSet();
    for (final field in const ['senderUid', 'receiverUid']) {
      final docs = await OnlineCommon.call(() => _repo.queryDocs(
            'friend_requests',
            whereField: field,
            isEqualTo: _me,
            limit: 30,
          ));
      if (docs == null) continue;
      for (final d in docs) {
        if (d['status'] != 'aceptada') continue;
        final other = field == 'senderUid'
            ? d['receiverUid']?.toString() ?? ''
            : d['senderUid']?.toString() ?? '';
        if (other.isNotEmpty) ids.add(other);
      }
    }
    final out = <FriendProgress>[];
    for (final uid in ids) {
      if (uid == _me) continue;
      final doc = await OnlineCommon.call(() => _repo.getDoc('users', uid));
      final f = FriendProgress.fromUserDoc(doc);
      if (f != null) out.add(f);
    }
    out.sort((a, b) => b.points.compareTo(a.points));
    return out;
  }

  /// Agrega un amigo por nombre de usuario. Solo si existe, dio
  /// permiso de compartir y no soy yo. true si quedó agregado (o
  /// ya lo era); false si no existe, no compartió, sin Google o
  /// sin internet.
  static Future<bool> addFriendByUsername(String username) async {
    final name = username.trim();
    if (!OnlineCommon.allowed || _me.isEmpty || name.isEmpty) return false;
    if (name == _myName) return false;
    final docs = await OnlineCommon.call(() => _repo.queryDocs(
          'users',
          whereField: 'username',
          isEqualTo: name,
          limit: 5,
        ));
    if (docs == null) return false;
    Map<String, dynamic>? target;
    for (final d in docs) {
      if (d['shared'] == true && d['banned'] != true) {
        target = d;
        break;
      }
    }
    if (target == null) return false;
    final uid =
        target['id']?.toString() ?? target['deviceId']?.toString() ?? '';
    if (uid.isEmpty || uid == _me) return false;
    final myDoc = await OnlineCommon.call(() => _repo.getDoc('users', _me));
    if (myDoc != null && _stringList(myDoc['friends']).contains(uid)) {
      return true;
    }
    return OnlineCommon.write(
        () => _repo.addToArray('users', _me, 'friends', uid));
  }

  /// Quita un amigo de mi lista. true si se quitó (o no estaba).
  /// Si la amistad vino de una solicitud aceptada, la solicitud
  /// pasa a 'rechazada': al quitar a un amigo, la amistad se rompe
  /// en los dos sentidos y no vuelve a aparecer solo.
  static Future<bool> removeFriend(String uid) async {
    if (!OnlineCommon.allowed || _me.isEmpty || uid.isEmpty) return false;
    if (uid == _me) return false;
    final removed = await OnlineCommon.write(
        () => _repo.removeFromArray('users', _me, 'friends', uid));
    for (final field in const ['senderUid', 'receiverUid']) {
      final docs = await OnlineCommon.call(() => _repo.queryDocs(
            'friend_requests',
            whereField: field,
            isEqualTo: _me,
            limit: 30,
          ));
      if (docs == null) continue;
      for (final d in docs) {
        if (d['status'] != 'aceptada') continue;
        final other = field == 'senderUid'
            ? d['receiverUid']?.toString() ?? ''
            : d['senderUid']?.toString() ?? '';
        if (other != uid) continue;
        final id = d['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        await OnlineCommon.write(() => _repo.setDoc(
              'friend_requests',
              id,
              <String, dynamic>{'status': 'rechazada'},
            ));
      }
    }
    return removed;
  }

  /// ¿Es [uid] amigo mío? (Lectura de mi doc.)
  static Future<bool> isFriend(String uid) async {
    if (!OnlineCommon.allowed || _me.isEmpty || uid.isEmpty) return false;
    final myDoc = await OnlineCommon.call(() => _repo.getDoc('users', _me));
    return _stringList(myDoc?['friends']).contains(uid);
  }

  // ---- Solicitudes de amistad (ronda 2d) ----

  /// Clave de la cola de solicitudes encoladas sin internet.
  static const String _pendingRequestsKey = 'melli_pending_friend_requests';

  /// Envía una solicitud de amistad por nombre de usuario. Valida
  /// con calma: existe y compartió, no soy yo, no somos ya amigos,
  /// no hay ya una solicitud pendiente en ningún sentido. Sin
  /// internet se encola (sin duplicados) y se envía sola al volver
  /// la conexión; la validación corre al reenviar.
  static Future<FriendRequestResult> sendFriendRequest(
      String username) async {
    final name = username.trim();
    if (!OnlineCommon.allowed || _me.isEmpty) {
      return FriendRequestResult.unavailable;
    }
    if (name.isEmpty) return FriendRequestResult.notFound;
    if (name.toLowerCase() == _myName.toLowerCase()) {
      return FriendRequestResult.self;
    }
    final docs = await OnlineCommon.call(() => _repo.queryDocs(
          'users',
          whereField: 'username',
          isEqualTo: name,
          limit: 5,
        ));
    if (docs == null) {
      // Sin red (o sin permiso): se encola y se envía sola.
      await _enqueueRequest(name);
      return FriendRequestResult.queued;
    }
    Map<String, dynamic>? target;
    for (final d in docs) {
      if (d['shared'] == true && d['banned'] != true) {
        target = d;
        break;
      }
    }
    if (target == null) return FriendRequestResult.notFound;
    final uid =
        target['id']?.toString() ?? target['deviceId']?.toString() ?? '';
    if (uid.isEmpty || uid == _me) return FriendRequestResult.self;
    final myDoc = await OnlineCommon.call(() => _repo.getDoc('users', _me));
    if (myDoc != null && _stringList(myDoc['friends']).contains(uid)) {
      return FriendRequestResult.alreadyFriends;
    }
    // Solicitudes pendientes en los dos sentidos (queryDocs solo
    // filtra por un campo: el resto se filtra en local).
    final mine = await OnlineCommon.call(() => _repo.queryDocs(
          'friend_requests',
          whereField: 'senderUid',
          isEqualTo: _me,
          limit: 20,
        ));
    if (mine != null) {
      for (final d in mine) {
        if (d['status'] == 'pendiente' && d['receiverUid'] == uid) {
          return FriendRequestResult.alreadySent;
        }
      }
    }
    final theirs = await OnlineCommon.call(() => _repo.queryDocs(
          'friend_requests',
          whereField: 'receiverUid',
          isEqualTo: _me,
          limit: 20,
        ));
    if (theirs != null) {
      for (final d in theirs) {
        if (d['status'] == 'pendiente' && d['senderUid'] == uid) {
          return FriendRequestResult.incomingPending;
        }
      }
    }
    final sent = await OnlineCommon.write(() async {
      await _repo.createDoc(
        'friend_requests',
        <String, dynamic>{
          'senderUid': _me,
          'senderUsername': _myName,
          'receiverUid': uid,
          'receiverUsername': name,
          'status': 'pendiente',
          'createdAtMs': DateTime.now().millisecondsSinceEpoch,
        },
      );
    });
    if (!sent) {
      await _enqueueRequest(name);
      return FriendRequestResult.queued;
    }
    return FriendRequestResult.sent;
  }

  /// Encola una solicitud sin internet, sin duplicados por nombre.
  static Future<void> _enqueueRequest(String name) async {
    final pending = await OnlineCommon.pending(_pendingRequestsKey);
    if (pending.any((p) => p['username'] == name)) return;
    await OnlineCommon.enqueue(
        _pendingRequestsKey, <String, dynamic>{'username': name});
  }

  /// Solicitudes pendientes que me llegaron (las más nuevas
  /// primero). Vacío sin Google o sin internet: nunca un error.
  static Future<List<FriendRequest>> incomingFriendRequests() async {
    if (!OnlineCommon.allowed || _me.isEmpty) return [];
    final docs = await OnlineCommon.call(() => _repo.queryDocs(
          'friend_requests',
          whereField: 'receiverUid',
          isEqualTo: _me,
          limit: 30,
        ));
    if (docs == null) return [];
    final out = <FriendRequest>[];
    for (final d in docs) {
      final r = FriendRequest.fromMap(d['id']?.toString() ?? '', d);
      if (r != null && r.isPending) out.add(r);
    }
    out.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return out;
  }

  /// Solicitudes pendientes que yo envié (las más nuevas primero).
  static Future<List<FriendRequest>> sentFriendRequests() async {
    if (!OnlineCommon.allowed || _me.isEmpty) return [];
    final docs = await OnlineCommon.call(() => _repo.queryDocs(
          'friend_requests',
          whereField: 'senderUid',
          isEqualTo: _me,
          limit: 30,
        ));
    if (docs == null) return [];
    final out = <FriendRequest>[];
    for (final d in docs) {
      final r = FriendRequest.fromMap(d['id']?.toString() ?? '', d);
      if (r != null && r.isPending) out.add(r);
    }
    out.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return out;
  }

  /// Confirmo una solicitud que me llegó: queda 'aceptada' y los
  /// dos quedamos amigos (el remitente entra en mi 'friends' y yo
  /// en la suya; esto último necesita la regla estrecha de
  /// 'friends' publicada en la consola — ver FIREBASE_SETUP.md).
  /// true si quedó confirmada.
  static Future<bool> acceptFriendRequest(String requestId) async {
    if (!OnlineCommon.allowed || _me.isEmpty || requestId.isEmpty) {
      return false;
    }
    final raw = await OnlineCommon.call(
        () => _repo.getDoc('friend_requests', requestId));
    final req = FriendRequest.fromMap(requestId, raw);
    if (req == null || !req.isPending || req.receiverUid != _me) {
      return false;
    }
    final accepted = await OnlineCommon.write(() => _repo.setDoc(
          'friend_requests',
          requestId,
          <String, dynamic>{'status': 'aceptada'},
        ));
    final mine = await OnlineCommon.write(
        () => _repo.addToArray('users', _me, 'friends', req.senderUid));
    // Espejo en el documento del remitente (regla estrecha):
    // best-effort — aunque tarde, la amistad ya es mutua por la
    // solicitud 'aceptada' (ver myFriends), así que el otro me ve
    // como amigo en cuanto lea.
    await OnlineCommon.write(
        () => _repo.addToArray('users', req.senderUid, 'friends', _me));
    return accepted && mine;
  }

  /// Elimino una solicitud que me llegó: queda 'rechazada' (el
  /// documento no se borra: las reglas lo prohíben) y desaparece
  /// de la lista. true si quedó rechazada.
  static Future<bool> rejectFriendRequest(String requestId) async {
    if (!OnlineCommon.allowed || _me.isEmpty || requestId.isEmpty) {
      return false;
    }
    final raw = await OnlineCommon.call(
        () => _repo.getDoc('friend_requests', requestId));
    final req = FriendRequest.fromMap(requestId, raw);
    if (req == null || !req.isPending || req.receiverUid != _me) {
      return false;
    }
    return OnlineCommon.write(() => _repo.setDoc(
          'friend_requests',
          requestId,
          <String, dynamic>{'status': 'rechazada'},
        ));
  }

  /// Cancelo una solicitud que yo envié: queda 'rechazada' y
  /// desaparece de las dos listas. true si quedó cancelada.
  static Future<bool> cancelFriendRequest(String requestId) async {
    if (!OnlineCommon.allowed || _me.isEmpty || requestId.isEmpty) {
      return false;
    }
    final raw = await OnlineCommon.call(
        () => _repo.getDoc('friend_requests', requestId));
    final req = FriendRequest.fromMap(requestId, raw);
    if (req == null || !req.isPending || req.senderUid != _me) {
      return false;
    }
    return OnlineCommon.write(() => _repo.setDoc(
          'friend_requests',
          requestId,
          <String, dynamic>{'status': 'rechazada'},
        ));
  }

  /// Reenvía las solicitudes que quedaron encoladas sin internet
  /// (se llama al abrir la app y al volver a primer plano).
  /// Devuelve cuántas se enviaron. Una encolada que ya no se puede
  /// enviar (usuario inexistente, ya amigos...) se descarta de la
  /// cola; si sigue sin internet, se queda para el próximo intento.
  static Future<int> retryPendingFriendRequests() async {
    if (!OnlineCommon.allowed || _me.isEmpty) return 0;
    final items = await OnlineCommon.pending(_pendingRequestsKey);
    var done = 0;
    for (var i = items.length - 1; i >= 0; i--) {
      final name = items[i]['username']?.toString() ?? '';
      if (name.isEmpty) {
        await OnlineCommon.removeAt(_pendingRequestsKey, i);
        continue;
      }
      final result = await sendFriendRequest(name);
      if (result != FriendRequestResult.queued) {
        await OnlineCommon.removeAt(_pendingRequestsKey, i);
        if (result == FriendRequestResult.sent) done++;
      }
    }
    return done;
  }

  // ---- Grupos ----

  /// Crea un grupo con [name] y un código de invitación único.
  /// Quedo como dueño y primer miembro. Null sin Google, sin
  /// nombre o sin internet.
  static Future<StudyGroup?> createGroup(String name) async {
    final cleanName = name.trim();
    if (!OnlineCommon.allowed || _me.isEmpty || cleanName.isEmpty) {
      return null;
    }
    String? code;
    for (var attempt = 0; attempt < 3 && code == null; attempt++) {
      final candidate = _randomCode();
      // Con la conexión lenta la consulta puede agotar sus 5 s:
      // se reintenta (Quemia 7.5) en vez de rendirse al primer
      // fallo y no crear el grupo. El código casi nunca choca
      // (6 caracteres de 31 símbolos), así que 3 intentos bastan.
      List<Map<String, dynamic>>? clash;
      for (var retry = 0; retry < 3 && clash == null; retry++) {
        clash = await OnlineCommon.call(() => _repo.queryDocs(
              'groups',
              whereField: 'code',
              isEqualTo: candidate,
              limit: 1,
            ));
      }
      if (clash == null) return null; // Sin red: no se crea a ciegas.
      if (clash.isEmpty) code = candidate;
    }
    if (code == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await OnlineCommon.call(() => _repo.createDoc(
          'groups',
          <String, dynamic>{
            'name': cleanName,
            'code': code,
            'ownerUid': _me,
            'memberUids': [_me],
            'createdAtMs': now,
          },
        ));
    if (id == null) return null;
    await OnlineCommon.write(
        () => _repo.addToArray('users', _me, 'groups', id));
    return StudyGroup(
      id: id,
      name: cleanName,
      code: code,
      ownerUid: _me,
      memberUids: [_me],
      createdAtMs: now,
    );
  }

  /// Me uno a un grupo con su código de invitación. Devuelve el
  /// grupo si entré (o ya estaba dentro); null si el código no
  /// existe, sin Google o sin internet.
  static Future<StudyGroup?> joinGroupByCode(String code) async {
    final clean = code.trim().toUpperCase();
    if (!OnlineCommon.allowed || _me.isEmpty || clean.isEmpty) return null;
    final docs = await OnlineCommon.call(() => _repo.queryDocs(
          'groups',
          whereField: 'code',
          isEqualTo: clean,
          limit: 1,
        ));
    if (docs == null || docs.isEmpty) return null;
    final group = StudyGroup.fromMap(docs.first);
    if (group == null) return null;
    if (!group.memberUids.contains(_me)) {
      final ok = await OnlineCommon.write(() =>
          _repo.addToArray('groups', group.id, 'memberUids', _me));
      if (!ok) return null;
    }
    await OnlineCommon.write(
        () => _repo.addToArray('users', _me, 'groups', group.id));
    final fresh = await getGroup(group.id);
    return fresh ?? group;
  }

  /// Mis grupos (los que guardé en mi doc). Vacío sin Google o sin
  /// internet: nunca un error.
  static Future<List<StudyGroup>> myGroups() async {
    if (!OnlineCommon.allowed || _me.isEmpty) return [];
    final myDoc = await OnlineCommon.call(() => _repo.getDoc('users', _me));
    final ids = _stringList(myDoc?['groups']);
    final out = <StudyGroup>[];
    for (final id in ids) {
      final doc = await OnlineCommon.call(() => _repo.getDoc('groups', id));
      final g = StudyGroup.fromMap(doc);
      if (g != null) out.add(g);
    }
    return out;
  }

  /// Un grupo por id. Null sin Google, si no existe o sin red.
  static Future<StudyGroup?> getGroup(String groupId) async {
    if (!OnlineCommon.allowed || groupId.isEmpty) return null;
    final doc =
        await OnlineCommon.call(() => _repo.getDoc('groups', groupId));
    return StudyGroup.fromMap(doc);
  }

  /// Progreso de los miembros del grupo (solo los que dieron
  /// permiso de compartir y no están baneados). Vacío sin Google
  /// o sin internet.
  static Future<List<FriendProgress>> groupMembersProgress(
      String groupId) async {
    if (!OnlineCommon.allowed || groupId.isEmpty) return [];
    final group = await getGroup(groupId);
    if (group == null) return [];
    final out = <FriendProgress>[];
    for (final uid in group.memberUids) {
      final doc = await OnlineCommon.call(() => _repo.getDoc('users', uid));
      final f = FriendProgress.fromUserDoc(doc);
      if (f != null) out.add(f);
    }
    out.sort((a, b) => b.points.compareTo(a.points));
    return out;
  }

  /// Salgo del grupo (saco mi uid de sus miembros y el grupo de
  /// mi lista). Si soy el dueño, el grupo queda sin dueño: los
  /// demás siguen dentro.
  static Future<bool> leaveGroup(String groupId) async {
    if (!OnlineCommon.allowed || _me.isEmpty || groupId.isEmpty) {
      return false;
    }
    final a = await OnlineCommon.write(() =>
        _repo.removeFromArray('groups', groupId, 'memberUids', _me));
    final b = await OnlineCommon.write(
        () => _repo.removeFromArray('users', _me, 'groups', groupId));
    return a && b;
  }

  static String _randomCode() {
    final rng = Random();
    final buf = StringBuffer();
    for (var i = 0; i < _codeLength; i++) {
      buf.write(_codeAlphabet[rng.nextInt(_codeAlphabet.length)]);
    }
    return buf.toString();
  }

  static List<String> _stringList(Object? raw) {
    final out = <String>[];
    if (raw is List) {
      for (final v in raw) {
        if (v is String && v.isNotEmpty) out.add(v);
      }
    }
    return out;
  }
}

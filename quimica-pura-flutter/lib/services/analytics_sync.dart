// Analítica y sincronización con Firebase (ronda fix8, versión 6.5,
// ampliada en la 7.0 con el acceso genérico a colecciones).
//
// Identidad: el documento de Firestore es 'users/<uid>', donde uid
// es el UID de Firebase Auth (sesión anónima automática al abrir la
// app, que persiste y NO cambia al enlazar con Google). El viejo id
// de shared_preferences ('melli_analytics_device_id') queda como id
// temporal: si ya existe (o Auth aún no está disponible offline), se
// usa mientras tanto, y en el primer inicio anónimo con éxito el
// documento temporal se copia una sola vez al documento del uid
// (migración best-effort).
//
// PUERTA DE IDENTIDAD (7.0, Kristian 09:19): para JUGAR online hay
// que tener la cuenta de Google vinculada. La sesión anónima sola
// NO habilita nada online: ni tabla, ni amigos, ni duelos, ni
// torneos, ni grupos, ni tienda, ni subida de progreso. Lo online
// comprueba primero [onlinePlayAllowed] y, sin Google, devuelve el
// estado "necesita Google" sin error ni excepción ([needsGoogle]).
// COMPARTIR AUTOMÁTICO (diseño 7.0, Kristian 11:09): con Google
// vinculada, el progreso se comparte automáticamente — respaldo Y
// tabla pública/friends, sin preguntar nada. El campo 'shared' del
// documento es siempre true. Los documentos ANTIGUOS con
// shared == false (de cuando compartir era una pregunta) siguen
// fuera de la tabla: la tabla los filtra, y el duelo no depende de
// la tabla (intercambia los resultados en su propio documento).
//
// Qué hace:
//   - Sube el progreso (usuario, niveles, puntos, racha, pista y
//     versión) a Firestore, colección 'users', documento = uid.
//     Solo con Google vinculada (puerta de identidad 7.0); el campo
//     'shared' es true: compartir automático (tabla pública).
//   - Lee si la cuenta está baneada ('banned' en su documento).
//   - Restaura el progreso del documento del uid actual
//     (restoreFromCloud): tras enlazar con Google o al iniciar
//     sesión en un teléfono nuevo. NO hay recuperación por nombre de
//     usuario (ese flujo se eliminó).
//   - Lee el ranking (top 100 por puntos, sin baneados y sin los
//     documentos antiguos con shared == false).
//   - Lee los ajustes remotos ('settings/app') y los aplica a los
//     valores de juego (ver remote_tuning.dart).
//   - (7.0) Acceso genérico a colecciones ([AnalyticsRepository]
//     ampliado: getDoc/setDoc/createDoc/queryDocs/watchDoc) para
//     duelos, torneos, amigos, grupos, reportes, avisos, tienda y
//     contenido remoto. Los servicios de la 7.0 lo usan a través de
//     [AnalyticsSync.repository].
//
// La app arranca 100% offline si Firebase falla: cada operación
// falla en silencio (try/catch en todo) y la subida se reintenta en
// la próxima apertura. Sin Google vinculada no se sube nada.
//
// Para que los tests corran sin Firebase real, el acceso a Firestore
// vive detrás de [AnalyticsRepository]: la app usa
// [FirestoreAnalyticsRepository] y los tests inyectan
// [InMemoryAnalyticsRepository] con
// [AnalyticsSync.setRepositoryForTests].
//
// REGLA 1 (Kristian, 6.5): lo online vive SOLO en Cuenta, el menú
// hamburguesa y sus propias pantallas (tabla de posiciones, inicio
// con Google). Este servicio NO se llama
// desde ninguna pantalla de estudio (Niveles, preguntas, Resolver,
// Aprender, Tabla periódica, simulador, calculadora): solo desde
// main() (arranque), Cuenta, onboarding y la tabla.
//
// REGLA 2 (Kristian, 6.5): sin internet no pasa nada malo. El estudio
// funciona 100% offline (contenido y progreso locales). CADA llamada
// a Firebase lleva timeout de 5 s y falla en silencio, sin diálogos
// ni banners. Cuando una subida falla, queda marcada como pendiente
// en shared_preferences y se reintenta sola al abrir la app y al
// volver a primer plano (retryPending). El flujo de Google por
// navegador es la excepción: lo maneja el usuario y no lleva timeout
// (cancelarlo es pulsar atrás); solo sus pasos automáticos previos
// (inicio anónimo) llevan los 5 s.
//
// Documento 'users/<uid>' (además de los campos base, se guardan
// 'levels' y 'practiceDays': sin ellos la restauración no podría
// devolver los niveles por tema ni la racha):
//   username: String (el nombre de UserPrefs, nunca se usa como id)
//   joinedAt: int (ms desde epoch, primera subida; se conserva el
//     más antiguo si el documento ya existe)
//   lastActive: int (ms desde epoch)
//   levelsPassed: {bach: int, uni: int}
//   levels: {bach: {tema: nivelDesbloqueado}, uni: {...}}
//   practiceDays: [ 'yyyy-MM-dd', ... ]
//   points: int
//   streak: int
//   track: 'bach' | 'uni'
//   appVersion: String (kAppVersion)
//   shared: bool (siempre true: compartir automático; un false
//     antiguo queda fuera de la tabla)
//   banned: bool (lo pone el creador desde el panel de admin)
//
// Hueco futuro (post-6.5, torneos): colección 'tournaments' (id,
// título, tema, fechas, preguntas, premio). No hay código de
// torneos en esta ronda.
//
// Esquema 7.0 (colecciones; todas con timeout de 5 s, fallo en
// silencio y reintento; las escrituras tocan SOLO el doc propio y
// el duelo/grupo propio, nunca el doc de otro usuario):
//   users/<uid>: ver arriba + 'purchases': [ids de cosméticos]
//   duels/<id>: {playerA, playerB, playerAName, playerBName,
//     questionIds: [5 ids gen:...], seed, status: waiting|playing|
//     finished|cancelled, createdAtMs, results: {uid: {correct,
//     timeMs, finishedAtMs, lastActivityMs}}, winnerUid,
//     forfeit: bool}
//   tournaments/<id>: {title, topic, startAtMs, endAtMs,
//     questionIds: [...], prizePoints, prizes: {1: 50, 2: 30, 3: 15}}
//   tournament_scores/<torneo>_<uid>: {tournamentId, uid, username,
//     bestScore, bestCorrect, updatedAtMs, lastActivityMs}
//   friends: en el propio doc 'users/<uid>': 'friends': [uid, ...]
//   groups/<id>: {name, code, ownerUid, memberUids: [...],
//     createdAtMs}
//   reports/<id>: {questionId, note, uid, username, createdAtMs}
//   announcements/<id>: {title, body, createdAtMs, active: bool}
//   levels/<tema>_<nivel>: {topic, level, questions: [{question,
//     options: [4], answer: int, difficulty, explanation}]}
//   support_messages/<id>: {authorUid, username, message, createdAt,
//     status: abierto|respondido, reply, replyAt}
//     (createdAt y replyAt son Timestamp; el usuario solo escribe
//     las suyas; el admin responde)
//   settings/app: {passRequired, maxLives, pointsCorrect, pointsWrong,
//     supportWhatsAppNumber, showWhatsAppInSupport}

// ---------------------------------------------------------------------------
// Repositorio genérico (7.0): los servicios online lo usan a través de
// AnalyticsSync.repository. La fusión (merge) es PROFUNDA en los dos
// lados: los mapas anidados se fusionan campo a campo (Firestore con
// SetOptions(merge: true) lo hace así), nunca se pisa el sub-mapa
// de otro jugador (p. ej. 'results' de un duelo: cada jugador
// escribe solo su entrada).

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'auth_service.dart';
import 'progress.dart';
import 'remote_tuning.dart';
import 'social_service.dart';
import 'update_check.dart';
import 'user_prefs.dart';

/// Una fila del ranking.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.deviceId,
    required this.username,
    required this.points,
    required this.levelsPassedTotal,
    required this.streak,
    this.avatarId,
  });

  final String deviceId;
  final String username;
  final int points;
  final int levelsPassedTotal;
  final int streak;

  /// Foto de avatar premium equipada ('avatar_dorado' |
  /// 'avatar_violeta' | 'avatar_teal'), o null: disco con inicial.
  final String? avatarId;

  /// Asset de la foto de avatar premium equipada, o null si usa el
  /// disco con la inicial (resuelve por el catálogo de la tienda).
  String? get avatarAsset => SocialService.avatarAssetForId(avatarId);
}

/// Acceso a los datos remotos, inyectable: la app usa Firestore y
/// los tests un falso en memoria.
abstract class AnalyticsRepository {
  Future<Map<String, dynamic>?> getUser(String deviceId);
  Future<void> setUser(String deviceId, Map<String, dynamic> data);
  Stream<List<Map<String, dynamic>>> leaderboard();
  Future<Map<String, dynamic>?> getSettings();

  /// Acceso genérico a cualquier colección (7.0). [getDoc] devuelve
  /// null si el documento no existe. [setDoc] fusiona en profundo
  /// con merge: true (por defecto) o sustituye el documento con
  /// merge: false. [createDoc] crea con id generado y lo devuelve.
  /// [queryDocs] filtra por igualdad en un campo, ordena y limita.
  /// [watchDoc] emite el documento (o null) y luego cada cambio.
  Future<Map<String, dynamic>?> getDoc(String collection, String docId);
  Future<void> setDoc(String collection, String docId,
      Map<String, dynamic> data,
      {bool merge = true});
  Future<String> createDoc(
      String collection, Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> queryDocs(
    String collection, {
    String? whereField,
    Object? isEqualTo,
    String? orderByField,
    bool descending = false,
    int? limit,
  });
  Stream<Map<String, dynamic>?> watchDoc(String collection, String docId);

  /// Añade [value] a la lista [field] del documento (sin duplicados)
  /// y quita [value] de la lista. En Firestore usan arrayUnion /
  /// arrayRemove, así dos teléfonos no se pisan la lista al
  /// escribir a la vez (p. ej. dos personas que se unen a un grupo).
  /// Si el documento no existe, lo crean con la lista.
  Future<void> addToArray(
      String collection, String docId, String field, Object value);
  Future<void> removeFromArray(
      String collection, String docId, String field, Object value);

  /// ¿Hay conexión con el servidor? Lee el documento desde el
  /// SERVIDOR (no de la caché local): true si responde (aunque el
  /// documento no exista), false si no hay red o no hay permiso.
  /// La UI lo usa para sus estados tranquilos sin internet.
  Future<bool> ping(String collection, String docId);
}

/// Implementación real con Cloud Firestore.
class FirestoreAnalyticsRepository implements AnalyticsRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  @override
  Future<Map<String, dynamic>?> getUser(String deviceId) async {
    final snap = await _db.collection('users').doc(deviceId).get();
    return snap.data();
  }

  @override
  Future<void> setUser(String deviceId, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(deviceId)
        .set(data, SetOptions(merge: true));
  }

  @override
  Stream<List<Map<String, dynamic>>> leaderboard() {
    return _db
        .collection('users')
        .orderBy('points', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => <String, dynamic>{'deviceId': d.id, ...d.data()})
            .toList());
  }

  @override
  Future<Map<String, dynamic>?> getSettings() async {
    final snap = await _db.collection('settings').doc('app').get();
    return snap.data();
  }

  @override
  Future<Map<String, dynamic>?> getDoc(
      String collection, String docId) async {
    final snap = await _db.collection(collection).doc(docId).get();
    final data = snap.data();
    return data == null ? null : <String, dynamic>{'id': snap.id, ...data};
  }

  @override
  Future<void> setDoc(String collection, String docId,
      Map<String, dynamic> data,
      {bool merge = true}) async {
    final ref = _db.collection(collection).doc(docId);
    if (merge) {
      await ref.set(data, SetOptions(merge: true));
    } else {
      await ref.set(data);
    }
  }

  @override
  Future<String> createDoc(
      String collection, Map<String, dynamic> data) async {
    final ref = await _db.collection(collection).add(data);
    return ref.id;
  }

  @override
  Future<List<Map<String, dynamic>>> queryDocs(
    String collection, {
    String? whereField,
    Object? isEqualTo,
    String? orderByField,
    bool descending = false,
    int? limit,
  }) async {
    Query<Map<String, dynamic>> q = _db.collection(collection);
    if (whereField != null) {
      q = q.where(whereField, isEqualTo: isEqualTo);
    }
    if (orderByField != null) {
      q = q.orderBy(orderByField, descending: descending);
    }
    if (limit != null) q = q.limit(limit);
    final snap = await q.get();
    return snap.docs
        .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
        .toList();
  }

  @override
  Stream<Map<String, dynamic>?> watchDoc(
      String collection, String docId) {
    return _db.collection(collection).doc(docId).snapshots().map((snap) {
      final data = snap.data();
      return data == null ? null : <String, dynamic>{'id': snap.id, ...data};
    });
  }

  @override
  Future<void> addToArray(
      String collection, String docId, String field, Object value) async {
    await _db.collection(collection).doc(docId).set(
      {field: FieldValue.arrayUnion([value])},
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> removeFromArray(
      String collection, String docId, String field, Object value) async {
    await _db.collection(collection).doc(docId).set(
      {field: FieldValue.arrayRemove([value])},
      SetOptions(merge: true),
    );
  }

  @override
  Future<bool> ping(String collection, String docId) async {
    try {
      await _db
          .collection(collection)
          .doc(docId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Fusión profunda de mapas (la misma que hace Firestore con
/// SetOptions(merge: true)): los mapas anidados se fusionan campo a
/// campo; el resto de valores (listas incluidas) se sustituyen.
Map<String, dynamic> deepMergeDocs(
    Map<String, dynamic> base, Map<String, dynamic> patch) {
  final out = Map<String, dynamic>.from(base);
  patch.forEach((key, value) {
    final existing = out[key];
    if (value is Map && existing is Map) {
      out[key] = deepMergeDocs(Map<String, dynamic>.from(existing),
          Map<String, dynamic>.from(value));
    } else {
      out[key] = value;
    }
  });
  return out;
}

/// Falso en memoria para los tests (y para depurar sin Firebase).
class InMemoryAnalyticsRepository implements AnalyticsRepository {
  /// Documento por deviceId.
  final Map<String, Map<String, dynamic>> users = {};

  /// Documento 'settings/app' (null = no existe).
  Map<String, dynamic>? settings;

  /// Si es true, getSettings lanza (para probar el fallback local).
  bool failSettings = false;

  /// Documentos por colección (la colección 'users' vive en [users]
  /// para que los tests viejos la sigan tocando directamente).
  final Map<String, Map<String, Map<String, dynamic>>> docs = {};

  /// Si es true, TODAS las llamadas lanzan (redirige a los tests de
  /// fallo de red de los servicios 7.0).
  bool failAll = false;

  /// Si es true, las escrituras cuelgan para siempre (modo avión con
  /// red colgada: los servicios deben cortar con timeout).
  bool hangWrites = false;

  int _createCounter = 0;

  final Map<String, StreamController<Map<String, dynamic>?>> _watchers =
      {};

  Map<String, Map<String, dynamic>> _collection(String collection) {
    if (collection == 'users') return users;
    return docs.putIfAbsent(collection, () => {});
  }

  void _notify(String collection, String docId) {
    final c = _watchers['$collection/$docId'];
    if (c != null && !c.isClosed) {
      final cur = _collection(collection)[docId];
      c.add(cur == null
          ? null
          : <String, dynamic>{'id': docId, ...cur});
    }
  }

  @override
  Future<Map<String, dynamic>?> getUser(String deviceId) async {
    if (failAll) throw StateError('fake offline');
    return users[deviceId] == null
        ? null
        : Map<String, dynamic>.from(users[deviceId]!);
  }

  @override
  Future<void> setUser(String deviceId, Map<String, dynamic> data) async {
    if (failAll) throw StateError('fake offline');
    if (hangWrites) await Completer<void>().future;
    final old = users[deviceId];
    users[deviceId] = old == null
        ? Map<String, dynamic>.from(data)
        : deepMergeDocs(old, data);
    _notify('users', deviceId);
  }

  @override
  Stream<List<Map<String, dynamic>>> leaderboard() async* {
    final docs = users.entries
        .map((e) => <String, dynamic>{'deviceId': e.key, ...e.value})
        .toList();
    docs.sort((a, b) => _asInt(b['points']).compareTo(_asInt(a['points'])));
    yield docs.take(100).toList();
  }

  @override
  Future<Map<String, dynamic>?> getSettings() async {
    if (failSettings) throw StateError('fake settings failure');
    return settings == null ? null : Map<String, dynamic>.from(settings!);
  }

  @override
  Future<Map<String, dynamic>?> getDoc(
      String collection, String docId) async {
    if (failAll) throw StateError('fake offline');
    final doc = _collection(collection)[docId];
    return doc == null
        ? null
        : <String, dynamic>{'id': docId, ...doc};
  }

  @override
  Future<void> setDoc(String collection, String docId,
      Map<String, dynamic> data,
      {bool merge = true}) async {
    if (failAll) throw StateError('fake offline');
    if (hangWrites) await Completer<void>().future;
    final col = _collection(collection);
    final old = col[docId];
    if (merge && old != null) {
      col[docId] = deepMergeDocs(old, data);
    } else {
      col[docId] = Map<String, dynamic>.from(data);
    }
    _notify(collection, docId);
  }

  @override
  Future<String> createDoc(
      String collection, Map<String, dynamic> data) async {
    if (failAll) throw StateError('fake offline');
    if (hangWrites) await Completer<void>().future;
    final id = 'fake-${++_createCounter}';
    _collection(collection)[id] = Map<String, dynamic>.from(data);
    _notify(collection, id);
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> queryDocs(
    String collection, {
    String? whereField,
    Object? isEqualTo,
    String? orderByField,
    bool descending = false,
    int? limit,
  }) async {
    if (failAll) throw StateError('fake offline');
    var rows = _collection(collection).entries.map((e) {
      return <String, dynamic>{'id': e.key, ...e.value};
    }).toList();
    if (whereField != null) {
      rows = rows.where((r) => r[whereField] == isEqualTo).toList();
    }
    if (orderByField != null) {
      int cmp(Map<String, dynamic> a, Map<String, dynamic> b) {
        final x = a[orderByField];
        final y = b[orderByField];
        final c = x is num && y is num
            ? x.compareTo(y)
            : '${x ?? ''}'.compareTo('${y ?? ''}');
        return descending ? -c : c;
      }

      rows.sort(cmp);
    }
    if (limit != null) rows = rows.take(limit).toList();
    return rows;
  }

  @override
  Stream<Map<String, dynamic>?> watchDoc(
      String collection, String docId) {
    final key = '$collection/$docId';
    var c = _watchers[key];
    if (c == null) {
      late final StreamController<Map<String, dynamic>?> ctrl;
      ctrl = StreamController<Map<String, dynamic>?>.broadcast(
        onListen: () {
          final cur = _collection(collection)[docId];
          ctrl.add(cur == null
              ? null
              : <String, dynamic>{'id': docId, ...cur});
        },
      );
      _watchers[key] = ctrl;
      c = ctrl;
    }
    return c.stream;
  }

  @override
  Future<void> addToArray(
      String collection, String docId, String field, Object value) async {
    if (failAll) throw StateError('fake offline');
    if (hangWrites) await Completer<void>().future;
    final col = _collection(collection);
    final doc = col.putIfAbsent(docId, () => <String, dynamic>{});
    final raw = doc[field];
    final list = raw is List ? List<Object?>.from(raw) : <Object?>[];
    if (!list.contains(value)) list.add(value);
    doc[field] = list;
    _notify(collection, docId);
  }

  @override
  Future<void> removeFromArray(
      String collection, String docId, String field, Object value) async {
    if (failAll) throw StateError('fake offline');
    if (hangWrites) await Completer<void>().future;
    final col = _collection(collection);
    final doc = col[docId];
    if (doc == null) return;
    final raw = doc[field];
    if (raw is List) {
      doc[field] = List<Object?>.from(raw)..remove(value);
      _notify(collection, docId);
    }
  }

  @override
  Future<bool> ping(String collection, String docId) async {
    if (failAll) return false;
    return true;
  }
}

int _asInt(Object? v) => (v as num?)?.toInt() ?? 0;

class AnalyticsSync {
  AnalyticsSync._();

  static const _kDeviceIdKey = 'melli_analytics_device_id';
  static const _kJoinedAtKey = 'melli_analytics_joined_at_ms';
  static const _kMigratedKey = 'melli_analytics_migrated_to_uid';

  /// Subida pendiente de reintento (Regla 2): true cuando una subida
  /// o respaldo falló (sin internet, timeout). Se reintenta al abrir
  /// la app y al volver a primer plano (retryPending).
  static const _kPendingUploadKey = 'melli_analytics_pending_upload';

  /// Mínimo entre subidas (salvo force): 60 s. Vale para la subida
  /// compartida y para el respaldo (cada una con su propio reloj).
  static const _kMinUploadGap = Duration(seconds: 60);

  static AnalyticsRepository? _repositoryOverride;

  /// La app usa Firestore; los tests inyectan el falso en memoria.
  static AnalyticsRepository get _repository =>
      _repositoryOverride ?? FirestoreAnalyticsRepository();

  /// Repositorio que usan los servicios online de la 7.0 (duelos,
  /// torneos, amigos, grupos, reportes, avisos, tienda, contenido).
  static AnalyticsRepository get repository => _repository;

  /// Puerta de identidad (7.0, Kristian 09:19): para JUGAR online
  /// hay que tener la cuenta de Google vinculada. La sesión anónima
  /// sola NO habilita nada online: ni tabla, ni amigos, ni duelos,
  /// ni torneos, ni grupos, ni tienda, ni subida de progreso. Cada
  /// servicio online lo comprueba primero y, si no hay Google,
  /// devuelve el estado "necesita Google" sin error ni excepción.
  static bool get onlinePlayAllowed => AuthService.isGoogleLinked;

  /// La UI lo usa para pedir el enlace con Google.
  static bool get needsGoogle => !onlinePlayAllowed;

  /// main() la llama cuando Firebase.initializeApp() terminó bien.
  static bool _firebaseReady = false;

  static void markFirebaseReady() => _firebaseReady = true;

  static bool get firebaseReady => _firebaseReady;

  /// ¿Se puede hablar con el servidor? Firebase listo, o un
  /// repositorio inyectado (tests).
  static bool get _ready => _firebaseReady || _repositoryOverride != null;

  /// Id temporal de antes (uuid en shared_preferences). Solo se usa
  /// mientras Auth no tenga uid (offline al abrir); en cuanto hay
  /// uid, manda el uid.
  static String _legacyDeviceId = '';
  static DateTime? _lastUpload;

  /// Identidad del documento de Firestore: el UID de Firebase Auth
  /// si lo hay; si no, el id temporal guardado. NUNCA el nombre de
  /// usuario.
  static String get deviceId {
    final uid = AuthService.currentUid;
    if (uid != null && uid.isNotEmpty) return uid;
    return _legacyDeviceId;
  }

  /// ¿La cuenta está baneada? La UI lo escucha; fetchBanned() lo
  /// actualiza. Empieza en false (sin bloqueo hasta comprobar).
  static final ValueNotifier<bool> bannedNotifier = ValueNotifier(false);

  /// Lee el id temporal (lo crea una vez si no
  /// existe), y migra el documento temporal al del uid si ya hay
  /// sesión anónima. No toca la red si no hay servidor: funciona
  /// 100% offline. main() llama antes a AuthService.ensureAnonymous().
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_kDeviceIdKey);
      if (id == null || id.isEmpty) {
        id = const Uuid().v4();
        await prefs.setString(_kDeviceIdKey, id);
      }
      _legacyDeviceId = id;
    } catch (_) {
      // Sin almacenamiento: sin id, no se sube nada.
      _legacyDeviceId = '';
    }
    await _migrateLegacyDocToUid();
  }

  /// Migración best-effort, una sola vez: si ya existe un documento
  /// bajo el id temporal y ahora hay uid, se copia al documento del
  /// uid. Corre antes de la primera subida con uid, así que el
  /// documento del uid aún está vacío. Silencio total si falla: se
  /// reintenta en la próxima apertura.
  static Future<void> _migrateLegacyDocToUid() async {
    final uid = AuthService.currentUid;
    if (!_ready || uid == null || uid.isEmpty) return;
    if (uid == _legacyDeviceId) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kMigratedKey) == true) return;
      final legacyDoc = await _repository
          .getUser(_legacyDeviceId)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (legacyDoc != null && legacyDoc.isNotEmpty) {
        await _repository
            .setUser(uid, legacyDoc)
            .timeout(const Duration(seconds: 5));
      }
      await prefs.setBool(_kMigratedKey, true);
    } catch (_) {
      // Sin red o sin permiso: se reintenta en la próxima apertura.
    }
  }

  /// ¿Hay una subida pendiente de reintento? (Regla 2.)
  static Future<bool> _isUploadPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kPendingUploadKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _markPending(bool v) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPendingUploadKey, v);
    } catch (_) {
      // Sin almacenamiento no se puede marcar: se reintentará al abrir.
    }
  }

  /// Reintenta la subida que quedó pendiente (Regla 2): la llama
  /// main() al abrir la app (vía uploadProgress/backupToCloud) y al
  /// volver a primer plano. Con force, para no esperar al debounce
  /// de 60 s. Si ya no hay nada que subir (sin permiso ni Google),
  /// limpia el flag para no reintentar en vano.
  static Future<void> retryPending() async {
    if (!await _isUploadPending()) return;
    await uploadProgress(force: true);
    if (!AuthService.isGoogleLinked) {
      // Sin Google vinculada no hay nada que subir: se limpia el
      // flag para no reintentar en vano.
      await _markPending(false);
    }
  }

  /// Foto del progreso local para subir (compartida y respaldo usan
  /// la misma). 'shared' es siempre true: compartir automático con
  /// Google vinculada; sin Google no se sube nada.
  static Future<Map<String, dynamic>?> _buildSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var joinedAtMs = prefs.getInt(_kJoinedAtKey);
      final now = DateTime.now();
      joinedAtMs ??= now.millisecondsSinceEpoch;
      await prefs.setInt(_kJoinedAtKey, joinedAtMs);
      final levels = await _levelsByTrack();
      return <String, dynamic>{
        'username': UserPrefs.userName,
        'joinedAt': joinedAtMs,
        'lastActive': now.millisecondsSinceEpoch,
        'levelsPassed': _levelsPassed(levels),
        'levels': levels,
        'practiceDays': ProgressService.instance.practiceDays.toList(),
        'points': ProgressService.instance.points,
        'streak': ProgressService.instance.streakNow,
        'track': UserPrefs.track,
        'appVersion': kAppVersion,
        'shared': true,
      };
    } catch (_) {
      return null;
    }
  }

  /// Escribe la foto en 'users/<deviceId>' (merge). Si el documento
  /// ya existe, se fusiona con lo que hay: joinedAt conserva el más
  /// antiguo, puntos y niveles por tema quedan en el mayor, y los
  /// días de práctica se unen (la racha sale de esa unión). Así dos
  /// teléfonos con la misma cuenta no se pisan el progreso.
  static Future<void> _writeSnapshot(Map<String, dynamic> data) async {
    final id = deviceId;
    if (id.isEmpty) return;
    try {
      final existing = await _repository
          .getUser(id)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (existing != null && existing.isNotEmpty) {
        final remoteJoined = _asInt(existing['joinedAt']);
        if (remoteJoined > 0) {
          final localJoined = _asInt(data['joinedAt']);
          if (localJoined == 0 || remoteJoined < localJoined) {
            data['joinedAt'] = remoteJoined;
          }
        }
        final remotePoints = _asInt(existing['points']);
        final localPoints = _asInt(data['points']);
        if (remotePoints > localPoints) data['points'] = remotePoints;
        final mergedDays = <String>{};
        final localDays = data['practiceDays'];
        if (localDays is List) {
          for (final d in localDays) {
            if (d is String) mergedDays.add(d);
          }
        }
        final remoteDays = existing['practiceDays'];
        if (remoteDays is List) {
          for (final d in remoteDays) {
            if (d is String) mergedDays.add(d);
          }
        }
        data['practiceDays'] = mergedDays.toList();
        data['streak'] =
            ProgressService.currentStreak(mergedDays, DateTime.now());
        final mergedLevels =
            _mergeLevels(data['levels'], existing['levels']);
        data['levels'] = mergedLevels;
        data['levelsPassed'] = _levelsPassed(mergedLevels);
      }
    } catch (_) {
      // Sin lectura previa: se escribe la foto local tal cual.
    }
    // Timeout de 5 s (Regla 2): sin internet la escritura queda
    // encolada en el SDK, pero este intento se da por fallido y
    // queda pendiente de reintento. Si la escritura llega, se
    // limpia el flag (merge: escribir dos veces es inofensivo).
    await _repository
        .setUser(id, data)
        .timeout(const Duration(seconds: 5));
    await _markPending(false);
  }

  /// Niveles por tema y pista como mapa tipado, desde cualquier mapa
  /// (foto local o documento remoto).
  static Map<String, Map<String, int>> _asLevelsMap(Object? raw) {
    final out = <String, Map<String, int>>{};
    if (raw is Map) {
      raw.forEach((track, topics) {
        if (topics is Map) {
          final m = <String, int>{};
          topics.forEach((topic, level) {
            if (level is num) m[topic.toString()] = level.toInt();
          });
          out[track.toString()] = m;
        }
      });
    }
    return out;
  }

  /// Fusión de niveles por tema: por tema queda el nivel mayor.
  static Map<String, Map<String, int>> _mergeLevels(
      Object? local, Object? remote) {
    final out = _asLevelsMap(local);
    _asLevelsMap(remote).forEach((track, topics) {
      final m = out.putIfAbsent(track, () => <String, int>{});
      topics.forEach((topic, level) {
        if (level > (m[topic] ?? 1)) m[topic] = level;
      });
    });
    return out;
  }

  /// Sube el progreso a 'users/<uid>' (merge, shared = true:
  /// compartir automático). Mínimo 60 s entre subidas, salvo
  /// [force]. Silencio total ante fallos y reintento en la próxima
  /// apertura.
  ///
  /// PUERTA DE IDENTIDAD (7.0): solo con Google vinculada. Con la
  /// sesión anónima sola NO se sube nada; cuando se vincula Google,
  /// el uid no cambia y la subida empieza.
  /// No-op sin Google, sin id o si Firebase no está listo.
  static Future<void> uploadProgress({bool force = false}) async {
    if (!_ready || deviceId.isEmpty || !AuthService.isGoogleLinked) return;
    final now = DateTime.now();
    if (!force &&
        _lastUpload != null &&
        now.difference(_lastUpload!) < _kMinUploadGap) {
      return;
    }
    try {
      final data = await _buildSnapshot();
      if (data == null) return;
      // Se marca el intento ANTES de escribir: si la escritura queda
      // pendiente sin internet, no se apilan subidas encima.
      _lastUpload = now;
      await _writeSnapshot(data);
    } catch (_) {
      // Silencio: queda pendiente y la próxima apertura (o el
      // próximo reintento con force) lo vuelve a intentar.
      await _markPending(true);
    }
  }

  /// Respaldo (alias histórico): en la 7.0 el respaldo ES la
  /// subida — con Google vinculada, uploadProgress escribe la misma
  /// foto con shared = true (compartir automático). Se conserva el
  /// nombre para no tocar main() ni los tests viejos.
  static Future<void> backupToCloud({bool force = false}) async =>
      uploadProgress(force: force);

  /// Niveles desbloqueados por tema y por pista, desde lo guardado
  /// (sin cambiar la pista actual).
  static Future<Map<String, Map<String, int>>> _levelsByTrack() async {
    final out = <String, Map<String, int>>{};
    for (final t in [ProgressService.trackBach, ProgressService.trackUni]) {
      final snap = await ProgressService.trackSnapshot(t);
      out[t] = Map<String, int>.from(snap.levels);
    }
    return out;
  }

  /// Niveles pasados por pista: por tema, (nivel desbloqueado − 1)
  /// con tope en los niveles que tiene el tema. Un tema nunca jugado
  /// (sin entrada) suma 0.
  static Map<String, int> _levelsPassed(
      Map<String, Map<String, int>> levels) {
    final out = <String, int>{};
    levels.forEach((track, byTopic) {
      var total = 0;
      byTopic.forEach((topic, unlocked) {
        final passed = (unlocked - 1)
            .clamp(0, ProgressService.levelCountForTopic(topic));
        total += passed;
      });
      out[track] = total;
    });
    return out;
  }

  /// Lee el campo 'banned' del propio documento. true si la cuenta
  /// está baneada. También actualiza [bannedNotifier]. Si falla la
  /// lectura, devuelve el último valor conocido (empieza en false).
  static Future<bool> fetchBanned() async {
    if (!_ready || deviceId.isEmpty) return bannedNotifier.value;
    try {
      final doc = await _repository
          .getUser(deviceId)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      final banned = doc?['banned'] == true;
      bannedNotifier.value = banned;
      return banned;
    } catch (_) {
      return bannedNotifier.value;
    }
  }

  /// Descarga el documento del uid actual y aplica su progreso al
  /// progreso local (niveles/puntos/racha, la misma lógica de
  /// applyRecovered). Se llama tras enlazar con Google o al iniciar
  /// sesión en un teléfono nuevo. Devuelve true si encontró y aplicó
  /// un documento. No-op sin servidor.
  static Future<bool> restoreFromCloud() async {
    if (!_ready || deviceId.isEmpty) return false;
    try {
      final doc = await _repository
          .getUser(deviceId)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (doc == null || doc.isEmpty) return false;
      await applyRecovered(doc);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Enlaza Google a la sesión actual y, solo si el enlace fue una
  /// RECUPERACIÓN (el uid cambió a la cuenta de Google: teléfono
  /// nuevo), restaura el progreso de la nube. Tras un enlace normal
  /// el uid no cambia y no hace falta restaurar. Después respalda lo
  /// fusionado. Lo llama Cuenta tras el botón de Google. Devuelve
  /// true si el enlace salió bien, false si falló (sin lanzar).
  static Future<bool> linkGoogleAndRestore() async {
    final uidBefore = AuthService.currentUid;
    final ok = await AuthService.linkWithGoogle();
    if (!ok) return false;
    final uidAfter = AuthService.currentUid;
    if (uidAfter != null && uidAfter != uidBefore) {
      await restoreFromCloud();
    }
    await uploadProgress(force: true);
    return true;
  }

  /// Entra con Google (teléfono nuevo) y restaura el progreso de la
  /// nube. Después sube la foto fusionada para que la nube quede al
  /// día. Devuelve true si la sesión salió bien.
  static Future<bool> signInGoogleAndRestore() async {
    final ok = await AuthService.signInWithGoogle();
    if (!ok) return false;
    await restoreFromCloud();
    await uploadProgress(force: true);
    return true;
  }

  /// Aplica un progreso recuperado ([restoreFromCloud]) al progreso
  /// local: niveles por tema, puntos y días de práctica (racha).
  /// Solo suma (ver ProgressService.applyRecoveredData): nunca borra
  /// ni baja el progreso que ya hay en el teléfono.
  static Future<void> applyRecovered(Map<String, dynamic> data) async {
    try {
      final levelsByTrack = <String, Map<String, int>>{};
      final levelsRaw = data['levels'];
      if (levelsRaw is Map) {
        levelsRaw.forEach((track, topics) {
          if (topics is Map) {
            final m = <String, int>{};
            topics.forEach((topic, level) {
              if (level is num) m[topic.toString()] = level.toInt();
            });
            levelsByTrack[track.toString()] = m;
          }
        });
      }
      final points = (data['points'] as num?)?.toInt();
      final days = <String>[];
      final rawDays = data['practiceDays'];
      if (rawDays is List) {
        for (final d in rawDays) {
          if (d is String) days.add(d);
        }
      }
      await ProgressService.applyRecoveredData(
        levelsByTrack: levelsByTrack,
        points: points,
        practiceDays: days,
      );
    } catch (_) {
      // Datos rotos: no se aplica nada, el progreso local sigue.
    }
  }

  /// Ranking: top 100 por puntos, sin los baneados y sin los
  /// documentos antiguos marcados como privados (shared == false,
  /// de cuando compartir era una pregunta), filtrados en el teléfono.
  /// Silencio ante fallos: emite una lista vacía. Sin Google
  /// vinculada no hay tabla (puerta de identidad 7.0): lista vacía.
  static Stream<List<LeaderboardEntry>> leaderboardStream() {
    if (!_ready || !onlinePlayAllowed) {
      return Stream<List<LeaderboardEntry>>.value(const []);
    }
    try {
      return _repository.leaderboard().map((docs) {
        final entries = <LeaderboardEntry>[];
        for (final doc in docs) {
          if (doc['banned'] == true) continue;
          if (doc['shared'] == false) continue;
          entries.add(LeaderboardEntry(
            deviceId: doc['deviceId']?.toString() ?? '',
            username: doc['username']?.toString() ?? '',
            points: _asInt(doc['points']),
            levelsPassedTotal: _levelsTotal(doc['levelsPassed']),
            streak: _asInt(doc['streak']),
            avatarId: doc['equippedAvatar']?.toString(),
          ));
        }
        return entries;
      }).transform(
        StreamTransformer<List<LeaderboardEntry>,
            List<LeaderboardEntry>>.fromHandlers(
          handleError: (error, stackTrace, sink) {
            sink.add(const <LeaderboardEntry>[]);
          },
        ),
      );
    } catch (_) {
      return Stream<List<LeaderboardEntry>>.value(const []);
    }
  }

  static int _levelsTotal(Object? v) {
    if (v is num) return v.toInt();
    if (v is Map) {
      var total = 0;
      v.forEach((_, n) {
        if (n is num) total += n.toInt();
      });
      return total;
    }
    return 0;
  }

  /// Lee el documento 'settings/app' de Firestore. {} si falla o si
  /// no existe. Timeout de 5 s (Regla 2): sin internet no cuelga.
  static Future<Map<String, dynamic>> fetchRemoteSettings() async {
    if (!_ready) return {};
    try {
      final doc = await _repository
          .getSettings()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      return doc ?? {};
    } catch (_) {
      return {};
    }
  }

  /// Aplica los ajustes remotos a los valores de juego (umbral de
  /// paso, puntos por dificultad, vidas máximas), con los valores
  /// locales como fallback: si la descarga falla, mandan los locales
  /// (ver RemoteTuning).
  static Future<void> applyRemoteSettings() async {
    final settings = await fetchRemoteSettings();
    RemoteTuning.apply(settings);
  }

  /// Solo para tests: inyecta un repositorio (el falso en memoria).
  @visibleForTesting
  static void setRepositoryForTests(AnalyticsRepository repo) {
    _repositoryOverride = repo;
  }

  /// Solo para tests: limpia id temporal, última
  /// subida/respaldo, repositorio inyectado y el aviso de baneo.
  @visibleForTesting
  static void resetForTests() {
    _repositoryOverride = null;
    _firebaseReady = false;
    _legacyDeviceId = '';
    _lastUpload = null;
    bannedNotifier.value = false;
  }
}

// Acceso a Firestore detrás de interfaces inyectables.
//
// - Las pantallas y los servicios solo conocen las interfaces.
// - [FirestoreUsersRepository], [FirestoreAdminsRepository] y
//   [FirestoreSettingsRepository] son la implementación real.
// - [FakeUsersRepository], [FakeAdminsRepository] y [FakeSettingsRepository]
//   son fakes en memoria para que los tests corran sin Firebase real.
// - [AdminService] es la capa que hace cumplir la matriz de permisos: ninguna
//   operación sensible llega al repositorio si el admin actual no tiene el
//   permiso correspondiente.
//
// Robustez offline: la app es online por naturaleza, pero SIN INTERNET NO
// PASA NADA MALO. Todas las llamadas a Firestore llevan timeout (20 s) y
// las pantallas atrapan el error y muestran un estado tranquilo
// ("Sin conexión" + botón Reintentar): ningún diálogo de error, ningún
// banner rojo, ningún bloqueo ni cierre. Ver [CalmOfflineState] en
// screens.dart y test/offline_test.dart.

import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';

/// Timeout de cada llamada a Firestore: sin conexión, la llamada no puede
/// colgarse eternamente; la UI muestra "Sin conexión" y permite reintentar.
const _firestoreTimeout = Duration(seconds: 20);

Future<T> _withTimeout<T>(Future<T> future) =>
    future.timeout(_firestoreTimeout);

/// Se lanza cuando el admin actual intenta una acción sin permiso.
class PermissionDenied implements Exception {
  PermissionDenied(this.message);
  final String message;
  @override
  String toString() => 'PermissionDenied: $message';
}

// ---------------------------------------------------------------------------
// Usuarios
// ---------------------------------------------------------------------------

abstract class UsersRepository {
  Future<List<AppUser>> listUsers();
  Future<AppUser?> getUser(String id);
  Future<void> setBan(String id, {required bool banned, String reason = ''});
}

class FirestoreUsersRepository implements UsersRepository {
  FirestoreUsersRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<List<AppUser>> listUsers() async {
    final snap = await _withTimeout(_db.collection('users').get());
    final users = snap.docs.map((d) => AppUser.fromDoc(d.id, d.data())).toList()
      ..sort((a, b) => b.joinedAt.compareTo(a.joinedAt));
    return users;
  }

  @override
  Future<AppUser?> getUser(String id) async {
    final doc = await _withTimeout(_db.collection('users').doc(id).get());
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromDoc(doc.id, doc.data()!);
  }

  @override
  Future<void> setBan(
    String id, {
    required bool banned,
    String reason = '',
  }) async {
    await _withTimeout(
      _db.collection('users').doc(id).update(<String, dynamic>{
        'banned': banned,
        'bannedReason': reason,
        if (banned) 'bannedAt': FieldValue.serverTimestamp(),
        if (!banned) 'bannedAt': FieldValue.delete(),
      }),
    );
  }
}

/// Fake en memoria de la colección 'users'.
class FakeUsersRepository implements UsersRepository {
  FakeUsersRepository([List<AppUser>? seed]) {
    if (seed != null) {
      for (final u in seed) {
        _users[u.id] = u;
      }
    }
  }

  final Map<String, AppUser> _users = {};

  void add(AppUser user) => _users[user.id] = user;

  @override
  Future<List<AppUser>> listUsers() async {
    final users = _users.values.toList()
      ..sort((a, b) => b.joinedAt.compareTo(a.joinedAt));
    return users;
  }

  @override
  Future<AppUser?> getUser(String id) async => _users[id];

  @override
  Future<void> setBan(
    String id, {
    required bool banned,
    String reason = '',
  }) async {
    final user = _users[id];
    if (user == null) return;
    _users[id] = user.copyWith(
      banned: banned,
      bannedReason: reason,
      bannedAt: banned ? DateTime.now() : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Administradores
// ---------------------------------------------------------------------------

abstract class AdminsRepository {
  /// Resuelve el registro de admin para un usuario autenticado.
  ///
  /// 1. Busca el documento con id = [uid].
  /// 2. Si no existe, busca una invitación pendiente por [email] y la adopta:
  ///    crea el documento con el uid y borra el pendiente.
  /// Devuelve null si no hay ningún registro: el usuario NO es admin.
  Future<AdminRecord?> resolveAdmin({
    required String uid,
    required String email,
  });

  /// Crea (o devuelve) el documento del dueño. Solo para la cuenta
  /// configurada como dueña ([kOwnerEmail]): si el documento no existe lo
  /// crea con role 'owner' y todos los permisos; si existe lo devuelve (y
  /// lo promueve a dueño si no lo era). Así el primer inicio de sesión del
  /// dueño no necesita ningún alta manual previa.
  Future<AdminRecord> ensureOwner({
    required String uid,
    required String email,
    String displayName = '',
  });

  Future<List<AdminRecord>> listAdmins();

  /// Crea una invitación pendiente por correo (id = correo en minúsculas).
  Future<AdminRecord> inviteByEmail({
    required String email,
    String displayName = '',
    required String createdBy,
  });

  Future<void> updatePermissions(String uid, AdminPermissions permissions);
  Future<void> deleteAdmin(String uid);

  /// Guarda el token FCM del admin (para los pushes): escribe 'fcmToken' y
  /// 'fcmTokenUpdatedAt' (ms desde epoch) en su documento de 'admins'.
  /// Solo la llama PushService después de que el admin ya está verificado
  /// (desde HomeShell): escribirlo antes crearía con set-merge un documento
  /// parcial que resolveAdmin leería como admin válido. Ver push_service.dart.
  Future<void> saveFcmToken(String uid, String token);
}

class FirestoreAdminsRepository implements AdminsRepository {
  FirestoreAdminsRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('admins');

  @override
  Future<AdminRecord?> resolveAdmin({
    required String uid,
    required String email,
  }) async {
    final direct = await _withTimeout(_col.doc(uid).get());
    if (direct.exists && direct.data() != null) {
      return AdminRecord.fromDoc(direct.id, direct.data()!);
    }
    // Invitación pendiente por correo: adoptarla.
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final pending = await _withTimeout(_col.doc(normalized).get());
    if (!pending.exists || pending.data() == null) return null;
    final record = AdminRecord.fromDoc(pending.id, pending.data()!);
    if (!record.pending) return null;
    final adopted = AdminRecord(
      uid: uid,
      email: record.email,
      displayName: record.displayName,
      role: 'admin',
      permissions: record.permissions,
      pending: false,
      createdAt: record.createdAt,
      createdBy: record.createdBy,
    );
    await _withTimeout(
      _db.runTransaction((tx) async {
        tx.set(_col.doc(uid), adopted.toMap());
        tx.delete(_col.doc(normalized));
      }),
    );
    return adopted;
  }

  @override
  Future<AdminRecord> ensureOwner({
    required String uid,
    required String email,
    String displayName = '',
  }) async {
    final normalized = email.trim().toLowerCase();
    final direct = await _withTimeout(_col.doc(uid).get());
    if (direct.exists && direct.data() != null) {
      final existing = AdminRecord.fromDoc(direct.id, direct.data()!);
      if (existing.isOwner) return existing;
      final promoted = AdminRecord(
        uid: uid,
        email: normalized,
        displayName:
            displayName.isEmpty ? existing.displayName : displayName,
        role: 'owner',
        permissions: AdminPermissions.all,
        createdAt: existing.createdAt,
        createdBy: 'bootstrap',
      );
      await _withTimeout(_col.doc(uid).set(promoted.toMap()));
      return promoted;
    }
    final owner = AdminRecord(
      uid: uid,
      email: normalized,
      displayName: displayName,
      role: 'owner',
      permissions: AdminPermissions.all,
      createdAt: DateTime.now(),
      createdBy: 'bootstrap',
    );
    await _withTimeout(_col.doc(uid).set(owner.toMap()));
    return owner;
  }

  @override
  Future<List<AdminRecord>> listAdmins() async {
    final snap = await _withTimeout(_col.get());
    final admins =
        snap.docs.map((d) => AdminRecord.fromDoc(d.id, d.data())).toList()
          ..sort((a, b) {
            if (a.isOwner != b.isOwner) return a.isOwner ? -1 : 1;
            return a.email.compareTo(b.email);
          });
    return admins;
  }

  @override
  Future<AdminRecord> inviteByEmail({
    required String email,
    String displayName = '',
    required String createdBy,
  }) async {
    final normalized = email.trim().toLowerCase();
    final record = AdminRecord(
      uid: normalized,
      email: normalized,
      displayName: displayName,
      role: 'admin',
      permissions: AdminPermissions.readOnly,
      pending: true,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
    await _withTimeout(_col.doc(normalized).set(record.toMap()));
    return record;
  }

  @override
  Future<void> updatePermissions(String uid, AdminPermissions p) async {
    await _withTimeout(
      _col.doc(uid).update(<String, dynamic>{'permissions': p.toMap()}),
    );
  }

  @override
  Future<void> deleteAdmin(String uid) async {
    await _withTimeout(_col.doc(uid).delete());
  }

  @override
  Future<void> saveFcmToken(String uid, String token) async {
    await _withTimeout(
      _col.doc(uid).set(<String, dynamic>{
        'fcmToken': token,
        'fcmTokenUpdatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true)),
    );
  }
}

/// Fake en memoria de la colección 'admins'.
class FakeAdminsRepository implements AdminsRepository {
  FakeAdminsRepository([List<AdminRecord>? seed]) {
    if (seed != null) {
      for (final a in seed) {
        _admins[a.uid] = a;
      }
    }
  }

  final Map<String, AdminRecord> _admins = {};

  void add(AdminRecord admin) => _admins[admin.uid] = admin;

  @override
  Future<AdminRecord?> resolveAdmin({
    required String uid,
    required String email,
  }) async {
    final direct = _admins[uid];
    if (direct != null) return direct;
    final normalized = email.trim().toLowerCase();
    final pending = _admins[normalized];
    if (pending == null || !pending.pending) return null;
    final adopted = AdminRecord(
      uid: uid,
      email: pending.email,
      displayName: pending.displayName,
      role: 'admin',
      permissions: pending.permissions,
      pending: false,
      createdAt: pending.createdAt,
      createdBy: pending.createdBy,
    );
    _admins.remove(normalized);
    _admins[uid] = adopted;
    return adopted;
  }

  @override
  Future<AdminRecord> ensureOwner({
    required String uid,
    required String email,
    String displayName = '',
  }) async {
    final normalized = email.trim().toLowerCase();
    final existing = _admins[uid];
    if (existing != null && existing.isOwner) return existing;
    final owner = AdminRecord(
      uid: uid,
      email: normalized,
      displayName: displayName.isEmpty
          ? (existing?.displayName ?? '')
          : displayName,
      role: 'owner',
      permissions: AdminPermissions.all,
      createdAt: existing?.createdAt ?? DateTime.now(),
      createdBy: 'bootstrap',
    );
    _admins[uid] = owner;
    return owner;
  }

  @override
  Future<List<AdminRecord>> listAdmins() async {
    final admins = _admins.values.toList()
      ..sort((a, b) {
        if (a.isOwner != b.isOwner) return a.isOwner ? -1 : 1;
        return a.email.compareTo(b.email);
      });
    return admins;
  }

  @override
  Future<AdminRecord> inviteByEmail({
    required String email,
    String displayName = '',
    required String createdBy,
  }) async {
    final normalized = email.trim().toLowerCase();
    final record = AdminRecord(
      uid: normalized,
      email: normalized,
      displayName: displayName,
      role: 'admin',
      permissions: AdminPermissions.readOnly,
      pending: true,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
    _admins[normalized] = record;
    return record;
  }

  @override
  Future<void> updatePermissions(String uid, AdminPermissions p) async {
    final admin = _admins[uid];
    if (admin == null) return;
    _admins[uid] = AdminRecord(
      uid: admin.uid,
      email: admin.email,
      displayName: admin.displayName,
      role: admin.role,
      permissions: p,
      pending: admin.pending,
      createdAt: admin.createdAt,
      createdBy: admin.createdBy,
    );
  }

  @override
  Future<void> deleteAdmin(String uid) async {
    _admins.remove(uid);
  }

  final Map<String, String> _fcmTokens = {};
  final Map<String, int> _fcmTokenUpdatedAt = {};

  String? fcmTokenFor(String uid) => _fcmTokens[uid];
  int? fcmTokenUpdatedAtFor(String uid) => _fcmTokenUpdatedAt[uid];

  @override
  Future<void> saveFcmToken(String uid, String token) async {
    _fcmTokens[uid] = token;
    _fcmTokenUpdatedAt[uid] = DateTime.now().millisecondsSinceEpoch;
  }
}

/// Puerta de auth completa (la usa main.dart).
///
/// - Si el correo es el del dueño configurado ([kOwnerEmail]), entra
///   directo como dueño: crea su documento en 'admins' si no existe
///   ([AdminsRepository.ensureOwner]), aunque la colección esté vacía.
/// - Cualquier otro correo pasa por [AdminsRepository.resolveAdmin]
///   (documento por uid o invitación pendiente por correo). Si no hay
///   registro, devuelve null: la UI muestra "No tienes acceso de
///   administrador" y el usuario no entra.
Future<AdminRecord?> resolveAdminRecord({
  required AdminsRepository admins,
  required String uid,
  required String email,
  String displayName = '',
}) async {
  if (email.trim().toLowerCase() == kOwnerEmail) {
    return admins.ensureOwner(
      uid: uid,
      email: email.trim().toLowerCase(),
      displayName: displayName,
    );
  }
  return admins.resolveAdmin(uid: uid, email: email);
}

// ---------------------------------------------------------------------------
// Ajustes remotos
// ---------------------------------------------------------------------------

abstract class SettingsRepository {
  Future<RemoteSettings> load();
  Future<void> save(RemoteSettings settings);
}

class FirestoreSettingsRepository implements SettingsRepository {
  FirestoreSettingsRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<RemoteSettings> load() async {
    final doc = await _withTimeout(_db.collection('settings').doc('app').get());
    if (!doc.exists || doc.data() == null) return const RemoteSettings();
    return RemoteSettings.fromMap(doc.data());
  }

  @override
  Future<void> save(RemoteSettings settings) async {
    await _withTimeout(
      _db
          .collection('settings')
          .doc('app')
          .set(settings.toMap(), SetOptions(merge: true)),
    );
  }
}

/// Fake en memoria del documento 'settings/app'.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository([RemoteSettings? seed])
    : _settings = seed ?? const RemoteSettings();

  RemoteSettings _settings;
  RemoteSettings get current => _settings;

  @override
  Future<RemoteSettings> load() async => _settings;

  @override
  Future<void> save(RemoteSettings settings) async {
    _settings = settings;
  }
}

// ---------------------------------------------------------------------------
// Contenido remoto (colección 'levels') — Quemia 7.0
// ---------------------------------------------------------------------------

abstract class LevelsRepository {
  Future<List<LevelContent>> listLevels();
  Future<LevelContent?> getLevel(String id);
  Future<void> saveLevel(LevelContent level);
}

class FirestoreLevelsRepository implements LevelsRepository {
  FirestoreLevelsRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<List<LevelContent>> listLevels() async {
    final snap = await _withTimeout(_db.collection('levels').get());
    final levels =
        snap.docs.map((d) => LevelContent.fromDoc(d.id, d.data())).toList()
          ..sort((a, b) {
            if (a.track != b.track) return a.track.compareTo(b.track);
            if (a.topicTitle != b.topicTitle) {
              return a.topicTitle.compareTo(b.topicTitle);
            }
            return a.level.compareTo(b.level);
          });
    return levels;
  }

  @override
  Future<LevelContent?> getLevel(String id) async {
    final doc = await _withTimeout(_db.collection('levels').doc(id).get());
    if (!doc.exists || doc.data() == null) return null;
    return LevelContent.fromDoc(doc.id, doc.data()!);
  }

  @override
  Future<void> saveLevel(LevelContent level) async {
    await _withTimeout(
      _db.collection('levels').doc(level.id).set(level.toMap()),
    );
  }
}

/// Fake en memoria de la colección 'levels'.
class FakeLevelsRepository implements LevelsRepository {
  FakeLevelsRepository([List<LevelContent>? seed]) {
    if (seed != null) {
      for (final l in seed) {
        _levels[l.id] = l;
      }
    }
  }

  final Map<String, LevelContent> _levels = {};

  void add(LevelContent level) => _levels[level.id] = level;

  @override
  Future<List<LevelContent>> listLevels() async {
    final levels = _levels.values.toList()
      ..sort((a, b) {
        if (a.track != b.track) return a.track.compareTo(b.track);
        if (a.topicTitle != b.topicTitle) {
          return a.topicTitle.compareTo(b.topicTitle);
        }
        return a.level.compareTo(b.level);
      });
    return levels;
  }

  @override
  Future<LevelContent?> getLevel(String id) async => _levels[id];

  @override
  Future<void> saveLevel(LevelContent level) async {
    _levels[level.id] = level;
  }
}

// ---------------------------------------------------------------------------
// Avisos (colección 'announcements') — Quemia 7.0
// ---------------------------------------------------------------------------

abstract class AnnouncementsRepository {
  Future<List<Announcement>> listAnnouncements();
  Future<Announcement> publish({
    required String title,
    required String body,
    required String createdBy,
  });
  Future<void> setActive(String id, bool active);
  Future<void> delete(String id);
}

class FirestoreAnnouncementsRepository implements AnnouncementsRepository {
  FirestoreAnnouncementsRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<List<Announcement>> listAnnouncements() async {
    final snap = await _withTimeout(_db.collection('announcements').get());
    final list =
        snap.docs.map((d) => Announcement.fromDoc(d.id, d.data())).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<Announcement> publish({
    required String title,
    required String body,
    required String createdBy,
  }) async {
    final ref = _db.collection('announcements').doc();
    final announcement = Announcement(
      id: ref.id,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      createdBy: createdBy,
      active: true,
    );
    await _withTimeout(ref.set(announcement.toMap()));
    return announcement;
  }

  @override
  Future<void> setActive(String id, bool active) async {
    await _withTimeout(
      _db.collection('announcements').doc(id).update({'active': active}),
    );
  }

  @override
  Future<void> delete(String id) async {
    await _withTimeout(_db.collection('announcements').doc(id).delete());
  }
}

/// Fake en memoria de la colección 'announcements'.
class FakeAnnouncementsRepository implements AnnouncementsRepository {
  FakeAnnouncementsRepository([List<Announcement>? seed]) {
    if (seed != null) {
      for (final a in seed) {
        _items[a.id] = a;
      }
    }
  }

  final Map<String, Announcement> _items = {};
  var _counter = 100;

  @override
  Future<List<Announcement>> listAnnouncements() async {
    final list = _items.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<Announcement> publish({
    required String title,
    required String body,
    required String createdBy,
  }) async {
    final announcement = Announcement(
      id: 'ann-fake-${_counter++}',
      title: title,
      body: body,
      createdAt: DateTime.now(),
      createdBy: createdBy,
      active: true,
    );
    _items[announcement.id] = announcement;
    return announcement;
  }

  @override
  Future<void> setActive(String id, bool active) async {
    final item = _items[id];
    if (item != null) _items[id] = item.copyWith(active: active);
  }

  @override
  Future<void> delete(String id) async {
    _items.remove(id);
  }
}

// ---------------------------------------------------------------------------
// Reportes de preguntas (colección 'reports') — Quemia 7.0
// ---------------------------------------------------------------------------

abstract class ReportsRepository {
  Future<List<QuestionReport>> listReports();
  Future<void> setStatus(String id, String status);
}

class FirestoreReportsRepository implements ReportsRepository {
  FirestoreReportsRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<List<QuestionReport>> listReports() async {
    final snap = await _withTimeout(_db.collection('reports').get());
    final list =
        snap.docs.map((d) => QuestionReport.fromDoc(d.id, d.data())).toList()
          ..sort((a, b) {
            if (a.isFixed != b.isFixed) return a.isFixed ? 1 : -1;
            return b.createdAt.compareTo(a.createdAt);
          });
    return list;
  }

  @override
  Future<void> setStatus(String id, String status) async {
    await _withTimeout(
      _db.collection('reports').doc(id).update({'status': status}),
    );
  }
}

/// Fake en memoria de la colección 'reports'.
class FakeReportsRepository implements ReportsRepository {
  FakeReportsRepository([List<QuestionReport>? seed]) {
    if (seed != null) {
      for (final r in seed) {
        _items[r.id] = r;
      }
    }
  }

  final Map<String, QuestionReport> _items = {};

  @override
  Future<List<QuestionReport>> listReports() async {
    final list = _items.values.toList()
      ..sort((a, b) {
        if (a.isFixed != b.isFixed) return a.isFixed ? 1 : -1;
        return b.createdAt.compareTo(a.createdAt);
      });
    return list;
  }

  @override
  Future<void> setStatus(String id, String status) async {
    final item = _items[id];
    if (item != null) _items[id] = item.copyWith(status: status);
  }
}

// ---------------------------------------------------------------------------
// Mensajes de soporte (colección 'support_messages') — Quemia 7.0
// ---------------------------------------------------------------------------

abstract class SupportRepository {
  Future<List<SupportMessage>> listMessages();

  /// Guarda la respuesta del admin: escribe reply + replyAt y pone el
  /// estado en 'respondido'. El usuario la ve en su ventanita de Soporte.
  Future<void> replyTo(String id, String reply);
}

class FirestoreSupportRepository implements SupportRepository {
  FirestoreSupportRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<List<SupportMessage>> listMessages() async {
    final snap = await _withTimeout(_db.collection('support_messages').get());
    final list =
        snap.docs.map((d) => SupportMessage.fromDoc(d.id, d.data())).toList()
          ..sort((a, b) {
            if (a.isAnswered != b.isAnswered) return a.isAnswered ? 1 : -1;
            return b.createdAt.compareTo(a.createdAt);
          });
    return list;
  }

  @override
  Future<void> replyTo(String id, String reply) async {
    await _withTimeout(
      _db.collection('support_messages').doc(id).update(<String, dynamic>{
        'reply': reply,
        'replyAt': Timestamp.fromDate(DateTime.now()),
        'status': 'respondido',
      }),
    );
  }
}

/// Fake en memoria de la colección 'support_messages'.
class FakeSupportRepository implements SupportRepository {
  FakeSupportRepository([List<SupportMessage>? seed]) {
    if (seed != null) {
      for (final m in seed) {
        _items[m.id] = m;
      }
    }
  }

  final Map<String, SupportMessage> _items = {};

  @override
  Future<List<SupportMessage>> listMessages() async {
    final list = _items.values.toList()
      ..sort((a, b) {
        if (a.isAnswered != b.isAnswered) return a.isAnswered ? 1 : -1;
        return b.createdAt.compareTo(a.createdAt);
      });
    return list;
  }

  @override
  Future<void> replyTo(String id, String reply) async {
    final item = _items[id];
    if (item != null) {
      _items[id] = item.copyWith(
        status: 'respondido',
        reply: reply,
        replyAt: DateTime.now(),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Capa de servicio: hace cumplir la matriz de permisos
// ---------------------------------------------------------------------------

/// Operaciones sensibles del panel, siempre con el admin actual como
/// contexto. Cada método comprueba el permiso antes de tocar el repositorio y
/// lanza [PermissionDenied] si no lo tiene. Así la regla vive en un solo
/// sitio y se puede probar con fakes.
class AdminService {
  AdminService({
    required this.me,
    required this.users,
    required this.admins,
    required this.settings,
    LevelsRepository? levels,
    AnnouncementsRepository? announcements,
    ReportsRepository? reports,
    SupportRepository? support,
  }) : levels = levels ?? FakeLevelsRepository(),
       announcements = announcements ?? FakeAnnouncementsRepository(),
       reports = reports ?? FakeReportsRepository(),
       support = support ?? FakeSupportRepository();

  final AdminRecord me;
  final UsersRepository users;
  final AdminsRepository admins;
  final SettingsRepository settings;

  /// Contenido remoto, avisos, reportes y soporte (Quemia 7.0). Por defecto,
  /// fakes vacíos en memoria; la app real inyecta la implementación
  /// Firestore.
  final LevelsRepository levels;
  final AnnouncementsRepository announcements;
  final ReportsRepository reports;
  final SupportRepository support;

  // -- Usuarios -------------------------------------------------------------

  Future<void> banUser(AppUser user, String reason) async {
    if (!me.canBanUsers()) {
      throw PermissionDenied('No tienes permiso para banear usuarios.');
    }
    await users.setBan(user.id, banned: true, reason: reason);
  }

  Future<void> unbanUser(AppUser user) async {
    if (!me.canBanUsers()) {
      throw PermissionDenied('No tienes permiso para quitar baneos.');
    }
    await users.setBan(user.id, banned: false);
  }

  // -- Administradores ------------------------------------------------------

  Future<AdminRecord> inviteAdmin({required String email}) async {
    if (!me.canManageAdmins()) {
      throw PermissionDenied(
        'No tienes permiso para gestionar administradores.',
      );
    }
    return admins.inviteByEmail(email: email, createdBy: me.email);
  }

  /// Cambia los permisos de [target].
  ///
  /// Reglas:
  /// - Hace falta manageAdmins (o ser dueño).
  /// - Nadie puede tocar los permisos del dueño.
  /// - Nadie puede concederse a sí mismo un permiso que no tiene.
  Future<void> setAdminPermissions(
    AdminRecord target,
    AdminPermissions next,
  ) async {
    if (!me.canManageAdmins()) {
      throw PermissionDenied(
        'No tienes permiso para gestionar administradores.',
      );
    }
    if (target.isOwner) {
      throw PermissionDenied('No se pueden cambiar los permisos del dueño.');
    }
    if (target.uid == me.uid) {
      final granting =
          (!me.permissions.banUsers && next.banUsers) ||
          (!me.permissions.manageAdmins && next.manageAdmins) ||
          (!me.permissions.viewUsers && next.viewUsers) ||
          (!me.permissions.viewProgress && next.viewProgress);
      if (granting) {
        throw PermissionDenied(
          'No puedes concederte a ti mismo permisos que no tienes.',
        );
      }
    }
    await admins.updatePermissions(target.uid, next);
  }

  /// Elimina a [target] de la colección 'admins'.
  /// Nadie puede eliminar al dueño ni eliminarse a sí mismo.
  Future<void> removeAdmin(AdminRecord target) async {
    if (!me.canManageAdmins()) {
      throw PermissionDenied(
        'No tienes permiso para gestionar administradores.',
      );
    }
    if (target.isOwner) {
      throw PermissionDenied('No se puede eliminar al dueño.');
    }
    if (target.uid == me.uid) {
      throw PermissionDenied('No puedes eliminarte a ti mismo.');
    }
    await admins.deleteAdmin(target.uid);
  }

  // -- Ajustes remotos ------------------------------------------------------

  Future<void> saveSettings(RemoteSettings next) async {
    if (!me.canManageAdmins()) {
      throw PermissionDenied(
        'No tienes permiso para cambiar los ajustes remotos.',
      );
    }
    final error = RemoteSettings.validate(next);
    if (error != null) throw ArgumentError(error);
    await settings.save(next);
  }

  // -- Avisos (Quemia 7.0) ----------------------------------------------------

  Future<Announcement> publishAnnouncement({
    required String title,
    required String body,
  }) async {
    if (!me.canManageAdmins()) {
      throw PermissionDenied('No tienes permiso para publicar avisos.');
    }
    if (title.trim().isEmpty || body.trim().isEmpty) {
      throw ArgumentError('El título y el mensaje no pueden estar vacíos.');
    }
    return announcements.publish(
      title: title.trim(),
      body: body.trim(),
      createdBy: me.email,
    );
  }

  Future<void> setAnnouncementActive(String id, bool active) async {
    if (!me.canManageAdmins()) {
      throw PermissionDenied('No tienes permiso para gestionar avisos.');
    }
    await announcements.setActive(id, active);
  }

  Future<void> deleteAnnouncement(String id) async {
    if (!me.canManageAdmins()) {
      throw PermissionDenied('No tienes permiso para gestionar avisos.');
    }
    await announcements.delete(id);
  }

  // -- Editor de contenido (Quemia 7.0) ---------------------------------------

  /// Guarda una pregunta en un nivel: si [isNew] es true la añade (con id
  /// nuevo), si no, sustituye la que tenga el mismo id. Valida antes de
  /// escribir: 4 opciones, exactamente 1 correcta, texto no vacío.
  Future<void> saveQuestion({
    required String levelId,
    required QuizQuestion question,
    bool isNew = false,
  }) async {
    if (!me.canManageAdmins()) {
      throw PermissionDenied('No tienes permiso para editar el contenido.');
    }
    final error = QuizQuestion.validate(question);
    if (error != null) throw ArgumentError(error);
    final level = await levels.getLevel(levelId);
    if (level == null) throw ArgumentError('Nivel no encontrado: $levelId');
    final questions = [...level.questions];
    if (isNew) {
      final id = question.id.isEmpty
          ? 'q-${DateTime.now().millisecondsSinceEpoch}'
          : question.id;
      questions.add(question.copyWith(id: id));
    } else {
      final index = questions.indexWhere((q) => q.id == question.id);
      if (index == -1) {
        questions.add(question);
      } else {
        questions[index] = question;
      }
    }
    await levels.saveLevel(
      level.copyWith(questions: questions, updatedAt: DateTime.now()),
    );
  }

  // -- Soporte (Quemia 7.0) ---------------------------------------------------

  /// Responde un mensaje de soporte: guarda reply + replyAt y el estado
  /// pasa a 'respondido' (la app principal lo muestra al usuario en su
  /// ventanita, con aviso en su bandeja). Solo cambia lo del mensaje: las
  /// escrituras del admin solo tocan lo que le corresponde.
  ///
  /// La respuesta automática de Muse NO va en esta versión: responde
  /// Kristian (o un admin) cuando puede.
  Future<void> replyToSupport(SupportMessage message, String reply) async {
    if (!me.canManageAdmins()) {
      throw PermissionDenied('No tienes permiso para responder soporte.');
    }
    if (reply.trim().isEmpty) {
      throw ArgumentError('La respuesta no puede estar vacía.');
    }
    await support.replyTo(message.id, reply.trim());
  }

  // -- Reportes (Quemia 7.0) --------------------------------------------------

  /// Marca un reporte como arreglado. Solo cambia el estado del reporte:
  /// las escrituras del admin solo tocan lo que le corresponde (baneo,
  /// avisos, contenido, reportes), nunca documentos de otros usuarios.
  Future<void> markReportFixed(QuestionReport report) async {
    if (!me.canManageAdmins()) {
      throw PermissionDenied('No tienes permiso para gestionar reportes.');
    }
    await reports.setStatus(report.id, 'fixed');
  }
}

// Modelos de datos de Quemia Admin.
//
// Contrato compartido con la app principal Quemia (NO cambiar los nombres
// de colecciones ni de campos):
//  - Colección 'users', documento id = id anónimo de dispositivo.
//  - Colección 'admins', documento id = uid de Firebase Auth.
//  - Documento 'settings/app' con los ajustes remotos.
//  - Colección 'levels' para el banco de preguntas editable (Quemia 7.0).
//  - Hueco previsto (versión posterior): colección 'tournaments'.
//    Ver README.md, sección "Para después".

import 'package:cloud_firestore/cloud_firestore.dart';

// El dueño por configuración: pozogomezkristian19@gmail.com. Aunque la
// colección 'admins' esté vacía, esta cuenta entra directo como dueña y la
// app crea su documento en 'admins' (todos los permisos) en el primer
// inicio de sesión. Cualquier otra cuenta necesita estar listada en
// 'admins'. Ver resolveAdminRecord() en repositories.dart.
const String kOwnerEmail = 'pozogomezkristian19@gmail.com';

/// Un usuario de la app Quemia (documento de la colección 'users').
class BanHistoryEntry {
  const BanHistoryEntry({
    required this.action,
    required this.reason,
    required this.at,
    required this.by,
  });

  /// 'ban' (baneado) o 'unban' (baneo retirado).
  final String action;

  /// Motivo escrito por el admin (obligatorio al banear, opcional al
  /// quitar el baneo; puede ser vacío en entradas antiguas).
  final String reason;

  final DateTime at;

  /// Quién lo hizo (correo del admin).
  final String by;

  factory BanHistoryEntry.fromMap(Map<String, dynamic> data) {
    return BanHistoryEntry(
      action: (data['action'] as String?) ?? 'ban',
      reason: (data['reason'] as String?) ?? '',
      at: AppUser.dateFromValue(data['at']),
      by: (data['by'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'action': action,
    'reason': reason,
    'at': Timestamp.fromDate(at),
    'by': by,
  };

  bool get isBan => action == 'ban';
}

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.joinedAt,
    required this.lastActive,
    required this.levelsBachPassed,
    required this.levelsUniPassed,
    required this.points,
    required this.streak,
    required this.track,
    required this.appVersion,
    required this.banned,
    this.bannedReason = '',
    this.bannedAt,
    this.lives,
    this.bannedBy = '',
    this.banHistory = const [],
  });

  factory AppUser.fromDoc(String id, Map<String, dynamic> data) {
    final levels = data['levelsPassed'] as Map<String, dynamic>? ?? {};
    final rawHistory = data['banHistory'];
    final history = <BanHistoryEntry>[];
    if (rawHistory is List) {
      for (final e in rawHistory) {
        if (e is Map<String, dynamic>) history.add(BanHistoryEntry.fromMap(e));
        if (e is Map) {
          history.add(BanHistoryEntry.fromMap(Map<String, dynamic>.from(e)));
        }
      }
    }
    return AppUser(
      id: id,
      username: (data['username'] as String?) ?? 'Sin nombre',
      joinedAt: _toDate(data['joinedAt']),
      lastActive: _toDate(data['lastActive']),
      levelsBachPassed: (levels['bach'] as num?)?.toInt() ?? 0,
      levelsUniPassed: (levels['uni'] as num?)?.toInt() ?? 0,
      points: (data['points'] as num?)?.toInt() ?? 0,
      streak: (data['streak'] as num?)?.toInt() ?? 0,
      track: (data['track'] as String?) ?? 'bach',
      appVersion: (data['appVersion'] as String?) ?? '—',
      banned: (data['banned'] as bool?) ?? false,
      bannedReason: (data['bannedReason'] as String?) ?? '',
      bannedAt: _toDateOrNull(data['bannedAt']),
      lives: (data['lives'] as num?)?.toInt(),
      bannedBy: (data['bannedBy'] as String?) ?? '',
      banHistory: history,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'username': username,
    'joinedAt': Timestamp.fromDate(joinedAt),
    'lastActive': Timestamp.fromDate(lastActive),
    'levelsPassed': <String, dynamic>{
      'bach': levelsBachPassed,
      'uni': levelsUniPassed,
    },
    'points': points,
    'streak': streak,
    'track': track,
    'appVersion': appVersion,
    'banned': banned,
    'bannedReason': bannedReason,
    if (bannedAt != null) 'bannedAt': Timestamp.fromDate(bannedAt!),
    if (lives != null) 'lives': lives,
    if (bannedBy.isNotEmpty) 'bannedBy': bannedBy,
    if (banHistory.isNotEmpty)
      'banHistory': banHistory.map((e) => e.toMap()).toList(),
  };

  final String id;
  final String username;
  final DateTime joinedAt;
  final DateTime lastActive;
  final int levelsBachPassed;
  final int levelsUniPassed;
  final int points;
  final int streak;

  /// 'bach' (Bachillerato) o 'uni' (Universidad).
  final String track;
  final String appVersion;
  final bool banned;
  final String bannedReason;
  final DateTime? bannedAt;

  /// Vidas editadas desde la Admin (0–5). null = el documento no trae
  /// valor remoto: las vidas viven en el teléfono del usuario y la app
  /// principal todavía no lee este campo (ver informe de la ronda).
  final int? lives;

  /// Correo del admin que puso el baneo vigente (vacío si no está baneado
  /// o si el baneo es anterior a esta función).
  final String bannedBy;

  /// Historial de baneos y desbaneos, del más antiguo al más reciente.
  final List<BanHistoryEntry> banHistory;

  int get totalLevelsPassed => levelsBachPassed + levelsUniPassed;

  bool get activeToday =>
      DateTime.now().difference(lastActive) < const Duration(hours: 24);

  /// Centinela para poder poner a null campos que admiten null
  /// (bannedAt, lives): copyWith(bannedAt: null) borra el valor; sin el
  /// parámetro se conserva.
  static const _unset = Object();

  AppUser copyWith({
    int? points,
    int? streak,
    Object? lives = _unset,
    bool? banned,
    String? bannedReason,
    Object? bannedAt = _unset,
    String? bannedBy,
    List<BanHistoryEntry>? banHistory,
  }) => AppUser(
    id: id,
    username: username,
    joinedAt: joinedAt,
    lastActive: lastActive,
    levelsBachPassed: levelsBachPassed,
    levelsUniPassed: levelsUniPassed,
    points: points ?? this.points,
    streak: streak ?? this.streak,
    track: track,
    appVersion: appVersion,
    banned: banned ?? this.banned,
    bannedReason: bannedReason ?? this.bannedReason,
    bannedAt: bannedAt == _unset ? this.bannedAt : bannedAt as DateTime?,
    lives: lives == _unset ? this.lives : lives as int?,
    bannedBy: bannedBy ?? this.bannedBy,
    banHistory: banHistory ?? this.banHistory,
  );

  static DateTime _toDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Igual que [_toDate] pero público para [BanHistoryEntry].
  static DateTime dateFromValue(Object? value) => _toDate(value);

  static DateTime? _toDateOrNull(Object? value) {
    if (value == null) return null;
    return _toDate(value);
  }
}

/// Permisos de un administrador (mapa 'permissions' del documento 'admins').
class AdminPermissions {
  const AdminPermissions({
    this.viewUsers = false,
    this.viewProgress = false,
    this.banUsers = false,
    this.manageAdmins = false,
  });

  factory AdminPermissions.fromMap(Map<String, dynamic>? data) {
    final m = data ?? {};
    return AdminPermissions(
      viewUsers: (m['viewUsers'] as bool?) ?? false,
      viewProgress: (m['viewProgress'] as bool?) ?? false,
      banUsers: (m['banUsers'] as bool?) ?? false,
      manageAdmins: (m['manageAdmins'] as bool?) ?? false,
    );
  }

  /// Permisos iniciales de un admin nuevo: solo lectura.
  static const readOnly = AdminPermissions(viewUsers: true, viewProgress: true);

  /// Todos los permisos en true (dueño).
  static const all = AdminPermissions(
    viewUsers: true,
    viewProgress: true,
    banUsers: true,
    manageAdmins: true,
  );

  Map<String, dynamic> toMap() => <String, dynamic>{
    'viewUsers': viewUsers,
    'viewProgress': viewProgress,
    'banUsers': banUsers,
    'manageAdmins': manageAdmins,
  };

  final bool viewUsers;
  final bool viewProgress;
  final bool banUsers;
  final bool manageAdmins;

  AdminPermissions copyWith({
    bool? viewUsers,
    bool? viewProgress,
    bool? banUsers,
    bool? manageAdmins,
  }) => AdminPermissions(
    viewUsers: viewUsers ?? this.viewUsers,
    viewProgress: viewProgress ?? this.viewProgress,
    banUsers: banUsers ?? this.banUsers,
    manageAdmins: manageAdmins ?? this.manageAdmins,
  );
}

/// Un administrador (documento de la colección 'admins').
///
/// El documento id es el uid de Firebase Auth. Cuando se agrega un admin por
/// correo antes de que haya entrado nunca, se crea un documento PENDIENTE con
/// id = el correo en minúsculas; al entrar por primera vez con Google, la
/// puerta de auth lo adopta (crea el documento con su uid y borra el
/// pendiente). Ver [AdminsRepository.resolveAdmin].
class AdminRecord {
  const AdminRecord({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.role = 'admin',
    this.permissions = AdminPermissions.readOnly,
    this.pending = false,
    this.createdAt,
    this.createdBy = '',
  });

  factory AdminRecord.fromDoc(String id, Map<String, dynamic> data) {
    return AdminRecord(
      uid: id,
      email: (data['email'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? '',
      role: (data['role'] as String?) ?? 'admin',
      permissions: AdminPermissions.fromMap(
        data['permissions'] as Map<String, dynamic>?,
      ),
      pending: (data['pending'] as bool?) ?? false,
      createdAt: _toDateOrNull(data['createdAt']),
      createdBy: (data['createdBy'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'email': email,
    'displayName': displayName,
    'role': role,
    'permissions': permissions.toMap(),
    'pending': pending,
    if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    'createdBy': createdBy,
  };

  final String uid;
  final String email;
  final String displayName;
  final String role; // 'owner' | 'admin'
  final AdminPermissions permissions;

  /// true si es una invitación pendiente creada por correo (aún sin uid real).
  final bool pending;
  final DateTime? createdAt;
  final String createdBy;

  bool get isOwner => role == 'owner';

  /// Primer nombre para el saludo ("Hola Kristian"): solo la primera
  /// palabra del displayName, sin apellidos y sin caer al correo
  /// (2026-11-13, Kristian: en el Admin no se muestra el correo).
  /// Vacío si no hay nombre guardado.
  String get firstName {
    final name = displayName.trim();
    if (name.isEmpty) return '';
    return name.split(RegExp(r'\s+')).first;
  }

  /// El dueño lo puede todo. Un admin solo lo que tenga en su mapa.
  bool canViewUsers() => isOwner || permissions.viewUsers;
  bool canViewProgress() => isOwner || permissions.viewProgress;
  bool canBanUsers() => isOwner || permissions.banUsers;
  bool canManageAdmins() => isOwner || permissions.manageAdmins;

  static DateTime? _toDateOrNull(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

/// Ajustes remotos (documento 'settings/app') que la app principal lee al
/// abrir. Los valores por defecto coinciden con los de Quemia 6.x.
class RemoteSettings {
  const RemoteSettings({
    this.passThreshold = 4,
    this.pointsEasyGain = 3,
    this.pointsEasyLoss = -5,
    this.pointsMediumGain = 5,
    this.pointsMediumLoss = -8,
    this.pointsHardGain = 8,
    this.pointsHardLoss = -12,
    this.maxLives = 5,
    this.supportNumber = '+5356519431',
    this.showWhatsApp = false,
  });

  factory RemoteSettings.fromMap(Map<String, dynamic>? data) {
    final m = data ?? {};
    int readInt(String key, int fallback) =>
        (m[key] as num?)?.toInt() ?? fallback;
    return RemoteSettings(
      passThreshold: readInt('passThreshold', 4),
      pointsEasyGain: readInt('pointsEasyGain', 3),
      pointsEasyLoss: readInt('pointsEasyLoss', -5),
      pointsMediumGain: readInt('pointsMediumGain', 5),
      pointsMediumLoss: readInt('pointsMediumLoss', -8),
      pointsHardGain: readInt('pointsHardGain', 8),
      pointsHardLoss: readInt('pointsHardLoss', -12),
      maxLives: readInt('maxLives', 5),
      supportNumber: (m['supportNumber'] as String?)?.trim() ?? '+5356519431',
      showWhatsApp: (m['showWhatsApp'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'passThreshold': passThreshold,
    'pointsEasyGain': pointsEasyGain,
    'pointsEasyLoss': pointsEasyLoss,
    'pointsMediumGain': pointsMediumGain,
    'pointsMediumLoss': pointsMediumLoss,
    'pointsHardGain': pointsHardGain,
    'pointsHardLoss': pointsHardLoss,
    'maxLives': maxLives,
    'supportNumber': supportNumber,
    'showWhatsApp': showWhatsApp,
  };

  /// Nota mínima para aprobar un nivel: de 1 a 5.
  final int passThreshold;
  final int pointsEasyGain;
  final int pointsEasyLoss;
  final int pointsMediumGain;
  final int pointsMediumLoss;
  final int pointsHardGain;
  final int pointsHardLoss;
  final int maxLives;

  /// Número de soporte (WhatsApp) que la app principal muestra en su
  /// ventanita de Soporte. Por defecto el de Kristian; lo cambia desde
  /// esta app de admin cuando tenga el número de Quemia, sin actualizar
  /// la app.
  final String supportNumber;

  /// Si está apagado, la ventanita de Soporte de la app principal NO
  /// muestra el botón de WhatsApp (aunque haya número guardado).
  final bool showWhatsApp;

  RemoteSettings copyWith({
    int? passThreshold,
    int? pointsEasyGain,
    int? pointsEasyLoss,
    int? pointsMediumGain,
    int? pointsMediumLoss,
    int? pointsHardGain,
    int? pointsHardLoss,
    int? maxLives,
    String? supportNumber,
    bool? showWhatsApp,
  }) => RemoteSettings(
    passThreshold: passThreshold ?? this.passThreshold,
    pointsEasyGain: pointsEasyGain ?? this.pointsEasyGain,
    pointsEasyLoss: pointsEasyLoss ?? this.pointsEasyLoss,
    pointsMediumGain: pointsMediumGain ?? this.pointsMediumGain,
    pointsMediumLoss: pointsMediumLoss ?? this.pointsMediumLoss,
    pointsHardGain: pointsHardGain ?? this.pointsHardGain,
    pointsHardLoss: pointsHardLoss ?? this.pointsHardLoss,
    maxLives: maxLives ?? this.maxLives,
    supportNumber: supportNumber ?? this.supportNumber,
    showWhatsApp: showWhatsApp ?? this.showWhatsApp,
  );

  /// Validación de la UI antes de guardar. Devuelve el mensaje de error o
  /// null si todo es válido.
  static String? validate(RemoteSettings s) {
    if (s.passThreshold < 1 || s.passThreshold > 5) {
      return 'El umbral de aprobado debe estar entre 1 y 5.';
    }
    if (s.maxLives < 1 || s.maxLives > 10) {
      return 'Las vidas máximas deben estar entre 1 y 10.';
    }
    if (s.supportNumber.trim().isNotEmpty &&
        !RegExp(r'^\+?[0-9][0-9 ]*$').hasMatch(s.supportNumber.trim())) {
      return 'El número de soporte no parece un número de teléfono.';
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Contenido remoto (colección 'levels') — Quemia 7.0
// ---------------------------------------------------------------------------

/// Una pregunta del banco remoto.
///
/// La colección 'levels' guarda un documento por nivel con sus preguntas en
/// un array. La app principal lee ese contenido con fallback al contenido
/// local si es inválido o no hay internet; por eso la validación aquí es
/// estricta.
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
    this.difficulty = 'facil',
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> data) {
    final options = (data['options'] as List<dynamic>? ?? [])
        .map((o) => '$o')
        .toList();
    return QuizQuestion(
      id: (data['id'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      options: options,
      correctIndex: (data['correctIndex'] as num?)?.toInt() ?? 0,
      difficulty: (data['difficulty'] as String?) ?? 'facil',
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'text': text,
    'options': options,
    'correctIndex': correctIndex,
    'difficulty': difficulty,
  };

  final String id;
  final String text;

  /// Exactamente 4 opciones.
  final List<String> options;

  /// Índice (0-3) de la única opción correcta.
  final int correctIndex;

  /// 'facil' | 'media' | 'dificil'.
  final String difficulty;

  String get difficultyLabel => switch (difficulty) {
    'media' => 'Media',
    'dificil' => 'Difícil',
    _ => 'Fácil',
  };

  /// Validación del editor. Devuelve el mensaje de error o null si es válida.
  static String? validate(QuizQuestion q) {
    if (q.text.trim().isEmpty) {
      return 'La pregunta no puede estar vacía.';
    }
    if (q.options.length != 4) {
      return 'La pregunta debe tener exactamente 4 opciones.';
    }
    if (q.options.any((o) => o.trim().isEmpty)) {
      return 'Ninguna opción puede estar vacía.';
    }
    if (q.options.map((o) => o.trim()).toSet().length != 4) {
      return 'Las 4 opciones deben ser distintas.';
    }
    if (q.correctIndex < 0 || q.correctIndex > 3) {
      return 'Hay que marcar exactamente una respuesta correcta.';
    }
    if (!['facil', 'media', 'dificil'].contains(q.difficulty)) {
      return 'La dificultad debe ser fácil, media o difícil.';
    }
    return null;
  }

  QuizQuestion copyWith({
    String? id,
    String? text,
    List<String>? options,
    int? correctIndex,
    String? difficulty,
  }) => QuizQuestion(
    id: id ?? this.id,
    text: text ?? this.text,
    options: options ?? this.options,
    correctIndex: correctIndex ?? this.correctIndex,
    difficulty: difficulty ?? this.difficulty,
  );
}

/// Un nivel del banco remoto (documento de la colección 'levels').
///
/// id sugerido: `track-topic-nivel` (p. ej. 'bach-estequiometria-1').
/// El id es interno; en la UI solo se muestran topicTitle y title.
class LevelContent {
  const LevelContent({
    required this.id,
    required this.track,
    required this.topic,
    required this.topicTitle,
    required this.level,
    required this.title,
    this.questions = const [],
    this.updatedAt,
  });

  factory LevelContent.fromDoc(String id, Map<String, dynamic> data) {
    final raw = (data['questions'] as List<dynamic>? ?? []);
    return LevelContent(
      id: id,
      track: (data['track'] as String?) ?? 'bach',
      topic: (data['topic'] as String?) ?? '',
      topicTitle: (data['topicTitle'] as String?) ?? '',
      level: (data['level'] as num?)?.toInt() ?? 1,
      title: (data['title'] as String?) ?? '',
      questions: raw
          .whereType<Map<String, dynamic>>()
          .map(QuizQuestion.fromMap)
          .toList(),
      updatedAt: _toDateOrNull(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'track': track,
    'topic': topic,
    'topicTitle': topicTitle,
    'level': level,
    'title': title,
    'questions': questions.map((q) => q.toMap()).toList(),
    if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
  };

  final String id;
  final String track; // 'bach' | 'uni'
  final String topic;
  final String topicTitle;
  final int level;
  final String title;
  final List<QuizQuestion> questions;
  final DateTime? updatedAt;

  String get trackLabel => track == 'uni' ? 'Universidad' : 'Bachillerato';

  LevelContent copyWith({List<QuizQuestion>? questions, DateTime? updatedAt}) =>
      LevelContent(
        id: id,
        track: track,
        topic: topic,
        topicTitle: topicTitle,
        level: level,
        title: title,
        questions: questions ?? this.questions,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  static DateTime? _toDateOrNull(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

// ---------------------------------------------------------------------------
// Avisos (colección 'announcements') — Quemia 7.0
// ---------------------------------------------------------------------------

/// Un aviso para todos los usuarios. La app principal lo lee y lo muestra
/// en su bandeja de notificaciones. Solo los activos se muestran.
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.createdBy,
    this.active = true,
    this.sendPush = false,
  });

  factory Announcement.fromDoc(String id, Map<String, dynamic> data) {
    return Announcement(
      id: id,
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      createdAt: _toDate(data['createdAt']),
      createdBy: (data['createdBy'] as String?) ?? '',
      active: (data['active'] as bool?) ?? true,
      sendPush: data['sendPush'] == true,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'title': title,
    'body': body,
    'createdAt': Timestamp.fromDate(createdAt),
    'createdBy': createdBy,
    'active': active,
    'sendPush': sendPush,
  };

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final String createdBy;
  final bool active;

  /// true = además de caer en la bandeja, el aviso se manda como
  /// notificación push a todos los usuarios (lo envía la Cloud Function
  /// onAnnouncementCreated; sin despliegue no llega el push).
  final bool sendPush;

  Announcement copyWith({bool? active, bool? sendPush}) => Announcement(
    id: id,
    title: title,
    body: body,
    createdAt: createdAt,
    createdBy: createdBy,
    active: active ?? this.active,
    sendPush: sendPush ?? this.sendPush,
  );

  static DateTime _toDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

// ---------------------------------------------------------------------------
// Duelos (colección 'duels') — solo lectura en la Admin.
// Campos reales del documento (ver duels_service.dart de la app principal):
// playerA/playerB (uid), playerAName/playerBName, questionIds, seed,
// status ('waiting' | 'playing' | 'finished' | 'cancelled'), createdAtMs,
// results (mapa por uid: correct, timeMs, finishedAtMs, lastActivityMs),
// winnerUid (uid del ganador o null), forfeit (ganó por abandono).
// OJO: las reglas publicadas hablan de 'participants'/'questions'/
// 'answers'/'winner', campos que NO existen en estos documentos: el admin
// no puede leer duelos hasta que se corrija la regla (ver informe).
// ---------------------------------------------------------------------------

/// Resultado de un jugador en un duelo. Una entrada con finishedAtMs == 0
/// es solo un latido (sigue jugando), no un resultado terminado.
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

  bool get isFinished => finishedAtMs > 0;

  factory DuelResult.fromMap(Object? raw) {
    if (raw is! Map) {
      return const DuelResult(
        correct: 0,
        timeMs: 0,
        finishedAtMs: 0,
        lastActivityMs: 0,
      );
    }
    return DuelResult(
      correct: (raw['correct'] as num?)?.toInt() ?? 0,
      timeMs: (raw['timeMs'] as num?)?.toInt() ?? 0,
      finishedAtMs: (raw['finishedAtMs'] as num?)?.toInt() ?? 0,
      lastActivityMs: (raw['lastActivityMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class Duel {
  const Duel({
    required this.id,
    required this.playerA,
    required this.playerB,
    required this.playerAName,
    required this.playerBName,
    required this.status,
    required this.createdAtMs,
    required this.results,
    required this.winnerUid,
    required this.forfeit,
  });

  factory Duel.fromDoc(String id, Map<String, dynamic> data) {
    final results = <String, DuelResult>{};
    final rawResults = data['results'];
    if (rawResults is Map) {
      rawResults.forEach((uid, r) {
        results[uid.toString()] = DuelResult.fromMap(r);
      });
    }
    return Duel(
      id: id,
      playerA: (data['playerA'] as String?) ?? '',
      playerB: (data['playerB'] as String?) ?? '',
      playerAName: (data['playerAName'] as String?) ?? 'Jugador A',
      playerBName: (data['playerBName'] as String?) ?? 'Jugador B',
      status: (data['status'] as String?) ?? 'waiting',
      createdAtMs: (data['createdAtMs'] as num?)?.toInt() ?? 0,
      results: results,
      winnerUid: (data['winnerUid'] as String?)?.isEmpty == true
          ? null
          : data['winnerUid'] as String?,
      forfeit: data['forfeit'] == true,
    );
  }

  final String id;
  final String playerA;
  final String playerB;
  final String playerAName;
  final String playerBName;

  /// 'waiting' | 'playing' | 'finished' | 'cancelled'.
  final String status;
  final int createdAtMs;
  final Map<String, DuelResult> results;
  final String? winnerUid;
  final bool forfeit;

  bool get isFinished => status == 'finished';
  bool get isCancelled => status == 'cancelled';
  bool get isActive => status == 'waiting' || status == 'playing';

  /// Etiqueta en español para la UI (sin slugs internos).
  String get statusLabel => switch (status) {
    'waiting' => 'En espera',
    'playing' => 'En curso',
    'finished' => 'Terminado',
    'cancelled' => 'Cancelado',
    _ => 'En curso',
  };

  DuelResult? resultOf(String uid) => results[uid];

  /// Aciertos del jugador (solo si terminó; null = aún jugando).
  int? scoreOf(String uid) {
    final r = results[uid];
    if (r == null || !r.isFinished) return null;
    return r.correct;
  }

  String get winnerName {
    if (winnerUid == null) return '';
    if (winnerUid == playerA) return playerAName;
    if (winnerUid == playerB) return playerBName;
    return '';
  }

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);
}

// ---------------------------------------------------------------------------
// Mensajes de soporte (colección 'support_messages') — Quemia 7.0
// ---------------------------------------------------------------------------

/// Un mensaje de soporte enviado desde la ventanita de Soporte de la app
/// principal. El admin lo lee aquí y responde; la respuesta la ve el
/// usuario en su ventanita (con aviso en su bandeja).
///
/// Campos canónicos (los mismos que lee la app principal y las reglas):
/// authorUid, username, message, createdAt, status ('abierto' |
/// 'respondido'), reply, replyAt. Al responder, la admin escribe reply +
/// replyAt y pone status 'respondido'. La respuesta automática de Muse NO
/// va en esta versión: responde Kristian (o un admin) cuando puede.
class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.authorUid,
    required this.username,
    required this.message,
    required this.createdAt,
    this.status = 'abierto',
    this.reply = '',
    this.replyAt,
  });

  factory SupportMessage.fromDoc(String id, Map<String, dynamic> data) {
    return SupportMessage(
      id: id,
      authorUid: (data['authorUid'] as String?) ?? '',
      username: (data['username'] as String?) ?? '',
      message: (data['message'] as String?) ?? '',
      createdAt: _toDate(data['createdAt']),
      status: (data['status'] as String?) ?? 'abierto',
      reply: (data['reply'] as String?) ?? '',
      replyAt: _toDateOrNull(data['replyAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'authorUid': authorUid,
    'username': username,
    'message': message,
    'createdAt': Timestamp.fromDate(createdAt),
    'status': status,
    'reply': reply,
    if (replyAt != null) 'replyAt': Timestamp.fromDate(replyAt!),
  };

  final String id;

  /// id anónimo de dispositivo del usuario que escribió (el mismo de
  /// la colección 'users').
  final String authorUid;

  /// Nombre del usuario que escribió.
  final String username;

  /// El mensaje del usuario.
  final String message;
  final DateTime createdAt;

  /// 'abierto' | 'respondido'.
  final String status;

  /// Respuesta del admin (vacía mientras está abierto).
  final String reply;
  final DateTime? replyAt;

  bool get isAnswered => status == 'respondido';

  SupportMessage copyWith({String? status, String? reply, DateTime? replyAt}) =>
      SupportMessage(
        id: id,
        authorUid: authorUid,
        username: username,
        message: message,
        createdAt: createdAt,
        status: status ?? this.status,
        reply: reply ?? this.reply,
        replyAt: replyAt ?? this.replyAt,
      );

  static DateTime _toDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime? _toDateOrNull(Object? value) {
    if (value == null) return null;
    return _toDate(value);
  }
}

// ---------------------------------------------------------------------------
// Reportes de preguntas (colección 'reports') — Quemia 7.0
// ---------------------------------------------------------------------------

/// Un reporte de una pregunta, enviado desde la app principal por un usuario.
class QuestionReport {
  const QuestionReport({
    required this.id,
    required this.questionId,
    required this.levelId,
    required this.username,
    required this.note,
    required this.createdAt,
    this.questionText = '',
    this.status = 'open',
  });

  factory QuestionReport.fromDoc(String id, Map<String, dynamic> data) {
    return QuestionReport(
      id: id,
      questionId: (data['questionId'] as String?) ?? '',
      levelId: (data['levelId'] as String?) ?? '',
      username: (data['username'] as String?) ?? '',
      note: (data['note'] as String?) ?? '',
      createdAt: _toDate(data['createdAt']),
      questionText: (data['questionText'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'open',
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'questionId': questionId,
    'levelId': levelId,
    'username': username,
    'note': note,
    'createdAt': Timestamp.fromDate(createdAt),
    'questionText': questionText,
    'status': status,
  };

  final String id;
  final String questionId;
  final String levelId;

  /// Nombre del usuario que reportó.
  final String username;

  /// Nota del usuario (qué está mal).
  final String note;
  final DateTime createdAt;

  /// Texto de la pregunta en el momento del reporte (puede venir vacío).
  final String questionText;

  /// 'open' | 'fixed'.
  final String status;

  bool get isFixed => status == 'fixed';

  /// Qué mostrar en la UI: el texto si vino, si no el id de la pregunta.
  String get displayQuestion =>
      questionText.isNotEmpty ? questionText : questionId;

  QuestionReport copyWith({String? status}) => QuestionReport(
    id: id,
    questionId: questionId,
    levelId: levelId,
    username: username,
    note: note,
    createdAt: createdAt,
    questionText: questionText,
    status: status ?? this.status,
  );

  static DateTime _toDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

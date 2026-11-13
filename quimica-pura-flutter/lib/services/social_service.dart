// Capa social de Quemia 7.0: amigos, duelos online, torneos, tienda,
// grupos de estudio y reportes de preguntas (UI).
//
// La UI llama SIEMPRE a la fachada estática `SocialService`, que
// nunca lanza: si el backend falla (sin internet), devuelve listas
// vacías / false y la pantalla muestra su estado tranquilo. El
// repositorio real (Firestore) lo conecta el otro agente instalando
// su implementación con `SocialService.setRepositoryForTests` en
// producción con otro nombre, o sustituyendo el repositorio por
// defecto aquí: hoy el repositorio por defecto es
// `InMemorySocialRepository` (sin semilla: vacío, funciona sin
// internet) y las previews/tests lo siembran con los 12 usuarios
// de demostración (`seedDemo: true`).
//
// Compras de la tienda: se guardan EN LOCAL (SharedPreferences)
// y se sincronizan cuando hay backend (`syncPurchase`, best-effort).
// Los puntos se descuentan de ProgressService al comprar.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'auth_service.dart';
import 'duels_service.dart';
import 'localization.dart';
import 'notification_inbox.dart';
import 'progress.dart';
import 'referral_rewards.dart';
import 'remote_shop_catalog.dart';
import 'shop_item.dart';

export 'shop_item.dart';

/// Los 12 usuarios de demostración (los mismos que usa el otro
/// agente en sus previews): kristian es el usuario actual.
const List<FriendEntry> kDemoSocialUsers = [
  FriendEntry(
      deviceId: 'dev-kristian',
      username: 'kristian',
      points: 1240,
      levelsPassedTotal: 24,
      streak: 12),
  FriendEntry(
      deviceId: 'dev-laura',
      username: 'laura',
      points: 1420,
      levelsPassedTotal: 28,
      streak: 15,
      badgeId: 'badge_star',
      avatarId: 'avatar_dorado'),
  FriendEntry(
      deviceId: 'dev-miguel',
      username: 'miguel',
      points: 980,
      levelsPassedTotal: 19,
      streak: 8),
  FriendEntry(
      deviceId: 'dev-sofia',
      username: 'sofia',
      points: 1580,
      levelsPassedTotal: 31,
      streak: 21,
      badgeId: 'badge_trophy',
      avatarId: 'avatar_violeta'),
  FriendEntry(
      deviceId: 'dev-daniel',
      username: 'daniel',
      points: 760,
      levelsPassedTotal: 15,
      streak: 5),
  FriendEntry(
      deviceId: 'dev-valeria',
      username: 'valeria',
      points: 1310,
      levelsPassedTotal: 26,
      streak: 11),
  FriendEntry(
      deviceId: 'dev-pedro',
      username: 'pedro',
      points: 540,
      levelsPassedTotal: 11,
      streak: 4),
  FriendEntry(
      deviceId: 'dev-camila',
      username: 'camila',
      points: 1150,
      levelsPassedTotal: 22,
      streak: 9,
      avatarId: 'avatar_teal'),
  FriendEntry(
      deviceId: 'dev-yordanis',
      username: 'yordanis',
      points: 890,
      levelsPassedTotal: 17,
      streak: 6),
  FriendEntry(
      deviceId: 'dev-lucia',
      username: 'lucia',
      points: 1470,
      levelsPassedTotal: 29,
      streak: 18,
      badgeId: 'badge_flame'),
  FriendEntry(
      deviceId: 'dev-andres',
      username: 'andres',
      points: 670,
      levelsPassedTotal: 13,
      streak: 3),
  FriendEntry(
      deviceId: 'dev-rosa',
      username: 'rosa',
      points: 1020,
      levelsPassedTotal: 20,
      streak: 7),
];

/// Un amigo (o un miembro de un grupo / un rival): solo lo que
/// compartió (los que no dieron permiso no aparecen nunca).
class FriendEntry {
  const FriendEntry({
    required this.deviceId,
    required this.username,
    required this.points,
    required this.levelsPassedTotal,
    required this.streak,
    this.badgeId,
    this.avatarId,
  });

  final String deviceId;
  final String username;
  final int points;
  final int levelsPassedTotal;
  final int streak;

  /// Insignia equipada ('badge_star' | 'badge_trophy' | 'badge_flame').
  final String? badgeId;

  /// Foto de avatar premium equipada ('avatar_dorado' |
  /// 'avatar_violeta' | 'avatar_teal'), o null: el disco con la
  /// inicial. Los marcos de la tienda existen desde la 7.3 (se
  /// equipan aparte y se dibujan como anillo alrededor de la
  /// foto), pero no viven en este campo.
  final String? avatarId;

  /// Ruta del asset de la foto equipada, o null sin foto.
  String? get avatarAsset => SocialService.avatarAssetForId(avatarId);
}

/// Una solicitud de amistad (colección 'friend_requests' en
/// Firestore, ronda 2d): yo te veo, te mando la solicitud y a ti
/// te llega para confirmarla o eliminarla. Los estados 'aceptada'
/// y 'rechazada' son terminales: la solicitud queda guardada pero
/// ya no se muestra. Rechazar o cancelar NO borra el documento
/// (las reglas lo prohíben): solo cambia el estado a 'rechazada'.
class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.senderUid,
    required this.senderUsername,
    required this.receiverUid,
    required this.receiverUsername,
    required this.status,
    required this.createdAtMs,
  });

  final String id;
  final String senderUid;
  final String senderUsername;
  final String receiverUid;
  final String receiverUsername;

  /// 'pendiente' | 'aceptada' | 'rechazada'.
  final String status;
  final int createdAtMs;

  bool get isPending => status == 'pendiente';

  FriendRequest copyWith({String? status}) => FriendRequest(
        id: id,
        senderUid: senderUid,
        senderUsername: senderUsername,
        receiverUid: receiverUid,
        receiverUsername: receiverUsername,
        status: status ?? this.status,
        createdAtMs: createdAtMs,
      );

  static FriendRequest? fromMap(
      String id, Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final senderUid = raw['senderUid']?.toString() ?? '';
    final receiverUid = raw['receiverUid']?.toString() ?? '';
    if (senderUid.isEmpty || receiverUid.isEmpty) return null;
    return FriendRequest(
      id: id,
      senderUid: senderUid,
      senderUsername: raw['senderUsername']?.toString() ?? '',
      receiverUid: receiverUid,
      receiverUsername: raw['receiverUsername']?.toString() ?? '',
      status: raw['status']?.toString() ?? 'pendiente',
      createdAtMs: (raw['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'senderUid': senderUid,
        'senderUsername': senderUsername,
        'receiverUid': receiverUid,
        'receiverUsername': receiverUsername,
        'status': status,
        'createdAtMs': createdAtMs,
      };
}

/// Resultado de enviar una solicitud de amistad.
enum FriendRequestResult {
  /// La solicitud llegó al otro usuario.
  sent,

  /// Sin internet: quedó guardada en local y se enviará sola
  /// cuando vuelva la conexión.
  queued,

  /// Ya son amigos (no hace falta solicitud).
  alreadyFriends,

  /// Ya hay una solicitud mía pendiente para ese usuario.
  alreadySent,

  /// Ese usuario ya me envió una solicitud pendiente: hay que
  /// confirmarla o eliminarla en vez de enviar otra.
  incomingPending,

  /// No existe ningún usuario con ese nombre (o no compartió).
  notFound,

  /// Intenté agregarme a mí mismo.
  self,

  /// No se pudo enviar (sin Google o error inesperado).
  unavailable,
}

/// Fases de un duelo online (cada jugador en su propio teléfono).
enum DuelPhase {
  /// Buscando rival al azar.
  searching,

  /// Rival encontrado: resumen y botón de empezar.
  intro,

  /// Jugando las 5 preguntas.
  playing,

  /// Yo terminé: esperando a que el rival juegue las suyas.
  waiting,

  /// Los dos terminaron (o victoria por abandono).
  finished,

  /// El rival no respondió a tiempo.
  abandoned,
}

/// Estado de un duelo, empujado por el stream del repositorio.
class DuelState {
  const DuelState({
    required this.matchId,
    required this.opponentName,
    required this.phase,
    required this.questions,
    this.myScore = 0,
    this.opponentScore = 0,
    this.opponentAnswered = false,
    this.opponentConnected = true,
    this.wonByForfeit = false,
    this.myTimeMs = 0,
    this.opponentTimeMs = 0,
    this.winnerIsMe,
    this.incoming = false,
  });

  final String matchId;
  final String opponentName;
  final DuelPhase phase;

  /// Las mismas 5 preguntas para los dos jugadores.
  final List<QuizQuestion> questions;

  final int myScore;
  final int opponentScore;
  final bool opponentAnswered;

  /// false si el rival perdió el internet a mitad de la partida.
  final bool opponentConnected;

  final bool wonByForfeit;

  /// Tiempo total de juego de cada uno, en ms (0 = no se conoce).
  /// El desempate de un duelo es el tiempo: a igualdad de aciertos
  /// gana el más rápido (el servicio cobra +10 al ganador).
  final int myTimeMs;
  final int opponentTimeMs;

  /// Ganador según el servicio (null = el servicio no lo ha dicho
  /// todavía, o empate exacto): true gané yo, false ganó el rival.
  /// La pantalla de resultado manda LO QUE DICE EL SERVICIO, no
  /// calcula el ganador solo por aciertos.
  final bool? winnerIsMe;

  /// true si el duelo llegó de otro jugador (yo soy el retado).
  final bool incoming;

  bool get iWon {
    if (phase != DuelPhase.finished) return false;
    if (wonByForfeit) return true;
    if (winnerIsMe != null) return winnerIsMe!;
    if (myScore != opponentScore) return myScore > opponentScore;
    if (myTimeMs > 0 &&
        opponentTimeMs > 0 &&
        myTimeMs != opponentTimeMs) {
      return myTimeMs < opponentTimeMs;
    }
    return false;
  }

  bool get isDraw {
    if (phase != DuelPhase.finished || wonByForfeit) return false;
    if (winnerIsMe != null) return false;
    if (myScore != opponentScore) return false;
    if (myTimeMs > 0 &&
        opponentTimeMs > 0 &&
        myTimeMs != opponentTimeMs) {
      return false;
    }
    return true;
  }

  /// Sentinel para poder poner winnerIsMe a null (empate exacto):
  /// copyWith(winnerIsMe: null) borra el ganador; sin el parámetro
  /// se conserva el valor actual.
  static const _unsetWinner = Object();

  DuelState copyWith({
    DuelPhase? phase,
    int? myScore,
    int? opponentScore,
    bool? opponentAnswered,
    bool? opponentConnected,
    bool? wonByForfeit,
    int? myTimeMs,
    int? opponentTimeMs,
    Object? winnerIsMe = _unsetWinner,
    bool? incoming,
  }) =>
      DuelState(
        matchId: matchId,
        opponentName: opponentName,
        phase: phase ?? this.phase,
        questions: questions,
        myScore: myScore ?? this.myScore,
        opponentScore: opponentScore ?? this.opponentScore,
        opponentAnswered: opponentAnswered ?? this.opponentAnswered,
        opponentConnected: opponentConnected ?? this.opponentConnected,
        wonByForfeit: wonByForfeit ?? this.wonByForfeit,
        myTimeMs: myTimeMs ?? this.myTimeMs,
        opponentTimeMs: opponentTimeMs ?? this.opponentTimeMs,
        winnerIsMe: winnerIsMe == _unsetWinner
            ? this.winnerIsMe
            : winnerIsMe as bool?,
        incoming: incoming ?? this.incoming,
      );
}

/// Las 5 preguntas de un duelo: del banco, con sus datos
/// ("Datos: ..." en el texto) y exactamente 4 opciones cada una.
const List<QuizQuestion> kDuelQuestions = [
  QuizQuestion(
    topic: 'estequiometria',
    question:
        '¿Cuántos moles hay en 36 g de agua?\nDatos: M = 18.02 g/mol',
    options: ['0.50 mol', '1.00 mol', '2.00 mol', '3.60 mol'],
    answer: 2,
    explanation: 'n = m/M = 36 g ÷ 18.02 g/mol ≈ 2.00 mol.',
    difficulty: 2,
  ),
  QuizQuestion(
    topic: 'estequiometria',
    question: '¿Cuál es la masa molar del Ca(OH)₂?\n'
        'Datos: Ca 40.08, O 16.00, H 1.01',
    options: ['57.09 g/mol', '58.10 g/mol', '74.10 g/mol', '90.08 g/mol'],
    answer: 2,
    explanation: '40.08 + 2×16.00 + 2×1.01 = 74.10 g/mol.',
    difficulty: 2,
  ),
  QuizQuestion(
    topic: 'gases',
    question: 'Un gas a 300 K y 1 atm ocupa 10 L. Si se calienta a '
        '600 K a presión constante, ocupará:\n'
        'Datos: P constante, T₁ = 300 K, T₂ = 600 K',
    options: ['5 L', '10 L', '15 L', '20 L'],
    answer: 3,
    explanation: 'Ley de Charles: V∝T (en kelvin). Al duplicar T, V se duplica: 20 L.',
    difficulty: 2,
  ),
  QuizQuestion(
    topic: 'estequiometria',
    question: '¿Cuántas moléculas hay en 0.25 mol de CO₂?\n'
        'Datos: Nₐ = 6.022×10²³ mol⁻¹',
    options: ['1.51×10²³', '3.01×10²³', '6.02×10²³', '1.20×10²⁴'],
    answer: 0,
    explanation: 'N = 0.25 × 6.022×10²³ = 1.51×10²³ moléculas.',
    difficulty: 2,
  ),
  QuizQuestion(
    topic: 'gases',
    question: 'Convierte 27 °C a kelvin:\nDatos: K = °C + 273.15',
    options: ['27 K', '273 K', '300 K', '310 K'],
    answer: 2,
    explanation: 'K = °C + 273.15 ≈ 300 K.',
    difficulty: 1,
  ),
];

/// Un torneo: título, tema, fechas, preguntas, premio en puntos.
class TournamentInfo {
  const TournamentInfo({
    required this.id,
    required this.title,
    required this.topic,
    required this.dateRange,
    required this.questionCount,
    required this.prizePoints,
    required this.status,
    this.myBestScore,
    this.joined = false,
    this.ranking = const [],
  });

  final String id;
  final String title;
  final String topic;

  /// Rango ya formateado para mostrar ("10–16 nov").
  final String dateRange;
  final int questionCount;
  final int prizePoints;

  /// 'active' | 'upcoming'.
  final String status;

  /// Mi mejor puntaje en este torneo, o null si aún no jugué.
  final int? myBestScore;
  final bool joined;

  /// Clasificación actual (mejor puntaje de cada uno), ordenada.
  final List<FriendEntry> ranking;

  TournamentInfo copyWith({
    int? myBestScore,
    bool? joined,
    List<FriendEntry>? ranking,
  }) =>
      TournamentInfo(
        id: id,
        title: title,
        topic: topic,
        dateRange: dateRange,
        questionCount: questionCount,
        prizePoints: prizePoints,
        status: status,
        myBestScore: myBestScore ?? this.myBestScore,
        joined: joined ?? this.joined,
        ranking: ranking ?? this.ranking,
      );
}

/// Un artículo de la tienda y el catálogo fijo de respaldo viven
/// en 'shop_item.dart' (el catálogo real es remoto, Firestore
/// 'shop_items', ver RemoteShopCatalog).

/// Un grupo de estudio (sin chat): nombre, código y miembros.
class StudyGroup {
  const StudyGroup({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.members,
  });

  final String id;
  final String name;
  final String inviteCode;
  final List<FriendEntry> members;

  StudyGroup copyWith({List<FriendEntry>? members}) => StudyGroup(
        id: id,
        name: name,
        inviteCode: inviteCode,
        members: members ?? this.members,
      );
}

/// Un reporte de pregunta (lo que vio el usuario que reportó).
class QuestionReport {
  const QuestionReport({
    required this.questionId,
    required this.reason,
    required this.at,
  });

  final String questionId;
  final String reason;
  final DateTime at;
}

/// Contrato que debe cumplir el backend social (hoy solo lo
/// implementa el falso en memoria; el de Firestore va aparte).
abstract class SocialRepository {
  /// ¿El backend está alcanzable? false = sin internet.
  Future<bool> get online;

  // --- Amigos ---
  Future<List<FriendEntry>> friends();
  Stream<List<FriendEntry>> friendsStream();
  Future<FriendEntry?> findUserByUsername(String username);
  Future<bool> addFriend(String username);
  Future<void> removeFriend(String deviceId);

  // --- Solicitudes de amistad (ronda 2d) ---
  Future<FriendRequestResult> sendFriendRequest(String username);
  Future<List<FriendRequest>> incomingFriendRequests();
  Future<List<FriendRequest>> sentFriendRequests();
  Future<bool> acceptFriendRequest(String requestId);
  Future<void> rejectFriendRequest(String requestId);
  Future<void> cancelFriendRequest(String requestId);

  /// Reenvía las solicitudes que quedaron encoladas sin internet.
  /// Devuelve cuántas se enviaron.
  Future<int> retryPendingFriendRequests();

  // --- Duelos ---
  Future<DuelState> createDuel({String? opponentUsername, bool random = false});
  Stream<DuelState> duelStream(String matchId);
  Future<void> submitDuelScore(String matchId, int score,
      {int timeMs = 0});
  Future<void> forfeitDuel(String matchId);
  Future<void> cancelDuel(String matchId);

  /// Mis duelos abiertos (soy jugador y siguen activos), del más
  /// reciente al más viejo: la lista para que el retado abra el
  /// suyo. Vacío sin Google o sin red.
  Future<List<DuelState>> myOpenDuels();

  // --- Torneos ---
  Future<List<TournamentInfo>> tournaments();
  Stream<List<TournamentInfo>> tournamentsStream();
  Future<void> joinTournament(String id);
  Future<TournamentInfo?> submitTournamentScore(String id, int score,
      {int timeMs = 0});

  // --- Tienda ---
  Future<List<ShopItem>> shopItems();
  Future<void> syncPurchase(String itemId);

  /// Sincroniza lo EQUIPADO (no solo la propiedad): [kind] es
  /// 'theme', 'avatar' o 'badge'; [itemId] null = se quitó.
  Future<void> syncEquipped(String kind, String? itemId);

  // --- Grupos ---
  Future<List<StudyGroup>> groups();
  Future<StudyGroup> createGroup(String name);
  Future<StudyGroup?> joinGroup(String code);
  Future<void> leaveGroup(String id);

  // --- Reportes ---
  Future<void> reportQuestion(String questionId, String reason);
}

/// Stream que emite el valor actual al suscribirse y cada cambio.
class _ValueStream<T> {
  _ValueStream(this._current);
  T _current;
  final _ctrl = StreamController<T>.broadcast();

  Stream<T> get stream {
    late StreamController<T> out;
    out = StreamController<T>(
      onListen: () {
        out.add(_current);
        final sub = _ctrl.stream.listen(
          out.add,
          onError: out.addError,
          onDone: out.close,
        );
        out.onCancel = sub.cancel;
      },
    );
    return out.stream;
  }

  void update(T value) {
    _current = value;
    if (!_ctrl.isClosed) _ctrl.add(value);
  }

  T get current => _current;

  void dispose() => _ctrl.close();
}

class _DuelRecord {
  _DuelRecord(this.state);

  DuelState state;
  final _ctrl = StreamController<DuelState>.broadcast();

  Stream<DuelState> get stream {
    late StreamController<DuelState> out;
    out = StreamController<DuelState>(
      onListen: () {
        out.add(state);
        final sub = _ctrl.stream.listen(
          out.add,
          onError: out.addError,
          onDone: out.close,
        );
        out.onCancel = sub.cancel;
      },
    );
    return out.stream;
  }

  void emit(DuelState next) {
    state = next;
    if (!_ctrl.isClosed) _ctrl.add(next);
  }

  void dispose() => _ctrl.close();
}

/// Falso en memoria: toda la lógica social sin servidor. Sirve
/// para tests y previews; el `seedDemo` siembra los 12 usuarios,
/// 3 amigos, 3 torneos y 1 grupo de demostración. Los métodos
/// `simulate*` son ganchos para tests y previews: simulan lo que
/// en producción empuja Firestore (el rival termina, se
/// desconecta, no responde...). Nunca lanza por red: si
/// [online] es false, los métodos de lectura devuelven vacío y
/// los de escritura hacen nada.
class InMemorySocialRepository implements SocialRepository {
  InMemorySocialRepository({bool seedDemo = false}) {
    if (seedDemo) {
      _friends = [
        kDemoSocialUsers[1], // laura
        kDemoSocialUsers[2], // miguel
        kDemoSocialUsers[3], // sofia
      ];
      _tournaments = [
        TournamentInfo(
          id: 't1',
          title: 'Torneo de Estequiometría',
          topic: 'Estequiometría',
          dateRange: '10–16 nov',
          questionCount: 20,
          prizePoints: 500,
          status: 'active',
          myBestScore: 12,
          joined: true,
          ranking: [
            kDemoSocialUsers[3].copyAs(points: 19),
            kDemoSocialUsers[1].copyAs(points: 18),
            kDemoSocialUsers[0].copyAs(points: 12),
            kDemoSocialUsers[2].copyAs(points: 11),
          ],
        ),
        TournamentInfo(
          id: 't2',
          title: 'Torneo de Gases',
          topic: 'Gases',
          dateRange: '11–17 nov',
          questionCount: 15,
          prizePoints: 400,
          status: 'active',
          ranking: [
            kDemoSocialUsers[9].copyAs(points: 14),
            kDemoSocialUsers[4].copyAs(points: 13),
            kDemoSocialUsers[8].copyAs(points: 10),
          ],
        ),
        TournamentInfo(
          id: 't3',
          title: 'Torneo de Enlace Químico',
          topic: 'Enlace químico',
          dateRange: '20–26 nov',
          questionCount: 25,
          prizePoints: 800,
          status: 'upcoming',
        ),
      ];
      _groups = [
        StudyGroup(
          id: 'g1',
          name: 'Químicos nocturnos',
          inviteCode: 'QUIM-4821',
          members: [
            kDemoSocialUsers[0],
            kDemoSocialUsers[1],
            kDemoSocialUsers[2],
            kDemoSocialUsers[3],
          ],
        ),
      ];
    }
    _friendsStream = _ValueStream<List<FriendEntry>>(_friends);
    _tournamentsStream = _ValueStream<List<TournamentInfo>>(_tournaments);
  }

  /// ¿Hay "internet"? Los tests lo apagan para probar los estados
  /// tranquilos sin conexión.
  bool onlineFlag = true;

  @override
  Future<bool> get online async => onlineFlag;

  var _friends = <FriendEntry>[];
  var _tournaments = <TournamentInfo>[];
  var _groups = <StudyGroup>[];
  late final _ValueStream<List<FriendEntry>> _friendsStream;
  late final _ValueStream<List<TournamentInfo>> _tournamentsStream;
  final _duels = <String, _DuelRecord>{};
  final reports = <QuestionReport>[];
  final syncedPurchases = <String>{};

  /// Lo equipado que se sincronizó (para tests): kind → itemId
  /// (null = se quitó).
  final syncedEquipped = <String, String?>{};

  /// Mejor tiempo (ms) de cada torneo por usuario, para el
  /// desempate: a igualdad de puntos gana el más rápido.
  final _tournTimes = <String, Map<String, int>>{};
  var _matchCounter = 0;
  var _groupCounter = 1;

  List<FriendEntry> get currentFriends =>
      List<FriendEntry>.unmodifiable(_friends);
  List<TournamentInfo> get currentTournaments =>
      List<TournamentInfo>.unmodifiable(_tournaments);
  List<StudyGroup> get currentGroups =>
      List<StudyGroup>.unmodifiable(_groups);

  bool _checkOnline() => onlineFlag;

  @override
  Future<List<FriendEntry>> friends() async =>
      _checkOnline() ? currentFriends : <FriendEntry>[];

  @override
  Stream<List<FriendEntry>> friendsStream() => _friendsStream.stream;

  @override
  Future<FriendEntry?> findUserByUsername(String username) async {
    if (!_checkOnline()) return null;
    final name = username.trim().toLowerCase();
    if (name.isEmpty || name == 'kristian') return null;
    for (final u in kDemoSocialUsers) {
      if (u.username == name) return u;
    }
    return null;
  }

  @override
  Future<bool> addFriend(String username) async {
    final found = await findUserByUsername(username);
    if (found == null) return false;
    if (_friends.any((f) => f.deviceId == found.deviceId)) return true;
    _friends = [..._friends, found];
    _friendsStream.update(currentFriends);
    return true;
  }

  @override
  Future<void> removeFriend(String deviceId) async {
    _friends = _friends.where((f) => f.deviceId != deviceId).toList();
    _friendsStream.update(currentFriends);
    // Si la amistad vino de una solicitud aceptada, se rompe en
    // los dos sentidos (igual que en el servicio real).
    _friendRequests = _friendRequests
        .map((r) => r.status == 'aceptada' &&
                (r.senderUid == deviceId || r.receiverUid == deviceId)
            ? r.copyWith(status: 'rechazada')
            : r)
        .toList();
  }

  // --- Solicitudes de amistad (ronda 2d) ---

  /// Yo en el falso: 'dev-kristian' / 'kristian'.
  static const String _meId = 'dev-kristian';

  var _friendRequests = <FriendRequest>[];
  var _requestCounter = 0;

  /// Nombres encolados sin internet (se reenvían solos al volver
  /// la conexión con [retryPendingFriendRequests]).
  final _queuedRequestUsernames = <String>[];

  /// Escrituras en la lista de amigos DEL OTRO usuario (para
  /// tests): uid del otro → uids que se le añadieron. Al confirmar
  /// una solicitud, yo quedo en la lista de amigos del remitente.
  final _otherSideFriends = <String, Set<String>>{};

  List<FriendRequest> get currentFriendRequests =>
      List<FriendRequest>.unmodifiable(_friendRequests);

  Map<String, Set<String>> get otherSideFriends =>
      Map<String, Set<String>>.unmodifiable(_otherSideFriends);

  List<String> get queuedRequestUsernames =>
      List<String>.unmodifiable(_queuedRequestUsernames);

  FriendEntry? _demoUserByName(String username) {
    final name = username.trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final u in kDemoSocialUsers) {
      if (u.username == name) return u;
    }
    return null;
  }

  @override
  Future<FriendRequestResult> sendFriendRequest(String username) async {
    final name = username.trim();
    if (name.isEmpty) return FriendRequestResult.notFound;
    // Sin internet no se puede validar nada: se encola y se envía
    // sola cuando vuelva la conexión (la validación corre entonces).
    if (!_checkOnline()) {
      if (!_queuedRequestUsernames.contains(name)) {
        _queuedRequestUsernames.add(name);
      }
      return FriendRequestResult.queued;
    }
    if (name.toLowerCase() == 'kristian') {
      return FriendRequestResult.self;
    }
    final found = await findUserByUsername(name);
    if (found == null) return FriendRequestResult.notFound;
    if (_friends.any((f) => f.deviceId == found.deviceId)) {
      return FriendRequestResult.alreadyFriends;
    }
    if (_friendRequests.any((r) =>
        r.isPending &&
        r.senderUid == _meId &&
        r.receiverUid == found.deviceId)) {
      return FriendRequestResult.alreadySent;
    }
    if (_friendRequests.any((r) =>
        r.isPending &&
        r.senderUid == found.deviceId &&
        r.receiverUid == _meId)) {
      return FriendRequestResult.incomingPending;
    }
    _requestCounter++;
    _friendRequests = [
      ..._friendRequests,
      FriendRequest(
        id: 'fr-$_requestCounter',
        senderUid: _meId,
        senderUsername: 'kristian',
        receiverUid: found.deviceId,
        receiverUsername: found.username,
        status: 'pendiente',
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    ];
    return FriendRequestResult.sent;
  }

  @override
  Future<List<FriendRequest>> incomingFriendRequests() async {
    if (!_checkOnline()) return <FriendRequest>[];
    final out = _friendRequests
        .where((r) => r.isPending && r.receiverUid == _meId)
        .toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return out;
  }

  @override
  Future<List<FriendRequest>> sentFriendRequests() async {
    if (!_checkOnline()) return <FriendRequest>[];
    final out = _friendRequests
        .where((r) => r.isPending && r.senderUid == _meId)
        .toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return out;
  }

  @override
  Future<bool> acceptFriendRequest(String requestId) async {
    final index = _friendRequests.indexWhere(
        (r) => r.id == requestId && r.isPending && r.receiverUid == _meId);
    if (index < 0) return false;
    final req = _friendRequests[index];
    _friendRequests = [
      ..._friendRequests.sublist(0, index),
      req.copyWith(status: 'aceptada'),
      ..._friendRequests.sublist(index + 1),
    ];
    // Los dos quedan amigos: el remitente entra en mi lista y yo
    // quedo en la suya (en producción, escritura en su documento
    // de usuario con la regla estrecha de 'friends').
    final sender = _demoUserByName(req.senderUsername);
    if (sender != null &&
        !_friends.any((f) => f.deviceId == sender.deviceId)) {
      _friends = [..._friends, sender];
      _friendsStream.update(currentFriends);
    }
    _otherSideFriends
        .putIfAbsent(req.senderUid, () => <String>{})
        .add(_meId);
    return true;
  }

  @override
  Future<void> rejectFriendRequest(String requestId) async {
    final index = _friendRequests.indexWhere(
        (r) => r.id == requestId && r.isPending && r.receiverUid == _meId);
    if (index < 0) return;
    _friendRequests = [
      ..._friendRequests.sublist(0, index),
      _friendRequests[index].copyWith(status: 'rechazada'),
      ..._friendRequests.sublist(index + 1),
    ];
  }

  @override
  Future<void> cancelFriendRequest(String requestId) async {
    final index = _friendRequests.indexWhere(
        (r) => r.id == requestId && r.isPending && r.senderUid == _meId);
    if (index < 0) return;
    _friendRequests = [
      ..._friendRequests.sublist(0, index),
      _friendRequests[index].copyWith(status: 'rechazada'),
      ..._friendRequests.sublist(index + 1),
    ];
  }

  @override
  Future<int> retryPendingFriendRequests() async {
    if (!_checkOnline()) return 0;
    var done = 0;
    for (final name in List<String>.of(_queuedRequestUsernames)) {
      final result = await sendFriendRequest(name);
      if (result != FriendRequestResult.queued) {
        _queuedRequestUsernames.remove(name);
        if (result == FriendRequestResult.sent) done++;
      }
    }
    return done;
  }

  /// Gancho de test/preview: llega una solicitud de amistad de
  /// otro usuario (yo soy el destinatario). Null si no existe.
  FriendRequest? simulateIncomingFriendRequest(String username) {
    final sender = _demoUserByName(username);
    if (sender == null || sender.deviceId == _meId) return null;
    _requestCounter++;
    final req = FriendRequest(
      id: 'fr-$_requestCounter',
      senderUid: sender.deviceId,
      senderUsername: sender.username,
      receiverUid: _meId,
      receiverUsername: 'kristian',
      status: 'pendiente',
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _friendRequests = [..._friendRequests, req];
    return req;
  }

  /// Gancho de test/preview: yo ya envié una solicitud pendiente
  /// a ese usuario (para la sección de enviadas).
  FriendRequest? simulateSentFriendRequest(String username) {
    final target = _demoUserByName(username);
    if (target == null || target.deviceId == _meId) return null;
    _requestCounter++;
    final req = FriendRequest(
      id: 'fr-$_requestCounter',
      senderUid: _meId,
      senderUsername: 'kristian',
      receiverUid: target.deviceId,
      receiverUsername: target.username,
      status: 'pendiente',
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _friendRequests = [..._friendRequests, req];
    return req;
  }

  // --- Duelos ---

  @override
  Future<DuelState> createDuel(
      {String? opponentUsername, bool random = false}) async {
    _matchCounter++;
    final id = 'duel-$_matchCounter';
    if (random) {
      // Al azar: primero buscando; el rival aparece enseguida.
      final state = DuelState(
        matchId: id,
        opponentName: '',
        phase: DuelPhase.searching,
        questions: kDuelQuestions,
      );
      final record = _DuelRecord(state);
      _duels[id] = record;
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (!_duels.containsKey(id)) return;
        record.emit(DuelState(
          matchId: id,
          opponentName: 'valeria',
          phase: DuelPhase.intro,
          questions: kDuelQuestions,
        ));
      });
      return state;
    }
    final name = (opponentUsername ?? 'laura').trim().toLowerCase();
    final state = DuelState(
      matchId: id,
      opponentName: name.isEmpty ? 'laura' : name,
      phase: DuelPhase.intro,
      questions: kDuelQuestions,
    );
    _duels[id] = _DuelRecord(state);
    return state;
  }

  @override
  Stream<DuelState> duelStream(String matchId) {
    final record = _duels[matchId];
    if (record == null) {
      return Stream<DuelState>.value(DuelState(
        matchId: matchId,
        opponentName: '',
        phase: DuelPhase.abandoned,
        questions: kDuelQuestions,
      ));
    }
    return record.stream;
  }

  @override
  Future<void> submitDuelScore(String matchId, int score,
      {int timeMs = 0}) async {
    final record = _duels[matchId];
    if (record == null) return;
    var next = record.state.copyWith(
      myScore: score,
      myTimeMs: timeMs,
    );
    if (record.state.opponentAnswered) {
      // El rival ya terminó: el duelo se cierra y el ganador lo
      // decide el desempate (aciertos, luego tiempo).
      next = next.copyWith(
        phase: DuelPhase.finished,
        winnerIsMe: _decideWinner(next),
      );
    } else {
      next = next.copyWith(phase: DuelPhase.waiting);
    }
    record.emit(next);
  }

  /// Mis duelos abiertos (del más reciente al más viejo). Sin
  /// internet devuelve la lista local igual: es un estado
  /// tranquilo, no un error.
  @override
  Future<List<DuelState>> myOpenDuels() async {
    const open = {
      DuelPhase.searching,
      DuelPhase.intro,
      DuelPhase.playing,
      DuelPhase.waiting,
    };
    final out = _duels.values
        .map((r) => r.state)
        .where((s) => open.contains(s.phase))
        .toList();
    return out.reversed.toList();
  }

  /// Gancho de test/preview: llega un duelo de otro jugador (yo
  /// soy el retado). Devuelve el estado inicial (intro).
  DuelState simulateIncomingDuel(String opponentName) {
    _matchCounter++;
    final id = 'duel-$_matchCounter';
    final state = DuelState(
      matchId: id,
      opponentName: opponentName.trim().toLowerCase(),
      phase: DuelPhase.intro,
      questions: kDuelQuestions,
      incoming: true,
    );
    _duels[id] = _DuelRecord(state);
    return state;
  }

  @override
  Future<void> forfeitDuel(String matchId) async {
    final record = _duels[matchId];
    if (record == null) return;
    record.emit(record.state.copyWith(
      phase: DuelPhase.finished,
      wonByForfeit: true,
    ));
  }

  @override
  Future<void> cancelDuel(String matchId) async {
    final record = _duels.remove(matchId);
    record?.dispose();
  }

  /// Gancho de test/preview: el rival termina con [score] en
  /// [timeMs] ms. Si yo ya terminé, el duelo se cierra y el
  /// ganador sale del desempate (aciertos, luego tiempo); si yo
  /// aún no jugué, solo queda registrado su resultado.
  void simulateOpponentFinishes(String matchId, int score,
      {int timeMs = 0}) {
    final record = _duels[matchId];
    if (record == null) return;
    var next = record.state.copyWith(
      opponentScore: score,
      opponentAnswered: true,
      opponentTimeMs: timeMs,
    );
    if (record.state.phase == DuelPhase.waiting) {
      next = next.copyWith(
        phase: DuelPhase.finished,
        winnerIsMe: _decideWinner(next),
      );
    }
    record.emit(next);
  }

  /// Ganador por aciertos y, en empate, por tiempo (como el
  /// servicio real): null = empate exacto o tiempos desconocidos.
  static bool? _decideWinner(DuelState s) {
    if (s.myScore != s.opponentScore) return s.myScore > s.opponentScore;
    if (s.myTimeMs > 0 &&
        s.opponentTimeMs > 0 &&
        s.myTimeMs != s.opponentTimeMs) {
      return s.myTimeMs < s.opponentTimeMs;
    }
    return null;
  }

  /// Gancho de test/preview: el rival perdió el internet.
  void simulateOpponentDisconnects(String matchId) {
    final record = _duels[matchId];
    if (record == null) return;
    record.emit(record.state.copyWith(opponentConnected: false));
  }

  /// Gancho de test/preview: el rival volvió.
  void simulateOpponentReconnects(String matchId) {
    final record = _duels[matchId];
    if (record == null) return;
    record.emit(record.state.copyWith(opponentConnected: true));
  }

  /// Gancho de test/preview: el rival no respondió a tiempo.
  void simulateOpponentAbandons(String matchId) {
    final record = _duels[matchId];
    if (record == null) return;
    record.emit(record.state.copyWith(phase: DuelPhase.abandoned));
  }

  // --- Torneos ---

  @override
  Future<List<TournamentInfo>> tournaments() async =>
      _checkOnline() ? currentTournaments : <TournamentInfo>[];

  @override
  Stream<List<TournamentInfo>> tournamentsStream() =>
      _tournamentsStream.stream;

  @override
  Future<void> joinTournament(String id) async {
    _tournaments = _tournaments
        .map((t) => t.id == id ? t.copyWith(joined: true) : t)
        .toList();
    _tournamentsStream.update(currentTournaments);
  }

  @override
  Future<TournamentInfo?> submitTournamentScore(String id, int score,
      {int timeMs = 0}) async {
    final index = _tournaments.indexWhere((t) => t.id == id);
    if (index < 0) return null;
    final old = _tournaments[index];
    final best = old.myBestScore == null
        ? score
        : (score > old.myBestScore! ? score : old.myBestScore!);
    // El tiempo real del intento: en empate de puntos gana el más
    // rápido (como el servicio real, que guarda bestTimeMs).
    final times = _tournTimes.putIfAbsent(id, () => <String, int>{});
    if (score > (old.myBestScore ?? -1)) {
      if (timeMs > 0) {
        times['kristian'] = timeMs;
      } else {
        times.remove('kristian');
      }
    } else if (score == old.myBestScore && timeMs > 0) {
      final prev = times['kristian'];
      if (prev == null || timeMs < prev) times['kristian'] = timeMs;
    }
    final me = kDemoSocialUsers[0].copyAs(points: best);
    final ranking = [
      ...old.ranking.where((r) => r.deviceId != me.deviceId),
      me,
    ]..sort((a, b) {
        final byPoints = b.points.compareTo(a.points);
        if (byPoints != 0) return byPoints;
        // Empate de puntos: el más rápido primero (sin tiempo
        // conocido se queda detrás de quien sí lo tiene).
        const huge = 1 << 62;
        final ta = times[a.username] ?? huge;
        final tb = times[b.username] ?? huge;
        return ta.compareTo(tb);
      });
    final next = old.copyWith(myBestScore: best, ranking: ranking);
    _tournaments = [
      ..._tournaments.sublist(0, index),
      next,
      ..._tournaments.sublist(index + 1),
    ];
    _tournamentsStream.update(currentTournaments);
    return next;
  }

  /// Mejor tiempo registrado de un usuario en un torneo (para
  /// tests): null si no hay tiempo conocido.
  int? tournamentBestTimeMs(String tournamentId, String username) =>
      _tournTimes[tournamentId]?[username];

  // --- Tienda ---

  @override
  Future<List<ShopItem>> shopItems() async =>
      _checkOnline() ? kShopCatalog : <ShopItem>[];

  @override
  Future<void> syncPurchase(String itemId) async {
    syncedPurchases.add(itemId);
  }

  @override
  Future<void> syncEquipped(String kind, String? itemId) async {
    syncedEquipped[kind] = itemId;
  }

  // --- Grupos ---

  @override
  Future<List<StudyGroup>> groups() async =>
      _checkOnline() ? currentGroups : <StudyGroup>[];

  @override
  Future<StudyGroup> createGroup(String name) async {
    _groupCounter++;
    final code = 'QUIM-${1000 + Random().nextInt(9000)}';
    final group = StudyGroup(
      id: 'g$_groupCounter',
      name: name.trim().isEmpty ? 'Mi grupo' : name.trim(),
      inviteCode: code,
      members: [kDemoSocialUsers[0]],
    );
    _groups = [..._groups, group];
    return group;
  }

  @override
  Future<StudyGroup?> joinGroup(String code) async {
    if (!_checkOnline()) return null;
    final wanted = code.trim().toUpperCase();
    for (final g in _groups) {
      if (g.inviteCode.toUpperCase() == wanted) {
        if (!g.members.any((m) => m.deviceId == 'dev-kristian')) {
          _groups = _groups
              .map((x) => x.id == g.id
                  ? x.copyWith(members: [...x.members, kDemoSocialUsers[0]])
                  : x)
              .toList();
        }
        return _groups.firstWhere((x) => x.id == g.id);
      }
    }
    return null;
  }

  @override
  Future<void> leaveGroup(String id) async {
    _groups = _groups
        .map((g) => g.id == id
            ? g.copyWith(
                members: g.members
                    .where((m) => m.deviceId != 'dev-kristian')
                    .toList())
            : g)
        .toList();
  }

  // --- Reportes ---

  @override
  Future<void> reportQuestion(String questionId, String reason) async {
    reports.add(QuestionReport(
      questionId: questionId,
      reason: reason,
      at: DateTime.now(),
    ));
  }
}

extension on FriendEntry {
  /// Copia cambiando solo los puntos (el puntaje en un torneo).
  FriendEntry copyAs({int? points}) => FriendEntry(
        deviceId: deviceId,
        username: username,
        points: points ?? this.points,
        levelsPassedTotal: levelsPassedTotal,
        streak: streak,
        badgeId: badgeId,
        avatarId: avatarId,
      );
}

/// Fachada estática para la UI. Nunca lanza: si algo falla, devuelve
/// el valor tranquilo (lista vacía / false / null).
class SocialService {
  SocialService._();

  static SocialRepository _repo = InMemorySocialRepository();

  static SocialRepository get repository => _repo;

  /// Instala otro repositorio (Firestore, en producción; el falso,
  /// en tests). Para tests, preferir [setRepositoryForTests].
  static void setRepositoryForTests(SocialRepository repo) {
    _repo = repo;
  }

  static void resetForTests() {
    _repo = InMemorySocialRepository();
    _owned = null;
    _equippedThemeId = null;
    _equippedAvatarId = null;
    _equippedBadgeId = null;
    _equippedFrameId = null;
    equippedAvatarIdNotifier.value = null;
    equippedFrameIdNotifier.value = null;
    RemoteShopCatalog.instance.resetForTests();
  }

  static Future<T> _safe<T>(Future<T> Function() run, T fallback) async {
    try {
      return await run();
    } catch (_) {
      return fallback;
    }
  }

  static Future<void> _safeVoid(Future<void> Function() run) async {
    try {
      await run();
    } catch (_) {}
  }

  static Stream<T> _safeStream<T>(Stream<T> source) =>
      source.handleError((Object _) {});

  static Future<bool> get online => _safe(() => _repo.online, false);

  // --- Amigos ---

  static Future<List<FriendEntry>> friends() =>
      _safe(() => _repo.friends(), <FriendEntry>[]);

  static Stream<List<FriendEntry>> friendsStream() =>
      _safeStream(_repo.friendsStream());

  static Future<bool> addFriend(String username) =>
      _safe(() => _repo.addFriend(username), false);

  static Future<void> removeFriend(String deviceId) =>
      _safeVoid(() => _repo.removeFriend(deviceId));

  static Future<FriendEntry?> findUserByUsername(String username) =>
      _safe(() => _repo.findUserByUsername(username), null);

  // --- Solicitudes de amistad (ronda 2d) ---

  static Future<FriendRequestResult> sendFriendRequest(String username) =>
      _safe(() => _repo.sendFriendRequest(username),
          FriendRequestResult.unavailable);

  static Future<List<FriendRequest>> incomingFriendRequests() =>
      _safe(() => _repo.incomingFriendRequests(), <FriendRequest>[]);

  static Future<List<FriendRequest>> sentFriendRequests() =>
      _safe(() => _repo.sentFriendRequests(), <FriendRequest>[]);

  static Future<bool> acceptFriendRequest(String requestId) =>
      _safe(() => _repo.acceptFriendRequest(requestId), false);

  static Future<void> rejectFriendRequest(String requestId) =>
      _safeVoid(() => _repo.rejectFriendRequest(requestId));

  static Future<void> cancelFriendRequest(String requestId) =>
      _safeVoid(() => _repo.cancelFriendRequest(requestId));

  static Future<int> retryPendingFriendRequests() =>
      _safe(() => _repo.retryPendingFriendRequests(), 0);

  /// Sincroniza la bandeja con las solicitudes entrantes
  /// pendientes: una entrada por solicitud (id
  /// 'friend-request-<id>'), sin duplicados y sin volver a marcar
  /// como no leída una que ya se leyó. La campana sube sola con el
  /// numerito de no leídos. Se llama al abrir Amigos.
  static Future<void> syncFriendRequestInbox() async {
    final incoming =
        await _safe(() => _repo.incomingFriendRequests(), <FriendRequest>[]);
    for (final r in incoming) {
      await NotificationInbox.addIfAbsent(
        id: 'friend-request-${r.id}',
        kind: InboxKind.friendRequest,
        title: tr('inboxFriendRequestTitle')
            .replaceFirst('%s', r.senderUsername),
        body: tr('inboxFriendRequestBody'),
        data: {'requestId': r.id, 'senderUsername': r.senderUsername},
      );
    }
  }

  /// Sincroniza la bandeja con mis duelos (Zona G2, capa sin push):
  /// un reto o un resultado que llegó mientras no había internet
  /// (o sin que el push llegara) aparece en Notificaciones al abrir
  /// la app, igual que las solicitudes. Los ids son los MISMOS que
  /// usa el push ('duel-challenge-<id>' / 'duel-result-<id>', ver
  /// push_service.dart), así que un duelo que llegó por push y luego
  /// se sincroniza no deja dos entradas. Solo se sincronizan los
  /// resultados de duelos creados en los últimos 7 días (un duelo
  /// viejo ya se vio en su pantalla de resultado). Sin Google o sin
  /// internet no hace nada (myOpenDuels y myFinishedDuels devuelven
  /// vacío) y nunca lanza.
  static Future<void> syncDuelInbox() async {
    final open = await myOpenDuels();
    for (final d in open) {
      if (!d.incoming) continue;
      if (d.phase == DuelPhase.finished ||
          d.phase == DuelPhase.abandoned) {
        continue;
      }
      await NotificationInbox.addIfAbsent(
        id: 'duel-challenge-${d.matchId}',
        kind: InboxKind.duel,
        title: tr('duelAgainst').replaceFirst('%s', d.opponentName),
        body: tr('duelStart'),
        data: {'duelId': d.matchId, 'pushType': 'duel_challenge'},
      );
    }
    final finished =
        await _safe(() => DuelService.myFinishedDuels(), <Duel>[]);
    if (finished.isEmpty) return;
    final me = AuthService.currentUid ?? '';
    final weekAgo = DateTime.now().millisecondsSinceEpoch -
        const Duration(days: 7).inMilliseconds;
    for (final duel in finished) {
      if (duel.createdAtMs < weekAgo) continue;
      final rival = duel.rivalName(me);
      final title = duel.winnerUid == null
          ? tr('duelDraw')
          : (duel.winnerUid == me ? tr('duelYouWin') : tr('duelYouLose'));
      await NotificationInbox.addIfAbsent(
        id: 'duel-result-${duel.id}',
        kind: InboxKind.duel,
        title: title,
        body: tr('duelAgainst').replaceFirst('%s', rival),
        data: {'duelId': duel.id, 'pushType': 'duel_result'},
      );
    }
  }

  // --- Duelos ---

  static Future<DuelState?> createDuel(
          {String? opponentUsername, bool random = false}) =>
      _safe(
          () => _repo.createDuel(
              opponentUsername: opponentUsername, random: random),
          null);

  static Stream<DuelState> duelStream(String matchId) =>
      _safeStream(_repo.duelStream(matchId));

  static Future<void> submitDuelScore(String matchId, int score,
          {int timeMs = 0}) =>
      _safeVoid(
          () => _repo.submitDuelScore(matchId, score, timeMs: timeMs));

  static Future<void> forfeitDuel(String matchId) =>
      _safeVoid(() => _repo.forfeitDuel(matchId));

  static Future<void> cancelDuel(String matchId) =>
      _safeVoid(() => _repo.cancelDuel(matchId));

  /// Mis duelos abiertos (para que el retado abra el suyo).
  static Future<List<DuelState>> myOpenDuels() =>
      _safe(() => _repo.myOpenDuels(), <DuelState>[]);

  // --- Torneos ---

  static Future<List<TournamentInfo>> tournaments() =>
      _safe(() => _repo.tournaments(), <TournamentInfo>[]);

  static Stream<List<TournamentInfo>> tournamentsStream() =>
      _safeStream(_repo.tournamentsStream());

  static Future<void> joinTournament(String id) =>
      _safeVoid(() => _repo.joinTournament(id));

  static Future<TournamentInfo?> submitTournamentScore(String id, int score,
          {int timeMs = 0}) =>
      _safe(
          () => _repo.submitTournamentScore(id, score, timeMs: timeMs),
          null);

  // --- Tienda: compras guardadas EN LOCAL y sincronizadas ---

  static const _kOwned = 'social_shop_owned';
  static const _kEquippedTheme = 'social_shop_equipped_theme';
  static const _kEquippedAvatar = 'social_shop_equipped_avatar';
  static const _kEquippedBadge = 'social_shop_equipped_badge';
  static const _kEquippedFrame = 'social_shop_equipped_frame';

  static Set<String>? _owned;
  static String? _equippedThemeId;
  static String? _equippedAvatarId;
  static String? _equippedBadgeId;
  static String? _equippedFrameId;
  static var _prefsLoaded = false;

  /// Carga las compras y lo equipado (llamar en main() antes de
  /// arrancar; también se carga perezoso en el primer uso).
  static Future<void> init() async {
    if (_prefsLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _owned = prefs.getStringList(_kOwned)?.toSet() ?? <String>{};
      _equippedThemeId = prefs.getString(_kEquippedTheme);
      _equippedAvatarId = prefs.getString(_kEquippedAvatar);
      _equippedBadgeId = prefs.getString(_kEquippedBadge);
      _equippedFrameId = prefs.getString(_kEquippedFrame);
    } catch (_) {
      _owned ??= <String>{};
    }
    _prefsLoaded = true;
    equippedAvatarIdNotifier.value = _equippedAvatarId;
    equippedFrameIdNotifier.value = _equippedFrameId;
  }

  static Future<Set<String>> ownedItemIds() async {
    await init();
    return Set<String>.of(_owned ?? <String>{});
  }

  static Future<bool> isOwned(String itemId) async {
    final owned = await ownedItemIds();
    return owned.contains(itemId);
  }

  static Future<String?> equippedItemId(String kind) async {
    await init();
    return switch (kind) {
      'theme' => _equippedThemeId,
      'avatar' => _equippedAvatarId,
      'badge' => _equippedBadgeId,
      'frame' => _equippedFrameId,
      _ => null,
    };
  }

  /// Catálogo para las búsquedas síncronas (tema/avatar/marco
  /// equipados): primero el último catálogo remoto cargado (así
  /// un tema o avatar NUEVO, que no está en el respaldo fijo,
  /// también se resuelve), después las recompensas de referidos
  /// (que aún no están en el catálogo remoto) y después
  /// `kShopCatalog`.
  static List<ShopItem> _lookupCatalog() {
    final seen = <String>{};
    final out = <ShopItem>[];
    for (final item in [
      ...RemoteShopCatalog.lastLoaded,
      ...kReferralRewardItems,
      ...kShopCatalog,
    ]) {
      if (seen.add(item.id)) out.add(item);
    }
    return out;
  }

  /// Color del tema equipado de la tienda (síncrono, para
  /// AppAccent): null si no hay tema de tienda equipado.
  static Color? get equippedThemeColor {
    final id = _equippedThemeId;
    if (id == null) return null;
    for (final item in _lookupCatalog()) {
      if (item.id == id && item.color != null) {
        return Color(item.color!);
      }
    }
    return null;
  }

  /// Foto de avatar equipada (su asset), o null sin foto.
  /// Es la foto del usuario: se ve en la cabecera de Cuenta, en
  /// Amigos y en las filas de la tabla en lugar del disco con la
  /// inicial. Cubre los premium del catálogo Y los gratuitos de
  /// la galería (alcance 9).
  static String? get equippedAvatarAsset =>
      avatarAssetForId(_equippedAvatarId);

  /// Id del avatar equipado (síncrono), o null.
  static String? get equippedAvatarId => _equippedAvatarId;

  /// Avatares GRATUITOS de la galería del editor (alcance 9,
  /// Quemia 7.1): no son artículos de la tienda, así que no están
  /// en kShopCatalog (la Tienda no cambia). La foto por defecto es
  /// neutra; Brenda y Britany son las gemelas; Kristian es la cara
  /// masculina. Se equipan con [equipItem] igual que los premium:
  /// mismo campo [equippedAvatar] local y misma sincronización.
  static const Map<String, String> freeAvatarAssets = {
    'avatar_default': 'assets/avatar_default.png',
    'avatar_brenda': 'assets/brenda.png',
    'avatar_britany': 'assets/britany.png',
    'avatar_kristian': 'assets/kristian.png',
  };

  /// Avatar por defecto según el género del onboarding (alcance 9):
  /// Femenino → cara femenina (Brenda), Masculino → cara masculina
  /// (Kristian); sin género elegido → neutro.
  static String defaultAvatarIdForGender(String gender) => switch (gender) {
        'Femenino' => 'avatar_brenda',
        'Masculino' => 'avatar_kristian',
        _ => 'avatar_default',
      };

  /// Foto del avatar que se muestra (alcance 9): la equipada si
  /// hay una, si no la de por defecto según el género. Nunca null:
  /// sin nada equipado cae al neutro.
  static String displayAvatarAssetForGender(String gender) =>
      equippedAvatarAsset ??
      avatarAssetForId(defaultAvatarIdForGender(gender)) ??
      'assets/avatar_default.png';

  /// Id del avatar que se muestra: el equipado si hay uno, si no
  /// el de por defecto según el género.
  static String displayAvatarIdForGender(String gender) =>
      _equippedAvatarId ?? defaultAvatarIdForGender(gender);

  /// Avisa a quien escucha (la cabecera de Cuenta) cuando cambia
  /// el avatar equipado: el editor lo toca al elegir, y Cuenta
  /// repinta el círculo sin falta de volver a entrar. El valor es
  /// el id equipado (null = ninguno, se usa el de por defecto).
  static final ValueNotifier<String?> equippedAvatarIdNotifier =
      ValueNotifier<String?>(null);

  /// Asset de la foto de un avatar por su id, o null si el id no
  /// es un avatar. Busca en el catálogo de la tienda (premium, el
  /// remoto primero) y en los gratuitos de la galería. Los
  /// avatares remotos con `imageUrl` no tienen asset: su foto se
  /// resuelve con [equippedAvatarImageUrl] + ShopImageCache.
  static String? avatarAssetForId(String? id) {
    if (id == null) return null;
    final free = freeAvatarAssets[id];
    if (free != null) return free;
    for (final item in _lookupCatalog()) {
      if (item.id == id) return item.asset;
    }
    return null;
  }

  /// URL remota de la foto del avatar equipado, o null si el
  /// avatar equipado es de asset (o no hay ninguno). La foto se
  /// muestra desde la caché en disco (ShopImageCache).
  static String? get equippedAvatarImageUrl {
    final id = _equippedAvatarId;
    if (id == null) return null;
    for (final item in _lookupCatalog()) {
      if (item.id == id) return item.imageUrl;
    }
    return null;
  }

  /// Id del marco equipado (síncrono), o null.
  static String? get equippedFrameId => _equippedFrameId;

  /// El marco equipado (su artículo del catálogo), o null sin
  /// marco. Se dibuja como anillo alrededor de la foto del avatar
  /// del usuario (Cuenta y vista previa de la tienda).
  static ShopItem? get equippedFrameItem {
    final id = _equippedFrameId;
    if (id == null) return null;
    for (final item in _lookupCatalog()) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Avisa a quien escucha (la cabecera de Cuenta) cuando cambia
  /// el marco equipado: el círculo repinta el anillo al instante.
  static final ValueNotifier<String?> equippedFrameIdNotifier =
      ValueNotifier<String?>(null);

  /// Insignia equipada ('badge_star' | 'badge_trophy' | 'badge_flame').
  static String? get equippedBadgeId => _equippedBadgeId;

  /// Compra [item]: descuenta los puntos, guarda en local y
  /// sincroniza cuando hay backend. false si no alcanzan los puntos.
  static Future<bool> buyItem(ShopItem item) async {
    await init();
    if ((_owned ?? <String>{}).contains(item.id)) return true;
    if (ProgressService.instance.points < item.price) return false;
    ProgressService.instance.addPoints(-item.price);
    _owned = {...?_owned, item.id};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kOwned, _owned!.toList());
    } catch (_) {}
    try {
      await _repo.syncPurchase(item.id);
    } catch (_) {}
    return true;
  }

  /// Regala un artículo (recompensa de referidos, 7.3): lo añade
  /// a la lista local de compras y lo sincroniza, SIN descontar
  /// puntos. No es una compra: el precio no se mira (las
  /// recompensas llevan price 0 y referralOnly). Si ya lo tiene,
  /// no hace nada.
  static Future<void> grantItem(ShopItem item) async {
    await init();
    if ((_owned ?? <String>{}).contains(item.id)) return;
    _owned = {...?_owned, item.id};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kOwned, _owned!.toList());
    } catch (_) {}
    try {
      await _repo.syncPurchase(item.id);
    } catch (_) {}
  }

  /// Equipa un artículo ya comprado. Los temas cambian el acento
  /// de la app (AppAccent lo lee de aquí, no de UserPrefs, porque
  /// UserPrefs solo guarda 'verde'/'violeta'). El campo en memoria
  /// se pone ANTES de cualquier await, para que el acento cambie
  /// en el mismo fotograma que el aviso de reconstrucción
  /// (themeAccentNotifier).
  static Future<void> equipItem(ShopItem item) async {
    switch (item.kind) {
      case 'theme':
        _equippedThemeId = item.id;
      case 'avatar':
        _equippedAvatarId = item.id;
      case 'badge':
        _equippedBadgeId = item.id;
      case 'frame':
        _equippedFrameId = item.id;
    }
    await init();
    // Si init() acababa de cargar las preferencias (primera
    // llamada), habría pisado lo equipado con el valor guardado:
    // se vuelve a poner el avatar elegido y se avisa a la
    // cabecera de Cuenta para que repinte el círculo al instante.
    if (item.kind == 'avatar') {
      _equippedAvatarId = item.id;
      equippedAvatarIdNotifier.value = item.id;
    }
    if (item.kind == 'frame') {
      _equippedFrameId = item.id;
      equippedFrameIdNotifier.value = item.id;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      switch (item.kind) {
        case 'theme':
          await prefs.setString(_kEquippedTheme, item.id);
        case 'avatar':
          await prefs.setString(_kEquippedAvatar, item.id);
        case 'badge':
          await prefs.setString(_kEquippedBadge, item.id);
        case 'frame':
          await prefs.setString(_kEquippedFrame, item.id);
      }
    } catch (_) {}
    // Lo equipado también se sincroniza (no solo la propiedad):
    // así el avatar/insignia/tema/marco sobrevive a un cambio de
    // teléfono y los amigos ven lo que llevas puesto.
    await _safeVoid(() => _repo.syncEquipped(item.kind, item.id));
  }

  /// Id del tema de tienda equipado (síncrono), o null.
  static String? get equippedThemeId => _equippedThemeId;

  /// Quita el tema de tienda equipado (al elegir Verde/Violeta en
  /// la pantalla de Tema).
  static Future<void> clearEquippedTheme() async {
    _equippedThemeId = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kEquippedTheme);
    } catch (_) {}
    await _safeVoid(() => _repo.syncEquipped('theme', null));
  }

  /// Nombre del tema de tienda equipado, o null.
  static String? get equippedThemeName {
    final id = _equippedThemeId;
    if (id == null) return null;
    for (final item in _lookupCatalog()) {
      if (item.id == id) return item.name;
    }
    return null;
  }

  /// El catálogo de la tienda: REMOTO (Firestore 'shop_items',
  /// con caché local y respaldo offline). Mantiene la firma de
  /// siempre; la UI no cambia.
  static Future<List<ShopItem>> shopItems() =>
      _safe(() => RemoteShopCatalog.instance.loadCatalog(), <ShopItem>[]);

  /// Fuerza la relectura remota del catálogo (tras publicar un
  /// artículo nuevo en Firestore).
  static Future<List<ShopItem>> refreshShopItems() => _safe(
      () => RemoteShopCatalog.instance.refreshCatalog(), <ShopItem>[]);

  // --- Grupos ---

  static Future<List<StudyGroup>> groups() =>
      _safe(() => _repo.groups(), <StudyGroup>[]);

  static Future<StudyGroup?> createGroup(String name) =>
      _safe(() => _repo.createGroup(name), null);

  static Future<StudyGroup?> joinGroup(String code) =>
      _safe(() => _repo.joinGroup(code), null);

  static Future<void> leaveGroup(String id) =>
      _safeVoid(() => _repo.leaveGroup(id));

  // --- Reportes ---

  /// Reporta una pregunta. Nunca falla hacia la UI: sin internet
  /// se guarda el intento en local (el falso lo registra igual) y
  /// la pantalla muestra solo "Gracias por avisar".
  static Future<void> reportQuestion(String questionId, String reason) =>
      _safeVoid(() => _repo.reportQuestion(questionId, reason));
}

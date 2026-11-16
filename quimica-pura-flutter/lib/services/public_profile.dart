// Perfil público de un usuario (lote seguir, 2026-11-16): datos
// 100 % reales, nada inventado. La UI lo importa desde
// social_service.dart (que reexporta este archivo).
//
// Fuentes reales:
//   - 'users/<uid>': username, joinedAt, levelsPassed (MAPA
//     {bach, uni} en usuarios reales, INT en los 50 bots),
//     levels (mapa por pista y tema), trophies (mapa por pista),
//     practiceDays (lista yyyy-MM-dd), points, streak, track,
//     dailyPoints (mapa yyyy-MM-dd -> puntos, solo desde que se
//     empezó a registrar: los días pasados sin registro quedan
//     vacíos), correctTotal, mixedBest, equippedAvatar, isBot.
//   - 'follows': contadores y si el seguimiento es mutuo.
//   - joinedAt/lastSeenMs son INT en ms en la mayoría de los
//     documentos, pero se tolera Timestamp o ausencia.
//
// Logros derivables de datos guardados: firstLevel (niveles > 0),
// topicDone (algún tema con todos sus niveles pasados),
// streak3/7/30 (mejor racha desde practiceDays), mixedPass
// (mixedBest >= 80), correct100/500/1000 (correctTotal).
// reviewClear NO es derivable (la lista de errores es solo local
// por diseño): NUNCA aparece en achievementsWon.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/topics.dart';
import 'progress.dart';

/// Contenido del QR del perfil: lo que la UI codifica en el QR.
/// 'quemia:user:<username>' (sin uid: el nombre es lo que se busca).
String profileQrData(String username) => 'quemia:user:$username';

int _asInt(Object? v) => (v as num?)?.toInt() ?? 0;

/// Milisegundos desde epoch: INT en ms, Timestamp, o 0 si no hay.
int _asMs(Object? v) {
  if (v is num) return v.toInt();
  if (v is Timestamp) return v.millisecondsSinceEpoch;
  return 0;
}

/// Total de niveles pasados: MAPA {bach, uni} (usuarios reales) o
/// INT (los 50 bots). Cualquier otro valor = 0.
int levelsPassedTotalOf(Object? raw) {
  if (raw is Map) {
    var total = 0;
    raw.forEach((_, v) {
      if (v is num) total += v.toInt();
    });
    return total;
  }
  if (raw is num) return raw.toInt();
  return 0;
}

/// Trofeos ganados: 'trophies' es un mapa por pista con la lista de
/// temas con trofeo ({'uni': ['estequiometria', ...]}).
int trophiesWonOf(Object? raw) {
  if (raw is! Map) return 0;
  var won = 0;
  raw.forEach((_, v) {
    if (v is List) won += v.length;
  });
  return won;
}

/// Días de práctica ('yyyy-MM-dd') desde cualquier valor guardado.
Set<String> practiceDaysOf(Object? raw) {
  final out = <String>{};
  if (raw is List) {
    for (final d in raw) {
      if (d is String && d.isNotEmpty) out.add(d);
    }
  }
  return out;
}

/// Mapa yyyy-MM-dd -> puntos desde cualquier valor guardado.
Map<String, int> dailyPointsOf(Object? raw) {
  final out = <String, int>{};
  if (raw is Map) {
    raw.forEach((k, v) {
      if (v is num) out[k.toString()] = v.toInt();
    });
  }
  return out;
}

/// Logros derivables de datos guardados (ver cabecera). reviewClear
/// no es derivable y nunca se incluye.
List<String> deriveAchievements({
  required int levelsPassedTotal,
  required bool anyTopicComplete,
  required Set<String> practiceDays,
  int? mixedBest,
  int? correctTotal,
}) {
  final out = <String>[];
  if (levelsPassedTotal > 0) out.add('firstLevel');
  if (anyTopicComplete) out.add('topicDone');
  final best = ProgressService.bestStreak(practiceDays);
  if (best >= 3) out.add('streak3');
  if (best >= 7) out.add('streak7');
  if (best >= 30) out.add('streak30');
  if (mixedBest != null && mixedBest >= 80) out.add('mixedPass');
  if (correctTotal != null && correctTotal >= 100) out.add('correct100');
  if (correctTotal != null && correctTotal >= 500) out.add('correct500');
  if (correctTotal != null && correctTotal >= 1000) out.add('correct1000');
  return out;
}

/// Perfil público de un usuario: solo lo que realmente guardó.
class PublicProfile {
  const PublicProfile({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.joinedAtMs,
    required this.levelsPassedTotal,
    required this.points,
    required this.streak,
    required this.trophiesWon,
    required this.trophiesTotal,
    required this.achievementsWon,
    required this.dailyPoints,
    required this.followingCount,
    required this.followersCount,
    required this.isFollowing,
    required this.isFollowedBy,
    required this.isMutual,
    required this.avatarId,
    required this.isBot,
  });

  /// Uid de Firebase Auth (id del documento en 'users').
  final String uid;

  /// Nombre público único ('' si no tiene).
  final String username;

  /// Nombre real si lo hay, si no el username, si no 'Quemia'.
  final String displayName;

  /// Cuándo se creó la cuenta (ms desde epoch, 0 si no hay).
  final int joinedAtMs;

  final int levelsPassedTotal;
  final int points;

  /// Racha actual guardada (días seguidos con práctica).
  final int streak;

  /// Trofeos de exámenes por tema: ganados y temas de su pista.
  final int trophiesWon;
  final int trophiesTotal;

  /// Ids de achievements.dart REALMENTE ganados (derivados de sus
  /// datos guardados). Nunca incluye 'reviewClear' (no derivable).
  final List<String> achievementsWon;

  /// Puntos por día ('yyyy-MM-dd' -> puntos) de los últimos 7 días.
  /// Vacío si no hay historial (la UI pone una nota honesta).
  final Map<String, int> dailyPoints;

  final int followingCount;
  final int followersCount;

  /// Yo lo sigo / él me sigue (respecto a quien mira el perfil).
  final bool isFollowing;
  final bool isFollowedBy;

  /// Seguimiento mutuo (los dos se siguen).
  final bool isMutual;

  /// Avatar equipado ('avatar_...'), o null.
  final String? avatarId;

  /// true si es un BOT (usuario simulado).
  final bool isBot;

  /// Construye el perfil desde un documento de 'users' (o null si
  /// no existe). [viewerUid] es quien mira el perfil: los campos
  /// isFollowing/isFollowedBy/isMutual se refieren a él. Los
  /// contadores y los booleanos de seguimiento los calcula quien
  /// llama (colección 'follows'); aquí solo se derivan los datos
  /// del documento. Tolera niveles como mapa o entero, fechas como
  /// int o Timestamp, y campos ausentes.
  static PublicProfile? fromUserDoc(
    Map<String, dynamic>? raw, {
    required String viewerUid,
    int followingCount = 0,
    int followersCount = 0,
    bool isFollowing = false,
    bool isFollowedBy = false,
  }) {
    if (raw == null) return null;
    final uid = raw['id']?.toString() ?? raw['deviceId']?.toString() ?? '';
    if (uid.isEmpty) return null;
    final username = raw['username']?.toString() ?? '';
    final displayName = raw['displayName']?.toString().isNotEmpty == true
        ? raw['displayName'].toString()
        : (username.isNotEmpty ? username : 'Quemia');
    final levelsTotal = levelsPassedTotalOf(raw['levelsPassed']);
    final practiceDays = practiceDaysOf(raw['practiceDays']);
    final track = raw['track']?.toString();
    final trackTopics =
        track == ProgressService.trackBach ? bachTopics : uniTopics;
    // ¿Algún tema completo? 'levels' es {pista: {tema: nivel
    // desbloqueado}}; un tema está completo cuando el nivel
    // desbloqueado supera su número de niveles (igual que
    // ProgressService.isTopicComplete).
    var anyTopicComplete = false;
    final levelsRaw = raw['levels'];
    if (levelsRaw is Map) {
      levelsRaw.forEach((_, topics) {
        if (topics is Map) {
          topics.forEach((topic, level) {
            if (level is num &&
                level.toInt() >
                    ProgressService.levelCountForTopic(topic.toString())) {
              anyTopicComplete = true;
            }
          });
        }
      });
    }
    final correctTotal = raw['correctTotal'] is num
        ? (raw['correctTotal'] as num).toInt()
        : null;
    final mixedBest =
        raw['mixedBest'] is num ? (raw['mixedBest'] as num).toInt() : null;
    // Semana: solo los últimos 7 días (las claves son yyyy-MM-dd,
    // así que el orden alfabético es el cronológico).
    final today = ProgressService.dateKey(DateTime.now());
    final weekAgo = ProgressService.dateKey(
        DateTime.now().subtract(const Duration(days: 6)));
    final week = <String, int>{};
    dailyPointsOf(raw['dailyPoints']).forEach((day, pts) {
      if (day.compareTo(weekAgo) >= 0 && day.compareTo(today) <= 0) {
        week[day] = pts;
      }
    });
    final avatarRaw = raw['equippedAvatar']?.toString();
    return PublicProfile(
      uid: uid,
      username: username,
      displayName: displayName,
      joinedAtMs: _asMs(raw['joinedAt']),
      levelsPassedTotal: levelsTotal,
      points: _asInt(raw['points']),
      streak: _asInt(raw['streak']),
      trophiesWon: trophiesWonOf(raw['trophies']),
      trophiesTotal: trackTopics.length,
      achievementsWon: deriveAchievements(
        levelsPassedTotal: levelsTotal,
        anyTopicComplete: anyTopicComplete,
        practiceDays: practiceDays,
        mixedBest: mixedBest,
        correctTotal: correctTotal,
      ),
      dailyPoints: week,
      followingCount: followingCount,
      followersCount: followersCount,
      isFollowing: isFollowing,
      isFollowedBy: isFollowedBy,
      isMutual: isFollowing && isFollowedBy,
      avatarId: avatarRaw == null || avatarRaw.isEmpty ? null : avatarRaw,
      isBot: raw['isBot'] == true,
    );
  }
}

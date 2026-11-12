// Usuarios falsos realistas para tests y previews de la 7.0.
// Los mismos 12 nombres que usa B (kDemoSocialUsers en
// lib/services/social_service.dart), con las MISMAS cifras de
// puntos, niveles pasados y racha, para que tests y previews
// hablen de los mismos usuarios.
//
//   kristian (el usuario), laura, miguel, sofia, daniel, valeria,
//   pedro, camila, yordanis, lucia, andres, rosa.
//
// Niveles pasados se reparten entre bach/uni y por tema (nivel
// desbloqueado = pasados + 1). Los días de práctica son los
// últimos `streak` días (relativos a `now`, por defecto hoy).
// Todos comparten (shared: true) SALVO pedro (privado: para
// probar que no sale en la tabla ni en la lista de amigos).
// Ninguno está baneado (los tests ponen 'banned' donde toca).
import 'package:quimica_pura/services/analytics_sync.dart';

/// Una fila: username, uid, points, niveles pasados (bach/uni),
/// racha, pista actual y si comparte.
class _FakeUserSpec {
  const _FakeUserSpec(
    this.username,
    this.points,
    this.bachPassed,
    this.uniPassed,
    this.streak,
    this.track, {
    this.shared = true,
  });

  final String username;
  final int points;
  final int bachPassed;
  final int uniPassed;
  final int streak;
  final String track;
  final bool shared;
}

const List<_FakeUserSpec> _specs = [
  _FakeUserSpec('kristian', 1240, 10, 14, 12, 'uni'),
  _FakeUserSpec('laura', 1420, 11, 17, 15, 'uni'),
  _FakeUserSpec('miguel', 980, 8, 11, 8, 'bach'),
  _FakeUserSpec('sofia', 1580, 12, 19, 21, 'uni'),
  _FakeUserSpec('daniel', 760, 6, 9, 5, 'bach'),
  _FakeUserSpec('valeria', 1310, 10, 16, 11, 'uni'),
  _FakeUserSpec('pedro', 540, 4, 7, 4, 'bach', shared: false),
  _FakeUserSpec('camila', 1150, 9, 13, 9, 'uni'),
  _FakeUserSpec('yordanis', 890, 7, 10, 6, 'bach'),
  _FakeUserSpec('lucia', 1470, 12, 17, 18, 'uni'),
  _FakeUserSpec('andres', 670, 5, 8, 3, 'bach'),
  _FakeUserSpec('rosa', 1020, 8, 12, 7, 'uni'),
];

const List<String> _bachTopics = [
  'bach-estequiometria',
  'bach-gases',
  'bach-disoluciones',
  'bach-acido-base',
];

const List<String> _uniTopics = [
  'estequiometria',
  'gases',
  'disoluciones',
  'acido-base',
  'equilibrio',
  'termo-cinetica',
  'tabla',
  'enlace',
];

class FakeUsers {
  FakeUsers._();

  /// Los 12 nombres, en orden.
  static List<String> get usernames =>
      _specs.map((s) => s.username).toList();

  /// Los 12 documentos (cada uno con 'deviceId' = uid).
  /// `now` fija los días de práctica (por defecto, hoy).
  static List<Map<String, dynamic>> build({DateTime? now}) {
    final anchor = now ?? DateTime.now();
    final out = <Map<String, dynamic>>[];
    for (final s in _specs) {
      final days = <String>[];
      for (var i = 0; i < s.streak; i++) {
        final d = anchor.subtract(Duration(days: i));
        days.add(
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
      }
      final levels = <String, Map<String, int>>{
        'bach': _distribute(s.bachPassed, _bachTopics),
        'uni': _distribute(s.uniPassed, _uniTopics),
      };
      out.add(<String, dynamic>{
        'deviceId': 'fake-${s.username}',
        'username': s.username,
        'points': s.points,
        'levelsPassed': {'bach': s.bachPassed, 'uni': s.uniPassed},
        'levels': levels,
        'practiceDays': days,
        'streak': s.streak,
        'track': s.track,
        'shared': s.shared,
        'banned': false,
        'joinedAt': anchor
            .subtract(const Duration(days: 60))
            .millisecondsSinceEpoch,
        'lastActive': anchor.millisecondsSinceEpoch,
        'appVersion': '7.0',
      });
    }
    return out;
  }

  /// Siembra los 12 en el repositorio falso (clave = uid).
  static void seed(InMemoryAnalyticsRepository repo, {DateTime? now}) {
    for (final doc in build(now: now)) {
      repo.users[doc['deviceId'] as String] =
          Map<String, dynamic>.from(doc);
    }
  }

  /// Un usuario por nombre (null si no existe).
  static Map<String, dynamic>? byUsername(String username,
      {DateTime? now}) {
    for (final doc in build(now: now)) {
      if (doc['username'] == username) return doc;
    }
    return null;
  }

  /// Reparte `total` niveles pasados entre los temas: nivel
  /// desbloqueado = pasados + 1 (un tema sin jugar queda en 1).
  static Map<String, int> _distribute(int total, List<String> topics) {
    final out = <String, int>{};
    var remaining = total;
    var i = 0;
    while (remaining > 0) {
      final topic = topics[i % topics.length];
      out[topic] = (out[topic] ?? 1) + 1;
      remaining--;
      i++;
    }
    return out;
  }
}

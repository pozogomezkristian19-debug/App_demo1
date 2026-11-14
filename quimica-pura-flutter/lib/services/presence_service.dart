// Presencia online (7.7): quién está en línea AHORA para los duelos.
//
// Cada usuario con Google vinculada escribe `lastSeenMs` (ms desde
// epoch) en su doc de 'users' con un latido cada 30 s mientras la app
// está abierta (y una vez al abrir). "En línea" = latido dentro de
// los últimos 90 s ([onlineThreshold]).
//
// Para qué sirve: el duelo al azar solo hace match con alguien que
// está en línea Y buscando (cola duel_queue), y retar a alguien exige
// que esa persona esté en línea. Sin esto, el azar elegía a cualquiera
// con shared==true aunque llevara días sin abrir la app.
//
// Los BOTS (isBot == true) no usan presencia: nunca laten y nunca
// entran en la cola; un bot siempre está disponible porque su jugada
// la pone un proceso del servidor (ver DuelService).
import 'dart:async';

import 'analytics_sync.dart';
import 'auth_service.dart';
import 'online_common.dart';

class PresenceService {
  PresenceService._();

  /// Cada cuánto late la app (30 s).
  static const Duration heartbeatInterval = Duration(seconds: 30);

  /// "En línea" = latido dentro de los últimos 90 s (3 latidos de
  /// margen: con la red lenta de Cuba un latido puede tardar).
  static const Duration onlineThreshold = Duration(seconds: 90);

  static Timer? _timer;

  /// ¿Está en línea alguien con este último latido? null o viejo =
  /// no. [nowMs] solo para tests.
  static bool isOnline(int? lastSeenMs, {int? nowMs}) {
    if (lastSeenMs == null) return false;
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    if (lastSeenMs <= 0) return false;
    return now - lastSeenMs <= onlineThreshold.inMilliseconds;
  }

  /// Un latido: escribe lastSeenMs en mi doc. Silencio total ante
  /// fallos (Regla 2). Sin Google vinculada no se escribe nada (la
  /// puerta de identidad: solo con Google se juega online).
  static Future<void> heartbeat() async {
    if (!OnlineCommon.allowed) return;
    final me = AuthService.currentUid;
    if (me == null || me.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await OnlineCommon.write(() => AnalyticsSync.repository.setDoc(
          'users',
          me,
          <String, dynamic>{'lastSeenMs': now},
        ));
  }

  /// Arranca el latido (main() al abrir la app): un latido inmediato
  /// y luego uno cada 30 s. Idempotente: llamarlo dos veces no crea
  /// dos temporizadores.
  static void start() {
    if (_timer != null) return;
    unawaited(heartbeat());
    _timer = Timer.periodic(heartbeatInterval, (_) => heartbeat());
  }

  /// Para el latido (tests).
  static void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

// Prueba GRATIS de 3 días de la app completa (web Y móvil,
// Kristian 2026-11-15): invitado O registrado, 3 días con la app
// COMPLETA (sin candados en Aprender/Resolver/Mis errores). Los
// corazones NO son ilimitados en la prueba: siguen siendo 10 al
// día, como gratis, y solo el Premium PAGADO tiene ∞ (Kristian
// 2026-11-16).
//
// Funciona SIN INTERNET: el inicio de la prueba se guarda en
// local (SharedPreferences, en web localStorage) y la caducidad
// se comprueba en local, sin pedir nada a la red. La prueba
// EMPIEZA SOLA la primera vez que se abre la app con este código
// (si no hay inicio guardado, se guarda ahora). A los 3 días se
// ACABA SOLA, aunque no haya internet, y la app vuelve a
// bloquearse a Premium (vuelven los candados y los 10 corazones).
//
// Si el usuario tiene sesión y hay internet, el inicio se guarda
// también en su documento de usuario (campo `trialStartedAt`,
// milisegundos; en `userWritableFields()` de firestore.rules para
// que el cliente pueda escribirlo). Al cargar, vale el inicio MÁS
// ANTIGUO entre local y nube, para que la prueba no se reinicie
// al reinstalar. La escritura en la nube solo se hace DESPUÉS de
// haber leído el documento del usuario (para no pisar un inicio
// anterior que aún no ha llegado).
//
// Y para el INVITADO (sin sesión, sin documento de usuario): el
// inicio se guarda también por TELÉFONO, en la colección
// `device_trials` con el id estable del aparato (ANDROID_ID en
// Android, identifierForVendor en iOS: sobrevive a borrar la
// caché y a desinstalar y volver a instalar). Las reglas solo
// dejan CREAR ese documento una vez: nadie puede reescribirlo ni
// borrarlo, así que reinstalar NO da otra prueba. Vale el inicio
// MÁS ANTIGUO entre local, nube y teléfono. En web no hay id
// estable: el registro por teléfono se salta y la prueba queda
// como antes (la web es solo para probar).
//
// El acceso efectivo (Premium pagado O prueba) lo calcula
// PremiumService: su temporizador de 1 s re-evalúa el vencimiento
// y su notifier `premiumNotifier` ya es el acceso efectivo, así
// que los candados funcionan solos con la prueba. El ∞ va por
// otro notifier, `paidPremiumNotifier` (solo Premium pagado).
// Este servicio solo guarda el inicio y avisa si la prueba está
// activa y cuántos días quedan.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_sync.dart';
import 'auth_service.dart';
import 'device_id.dart';

/// Duración de la prueba, en días (Kristian 2026-11-15: 3 días,
/// antes 2 en el primer resumen).
const int trialDurationDays = 3;

/// Clave local del inicio de la prueba (milisegundos desde epoch).
const String trialPrefsKey = 'quemia_trial_start_ms';

/// Campo del documento users/{uid} con el inicio de la prueba
/// (milisegundos desde epoch).
const String trialCloudField = 'trialStartedAt';

/// Colección con el inicio de la prueba POR TELÉFONO
/// (device_trials/{id estable del aparato}).
const String deviceTrialsCollection = 'device_trials';

/// Campo del documento device_trials/{id} con el inicio de la
/// prueba (milisegundos desde epoch).
const String deviceTrialStartField = 'trialStartedAt';

/// Campo del documento device_trials/{id} con la creación del
/// registro (milisegundos desde epoch, solo informativo).
const String deviceTrialCreatedField = 'createdAt';

/// Fin de la prueba que empieza en [start]. null sin inicio.
DateTime? trialEndsAt(DateTime? start) =>
    start?.add(const Duration(days: trialDurationDays));

/// ¿Está activa la prueba que empieza en [start]? [now]
/// inyectable para tests. null o vencida = inactiva.
bool trialActive(DateTime? start, {DateTime? now}) {
  if (start == null) return false;
  return (now ?? DateTime.now()).isBefore(trialEndsAt(start)!);
}

/// Días que quedan de la prueba que empieza en [start]:
/// redondeo hacia ARRIBA (2 días y 23 horas → 3 días; media hora
/// → 1 día). 0 si no hay prueba o ya venció. [now] inyectable
/// para tests.
int trialDaysLeft(DateTime? start, {DateTime? now}) {
  if (start == null) return 0;
  final at = now ?? DateTime.now();
  final end = trialEndsAt(start)!;
  if (!at.isBefore(end)) return 0;
  final left = end.difference(at);
  return (left.inSeconds / 86400).ceil().clamp(1, trialDurationDays);
}

/// El inicio más antiguo entre local y nube (o null si no hay
/// ninguno): el que manda para que la prueba no se reinicie.
DateTime? trialEarliestStart(DateTime? local, DateTime? cloud) {
  if (local == null) return cloud;
  if (cloud == null) return local;
  return local.isBefore(cloud) ? local : cloud;
}

/// El inicio más antiguo entre local, nube y teléfono (o null si
/// no hay ninguno): el que manda para que la prueba no se
/// reinicie ni borrando la caché ni reinstalando.
DateTime? trialEarliestStart3(
    DateTime? local, DateTime? cloud, DateTime? device) {
  DateTime? earliest;
  for (final start in [local, cloud, device]) {
    if (start == null) continue;
    if (earliest == null || start.isBefore(earliest)) earliest = start;
  }
  return earliest;
}

/// ¿Toca enseñar la pantalla "Se acabó tu prueba"? Solo cuando la
/// prueba EXISTIÓ y ya terminó, sin Premium pagado y sin haberla
/// enseñado ya: un usuario nuevo (prueba recién empezada) no la
/// ve, y uno que ya la vio no la vuelve a ver en cada apertura.
/// Pura, para tests: la pantalla la decide la HomeScreen con
/// estos cuatro datos.
bool shouldShowTrialEnded({
  required bool hadTrial,
  required bool trialActiveNow,
  required bool hasPaidPremium,
  required bool alreadyShown,
}) =>
    hadTrial && !trialActiveNow && !hasPaidPremium && !alreadyShown;

class TrialService {
  TrialService._();

  static final TrialService instance = TrialService._();

  /// ¿Está activa la prueba ahora? Lo escuchan el banner de
  /// Niveles y Cuenta y el paywall.
  static final ValueNotifier<bool> trialNotifier =
      ValueNotifier<bool>(false);

  /// Días que quedan de la prueba (0 sin prueba). Lo escucha el
  /// banner para pintar el número.
  static final ValueNotifier<int> trialDaysLeftNotifier =
      ValueNotifier<int>(0);

  /// Atajo de lectura: ¿prueba activa ahora mismo? Se calcula
  /// del inicio guardado + la hora actual (no del notifier, para
  /// que el acceso se corte en el segundo exacto del vencimiento
  /// aunque el banner se repinte cada 30 s).
  static bool get isTrialActiveNow => instance._isActiveNow();

  bool _isActiveNow() => trialActive(effectiveStart);

  /// Días que quedan ahora mismo (0 sin prueba).
  static int get daysLeftNow => trialDaysLeftNotifier.value;

  DateTime? _localStart;
  DateTime? _cloudStart;

  /// Inicio de la prueba según el TELÉFONO (colección
  /// `device_trials`): el que impide reiniciar la prueba
  /// reinstalando. null = aún no se leyó (o no hay id estable).
  DateTime? _deviceStart;

  /// True cuando el registro del teléfono ya se leyó o se creó al
  /// menos una vez (así no se reintenta en cada apertura).
  bool _deviceKnown = false;

  /// True cuando el documento del usuario ya se leyó al menos una
  /// vez (así la escritura en la nube nunca pisa un inicio
  /// anterior que aún no ha llegado).
  bool _cloudKnown = false;
  bool _started = false;
  Timer? _timer;

  /// Arranca la prueba. Si no
  /// hay inicio guardado en local, se guarda AHORA (la prueba
  /// empieza sola al primer arranque con este código). No espera
  /// a la red ni lanza nada: sin internet, el inicio local basta.
  /// [prefsOverride] solo existe para tests.
  Future<void> start({SharedPreferences? prefsOverride}) async {
    if (_started) return;
    _started = true;
    try {
      final prefs = prefsOverride ?? await SharedPreferences.getInstance();
      final stored = prefs.getInt(trialPrefsKey);
      if (stored != null) {
        _localStart =
            DateTime.fromMillisecondsSinceEpoch(stored, isUtc: true);
      } else {
        final now = DateTime.now().toUtc();
        _localStart = now;
        await prefs.setInt(trialPrefsKey, now.millisecondsSinceEpoch);
      }
    } catch (_) {
      // Sin almacenamiento local: sin prueba, como antes.
      _localStart = null;
    }
    _recompute();
    // Re-evaluar cada 30 s: al llegar el vencimiento, la prueba
    // se acaba sola aunque la app lleve horas abierta (el
    // temporizador de 1 s de PremiumService quita el acceso
    // efectivo en el mismo momento).
    _timer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      _recompute();
    });
    unawaited(_syncToCloud());
    // Registro por teléfono (invitado incluido): si este aparato
    // ya tuvo una prueba, su inicio manda aunque se haya borrado
    // la caché o reinstalado. Sin esperar: el inicio local ya
    // está y la pantalla no se bloquea por la red.
    unawaited(syncDeviceTrial());
  }

  /// ¿El usuario TUVO prueba alguna vez (empezada, activa o
  /// vencida)? Es lo que distingue "se acabó tu prueba" de "aún
  /// no tienes prueba": sin inicio no hay nada que se haya
  /// acabado.
  bool get hadTrial => effectiveStart != null;

  /// El inicio de la prueba según el documento users/{uid} (lo
  /// llama PremiumService al leer el documento). [value] acepta
  /// milisegundos (int), Timestamp, DateTime o ISO. null = el
  /// documento no trae inicio (o no existe): queda marcado como
  /// conocido para poder escribir el inicio local en la nube.
  void applyCloudStart(Object? value) {
    _cloudKnown = true;
    _cloudStart = _parseStart(value);
    _recompute();
    // Si la nube no trae inicio, el local se sube ahora (si hay
    // sesión e internet): es el momento seguro, porque el
    // documento ya se leyó y no hay un inicio anterior que pisar.
    if (_cloudStart == null) unawaited(_syncToCloud());
  }

  /// Inicio efectivo: el más antiguo entre local, nube y
  /// teléfono.
  DateTime? get effectiveStart =>
      trialEarliestStart3(_localStart, _cloudStart, _deviceStart);

  void _recompute() {
    final start = effectiveStart;
    final active = trialActive(start);
    final days = trialDaysLeft(start);
    if (trialNotifier.value != active) trialNotifier.value = active;
    if (trialDaysLeftNotifier.value != days) {
      trialDaysLeftNotifier.value = days;
    }
  }

  /// Sube el inicio local al documento del usuario (solo con
  /// sesión y solo si la nube no trae inicio: nunca pisa un
  /// inicio anterior). Falla en silencio sin red.
  Future<void> _syncToCloud() async {
    if (!_cloudKnown) return;
    if (_cloudStart != null) return;
    final start = _localStart;
    final uid = AuthService.currentUid;
    if (start == null || uid == null || uid.isEmpty) return;
    if (!AuthService.isGoogleLinked && !AuthService.isEmailLinked) return;
    try {
      await AnalyticsSync.repository
          .setDoc('users', uid, <String, dynamic>{
        trialCloudField: start.millisecondsSinceEpoch,
      }).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Sin red: el inicio local sigue mandando.
    }
  }

  /// Lee o crea el registro de la prueba POR TELÉFONO (colección
  /// `device_trials`, doc = id estable del aparato). Si el teléfono
  /// ya tuvo una prueba, su inicio pasa a mandar (aunque el local
  /// sea más nuevo: borrar la caché o reinstalar NO da otra
  /// prueba). Si no la tuvo, se crea con el inicio efectivo (o
  /// ahora). Sin id estable (web) o sin red, no hace nada: el
  /// inicio local sigue mandando y se reintenta en la próxima
  /// apertura. Falla en silencio siempre.
  Future<void> syncDeviceTrial() async {
    if (_deviceKnown) return;
    final deviceId = await DeviceId.stableId();
    if (deviceId == null || deviceId.isEmpty) return;
    try {
      final doc = await AnalyticsSync.repository
          .getDoc(deviceTrialsCollection, deviceId)
          .timeout(const Duration(seconds: 5));
      if (doc != null) {
        _deviceStart = _parseStart(doc[deviceTrialStartField]);
        _deviceKnown = true;
        _recompute();
        return;
      }
      final start = effectiveStart ?? DateTime.now().toUtc();
      await AnalyticsSync.repository.setDoc(
        deviceTrialsCollection,
        deviceId,
        <String, dynamic>{
          deviceTrialStartField: start.millisecondsSinceEpoch,
          deviceTrialCreatedField:
              DateTime.now().toUtc().millisecondsSinceEpoch,
        },
      ).timeout(const Duration(seconds: 5));
      _deviceStart = start;
      _deviceKnown = true;
      _recompute();
    } catch (_) {
      // Sin red, o el documento ya existe (otro arranque lo creó
      // antes: las reglas no dejan reescribirlo): se reintenta en
      // la próxima apertura; mientras tanto manda el local.
    }
  }

  /// Parsea el inicio en cualquiera de sus formas (ms, Timestamp,
  /// DateTime, ISO). null si no se entiende.
  static DateTime? _parseStart(Object? v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate().toUtc();
    if (v is DateTime) return v.toUtc();
    if (v is num) {
      return DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
    }
    if (v is String) return DateTime.tryParse(v)?.toUtc();
    return null;
  }

  /// Para la escucha (al cerrar, en tests). No borra el inicio.
  void stop() {
    _started = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Solo para tests: limpia estado, notifiers y temporizador.
  /// Sin anotación @visibleForTesting a propósito: la llama
  /// también PremiumService.resetForTests().
  static void resetForTests() {
    instance.stop();
    instance._localStart = null;
    instance._cloudStart = null;
    instance._cloudKnown = false;
    instance._deviceStart = null;
    instance._deviceKnown = false;
    trialNotifier.value = false;
    trialDaysLeftNotifier.value = 0;
  }
}

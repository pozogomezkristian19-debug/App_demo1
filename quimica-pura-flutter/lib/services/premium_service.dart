// Premium REAL (pago manual por Transfermóvil).
//
// Escucha EN VIVO con snapshots de Firestore:
//   - users/{uid}: premiumExpiresAt + premiumPlan. Al aprobar en
//     Admin, la app pasa a Premium AL INSTANTE sin reabrir; al
//     llegar el vencimiento a cero, el Premium se quita solo (un
//     temporizador de 1 s re-evalúa el vencimiento aunque el
//     servidor no escriba nada).
//   - settings/app: precios y datos de Transfermóvil. Al cambiarlos
//     el Admin, el paywall y las instrucciones se actualizan AL
//     INSTANTE (RemoteTuning + settingsVersion).
//   - paymentRequests/{id} (la última del usuario): su estado
//     ('pending' | 'approved' | 'denied') y la razón del admin.
//
// El cliente NUNCA escribe premiumExpiresAt ni premiumPlan (eso lo
// hace solo el Admin; las reglas lo impiden): aquí solo se LEE el
// documento del usuario y se CREA la solicitud de pago.
//
// Alcance (2026-11-16): Premium y prueba funcionan en web Y en
// móvil (la puerta kIsWeb se quitó; al final todo va en la app
// compilada).

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'analytics_sync.dart';
import 'auth_service.dart';
import 'premium.dart';
import 'remote_tuning.dart';
import 'trial.dart';
import 'user_prefs.dart';

/// Una solicitud de pago (paymentRequests/{autoId}).
class PaymentRequest {
  const PaymentRequest({
    required this.id,
    required this.uid,
    required this.username,
    required this.plan,
    required this.amount,
    required this.status,
    required this.reason,
    this.createdAt,
  });

  /// 'pending' | 'approved' | 'denied'.
  final String id;
  final String uid;
  final String username;
  final String plan;
  final int amount;
  final String status;
  final String reason;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDenied => status == 'denied';

  /// Parsea un documento de Firestore. Acepta createdAt como
  /// Timestamp, DateTime, milisegundos (int) o ISO (String): el
  /// Admin y los tests no siempre escriben el mismo tipo.
  static PaymentRequest? fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) return null;
    return PaymentRequest(
      id: id,
      uid: data['uid']?.toString() ?? '',
      username: data['username']?.toString() ?? '',
      plan: data['plan']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      status: data['status']?.toString() ?? 'pending',
      reason: data['reason']?.toString() ?? '',
      createdAt: _parseDate(data['createdAt']),
    );
  }

  /// Parsea premiumExpiresAt / createdAt en cualquiera de sus
  /// formas (Timestamp de Firestore, DateTime, ms, ISO).
  static DateTime? _parseDate(Object? v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  /// premiumExpiresAt del documento users/{uid}, en cualquier forma.
  static DateTime? parseExpiry(Object? v) => _parseDate(v);
}

class PremiumService {
  PremiumService._();

  static final PremiumService instance = PremiumService._();

  /// ¿Tiene ACCESO COMPLETO vigente ahora (Premium pagado O
  /// prueba gratuita de 3 días)? Lo escuchan los candados y el
  /// paywall. NO lo escucha el chip de vidas: la prueba abre el
  /// contenido pero deja los 10 corazones al día; solo el Premium
  /// PAGADO tiene ∞ (Kristian 2026-11-16) — para eso está
  /// [paidPremiumNotifier]. El Premium PAGADO
  /// solo se sabe por [expiresNotifier] / [hasPaidPremium].
  static final ValueNotifier<bool> premiumNotifier =
      ValueNotifier<bool>(false);

  /// ¿Tiene Premium PAGADO vigente ahora (sin contar la prueba)?
  /// Lo escuchan ProgressService y el chip de vidas para el ∞:
  /// solo el Premium pagado tiene corazones ilimitados. La prueba
  /// de 3 días abre el contenido pero los corazones siguen
  /// limitados a 10 al día (Kristian 2026-11-16).
  static final ValueNotifier<bool> paidPremiumNotifier =
      ValueNotifier<bool>(false);

  /// Fecha de vencimiento vigente (o null). La escucha el contador
  /// en vivo del paywall.
  static final ValueNotifier<DateTime?> expiresNotifier =
      ValueNotifier<DateTime?>(null);

  /// Versión de settings/app: sube cada vez que llega un cambio
  /// (precios/tarjeta). El paywall la escucha para repintarse.
  static final ValueNotifier<int> settingsVersion = ValueNotifier<int>(0);

  /// Última solicitud de pago del usuario (o null si no hay ninguna).
  static final ValueNotifier<PaymentRequest?> latestRequestNotifier =
      ValueNotifier<PaymentRequest?>(null);

  /// Petición de abrir el paywall (la piden los candados desde las
  /// pantallas y la fila Premium de Cuenta; HomeScreen la escucha
  /// y navega). Sube en 1 cada vez que alguien pide el paywall.
  static final ValueNotifier<int> paywallRequested = ValueNotifier<int>(0);

  static void requestPaywall() => paywallRequested.value++;

  /// ¿La sesión actual inició sesión (Google o correo)? El
  /// anónimo (invitado) es false. Cambio 6 (2026-11-15): Premium
  /// exige iniciar sesión; el diamante y el paywall usan esto.
  static bool get isSignedIn => premiumIsSignedIn(
        googleLinked: AuthService.isGoogleLinked,
        emailLinked: AuthService.isEmailLinked,
      );

  /// Atajo de lectura (lo usa ProgressService a través de
  /// PremiumFlags; aquí queda para los tests): acceso completo
  /// vigente, Premium pagado O prueba gratuita.
  static bool get isPremiumNow => premiumNotifier.value;

  /// ¿Tiene Premium PAGADO vigente (sin contar la prueba)? El
  /// paywall lo usa para enseñar "¡Ya tienes Premium!" solo
  /// cuando de verdad se pagó: con la prueba activa, el paywall
  /// enseña los planes + el aviso de prueba, no el resultado.
  static bool get hasPaidPremium =>
      isPremiumActive(expiresNotifier.value ?? PremiumFlags.expiresAt);

  /// Re-evalúa el acceso completo ahora mismo (lo llama el
  /// temporizador de 1 s y quien cambie la prueba a mano, como
  /// los tests).
  void recomputeNow() => _recomputePremium();

  StreamSubscription<Map<String, dynamic>?>? _userSub;
  StreamSubscription<Map<String, dynamic>?>? _settingsSub;
  StreamSubscription<Map<String, dynamic>?>? _requestSub;
  Timer? _expiryTimer;
  Timer? _uidRetryTimer;
  Timer? _refreshTimer;
  String? _uid;
  String? _watchedRequestId;
  bool _started = false;

  /// Arranca las escuchas en vivo. Si aún no hay uid (inicio anónimo
  /// en curso), reintenta cada 5 s hasta que lo haya.
  /// [uidOverride] solo existe para tests.
  void start({String? uidOverride}) {
    if (_started) return;
    _started = true;
    _uid = uidOverride ?? AuthService.currentUid;
    if (_uid == null || _uid!.isEmpty) {
      _uidRetryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_uid != null && _uid!.isNotEmpty) {
          _uidRetryTimer?.cancel();
          _subscribeAll();
        } else {
          _uid = AuthService.currentUid;
          if (_uid != null && _uid!.isNotEmpty) {
            _uidRetryTimer?.cancel();
            _subscribeAll();
          }
        }
      });
      // Temporizador de vencimiento igual: sin uid, el Premium
      // local (si lo hubiera) también debe caducar solo.
      _startExpiryTimer();
      return;
    }
    _subscribeAll();
  }

  void _subscribeAll() {
    _subscribeSettings();
    _subscribeUser();
    unawaited(refreshLatestRequest());
    _startExpiryTimer();
    _refreshTimer ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(refreshLatestRequest()),
    );
  }

  void _startExpiryTimer() {
    _expiryTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      _recomputePremium();
    });
  }

  void _subscribeSettings() {
    try {
      _settingsSub =
          AnalyticsSync.repository.watchDoc('settings', 'app').listen(
        (data) {
          if (data == null) return;
          RemoteTuning.apply(data);
          settingsVersion.value++;
        },
        onError: (_) {},
      );
    } catch (_) {
      // Sin Firebase: los valores locales mandan, como antes.
    }
  }

  void _subscribeUser() {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    try {
      _userSub =
          AnalyticsSync.repository.watchDoc('users', uid).listen((data) {
        _applyUserDoc(data);
      }, onError: (_) {});
    } catch (_) {
      // Sin Firebase: sin Premium, como antes.
    }
  }

  /// Aplica el documento users/{uid}: premiumExpiresAt +
  /// premiumPlan. Solo lee; nunca escribe estos campos. También
  /// pasa el inicio de la prueba (`trialStartedAt`) a
  /// TrialService, que marca la nube como conocida (así la prueba
  /// local se puede subir sin pisar un inicio anterior).
  void _applyUserDoc(Map<String, dynamic>? data) {
    final expires = PaymentRequest.parseExpiry(data?['premiumExpiresAt']);
    final plan = data?['premiumPlan']?.toString();
    final validPlan = isValidPremiumPlan(plan) ? plan : null;
    expiresNotifier.value = expires;
    PremiumFlags.expiresAt = expires;
    PremiumFlags.plan = validPlan;
    TrialService.instance.applyCloudStart(data?['trialStartedAt']);
    _recomputePremium();
  }

  /// Re-evalúa si hay ACCESO COMPLETO vigente: Premium pagado
  /// (vencimiento en el futuro) O prueba gratuita de 3 días
  /// activa (2026-11-15, Kristian). Lo llama el listener del
  /// usuario y el temporizador de 1 s: al llegar a cero, el
  /// acceso se quita solo sin tocar el servidor (y con la prueba
  /// vencida, vuelven los candados y los 10 corazones). El ∞ es
  /// aparte: SOLO el Premium pagado lo tiene — la prueba abre el
  /// contenido pero los corazones siguen limitados a 10 al día
  /// (Kristian 2026-11-16).
  void _recomputePremium() {
    final paid = isPremiumActive(
      expiresNotifier.value ?? PremiumFlags.expiresAt,
    );
    final active = paid || TrialService.isTrialActiveNow;
    if (premiumNotifier.value != active) {
      premiumNotifier.value = active;
      PremiumFlags.isPremium = active;
      if (!active) {
        PremiumFlags.expiresAt = null;
        PremiumFlags.plan = null;
      }
    } else {
      PremiumFlags.isPremium = active;
    }
    PremiumFlags.hasPaidPremium = paid;
    if (paidPremiumNotifier.value != paid) {
      paidPremiumNotifier.value = paid;
    }
  }

  /// Lee la última solicitud de pago del usuario (la más reciente
  /// por createdAt) y se suscribe a sus cambios en vivo. Falla en
  /// silencio sin red: latestRequest queda como estaba.
  Future<void> refreshLatestRequest() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    try {
      final rows = await AnalyticsSync.repository
          .queryDocs('paymentRequests', whereField: 'uid', isEqualTo: uid)
          .timeout(const Duration(seconds: 5));
      if (rows.isEmpty) return;
      rows.sort((a, b) {
        final da = PaymentRequest.parseExpiry(a['createdAt']);
        final db = PaymentRequest.parseExpiry(b['createdAt']);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
      final latest = rows.first;
      final id = latest['id']?.toString() ?? '';
      final parsed = PaymentRequest.fromMap(id, latest);
      if (parsed != null) latestRequestNotifier.value = parsed;
      if (id.isNotEmpty && id != _watchedRequestId) {
        _watchedRequestId = id;
        await _requestSub?.cancel();
        try {
          _requestSub = AnalyticsSync.repository
              .watchDoc('paymentRequests', id)
              .listen((data) {
            final req = PaymentRequest.fromMap(id, data);
            if (req != null) latestRequestNotifier.value = req;
          }, onError: (_) {});
        } catch (_) {
          // Sin escucha en vivo: el refresco de 30 s la actualiza.
        }
      }
    } catch (_) {
      // Sin red: la solicitud queda como estaba.
    }
  }

  /// Motivo del último envío fallido ('timeout' | 'denied' |
  /// 'no-session' | 'bad-plan' | 'unknown'), o null si el último
  /// envío fue bien. El paywall lo usa para decirle al usuario
  /// QUÉ pasó, no solo "revisa tu conexión".
  String? lastSubmitError;

  /// Crea la solicitud de pago en paymentRequests/{autoId} con la
  /// captura en base64 (screenshotData). El cliente NUNCA escribe
  /// premiumExpiresAt/premiumPlan. Devuelve true si se creó.
  /// [screenshotData] es la data URL de pickAndEncodeScreenshot
  /// (puede ser '' si el usuario no subió captura).
  ///
  /// Conexión lenta (2026-11-16, Kristian: el envío falló): la
  /// captura en base64 pesa ~100-300 KB y con la conexión lenta
  /// 10 s no alcanzan — ahora 30 s por intento y 2 intentos. La
  /// escucha en vivo y el refresco van FUERA del reintento: si la
  /// solicitud ya se creó, no se crea otra igual.
  Future<bool> submitPaymentRequest({
    required String plan,
    String screenshotData = '',
  }) async {
    final uid = _uid ?? AuthService.currentUid;
    if (uid == null || uid.isEmpty) {
      lastSubmitError = 'no-session';
      return false;
    }
    // Cambio 6 (2026-11-15): sin sesión no hay pago — el invitado
    // nunca llega al paywall (la puerta está en _openPaywall), y
    // esto es el cinturón y tirantes por si llegara aquí.
    if (!isSignedIn) {
      lastSubmitError = 'no-session';
      return false;
    }
    if (!isValidPremiumPlan(plan)) {
      lastSubmitError = 'bad-plan';
      return false;
    }
    _uid = uid;
    String? failure;
    String? id;
    for (var attempt = 0; attempt < 2 && id == null; attempt++) {
      if (attempt > 0) {
        // El intento anterior se quedó sin respuesta (tiempo
        // agotado o error): puede que el servidor SÍ haya creado
        // la solicitud y solo se perdiera la respuesta. Antes de
        // crear otra, se busca la pendiente que ya exista para
        // este plan y se adopta (2026-11-17, revisión: con la
        // conexión lenta, el reintento duplicaba la solicitud y
        // en el Admin se veían dos pendientes del mismo usuario).
        // Solo se adopta si está pendiente y es del mismo plan;
        // si no hay red, el refresco no hace nada y el reintento
        // sigue normal.
        await refreshLatestRequest();
        final existing = latestRequestNotifier.value;
        if (existing != null &&
            existing.isPending &&
            existing.plan == plan) {
          id = existing.id;
          break;
        }
      }
      try {
        final username = UserPrefs.publicUsername.isNotEmpty
            ? UserPrefs.publicUsername
            : UserPrefs.userName;
        id = await AnalyticsSync.repository
            .createDoc('paymentRequests', <String, dynamic>{
          'uid': uid,
          'username': username,
          'plan': plan,
          'amount': premiumPriceFor(plan, RemoteTuning.planPrices),
          'screenshotUrl': '',
          'screenshotPath': '',
          'screenshotData': screenshotData,
          'status': 'pending',
          'reason': '',
          'createdAt': DateTime.now(),
          'reviewedAt': null,
          'reviewedBy': null,
        }).timeout(const Duration(seconds: 30));
      } on TimeoutException {
        // Conexión lenta: se reintenta una vez.
        failure = 'timeout';
      } on FirebaseException catch (e) {
        // Sin permiso no se reintenta: volver a intentarlo no
        // cambia nada.
        if (e.code == 'permission-denied') {
          lastSubmitError = 'denied';
          return false;
        }
        failure = 'unknown';
      } catch (_) {
        failure = 'unknown';
      }
    }
    if (id == null) {
      lastSubmitError = failure ?? 'unknown';
      return false;
    }
    lastSubmitError = null;
    // `id` es String? y el cierre de listen() no conserva la
    // promoción del chequeo de null: copiar a no-nulo.
    final requestId = id;
    _watchedRequestId = requestId;
    await _requestSub?.cancel();
    try {
      _requestSub = AnalyticsSync.repository
          .watchDoc('paymentRequests', requestId)
          .listen((data) {
        final req = PaymentRequest.fromMap(requestId, data);
        if (req != null) latestRequestNotifier.value = req;
      }, onError: (_) {});
    } catch (_) {
      // Sin escucha en vivo: el refresco de 30 s la actualiza.
    }
    await refreshLatestRequest();
    return true;
  }

  /// Reinicia tras un cambio de sesión (cerrar sesión, 2026-11-16):
  /// corta las escuchas del uid viejo (su Premium y su solicitud
  /// ya no son mías) y se suscribe al uid actual. El invitado no
  /// tiene Premium pagado ni solicitudes pendientes.
  void restart() {
    stop();
    latestRequestNotifier.value = null;
    start();
  }

  /// Para la escucha (al cerrar sesión, en tests). No borra el
  /// estado Premium en vivo: solo corta los streams.
  void stop() {
    _started = false;
    _uidRetryTimer?.cancel();
    _refreshTimer?.cancel();
    _expiryTimer?.cancel();
    _uidRetryTimer = null;
    _refreshTimer = null;
    _expiryTimer = null;
    unawaited(_userSub?.cancel());
    unawaited(_settingsSub?.cancel());
    unawaited(_requestSub?.cancel());
    _userSub = null;
    _settingsSub = null;
    _requestSub = null;
    _watchedRequestId = null;
  }

  /// Solo para tests: limpia estado, notifiers y suscripciones.
  @visibleForTesting
  static void resetForTests() {
    instance.stop();
    instance._uid = null;
    premiumNotifier.value = false;
    paidPremiumNotifier.value = false;
    expiresNotifier.value = null;
    settingsVersion.value = 0;
    latestRequestNotifier.value = null;
    paywallRequested.value = 0;
    PremiumFlags.resetForTests();
    TrialService.resetForTests();
  }
}

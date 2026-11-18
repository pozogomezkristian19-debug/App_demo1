// Compra de puntos REAL (pago manual por Transfermóvil, 2026-11-17).
//
// Igual que el Premium, pero con puntos: el usuario elige un
// paquete, paga por Transfermóvil y sube la captura. La solicitud
// va a Firestore (colección `pointsRequests`) y Kristian la aprueba
// (o niega) en el Admin; al aprobar, los puntos se suman al usuario
// con un incremento atómico (ver review_points.py).
//
// El cliente NUNCA escribe los puntos del usuario directamente
// (eso lo hace solo el Admin al aprobar; las reglas lo impiden):
// aquí solo se CREA la solicitud y se LEE su estado.
//
// La pantalla escucha `latestRequestNotifier` para pasar de
// «En revisión» a «¡Listo!» cuando Kristian aprueba. Los puntos
// acreditados aparecen en el saldo al subir el progreso (la nube
// manda cuando tiene más puntos que el teléfono; ver
// AnalyticsSync._writeSnapshot).
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'analytics_sync.dart';
import 'auth_service.dart';
import 'premium.dart';
import 'premium_service.dart';
import 'user_prefs.dart';

/// Un paquete de puntos: puntos que se acreditan y precio en CUP.
class PointsPack {
  const PointsPack(this.points, this.cup, {this.popular = false});

  final int points;
  final int cup;
  final bool popular;
}

/// Paquetes (2026-11-17): con los precios de hoy, un tema cuesta
/// 300 puntos y jugando se ganan unos 20-40 por nivel.
const List<PointsPack> kPointsPacks = [
  PointsPack(500, 50),
  PointsPack(1200, 100, popular: true),
  PointsPack(3000, 200),
];

/// Una solicitud de compra de puntos (pointsRequests/{autoId}).
class PointsRequest {
  const PointsRequest({
    required this.id,
    required this.uid,
    required this.username,
    required this.points,
    required this.amount,
    required this.status,
    required this.reason,
    this.createdAt,
  });

  /// 'pending' | 'approved' | 'denied'.
  final String id;
  final String uid;
  final String username;
  final int points;
  final int amount;
  final String status;
  final String reason;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDenied => status == 'denied';

  static PointsRequest? fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) return null;
    return PointsRequest(
      id: id,
      uid: data['uid']?.toString() ?? '',
      username: data['username']?.toString() ?? '',
      points: (data['points'] as num?)?.toInt() ?? 0,
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      status: data['status']?.toString() ?? 'pending',
      reason: data['reason']?.toString() ?? '',
      createdAt: PaymentRequest.parseExpiry(data['createdAt']),
    );
  }
}

class PointsPurchaseService {
  PointsPurchaseService._();

  static final PointsPurchaseService instance = PointsPurchaseService._();

  /// Última solicitud de compra de puntos del usuario (o null).
  static final ValueNotifier<PointsRequest?> latestRequestNotifier =
      ValueNotifier<PointsRequest?>(null);

  /// ¿La sesión actual inició sesión (Google o correo)? Igual que
  /// Premium: comprar puntos exige iniciar sesión; el invitado no
  /// llega a enviar (el _submit lo frena con 'no-session').
  static bool get isSignedIn => premiumIsSignedIn(
        googleLinked: AuthService.isGoogleLinked,
        emailLinked: AuthService.isEmailLinked,
      );

  /// ¿Es un paquete válido (puntos de la tabla y precio que le toca)?
  static bool isValidPack(PointsPack pack) {
    for (final p in kPointsPacks) {
      if (p.points == pack.points && p.cup == pack.cup) return true;
    }
    return false;
  }

  StreamSubscription<Map<String, dynamic>?>? _requestSub;
  Timer? _refreshTimer;
  Timer? _uidRetryTimer;
  String? _uid;
  String? _watchedRequestId;
  bool _started = false;

  /// Arranca la escucha de la última solicitud. Si aún no hay uid,
  /// reintenta cada 5 s hasta que lo haya.
  /// [uidOverride] solo existe para tests.
  void start({String? uidOverride}) {
    if (_started) return;
    _started = true;
    _uid = uidOverride ?? AuthService.currentUid;
    if (_uid == null || _uid!.isEmpty) {
      _uidRetryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _uid = AuthService.currentUid;
        if (_uid != null && _uid!.isNotEmpty) {
          _uidRetryTimer?.cancel();
          _subscribeAll();
        }
      });
      return;
    }
    _subscribeAll();
  }

  void _subscribeAll() {
    unawaited(refreshLatestRequest());
    _refreshTimer ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(refreshLatestRequest()),
    );
  }

  /// Para la escucha (al salir de la pantalla, en tests).
  void stop() {
    _started = false;
    _uidRetryTimer?.cancel();
    _refreshTimer?.cancel();
    _requestSub?.cancel();
    _uidRetryTimer = null;
    _refreshTimer = null;
    _requestSub = null;
  }

  static void resetForTests() {
    instance.stop();
    instance._uid = null;
    instance._watchedRequestId = null;
    instance.lastSubmitError = null;
    latestRequestNotifier.value = null;
  }

  /// Lee la última solicitud de compra del usuario (la más reciente
  /// por createdAt) y se suscribe a sus cambios en vivo. Falla en
  /// silencio sin red: latestRequest queda como estaba. Sin uid
  /// previo, coge el de la sesión (como el _submit).
  Future<void> refreshLatestRequest() async {
    final uid = _uid ?? AuthService.currentUid;
    if (uid == null || uid.isEmpty) return;
    _uid = uid;
    try {
      final rows = await AnalyticsSync.repository
          .queryDocs('pointsRequests', whereField: 'uid', isEqualTo: uid)
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
      final parsed = PointsRequest.fromMap(id, latest);
      if (parsed != null) latestRequestNotifier.value = parsed;
      if (id.isNotEmpty && id != _watchedRequestId) {
        _watchedRequestId = id;
        await _requestSub?.cancel();
        try {
          _requestSub = AnalyticsSync.repository
              .watchDoc('pointsRequests', id)
              .listen((data) {
            final req = PointsRequest.fromMap(id, data);
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
  /// 'no-session' | 'bad-pack' | 'unknown'), o null si el último
  /// envío fue bien. La pantalla lo usa para decirle al usuario
  /// QUÉ pasó, no solo "revisa tu conexión".
  String? lastSubmitError;

  /// Crea la solicitud de compra en pointsRequests/{autoId} con la
  /// captura en base64 (screenshotData). El cliente NUNCA escribe
  /// los puntos del usuario. Devuelve true si se creó.
  /// [screenshotData] es la data URL de pickAndEncodeScreenshot
  /// (puede ser '' si el usuario no subió captura).
  ///
  /// Conexión lenta (igual que Premium): la captura en base64 pesa
  /// ~100-300 KB y 10 s no alcanzan — ahora 30 s por intento y 2
  /// intentos. Si el primer intento se quedó sin respuesta, antes
  /// de crear otra se busca la pendiente que ya exista para este
  /// paquete y se adopta: con la conexión lenta, el reintento
  /// duplicaba la solicitud.
  Future<bool> submitPointsRequest({
    required PointsPack pack,
    String screenshotData = '',
  }) async {
    final uid = _uid ?? AuthService.currentUid;
    if (uid == null || uid.isEmpty) {
      lastSubmitError = 'no-session';
      return false;
    }
    if (!isSignedIn) {
      lastSubmitError = 'no-session';
      return false;
    }
    if (!isValidPack(pack)) {
      lastSubmitError = 'bad-pack';
      return false;
    }
    _uid = uid;
    String? failure;
    String? id;
    for (var attempt = 0; attempt < 2 && id == null; attempt++) {
      if (attempt > 0) {
        await refreshLatestRequest();
        final existing = latestRequestNotifier.value;
        if (existing != null &&
            existing.isPending &&
            existing.points == pack.points) {
          id = existing.id;
          break;
        }
      }
      try {
        final username = UserPrefs.publicUsername.isNotEmpty
            ? UserPrefs.publicUsername
            : UserPrefs.userName;
        id = await AnalyticsSync.repository
            .createDoc('pointsRequests', <String, dynamic>{
          'uid': uid,
          'username': username,
          'points': pack.points,
          'amount': pack.cup,
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
          .watchDoc('pointsRequests', requestId)
          .listen((data) {
        final req = PointsRequest.fromMap(requestId, data);
        if (req != null) latestRequestNotifier.value = req;
      }, onError: (_) {});
    } catch (_) {
      // Sin escucha en vivo: el refresco de 30 s la actualiza.
    }
    await refreshLatestRequest();
    return true;
  }
}

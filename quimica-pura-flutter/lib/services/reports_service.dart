// Reportar una pregunta (7.0): escribe en Firestore 'reports'
// (id de la pregunta + nota del usuario + fecha). La UI lo llama
// desde el quiz ("Reportar pregunta") y muestra solo "Gracias por
// avisar": nunca un error en pantalla.
//
// Reportar un USUARIO (lote seguir, 2026-11-16): también escribe
// en 'reports', con 'type': 'user', para que llegue a la cola del
// Admin. El Admin lee con orderBy('createdAt', descending: true):
// por eso el reporte de usuario lleva 'createdAt' como Timestamp
// (ADEMÁS de 'createdAtMs'). Los reportes de pregunta YA llevan
// 'createdAt' + 'authorUid' + 'status' desde 2026-11-17 (antes
// escribían solo 'createdAtMs' y por eso NO aparecían en la cola
// y la regla de creación los rechazaba en silencio).
//
// Reglas: sin Google vinculada no se reporta (puerta de
// identidad); sin internet el reporte se encola en local y se
// reintenta solo (retryPendingReports, al abrir la app y al volver
// a primer plano). Un reporte duplicado por reintento es inofensivo
// (el creador ve dos avisos iguales de la misma pregunta).
import 'package:cloud_firestore/cloud_firestore.dart';

import 'analytics_sync.dart';
import 'auth_service.dart';
import 'online_common.dart';
import 'user_prefs.dart';

class ReportsService {
  ReportsService._();

  static const String _pendingKey = 'melli_online_pending_reports';

  /// Cola local de reportes de usuario pendientes (sin internet).
  static const String _pendingUserReportsKey =
      'melli_online_pending_user_reports';

  static AnalyticsRepository get _repo => AnalyticsSync.repository;
  static String get _me => AuthService.currentUid ?? '';
  static String get _myName => UserPrefs.userName;

  /// Reporta [questionId] con la nota [note] del usuario. Devuelve
  /// true si quedó enviado; false si quedó encolado en local (sin
  /// internet), sin Google o con la nota vacía. Nunca lanza.
  static Future<bool> reportQuestion({
    required String questionId,
    required String note,
  }) async {
    final cleanNote = note.trim();
    if (questionId.isEmpty || cleanNote.isEmpty) return false;
    if (!OnlineCommon.allowed || _me.isEmpty) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = <String, dynamic>{
      'questionId': questionId,
      'note': cleanNote,
      'uid': _me,
      'username': _myName,
      'createdAtMs': now,
      // Para que el reporte llegue y se vea en la cola del Admin
      // (2026-11-17): la regla de creación exige authorUid propio
      // y estado inicial 'pendiente', y la cola ordena por
      // 'createdAt' (sin él, el reporte no aparece). Antes no se
      // escribía ninguno de los tres y el reporte se rechazaba
      // en silencio aunque la app dijera «Gracias por avisar».
      'authorUid': _me,
      'status': 'pendiente',
      'createdAt': Timestamp.now(),
    };
    final id = await OnlineCommon.call(() => _repo.createDoc('reports', data));
    if (id != null) return true;
    // La cola es JSON y el Timestamp no se puede guardar: se
    // reconstruye al reintentar (igual que los de usuario).
    final queued = Map<String, dynamic>.from(data)..remove('createdAt');
    await OnlineCommon.enqueue(_pendingKey, queued);
    return false;
  }

  /// Reportes pendientes de envío (solo lectura local).
  static Future<List<Map<String, dynamic>>> pendingReports() =>
      OnlineCommon.pending(_pendingKey);

  /// ¿Cuántos reportes pendientes hay?
  static Future<int> pendingCount() =>
      OnlineCommon.pendingCount(_pendingKey);

  /// Reporta a un usuario ([uid]) con el motivo [reason]. Crea un
  /// documento REAL en 'reports' que llega a la cola del Admin
  /// (type 'user', createdAt Timestamp + createdAtMs, status
  /// 'open'). Devuelve true si quedó enviado; false si quedó
  /// encolado en local (sin internet), sin Google, con el motivo
  /// vacío o si es yo mismo. Nunca lanza.
  static Future<bool> reportUser({
    required String uid,
    required String reason,
  }) async {
    final cleanReason = reason.trim();
    if (uid.isEmpty || cleanReason.isEmpty) return false;
    if (!OnlineCommon.allowed || _me.isEmpty) return false;
    if (uid == _me) return false;
    String reportedUsername = '';
    final doc =
        await OnlineCommon.call(() => _repo.getDoc('users', uid));
    reportedUsername = doc?['username']?.toString() ?? '';
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = <String, dynamic>{
      'type': 'user',
      'reportedUid': uid,
      'reportedUsername': reportedUsername,
      'questionId': '',
      'note': cleanReason,
      'uid': _me,
      'username': _myName,
      'status': 'open',
      'createdAt': Timestamp.now(),
      'createdAtMs': now,
    };
    final id = await OnlineCommon.call(() => _repo.createDoc('reports', data));
    if (id != null) return true;
    // La cola es JSON y el Timestamp no se puede guardar: se
    // reconstruye al reintentar (ver retryPendingUserReports).
    final queued = Map<String, dynamic>.from(data)..remove('createdAt');
    await OnlineCommon.enqueue(_pendingUserReportsKey, queued);
    return false;
  }

  /// Reportes de usuario pendientes de envío (solo lectura local).
  static Future<List<Map<String, dynamic>>> pendingUserReports() =>
      OnlineCommon.pending(_pendingUserReportsKey);

  /// Reintenta los reportes de usuario que quedaron pendientes sin
  /// internet. Devuelve cuántos se enviaron.
  static Future<int> retryPendingUserReports() async {
    if (!OnlineCommon.allowed || _me.isEmpty) return 0;
    final items = await OnlineCommon.pending(_pendingUserReportsKey);
    var done = 0;
    for (var i = items.length - 1; i >= 0; i--) {
      final item = Map<String, dynamic>.from(items[i])
        ..['createdAt'] = Timestamp.now();
      final id = await OnlineCommon.call(
          () => _repo.createDoc('reports', item));
      if (id != null) {
        await OnlineCommon.removeAt(_pendingUserReportsKey, i);
        done++;
      }
    }
    return done;
  }

  /// Reintenta los reportes que quedaron pendientes sin internet.
  /// Devuelve cuántos se enviaron. También reintenta los reportes
  /// de usuario (misma cola de arranque en main()).
  static Future<int> retryPendingReports() async {
    var done = await retryPendingUserReports();
    if (!OnlineCommon.allowed || _me.isEmpty) return done;
    final items = await OnlineCommon.pending(_pendingKey);
    for (var i = items.length - 1; i >= 0; i--) {
      // Se reconstruye 'createdAt' (no cabe en la cola JSON) y se
      // aseguran los campos que la regla exige (los encolados de
      // antes del arreglo no los traían).
      final item = Map<String, dynamic>.from(items[i])
        ..['createdAt'] = Timestamp.now()
        ..['authorUid'] = _me
        ..['status'] = 'pendiente';
      final id = await OnlineCommon.call(
          () => _repo.createDoc('reports', item));
      if (id != null) {
        await OnlineCommon.removeAt(_pendingKey, i);
        done++;
      }
    }
    return done;
  }
}

// Reportar una pregunta (7.0): escribe en Firestore 'reports'
// (id de la pregunta + nota del usuario + fecha). La UI lo llama
// desde el quiz ("Reportar pregunta") y muestra solo "Gracias por
// avisar": nunca un error en pantalla.
//
// Reglas: sin Google vinculada no se reporta (puerta de
// identidad); sin internet el reporte se encola en local y se
// reintenta solo (retryPendingReports, al abrir la app y al volver
// a primer plano). Un reporte duplicado por reintento es inofensivo
// (el creador ve dos avisos iguales de la misma pregunta).
import 'analytics_sync.dart';
import 'auth_service.dart';
import 'online_common.dart';
import 'user_prefs.dart';

class ReportsService {
  ReportsService._();

  static const String _pendingKey = 'melli_online_pending_reports';

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
    };
    final id = await OnlineCommon.call(() => _repo.createDoc('reports', data));
    if (id != null) return true;
    await OnlineCommon.enqueue(_pendingKey, data);
    return false;
  }

  /// Reportes pendientes de envío (solo lectura local).
  static Future<List<Map<String, dynamic>>> pendingReports() =>
      OnlineCommon.pending(_pendingKey);

  /// ¿Cuántos reportes pendientes hay?
  static Future<int> pendingCount() =>
      OnlineCommon.pendingCount(_pendingKey);

  /// Reintenta los reportes que quedaron pendientes sin internet.
  /// Devuelve cuántos se enviaron.
  static Future<int> retryPendingReports() async {
    if (!OnlineCommon.allowed || _me.isEmpty) return 0;
    final items = await OnlineCommon.pending(_pendingKey);
    var done = 0;
    for (var i = items.length - 1; i >= 0; i--) {
      final item = items[i];
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

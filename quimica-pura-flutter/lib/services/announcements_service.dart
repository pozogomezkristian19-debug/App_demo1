// Avisos del creador (7.0): lee la colección 'announcements' y
// los expone para que la bandeja de notificaciones los muestre.
// Los avisos los crea el creador desde el panel de admin (o
// Firebase): este servicio SOLO lee.
//
// Reglas: sin Google vinculada no hay avisos (puerta de
// identidad); sin internet, lista vacía, nunca un error. Un aviso
// sin 'active' se considera activo (los viejos no llevan el campo).
import 'analytics_sync.dart';
import 'notification_inbox.dart';
import 'online_common.dart';

/// Un aviso del creador.
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAtMs,
    required this.active,
  });

  final String id;
  final String title;
  final String body;
  final int createdAtMs;
  final bool active;

  static Announcement? fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final id = raw['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    return Announcement(
      id: id,
      title: raw['title']?.toString() ?? '',
      body: raw['body']?.toString() ?? '',
      createdAtMs: (raw['createdAtMs'] as num?)?.toInt() ?? 0,
      active: raw['active'] != false,
    );
  }
}

class AnnouncementsService {
  AnnouncementsService._();

  static AnalyticsRepository get _repo => AnalyticsSync.repository;

  /// Avisos, del más reciente al más viejo. [activeOnly] deja
  /// solo los activos. Vacío sin Google o sin internet.
  static Future<List<Announcement>> fetchAnnouncements({
    bool activeOnly = true,
  }) async {
    if (!OnlineCommon.allowed) return [];
    final docs = await OnlineCommon.call(() => _repo.queryDocs(
          'announcements',
          orderByField: 'createdAtMs',
          descending: true,
          limit: 50,
        ));
    if (docs == null) return [];
    final out = <Announcement>[];
    for (final d in docs) {
      final a = Announcement.fromMap(d);
      if (a == null) continue;
      if (activeOnly && !a.active) continue;
      out.add(a);
    }
    return out;
  }

  /// El aviso más reciente (o null si no hay ninguno).
  static Future<Announcement?> latestAnnouncement() async {
    final all = await fetchAnnouncements();
    return all.isEmpty ? null : all.first;
  }

  /// Sincroniza la bandeja con los avisos del creador (Zona G2,
  /// capa sin push): un aviso publicado mientras no había internet
  /// (o sin que el push llegara) aparece en Notificaciones al abrir
  /// la app. El id es el MISMO que usa el push
  /// ('announcement-<id>', ver push_service.dart), así que un aviso
  /// que llegó por push y luego se sincroniza no deja dos entradas.
  /// El título y el cuerpo son los que escribió el creador (no hay
  /// traducción: el aviso es su texto). Sin Google o sin internet,
  /// vacío y sin hacer nada; nunca lanza.
  static Future<void> syncToInbox() async {
    final all = await fetchAnnouncements();
    for (final a in all) {
      final title = a.title.trim();
      final body = a.body.trim();
      await NotificationInbox.addIfAbsent(
        id: 'announcement-${a.id}',
        kind: InboxKind.announcement,
        title: title.isEmpty ? 'Nuevo aviso de Quemia' : title,
        body: body.isEmpty ? 'Abre la app para leerlo.' : body,
        data: {'announcementId': a.id, 'pushType': 'announcement'},
      );
    }
  }
}

// Pantalla "Notificaciones" (fix4, punto 8): la bandeja de entrada
// del centro de notificaciones (como Facebook), que se abre con la
// campana de la barra superior (antes abría Recordatorios).
//
// - Si las notificaciones del sistema NO están activadas, arriba
//   sale la tarjeta "Activar notificaciones" (pide el permiso; si
//   está denegado, ofrece "Ir a Ajustes", el mismo flujo del punto
//   3). La lista se ve SIEMPRE debajo (no se esconde hasta activar):
//   así la entrada de una actualización pendiente sigue al alcance
//   aunque las notificaciones estén apagadas. La tarjeta desaparece
//   cuando se concede el permiso.
// - Abrir la bandeja marca los visibles como leídos (la campana se
//   apaga); tocar un elemento lo marca leído y abre lo que le toca:
//   actualización → el diálogo de actualización; recordatorio → el
//   repaso de errores; logro → Mis estadísticas; racha → Niveles.
// - Abajo, un enlace a "Configurar recordatorios" (la pantalla de
//   Recordatorios sigue existiendo: se llega desde Cuenta y desde
//   aquí; la campana ya no la abre directamente).

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/localization.dart';
import '../services/notification_inbox.dart';
import '../services/notification_service.dart';
import '../services/update_check.dart';
import '../widgets/lucide_icons.dart';
import '../widgets/notification_settings_dialog.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.onOpenScreen});

  /// Abre una pantalla del menú por su clave (review, stats,
  /// reminder…): lo resuelve HomeScreen con _openScreenKey.
  final void Function(String key) onOpenScreen;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  bool _notifEnabled = true;
  bool _waitingForPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
    // Al abrir la bandeja: primero se anotan los avisos que ya
    // sonaron y luego se marca todo como leído (la campana se
    // apaga: el usuario ya está mirando la lista).
    unawaited(_openInbox());
  }

  Future<void> _openInbox() async {
    await NotificationService.reconcileFiredReminders();
    if (mounted) await NotificationInbox.markAllRead();
  }

  Future<void> _checkPermission() async {
    final granted = await NotificationService.isPermissionGranted;
    if (mounted) setState(() => _notifEnabled = granted);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver de Ajustes, la pantalla se mantiene abierta (ver
    // _enableNotifications): si el usuario repartió el permiso, la
    // tarjeta desaparece sola (mismo patrón que ReminderScreen).
    if (state == AppLifecycleState.resumed && _waitingForPermission) {
      _waitingForPermission = false;
      _checkPermission();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _enableNotifications() async {
    final granted = await NotificationService.requestPermission();
    if (!mounted) return;
    if (granted) {
      setState(() => _notifEnabled = true);
      return;
    }
    final go = await showNotificationSettingsDialog(context);
    if (go == true) {
      _waitingForPermission = true;
      await NotificationService.openNotificationSettings();
    }
  }

  Future<void> _openEntry(InboxEntry entry) async {
    await NotificationInbox.markRead(entry.id);
    if (!mounted) return;
    switch (entry.kind) {
      case InboxKind.update:
        final info = UpdateInfo.fromJson(entry.data);
        if (info == null || compareVersions(info.latest, kAppVersion) <= 0) {
          // Ya estamos al día: la entrada sobra.
          await NotificationInbox.removeByKind(InboxKind.update);
          return;
        }
        await UpdateCheckService.showUpdateDialog(context, info);
      case InboxKind.reminder:
        Navigator.of(context).pop();
        widget.onOpenScreen('review');
      case InboxKind.achievement:
        Navigator.of(context).pop();
        widget.onOpenScreen('stats');
      case InboxKind.streak:
        // La racha se salva practicando: volver a Niveles.
        Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('inboxTitle'))),
      body: ValueListenableBuilder<List<InboxEntry>>(
        valueListenable: NotificationInbox.entriesNotifier,
        builder: (context, entries, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!_notifEnabled) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('notifSettingsTitle'),
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(tr('notifSettingsBody')),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _enableNotifications,
                          icon: const LucideIcon(LucideIcons.bell,
                              size: 20, threeD: true),
                          label: Text(tr('inboxEnableButton')),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    tr('inboxEmpty'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final entry in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _EntryTile(
                      entry: entry,
                      onTap: () => _openEntry(entry),
                    ),
                  ),
              const SizedBox(height: 8),
              ListTile(
                key: const Key('inboxOpenReminders'),
                leading: const LucideIcon(LucideIcons.bellRing,
                    size: 24, threeD: true),
                title: Text(tr('inboxOpenReminders')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => widget.onOpenScreen('reminder'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Una entrada de la bandeja (fix4, punto 10, rediseño): tarjeta
/// grande y tintada según el tipo (actualización = tinte teal,
/// recordatorio = tinte ámbar, logro = tinte violeta, racha = tinte
/// naranja), esquinas de 18, icono 3D en su círculo tintado, flecha
/// a la derecha y hora en gris pequeño. Sin leer: título en negrita,
/// tinte más fuerte y puntito del color del tipo; leída: atenuada
/// (tinte suave, título normal, cuerpo más apagado).
class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.onTap});

  final InboxEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (entry.kind) {
      InboxKind.update => (LucideIcons.download, const Color(0xFF00C2A8)),
      InboxKind.reminder => (LucideIcons.bell, const Color(0xFFF59E0B)),
      InboxKind.achievement => (LucideIcons.trophy, const Color(0xFF8B5CF6)),
      InboxKind.streak => (LucideIcons.flame, const Color(0xFFF97316)),
    };
    final unread = !entry.read;
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: unread ? 0.16 : 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: unread ? 0.35 : 0.15),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: LucideIcon(icon, size: 24, color: color, threeD: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: TextStyle(
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w500,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (entry.body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          entry.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface
                                .withValues(alpha: unread ? 0.85 : 0.65),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(entry.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    if (unread)
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (unread) const SizedBox(height: 10),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "hoy, 18:30" / "ayer, 09:15" / "3/11/2026, 18:30".
String _formatTime(DateTime at) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final hm = '${at.hour.toString().padLeft(2, '0')}'
      ':${at.minute.toString().padLeft(2, '0')}';
  if (day == today) return '${tr('inboxToday')}, $hm';
  if (day == today.subtract(const Duration(days: 1))) {
    return '${tr('inboxYesterday')}, $hm';
  }
  return '${at.day}/${at.month}/${at.year}, $hm';
}

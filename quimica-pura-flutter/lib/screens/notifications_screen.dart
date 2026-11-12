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
import '../widgets/duo_button.dart';
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
      case InboxKind.support:
        // Respuesta del admin a un mensaje de soporte: solo se
        // marca como leída (la charla vive en Soporte, B la abre
        // desde Cuenta o el drawer).
        break;
      case InboxKind.friendRequest:
        // Solicitud de amistad: se confirma o se elimina en Amigos.
        Navigator.of(context).pop();
        widget.onOpenScreen('friends');
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
                // Diseño Duolingo §3.15: fila plana con borde 2 pt
                // #E5E5E5 y radio 16, sin tarjeta con sombra.
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: const Color(0xFFE5E5E5), width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('notifSettingsTitle'),
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4B4B4B)),
                        ),
                        const SizedBox(height: 6),
                        Text(tr('notifSettingsBody'),
                            style: const TextStyle(
                                fontSize: 16, color: Color(0xFF4B4B4B))),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: DuoButton.primary(
                            label: tr('inboxEnableButton').toUpperCase(),
                            onPressed: _enableNotifications,
                            icon: LucideIcons.bell,
                            fontSize: 17,
                          ),
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
                  _EntryTile(
                    entry: entry,
                    onTap: () => _openEntry(entry),
                  ),
              const SizedBox(height: 8),
              // Fila plana de acceso a Recordatorios (antes una
              // tarjeta con sombra): sin tarjeta, con línea #E5E5E5.
              const Divider(height: 1, thickness: 1, color: Color(0xFFE5E5E5)),
              ListTile(
                key: const Key('inboxOpenReminders'),
                contentPadding: EdgeInsets.zero,
                leading: const LucideIcon(LucideIcons.bellRing, size: 24),
                title: Text(tr('inboxOpenReminders'),
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4B4B4B))),
                trailing:
                    const Icon(Icons.chevron_right, color: Color(0xFFAFAFAF)),
                onTap: () => widget.onOpenScreen('reminder'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Una entrada de la bandeja (diseño Duolingo §3.15): fila plana,
/// sin tarjeta y sin sombra — icono en su círculo tintado, flecha
/// a la derecha y hora en gris pequeño, separada por una línea
/// #E5E5E5. Sin leer: título en negrita y puntito del color del
/// tipo; leída: atenuada (título normal, cuerpo más apagado).
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
      InboxKind.support => (LucideIcons.messageCircle, const Color(0xFF00C2A8)),
      InboxKind.friendRequest => (
          LucideIcons.userRound,
          const Color(0xFF00C2A8)
        ),
    };
    final unread = !entry.read;
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
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
                    child: LucideIcon(icon, size: 24, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.w500,
                            color: const Color(0xFF4B4B4B),
                          ),
                        ),
                        if (entry.body.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            entry.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
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
        const Divider(height: 1, thickness: 1, color: Color(0xFFE5E5E5)),
      ],
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

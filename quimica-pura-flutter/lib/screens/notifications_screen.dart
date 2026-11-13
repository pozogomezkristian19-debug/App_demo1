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
import '../services/accent.dart';

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
      case InboxKind.duel:
        // Duelo (reto o resultado): se juega en Amigos, sección
        // "Mis duelos abiertos".
        Navigator.of(context).pop();
        widget.onOpenScreen('friends');
      case InboxKind.announcement:
        // Aviso del admin: la bandeja YA es su destino; solo se
        // marca como leída.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('inboxTitle'))),
      body: ValueListenableBuilder<List<InboxEntry>>(
        valueListenable: NotificationInbox.entriesNotifier,
        builder: (context, entries, _) {
          final scheme = Theme.of(context).colorScheme;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!_notifEnabled) ...[
                // Diseño Duolingo §3.15: fila plana, radio 16, sin
                // sombra y SIN borde (Kristian, 2026-11-13: el borde
                // blanco de las tarjetas de la bandeja fuera, en
                // ambos temas). La tarjeta se lee por el relleno
                // (surfaceContainerHighest) contra el fondo.
                Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('notifSettingsTitle'),
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? scheme.onSurface
                                  : const Color(0xFF4B4B4B)),
                        ),
                        const SizedBox(height: 6),
                        Text(tr('notifSettingsBody'),
                            style: TextStyle(
                                fontSize: 16,
                                color: isDark
                                    ? scheme.onSurface.withValues(alpha: 0.85)
                                    : const Color(0xFF4B4B4B))),
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
              // Acceso a Recordatorios (seguimiento 7.2): tarjeta
              // como las entradas, sin líneas divisorias.
              _InboxLinkCard(
                onTap: () => widget.onOpenScreen('reminder'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Una entrada de la bandeja (seguimiento 7.2): tarjeta redondeada
/// (radio 16, sin borde y sin sombra borrosa), como el resto de la
/// app — sin líneas divisorias, que se veían rústicas. El borde
/// blanco se quitó por pedido de Kristian (2026-11-13): la tarjeta
/// se lee por el relleno (surfaceContainerHighest) contra el fondo,
/// en ambos temas. Sin leer: título en negrita y puntito del color
/// del tipo; leída: atenuada (título normal, cuerpo más apagado).
class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.onTap});

  final InboxEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (entry.kind) {
      InboxKind.update => (LucideIcons.download, AppAccent.primary),
      InboxKind.reminder => (LucideIcons.bell, const Color(0xFFF59E0B)),
      InboxKind.achievement => (LucideIcons.trophy, const Color(0xFF8B5CF6)),
      InboxKind.streak => (LucideIcons.flame, const Color(0xFFF97316)),
      InboxKind.support => (LucideIcons.messageCircle, AppAccent.primary),
      InboxKind.friendRequest => (LucideIcons.userRound, AppAccent.primary),
      InboxKind.duel => (LucideIcons.trophy, AppAccent.primary),
      InboxKind.announcement => (LucideIcons.bell, AppAccent.primary),
    };
    final unread = !entry.read;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                          // onSurface del tema (no el gris fijo
                          // #4B4B4B): el título va sobre el fondo de
                          // la bandeja, oscuro en modo oscuro.
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
    );
  }
}

/// Enlace a "Configurar recordatorios" (seguimiento 7.2): la misma
/// tarjeta que las entradas, sin líneas divisorias.
class _InboxLinkCard extends StatelessWidget {
  const _InboxLinkCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('inboxOpenReminders'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              const LucideIcon(LucideIcons.bellRing, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(tr('inboxOpenReminders'),
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        // Color del tema (no el gris fijo #4B4B4B): en
                        // oscuro el gris sobre fondo oscuro no se leía.
                        color: scheme.onSurface)),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFAFAFAF)),
            ],
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

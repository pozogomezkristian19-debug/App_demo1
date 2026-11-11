// Recordatorio de estudio (v6): avisos REALES del sistema con
// flutter_local_notifications, a intervalos aleatorios siempre de más
// de 1 hora entre uno y otro (61-180 min), con mensajes que rotan.
// Al activarlo se pide el permiso de notificaciones con el diálogo
// del sistema DIRECTO (Android 13+); si no se da, los avisos no
// llegan. El botón de prueba manda un aviso ahora mismo, para
// comprobar que funciona en el teléfono.
//
// Fix5, punto 1: el interruptor refleja el permiso REAL (si se
// revoca en Ajustes, queda apagado aunque la preferencia guardada
// diga que sí) y la pantalla muestra el estado del permiso
// (concedido/denegado) junto al próximo aviso. Al concederse el
// permiso, enable() dispara UNA notificación inmediata de
// confirmación para que se VEA que funciona.
//
// Lo que NO se puede comprobar aquí: que el aviso llegue con la app
// cerrada depende del permiso y de que el sistema no mate la app en
// segundo plano; eso hay que confirmarlo en el teléfono.

import 'package:flutter/material.dart';
import '../widgets/lucide_icons.dart';

import '../services/localization.dart';
import '../services/notification_service.dart';
import '../services/user_prefs.dart';
import '../widgets/notification_settings_dialog.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});
  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen>
    with WidgetsBindingObserver {
  var _busy = false;

  /// El usuario fue a Ajustes a conceder el permiso: al volver se
  /// vuelve a comprobar y, si ya está dado, se activan los
  /// recordatorios (fix4, punto 3).
  var _waitingForPermission = false;

  /// Estado REAL del permiso (fix5, punto 1): null mientras no se ha
  /// comprobado. El interruptor refleja la realidad: si no hay
  /// permiso, queda apagado aunque la preferencia guardada diga que
  /// sí (p. ej. permiso revocado en Ajustes).
  bool? _granted;

  late Future<DateTime?> _nextFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshNext();
    _refreshPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_waitingForPermission) {
      _waitingForPermission = false;
      _recheckPermission();
    }
    // Aunque no se viniera de Ajustes, el permiso puede haber
    // cambiado fuera: se vuelve a comprobar siempre (fix5).
    _refreshPermission();
  }

  /// Comprueba el permiso de verdad y actualiza la pantalla. Si los
  /// recordatorios estaban encendidos y el permiso se revocó en
  /// Ajustes, se apagan (se borra el próximo aviso): el interruptor
  /// no puede seguir en ON si ningún aviso puede llegar. El próximo
  /// aviso solo se relee cuando se apagó (si no, se invalidaría el
  /// FutureBuilder y la fila desaparecería hasta el siguiente
  /// frame).
  Future<void> _refreshPermission() async {
    final granted = await NotificationService.isPermissionGranted;
    if (!mounted) return;
    var disabled = false;
    if (UserPrefs.reminderOn && !granted) {
      await NotificationService.disable();
      if (!mounted) return;
      disabled = true;
    }
    setState(() {
      _granted = granted;
      if (disabled) _refreshNext();
    });
  }

  Future<void> _recheckPermission() async {
    final granted = await NotificationService.isPermissionGranted;
    if (!granted || !mounted) return;
    final ok = await NotificationService.enable();
    if (!mounted) return;
    setState(() {
      _granted = true;
      _refreshNext();
    });
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('notifOn'))),
      );
    }
  }

  void _refreshNext() {
    _nextFuture = NotificationService.nextNotificationTime();
  }

  @override
  Widget build(BuildContext context) {
    final on = UserPrefs.reminderOn;
    // El interruptor refleja la realidad (fix5): sin permiso,
    // apagado. Mientras no se ha comprobado (_granted null), se
    // muestra la preferencia guardada.
    final effectiveOn = on && (_granted ?? true);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('notifTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr('notifExplain')),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text(effectiveOn ? tr('notifOn') : tr('notifOff')),
            value: effectiveOn,
            onChanged: _busy
                ? null
                : (v) async {
                    setState(() => _busy = true);
                    var ok = true;
                    if (v) {
                      ok = await NotificationService.enable();
                    } else {
                      await NotificationService.disable();
                    }
                    if (!mounted) return;
                    setState(() {
                      _busy = false;
                      // Al activar, el permiso queda como enable()
                      // lo dejó (concedido o denegado): la fila de
                      // estado se actualiza en el acto (fix5).
                      if (v) _granted = ok;
                      // Al activar se programa la tanda: releer el
                      // próximo aviso; al apagar se borra.
                      _refreshNext();
                    });
                    // Sin permiso no hay nada que activar: en vez del
                    // toast, el diálogo con "Ir a Ajustes" (fix4,
                    // punto 3). El interruptor queda apagado hasta que
                    // el permiso se conceda en Ajustes.
                    if (v && !ok) {
                      final went =
                          await showNotificationSettingsDialog(context);
                      if (went && mounted) _waitingForPermission = true;
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text(v ? tr('notifOn') : tr('notifOff')),
                      ),
                    );
                  },
          ),
          const SizedBox(height: 12),
          // Estado REAL del permiso (fix5, punto 1): que se vea si
          // los avisos pueden llegar o no, junto al próximo aviso.
          if (_granted != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_granted! ? scheme.primary : Colors.orange)
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LucideIcon(
                      LucideIcons.bellRing,
                      size: 18,
                      color:
                          _granted! ? scheme.primary : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr(_granted!
                            ? 'notifPermGranted'
                            : 'notifPermDenied'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Próximo aviso programado (fix3): para que se vea que el
          // recordatorio de verdad está armado y a qué hora llega.
          // Solo con recordatorios activos y un aviso aún futuro;
          // si no hay ninguno no se muestra nada (sin texto vacío).
          // La clave es necesaria (fix5): la fila de estado del
          // permiso se inserta ANTES que este FutureBuilder cuando
          // se conoce el permiso; sin clave, al insertarse el
          // FutureBuilder se remontaba (perdía su snapshot) y la
          // fila del próximo aviso desaparecía un frame.
          FutureBuilder<DateTime?>(
            key: const ValueKey('nextReminder'),
            future: _nextFuture,
            builder: (context, snapshot) {
              final at = snapshot.data;
              if (!effectiveOn || at == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LucideIcon(
                        LucideIcons.bellRing,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nextReminderLabel(AppLang.code),
                              style: TextStyle(
                                color: scheme.onSurface
                                    .withValues(alpha: 0.65),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatNextReminder(at),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          ElevatedButton.icon(
            onPressed: () async {
              // El permiso se pide DIRECTO (fix5): requestPermission()
              // es la respuesta autorizada (sin diálogo si ya está
              // dado) y no depende de isPermissionGranted, que solo
              // consulta. Pedirlo aquí evita el "enviado" mentiroso
              // si la consulta dijera que sí con el permiso negado.
              final granted =
                  await NotificationService.requestPermission();
              if (!mounted) return;
              setState(() => _granted = granted);
              if (!granted) {
                final went = await showNotificationSettingsDialog(context);
                if (went && mounted) _waitingForPermission = true;
                return;
              }
              await NotificationService.sendTest();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('notifSent'))),
              );
            },
            icon: const LucideIcon(LucideIcons.bellRing),
            label: Text(tr('notifTest')),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nota: si el teléfono lleva mucho tiempo con la app cerrada, el sistema puede retrasar los avisos. Ábrela de vez en cuando para que la racha no se pierda.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

/// "Próximo aviso" en el idioma de la app. Se traduce aquí (como los
/// mensajes de NotificationService) porque localization.dart está
/// cerrado en esta ronda.
String _nextReminderLabel(String lang) => switch (lang) {
      'en' => 'Next reminder',
      'fr' => 'Prochain rappel',
      'it' => 'Prossimo promemoria',
      'pt' => 'Próximo lembrete',
      'ru' => 'Следующее напоминание',
      _ => 'Próximo aviso',
    };

String _todayWord(String lang) => switch (lang) {
      'en' => 'today',
      'fr' => "aujourd'hui",
      'it' => 'oggi',
      'pt' => 'hoje',
      'ru' => 'сегодня',
      _ => 'hoy',
    };

String _tomorrowWord(String lang) => switch (lang) {
      'en' => 'tomorrow',
      'fr' => 'demain',
      'it' => 'domani',
      'pt' => 'amanhã',
      'ru' => 'завтра',
      _ => 'mañana',
    };

/// Fecha y hora del próximo aviso: "hoy, 18:30", "mañana, 09:15" o
/// "12/11 · 18:30" si cae más lejos (en la práctica, los 3 avisos de
/// la tanda llegan el mismo día o al siguiente).
String _formatNextReminder(DateTime at) {
  final lang = AppLang.code;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final time =
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
  final diff = day.difference(today).inDays;
  if (diff == 0) return '${_todayWord(lang)}, $time';
  if (diff == 1) return '${_tomorrowWord(lang)}, $time';
  return '${day.day}/${day.month} · $time';
}

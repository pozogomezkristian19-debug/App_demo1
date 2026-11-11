// Recordatorio de estudio (v6): avisos REALES del sistema con
// flutter_local_notifications, a intervalos aleatorios siempre de más
// de 1 hora entre uno y otro (61-180 min), con mensajes que rotan.
// Al activarlo se pide el permiso de notificaciones (Android 13+);
// si no se da, los avisos no llegan. El botón de prueba manda un
// aviso ahora mismo, para comprobar que funciona en el teléfono.
//
// Lo que NO se puede comprobar aquí: que el aviso llegue con la app
// cerrada depende del permiso y de que el sistema no mate la app en
// segundo plano; eso hay que confirmarlo en el teléfono.

import 'package:flutter/material.dart';
import '../widgets/lucide_icons.dart';

import '../services/localization.dart';
import '../services/notification_service.dart';
import '../services/user_prefs.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});
  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  var _busy = false;
  late Future<DateTime?> _nextFuture;

  @override
  void initState() {
    super.initState();
    _refreshNext();
  }

  void _refreshNext() {
    _nextFuture = NotificationService.nextNotificationTime();
  }

  @override
  Widget build(BuildContext context) {
    final on = UserPrefs.reminderOn;
    return Scaffold(
      appBar: AppBar(title: Text(tr('notifTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr('notifExplain')),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text(on ? tr('notifOn') : tr('notifOff')),
            value: on,
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
                      // Al activar se programa la tanda: releer el
                      // próximo aviso; al apagar se borra.
                      _refreshNext();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(v
                            ? (ok ? tr('notifOn') : tr('notifNeedPermission'))
                            : tr('notifOff')),
                      ),
                    );
                  },
          ),
          const SizedBox(height: 12),
          // Próximo aviso programado (fix3): para que se vea que el
          // recordatorio de verdad está armado y a qué hora llega.
          // Solo con recordatorios activos y un aviso aún futuro;
          // si no hay ninguno no se muestra nada (sin texto vacío).
          FutureBuilder<DateTime?>(
            future: _nextFuture,
            builder: (context, snapshot) {
              final at = snapshot.data;
              if (!on || at == null) return const SizedBox.shrink();
              final scheme = Theme.of(context).colorScheme;
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

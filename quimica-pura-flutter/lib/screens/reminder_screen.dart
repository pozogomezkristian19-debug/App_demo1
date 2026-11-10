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
                    setState(() => _busy = false);
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

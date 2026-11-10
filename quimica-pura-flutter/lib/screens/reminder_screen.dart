// Recordatorio de estudio (v5): aviso diario para practicar, a la
// hora que elija el usuario. Se guarda en el teléfono.
//
// Nota honesta: las notificaciones del sistema necesitan el plugin
// flutter_local_notifications, que no está disponible sin internet en
// este entorno de construcción. Por eso el recordatorio es un ajuste
// dentro de la app: cuando se abre la app después de la hora elegida y
// aún no se ha practicado hoy, Niveles muestra una tarjeta que lo
// recuerda. Sin plugin, sin permisos extra y sin internet.

import 'package:flutter/material.dart';

import '../services/localization.dart';
import '../services/user_prefs.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});
  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  @override
  Widget build(BuildContext context) {
    final on = UserPrefs.reminderOn;
    final time = TimeOfDay(
        hour: UserPrefs.reminderHour, minute: UserPrefs.reminderMinute);
    return Scaffold(
      appBar: AppBar(title: Text(tr('menuReminder'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'La app te recuerda practicar cada día a la hora que elijas. Cuando abras la app después de esa hora y aún no hayas practicado, verás el aviso en Niveles.',
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Recordatorio diario'),
            subtitle: Text(on ? 'Activado' : 'Desactivado'),
            value: on,
            onChanged: (v) async {
              await UserPrefs.saveReminder(
                  v, UserPrefs.reminderHour, UserPrefs.reminderMinute);
              setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Hora del recordatorio'),
            subtitle: Text(time.format(context)),
            trailing: const Icon(Icons.chevron_right),
            onTap: on
                ? () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: time,
                    );
                    if (picked == null) return;
                    await UserPrefs.saveReminder(
                        true, picked.hour, picked.minute);
                    setState(() {});
                  }
                : null,
          ),
          const SizedBox(height: 12),
          const Text(
            'Consejo: elige una hora en la que siempre tengas el teléfono a mano, por ejemplo después de cenar.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

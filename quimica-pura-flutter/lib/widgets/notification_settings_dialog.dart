// Diálogo "falta el permiso de notificaciones" (fix4, punto 3):
// sale cuando activar los recordatorios (o probar un aviso) falla
// porque el permiso está denegado: explica dónde se activa y ofrece
// abrir los ajustes de notificaciones de la app. El botón para
// cerrar es "Cerrar", no "Ahora no" (Kristian quitó el "Ahora no"
// del flujo de notificaciones, 2026-11-10 20:43).

import 'package:flutter/material.dart';

import '../services/localization.dart';
import '../services/notification_service.dart';

/// Muestra el diálogo de permiso denegado. Devuelve true si el
/// usuario tocó "Ir a Ajustes" (y se intentó abrir los ajustes de
/// la app).
Future<bool> showNotificationSettingsDialog(BuildContext context) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(tr('notifSettingsTitle')),
      content: Text(tr('notifSettingsBody')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(tr('notifSettingsClose')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(tr('notifGoSettings')),
        ),
      ],
    ),
  );
  if (go != true) return false;
  await NotificationService.openNotificationSettings();
  return true;
}

// Diálogo "falta el permiso de notificaciones" (fix4, punto 3):
// sale cuando activar los recordatorios (o probar un aviso) falla
// porque el permiso está denegado: ofrece abrir los ajustes de
// notificaciones de la app DIRECTO (un toque, sin explicar la ruta
// a mano: el texto es corto, fix5, punto 1). El botón para cerrar
// es "Cerrar", no "Ahora no" (Kristian quitó el "Ahora no" del
// flujo de notificaciones, 2026-11-10 20:43).
//
// Ronda #6, punto 2: en Xiaomi/MIUI, además del permiso, el ahorro
// de batería y el inicio automático pueden bloquear los avisos
// aunque el permiso esté dado. Por eso el diálogo añade un párrafo
// corto con los pasos (Ajustes → Apps → Quemia → Ahorro de batería
// → Sin restricciones, y Seguridad → Inicio automático). El texto
// se traduce aquí (como en reminder_screen.dart), sin tocar
// localization.dart.

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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('notifSettingsBody')),
          const SizedBox(height: 10),
          Text(
            _xiaomiBatterySteps(AppLang.code),
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
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

/// Pasos de batería / inicio automático para Xiaomi (ronda #6,
/// punto 2): en MIUI el ahorro de batería agresivo y el inicio
/// automático denegado pueden bloquear los avisos aunque el permiso
/// esté concedido. Sin slugs ni rutas inventadas: son los nombres
/// de los ajustes del sistema.
String _xiaomiBatterySteps(String lang) => switch (lang) {
      'en' =>
        'On Xiaomi, battery saving can also block reminders: Settings → Apps → Quemia → Battery saver → No restrictions. And in the Security app → Autostart → allow Quemia.',
      'fr' =>
        'Sur Xiaomi, l’économie de batterie peut aussi bloquer les rappels : Réglages → Applis → Quemia → Batterie → Sans restriction. Et dans l’appli Sécurité → Démarrage auto → autorise Quemia.',
      'it' =>
        'Su Xiaomi, il risparmio energetico può bloccare i promemoria: Impostazioni → App → Quemia → Batteria → Senza restrizioni. E nell’app Sicurezza → Avvio automatico → consenti Quemia.',
      'pt' =>
        'Na Xiaomi, a economia de bateria também pode bloquear os lembretes: Ajustes → Apps → Quemia → Economia de bateria → Sem restrições. E no app Segurança → Início automático → permita o Quemia.',
      'ru' =>
        'На Xiaomi экономия батареи тоже может блокировать напоминания: Настройки → Приложения → Quemia → Батарея → Без ограничений. И в приложении «Безопасность» → Автозапуск → разрешите Quemia.',
      _ =>
        'En Xiaomi, además del permiso, la batería puede bloquear los avisos: Ajustes → Apps → Quemia → Ahorro de batería → Sin restricciones. Y en la app Seguridad → Inicio automático → permite Quemia.',
    };

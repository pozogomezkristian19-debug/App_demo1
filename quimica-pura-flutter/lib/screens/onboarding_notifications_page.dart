// Pantalla de permiso de notificaciones dentro del onboarding
// (fix3, punto 9, item 1): sale después de la pantalla del nombre y
// antes de la del idioma ("Finalizar").
//
// Antes la app NUNCA pedía el permiso al instalarse: solo se pedía
// dentro de la pantalla de Recordatorio, que casi nadie abre, y por
// eso a Kristian casi nunca le llegaba ningún aviso. Aquí se explica
// para qué sirven los recordatorios (que la racha no se pierda) y se
// pide el permiso con el botón "Activar recordatorios".
//
// Si lo niega (denegar el diálogo del sistema), los recordatorios
// quedan apagados sin romper nada: se avanza igual al siguiente paso
// y se pueden activar luego desde Cuenta › Recordatorio, cuyo
// interruptor pide el permiso y programa (ver
// screens/reminder_screen.dart). Solo hay un botón: "Activar
// recordatorios" (el "Ahora no" se quitó a petición de Kristian,
// 2026-11-10 20:43).

import 'package:flutter/material.dart';

import '../services/localization.dart';
import '../services/notification_service.dart';
import '../widgets/lucide_icons.dart';
import '../widgets/notification_settings_dialog.dart';

class OnboardingNotificationsPage extends StatefulWidget {
  const OnboardingNotificationsPage({super.key, required this.onNext});

  /// Avanza a la siguiente pantalla del onboarding.
  final VoidCallback onNext;

  @override
  State<OnboardingNotificationsPage> createState() =>
      _OnboardingNotificationsPageState();
}

class _OnboardingNotificationsPageState
    extends State<OnboardingNotificationsPage> {
  var _busy = false;

  /// Pide el permiso y programa los recordatorios; avance lo mismo
  /// si se niega (quedan apagados, se pueden activar luego).
  Future<void> _enable() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await NotificationService.enable();
    if (!mounted) return;
    setState(() => _busy = false);
    // Permiso denegado: el diálogo con "Ir a Ajustes" (fix4, punto
    // 3); se avanza igual al siguiente paso y los recordatorios
    // quedan apagados, para activarlos luego desde Cuenta.
    if (!ok) {
      await showNotificationSettingsDialog(context);
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF14B8A6);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: teal.withValues(alpha: 0.18),
              child:
                  const LucideIcon(LucideIcons.bellRing, size: 46, color: teal),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            tr('obNotifTitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            tr('obNotifBody'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, height: 1.5),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _enable,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(tr('obNotifEnable'),
                  style: const TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}

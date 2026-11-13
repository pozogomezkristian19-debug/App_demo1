// Pantalla de permiso de notificaciones dentro del onboarding
// (fix3, punto 9, item 1): sale después de la pantalla del nombre y
// antes de la del idioma ("Finalizar").
//
// Antes la app NUNCA pedía el permiso al instalarse: solo se pedía
// dentro de la pantalla de Recordatorio, que casi nadie abre, y por
// eso a Kristian casi nunca le llegaba ningún aviso. Aquí se pide el
// permiso con el botón "Activar recordatorios", que dispara el
// diálogo del sistema DIRECTO (fix5, punto 1): sin pantallas de
// explicación antes y sin abrir los Ajustes de alarmas exactas (eso
// era lo que parecía "una explicación de cómo activar").
//
// Si lo niega (denegar el diálogo del sistema), los recordatorios
// quedan apagados sin romper nada: se avanza igual al siguiente paso
// y se pueden activar luego desde Cuenta › Recordatorio, cuyo
// interruptor pide el permiso y programa (ver
// screens/reminder_screen.dart). Solo hay un botón: "Activar
// recordatorios" (el "Ahora no" se quitó a petición de Kristian,
// 2026-11-10 20:43).
//
// Si el permiso está denegado de forma permanente, el sistema ya no
// muestra su diálogo: el único camino es "Ir a Ajustes", de un
// toque, y al volver se re-comprueba y se activa solo (fix5).

import 'package:flutter/material.dart';

import '../services/localization.dart';
import '../services/notification_service.dart';
import '../widgets/duo_button.dart';
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
    extends State<OnboardingNotificationsPage> with WidgetsBindingObserver {
  var _busy = false;

  /// El usuario tocó "Ir a Ajustes": al volver se vuelve a
  /// comprobar el permiso y, si ya está dado, se activan los
  /// recordatorios (fix5, punto 1; en Recordatorios ya existía).
  var _waitingForPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForPermission) {
      _waitingForPermission = false;
      _recheckPermission();
    }
  }

  /// Al volver de Ajustes con el permiso ya concedido: activar los
  /// recordatorios (programa la tanda y dispara la confirmación
  /// inmediata) y avanzar al idioma. Si no se concedió, se sigue
  /// desde esta pantalla (el botón vuelve a pedir el permiso).
  Future<void> _recheckPermission() async {
    final granted = await NotificationService.isPermissionGranted;
    if (!granted || !mounted) return;
    final ok = await NotificationService.enable();
    if (!mounted) return;
    if (ok) _advance();
  }

  /// Ya se avanzó a la siguiente pantalla (no avanzar dos veces).
  var _advanced = false;

  void _advance() {
    if (_advanced) return;
    _advanced = true;
    widget.onNext();
  }

  /// Pide el permiso con el diálogo del sistema DIRECTO y programa
  /// los recordatorios; se avanza lo mismo si se niega (quedan
  /// apagados, se pueden activar luego).
  Future<void> _enable() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await NotificationService.enable();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _advance();
      return;
    }
    // Permiso denegado (de forma permanente el sistema ya no muestra
    // su diálogo): el ÚNICO camino es Ajustes, de un toque (fix5).
    final went = await showNotificationSettingsDialog(context);
    if (!mounted) return;
    if (went) {
      // NO se avanza todavía: si se avanzara, el PageView destruye
      // esta página y el re-chequeo al volver de Ajustes no podría
      // dispararse (la página ya no estaría viva). Al volver con el
      // permiso dado se activa solo y se avanza; si no se concedió,
      // se sigue desde aquí (el botón vuelve a pedirlo, y "Cerrar"
      // en el diálogo avanza igual).
      _waitingForPermission = true;
    } else {
      _advance();
    }
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF14B8A6);
    // Contraste (zona E): título y cuerpo con el on-surface del
    // tema (#4B4B4B en claro, casi blanco en oscuro); el #4B4B4B y
    // el #777777 fijos eran ilegibles sobre el fondo oscuro.
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = scheme.onSurface;
    final bodyColor = isDark
        ? scheme.onSurface.withValues(alpha: 0.75)
        : const Color(0xFF777777);
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
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: ink),
          ),
          const SizedBox(height: 12),
          Text(
            tr('obNotifBody'),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16, height: 1.5, color: bodyColor),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            // Botón primario Duolingo: sólido teal + labio.
            child: DuoButton.primary(
              label: tr('obNotifEnable').toUpperCase(),
              onPressed: _busy ? null : _enable,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }
}

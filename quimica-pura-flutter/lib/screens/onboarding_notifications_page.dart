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
import '../widgets/icon_animations.dart';
import '../widgets/notification_settings_dialog.dart';
import '../widgets/play_once_lottie.dart';

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
    // Contraste (zona E): título y cuerpo con el on-surface del
    // tema (#4B4B4B en claro, casi blanco en oscuro); el #4B4B4B y
    // el #777777 fijos eran ilegibles sobre el fondo oscuro.
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = scheme.onSurface;
    final bodyColor = isDark
        ? scheme.onSurface.withValues(alpha: 0.75)
        : const Color(0xFF777777);
    // Botón ABAJO como en el resto del inicio (Quemia 7.7, Kristian
    // 2026-11-13: el botón quedaba a mitad de pantalla mientras en
    // las demás pantallas va pegado abajo, como Duolingo).
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            // Contenido CENTRADO en vertical (Quemia 7.7, Kristian
            // 2026-11-13: el botón abajo dejaba un hueco vacío enorme
            // en el medio; como en Duolingo, la campana y el texto
            // van en el centro y el botón abajo).
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    // Entrada suave (Quemia 7.7, animación simple como el
                    // vídeo de Duolingo): la campana y el título aparecen
                    // con fundido + subida.
                    //
                    // Campana (Lottie, Kristian 2026-11-14: "en la
                    // de activar notificaciones pon este"; 2026-11-14
                    // mandó la campana nueva "bell-notification-icon"
                    // y pidió que suene una sola vez al abrir la
                    // página y luego quede quieta): la animación
                    // "notifications" de LottieFiles en vez de la
                    // campana dibujada con _BellRing (borrado, ya no
                    // se usa). La campana va sobre un círculo
                    // blanco: el modelo trae un cuadro claro detrás
                    // y con el círculo el fondo es el mismo en claro
                    // y en oscuro. El Lottie mide 130 dentro del
                    // círculo de 200 para que ese cuadro no asome
                    // por las esquinas.
                    FadeSlideIn(
                      child: Center(
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: PlayOnceLottie(
                              asset: 'assets/notifications.json',
                              width: 130,
                              height: 130,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 80),
                      child: Text(
                        tr('obNotifTitle'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: ink),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 140),
                      child: Text(
                        tr('obNotifBody'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 16, height: 1.5, color: bodyColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
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

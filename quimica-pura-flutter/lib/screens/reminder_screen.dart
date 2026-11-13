// Recordatorio de estudio (v6): avisos REALES del sistema con
// flutter_local_notifications, a intervalos aleatorios siempre de más
// de 1 hora entre uno y otro (61-180 min), con mensajes que rotan.
// Al activarlo se pide el permiso de notificaciones con el diálogo
// del sistema DIRECTO (Android 13+); si no se da, los avisos no
// llegan. El botón de prueba manda un aviso ahora mismo, para
// comprobar que funciona en el teléfono.
//
// Pantalla SIMPLIFICADA (simplificación ronda #7, 6.4): solo
// desactivar y activar. Quedan la introducción, el interruptor y el
// botón de prueba. El diagnóstico (permiso, canales, próximo y
// último aviso, batería) se quitó de la pantalla: es detalle para
// programadores. El comportamiento que arregló la 6.4 sigue intacto:
// la prueba es honesta (sendTest devuelve bool), usa su propio
// canal 'quemia_prueba_avisos', el aviso pendiente se manda solo al
// volver de Ajustes con el permiso concedido, el canal bloqueado se
// avisa con su mensaje claro, y un init() que falle no mata la
// prueba. Los chequeos de canal siguen en el servicio y alimentan
// los mensajes del botón.

import 'package:flutter/material.dart';
import '../widgets/lucide_icons.dart';

import '../services/localization.dart';
import '../services/notification_service.dart';
import '../services/user_prefs.dart';
import '../widgets/duo_button.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  /// Ajustes, se apagan: el interruptor no puede seguir en ON si
  /// ningún aviso puede llegar.
  Future<void> _refreshPermission() async {
    final granted = await NotificationService.isPermissionGranted;
    if (!mounted) return;
    if (UserPrefs.reminderOn && !granted) {
      await NotificationService.disable();
      if (!mounted) return;
    }
    setState(() => _granted = granted);
  }

  /// Al volver de Ajustes con el permiso ya concedido, SOLO se
  /// re-activa lo que el usuario pidió de verdad (ronda #7):
  ///  - la confirmación (el interruptor) llama a enable() SOLO si
  ///    el que pidió ir a Ajustes fue el interruptor;
  ///  - la prueba (el botón) se manda SOLO si la pidió el botón.
  /// Antes, _recheckPermission() llamaba a enable() siempre que
  /// había permiso y _waitingForPermission lo ponían TAMBIÉN el
  /// botón de prueba: si el usuario solo tocó la prueba (con los
  /// recordatorios APAGADOS) y volvió de Ajustes, enable() le
  /// ENCENDÍA los recordatorios sin pedirlos.
  /// Si no hay nada pendiente, solo refresca el permiso como hoy.
  /// Los flags pendientes se descartan si al volver el permiso
  /// sigue denegado: la petición de esa vuelta fracasó y hay que
  /// volver a tocar el botón o el interruptor para reintentarla.
  Future<void> _recheckPermission() async {
    final granted = await NotificationService.isPermissionGranted;
    if (!mounted) return;
    if (!granted) {
      NotificationService.takePendingConfirmation();
      NotificationService.takePendingTest();
      return;
    }
    if (NotificationService.takePendingConfirmation()) {
      final ok = await NotificationService.enable();
      if (!mounted) return;
      setState(() => _granted = true);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('notifOn'))),
        );
      }
    } else {
      setState(() => _granted = true);
    }
    if (NotificationService.takePendingTest()) {
      // La prueba pendiente también es TIPADA (Zona G, regla
      // general): si al volver de Ajustes el aviso sigue sin
      // poder enviarse, la pantalla dice LA CAUSA en vez de
      // callarse (sin diálogo: el usuario acaba de venir de
      // Ajustes, volver a abrirlo sería molesto).
      final result = await NotificationService.sendTestDetailed();
      if (!mounted) return;
      switch (result.outcome) {
        case NotificationTestOutcome.sent:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('notifSent'))),
          );
        case NotificationTestOutcome.permissionDenied:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('notifTestFailedPerm'))),
          );
        case NotificationTestOutcome.channelBlocked:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('notifTestFailedChannel'))),
          );
        case NotificationTestOutcome.pluginError:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr('notifTestFailedDetail').replaceFirst(
                  '{detail}',
                  result.detail ?? tr('notifTestFailedSystem'),
                ),
              ),
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = UserPrefs.reminderOn;
    // El interruptor refleja la realidad (fix5): sin permiso,
    // apagado. Mientras no se ha comprobado (_granted null), se
    // muestra la preferencia guardada.
    final effectiveOn = on && (_granted ?? true);
    return Scaffold(
      appBar: AppBar(title: Text(tr('notifTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Contraste (Zona G): el #4B4B4B fijo era gris apagado
          // sobre el fondo oscuro (ilegible); el onSurface del tema
          // es #4B4B4B en claro y casi blanco en oscuro, como en la
          // página de permiso del onboarding.
          Text(tr('notifExplain'),
              style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 16),
          // El interruptor vive en una fila plana con su línea
          // #E5E5E5 (antes una tarjeta blanca con sombra). El
          // interruptor teal ya es correcto y se queda.
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
                      // lo dejó (concedido o denegado).
                      if (v) _granted = ok;
                    });
                    // Sin permiso no hay nada que activar: en vez del
                    // toast, el diálogo con "Ir a Ajustes" (fix4,
                    // punto 3). El interruptor queda apagado hasta que
                    // el permiso se conceda en Ajustes.
                    if (v && !ok) {
                      // Ronda #7: el usuario pidió activar los
                      // recordatorios: se anota ANTES del diálogo que
                      // hay una confirmación pendiente, para que al
                      // volver de Ajustes con el permiso concedido
                      // se re-activen solos. Si no fue a Ajustes, el
                      // pendiente se descarta: no queda nada que
                      // activar en una vuelta posterior que el
                      // usuario no haya pedido.
                      NotificationService.markConfirmationPending();
                      final went =
                          await showNotificationSettingsDialog(context);
                      if (went && mounted) {
                        _waitingForPermission = true;
                      } else {
                        NotificationService.takePendingConfirmation();
                      }
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(v ? tr('notifOn') : tr('notifOff')),
                      ),
                    );
                  },
          ),
          const Divider(height: 25, thickness: 1, color: Color(0xFFE5E5E5)),
          const SizedBox(height: 12),
          // Botón primario Duolingo: sólido teal + labio.
          DuoButton.primary(
            label: tr('notifTest').toUpperCase(),
            icon: LucideIcons.bellRing,
            fontSize: 17,
            onPressed: () async {
              // El permiso se pide DIRECTO (fix5): requestPermission()
              // es la respuesta autorizada (sin diálogo si ya está
              // dado) y no depende de isPermissionGranted, que solo
              // consulta. Pedirlo aquí evita el "enviado" mentiroso
              // si la consulta dijera que sí con el permiso negado.
              //
              // Ronda #7, flujo honesto (nunca "Aviso enviado"
              // cuando nada se envió):
              final granted = await NotificationService.requestPermission();
              if (!mounted) return;
              setState(() => _granted = granted);
              if (!granted) {
                // Se anota la prueba pendiente ANTES del diálogo:
                // si el usuario fue a Ajustes y vuelve con el
                // permiso concedido, el aviso se manda SOLO al
                // volver (ver _recheckPermission). Si no fue, el
                // pendiente se descarta y se dice que falló.
                NotificationService.markTestPending();
                final went = await showNotificationSettingsDialog(context);
                if (went && mounted) {
                  _waitingForPermission = true;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('notifTestPending'))),
                  );
                } else if (mounted) {
                  NotificationService.takePendingTest();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('notifTestFailedPerm'))),
                  );
                }
                return;
              }
              // Permiso dado según el diálogo del sistema: la prueba
              // TIPADA (Zona G) vuelve a comprobar el permiso real y
              // el canal ANTES de enviar, y si el show() lanza dice
              // LA CAUSA, nunca el genérico "error del sistema":
              // denegado → Ajustes, canal bloqueado → Ajustes, otro
              // error → su texto real (Ajustes no lo arregla).
              final result =
                  await NotificationService.sendTestDetailed();
              if (!mounted) return;
              switch (result.outcome) {
                case NotificationTestOutcome.sent:
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('notifSent'))),
                  );
                case NotificationTestOutcome.permissionDenied:
                  // El permiso se perdió entre la petición y el envío
                  // (o el show() lo delató con SecurityException):
                  // mismo camino que denegado de entrada: prueba
                  // pendiente + diálogo de Ajustes.
                  NotificationService.markTestPending();
                  final went =
                      await showNotificationSettingsDialog(context);
                  if (went && mounted) {
                    _waitingForPermission = true;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('notifTestPending'))),
                    );
                  } else if (mounted) {
                    NotificationService.takePendingTest();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('notifTestFailedPerm'))),
                    );
                  }
                case NotificationTestOutcome.channelBlocked:
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('notifTestFailedChannel'))),
                  );
                  await showNotificationSettingsDialog(context);
                case NotificationTestOutcome.pluginError:
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        tr('notifTestFailedDetail').replaceFirst(
                          '{detail}',
                          result.detail ?? tr('notifTestFailedSystem'),
                        ),
                      ),
                    ),
                  );
              }
            },
          ),
        ],
      ),
    );
  }
}

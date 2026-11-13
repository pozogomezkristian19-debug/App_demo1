// Notificaciones locales REALES de Melli-Qui (v6, fix3 punto 9).
//
// El recordatorio viejo solo guardaba una hora y nunca avisaba. Esto
// programa notificaciones locales de verdad con
// flutter_local_notifications + timezone:
//  - llegan a intervalos ALEATORIOS, siempre con MÁS DE 1 HORA entre
//    una y otra (61-180 minutos), nunca en avalancha, EXCEPTO la
//    primera, que llega pronto (20-50 min) para que el usuario vea
//    que funciona y no crea que no avisa nunca;
//  - los mensajes rotan al azar (repaso, racha, repaso de tu tema
//    más débil), SIEMPRE con el nombre bonito del tema
//    ("Estequiometría y el mol"), nunca con el id interno
//    ("bach-estequiometria"); la pregunta del día se eliminó de la
//    app (ronda #6) y ya no sale en los mensajes.
//  - se programan 3 seguidas por delante, para que lleguen aunque la
//    app lleve días sin abrirse; al abrir la app (o al tocar una
//    notificación) se vuelve a programar la tanda;
//  - el ajuste (activado/apagado) y la hora de la última notificación
//    programada se guardan en el teléfono.
//  - cada aviso que se dispara queda también registrado en la bandeja
//    de Notificaciones (fix4, punto 8), por si el usuario no lo vio.
//
// Por qué antes casi no llegaban (la captura de las 7:00 es la única
// que llegó en horas):
//  1. Los recordatorios vienen APAGADOS y la app NUNCA pedía el
//     permiso al instalarse: solo se pedía dentro de la pantalla de
//     Recordatorio, que casi nadie abre. Ahora el onboarding tiene
//     una pantalla que pide el permiso (ver
//     screens/onboarding_notifications_page.dart).
//  2. Las alarmas se programaban como INEXACTAS
//     (inexactAllowWhileIdle): con Doze, Android las agrupa y las
//     puede retrasar HORAS. Ahora se piden alarmas EXACTAS
//     (SCHEDULE_EXACT_ALARM, declarado en AndroidManifest.xml):
//     si el permiso está dado, la alarma suena a su hora incluso
//     con Doze; si no, se vuelve a inexactas sin romper nada.
//  3. El icono pequeño era el logo a color: Android solo dibuja su
//     silueta en blanco y salía un CUADRADO NEGRO. Ahora el icono
//     pequeño es una campana blanca en PNG (res/drawable-*/ic_notif_bell.png
//     en las 5 densidades, protegido de la limpieza de recursos por
//     res/values/keep.xml con tools:keep="@drawable/ic_notif_bell";
//     el vector anterior se eliminó) y el icono grande es el
//     compañero del día.
//
// Límites que la app NO puede quitar: las alarmas programadas no
// sobreviven a un reinicio del teléfono (se reprograman al abrir la
// app); y en Xiaomi/MIUI, si el sistema mata la app en segundo plano
// o el ahorro de batería está en agresivo, los avisos pueden seguir
// retrasándose. Eso hay que confirmarlo en el teléfono.
//
// Qué está verificado y qué no: el código compila (flutter analyze) y
// la lógica de intervalos/mensajes tiene pruebas (test/
// notification_gap_test.dart, test/fix3_notifications_test.dart). Que
// la notificación aparezca en la barra del teléfono solo se puede
// confirmar en el teléfono: depende del permiso (Android 13+ lo pide
// al activar el recordatorio) y de que el sistema no mate la app en
// segundo plano.
//
// Ronda #5 (6.2), punto 1 — por qué "no se activan las
// notificaciones" (verificado en el código y en el fuente del plugin
// flutter_local_notifications 23.0.0):
//  1. REAL (la principal): enable() pedía las alarmas exactas con
//     requestExactAlarmsPermission() justo después del diálogo del
//     permiso. En Android 12+ ese método, si no están concedidas,
//     abre los Ajustes del sistema ("Alarmas y recordatorios", con
//     su interruptor) y no vuelve hasta que el usuario sale de
//     Ajustes. Eso es lo que Kristian veía como "una explicación de
//     cómo activar" en vez de una petición. Ahora ya NO se piden ni
//     se consultan: al programar la tanda se PRUEBAN las exactas
//     (el propio plugin lanza ExactAlarmPermissionException ANTES
//     de programar si no están concedidas, verificado en su
//     fuente) y _scheduleOne vuelve a inexactas solo (llegan tarde
//     con Doze, pero llegan). Sin abrir Ajustes, sin diálogo extra.
//     Si el usuario las concede luego en Ajustes, la siguiente
//     tanda las vuelve a probar y las usa.
//  2. REAL: denegación permanente. En Android 13+ el sistema, tras
//     dos negativas, ya NO muestra su diálogo: requestPermissions
//     devuelve denegado en el acto y la app solo puede ofrecer "Ir
//     a Ajustes". Kristian ya había negado en el onboarding de la
//     6.0/6.1, así que cada toque iba directo al diálogo de Ajustes
//     sin que el sistema le preguntara nada. No se puede forzar el
//     diálogo; el arreglo es que "Ir a Ajustes" sea de un toque, con
//     texto corto, y que al volver se re-compruebe y se active solo
//     (en Recordatorios ya existía; en el onboarding faltaba).
//  3. NO es la causa en el teléfono: init() no puede devolver false
//     sin que se haya pedido el permiso por un fallo suyo (la zona
//     horaria tiene tope de 3 s y try/catch, y scheduleNext / la
//     bandeja tragan sus errores). Pero SÍ había una contradicción
//     real en el código: con init() fallido, isPermissionGranted
//     devolvía true ("se asume que sí") mientras requestPermission()
//     devolvía false; y si requestNotificationsPermission() lanzaba
//     una excepción, requestPermission() devolvía true y enable()
//     guardaba los recordatorios como activos aunque ningún aviso
//     pudiera llegar. Ahora ambos devuelven false si no se pudo
//     comprobar o pedir el permiso.
//  4. REAL: nada confirmaba en el acto que funcionara. Al conceder
//     el permiso no salía ningún aviso, así que el usuario no tenía
//     forma de saber si estaba activo. Ahora enable() dispara UNA
//     notificación inmediata de confirmación ("Recordatorios
//     activados") y la pantalla de Recordatorios muestra el estado
//     REAL del permiso (concedido/denegado), no solo la preferencia
//     guardada.

// Ronda #6 (Quemia 6.3), punto 2 — por qué "las notificaciones
// nunca funcionaron", TAMPOCO en la 6.2 (verificado en el código y
// en el fuente del plugin flutter_local_notifications 23.0.0):
//
//  CAUSA PRINCIPAL (real, en AndroidManifest.xml): la app NO
//  declaraba los receivers que el plugin exige para mostrar
//  notificaciones PROGRAMADAS (README del plugin, sección
//  "AndroidManifest.xml setup", y su ejemplo): faltaban
//  ScheduledNotificationReceiver, ScheduledNotificationBootReceiver
//  y RECEIVE_BOOT_COMPLETED (y ActionBroadcastReceiver, para que la
//  acción "Repasar ahora" haga algo). El manifiesto del plugin solo
//  declara POST_NOTIFICATIONS y VIBRATE: desde la v16 hay que
//  declarar los receivers en el manifiesto de la app. El plugin
//  programa la alarma en AlarmManager con un broadcast dirigido a
//  ScheduledNotificationReceiver (FlutterLocalNotificationsPlugin
//  .java, zonedScheduleNotification) y nunca registra receivers en
//  runtime: sin el receiver declarado, al llegar la hora el sistema
//  descarta el broadcast en silencio. La app sí guardaba las horas
//  (melli_notif_next) y la pantalla decía "Próximo aviso", pero
//  NADA podía mostrarse: ni exactas ni inexactas, llegaran cuando
//  llegaran. Por eso la ronda #5 no lo arregló (sus causas eran
//  reales pero secundarias): los avisos INMEDIATOS (confirmación
//  9998, prueba 9999) sí pueden llegar, porque van directos al
//  NotificationManager sin pasar por AlarmManager; los programados
//  (toda la tanda de 3), nunca. Arreglo: receivers + permiso de
//  arranque en AndroidManifest.xml (ver ese archivo).
//  Tras un reinicio, el plugin reprograma solo los avisos
//  guardados (ScheduledNotificationBootReceiver) al arrancar el
//  teléfono; antes, tras reiniciar no llegaba nada hasta abrir la
//  app (y abrirla reprogramaba, así que el hueco era invisible).
//
//  SECUNDARIAS (siguen vigentes, fuera del código): sin alarmas
//  exactas concedidas, las inexactas + Doze retrasan los avisos
//  horas (el repliegue ya existía); y en Xiaomi/MIUI, si el ahorro
//  de batería está en agresivo o el inicio automático está
//  denegado, el sistema puede seguir retrasando o bloqueando la
//  entrega aunque el receiver exista. Eso ya no se puede arreglar
//  desde el código: la pantalla de Recordatorios lo diagnostica y
//  explica los pasos (ver screens/reminder_screen.dart y
//  services/battery_settings.dart).
//
//  Diagnóstico nuevo (ronda #6): la pantalla de Recordatorios
//  muestra el permiso real, el próximo aviso programado (o que no
//  hay ninguno), el ÚLTIMO aviso enviado (de la bandeja y de los
//  envíos inmediatos) y el estado del ahorro de batería. Si "Probar
//  un aviso ahora" llega, el problema era la programación (los
//  receivers); si ni esa llega, es permiso/canal o MIUI.
//
//  RUTA DE PETICIÓN (ronda #6, 02:18 — "la app nunca pide permiso"):
//  la cadena del toque al diálogo está completa y los tests la
//  prueban (fix5): botón → enable()/requestPermission() →
//  resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
//  → requestNotificationsPermission() → canal nativo → Java
//  requestNotificationsPermission → ActivityCompat.requestPermissions
//  (POST_NOTIFICATIONS). No hay guardia en la UI que bloquee el
//  toque (el botón llama directo, con la Activity viva) ni se piden
//  las alarmas exactas antes (eso se quitó en la ronda #5).
//  PERO había un retorno temprano que podía tragarse la petición:
//  requestPermission() (y la confirmación 9998, y sendTest())
//  exigían ANTES que init() tuviera éxito ("si !_ready, init(); si
//  falla, return false SIN pedir nada"). Las llamadas nativas del
//  permiso (requestNotificationsPermission, areNotificationsEnabled,
//  show) NO necesitan el init() de Dart — el lado Java solo usa la
//  Activity / el applicationContext — así que ese gate era un
//  acoplamiento innecesario: si init() fallaba por cualquier motivo,
//  el diálogo del sistema no se pedía nunca. Ahora la petición va
//  DIRECTO al plugin y el init() solo se asegura DESPUÉS de
//  concedido (para programar y para el handler de toques); el
//  aviso inmediato se intenta siempre, aunque init() falle.
//  Causa MÁS PROBABLE en el teléfono de Kristian: denegación
//  PERMANENTE (negó en el onboarding de la 6.0/6.1; en Android 13+,
//  tras dos negativas, el sistema ya NO muestra su diálogo y
//  requestPermissions devuelve denegado en el acto). Eso NO lo
//  puede arreglar ningún código: el único camino es Ajustes
//  (el diálogo de la app lo abre de un toque y al volver se
//  re-comprueba y se activa solo). En una instalación nueva, o
//  después de concederlo en Ajustes, el diálogo SÍ aparece al
//  tocar "Activar recordatorios", porque ahora la petición se
//  intenta siempre.

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../data/i18n/content_i18n.dart';
import '../data/questions.dart';
import '../widgets/twin_avatars.dart';
import 'accent.dart';
import 'localization.dart';
import 'nav_requests.dart';
import 'notification_inbox.dart';
import 'progress.dart';
import 'user_prefs.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _kLastNotif = 'melli_notif_last';

  /// Hora ISO del ÚLTIMO aviso enviado de verdad (ronda #6, punto
  /// 2): la anota cada envío inmediato (confirmación 9998 y prueba
  /// 9999). La lee [lastReminderSentTime] junto con la bandeja para
  /// el diagnóstico de Recordatorios. No se borra al apagar los
  /// recordatorios: es historial, no estado.
  static const _kLastSent = 'melli_notif_last_sent';

  /// Horas ISO de los 3 avisos programados, separadas por comas (la
  /// PRIMERA es el próximo aviso; se guardan las 3 para poder saltar
  /// las que ya pasaron sin abrir la app). La lee la pantalla de
  /// Recordatorios para mostrar "Próximo aviso: …".
  static const _kNextNotifs = 'melli_notif_next';
  static const _kExactAlarms = 'melli_notif_exact';
  static const _channelId = 'melli_study_reminders';
  static const _channelName = 'Recordatorios de estudio';

  /// Canal propio de los avisos INMEDIATOS (prueba 9999 y
  /// confirmación 9998) — ronda #7 (6.4). Antes compartían el canal
  /// de los recordatorios programados: si el usuario silenciaba ese
  /// canal en Ajustes, la prueba tampoco llegaba y no había forma de
  /// saber si el problema era el permiso o el canal. Con canal
  /// propio, la prueba es una señal limpia (canal nuevo = nunca
  /// silenciado por el usuario) y [isTestChannelBlocked] puede
  /// diagnosticar si el usuario lo desactivó después.
  static const _testChannelId = 'quemia_prueba_avisos';
  static const _testChannelName = 'Aviso de prueba';

  /// Nombre del canal de prueba, tal y como lo muestra el sistema en
  /// Ajustes (etiqueta fija en español, igual en todos los idiomas):
  /// la pantalla lo usa para componer las filas de estado de canal
  /// ("Canal «Aviso de prueba»: activado/desactivado").
  static String get testChannelName => _testChannelName;

  /// Id del canal de prueba (Zona G2): distinto del canal de
  /// recordatorios y del canal de push, para que las tres capas
  /// no se pisen en Ajustes.
  static String get testChannelId => _testChannelId;

  /// Nombre del canal de recordatorios, tal y como lo muestra el
  /// sistema en Ajustes (etiqueta fija en español, igual en todos
  /// los idiomas). Es el canal viejo ('melli_study_reminders'): si
  /// está desactivado en Ajustes, los avisos programados no llegan
  /// aunque el permiso general esté concedido.
  static String get remindersChannelName => _channelName;

  /// Id del canal de recordatorios (Zona G2): distinto del canal
  /// de prueba y del canal de push.
  static String get remindersChannelId => _channelId;

  /// Payload de TODAS las notificaciones: tocar la notificación (o su
  /// acción "Repasar ahora") abre el repaso de errores.
  static const reviewPayload = 'review_mistakes';

  // --- Actualización de la app (fix3, punto 20) ---
  // Las notificaciones de la actualización (descarga con progreso,
  // "descarga completa" y recordatorio de "Más tarde") viven AQUÍ,
  // con el MISMO plugin, canal, icono pequeño y estilo que los
  // recordatorios: un segundo plugin que llamara a initialize()
  // robaría el handler de toques del primero y las notificaciones de
  // repaso dejarían de abrir el repaso. El canal de la descarga es
  // propio (melli_app_updates) para que se pueda silenciar aparte;
  // el recordatorio usa el canal de repaso (mismo canal/estilo).
  /// Tocar el recordatorio de actualización: abre la app y muestra
  /// el diálogo de actualización.
  static const updatePayload = 'update_available';

  /// Tocar "Descarga completa" o su acción "Instalar": instala el
  /// APK ya descargado.
  static const installActionId = 'install_update';

  /// Id del recordatorio de actualización programado.
  static const _updateReminderId = 500;

  /// Id de la notificación de descarga (progreso y "completa"): el
  /// mismo, para que una reemplace a la otra.
  static const _updateNotifId = 9001;

  static const _updateChannelId = 'melli_app_updates';
  static const _updateChannelName = 'Actualizaciones de la app';

  /// Id de la acción "Repasar ahora" de la notificación.
  static const _reviewActionId = 'review_now';

  /// Icono pequeño: campana blanca en PNG (res/drawable-*/ic_notif_bell.png,
  /// protegido por res/values/keep.xml), no el logo a color, que
  /// Android pinta como un cuadrado negro.
  static const _smallIcon = 'ic_notif_bell';

  static bool _ready = false;

  // --- Avisos pendientes tras ir a Ajustes (ronda #7, 6.4) ---
  //
  // Bug de la 6.3: Kristian negó el permiso dos veces en la 6.0/6.1
  // (denegación permanente en Android 13+: el sistema ya no muestra
  // su diálogo), fue a Ajustes, lo permitió y volvió... y el aviso
  // nunca se mandó solo: había que tocar "Probar un aviso ahora"
  // otra vez y nada se lo decía. Así que la prueba parecía no
  // funcionar aunque el permiso ya estuviera concedido.
  //
  // La pantalla pone el flag al mandar al usuario a Ajustes (con el
  // texto 'notifTestPending') y lo consume al volver con el permiso
  // concedido: [takePendingTest] / [takePendingConfirmation]
  // devuelven true UNA SOLA VEZ y limpian el flag, así que el aviso
  // pendiente se envía una sola vez, nunca en bucle. Solo viven en
  // memoria (no en SharedPreferences): si la app se cierra, el
  // pendiente se pierde, pero el usuario puede tocar el botón de
  // prueba de nuevo; guardarlos persistentes haría que un aviso
  // viejo se disparara días después sin que nadie lo pidiera.
  static bool _pendingTest = false;
  static bool _pendingConfirmation = false;

  /// La pantalla marca que, al volver de Ajustes con el permiso
  /// concedido, hay que enviar sola la prueba (9999).
  static void markTestPending() {
    _pendingTest = true;
  }

  /// ¿Había una prueba pendiente? Devuelve true una sola vez y
  /// limpia el flag.
  static bool takePendingTest() {
    if (!_pendingTest) return false;
    _pendingTest = false;
    return true;
  }

  /// La pantalla marca que, al volver de Ajustes con el permiso
  /// concedido, hay que enviar sola la confirmación (9998).
  static void markConfirmationPending() {
    _pendingConfirmation = true;
  }

  /// ¿Había una confirmación pendiente? Devuelve true una sola vez
  /// y limpia el flag.
  static bool takePendingConfirmation() {
    if (!_pendingConfirmation) return false;
    _pendingConfirmation = false;
    return true;
  }

  /// ¿Está BLOQUEADO el canal de prueba ('quemia_prueba_avisos')?
  /// Mismo criterio que [isRemindersChannelBlocked]: true SOLO si
  /// el canal existe y su importancia es [Importance.none] (el
  /// usuario lo desactivó en Ajustes de notificaciones: en ese canal
  /// no llega nada aunque el permiso general esté concedido).
  static Future<bool> isTestChannelBlocked() =>
      _isChannelBlocked(_testChannelId);

  /// ¿Está BLOQUEADO el canal de recordatorios
  /// ('melli_study_reminders')? Mismo criterio que
  /// [isTestChannelBlocked]: true SOLO si el canal existe y su
  /// importancia es [Importance.none]. Es el canal viejo: si está
  /// desactivado en Ajustes, los avisos programados no llegan aunque
  /// el permiso general esté concedido (corrección de la ronda #7).
  static Future<bool> isRemindersChannelBlocked() =>
      _isChannelBlocked(_channelId);

  /// ¿Está BLOQUEADO el canal con id [channelId]?
  /// Devuelve true SOLO si el canal existe y su importancia es
  /// [Importance.none]. En no-Android, si el canal no existe
  /// (nunca se creó: aún no se envió ningún aviso por él) o si
  /// algo falla, devuelve false (no bloqueado).
  ///
  /// NOTA: flutter_local_notifications 23.0.0 no tiene
  /// getNotificationChannel(id) (singular); solo
  /// getNotificationChannels() (lista). Se busca el canal por id en
  /// esa lista: el resultado es el mismo.
  static Future<bool> _isChannelBlocked(String channelId) async {
    try {
      // defaultTargetPlatform, no Platform.isAndroid (ronda #7): en
      // `flutter test` el host es Linux pero el target es Android,
      // así que la detección de canal bloqueado sí tiene cobertura
      // en tests. En el teléfono el comportamiento es el mismo
      // (Android → se consulta; resto → false).
      if (defaultTargetPlatform != TargetPlatform.android) return false;
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      // Tope de 2 s (Zona G; antes 100 ms): si el canal no
      // responde, el botón no se puede quedar esperando (en
      // tests, los fakes viejos no implementan
      // getNotificationChannels y su Future no se resuelve nunca):
      // se asume que no está bloqueado y el aviso se intenta
      // igualmente. El TimeoutException lo traga el catch de
      // abajo. 100 ms mentía en el teléfono: en un MIUI ocupado
      // la llamada al NotificationManager puede tardar más y el
      // canal bloqueado parecía "no bloqueado", así que la prueba
      // decía "Aviso enviado" sin que llegara nada. Una consulta
      // local responde en ms; 2 s solo es el tope, no la espera
      // habitual (y es el mismo tope que la comprobación
      // estricta del permiso en sendTestDetailed).
      final channels = await android
          .getNotificationChannels()
          .timeout(const Duration(seconds: 2));
      if (channels == null) return false;
      for (final channel in channels) {
        if (channel.id == channelId) {
          return channel.importance == Importance.none;
        }
      }
      // El canal no existe todavía: aún no se envió ningún aviso
      // por él, así que nadie pudo bloquearlo.
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Reinicia el estado estático (solo para tests): sin inicializar
  /// y sin alarmas exactas. Permite probar la ruta de petición con
  /// el servicio "frío", como al abrir la app por primera vez.
  @visibleForTesting
  static void resetForTests() {
    _ready = false;
    _exactAlarms = false;
    _pendingTest = false;
    _pendingConfirmation = false;
  }

  /// ¿Se pueden usar alarmas exactas? Se PRUEBAN al programar la
  /// tanda (fix5, punto 1): se intenta exacta y, si el plugin dice
  /// que no están concedidas, _scheduleOne vuelve a inexacta y
  /// apaga el modo exacto hasta la siguiente tanda. Nunca se piden
  /// (pedirlas abre los Ajustes del sistema) ni se consultan. Si
  /// no están dadas, las alarmas son inexactas y Doze puede
  /// retrasarlas horas: se sigue avisando, pero tarde.
  static bool _exactAlarms = false;

  /// ¿Las alarmas se programan exactas? (Para pruebas.)
  static bool get exactAlarmsOn => _exactAlarms;

  /// Modo de alarma según el permiso de alarmas exactas.
  static AndroidScheduleMode get scheduleMode => _exactAlarms
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  /// Intervalo entre avisos, en minutos: siempre más de 1 hora.
  static const int minGapMinutes = 61;
  static const int maxGapMinutes = 180;

  /// El PRIMER aviso llega pronto, dentro de la primera hora
  /// (20-50 min). Si el primero tardara 3 horas, el usuario cree que
  /// no funciona. Los siguientes sí van a 61-180 min.
  static const int minFirstGapMinutes = 20;
  static const int maxFirstGapMinutes = 50;

  /// ¿La próxima notificación debe llegar dentro de estos márgenes?
  /// (Para pruebas: el aviso llega entre 61 y 180 min después de ahora.)
  static bool gapIsValid(int minutes) =>
      minutes >= minGapMinutes && minutes <= maxGapMinutes;

  /// ¿El primer aviso llega dentro de la primera hora (20-50 min)?
  /// (Para pruebas.)
  static bool firstGapIsValid(int minutes) =>
      minutes >= minFirstGapMinutes && minutes <= maxFirstGapMinutes;

  /// Un hueco aleatorio entre dos avisos: siempre más de 1 hora
  /// (61-180 minutos). Función pura para poder probarla.
  static int nextGapMinutes(Random rng) =>
      minGapMinutes + rng.nextInt(maxGapMinutes - minGapMinutes + 1);

  /// El hueco hasta el PRIMER aviso: aleatorio, dentro de la primera
  /// hora (20-50 minutos). Función pura para poder probarla.
  static int nextFirstGapMinutes(Random rng) =>
      minFirstGapMinutes +
      rng.nextInt(maxFirstGapMinutes - minFirstGapMinutes + 1);

  /// Inicializa el plugin y, si el recordatorio está activado, programa
  /// la próxima tanda. No pide el permiso aquí: se pide al activar el
  /// recordatorio (o en la pantalla de permiso del onboarding), para no
  /// asustar al abrir la app por primera vez.
  static Future<bool> init() async => _init(reschedule: true);

  /// Inicialización con o sin reprogramación. La consulta del permiso
  /// ([isPermissionGranted]) es de SOLO LECTURA y no debe tener
  /// efectos secundarios: si inicializara con reprogramación,
  /// comprobar el permiso reprogramaría la tanda (y su copia del
  /// icono grande) en mitad de una comprobación (fix5, punto 1).
  /// main() siempre llama a [init] (completa) al arrancar, así que
  /// en la app la reprogramación de inicio no se pierde.
  static Future<bool> _init({required bool reschedule}) async {
    try {
      tz.initializeTimeZones();
      try {
        // Con tiempo límite: si el canal del sistema no responde
        // (en pruebas no hay plataforma y la llamada se queda
        // colgada en vez de fallar), no se puede quedar init()
        // esperando para siempre: sin zona horaria se usa la local
        // por defecto y el permiso se pide igual. Sin este límite,
        // "Activar recordatorios" con el permiso negado no avanzaba
        // al siguiente paso del onboarding.
        final tzInfo = await FlutterTimezone.getLocalTimezone().timeout(
          const Duration(seconds: 3),
        );
        tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
      } catch (_) {
        // Sin zona horaria del sistema: se usa la local por defecto.
      }
      final prefs = await SharedPreferences.getInstance();
      _exactAlarms = prefs.getBool(_kExactAlarms) ?? false;
      const androidSettings =
          AndroidInitializationSettings(_smallIcon);
      await _plugin.initialize(
        settings: const InitializationSettings(android: androidSettings),
        onDidReceiveNotificationResponse: (response) {
          // Tocar la notificación (o "Repasar ahora") abre el repaso
          // de errores; cualquier toque de repaso reprograma la tanda.
          if (response.payload == reviewPayload ||
              response.actionId == _reviewActionId) {
            NavRequests.requestReview();
            // La bandeja anota el aviso que se tocó ANTES de
            // reprogramar la tanda (que borra las horas pasadas).
            // Zona G2: la cadena lleva su propio try/catch — si
            // reprogramar falla (p. ej. zona horaria sin inicializar
            // en un arranque raro), el toque NO debe soltar un error
            // sin capturar: el repaso ya quedó pedido arriba.
            unawaited(
              () async {
                try {
                  await reconcileFiredReminders();
                  await scheduleNext();
                } catch (_) {
                  // El repaso ya está pedido; reprogramar es opcional.
                }
              }(),
            );
          } else if (response.payload == updatePayload) {
            // Recordatorio de actualización: la app se abre y sale el
            // diálogo de actualización (fix3, punto 20).
            NavRequests.requestUpdateDialog();
          } else if (response.payload == installActionId ||
              response.actionId == installActionId) {
            // "Descarga completa" o su acción "Instalar": instala el
            // APK ya descargado (fix3, punto 20).
            NavRequests.requestInstallApk();
          }
        },
      );
      _ready = true;
      // Los avisos que ya se dispararon mientras la app estaba
      // cerrada quedan registrados en la bandeja ANTES de
      // reprogramar la tanda (que borraría sus horas).
      await reconcileFiredReminders();
      if (reschedule && UserPrefs.reminderOn) {
        await scheduleNext();
      }
      return true;
    } catch (_) {
      _ready = false;
      return false;
    }
  }

  /// ¿Está dado el permiso de notificaciones? (Android 13+:
  /// POST_NOTIFICATIONS; antes: avisos activados.) Solo consulta,
  /// no pide nada y no reprograma nada. La consulta va DIRECTO al
  /// plugin (ronda #6): areNotificationsEnabled solo usa el
  /// applicationContext y NO necesita que el servicio esté
  /// inicializado; si init() fallara, la consulta no debe mentir
  /// diciendo "denegado" ni impedir que se pida el permiso (antes
  /// se inicializaba aquí y, si init() fallaba, se devolvía false
  /// sin comprobar nada). Si la plataforma no responde, se asume
  /// que sí (en Android < 13 no hay permiso que pedir).
  static Future<bool> get isPermissionGranted async {
    try {
      // areNotificationsEnabled vive en la implementación de
      // Android (no en el plugin ni en la interfaz abstracta): en
      // Android 13+ dice si POST_NOTIFICATIONS está concedido;
      // antes, si los avisos están activados.
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final enabled = android?.areNotificationsEnabled();
      if (enabled == null) return true;
      // Tope de 100 ms: si el canal no responde (en pruebas sin
      // mock se queda colgado), no se puede quedar la app esperando:
      // se asume que sí, como antes (fix5). Es una consulta local y
      // en el teléfono responde en milisegundos.
      return await enabled.timeout(const Duration(milliseconds: 100)) ??
          true;
    } catch (_) {
      return true;
    }
  }

  /// Pide el permiso de notificaciones (muestra el diálogo del
  /// sistema la primera vez). Devuelve si quedó concedido. Extraído
  /// de [enable] para reutilizarlo en la pantalla de Recordatorios,
  /// en el botón de prueba y en el onboarding (fix4, punto 3).
  /// La petición va DIRECTO al plugin, sin pasar por init()
  /// (ronda #6, punto 2): el diálogo del sistema no necesita que
  /// el servicio esté inicializado — el canal nativo solo necesita
  /// la Activity viva del toque — y antes, si init() fallaba, la
  /// petición se tragaba el diálogo ("la app nunca pide permiso").
  /// OJO: si el permiso está denegado de forma permanente, el
  /// sistema ya NO muestra su diálogo y devuelve false en el acto
  /// (fix5, punto 1): el único camino es entonces "Ir a Ajustes".
  /// Si la petición en sí falla (p. ej. otra petición en curso),
  /// se devuelve false: antes se devolvía true y enable() guardaba
  /// los recordatorios como activos aunque ningún aviso pudiera
  /// llegar.
  static Future<bool> requestPermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? true;
    } catch (_) {
      return false;
    }
  }

  /// Abre los ajustes de notificaciones de la app (el sistema abre
  /// la pantalla de notificaciones o, si no la hay, los detalles de
  /// la app). Lo implementa el propio plugin de notificaciones, sin
  /// dependencia ni código nativo nuevo en MainActivity. Devuelve si
  /// se pudo abrir.
  static Future<bool> openNotificationSettings() async {
    try {
      return await _plugin.openAppNotificationSettings() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Activa los recordatorios: pide el permiso con el diálogo del
  /// sistema DIRECTO (Android 13+), guarda el ajuste, programa la
  /// primera tanda (el primer aviso llega dentro de la primera
  /// hora) y dispara UNA notificación inmediata de confirmación para
  /// que se VEA que las notificaciones funcionan (fix5, punto 1).
  /// Si el permiso está denegado de forma permanente, el sistema ya
  /// no muestra su diálogo y devuelve false: la UI ofrece entonces
  /// "Ir a Ajustes" (fix4, punto 3).
  ///
  /// Orden (ronda #6, punto 2): la petición va PRIMERO, y solo con
  /// el permiso ya concedido se asegura la inicialización antes de
  /// programar. Antes la petición exigía init() con éxito, así que
  /// si init() fallaba el diálogo no se pedía nunca. El init() de
  /// aquí es "lo mejor posible": si falla, la tanda se intenta
  /// igual (sus errores se tragan) y la confirmación sale igual.
  ///
  /// Las alarmas exactas YA NO se piden aquí: en Android 12+
  /// requestExactAlarmsPermission() abre los Ajustes del sistema
  /// ("Alarmas y recordatorios") justo después del diálogo del
  /// permiso, y eso es lo que al usuario le parecía "una explicación
  /// de cómo activar" en vez de una petición (fix5). Al programar
  /// se PRUEBAN las exactas (el plugin falla antes de programar si
  /// no están concedidas) y se vuelve a inexactas sin abrir nada.
  /// La confirmación se dispara sin esperar (unawaited): si el
  /// canal no responde, la activación no se queda colgada.
  static Future<bool> enable() async {
    if (!await requestPermission()) return false;
    if (!_ready) {
      await init();
    }
    await UserPrefs.saveReminder(
        true, UserPrefs.reminderHour, UserPrefs.reminderMinute);
    await scheduleNext();
    // Confirmación inmediata: que se VEA que funciona (fix5).
    unawaited(sendEnabledConfirmation());
    return true;
  }

  /// Apaga los recordatorios y cancela los pendientes.
  static Future<void> disable() async {
    await _plugin.cancelAll();
    try {
      // Sin avisos pendientes, la pantalla no debe mostrar un
      // "Próximo aviso" viejo.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kNextNotifs);
    } catch (_) {
      // Limpiar el próximo aviso es opcional.
    }
    await UserPrefs.saveReminder(
        false, UserPrefs.reminderHour, UserPrefs.reminderMinute);
  }

  /// Programa 3 avisos por delante: el primero dentro de la primera
  /// hora (20-50 min) y los siguientes 61-180 min después del
  /// anterior. Devuelve las horas programadas (para depurar).
  static Future<List<DateTime>> scheduleNext({Random? rng}) async {
    final random = rng ?? Random();
    final now = tz.TZDateTime.now(tz.local);
    var at = now;
    final scheduled = <DateTime>[];
    try {
      // Sin permiso no hay nada que programar: las alarmas no se
      // mostrarían nunca y el "Próximo aviso" guardado mentiría
      // (fix5, punto 1). Se borra la tanda vieja, si la había; al
      // volver a concederse el permiso, enable() reprograma.
      if (!await isPermissionGranted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_kNextNotifs);
        return [];
      }
      // Alarmas exactas (fix5): se PRUEBAN en cada tanda. Si el
      // usuario las concedió en Ajustes desde la última vez, esta
      // tanda ya sale exacta; si no están concedidas, el primer
      // intento falla antes de programar y _scheduleOne vuelve a
      // inexacta (sin abrir Ajustes ni pedir nada).
      _exactAlarms = true;
      await _plugin.cancelAll();
      final details = await _details();
      for (var i = 0; i < 3; i++) {
        final gap =
            i == 0 ? nextFirstGapMinutes(random) : nextGapMinutes(random);
        at = at.add(Duration(minutes: gap));
        final message = _pickMessage(random);
        await _scheduleOne(100 + i, message, at, details);
        scheduled.add(at);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kLastNotif, scheduled.isEmpty ? '' : scheduled.last.toIso8601String());
      await prefs.setString(_kNextNotifs,
          scheduled.map((d) => d.toIso8601String()).join(','));
    } catch (_) {
      // Si programar falla (p. ej. sin plugin en pruebas), no se rompe
      // la app: el recordatorio simplemente no llega.
    }
    return scheduled;
  }

  /// Próximo aviso programado que aún no ha pasado, o null si no hay
  /// ninguno (recordatorios apagados, tanda ya pasada o nunca se
  /// programó). Solo lee lo guardado por [scheduleNext]; no programa
  /// nada. Si el primero de la tanda ya pasó (la app lleva horas sin
  /// abrirse), devuelve el siguiente que siga en el futuro.
  static Future<DateTime?> nextNotificationTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kNextNotifs);
      if (raw == null || raw.isEmpty) return null;
      final now = DateTime.now();
      for (final part in raw.split(',')) {
        final at = DateTime.tryParse(part.trim());
        if (at != null && at.isAfter(now)) return at;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Hora a la que se envió el ÚLTIMO recordatorio de estudio, o
  /// null si todavía no se envió ninguno (ronda #6, punto 2:
  /// diagnóstico de Recordatorios). Dos fuentes, se toma la más
  /// reciente:
  ///  - la bandeja: cada aviso programado que se disparó deja una
  ///    entrada de tipo recordatorio (la anota
  ///    [reconcileFiredReminders] al abrir la app). La hora es la
  ///    PROGRAMADA (va en el id, "reminder-<milisegundos>"), no la
  ///    de la reconciliación, que puede ser horas después;
  ///  - el último envío inmediato (confirmación 9998 o prueba
  ///    9999), guardado en [_kLastSent] por [sendEnabledConfirmation]
  ///    y [sendTest].
  /// Solo lee: no programa nada.
  static Future<DateTime?> lastReminderSentTime() async {
    DateTime? last;
    try {
      final prefs = await SharedPreferences.getInstance();
      final sentRaw = prefs.getString(_kLastSent);
      final sent = sentRaw == null ? null : DateTime.tryParse(sentRaw);
      if (sent != null) last = sent;
    } catch (_) {
      // Sin preferencia, solo queda la bandeja.
    }
    try {
      await NotificationInbox.load();
      for (final entry in NotificationInbox.entries) {
        if (entry.kind != InboxKind.reminder) continue;
        var at = entry.createdAt;
        final millis = int.tryParse(
          entry.id.replaceFirst('reminder-', ''),
        );
        if (millis != null) {
          at = DateTime.fromMillisecondsSinceEpoch(millis);
        }
        if (last == null || at.isAfter(last)) last = at;
      }
    } catch (_) {
      // Sin bandeja, solo queda el envío inmediato.
    }
    return last;
  }

  /// Anota la hora del último aviso enviado de verdad (confirmación
  /// o prueba). "Lo mejor posible": si no se puede guardar, el
  /// diagnóstico simplemente no muestra ese envío.
  static Future<void> _recordLastSent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kLastSent, DateTime.now().toIso8601String());
    } catch (_) {
      // Guardar la hora es opcional.
    }
  }
  /// estudio que ya se dispararon (fix4, punto 8): cada hora
  /// programada que ya pasó genera una entrada ("Hora de repasar"),
  /// por si el usuario no vio el aviso. Se llama al abrir la app
  /// (antes de reprogramar la tanda, que borraría las horas
  /// pasadas), al tocar una notificación de repaso y al abrir la
  /// bandeja. NO reescribe la lista de programadas: el dedup va por
  /// el id de la entrada (recordatorio-<milisegundos de la hora>),
  /// así que llamarlo dos veces no duplica nada. [nowOverride] es
  /// solo para los tests.
  static Future<void> reconcileFiredReminders({
    DateTime? nowOverride,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kNextNotifs);
      if (raw == null || raw.isEmpty) return;
      final now = nowOverride ?? DateTime.now();
      for (final part in raw.split(',')) {
        final at = DateTime.tryParse(part.trim());
        if (at == null || !at.isBefore(now)) continue;
        await NotificationInbox.add(
          id: 'reminder-${at.millisecondsSinceEpoch}',
          kind: InboxKind.reminder,
          title: tr('inboxReminderTitle'),
          body: tr('inboxReminderBody'),
        );
      }
    } catch (_) {
      // Registrar en la bandeja es opcional: la app sigue.
    }
  }

  /// Programa UN aviso. Si la alarma exacta falla (permiso revocado
  /// en ajustes: SecurityException), se reintenta como inexacta y
  /// se apaga el modo exacto hasta que se vuelva a conceder.
  static Future<void> _scheduleOne(
      int id, String body, tz.TZDateTime at, NotificationDetails details,
      {String? payload}) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: 'Quemia',
        body: body,
        scheduledDate: at,
        payload: payload ?? reviewPayload,
        notificationDetails: details,
        androidScheduleMode: scheduleMode,
      );
    } catch (_) {
      if (!_exactAlarms) rethrow;
      _exactAlarms = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kExactAlarms, false);
      } catch (_) {
        // Guardar el ajuste es opcional.
      }
      await _plugin.zonedSchedule(
        id: id,
        title: 'Quemia',
        body: body,
        scheduledDate: at,
        payload: payload ?? reviewPayload,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  /// Detalles de la notificación: icono pequeño blanco (PNG),
  /// color teal, icono grande con el compañero del día y acción
  /// "Repasar ahora". Si el compañero no se puede copiar, sale sin
  /// icono grande, pero con todo lo demás.
  static Future<NotificationDetails> _details() async {
    final largeIcon = await _twinLargeIcon();
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: _smallIcon,
        color: AppAccent.primary,
        largeIcon: largeIcon,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(_reviewActionId, tr('notifActionReview')),
        ],
      ),
    );
  }

  /// Detalles de los avisos INMEDIATOS (prueba 9999): como
  /// [_details] (icono pequeño blanco, color del acento, icono grande con
  /// el compañero del día y acción "Repasar ahora"), pero en el canal
  /// propio de prueba ([_testChannelId]) con Importance.high y
  /// Priority.high, para que el aviso de prueba no se pierda entre
  /// los recordatorios ni lo silencie el canal de repaso. Los
  /// recordatorios PROGRAMADOS siguen en 'melli_study_reminders'
  /// con [_details] sin tocar.
  static Future<NotificationDetails> _testDetails() async {
    final largeIcon = await _twinLargeIcon();
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _testChannelId,
        _testChannelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: _smallIcon,
        color: AppAccent.primary,
        largeIcon: largeIcon,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(_reviewActionId, tr('notifActionReview')),
        ],
      ),
    );
  }

  /// Icono grande: el compañero del día (Brenda, Britany o
  /// Kristian). El PNG del asset se copia a un archivo temporal y se
  /// usa con FilePathAndroidBitmap: los binarios del repo viajan como
  /// .b64 y los decodifica el workflow, así que añadir un drawable
  /// PNG nuevo obligaría a tocar el workflow. Si la copia falla,
  /// null (la notificación sale sin icono grande, pero sale).
  static Future<AndroidBitmap<Object>?> _twinLargeIcon() async {
    try {
      final companion = companionOfTheDay();
      final asset = companionAsset(companion);
      final name = 'melli_notif_${companion.name}.png';
      final dir = await getTemporaryDirectory();
      // La copia es "lo mejor posible": si el disco tarda demasiado,
      // no se bloquea la programación de los avisos (ni el avance del
      // onboarding): se sigue sin icono grande, pero el aviso sale.
      return await Future<AndroidBitmap<Object>>(() async {
        final file = File('${dir.path}/$name');
        if (!await file.exists()) {
          final bytes = await rootBundle.load(asset);
          await file.writeAsBytes(bytes.buffer.asUint8List());
        }
        return FilePathAndroidBitmap(file.path);
      }).timeout(const Duration(seconds: 3));
    } catch (_) {
      return null;
    }
  }

  /// UNA notificación inmediata de confirmación ("Recordatorios
  /// activados"): se dispara al concederse el permiso (al final de
  /// [enable], sin esperar) para que se VEA en ese momento que las
  /// notificaciones funcionan (fix5, punto 1). Sin icono grande ni
  /// acción: tiene que salir ya, sin esperar la copia del PNG del
  /// compañero (hasta 3 s). Tocar la notificación solo abre la app.
  /// Devuelve false si no se pudo mostrar (sin permiso, sin plugin).
  /// Sin tope: en enable() se llama sin esperar (unawaited), así
  /// que un canal que no responda no puede colgar la activación.
  /// Envoltorio bool de [sendEnabledConfirmationDetailed] (Zona G,
  /// regla general: el mismo defecto que la prueba — el catch ciego
  /// tragaba la causa — estaba también aquí y queda corregido con
  /// la versión tipada).
  static Future<bool> sendEnabledConfirmation() async =>
      (await sendEnabledConfirmationDetailed()).sent;

  /// Versión TIPADA de la confirmación (Zona G, regla general):
  /// el show() de la 9998 tenía el mismo `catch (_) { return
  /// false; }` que la prueba: si la confirmación fallaba al
  /// conceder el permiso, nadie sabía si fue el permiso, el canal
  /// o el plugin. Ahora clasifica el error igual que
  /// [sendTestDetailed] y comprueba el canal de avisos inmediatos
  /// ANTES de enviar (si está bloqueado, el show() no lanzaría y
  /// la confirmación se perdería en silencio, como le pasaba a la
  /// prueba). No re-comprueba el permiso: enable() lo acaba de
  /// pedir con el diálogo del sistema, y si el show() lanzara
  /// SecurityException se clasifica como permissionDenied igual.
  static Future<NotificationTestResult>
      sendEnabledConfirmationDetailed() async {
    // La confirmación se intenta SIEMPRE (ronda #6, punto 2): si
    // init() fallara, el aviso no debe perderse con él (antes se
    // devolvía false sin mostrar nada). Mostrarlo no necesita que
    // el servicio esté inicializado; el init() solo se intenta
    // para que el toque abra la app con el handler correcto.
    // Ronda #7 (6.4): el init() va en try/catch — si lanza, se sigue
    // al show() igual: un init() que falle NUNCA bloquea el aviso.
    if (!_ready) {
      try {
        await init();
      } catch (_) {
        // Sin inicializar, el aviso se intenta igual.
      }
    }
    if (await isTestChannelBlocked()) {
      return const NotificationTestResult(
        NotificationTestOutcome.channelBlocked,
      );
    }
    try {
      await _plugin.show(
        id: 9998,
        title: 'Quemia',
        body: tr('notifEnabledConfirm'),
        notificationDetails: _confirmationDetails(),
      );
      // Salió de verdad: queda anotado para el diagnóstico
      // (ronda #6, punto 2).
      await _recordLastSent();
      return const NotificationTestResult(NotificationTestOutcome.sent);
    } catch (error) {
      return resultForShowError(error);
    }
  }

  /// Detalles de la confirmación inmediata: canal propio de avisos
  /// inmediatos ([_testChannelId], ronda #7) con Importance.high,
  /// icono pequeño blanco y acento del tema, pero sin icono grande (sin
  /// espera) y sin la acción "Repasar ahora".
  static NotificationDetails _confirmationDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _testChannelId,
        _testChannelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: _smallIcon,
        color: AppAccent.primary,
      ),
    );
  }

  /// Una notificación de prueba, ahora mismo (botón "Probar" del
  /// recordatorio). Sirve para comprobar en el teléfono que los avisos
  /// llegan y que el permiso está dado. Usa los detalles de prueba
  /// ([_testDetails]: icono, gemela y acción, en el canal propio de
  /// prueba con Importance.high, ronda #7). Si sale, queda anotada la
  /// hora para el diagnóstico (ronda #6, punto 2): si esta llega y
  /// los programados no, el problema era la programación, no el
  /// permiso. Si el show() lanza, NO se anota la hora (no hubo aviso).
  ///
  /// Zona G (Quemia 7.1) — diagnóstico real, verificado en el fuente
  /// de flutter_local_notifications 23.0.0 (pub-cache):
  ///  - El show() de Java (FlutterLocalNotificationsPlugin.java,
  ///    `show`) NO tiene try/catch alrededor de
  ///    showNotification → NotificationManagerCompat.notify: en
  ///    API 33+, sin POST_NOTIFICATIONS, notify() lanza
  ///    SecurityException; y si el icono no es válido,
  ///    extractNotificationDetails devuelve result.error con
  ///    código invalid_icon / invalid_large_icon / etc. (el Dart
  ///    lo ve como PlatformException con ese código). Un plugin
  ///    sin inicializar NO lanza desde show (el lado Java solo
  ///    necesita el applicationContext). Un canal bloqueado
  ///    (Importance.none) TAMPOCO lanza: el sistema descarta el
  ///    aviso en silencio y show() devuelve normal.
  ///  - Por eso el "error del sistema" de la 6.4 solo podía ser
  ///    una excepción LANZADA por show() (permiso denegado en el
  ///    momento del notify, icono no válido u otro RuntimeException),
  ///    nunca un canal bloqueado ni un init() fallido. Pero
  ///    sendTest() la tragaba con `catch (_) { return false; }`,
  ///    así que en el teléfono no quedaba NINGUNA pista de cuál
  ///    era. La 6.4 cambió el canal y el tipo de retorno sin
  ///    guardar la excepción: el mismo síntoma, sin información
  ///    nueva. Ahora la excepción se captura, se clasifica y se
  ///    muestra: [sendTestDetailed] devuelve el resultado TIPADO
  ///    y la pantalla nombra la causa real.
  ///  - El permiso podía llegar denegado hasta show() aunque la
  ///    pantalla dijera lo contrario: [isPermissionGranted] (y
  ///    [_isChannelBlocked]) usan un tope de 100 ms y, al
  ///    expirar o fallar, ASUMEN que sí ("se asume que sí" / "no
  ///    bloqueado"). En un MIUI ocupado la llamada al
  ///    NotificationManager puede tardar más de 100 ms, así que
  ///    el interruptor podía mostrar ON con el permiso denegado
  ///    de verdad. La prueba ya no se fía de esa suposición:
  ///    [_isPermissionGrantedStrict] espera hasta 2 s y, si no
  ///    puede comprobarlo, lo dice (null) en vez de mentir.
  static Future<bool> sendTest() async =>
      (await sendTestDetailed()).sent;

  /// Resultado TIPADO de la prueba (Zona G). La pantalla lo usa
  /// para nombrar la causa real en vez del genérico
  /// "error del sistema".
  static Future<NotificationTestResult> sendTestDetailed() async {
    // El aviso de prueba se intenta SIEMPRE (ronda #6, punto 2):
    // si init() fallara, la prueba no debe perderse con él (antes
    // se salía sin mostrar nada). Mostrarlo no necesita que el
    // servicio esté inicializado. Ronda #7 (6.4): el init() va en
    // try/catch — si lanza, se sigue al show() igual: el resultado
    // refleja el show(), no el init().
    if (!_ready) {
      try {
        await init();
      } catch (_) {
        // Sin inicializar, la prueba se intenta igual.
      }
    }
    // 1) Permiso REAL, comprobación estricta: si dice que NO, no
    // se intenta el show(): en API 33+ el notify() lanzaría
    // SecurityException y la pantalla diría "error del sistema"
    // en vez de la causa real ("permiso denegado"). Si NO se pudo
    // comprobar (null), se sigue: el show() lo dirá con su
    // excepción.
    final granted = await _isPermissionGrantedStrict();
    if (granted == false) {
      return const NotificationTestResult(
        NotificationTestOutcome.permissionDenied,
      );
    }
    // 2) Canal de prueba bloqueado en Ajustes: el show() NO
    // lanzaría (el sistema descarta el aviso en silencio), así
    // que hay que detectarlo ANTES o la pantalla mentiría
    // diciendo "Aviso enviado" sin que llegara nada.
    if (await isTestChannelBlocked()) {
      return const NotificationTestResult(
        NotificationTestOutcome.channelBlocked,
      );
    }
    // 3) Enviar, guardando ESTA VEZ la excepción: es la única
    // prueba de lo que falla en el teléfono.
    try {
      await _plugin.show(
        id: 9999,
        title: 'Quemia',
        body: _pickMessage(Random()),
        payload: reviewPayload,
        notificationDetails: await _testDetails(),
      );
      await _recordLastSent();
      return const NotificationTestResult(NotificationTestOutcome.sent);
    } catch (error) {
      return resultForShowError(error);
    }
  }

  /// Permiso REAL con comprobación estricta (Zona G, solo para la
  /// prueba): como [isPermissionGranted] pero sin mentir nunca.
  /// Espera hasta 2 s (una consulta local responde en ms, pero en
  /// un teléfono ocupado 100 ms es demasiado justo) y devuelve
  /// null si no se pudo comprobar: en ese caso la prueba se
  /// intenta igual y es el show() el que dice si el permiso está
  /// dado. NO se toca [isPermissionGranted]: su valor por defecto
  /// ("sí" ante cualquier fallo) lo usan scheduleNext y el
  /// interruptor, y cambiarlo ahí borraría tandas programadas por
  /// un fallo transitorio.
  static Future<bool?> _isPermissionGrantedStrict() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final enabled = android?.areNotificationsEnabled();
      if (enabled == null) return null;
      return await enabled.timeout(const Duration(seconds: 2));
    } catch (_) {
      return null;
    }
  }

  /// Clasifica la excepción que lanzó show() (Zona G): en API 33+
  /// el notify() sin permiso lanza SecurityException, así que un
  /// error que hable de permiso/seguridad ES un permiso denegado
  /// (aunque la comprobación previa dijera que sí: la del
  /// notify es la que manda); el resto es un error del plugin y
  /// su texto real va en [NotificationTestResult.detail] para
  /// mostrarlo (nunca el genérico "error del sistema"). Función
  /// pura y visible para las pruebas: se alimenta con excepciones
  /// falsas y se comprueba el resultado.
  @visibleForTesting
  static NotificationTestResult resultForShowError(Object error) {
    final text = error.toString();
    final lower = text.toLowerCase();
    if (lower.contains('securityexception') ||
        lower.contains('post_notifications') ||
        lower.contains('not allowed to post') ||
        lower.contains('permission')) {
      return NotificationTestResult(
        NotificationTestOutcome.permissionDenied,
        _shortError(error),
      );
    }
    return NotificationTestResult(
      NotificationTestOutcome.pluginError,
      _shortError(error),
    );
  }

  /// Texto corto del error para el snackbar (máx. 120 caracteres):
  /// de una PlatformException, "código: mensaje"; del resto, su
  /// toString() recortado.
  static String _shortError(Object error) {
    final String text;
    if (error is PlatformException) {
      final message = error.message;
      text = message == null || message.isEmpty
          ? 'PlatformException(${error.code})'
          : '${error.code}: $message';
    } else {
      text = error.toString();
    }
    const max = 120;
    return text.length <= max ? text : '${text.substring(0, max)}…';
  }

  /// Elige un mensaje al azar en el idioma actual. Una de cada tres
  /// veces, si hay un tema débil, el mensaje es un repaso de ese tema,
  /// con su NOMBRE BONITO (nunca el slug).
  static String _pickMessage(Random rng) {
    final lang = AppLang.code;
    final generic = _messages[lang] ?? _messages['es']!;
    final p = ProgressService.instance;
    // Temas del banco (los slugs no dependen del idioma).
    final bankTopics = <String>{
      for (final q in allQuestions) q.topic,
    }.toList();
    final weakest = p.weakestTopics(bankTopics);
    if (weakest.isNotEmpty && rng.nextInt(3) == 0) {
      return weakTopicMessage(lang, localizedTopicTitle(weakest.first));
    }
    return generic[rng.nextInt(generic.length)];
  }

  /// Mensaje de repaso del tema más débil. Recibe ya el NOMBRE BONITO
  /// del tema ("Estequiometría y el mol"), nunca el slug: ningún texto
  /// mostrado sale de un id interno. (Para pruebas.)
  static String weakTopicMessage(String lang, String topicName) {
    switch (lang) {
      case 'en':
        return 'Time to review $topicName, your weakest topic.';
      case 'fr':
        return 'Il est temps de réviser $topicName, ton point faible.';
      case 'it':
        return 'È ora di ripassare $topicName, il tuo punto debole.';
      case 'pt':
        return 'Hora de revisar $topicName, seu ponto fraco.';
      case 'ru':
        return 'Пора повторить $topicName — твою самую слабую тему.';
      default:
        return 'Toca repasar $topicName, tu tema más flojo.';
    }
  }

  /// Todas las plantillas genéricas de mensajes, por idioma.
  /// (Para pruebas: ninguna puede contener un slug.)
  static List<String> messageTemplates(String lang) =>
      List.unmodifiable(_messages[lang] ?? _messages['es']!);

  static const Map<String, List<String>> _messages = {
    'es': [
      '¿Ya repasaste hoy o lo dejamos para mañana?',
      'Tu racha te está esperando: un nivel y sigue viva.',
      'Cinco minutos de química: ¿te atreves con un nivel?',
      'Tu yo de mañana te lo va a agradecer: repasa un poco.',
    ],
    'en': [
      'Did you review today or shall we leave it for tomorrow?',
      'Your streak is waiting: one level and it stays alive.',
      'Five minutes of chemistry: fancy a level?',
      'Your tomorrow self will thank you: review a little.',
    ],
    'fr': [
      'As-tu déjà révisé aujourd’hui ou on remet à demain ?',
      'Ta série t’attend : un niveau et elle reste en vie.',
      'Cinq minutes de chimie : tu tentes un niveau ?',
      'Ton toi de demain te remerciera : révise un peu.',
    ],
    'it': [
      'Hai già ripassato oggi o rimandiamo a domani?',
      'La tua serie ti aspetta: un livello e resta viva.',
      'Cinque minuti di chimica: ti va un livello?',
      'Il te di domani ti ringrazierà: ripassa un po’.',
    ],
    'pt': [
      'Você já revisou hoje ou deixamos para amanhã?',
      'Sua sequência está esperando: um nível e ela continua viva.',
      'Cinco minutos de química: topa um nível?',
      'Você de amanhã vai agradecer: revise um pouco.',
    ],
    'ru': [
      'Ты уже повторил сегодня или оставим на завтра?',
      'Твоя серия ждёт: один уровень — и она жива.',
      'Пять минут химии: рискнёшь пройти уровень?',
      'Ты завтрашний скажешь спасибо: повтори немного.',
    ],
  };

  // --- Notificaciones de la actualización (fix3, punto 20) ---
  //
  // Mismo plugin, mismo icono pequeño (campana blanca ic_notif_bell,
  // que Android NO pinta como cuadrado negro) y mismo acento teal
  // que los recordatorios. La descarga usa su propio canal para
  // silenciarse aparte; el recordatorio usa el canal de repaso.
  // Todas las llamadas son "lo mejor posible": si el plugin falla
  // (sin permiso, sin plugin en pruebas), devuelven false y la app
  // sigue normal. OJO: scheduleNext() hace cancelAll(), así que si
  // se reprograman los recordatorios de estudio, el recordatorio de
  // actualización se borra con ellos; la comprobación diaria de
  // UpdateCheckService lo vuelve a programar al abrir la app.

  /// Programa el recordatorio de "Hay una actualización pendiente"
  /// para [at]. Al tocarlo, la app se abre y sale el diálogo.
  static Future<bool> scheduleUpdateReminder({
    required String body,
    required DateTime at,
  }) async {
    try {
      final details = await _updateReminderDetails();
      await _scheduleOne(
        _updateReminderId,
        body,
        tz.TZDateTime.from(at, tz.local),
        details,
        payload: updatePayload,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Cancela el recordatorio de actualización (ya se actualizó).
  static Future<void> cancelUpdateReminder() async {
    try {
      await _plugin.cancel(id: _updateReminderId);
    } catch (_) {
      // Sin plugin, no hay nada que cancelar.
    }
  }

  /// Detalles del recordatorio de actualización: MISMO canal, icono
  /// y estilo que los recordatorios de repaso (icono grande con el
  /// compañero del día, acento teal), pero sin la acción "Repasar ahora".
  static Future<NotificationDetails> _updateReminderDetails() async {
    final largeIcon = await _twinLargeIcon();
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: _smallIcon,
        color: AppAccent.primary,
        largeIcon: largeIcon,
      ),
    );
  }

  /// Detalles de la notificación de descarga: canal propio, icono
  /// pequeño blanco, color teal (la barra de progreso se ve verde
  /// sobre el fondo blanco del sistema) y barra de progreso limpia.
  ///
  /// Zona C (2026-11-12): cuando el total aún no se conoce
  /// ([indeterminate] true), la barra es indeterminada
  /// (AndroidNotificationDetails.indeterminate, soportado por
  /// flutter_local_notifications 23.0.0: el lado Java llama a
  /// NotificationCompat.Builder.setProgress(max, progress, true)).
  /// Así la descarga se ve desde el primer instante, aunque el
  /// servidor no haya dicho el tamaño total.
  static NotificationDetails _updateDetails({
    int? progress,
    bool ongoing = false,
    bool indeterminate = false,
    List<AndroidNotificationAction>? actions,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _updateChannelId,
        _updateChannelName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: _smallIcon,
        color: AppAccent.primary,
        showProgress: progress != null,
        maxProgress: 100,
        progress: progress ?? 0,
        indeterminate: indeterminate,
        ongoing: ongoing,
        onlyAlertOnce: true,
        autoCancel: !ongoing,
        actions: actions,
      ),
    );
  }

  /// Progreso de la descarga (id 9001, se actualiza por trozos).
  /// Tocar la notificación abre la app (y el diálogo de actualización).
  /// Con [indeterminate] true (total desconocido) la barra es
  /// indeterminada pero la notificación existe y se ve desde el
  /// primer momento; en cuanto se conoce el total, el llamador pasa
  /// a valores 0..100 determinados.
  static Future<bool> showUpdateProgress({
    required String title,
    required String body,
    required int progress,
    bool indeterminate = false,
  }) async {
    try {
      await _plugin.show(
        id: _updateNotifId,
        title: title,
        body: body,
        payload: updatePayload,
        notificationDetails: _updateDetails(
          progress: progress.clamp(0, 100),
          ongoing: true,
          indeterminate: indeterminate,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Descarga completa: la notificación (id 9001, reemplaza a la de
  /// progreso) ofrece "Instalar" y al tocarla instala el APK.
  static Future<bool> showUpdateReady({
    required String title,
    required String body,
    required String installLabel,
  }) async {
    try {
      await _plugin.show(
        id: _updateNotifId,
        title: title,
        body: body,
        payload: installActionId,
        notificationDetails: _updateDetails(actions: [
          AndroidNotificationAction(installActionId, installLabel),
        ]),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// La descarga falló: avisa (no es silencio: el usuario la pidió).
  static Future<bool> showUpdateFailed({
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.show(
        id: _updateNotifId,
        title: title,
        body: body,
        payload: updatePayload,
        notificationDetails: _updateDetails(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Quita la notificación de descarga (al fallar o al cancelarse).
  static Future<void> cancelUpdateProgress() async {
    try {
      await _plugin.cancel(id: _updateNotifId);
    } catch (_) {
      // Sin plugin, no hay nada que cancelar.
    }
  }
}

/// Qué pasó con la prueba de aviso (Zona G, Quemia 7.1): el
/// resultado TIPADO que devuelve [NotificationService.sendTestDetailed]
/// para que la pantalla nombre la causa real en vez del genérico
/// "error del sistema".
enum NotificationTestOutcome {
  /// El show() completó: el aviso se envió de verdad.
  sent,

  /// El sistema no deja avisar (permiso denegado en el momento del
  /// notify): el único arreglo es "Ir a Ajustes".
  permissionDenied,

  /// El canal 'quemia_prueba_avisos' está desactivado en Ajustes:
  /// el show() no lanzaría (el aviso se descartaría en silencio),
  /// así que hay que detectarlo antes de enviar.
  channelBlocked,

  /// El show() lanzó otra cosa (icono no válido, plugin sin
  /// registrar, error interno): [NotificationTestResult.detail]
  /// trae el texto real del error.
  pluginError,
}

/// Resultado de [NotificationService.sendTestDetailed]: qué pasó con
/// la prueba y, si falló por un error del plugin, el texto real del
/// error (corto, apto para un snackbar).
class NotificationTestResult {
  const NotificationTestResult(this.outcome, [this.detail]);

  final NotificationTestOutcome outcome;

  /// Texto real del fallo (para [NotificationTestOutcome.pluginError]
  /// y, a veces, [NotificationTestOutcome.permissionDenied]): la
  /// excepción tal y como llegó del plugin, recortada a 120
  /// caracteres. null cuando no hay detalle que mostrar.
  final String? detail;

  bool get sent => outcome == NotificationTestOutcome.sent;
}

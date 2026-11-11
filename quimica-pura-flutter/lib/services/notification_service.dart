// Notificaciones locales REALES de Melli-Qui (v6, fix3 punto 9).
//
// El recordatorio viejo solo guardaba una hora y nunca avisaba. Esto
// programa notificaciones locales de verdad con
// flutter_local_notifications + timezone:
//  - llegan a intervalos ALEATORIOS, siempre con MÁS DE 1 HORA entre
//    una y otra (61-180 minutos), nunca en avalancha, EXCEPTO la
//    primera, que llega pronto (20-50 min) para que el usuario vea
//    que funciona y no crea que no avisa nunca;
//  - los mensajes rotan al azar (repaso, racha, pregunta del día,
//    repaso de tu tema más débil), SIEMPRE con el nombre bonito del
//    tema ("Estequiometría y el mol"), nunca con el id interno
//    ("bach-estequiometria");
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
//     pequeño es un vector blanco (res/drawable/ic_notif_bell.xml)
//     y el icono grande es el compañero del día.
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

import 'dart:async';
import 'dart:io';
import 'dart:math';

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

  /// Horas ISO de los 3 avisos programados, separadas por comas (la
  /// PRIMERA es el próximo aviso; se guardan las 3 para poder saltar
  /// las que ya pasaron sin abrir la app). La lee la pantalla de
  /// Recordatorios para mostrar "Próximo aviso: …".
  static const _kNextNotifs = 'melli_notif_next';
  static const _kExactAlarms = 'melli_notif_exact';
  static const _channelId = 'melli_study_reminders';
  static const _channelName = 'Recordatorios de estudio';

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

  /// Icono pequeño: campana blanca (vector), no el logo a color, que
  /// Android pinta como un cuadrado negro.
  static const _smallIcon = 'ic_notif_bell';

  static bool _ready = false;

  /// ¿Se pueden usar alarmas exactas? Se decide al activar los
  /// recordatorios (se pide SCHEDULE_EXACT_ALARM) y se guarda. Si no
  /// está dado, las alarmas son inexactas y Doze puede retrasarlas
  /// horas: se sigue avisando, pero tarde.
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
  static Future<bool> init() async {
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
            unawaited(
              reconcileFiredReminders().then((_) => scheduleNext()),
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
      if (UserPrefs.reminderOn) {
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
  /// no pide nada. Si la plataforma no responde, se asume que sí
  /// (en Android < 13 no hay permiso que pedir).
  static Future<bool> get isPermissionGranted async {
    if (!_ready) {
      final ok = await init();
      if (!ok) return true;
    }
    try {
      // areNotificationsEnabled vive en la implementación de
      // Android (no en el plugin ni en la interfaz abstracta): en
      // Android 13+ dice si POST_NOTIFICATIONS está concedido;
      // antes, si los avisos están activados.
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Pide el permiso de notificaciones (muestra el diálogo del
  /// sistema la primera vez). Devuelve si quedó concedido. Extraído
  /// de [enable] para reutilizarlo en la pantalla de Recordatorios,
  /// en el botón de prueba y en el onboarding (fix4, punto 3).
  static Future<bool> requestPermission() async {
    if (!_ready) {
      final ok = await init();
      if (!ok) return false;
    }
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? true;
    } catch (_) {
      // En Android < 13 no hay permiso que pedir.
      return true;
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

  /// Activa los recordatorios: pide el permiso (Android 13+), pide el
  /// permiso de alarmas exactas (Android 12+, en Android 14+ abre los
  /// ajustes del sistema), guarda el ajuste y programa la primera
  /// tanda (el primer aviso llega dentro de la primera hora). Si el
  /// permiso está denegado de forma permanente, el sistema ya no
  /// muestra su diálogo y devuelve false: la UI ofrece entonces
  /// "Ir a Ajustes" (fix4, punto 3).
  static Future<bool> enable() async {
    if (!await requestPermission()) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // Alarmas exactas: sin este permiso, Doze retrasa los avisos
      // horas. Si el sistema abre los ajustes y el usuario no lo
      // concede, se sigue con alarmas inexactas (llegan tarde, pero
      // llegan). No bloquea la activación.
      try {
        final exact = await android?.requestExactAlarmsPermission();
        _exactAlarms = exact == true;
      } catch (_) {
        _exactAlarms = false;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kExactAlarms, _exactAlarms);
    } catch (_) {
      // En Android < 13 no hay permiso que pedir.
    }
    await UserPrefs.saveReminder(
        true, UserPrefs.reminderHour, UserPrefs.reminderMinute);
    await scheduleNext();
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

  /// Registra en la bandeja de Notificaciones los recordatorios de
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

  /// Detalles de la notificación: icono pequeño blanco (vector),
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
        color: const Color(0xFF00C2A8),
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

  /// Una notificación de prueba, ahora mismo (botón "Probar" del
  /// recordatorio). Sirve para comprobar en el teléfono que los avisos
  /// llegan y que el permiso está dado. Usa los mismos detalles que
  /// los avisos programados (icono, gemela y acción).
  static Future<void> sendTest() async {
    if (!_ready) {
      final ok = await init();
      if (!ok) return;
    }
    await _plugin.show(
      id: 9999,
      title: 'Quemia',
      body: _pickMessage(Random()),
      payload: reviewPayload,
      notificationDetails: await _details(),
    );
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
      '¿Ya hiciste la pregunta del día?',
      'Cinco minutos de química: ¿te atreves con un nivel?',
      'Tu yo de mañana te lo va a agradecer: repasa un poco.',
    ],
    'en': [
      'Did you review today or shall we leave it for tomorrow?',
      'Your streak is waiting: one level and it stays alive.',
      'Did you do today’s question yet?',
      'Five minutes of chemistry: fancy a level?',
      'Your tomorrow self will thank you: review a little.',
    ],
    'fr': [
      'As-tu déjà révisé aujourd’hui ou on remet à demain ?',
      'Ta série t’attend : un niveau et elle reste en vie.',
      'As-tu fait la question du jour ?',
      'Cinq minutes de chimie : tu tentes un niveau ?',
      'Ton toi de demain te remerciera : révise un peu.',
    ],
    'it': [
      'Hai già ripassato oggi o rimandiamo a domani?',
      'La tua serie ti aspetta: un livello e resta viva.',
      'Hai già fatto la domanda del giorno?',
      'Cinque minuti di chimica: ti va un livello?',
      'Il te di domani ti ringrazierà: ripassa un po’.',
    ],
    'pt': [
      'Você já revisou hoje ou deixamos para amanhã?',
      'Sua sequência está esperando: um nível e ela continua viva.',
      'Você já fez a pergunta do dia?',
      'Cinco minutos de química: topa um nível?',
      'Você de amanhã vai agradecer: revise um pouco.',
    ],
    'ru': [
      'Ты уже повторил сегодня или оставим на завтра?',
      'Твоя серия ждёт: один уровень — и она жива.',
      'Ты уже ответил на вопрос дня?',
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
        color: const Color(0xFF00C2A8),
        largeIcon: largeIcon,
      ),
    );
  }

  /// Detalles de la notificación de descarga: canal propio, icono
  /// pequeño blanco, color teal (la barra de progreso se ve verde
  /// sobre el fondo blanco del sistema) y barra de progreso limpia.
  static NotificationDetails _updateDetails({
    int? progress,
    bool ongoing = false,
    List<AndroidNotificationAction>? actions,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _updateChannelId,
        _updateChannelName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: _smallIcon,
        color: const Color(0xFF00C2A8),
        showProgress: progress != null,
        maxProgress: 100,
        progress: progress ?? 0,
        ongoing: ongoing,
        onlyAlertOnce: true,
        autoCancel: !ongoing,
        actions: actions,
      ),
    );
  }

  /// Progreso de la descarga (id 9001, se actualiza por trozos).
  /// Tocar la notificación abre la app (y el diálogo de actualización).
  static Future<bool> showUpdateProgress({
    required String title,
    required String body,
    required int progress,
  }) async {
    try {
      await _plugin.show(
        id: _updateNotifId,
        title: title,
        body: body,
        payload: updatePayload,
        notificationDetails:
            _updateDetails(progress: progress.clamp(0, 100), ongoing: true),
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

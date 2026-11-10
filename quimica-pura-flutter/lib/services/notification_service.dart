// Notificaciones locales REALES de Melli-Qui (v6).
//
// El recordatorio viejo solo guardaba una hora y nunca avisaba. Esto
// programa notificaciones locales de verdad con
// flutter_local_notifications + timezone:
//  - llegan a intervalos ALEATORIOS, siempre con MÁS DE 1 HORA entre
//    una y otra (61-180 minutos), nunca en avalancha;
//  - los mensajes rotan al azar (repaso, racha, pregunta del día,
//    repaso de tu tema más débil);
//  - se programan 3 seguidas por delante, para que lleguen aunque la
//    app lleve días sin abrirse; al abrir la app (o al tocar una
//    notificación) se vuelve a programar la tanda;
//  - el ajuste (activado/apagado) y la hora de la última notificación
//    programada se guardan en el teléfono.
//
// Qué está verificado y qué no: el código compila (flutter analyze) y
// la lógica de intervalos/mensajes tiene pruebas (test/
// notification_logic_test.dart). Que la notificación aparezca en la
// barra del teléfono solo se puede confirmar en el teléfono: depende
// del permiso (Android 13+ lo pide al activar el recordatorio) y de
// que el sistema no mate la app en segundo plano.

import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../data/i18n/content_i18n.dart';
import '../data/questions.dart';
import 'localization.dart';
import 'progress.dart';
import 'user_prefs.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _kLastNotif = 'melli_notif_last';
  static const _channelId = 'melli_study_reminders';
  static const _channelName = 'Recordatorios de estudio';

  static bool _ready = false;

  /// Intervalo entre avisos, en minutos: siempre más de 1 hora.
  static const int minGapMinutes = 61;
  static const int maxGapMinutes = 180;

  /// ¿La próxima notificación debe llegar dentro de estos márgenes?
  /// (Para pruebas: el aviso llega entre 61 y 180 min después de ahora.)
  static bool gapIsValid(int minutes) =>
      minutes >= minGapMinutes && minutes <= maxGapMinutes;

  /// Un hueco aleatorio entre dos avisos: siempre más de 1 hora
  /// (61-180 minutos). Función pura para poder probarla.
  static int nextGapMinutes(Random rng) =>
      minGapMinutes + rng.nextInt(maxGapMinutes - minGapMinutes + 1);

  /// Inicializa el plugin y, si el recordatorio está activado, programa
  /// la próxima tanda. No pide el permiso aquí: se pide al activar el
  /// recordatorio, para no asustar al abrir la app por primera vez.
  static Future<bool> init() async {
    try {
      tz.initializeTimeZones();
      try {
        final tzInfo = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
      } catch (_) {
        // Sin zona horaria del sistema: se usa la local por defecto.
      }
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        settings: const InitializationSettings(android: androidSettings),
        onDidReceiveNotificationResponse: (_) => scheduleNext(),
      );
      _ready = true;
      if (UserPrefs.reminderOn) {
        await scheduleNext();
      }
      return true;
    } catch (_) {
      _ready = false;
      return false;
    }
  }

  /// Activa los recordatorios: pide el permiso (Android 13+), guarda
  /// el ajuste y programa la primera tanda.
  static Future<bool> enable() async {
    if (!_ready) {
      final ok = await init();
      if (!ok) return false;
    }
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted =
          await android?.requestNotificationsPermission() ?? true;
      if (granted == false) return false;
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
    await UserPrefs.saveReminder(
        false, UserPrefs.reminderHour, UserPrefs.reminderMinute);
  }

  /// Programa 3 avisos por delante, cada uno 61-180 min después del
  /// anterior. Devuelve las horas programadas (para depurar).
  static Future<List<DateTime>> scheduleNext({Random? rng}) async {
    final random = rng ?? Random();
    final now = tz.TZDateTime.now(tz.local);
    var at = now;
    final scheduled = <DateTime>[];
    try {
      await _plugin.cancelAll();
      for (var i = 0; i < 3; i++) {
        final gap = nextGapMinutes(random);
        at = at.add(Duration(minutes: gap));
        final message = _pickMessage(random);
        await _plugin.zonedSchedule(
          id: 100 + i,
          title: 'Melli-Qui',
          body: message,
          scheduledDate: at,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        scheduled.add(at);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kLastNotif, scheduled.isEmpty ? '' : scheduled.last.toIso8601String());
    } catch (_) {
      // Si programar falla (p. ej. sin plugin en pruebas), no se rompe
      // la app: el recordatorio simplemente no llega.
    }
    return scheduled;
  }

  /// Una notificación de prueba, ahora mismo (botón "Probar" del
  /// recordatorio). Sirve para comprobar en el teléfono que los avisos
  /// llegan y que el permiso está dado.
  static Future<void> sendTest() async {
    if (!_ready) {
      final ok = await init();
      if (!ok) return;
    }
    await _plugin.show(
      id: 9999,
      title: 'Melli-Qui',
      body: _pickMessage(Random()),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// Elige un mensaje al azar en el idioma actual. Una de cada tres
  /// veces, si hay un tema débil, el mensaje es un repaso de ese tema.
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
      final topic = localizedTopicName(weakest.first);
      return _weakTopicMessage(lang, topic);
    }
    return generic[rng.nextInt(generic.length)];
  }

  /// Mensaje de repaso del tema más débil.
  static String _weakTopicMessage(String lang, String topic) {
    switch (lang) {
      case 'en':
        return 'Time to review $topic, your weakest topic.';
      case 'fr':
        return 'Il est temps de réviser $topic, ton point faible.';
      case 'it':
        return 'È ora di ripassare $topic, il tuo punto debole.';
      case 'pt':
        return 'Hora de revisar $topic, seu ponto fraco.';
      case 'ru':
        return 'Пора повторить $topic — твою самую слабую тему.';
      default:
        return 'Toca repasar $topic, tu tema más flojo.';
    }
  }

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
}

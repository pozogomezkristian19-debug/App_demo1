// Datos guardados en el teléfono, sin internet (SharedPreferences).
// Aquí viven el onboarding (nombre y género), el saludo y el tema claro/oscuro.

import 'package:shared_preferences/shared_preferences.dart';

class UserPrefs {
  UserPrefs._();

  static const _kOnboardingDone = 'melli_onboarding_done';
  static const _kUserName = 'melli_user_name';
  static const _kUserGender = 'melli_user_gender'; // 'Femenino' o 'Masculino'
  static const _kDarkMode = 'melli_dark_mode';
  static const _kLanguage = 'melli_language'; // 'es' | 'en' | 'fr' | 'it' | 'pt' | 'ru'
  static const _kTrack = 'melli_track'; // 'uni' | 'bach'
  static const _kSoundOn = 'melli_sound_on';
  static const _kReminderOn = 'melli_reminder_on';
  static const _kReminderHour = 'melli_reminder_hour';
  static const _kReminderMinute = 'melli_reminder_minute';
  static const _kAvatar = 'melli_avatar'; // 'm0'..'m2' | 'f0'..'f2'
  static const _kRulesSeenV6 = 'melli_rules_seen_v6';
  static const _kMetBrenda = 'melli_met_brenda';
  static const _kMetBritany = 'melli_met_britany';

  static bool onboardingDone = false;
  static String userName = '';
  static String userGender = '';
  static bool isDark = false; // La app nace clara (tema claro por
  // defecto); se puede cambiar con el botoncito.
  static String language = 'es';
  static String track = 'uni';
  static bool soundOn = true; // Sonidos y vibración al contestar.
  static bool reminderOn = false; // Recordatorio diario de estudio.
  static int reminderHour = 19;
  static int reminderMinute = 0;
  static String avatar = ''; // Avatar elegido ('' = el de su género).
  static bool rulesSeenV6 = false; // ¿Ya vio la ventanita de reglas v6?
  static bool metBrenda = false; // ¿Brenda ya se presentó?
  static bool metBritany = false; // ¿Britany ya se presentó?

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    onboardingDone = prefs.getBool(_kOnboardingDone) ?? false;
    userName = prefs.getString(_kUserName) ?? '';
    userGender = prefs.getString(_kUserGender) ?? '';
    isDark = prefs.getBool(_kDarkMode) ?? false; // Sin preferencia guardada: claro.
    language = prefs.getString(_kLanguage) ?? 'es';
    track = prefs.getString(_kTrack) ?? 'uni';
    soundOn = prefs.getBool(_kSoundOn) ?? true;
    reminderOn = prefs.getBool(_kReminderOn) ?? false;
    reminderHour = prefs.getInt(_kReminderHour) ?? 19;
    reminderMinute = prefs.getInt(_kReminderMinute) ?? 0;
    avatar = prefs.getString(_kAvatar) ?? '';
    rulesSeenV6 = prefs.getBool(_kRulesSeenV6) ?? false;
    metBrenda = prefs.getBool(_kMetBrenda) ?? false;
    metBritany = prefs.getBool(_kMetBritany) ?? false;
  }

  static Future<void> saveProfile(String name, String gender) async {
    final prefs = await SharedPreferences.getInstance();
    userName = name.trim();
    userGender = gender;
    onboardingDone = true;
    await prefs.setString(_kUserName, userName);
    await prefs.setString(_kUserGender, userGender);
    await prefs.setBool(_kOnboardingDone, true);
  }

  static Future<void> saveDarkMode(bool dark) async {
    final prefs = await SharedPreferences.getInstance();
    isDark = dark;
    await prefs.setBool(_kDarkMode, dark);
  }

  static Future<void> saveLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    language = code;
    await prefs.setString(_kLanguage, code);
  }

  static Future<void> saveTrack(String t) async {
    final prefs = await SharedPreferences.getInstance();
    track = t;
    await prefs.setString(_kTrack, t);
  }

  static Future<void> saveSoundOn(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    soundOn = on;
    await prefs.setBool(_kSoundOn, on);
  }

  static Future<void> saveReminder(bool on, int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    reminderOn = on;
    reminderHour = hour;
    reminderMinute = minute;
    await prefs.setBool(_kReminderOn, on);
    await prefs.setInt(_kReminderHour, hour);
    await prefs.setInt(_kReminderMinute, minute);
  }

  static Future<void> saveAvatar(String id) async {
    final prefs = await SharedPreferences.getInstance();
    avatar = id;
    await prefs.setString(_kAvatar, id);
  }

  static Future<void> saveRulesSeenV6() async {
    final prefs = await SharedPreferences.getInstance();
    rulesSeenV6 = true;
    await prefs.setBool(_kRulesSeenV6, true);
  }

  /// La gemela se acaba de presentar por primera vez.
  static Future<void> saveMetTwin(bool twinA) async {
    final prefs = await SharedPreferences.getInstance();
    if (twinA) {
      metBrenda = true;
      await prefs.setBool(_kMetBrenda, true);
    } else {
      metBritany = true;
      await prefs.setBool(_kMetBritany, true);
    }
  }

  /// Saludo de cada entrada: "Bienvenida Ana" o "Bienvenido Luis".
  static String get greeting {
    if (userName.isEmpty) return 'Hola';
    final word = userGender == 'Femenino' ? 'Bienvenida' : 'Bienvenido';
    return '$word $userName';
  }
}

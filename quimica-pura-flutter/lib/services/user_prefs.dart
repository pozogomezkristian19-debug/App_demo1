// Datos guardados en el teléfono, sin internet (SharedPreferences).
// Aquí viven el onboarding (nombre y género), el saludo y el tema claro/oscuro.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserPrefs {
  UserPrefs._();

  static const _kOnboardingDone = 'melli_onboarding_done';
  static const _kUserName = 'melli_user_name';
  static const _kUserGender = 'melli_user_gender'; // 'Femenino' o 'Masculino'
  static const _kDarkMode = 'melli_dark_mode';
  static const _kThemeMode =
      'melli_theme_mode'; // 'claro' | 'oscuro' | 'sistema'
  static const _kLanguage =
      'melli_language'; // 'es' | 'en' | 'fr' | 'it' | 'pt' | 'ru'
  static const _kTrack = 'melli_track'; // 'uni' | 'bach'
  static const _kSoundOn = 'melli_sound_on';
  static const _kReminderOn = 'melli_reminder_on';
  static const _kReminderHour = 'melli_reminder_hour';
  static const _kReminderMinute = 'melli_reminder_minute';
  static const _kAvatar = 'melli_avatar'; // 'm0'..'m2' | 'f0'..'f2'
  static const _kThemeAccent = 'melli_theme_accent'; // 'verde' | 'violeta'
  static const _kRulesSeenV6 = 'melli_rules_seen_v6';
  static const _kMetBrenda = 'melli_met_brenda';
  static const _kMetBritany = 'melli_met_britany';
  static const _kMetKristian = 'melli_met_kristian';

  static bool onboardingDone = false;
  static String userName = '';
  static String userGender = '';
  static bool isDark = false; // Valor EFECTIVO ahora (con 'sistema',
  // el brillo del teléfono en este momento).
  // Modo de tema (fix3, punto 13): 'claro' | 'oscuro' | 'sistema'.
  // 'sistema' sigue al brillo del teléfono. El cambio de tema vive
  // SOLO en Cuenta (sección "Tema"): al cambiar, themeModeNotifier
  // avisa y la app reconstruye el tema en el acto (ver main.dart).
  // Por defecto es 'sistema' (ronda fix6, ítem 3): quien no haya
  // elegido nunca sigue al teléfono; quien guardó 'claro' u
  // 'oscuro' lo mantiene, porque su valor guardado manda.
  static String themeMode = 'sistema';
  static final ValueNotifier<String> themeModeNotifier =
      ValueNotifier('sistema');

  /// ¿Está oscuro el tema AHORA? Con 'sistema', manda el brillo del
  /// teléfono en este momento. Con 'claro'/'oscuro', el modo elegido.
  static bool get effectiveDark {
    if (themeMode == 'oscuro') return true;
    if (themeMode == 'sistema') {
      return PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    }
    return false;
  }

  static String language = 'es';
  static String track = 'uni';
  static bool soundOn = true; // Sonidos y vibración al contestar.
  static bool reminderOn = false; // Recordatorio diario de estudio.
  static int reminderHour = 19;
  static int reminderMinute = 0;
  static String avatar = ''; // Avatar elegido ('' = el de su género).
  // MUERTO desde la ronda fix5, punto 1 (Quemia 6.2): el diálogo
  // "Cómo se juega" ya no sale solo en la primera entrada a Niveles
  // (ahora es una pantalla que se abre desde Cuenta), así que nada
  // en lib/ lee ni escribe este flag. Se CONSERVA el campo, su
  // lectura en load() y saveRulesSeenV6() solo para no romper la
  // veintena de tests viejos que lo ponen a true/false en su setUp
  // (fuera del ámbito de esta ronda): quitarlo exige tocarlos
  // todos. La próxima limpieza lo puede borrar junto con ellos.
  static bool rulesSeenV6 = false; // ¿Ya vio la ventanita de reglas v6?
  // Tema de acento (fix2 2026-11-10): 'verde' (teal de siempre) o
  // 'violeta' (el acento actual). Se guarda en el teléfono y la app
  // se reconstruye al cambiar gracias a themeAccentNotifier.
  static String themeAccent = 'verde';
  static final ValueNotifier<String> themeAccentNotifier =
      ValueNotifier('verde');
  static bool metBrenda = false; // ¿Brenda ya se presentó?
  static bool metBritany = false; // ¿Britany ya se presentó?
  static bool metKristian = false; // ¿Kristian ya se presentó?

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    onboardingDone = prefs.getBool(_kOnboardingDone) ?? false;
    userName = prefs.getString(_kUserName) ?? '';
    userGender = prefs.getString(_kUserGender) ?? '';
    isDark = prefs.getBool(_kDarkMode) ?? false; // Booleano viejo
    // (legado): sin guardar, false.
    // Modo de tema (fix3, punto 13): si no hay valor guardado
    // (versión anterior), se migra del booleano claro/oscuro de
    // antes: isDark=true da 'oscuro'. Sin nada guardado, el defecto
    // es 'sistema' (ronda fix6, ítem 3), que sigue al brillo del
    // teléfono. Un valor raro se sanea a claro. isDark queda como el
    // valor EFECTIVO (con 'sistema', el brillo del teléfono ahora).
    themeMode = prefs.getString(_kThemeMode) ?? (isDark ? 'oscuro' : 'sistema');
    if (themeMode != 'oscuro' && themeMode != 'sistema') {
      themeMode = 'claro';
    }
    themeModeNotifier.value = themeMode;
    isDark = effectiveDark;
    language = prefs.getString(_kLanguage) ?? 'es';
    track = prefs.getString(_kTrack) ?? 'uni';
    soundOn = prefs.getBool(_kSoundOn) ?? true;
    reminderOn = prefs.getBool(_kReminderOn) ?? false;
    reminderHour = prefs.getInt(_kReminderHour) ?? 19;
    reminderMinute = prefs.getInt(_kReminderMinute) ?? 0;
    avatar = prefs.getString(_kAvatar) ?? '';
    themeAccent = prefs.getString(_kThemeAccent) ?? 'verde';
    if (themeAccent != 'violeta') themeAccent = 'verde';
    themeAccentNotifier.value = themeAccent;
    rulesSeenV6 = prefs.getBool(_kRulesSeenV6) ?? false;
    metBrenda = prefs.getBool(_kMetBrenda) ?? false;
    metBritany = prefs.getBool(_kMetBritany) ?? false;
    metKristian = prefs.getBool(_kMetKristian) ?? false;
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

  /// El viejo interruptor claro/oscuro (el icono de la AppBar):
  /// equivale a elegir el modo 'oscuro' o 'claro'.
  static Future<void> saveDarkMode(bool dark) async {
    await saveThemeMode(dark ? 'oscuro' : 'claro');
  }

  /// Guarda el modo de tema ('claro' | 'oscuro' | 'sistema') y avisa
  /// a la app para que reconstruya el tema en el acto. Mantiene el
  /// booleano viejo (melli_dark_mode) sincronizado con el valor
  /// efectivo, por compatibilidad. Un valor raro se sanea a claro.
  static Future<void> saveThemeMode(String mode) async {
    final value = mode == 'oscuro' || mode == 'sistema' ? mode : 'claro';
    final prefs = await SharedPreferences.getInstance();
    themeMode = value;
    isDark = effectiveDark;
    themeModeNotifier.value = value;
    await prefs.setString(_kThemeMode, value);
    await prefs.setBool(_kDarkMode, isDark);
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

  /// Guarda el tema de acento ('verde' o 'violeta') y avisa a la app
  /// para que reconstruya el tema en el acto.
  static Future<void> saveThemeAccent(String accent) async {
    final value = accent == 'violeta' ? 'violeta' : 'verde';
    final prefs = await SharedPreferences.getInstance();
    themeAccent = value;
    themeAccentNotifier.value = value;
    await prefs.setString(_kThemeAccent, value);
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

  /// Kristian se acaba de presentar por primera vez.
  static Future<void> saveMetKristian() async {
    final prefs = await SharedPreferences.getInstance();
    metKristian = true;
    await prefs.setBool(_kMetKristian, true);
  }

  /// Primer nombre del usuario (primera palabra del nombre
  /// guardado); vacío si no hay nombre.
  static String get firstName {
    final name = userName.trim();
    if (name.isEmpty) return '';
    return name.split(RegExp(r'\s+')).first;
  }

  /// Saludo de cada entrada: "Bienvenido [primer nombre]" o
  /// "Bienvenida [primer nombre]" según el género guardado.
  /// Sin nombre guardado, "Hola" como antes.
  static String get greeting {
    if (userName.isEmpty) return 'Hola';
    final word = userGender == 'Femenino' ? 'Bienvenida' : 'Bienvenido';
    return '$word $firstName';
  }
}

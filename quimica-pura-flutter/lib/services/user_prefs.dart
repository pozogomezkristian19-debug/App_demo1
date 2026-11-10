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

  static bool onboardingDone = false;
  static String userName = '';
  static String userGender = '';
  static bool isDark = true; // La app nació oscura; se puede cambiar con el botoncito.
  static String language = 'es';
  static String track = 'uni';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    onboardingDone = prefs.getBool(_kOnboardingDone) ?? false;
    userName = prefs.getString(_kUserName) ?? '';
    userGender = prefs.getString(_kUserGender) ?? '';
    isDark = prefs.getBool(_kDarkMode) ?? true;
    language = prefs.getString(_kLanguage) ?? 'es';
    track = prefs.getString(_kTrack) ?? 'uni';
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

  /// Saludo de cada entrada: "Bienvenida Ana" o "Bienvenido Luis".
  static String get greeting {
    if (userName.isEmpty) return 'Hola';
    final word = userGender == 'Femenino' ? 'Bienvenida' : 'Bienvenido';
    return '$word $userName';
  }
}

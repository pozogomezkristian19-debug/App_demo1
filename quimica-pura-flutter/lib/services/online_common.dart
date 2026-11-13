// Piezas comunes de todo lo online (7.0): puerta de identidad,
// timeout de 10 s y cola de reintento en local.
//
// REGLA DE IDENTIDAD (Kristian 09:19): para jugar online hay que
// tener la cuenta de Google vinculada. La sesión anónima sola NO
// habilita nada online. Cada servicio online comprueba primero
// [OnlineCommon.allowed] y, sin Google, devuelve el estado
// "necesita Google" sin error ni excepción (listas vacías, null o
// false, según el método). La UI lo sabe por
// [AnalyticsSync.needsGoogle].
//
// REGLA 2 (Kristian 6.5): sin internet no pasa nada malo. Cada
// llamada a la red lleva timeout de 10 s y falla en silencio; lo que
// no se pudo enviar queda encolado en shared_preferences y se
// reintenta solo al abrir la app y al volver a primer plano.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_sync.dart';

class OnlineCommon {
  OnlineCommon._();

  /// Timeout de cada llamada a la red (Regla 2). Quemia 7.5: era
  /// 5 s, pero con la conexión lenta de Cuba + VPN una llamada
  /// normal tarda 6-9 s (la primera, con el apretón de manos,
  /// aún más). A 5 s se cortaba, se reintentaba y al final tardaba
  /// MÁS que esperando un poco. A 10 s casi todo entra al primer
  /// intento; sin internet de verdad, la llamada falla en silencio
  /// igual, solo que 5 s más tarde y en segundo plano.
  static const Duration timeout = Duration(seconds: 10);

  /// ¿Se puede jugar online? Solo con Google vinculada.
  static bool get allowed => AnalyticsSync.onlinePlayAllowed;

  /// ¿Falta vincular Google para jugar online?
  static bool get needsGoogle => !allowed;

  /// Una llamada a la red con timeout de 10 s y silencio total ante
  /// fallos: devuelve null si no hay internet, si cuelga o si el
  /// servidor rechaza. Nunca lanza.
  static Future<T?> call<T>(Future<T> Function() fn) async {
    try {
      return await fn().timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  /// Una escritura a la red con timeout y silencio: true si llegó,
  /// false si quedó pendiente (el llamador la encola).
  static Future<bool> write(Future<void> Function() fn) async {
    try {
      await fn().timeout(timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---- Cola de reintento (prefs, JSON) ----

  static Future<List<Map<String, dynamic>>> pending(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> enqueue(
      String key, Map<String, dynamic> item) async {
    try {
      final items = await pending(key);
      items.add(item);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(items));
    } catch (_) {
      // Sin almacenamiento no se puede encolar: se pierde el reintento.
    }
  }

  static Future<void> removeAt(String key, int index) async {
    try {
      final items = await pending(key);
      if (index < 0 || index >= items.length) return;
      items.removeAt(index);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(items));
    } catch (_) {
      // Sin almacenamiento no se puede limpiar: se reintentará.
    }
  }

  static Future<int> pendingCount(String key) async =>
      (await pending(key)).length;
}

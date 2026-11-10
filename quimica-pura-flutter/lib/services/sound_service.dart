// Sonidos propios de Melli-Qui (v6): archivos WAV cortos generados
// con un script (ver assets/sounds/), sin internet y sin depender de
// los sonidos del sistema. Cada sonido va con su vibración, para que
// acertar, fallar, pasar de nivel y la racha se sientan distintos.
//
// Si el audio falla en el teléfono (o el usuario apagó "Sonido y
// vibración" en Mis estadísticas), el servicio cae a SystemSound y a
// HapticFeedback, y nunca rompe la app: todos los errores se tragan.

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'user_prefs.dart';

class SoundService {
  SoundService._();
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> _play(String file, {bool heavy = false}) async {
    if (!UserPrefs.soundOn) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/$file'));
      if (heavy) {
        await HapticFeedback.heavyImpact();
      } else {
        await HapticFeedback.lightImpact();
      }
    } catch (_) {
      // Sin audio: vibración, y nada más.
      try {
        await HapticFeedback.lightImpact();
      } catch (_) {}
    }
  }

  /// Acierto: campanita de dos notas + vibración suave.
  static Future<void> correct() => _play('correct.wav');

  /// Fallo: zumbido grave descendente + vibración fuerte.
  static Future<void> wrong() async {
    if (!UserPrefs.soundOn) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/wrong.wav'));
      await HapticFeedback.vibrate();
    } catch (_) {
      try {
        await HapticFeedback.vibrate();
      } catch (_) {}
    }
  }

  /// Pasar de nivel: fanfarria + vibración fuerte.
  static Future<void> levelUp() => _play('levelup.wav', heavy: true);

  /// Racha / meta del día: campana cálida + vibración.
  static Future<void> streak() => _play('streak.wav', heavy: true);

  /// Toque en botones y tarjetas: clic corto + vibración leve.
  static Future<void> tap() => _play('click.wav');

  /// Solo vibración leve (para sitios donde el sonido sobra).
  static Future<void> haptic() async {
    if (!UserPrefs.soundOn) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }
}

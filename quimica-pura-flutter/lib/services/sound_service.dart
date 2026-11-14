// Sonidos propios de Melli-Qui (v6): archivos WAV cortos generados
// con un script (ver assets/sounds/), sin internet y sin depender de
// los sonidos del sistema. Cada sonido va con su vibración, para que
// acertar, fallar, pasar de nivel y la racha se sientan distintos.
//
// Si el audio falla en el teléfono (o el usuario apagó "Sonido y
// vibración" en Mis estadísticas), el servicio cae a SystemSound y a
// HapticFeedback, y nunca rompe la app: todos los errores se tragan.
//
// Toque (7.7, optimización): el clic NO usa el jugador compartido.
// Tiene su propio pool de baja latencia (AudioPool), precargado al
// arrancar: los toques rápidos se solapan en jugadores distintos en
// vez de cortarse entre sí, y tap() no espera a nada (dispara y
// olvida), así el sonido arranca al instante.

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'user_prefs.dart';

class SoundService {
  SoundService._();
  static final AudioPlayer _player = AudioPlayer();

  // Pool de baja latencia solo para el toque (click.wav): los
  // jugadores ya tienen el asset cargado, así el primer toque no
  // espera a leerlo. Se crea una vez y se reutiliza; si la
  // creación falla (sin plugin de audio), se reintenta en el
  // próximo toque.
  static Future<AudioPool>? _tapPoolFuture;

  static Future<AudioPool> _tapPool() {
    return _tapPoolFuture ??= AudioPool.createFromAsset(
      path: 'sounds/click.wav',
      maxPlayers: 3,
      playerMode: PlayerMode.lowLatency,
    );
  }

  /// Precarga el clic para que el primer toque sea instantáneo.
  /// Llamar al arrancar la app (main), sin esperar; si el sonido
  /// está apagado no hace nada. Nunca lanza.
  static Future<void> preloadTap() async {
    if (!UserPrefs.soundOn) return;
    try {
      await _tapPool();
    } catch (_) {
      _tapPoolFuture = null;
    }
  }

  /// Suena el clic en el pool de baja latencia. Dispara y olvida:
  /// no se espera al sonido. En baja latencia el pool no devuelve
  /// el jugador solo al terminar, así que se devuelve a los 300 ms
  /// (el clic dura como mucho 0,2 s) para que se pueda reutilizar.
  static Future<void> _playTap() async {
    AudioPool pool;
    try {
      pool = await _tapPool();
    } catch (_) {
      _tapPoolFuture = null;
      return;
    }
    try {
      final stop = await pool.start();
      unawaited(Future.delayed(const Duration(milliseconds: 300))
          .then((_) => stop())
          .catchError((_) {}));
    } catch (_) {
      // El clic no sonó; el pool se conserva para el próximo toque.
    }
  }

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
  /// Dispara y olvida: el Future se completa al instante (no espera
  /// al sonido ni a la vibración), así el toque nunca retrasa la
  /// pantalla y los toques rápidos se solapan en vez de cortarse.
  static Future<void> tap() async {
    if (!UserPrefs.soundOn) return;
    unawaited(HapticFeedback.lightImpact().catchError((_) {}));
    unawaited(_playTap());
  }

  /// Solo vibración leve (para sitios donde el sonido sobra).
  static Future<void> haptic() async {
    if (!UserPrefs.soundOn) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }
}

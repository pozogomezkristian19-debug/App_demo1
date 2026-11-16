import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Cuenta atrás EN VIVO de la racha (Kristian 2026-11-16): puente
/// Dart hacia el aviso nativo (MainActivity, canal
/// "com.melliqui/live_countdown"). El aviso no dice un tiempo fijo,
/// sino que muestra la cuenta atrás TICKING hasta medianoche, como
/// Duolingo, y se queda hasta que se hace la lección o llega
/// medianoche. En Android 16+ se publica como Live Update y sale en
/// Hyper Island; en Android <16 es el mismo aviso en curso con
/// cronómetro, sin isla.
///
/// Fuera de Android (web, tests) todos los métodos devuelven false
/// sin tocar el canal: la cuenta atrás es solo de la app instalada.
class LiveCountdown {
  static const MethodChannel _channel =
      MethodChannel('com.melliqui/live_countdown');

  /// Id del aviso (el mismo en nativo: LiveCountdown.NOTIFICATION_ID).
  static const int notificationId = 7001;

  /// Para tests: sin esto, en el host (Linux) Platform.isAndroid
  /// es false y ningún método llega al canal mockeado.
  @visibleForTesting
  static bool forceAndroidForTests = false;

  static bool get _isAndroid => forceAndroidForTests || Platform.isAndroid;

  /// Publica la cuenta atrás AHORA (la app está abierta).
  static Future<bool> show({
    required DateTime endsAt,
    required String title,
    required String body,
    String? largeIconPath,
    DateTime? startAt,
  }) async {
    if (!_isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('show', <String, dynamic>{
        'title': title,
        'body': body,
        'endAtMs': endsAt.millisecondsSinceEpoch,
        'startAtMs': (startAt ?? DateTime.now()).millisecondsSinceEpoch,
        'largeIconPath': largeIconPath,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Programa la cuenta atrás para las [at] con una alarma exacta
  /// (la app puede estar cerrada): el receiver nativo la publica a
  /// esa hora sin necesidad de Dart.
  static Future<bool> schedule({
    required DateTime at,
    required DateTime endsAt,
    required String title,
    required String body,
    String? largeIconPath,
  }) async {
    if (!_isAndroid) return false;
    try {
      final ok =
          await _channel.invokeMethod<bool>('schedule', <String, dynamic>{
        'atMs': at.millisecondsSinceEpoch,
        'title': title,
        'body': body,
        'endAtMs': endsAt.millisecondsSinceEpoch,
        'largeIconPath': largeIconPath,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Quita la cuenta atrás y cancela su alarma (si la había).
  static Future<bool> cancel() async {
    if (!_isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('cancel');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}

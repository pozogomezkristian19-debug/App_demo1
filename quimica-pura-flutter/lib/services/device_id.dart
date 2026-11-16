// Id ESTABLE del teléfono (Kristian 2026-11-16: la prueba no se
// puede borrar ni reinstalar):
//
// - Android: ANDROID_ID (`androidInfo.id`), que sobrevive a borrar
//   la caché y a desinstalar y volver a instalar la app. Solo un
//   restablecimiento de fábrica lo cambia (y eso ya no se puede
//   evitar sin una cuenta: con otro teléfono, la prueba es nueva,
//   como es lógico).
// - iOS: identifierForVendor, que sobrevive a reinstalar mientras
//   quede alguna app del mismo fabricante instalada.
// - Web: NO hay id estable (el navegador no lo da): null, y la
//   prueba queda como antes (local + nube con sesión).
//
// No es el `deviceId` de AnalyticsSync (un uuid inventado y
// guardado en local: se borra con la caché, justo lo que se quiere
// evitar). Se antepone el sistema (`android:` / `ios:`) para que
// un mismo valor numérico en dos sistemas no choque en la
// colección `device_trials`.
//
// La lectura va por canal de plataforma y puede fallar (sin
// plugin, permiso raro): null en ese caso, y la prueba sigue con
// local + nube, sin romperse.

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceId {
  DeviceId._();

  static String? _cached;

  /// Solo tests: fija el id que devuelve [stableId] (en tests
  /// Platform no es Android ni iOS y daría null siempre).
  static String? _override;

  @visibleForTesting
  static void setOverrideForTests(String? id) {
    _override = id;
    _cached = null;
  }

  @visibleForTesting
  static void resetForTests() {
    _override = null;
    _cached = null;
  }

  /// El id estable del teléfono, o null si no hay (web, fallo del
  /// canal). Se lee una sola vez y se guarda en memoria.
  static Future<String?> stableId() async {
    if (_override != null) return _override;
    if (_cached != null) return _cached;
    if (kIsWeb) return null;
    try {
      final info = DeviceInfoPlugin();
      String? raw;
      String? prefix;
      if (Platform.isAndroid) {
        raw = (await info.androidInfo).id;
        prefix = 'android';
      } else if (Platform.isIOS) {
        raw = (await info.iosInfo).identifierForVendor;
        prefix = 'ios';
      } else {
        return null;
      }
      if (raw == null || raw.isEmpty) return null;
      _cached = '$prefix:$raw';
      return _cached;
    } catch (_) {
      return null;
    }
  }
}

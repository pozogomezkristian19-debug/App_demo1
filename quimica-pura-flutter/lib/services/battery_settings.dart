// Ajustes de batería y de inicio automático (ronda #6, punto 2).
//
// En Xiaomi/MIUI, el ahorro de batería agresivo y el inicio
// automático denegado pueden retrasar o bloquear los avisos aunque
// el permiso de notificaciones esté dado y los receivers
// programados existan: el sistema mata la app en segundo plano y
// no la deja despertarse. Eso no se puede arreglar desde el código:
// hay que cambiarlo a mano en los Ajustes del teléfono. Para que
// Kristian no tenga que buscar la ruta, este servicio:
//
//  - consulta si la app está exenta de la optimización de batería
//    (PowerManager.isIgnoringBatteryOptimizations, API 23+; antes
//    no existe el ajuste y se devuelve true);
//  - abre DIRECTO la pantalla del sistema con la lista de apps y
//    su optimización de batería (ACTION_IGNORE_BATTERY_OPTIMIZATION
//    _SETTINGS; abrirla no necesita ningún permiso);
//  - intenta abrir el "Inicio automático" de MIUI (intent no
//    documentado, puede no existir según la versión) y, si no
//    existe, cae en la pantalla de batería.
//
// Todo pasa por el canal "com.melliqui/battery_settings" de
// MainActivity.kt (mismo patrón que el instalador de
// actualizaciones): sin dependencias nuevas. Cada método es "lo
// mejor posible": si el canal no existe (pruebas, iOS), devuelve
// null/false y la pantalla muestra que no se pudo comprobar.

import 'package:flutter/services.dart';

class BatterySettings {
  BatterySettings._();

  static const _channel =
      MethodChannel('com.melliqui/battery_settings');

  /// ¿La app está exenta de la optimización de batería? true =
  /// "Sin restricciones" (bien); false = optimizada (puede retrasar
  /// los avisos); null = no se pudo comprobar.
  static Future<bool?> isIgnoringBatteryOptimizations() async {
    try {
      return await _channel
          .invokeMethod<bool>('isIgnoringBatteryOptimizations');
    } catch (_) {
      return null;
    }
  }

  /// Abre la pantalla del sistema con la lista de optimización de
  /// batería. Devuelve si se pudo abrir.
  static Future<bool> openBatteryOptimizationSettings() async {
    try {
      return await _channel.invokeMethod<bool>(
              'openBatteryOptimizationSettings') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Abre el "Inicio automático" de MIUI (o la pantalla de batería
  /// si no existe). Devuelve si se pudo abrir algo.
  static Future<bool> openAutostartSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openAutostartSettings') ??
          false;
    } catch (_) {
      return false;
    }
  }
}

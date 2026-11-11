// Navegación entre pantallas y botón atrás (v5).
//
// Dos cosas pequeñas y separadas:
//
// - BackNav: pila de "manejadores de atrás". Una pantalla con algo
//   abierto por dentro (un quiz, un solucionador) registra un manejador
//   que lo cierra y devuelve true. El PopScope de HomeScreen pregunta
//   primero aquí: si hay algo que cerrar, se cierra y NO se sale de la
//   app. Solo cuando no hay nada que cerrar y ya se está en Niveles, el
//   botón atrás sale de la app.
// - NavRequests: peticiones pendientes de una sola vez, para que una
//   pantalla pueda pedirle a otra que abra algo (la búsqueda pide a
//   Resolver que abra un solucionador; el menú pide a Niveles que
//   empiece el repaso; la búsqueda pide a Tabla que filtre). La pantalla
//   destino las consume en didChangeDependencies y las limpia.

import 'package:flutter/foundation.dart';

class BackNav {
  BackNav._();
  static final List<bool Function()> _handlers = <bool Function()>[];

  static void register(bool Function() handler) {
    if (!_handlers.contains(handler)) _handlers.add(handler);
  }

  static void unregister(bool Function() handler) {
    _handlers.remove(handler);
  }

  /// Devuelve true si algún manejador consumió el botón atrás.
  static bool handle() {
    if (_handlers.isEmpty) return false;
    return _handlers.last();
  }
}

class NavRequests {
  NavRequests._();

  /// Título exacto del solucionador que Resolver debe abrir.
  static String? openSolverTitle;

  /// Consulta con la que Tabla debe filtrar al abrirse.
  static String? tableQuery;

  /// Si es true, Niveles debe empezar el repaso de errores.
  static bool startReview = false;

  /// Contador de peticiones de repaso (p. ej. desde una notificación).
  /// HomeScreen lo escucha: si la app ya estaba abierta al tocar la
  /// notificación, el flag `startReview` solo no bastaría (Niveles ya
  /// está montada y no vuelve a mirar el flag). Con el aviso, HomeScreen
  /// va a Niveles y el repaso arranca. Si la app se abrió desde la
  /// notificación, no hace falta: Niveles consume el flag al montarse.
  static final ValueNotifier<int> reviewRequested = ValueNotifier(0);

  /// Pide el repaso de errores (p. ej. al tocar una notificación):
  /// deja el flag y avisa a quien escuche.
  static void requestReview() {
    startReview = true;
    reviewRequested.value++;
  }

  /// Si es true, al abrirse la app debe mostrarse el diálogo de
  /// actualización (se tocó el recordatorio "Hay una actualización
  /// pendiente"). HomeScreen lo consume al montarse (fix3, punto 20).
  static bool showUpdateDialog = false;

  /// Contador de peticiones de diálogo de actualización (p. ej. desde
  /// el recordatorio, con la app ya abierta). Igual que
  /// reviewRequested: el flag solo no bastaría si HomeScreen ya está
  /// montada.
  static final ValueNotifier<int> updateRequested = ValueNotifier(0);

  /// Pide el diálogo de actualización: deja el flag y avisa.
  static void requestUpdateDialog() {
    showUpdateDialog = true;
    updateRequested.value++;
  }

  /// Contador de peticiones de instalar el APK ya descargado (al tocar
  /// la notificación "Descarga completa" o su acción "Instalar").
  static final ValueNotifier<int> installRequested = ValueNotifier(0);

  /// Pide instalar el APK ya descargado.
  static void requestInstallApk() {
    installRequested.value++;
  }

  /// Pestaña de Tabla que debe abrirse (0 periódica, 1 actividad, 2
  /// solubilidad). null = la que ya estaba.
  static int? tableTab;
}

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

  /// Pestaña de Tabla que debe abrirse (0 periódica, 1 actividad, 2
  /// solubilidad). null = la que ya estaba.
  static int? tableTab;
}

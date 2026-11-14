/// ¿Corre bajo `flutter test`? En móvil se lee de
/// `Platform.environment`; en web no existe dart:io, así que ahí es
/// siempre false. (La vista previa web del inicio y la animación
/// Lottie de la racha la usan para quedarse quietas en pruebas.)
export 'platform_check_stub.dart' if (dart.library.io) 'platform_check_io.dart';

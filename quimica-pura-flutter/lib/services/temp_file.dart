/// Copia un asset a un archivo temporal y devuelve su ruta, o null
/// si no se puede. En web no hay archivos: siempre null. (El icono
/// grande de las notificaciones lo usa; en web la vista previa del
/// inicio no programa avisos.)
export 'temp_file_stub.dart' if (dart.library.io) 'temp_file_io.dart';

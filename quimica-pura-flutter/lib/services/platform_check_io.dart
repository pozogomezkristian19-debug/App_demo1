import 'dart:io' show Platform;

/// Bajo `flutter test` (variable de entorno FLUTTER_TEST).
bool get isFlutterTest => Platform.environment.containsKey('FLUTTER_TEST');

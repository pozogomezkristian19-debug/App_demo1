// Vista previa WEB del inicio (Kristian 2026-11-13: probar el
// inicio en el navegador sin descargar el APK). SOLO para web:
// usa los fakes de pruebas (Google de mentira, OTP 123456, nada
// se guarda en el servidor) y al terminar el inicio muestra LA APP
// DE VERDAD (Niveles, Cuenta con el botón de cambiar tema...) en
// vez de una página en blanco — 2026-11-14, Kristian: "muéstrame
// en la web hasta la pantalla de niveles aunque nada funcione para
// ver cómo quedó el botón". No se usa en el móvil ni entra en el
// APK: se compila aparte con `flutter build web -t
// lib/main_preview.dart`. En el navegador el paso de
// notificaciones no tiene permiso real: avanza como si estuviera
// concedido (el plugin no existe en web) y los avisos no suenan.
import 'package:flutter/material.dart';

import 'main.dart';
import 'services/analytics_sync.dart';
import 'services/auth_service.dart';
import 'services/localization.dart';
import 'services/otp_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Vista previa de pruebas: los fakes son el punto (nada real).
  // ignore: invalid_use_of_visible_for_testing_member
  AuthService.setProviderForTests(FakeAuthProvider());
  // ignore: invalid_use_of_visible_for_testing_member
  OtpService.setTransportForTests(FakeOtpTransport());
  // ignore: invalid_use_of_visible_for_testing_member
  AnalyticsSync.setRepositoryForTests(InMemoryAnalyticsRepository());
  await AppLang.load();
  runApp(const MelliQuiApp());
}

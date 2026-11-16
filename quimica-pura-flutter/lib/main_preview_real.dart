// Vista previa WEB DE VERDAD (Kristian 2026-11-15): la app con
// Firebase real (Auth + OTP + Firestore), para entrar con su
// cuenta de verdad y llegar a Niveles con sus datos reales. NO
// usa fakes: sin Google de mentira, sin OTP 123456, nada se
// inventa. Se compila aparte con `flutter build web -t
// lib/main_preview_real.dart` y se sube al canal `inicio` (el
// mismo enlace de la vista previa de pruebas). No se usa en el
// móvil ni entra en el APK.
//
// En el navegador, el inicio con Google puede necesitar la VPN
// desde Cuba (como en la app); el correo+contraseña es el plan B.
// El paso de notificaciones no tiene permiso real en web: avanza
// como si estuviera concedido y los avisos no suenan.
//
// SALTO DIRECTO A NIVELES (Kristian 2026-11-15, "Salta directo a
// niveles"): antes de arrancar, el inicio queda marcado como hecho
// (UserPrefs.markOnboardingDone), así la vista previa abre directo
// en la principal (Niveles) sin las pantallas de bienvenida. La
// cuenta real se vincula después desde Cuenta (Vincular con
// Google); el inicio con Google en el navegador desde Cuba puede
// necesitar la VPN, y el correo+contraseña es el plan B. Solo
// afecta a esta vista previa: el móvil y el APK no cambian.
import 'package:flutter/widgets.dart';
import 'package:quimica_pura/services/user_prefs.dart';

import 'main.dart' as app;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // El salto ya no depende solo del almacenamiento local: el flag
  // estático (previewSkipOnboarding) lo fuerza en main() aunque el
  // SharedPreferences web falle en este navegador. El guardado
  // local se intenta igual, pero su fallo ya no puede tumbar el
  // arranque ni devolver la app a las bienvenidas.
  UserPrefs.previewSkipOnboarding = true;
  try {
    await UserPrefs.markOnboardingDone();
  } catch (_) {
    // Sin almacenamiento local: el salto va por el flag estático.
  }
  await app.main();
}

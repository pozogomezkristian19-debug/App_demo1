// Pantalla del logo al abrir la app (Zona E2, Quemia 7.1).
//
// Aclaración de Kristian (Problem C del splash): el logo NO sale solo
// la primera vez que se instala. CADA vez que la app se abre en frío,
// la primera pantalla es el logo sobre el fondo del tema, y al cabo
// de ~1 s pasa a la pantalla principal (o al onboarding si es la
// primera vez), para que la app no se abra de golpe.
//
// Cómo encaja con el splash NATIVO (Zona E, ya hecho): Android
// muestra desde el primer instante launch_background.xml (fondo del
// tema + anillo órbita transparente centrado) hasta que Flutter pinta
// su primer frame. ESTA pantalla es ese primer frame de Flutter: el
// mismo logo centrado sobre el mismo fondo, aguantando ~1 s. No hay
// llamadas de red ni espera a Firebase/auth durante la espera: el
// temporizador es lo único que hay, así la app sigue abriendo rápido
// y funciona sin internet.
//
// El fondo es el scaffoldBackgroundColor del tema activo: blanco en
// claro, #131F24 en oscuro (acento Verde, el de por defecto) o
// #17112A con Violeta. Con el modo 'sistema' (el de por defecto)
// sigue al brillo del teléfono, igual que el drawable nocturno.
//
// EL ARTE: en claro, assets/app_icon.png, el anillo órbita (el icono
// lanzador: un cuadrado blanco redondeado OPACO, NO las gemelas). En
// claro la baldosa blanca se funde con el fondo blanco y se ve solo
// el anillo, igual que el splash nativo. En oscuro, assets/
// ring_logo.png, el anillo TRANSPARENTE del splash nativo (copiado de
// android/.../drawable-xxxhdpi/splash_logo.png): así en oscuro no se
// ve ninguna baldosa blanca, solo el anillo sobre el fondo oscuro.
// Kristian lo pidió así 2026-11-12 ("quítale la baldosa blanca esa").
//
// La espera solo vale para arranques en frío: _showSplash vive en el
// estado de MelliQuiApp y solo es true al arrancar. Al volver de
// segundo plano Android enseña la última pantalla (comportamiento
// del sistema) y aquí no se fuerza ningún splash.
//
// Tamaño 128 dp (Quemia 7.5, Kristian: "carga doble"): el anillo
// visible queda en ~94 dp, IGUAL que el splash nativo. Antes era
// 180 dp y el anillo se veía a ~132 dp, así al pasar del splash
// nativo a este el logo PEGABA UN SALTO a más grande y parecía
// que la app cargaba dos veces. La cuenta: splash_logo.png mide
// 512 px en drawable-xxxhdpi y el anillo ocupa 376 px (73%);
// Android lo enseña a 128 dp y el anillo visible queda en 94 dp
// en cualquier teléfono. Con la caja a 128 dp aquí, el anillo
// visible también es 94 dp y el paso de un splash al otro no se
// nota: parece un solo logo desde que se abre la app.
import 'dart:async';

import 'package:flutter/material.dart';

/// Cuánto aguanta el logo en pantalla antes de pasar a la principal
/// (o al onboarding). ~1 s: lo bastante para ver el logo, sin que la
/// app se sienta lenta.
const Duration kSplashHoldDuration = Duration(milliseconds: 1000);

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.onDone,
    this.holdDuration = kSplashHoldDuration,
  });

  /// Se llama una sola vez, al agotarse la espera. El padre cambia
  /// entonces a la pantalla principal o al onboarding.
  final VoidCallback onDone;

  /// Duración de la espera (inyectable para los tests; en la app
  /// real siempre es [kSplashHoldDuration], ~1 s).
  final Duration holdDuration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Un temporizador y nada más: sin red, sin Firebase, sin auth.
    // Se cancela al desmontar, para no avisar a un padre que ya no
    // está (p. ej. test que desmonta la pantalla antes del segundo).
    _timer = Timer(widget.holdDuration, () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // En oscuro, solo el anillo transparente (sin la baldosa blanca
    // del icono lanzador): Kristian lo pidió así 2026-11-12. En claro
    // la baldosa blanca se funde con el fondo y se ve solo el anillo,
    // así que ahí se usa el icono normal.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      // Fondo del tema activo (blanco / #131F24 / #17112A): el mismo
      // que el splash nativo, sin flash blanco al cambiar.
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: ClipRRect(
          // El radio propio del icono (~16% de 128): recorta los
          // píxeles negros de fuera de su cuadrado redondeado.
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            isDark ? 'assets/ring_logo.png' : 'assets/app_icon.png',
            key: const Key('splashLogo'),
            width: 128,
            height: 128,
            fit: BoxFit.cover,
            semanticLabel: 'Quemia',
          ),
        ),
      ),
    );
  }
}

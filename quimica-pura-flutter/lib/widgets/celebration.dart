// Celebración al pasar de nivel (v5, rediseño claro 2026-11-10;
// arreglo fix5 2026-11-11; Lottie 2026-11-14): lluvia de confeti
// con la animación "confetti" de LottieFiles que mandó Kristian
// (https://lottiefiles.com/free-animation/confetti-3ofTs67sBx),
// una sola pasada de ~5 s sobre la pantalla de resultado (y en
// duelo y torneo, que usan este mismo overlay). No es un diálogo
// ni una tarjeta: es solo la lluvia de confeti, sin fondo oscuro
// detrás. El Lottie es 1920x1080 (apaisado): con BoxFit.cover
// llena la pantalla del teléfono recortando los lados, así la
// lluvia cae por todo el alto.
//
// Fix5: el confeti dibujado por código se quedaba congelado y
// opaco tapando los botones al terminar. Ahora, como entonces,
// cuando el controlador completa el widget se desmonta
// (SizedBox.shrink) en vez de quedarse pintando un fotograma
// congelado. IgnorePointer se mantiene: los botones funcionan
// DURANTE la celebración.

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({super.key});
  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  /// La animación terminó: ya no hay nada que pintar. Sin esto el
  /// widget se quedaba para siempre con el último fotograma
  /// congelado encima de la pantalla de resultado.
  var _done = false;

  @override
  void initState() {
    super.initState();
    // Una pasada a la velocidad natural del Lottie: 126 fotogramas
    // a 25 fps = 5,04 s.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5040),
    )
      ..addStatusListener(_onStatus)
      ..forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _done = true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const SizedBox.shrink();
    return IgnorePointer(
      child: Lottie.asset(
        'assets/confetti.json',
        controller: _ctrl,
        fit: BoxFit.cover,
        repeat: false,
      ),
    );
  }
}

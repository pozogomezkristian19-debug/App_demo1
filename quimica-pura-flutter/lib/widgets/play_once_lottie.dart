// Animación Lottie que suena UNA sola vez al aparecer y luego se
// queda quieta (Kristian, 2026-11-14: "que la animación sea al
// comienzo, al abrir o ir a ese apartado; después, en esa pantalla,
// esté quieto"). En pruebas no anima: queda fija en el cuadro de
// descanso para que las fotos sean deterministas.
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../services/platform_check.dart';

/// Reproduce [asset] una vez, desde el cuadro 0 hasta [rest]
/// (0.0–1.0, por defecto el final: el cuadro en el que la
/// animación se queda quieta). En pruebas salta directo a [rest].
class PlayOnceLottie extends StatefulWidget {
  const PlayOnceLottie({
    super.key,
    required this.asset,
    required this.width,
    required this.height,
    this.rest = 1.0,
  });

  final String asset;
  final double width;
  final double height;

  /// Cuadro de descanso (fracción de la animación, 0.0–1.0).
  final double rest;

  @override
  State<PlayOnceLottie> createState() => _PlayOnceLottieState();
}

class _PlayOnceLottieState extends State<PlayOnceLottie>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Lottie.asset(
        widget.asset,
        controller: _ctrl,
        fit: BoxFit.contain,
        onLoaded: (composition) {
          _ctrl.duration = composition.duration;
          if (isFlutterTest) {
            _ctrl.value = widget.rest;
          } else if (!_ctrl.isAnimating && _ctrl.value == 0) {
            _ctrl.animateTo(widget.rest).then((_) {
              if (mounted) _ctrl.value = widget.rest;
            });
          }
        },
      ),
    );
  }
}

// Contador animado (v6): el número rueda desde el valor anterior
// hasta el nuevo, en vez de saltar de golpe. Para los puntos, la
// racha y cualquier cifra que cambie al contestar.

import 'dart:async';

import 'package:flutter/material.dart';

class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 600),
  });

  final int value;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        '$prefix${v.round()}$suffix',
        style: style,
      ),
    );
  }
}

/// Entrada suave: el hijo aparece con un fundido y subiendo un poco,
/// con un pequeño retraso (para escalonar secciones al abrir una
/// pantalla). Sin paquetes: solo AnimatedOpacity + AnimatedSlide.
class FadeIn extends StatefulWidget {
  const FadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 450),
  });
  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> {
  var _visible = false;
  // Timer cancelable (pulido 7.7): igual que FadeSlideIn, con
  // Future.delayed quedaba un temporizador pendiente si la
  // pantalla se cerraba antes del retardo.
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _delayTimer = Timer(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: widget.duration,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.08),
        duration: widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

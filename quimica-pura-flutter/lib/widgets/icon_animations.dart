// Animaciones suaves con gusto (rediseño 2026-11-10, fix 6): el
// corazón respira, la llama parpadea, las tarjetas entran con un
// fundido al abrir la pantalla. Nada de rebotes ruidosos: todo
// lento y sutil. Los controladores que repiten siguen el mismo
// patrón que ya usaba el nodo actual del camino
// (_LevelNodeRowState): repetir con reverse y parar al salir.

import 'package:flutter/material.dart';

/// Un hijo que respira: escala suave de 1.0 a [maxScale] y vuelta,
/// en bucle, para el corazón de las vidas (y lo que lo necesite).
class PulseWidget extends StatefulWidget {
  const PulseWidget({
    super.key,
    required this.child,
    this.maxScale = 1.12,
    this.duration = const Duration(milliseconds: 1200),
  });

  final Widget child;
  final double maxScale;
  final Duration duration;

  @override
  State<PulseWidget> createState() => _PulseWidgetState();
}

class _PulseWidgetState extends State<PulseWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _scale = Tween<double>(begin: 1.0, end: widget.maxScale).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Parpadeo sutil de la llama de la racha: escala y opacidad
/// apenas perceptibles, en bucle lento.
class FlickerWidget extends StatefulWidget {
  const FlickerWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 900),
  });

  final Widget child;
  final Duration duration;

  @override
  State<FlickerWidget> createState() => _FlickerWidgetState();
}

class _FlickerWidgetState extends State<FlickerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _scale = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _opacity = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.scale(scale: _scale.value, child: child),
      ),
      child: widget.child,
    );
  }
}

/// Entrada de una tarjeta al abrir la pantalla: fundido + subida
/// suave de 10 px, una sola vez (no se repite al reconstruir, porque
/// el estado vive en el widget y solo avanza en initState).
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 320),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: SlideTransition(position: _offset, child: child),
      ),
      child: widget.child,
    );
  }
}

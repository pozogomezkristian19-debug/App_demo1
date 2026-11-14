// Animaciones suaves con gusto (rediseño 2026-11-10, fix 6): el
// corazón respira, la llama parpadea, las tarjetas entran con un
// fundido al abrir la pantalla. Nada de rebotes ruidosos: todo
// lento y sutil. Los controladores que repiten siguen el mismo
// patrón que ya usaba el nodo actual del camino
// (_LevelNodeRowState): repetir con reverse y parar al salir.

import 'dart:async';

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

/// Feedback táctil al pulsar (pulido 7.7): el hijo se encoge un
/// poco (0.97) al bajar el dedo y vuelve suave al soltar, como una
/// tecla. Para tarjetas, píldoras, iconos y filas que hoy solo
/// tienen ripple (o nada) y se sienten secas. NO es un botón: no
/// dibuja nada, solo escala; el onTap sigue siendo del hijo (o se
/// pasa aquí). Curva suave, 120 ms, sin rebotes.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
    this.duration = const Duration(milliseconds: 120),
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  var _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
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
  // El retardo es un Timer cancelable (pulido 7.7): con
  // Future.delayed, si la pantalla se cerraba antes de que el
  // retardo terminara, quedaba un temporizador pendiente y los
  // tests fallaban ("A Timer is still pending"). Al salir, el
  // temporizador se cancela y no queda nada pendiente.
  Timer? _delayTimer;

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
    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
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

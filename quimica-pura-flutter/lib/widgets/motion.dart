// Pulido de movimiento de la pantalla de Cuenta y el perfil
// público, con motion dibujado por código, sin assets nuevos.
// Un solo tiempo por tipo de animación (AppMotion). El rebote
// elástico SOLO en celebraciones y pops, nunca en navegación.
// Con movimiento reducido (accessibleNavigation) no hay rebotes
// ni confeti: solo opacidad y color.
//
// NOTA (Kristian 2026-11-16, "quítale la mascota"): el sistema
// de animación de la mascota (MascotStateMachine / MascotMotion:
// respiración, parpadeo, salto con estrellitas) se ELIMINÓ
// entero — las mellizas quedan como imágenes estáticas. Lo que
// queda aquí es motion genérico: contadores, pops, entradas
// escalonadas y el pulso del botón SEGUIR.

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Un solo tiempo por tipo de animación (la tabla de la
/// investigación; reconstrucción de terceros, no spec oficial).
abstract final class AppMotion {
  /// Pulsar un botón (hundir + labio fuera).
  static const buttonPress = Duration(milliseconds: 100);

  /// Micro-feedback (150-200 ms).
  static const micro = Duration(milliseconds: 175);

  /// Panel / hoja (200-250 ms).
  static const sheet = Duration(milliseconds: 250);

  /// Transición de pantalla (300 ms).
  static const screenTransition = Duration(milliseconds: 300);

  /// Relleno de progreso (600 ms).
  static const progress = Duration(milliseconds: 600);

  /// Celebración (800-1200 ms).
  static const celebration = Duration(milliseconds: 900);

  /// Entre fases de una celebración escalonada (80-120 ms).
  static const stagger = Duration(milliseconds: 100);

  /// Salida de una tarjeta (deslizar/desvanecer, 300 ms).
  static const cardExit = Duration(milliseconds: 300);

  /// Pop elástico al aparecer (400 ms).
  static const pop = Duration(milliseconds: 400);
}

/// ¿Movimiento reducido? Con accessibleNavigation activado no hay
/// rebotes ni confeti: solo opacidad y color.
/// Movimiento reducido: SOLO la preferencia de movimiento del
/// sistema (prefers-reduced-motion en web → disableAnimations).
/// accessibleNavigation NO es una preferencia de movimiento: es
/// navegación asistida (lector de pantalla) y no debe apagar las
/// animaciones — con ella activa el baile de las mellizas no
/// arrancaba nunca en el navegador de verificación.
bool reducedMotion(BuildContext context) =>
    MediaQuery.of(context).disableAnimations;

/// valor directamente, sin contar ni pulsar.
class CountUp extends StatefulWidget {
  const CountUp({
    super.key,
    required this.value,
    this.style,
    this.duration = AppMotion.progress,
  });

  final int value;
  final TextStyle? style;
  final Duration duration;

  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  int _from = 0;
  int _to = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: AppMotion.pop,
    );
    _to = widget.value;
  }

  @override
  void didUpdateWidget(CountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _from = oldWidget.value;
      _to = widget.value;
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reducedMotion(context)) {
      return Text('${widget.value}', style: widget.style);
    }
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value;
        final scale = t == 0
            ? 1.0
            : 1.0 + 0.15 * math.sin(t * math.pi);
        return Transform.scale(scale: scale, child: child);
      },
      child: TweenAnimationBuilder<int>(
        tween: IntTween(begin: _from, end: _to),
        duration: widget.duration,
        curve: Curves.easeOut,
        builder: (context, value, _) =>
            Text('$value', style: widget.style),
      ),
    );
  }
}

/// Pop elástico al aparecer (escala 0.9 → 1, elasticOut, 400 ms):
/// tarjeta de completar perfil la primera vez, check de SEGUIR,
/// corazoncito de mutuo. Con movimiento reducido no hace pop.
class PopOnMount extends StatefulWidget {
  const PopOnMount({super.key, required this.child});

  final Widget child;

  @override
  State<PopOnMount> createState() => _PopOnMountState();
}

class _PopOnMountState extends State<PopOnMount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.pop,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reducedMotion(context)) return widget.child;
    return ScaleTransition(
      scale: Tween<double>(begin: 0.9, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
      ),
      child: widget.child,
    );
  }
}

/// Entrada escalonada por fases (mascota → texto → barra →
/// botón, 100 ms entre fases): se desvanece y sube desde abajo
/// (300 ms, easeOut). Con movimiento reducido solo se desvanece.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
  });

  /// Fase (0 = primera): el retraso es index × 100 ms.
  final int index;
  final Widget child;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance> {
  var _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(AppMotion.stagger * widget.index, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduced = reducedMotion(context);
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: AppMotion.sheet,
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible || reduced ? Offset.zero : const Offset(0, 0.15),
        duration: AppMotion.sheet,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Pulso elástico del botón SEGUIR al pasar a SIGUIENDO: el botón
/// hace un pop (1 → 1.07 → 1) justo cuando el estado cambia.
/// Con movimiento reducido no pulsa.
class FollowPulse extends StatefulWidget {
  const FollowPulse({
    super.key,
    required this.following,
    required this.child,
  });

  final bool following;
  final Widget child;

  @override
  State<FollowPulse> createState() => _FollowPulseState();
}

class _FollowPulseState extends State<FollowPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.pop,
    );
  }

  @override
  void didUpdateWidget(FollowPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.following && !oldWidget.following) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reducedMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final scale = t == 0
            ? 1.0
            : 1.0 + 0.07 * math.sin(t * math.pi);
        return Transform.scale(scale: scale, child: child);
      },
      child: widget.child,
    );
  }
}

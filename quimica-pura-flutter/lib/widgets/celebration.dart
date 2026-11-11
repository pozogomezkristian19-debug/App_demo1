// Celebración al pasar de nivel (v5, rediseño claro 2026-11-10;
// arreglo fix5 2026-11-11): confeti cayendo con los colores de la
// app, durante unos segundos, sobre la pantalla de resultado.
// Dibujo ligero con CustomPaint y un solo AnimationController. No
// es un diálogo ni una tarjeta: es solo la lluvia de confeti, sin
// fondo oscuro detrás.
//
// Fix5: antes cada pieza caía con `p = (progress * speed)` y speed
// 0,5–1,0, así que al terminar la animación las piezas lentas
// quedaban a mitad de pantalla con alfa 1,0, CONGELADAS y opacas
// para siempre, tapando los botones de la pantalla de resultado.
// Ahora cada pieza tiene su propio retardo de salida y un progreso
// local que llega a 1 para TODAS al final: al terminar, todas han
// salido por abajo y su alfa es 0. Y cuando el controlador
// completa, el widget se desmonta (SizedBox.shrink) en vez de
// quedarse pintando un fotograma congelado. IgnorePointer se
// mantiene: los botones funcionan DURANTE la celebración.

import 'dart:math' as math;

import 'package:flutter/material.dart';

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
    // Más larga y más densa que en v5: 4,2 s y 110 piezas, para que la
    // celebración se note de verdad al pasar de nivel.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
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
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          painter: _ConfettiPainter(_ctrl.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Estado de una pieza de confeti en un instante de la animación:
/// posición, giro, tamaño, opacidad y forma. Cálculo puro y
/// determinista (una sola fuente de verdad para el pintor y los
/// tests): cada pieza tiene su propia semilla `42 + index`, así que
/// su estado depende solo de su índice, del progreso global y del
/// tamaño de la pantalla.
({
  double x,
  double y,
  double rot,
  double alpha,
  double w,
  double h,
  bool isCircle,
}) _pieceState(int index, double progress, Size size) {
  final rng = math.Random(42 + index);
  final x0 = rng.nextDouble() * size.width;
  // Retardo de salida (0–35 % de la animación): las piezas no
  // salen todas a la vez, pero TODAS terminan a la vez. El
  // progreso local llega a 1 para cada pieza cuando el progreso
  // global llega a 1, así que ninguna se queda a mitad de camino.
  final delay = rng.nextDouble() * 0.35;
  final local = ((progress - delay) / (1.0 - delay)).clamp(0.0, 1.0);
  final sway = math.sin(local * 6 + index) * 22 * local;
  final rotSpeed = 4 + rng.nextDouble() * 4;
  // La pieza recorre desde 24 px por encima de la pantalla hasta
  // 24 px por debajo: con local = 1 está fuera por abajo.
  final y = -24 + local * (size.height + 48);
  // Aparece con un fundido rápido al salir y se desvanece al final
  // del recorrido: con local = 1 el alfa es 0.
  final alpha = local < 0.1
      ? local / 0.1
      : local > 0.85
          ? (1 - local) / 0.15
          : 1.0;
  final w = 7 + rng.nextDouble() * 6;
  final h = 10 + rng.nextDouble() * 8;
  return (
    x: x0 + sway,
    y: y,
    rot: local * rotSpeed * (index.isEven ? 1 : -1),
    alpha: alpha,
    w: w,
    h: h,
    isCircle: index % 4 == 0,
  );
}

/// Posición vertical y opacidad de una pieza, expuesta para los
/// tests: al final de la animación (progress = 1) TODAS las piezas
/// deben estar por debajo de la pantalla (y > size.height) y con
/// alfa 0.
@visibleForTesting
({double y, double alpha}) confettiPieceState(
  int index,
  double progress,
  Size size,
) {
  final s = _pieceState(index, progress, size);
  return (y: s.y, alpha: s.alpha);
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.progress);
  final double progress;

  // Colores de la app (teal propio #00C2A8, ámbar, celeste, rosa,
  // coral y violeta; sin verde Duolingo).
  static const _colors = [
    Color(0xFF00C2A8),
    Color(0xFFFFB300),
    Color(0xFF38BDF8),
    Color(0xFFEC4899),
    Color(0xFFF97316),
    Color(0xFFA78BFA),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // 110 piezas con posiciones deterministas: caen con retardos
    // distintos, giran mientras caen y algunas son círculos
    // (confeti redondo) en vez de tiras.
    for (var i = 0; i < 110; i++) {
      final s = _pieceState(i, progress, size);
      canvas.save();
      canvas.translate(s.x, s.y);
      canvas.rotate(s.rot);
      final paint = Paint()
        ..color = _colors[i % _colors.length].withValues(alpha: s.alpha);
      if (s.isCircle) {
        canvas.drawCircle(Offset.zero, s.w / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: s.w, height: s.h),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

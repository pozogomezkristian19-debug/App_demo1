// Celebración al pasar de nivel (v5, rediseño claro 2026-11-10):
// confeti cayendo con los colores de la app, durante unos segundos,
// sobre la pantalla de resultado. Dibujo ligero con CustomPaint y
// un solo AnimationController. No es un diálogo ni una tarjeta: es
// solo la lluvia de confeti, sin fondo oscuro detrás.

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

  @override
  void initState() {
    super.initState();
    // Más larga y más densa que en v5: 4,2 s y 110 piezas, para que la
    // celebración se note de verdad al pasar de nivel.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
    // 110 piezas con posiciones deterministas (semilla fija): caen con
    // velocidades distintas, giran mientras caen y algunas son círculos
    // (confeti redondo) en vez de tiras.
    final rng = math.Random(42);
    for (var i = 0; i < 110; i++) {
      final x0 = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.5;
      final sway = math.sin(progress * 6 + i) * 22;
      final p = (progress * speed).clamp(0.0, 1.0);
      final y = -24 + p * (size.height + 48);
      final x = x0 + sway * p;
      final rot = progress * (4 + rng.nextDouble() * 4) * (i.isEven ? 1 : -1);
      final alpha = p > 0.85 ? (1 - p) / 0.15 : 1.0;
      final w = 7 + rng.nextDouble() * 6;
      final h = 10 + rng.nextDouble() * 8;
      final isCircle = i % 4 == 0;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      final paint = Paint()
        ..color = _colors[i % _colors.length].withValues(alpha: alpha);
      if (isCircle) {
        canvas.drawCircle(Offset.zero, w / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: w, height: h),
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

// Celebración al pasar de nivel (v5): confeti cayendo con los colores
// de la app, durante unos segundos, sobre la pantalla de resultado.
// Dibujo ligero con CustomPaint y un solo AnimationController.

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
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
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

  static const _colors = [
    Color(0xFF14B8A6),
    Color(0xFFFFB300),
    Color(0xFF38BDF8),
    Color(0xFFEC4899),
    Color(0xFF22C55E),
    Color(0xFFA78BFA),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // 42 piezas con posiciones deterministas (semilla fija): caen con
    // velocidades distintas y giran mientras caen.
    final rng = math.Random(42);
    for (var i = 0; i < 42; i++) {
      final x0 = rng.nextDouble() * size.width;
      final speed = 0.55 + rng.nextDouble() * 0.45;
      final sway = math.sin(progress * 6 + i) * 18;
      final p = (progress * speed).clamp(0.0, 1.0);
      final y = -24 + p * (size.height + 48);
      final x = x0 + sway * p;
      final rot = progress * (4 + rng.nextDouble() * 4) * (i.isEven ? 1 : -1);
      final alpha = p > 0.85 ? (1 - p) / 0.15 : 1.0;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 9, height: 14),
          const Radius.circular(2),
        ),
        Paint()..color = _colors[i % _colors.length].withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

// Anillo de marco de la tienda (Quemia 7.3) alrededor de la foto
// del avatar del usuario: en la vista previa de la tarjeta de la
// tienda y en la cabecera de Cuenta.
//
// - Marco con color: anillo SÓLIDO de ese color (sin degradado,
//   regla 1: nunca un degradado).
// - Marco 'rainbow' (badgeIcon == 'rainbow', sin color único):
//   6 arcos de color, como el mockup de la 7.3 — tampoco es un
//   degradado, son 6 trazos sólidos.
// Sin marco equipado no dibuja nada (devuelve el hijo tal cual).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/shop_item.dart';

/// Los 6 colores del arcoíris (mockup 7.3).
const List<Color> kRainbowRingColors = [
  Color(0xFFFF0000),
  Color(0xFFFFA500),
  Color(0xFFFFEB00),
  Color(0xFF00C800),
  Color(0xFF0078FF),
  Color(0xFF9600FF),
];

class AvatarFrameRing extends StatelessWidget {
  const AvatarFrameRing({
    super.key,
    required this.frame,
    required this.child,
    this.ringWidth = 4,
  });

  /// El marco equipado, o null sin marco.
  final ShopItem? frame;
  final Widget child;

  /// Grosor del anillo.
  final double ringWidth;

  @override
  Widget build(BuildContext context) {
    final item = frame;
    if (item == null) return child;
    if (item.badgeIcon == 'rainbow') {
      return CustomPaint(
        painter: _RainbowRingPainter(ringWidth: ringWidth),
        child: Padding(
          padding: EdgeInsets.all(ringWidth),
          child: child,
        ),
      );
    }
    final color =
        item.color != null ? Color(item.color!) : const Color(0xFFFFD700);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: ringWidth),
      ),
      padding: EdgeInsets.all(ringWidth),
      child: child,
    );
  }
}

/// 6 arcos sólidos alrededor del hijo (el pintor cubre todo el
/// tamaño del CustomPaint: el hijo lleva el padding del grosor
/// del anillo, así los arcos caen justo en el borde).
class _RainbowRingPainter extends CustomPainter {
  const _RainbowRingPainter({required this.ringWidth});

  final double ringWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.shortestSide - ringWidth) / 2;
    if (radius <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < kRainbowRingColors.length; i++) {
      final paint = Paint()
        ..color = kRainbowRingColors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2 + i * math.pi / 3,
        math.pi / 3,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RainbowRingPainter old) =>
      old.ringWidth != ringWidth;
}

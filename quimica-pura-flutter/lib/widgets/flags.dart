// Banderitas dibujadas con CustomPaint (sin imágenes externas ni emojis),
// para la pantalla de idioma. Cada bandera es una miniatura de 32×22 con
// sus franjas y, en el caso del Reino Unido, sus cruces.

import 'package:flutter/material.dart';

/// Banderita de un idioma ('es', 'en', 'fr', 'it', 'pt', 'ru').
class FlagWidget extends StatelessWidget {
  const FlagWidget({super.key, required this.code, this.width = 34, this.height = 24});
  final String code;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black.withValues(alpha: 0.25)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: CustomPaint(
          painter: _FlagPainter(code),
          size: Size(width, height),
        ),
      ),
    );
  }
}

class _FlagPainter extends CustomPainter {
  _FlagPainter(this.code);
  final String code;

  void _stripe(Canvas c, Rect area, Color color) {
    c.drawRect(area, Paint()..color = color);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    switch (code) {
      case 'es':
        // España: rojo, amarillo (doble), rojo.
        _stripe(canvas, Rect.fromLTWH(0, 0, w, h * 0.25), const Color(0xFFAA151B));
        _stripe(canvas, Rect.fromLTWH(0, h * 0.25, w, h * 0.5), const Color(0xFFF1BF00));
        _stripe(canvas, Rect.fromLTWH(0, h * 0.75, w, h * 0.25), const Color(0xFFAA151B));
        break;
      case 'en':
        // Reino Unido (simplificado): fondo azul, aspa blanca, cruz
        // blanca, aspa roja fina y cruz roja.
        _stripe(canvas, Rect.fromLTWH(0, 0, w, h), const Color(0xFF012169));
        final white = Paint()
          ..color = Colors.white
          ..strokeWidth = h * 0.28
          ..strokeCap = StrokeCap.butt;
        canvas.drawLine(const Offset(0, 0), Offset(w, h), white);
        canvas.drawLine(Offset(w, 0), Offset(0, h), white);
        canvas.drawRect(Rect.fromLTWH(w / 2 - h * 0.14, 0, h * 0.28, h), Paint()..color = Colors.white);
        canvas.drawRect(Rect.fromLTWH(0, h / 2 - h * 0.14, w, h * 0.28), Paint()..color = Colors.white);
        final red = Paint()
          ..color = const Color(0xFFC8102E)
          ..strokeWidth = h * 0.1
          ..strokeCap = StrokeCap.butt;
        canvas.drawLine(const Offset(0, 0), Offset(w, h), red);
        canvas.drawLine(Offset(w, 0), Offset(0, h), red);
        canvas.drawRect(Rect.fromLTWH(w / 2 - h * 0.05, 0, h * 0.1, h), Paint()..color = const Color(0xFFC8102E));
        canvas.drawRect(Rect.fromLTWH(0, h / 2 - h * 0.05, w, h * 0.1), Paint()..color = const Color(0xFFC8102E));
        break;
      case 'fr':
        // Francia: azul, blanco, rojo (verticales).
        _stripe(canvas, Rect.fromLTWH(0, 0, w / 3, h), const Color(0xFF0055A4));
        _stripe(canvas, Rect.fromLTWH(w / 3, 0, w / 3, h), Colors.white);
        _stripe(canvas, Rect.fromLTWH(2 * w / 3, 0, w / 3, h), const Color(0xFFEF4135));
        break;
      case 'it':
        // Italia: verde, blanco, rojo (verticales).
        _stripe(canvas, Rect.fromLTWH(0, 0, w / 3, h), const Color(0xFF009246));
        _stripe(canvas, Rect.fromLTWH(w / 3, 0, w / 3, h), Colors.white);
        _stripe(canvas, Rect.fromLTWH(2 * w / 3, 0, w / 3, h), const Color(0xFFCE2B37));
        break;
      case 'pt':
        // Portugal: verde (2/5) y rojo (3/5), con el círculo amarillo
        // de la esfera armilar en la unión.
        _stripe(canvas, Rect.fromLTWH(0, 0, w * 0.4, h), const Color(0xFF046A38));
        _stripe(canvas, Rect.fromLTWH(w * 0.4, 0, w * 0.6, h), const Color(0xFFDA291C));
        canvas.drawCircle(
            Offset(w * 0.4, h / 2), h * 0.28, Paint()..color = const Color(0xFFFFE900));
        canvas.drawCircle(
            Offset(w * 0.4, h / 2), h * 0.2, Paint()..color = const Color(0xFFDA291C));
        break;
      case 'ru':
        // Rusia: blanco, azul, rojo (horizontales).
        _stripe(canvas, Rect.fromLTWH(0, 0, w, h / 3), Colors.white);
        _stripe(canvas, Rect.fromLTWH(0, h / 3, w, h / 3), const Color(0xFF0039A6));
        _stripe(canvas, Rect.fromLTWH(0, 2 * h / 3, w, h / 3), const Color(0xFFD52B1E));
        break;
      default:
        _stripe(canvas, Rect.fromLTWH(0, 0, w, h), Colors.grey);
    }
  }

  @override
  bool shouldRepaint(_FlagPainter old) => old.code != code;
}

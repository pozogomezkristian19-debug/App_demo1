// Las vidas, como corazón + número (rediseño 2026-11-10, fix 1/5):
// ya NO hay fila de 5 corazones en ningún sitio. El corazón es el
// de Lucide (icono moderno minimalista, trazado fino), relleno con
// un degradado coral-rojo y un brillito blanco para que se vea
// vivo y con volumen, nunca un emoji ni el corazón plano de antes.
// El chip es el mismo en todas partes: junto al saludo en la
// AppBar, en la tarjeta de estadísticas de Cuenta y en Mis
// estadísticas. La lógica de las vidas no cambia (5 máx., -1 por
// abandonar, +1 por pasar, recarga diaria, 0 bloquea).

import 'package:flutter/material.dart';

import 'icon_animations.dart';
import 'lucide_icons.dart';

/// El corazón de las vidas: el path de Lucide, relleno con un
/// degradado coral-rojo y un brillito blanco arriba a la izquierda.
class LivesHeart extends StatelessWidget {
  const LivesHeart({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _LivesHeartPainter(),
    );
  }
}

class _LivesHeartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.save();
    canvas.scale(scale, scale);
    final path = LucideIcons.heart.paths.first;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFF6B6B), Color(0xFFEF4444)],
      ).createShader(path.getBounds());
    canvas.drawPath(path, fill);
    // Brillito blanco, arriba a la izquierda, para darle vida.
    canvas.save();
    canvas.translate(8.4, 7.2);
    canvas.rotate(-0.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: 6.4,
        height: 3.0,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LivesHeartPainter old) => false;
}

/// Chip compacto: corazón que respira + número de vidas.
/// [showMax] muestra "4/5"; sin él, solo "4".
class LivesChip extends StatelessWidget {
  const LivesChip({
    super.key,
    required this.lives,
    this.maxLives = 5,
    this.showMax = false,
    this.pulse = true,
    this.heartSize = 17,
    this.fontSize = 14,
  });

  final int lives;
  final int maxLives;
  final bool showMax;
  final bool pulse;
  final double heartSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final label = showMax ? '$lives/$maxLives' : '$lives';
    final heart = LivesHeart(size: heartSize);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE4E6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pulse
              ? PulseWidget(child: heart)
              : heart,
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }
}

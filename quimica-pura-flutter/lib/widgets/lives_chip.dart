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
    // Corazón con degradado coral-rojo (#FF6B6B arriba →
    // #EF4444 abajo) y brillito blanco en el medio (ronda de
    // arreglo #1). EXCEPCIÓN EXPLÍCITA del usuario (alcance 7,
    // 2026-11-12) a la regla "sin gradiente/brillo": él lo pide
    // así, solo para el corazón de vidas, en todas partes donde
    // aparece (píldora de la barra superior, tarjeta de
    // estadísticas de Cuenta, Mis estadísticas, Cómo se juega).
    // El degradado se quitó en el rediseño Duolingo §3.2.6
    // (corazón plano #FF4B4B); se restaura por orden suya.
    final gradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFF6B6B), Color(0xFFEF4444)],
    ).createShader(const Rect.fromLTWH(0, 0, 24, 24));
    canvas.drawPath(
        path, Paint()..style = PaintingStyle.fill..shader = gradient);
    // Brillito blanco en el medio del lóbulo izquierdo,
    // recortado a la forma del corazón para que no se salga:
    // halo suave + punto más vivo encima.
    canvas.save();
    canvas.clipPath(path);
    canvas.drawOval(
        Rect.fromCenter(
            center: const Offset(8.5, 7.5), width: 7, height: 4.5),
        Paint()..color = Colors.white.withValues(alpha: 0.28));
    canvas.drawOval(
        Rect.fromCenter(
            center: const Offset(8.5, 7), width: 4.5, height: 3),
        Paint()..color = Colors.white.withValues(alpha: 0.6));
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LivesHeartPainter old) => false;
}

/// Chip compacto: corazón que respira + número de vidas.
/// [showMax] muestra "4/5"; sin él, solo "4".
/// PÍLDORA rosa claro (Zona F, corrección 2026-11-12, imagen de
/// Kristian): fondo #FDE8E8, corazón #FF4B4B + número en rojo
/// #FF4B4B, redondeada, en claro y en oscuro. Antes era fondo
/// transparente (rediseño Duolingo §3.9.5).
/// Altura EXACTA de las tres píldoras de la barra superior (vidas,
/// repaso, campana): 36 dp. Las tres miden LO MISMO de alto SIEMPRE
/// (regla de Kristian 2026-11-12): la campana, sin número, quedaba
/// 6 dp más baja que las otras dos (30 dp) porque su altura salía
/// solo del icono + padding; con la altura fija ya no puede
/// descolgarse aunque cambie el contenido.
const double kTopBarPillHeight = 36.0;

class LivesChip extends StatelessWidget {
  const LivesChip({
    super.key,
    required this.lives,
    this.maxLives = 5,
    this.showMax = false,
    this.pulse = true,
    this.heartSize = 20,
    this.fontSize = 18,
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
      // Píldora rosa claro con el número dentro (imagen de
      // Kristian): fondo #FDE8E8 en los dos temas, número en rojo.
      // Altura fija kTopBarPillHeight: igual que repaso y campana.
      decoration: BoxDecoration(
        color: const Color(0xFFFDE8E8),
        borderRadius: BorderRadius.circular(999),
      ),
      height: kTopBarPillHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pulse ? PulseWidget(child: heart) : heart,
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFFF4B4B),
            ),
          ),
        ],
      ),
    );
  }
}

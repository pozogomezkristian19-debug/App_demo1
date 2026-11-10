// Avatares de Melli-Qui (v6): dibujados en la app con CustomPaint,
// sin imágenes externas ni emojis. Cada usuario elige uno según su
// género (guardado en su perfil: 'Femenino' o 'Masculino').
// Hay 3 estilos por género; el elegido se guarda en UserPrefs.avatar
// y se muestra en la pantalla Cuenta y junto al saludo.

import 'package:flutter/material.dart';

/// Un avatar: id 'm0'..'m2' (masculino) o 'f0'..'f2' (femenino).
class MelliAvatar extends StatelessWidget {
  const MelliAvatar({super.key, required this.avatarId, this.size = 64});

  final String avatarId;
  final double size;

  /// Estilos disponibles para un género.
  static List<String> stylesForGender(String gender) {
    return gender == 'Femenino' ? const ['f0', 'f1', 'f2'] : const ['m0', 'm1', 'm2'];
  }

  /// Avatar por defecto según el género del perfil.
  static String defaultForGender(String gender) =>
      gender == 'Femenino' ? 'f0' : 'm0';

  static bool isValidId(String id) =>
      const ['m0', 'm1', 'm2', 'f0', 'f1', 'f2'].contains(id);

  @override
  Widget build(BuildContext context) {
    final id = isValidId(avatarId) ? avatarId : 'm0';
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _AvatarPainter(id)),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.id);
  final String id;

  bool get _female => id.startsWith('f');
  int get _style => int.tryParse(id.substring(1)) ?? 0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s * 0.5;

    // Fondo: círculo con un tinte suave distinto por estilo.
    const bgColors = [
      Color(0xFFEDE9FE),
      Color(0xFFCCFBF1),
      Color(0xFFFFEDD5),
    ];
    canvas.drawCircle(
      Offset(cx, s * 0.5),
      s * 0.5,
      Paint()..color = bgColors[_style % bgColors.length],
    );

    // Tonos de piel (morenos claros, como las gemelas del regalo).
    const skins = [
      Color(0xFFD9A066),
      Color(0xFFC68E6A),
      Color(0xFFB97A56),
    ];
    final skin = skins[_style % skins.length];
    // Pelo castaño oscuro, con una variante negra.
    final hair = _style == 2
        ? const Color(0xFF2B2B2B)
        : const Color(0xFF6B4226);

    // Pelo largo (femenino, salvo moño): mechones a los lados, detrás
    // de la cara.
    if (_female && _style != 1) {
      final lock = Paint()..color = hair;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s * 0.16, s * 0.42, s * 0.13, s * 0.44),
          Radius.circular(s * 0.065),
        ),
        lock,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s * 0.71, s * 0.42, s * 0.13, s * 0.44),
          Radius.circular(s * 0.065),
        ),
        lock,
      );
    }

    // Cara.
    canvas.drawCircle(
      Offset(cx, s * 0.54),
      s * 0.30,
      Paint()..color = skin,
    );

    // Moño (f1): círculo encima de la cabeza.
    if (_female && _style == 1) {
      canvas.drawCircle(
        Offset(cx, s * 0.17),
        s * 0.11,
        Paint()..color = hair,
      );
    }

    // Pelo superior: media luna sobre la frente.
    final hairPaint = Paint()..color = hair;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, s * 0.47), radius: s * 0.30),
      3.1415926535 * 1.02,
      3.1415926535 * 0.96,
      true,
      hairPaint,
    );
    // Flequillo: pequeño arco que baja un poco en el centro (salvo rizado).
    if (_style != 1) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, s * 0.40), radius: s * 0.17),
        0,
        3.1415926535,
        true,
        hairPaint,
      );
    }

    // Rizos (m1 y f2): bolitas sobre la línea del pelo.
    if (_style == 1 && !_female || _style == 2 && _female) {
      for (var i = 0; i < 5; i++) {
        final x = s * (0.28 + i * 0.11);
        final y = s * (0.24 + (i.isEven ? 0.0 : 0.03));
        canvas.drawCircle(Offset(x, y), s * 0.055, hairPaint);
      }
    }

    // Ojos.
    final eyePaint = Paint()..color = const Color(0xFF2B2118);
    canvas.drawCircle(Offset(s * 0.40, s * 0.54), s * 0.032, eyePaint);
    canvas.drawCircle(Offset(s * 0.60, s * 0.54), s * 0.032, eyePaint);

    // Sonrisa.
    final smilePaint = Paint()
      ..color = const Color(0xFF7C4A2D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.028
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, s * 0.60), radius: s * 0.09),
      0.25,
      3.1415926535 - 0.5,
      false,
      smilePaint,
    );

    // Gafas (m2): dos aros y el puente.
    if (!_female && _style == 2) {
      final g = Paint()
        ..color = const Color(0xFF1F2937)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.025;
      canvas.drawCircle(Offset(s * 0.40, s * 0.54), s * 0.085, g);
      canvas.drawCircle(Offset(s * 0.60, s * 0.54), s * 0.085, g);
      canvas.drawLine(
        Offset(s * 0.485, s * 0.54),
        Offset(s * 0.515, s * 0.54),
        g,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter old) => old.id != id;
}

// Anillo de marco de la tienda (Quemia 7.3, 3D en la 7.9)
// alrededor de la foto del avatar del usuario: en la vista
// previa de la tarjeta de la tienda y en la cabecera de Cuenta.
//
// El dorado y el fuego NO se dibujan en código: son IMÁGENES
// recortadas de las fotos de referencia de Kristian (las que
// él mandó el 2026-11-18: el medallón dorado y el halo de
// fuego). El dibujo en código nunca se veía igual que la foto
// — por eso se recortaron las fotos mismas: el anillo es la
// foto, con el centro transparente para que se vea la foto del
// usuario. La plata sigue dibujada (no hay foto de ella).
//
// - Marco con color (plata): anillo 3D con RELIEVE Y LUZ: banda
//   del color con un borde oscuro fuera, un brillo sólido arriba
//   a la izquierda y una sombra sólida abajo a la derecha. Son
//   trazos SÓLIDOS (nunca un degradado, regla 1).
// - Marco 'fire' en código (solo si no hay imagen): anillo de
//   LLAMAS dibujadas — queda como respaldo, no se usa con la
//   imagen puesta.
// - Marco 'rainbow' (badgeIcon == 'rainbow', sin color único):
//   6 arcos de color, como el mockup de la 7.3 — tampoco es un
//   degradado, son 6 trazos sólidos.
// Sin marco equipado no dibuja nada (devuelve el hijo tal cual).
// El estilo lo decide el artículo (color/tipo), no un solo
// estilo para todos.

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
    this.photoSize,
  });

  /// El marco equipado, o null sin marco.
  final ShopItem? frame;
  final Widget child;

  /// Grosor del anillo.
  final double ringWidth;

  /// Diámetro de la foto del hijo: lo necesitan los marcos de
  /// imagen, porque su aire es una fracción de la foto (no un
  /// grosor fijo). Sin él, el marco-imagen usa el grosor como
  /// aproximación.
  final double? photoSize;

  /// Marcos que son una IMAGEN recortada de la foto de
  /// referencia de Kristian (el anillo es la foto misma, con el
  /// centro transparente). Null = marco dibujado en código.
  static String? imageAssetFor(ShopItem? frame) {
    if (frame == null) return null;
    if (frame.id == 'frame_dorado_3d') return 'assets/frame_dorado_3d.png';
    if (frame.id == 'frame_fuego') return 'assets/frame_fuego_3d.png';
    // Marcos nuevos (2026-11-18): discos recortados de las fotos
    // de referencia, como el Dorado y el Fuego.
    if (frame.id == 'frame_diamante') return 'assets/frame_diamante_3d.png';
    if (frame.id == 'frame_esmeralda') {
      return 'assets/frame_esmeralda_3d.png';
    }
    if (frame.id == 'frame_zafiro') return 'assets/frame_zafiro_3d.png';
    if (frame.id == 'frame_rubi') return 'assets/frame_rubi_3d.png';
    if (frame.id == 'frame_hielo') return 'assets/frame_hielo_3d.png';
    return null;
  }

  /// Aire que el marco-imagen ocupa a cada lado de la foto, como
  /// fracción del tamaño de la foto, medido en la foto de
  /// referencia: dorado (440-340)/680, fuego (495-395)/790.
  /// Marcos nuevos: medido en el PNG construido, no en la foto
  /// de referencia (su anillo salió más grueso que el PNG): el
  /// hueco real del disco es diamante 0.727, esmeralda y zafiro
  /// 0.793 y rubí 0.809 del diámetro, con un pelín de solape
  /// para que el brillo dorado no se asome entre la foto y el
  /// anillo. El hielo (322-220)/440 ya cubría el hueco.
  static double? imagePaddingRatio(ShopItem? frame) {
    if (frame == null) return null;
    if (frame.id == 'frame_dorado_3d') return 100 / 680;
    if (frame.id == 'frame_fuego') return 100 / 790;
    if (frame.id == 'frame_diamante') return 0.17;
    if (frame.id == 'frame_esmeralda' || frame.id == 'frame_zafiro') {
      return 0.122;
    }
    if (frame.id == 'frame_rubi') return 0.11;
    if (frame.id == 'frame_hielo') return 102 / 440;
    return null;
  }

  /// Espacio que el marco ocupa alrededor de la foto: el grosor
  /// del anillo, salvo el fuego dibujado, cuyo halo de llamas
  /// necesita más aire; y salvo los marcos de imagen, cuyo aire
  /// es una fracción de la foto (medido en la foto misma).
  static double paddingFor(ShopItem? frame, double ringWidth,
      {double? photoSize}) {
    final ratio = imagePaddingRatio(frame);
    if (ratio != null && photoSize != null) return photoSize * ratio;
    if (frame != null && frame.badgeIcon == 'fire') {
      return ringWidth * 1.75;
    }
    return ringWidth;
  }

  @override
  Widget build(BuildContext context) {
    final item = frame;
    if (item == null) return child;
    final width = ringWidth;
    final imageAsset = imageAssetFor(item);
    if (imageAsset != null) {
      // El anillo ES la foto: la imagen cuadrada es el disco
      // completo (anillo + brillo dorado de adentro, copiados
      // de la foto), y la foto del usuario va centrada con el
      // aire medido en la foto. Por las partes transparentes
      // del avatar se ve el brillo de la foto, como en ella.
      final pad = paddingFor(item, width, photoSize: photoSize);
      // El marco va ABAJO y el avatar ENCIMA: el PNG es el disco
      // completo (anillo + brillo dorado) y es opaco en el centro,
      // así que si el marco quedara encima taparía el avatar.
      // El avatar (círculo recortado) cubre justo el hueco y por
      // sus partes transparentes se ve el brillo de la foto.
      return Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Image.asset(imageAsset, fit: BoxFit.fill),
          ),
          Padding(
            padding: EdgeInsets.all(pad),
            child: child,
          ),
        ],
      );
    }
    if (item.badgeIcon == 'rainbow') {
      return CustomPaint(
        painter: _RainbowRingPainter(ringWidth: width),
        child: Padding(
          padding: EdgeInsets.all(width),
          child: child,
        ),
      );
    }
    if (item.badgeIcon == 'fire') {
      // Las llamas necesitan aire: el halo de fuego se extiende
      // más allá del anillo, como en la foto de referencia.
      final pad = paddingFor(item, width);
      return CustomPaint(
        painter: _FlameRingPainter(ringWidth: width, flameExtent: pad),
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: child,
        ),
      );
    }
    final color =
        item.color != null ? Color(item.color!) : const Color(0xFFFFD700);
    return CustomPaint(
      painter: _MetalRingPainter(color: color, ringWidth: width),
      child: Padding(
        padding: EdgeInsets.all(width),
        child: child,
      ),
    );
  }
}

/// Anillo 3D con relieve y luz (mockup del dorado): el color del
/// marco con un borde oscuro por fuera (el anillo tiene grosor),
/// un brillo sólido arriba a la izquierda (donde cae la luz) y
/// una sombra sólida abajo a la derecha. Todo trazos sólidos, sin
/// degradados: el relieve lo dan las capas.
class _MetalRingPainter extends CustomPainter {
  const _MetalRingPainter({required this.color, required this.ringWidth});

  final Color color;
  final double ringWidth;

  static Color _light(Color c, double amount) =>
      Color.lerp(c, Colors.white, amount)!;
  static Color _dark(Color c, double amount) =>
      Color.lerp(c, Colors.black, amount)!;

  @override
  void paint(Canvas canvas, Size size) {
    final w = ringWidth;
    if (w <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - w) / 2;
    if (radius <= 0) return;
    // Sombra suave debajo: el anillo flota sobre la foto (como
    // el medallón dorado de la foto de referencia).
    canvas.drawCircle(
      center + Offset(0, w * 0.18),
      radius,
      Paint()
        ..color = const Color(0x40000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w,
    );
    // Banda principal: TODO el grosor, como el medallón grueso
    // de la foto (antes solo 0.72×, por eso se veía fino).
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w,
    );
    // Borde oscuro exterior: el anillo tiene grosor.
    canvas.drawCircle(
      center,
      radius + w / 2 - 1,
      Paint()
        ..color = _dark(color, 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Brillo arriba a la izquierda (la luz cae desde ahí).
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.85,
      math.pi * 0.8,
      false,
      Paint()
        ..color = _light(color, 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.5
        ..strokeCap = StrokeCap.round,
    );
    // Sombra abajo a la derecha.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.15,
      math.pi * 0.7,
      false,
      Paint()
        ..color = _dark(color, 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.5
        ..strokeCap = StrokeCap.round,
    );
    // Filo claro interior: el borde de dentro brilla un poco.
    canvas.drawCircle(
      center,
      radius - w / 2 + 1,
      Paint()
        ..color = _light(color, 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Surco interior: la ranura del medallón, como en la foto
    // de referencia (el anillo no es una banda lisa, tiene un
    // canal que le da el relieve de moneda).
    canvas.drawCircle(
      center,
      radius - w * 0.25,
      Paint()
        ..color = _dark(color, 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_MetalRingPainter old) =>
      old.color != color || old.ringWidth != ringWidth;
}

/// Anillo de llamas (foto de referencia del fuego): un halo de
/// lenguas de fuego naranja con núcleo amarillo alrededor de la
/// foto, más brasas. Las llamas nacen en el borde de la foto y
/// llegan hasta el borde del cuadro: son grandes y se ven, no
/// como antes (0.72× el grosor). Las posiciones y los tamaños son
/// deterministas (una función del índice): el mismo marco se
/// dibuja igual en cada repintado.
class _FlameRingPainter extends CustomPainter {
  const _FlameRingPainter({
    required this.ringWidth,
    required this.flameExtent,
  });

  final double ringWidth;

  /// Aire alrededor de la foto: hasta ahí llegan las llamas.
  final double flameExtent;

  static const _outer = Color(0xFFFF6B00);
  static const _mid = Color(0xFFFF9600);
  static const _core = Color(0xFFFFC800);

  /// Variación determinista 0.0–1.0 para el índice [i].
  static double _vary(int i) {
    var h = (i * 2654435761) & 0xFFFFFFFF;
    h ^= h >> 13;
    h = (h * 1274126177) & 0xFFFFFFFF;
    return (h % 1000) / 1000;
  }

  /// Lengua de fuego en coordenadas locales: la base en (0, 0)
  /// y la punta en (0, -h), con una leve inclinación [lean].
  static Path _flame(double w, double h, double lean) {
    final path = Path();
    path.moveTo(-w / 2, 0);
    path.quadraticBezierTo(-w * 0.75, -h * 0.5, lean * w, -h);
    path.quadraticBezierTo(w * 0.75, -h * 0.5, w / 2, 0);
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = ringWidth;
    final ext = flameExtent;
    if (w <= 0 || ext <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    // Radio de la foto (el cuadro menos el aire de las llamas).
    final photoR = size.shortestSide / 2 - ext;
    if (photoR <= 0) return;
    // Base quemada: anillo rojo oscuro en el borde de la foto.
    final bandR = photoR + w / 2;
    canvas.drawCircle(
      center,
      bandR,
      Paint()
        ..color = const Color(0xFF7A1F00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w,
    );
    // Resplandor: NO lleva un anillo naranja uniforme bajo las
    // llamas — eso lo leía como el disco de un sol. El fuego es
    // solo llamas + brasas sobre la base quemada.
    // Llamas: una por cada 22.5°, de la foto al borde del cuadro.
    // La local -y apunta hacia fuera del círculo. El fuego SUBE:
    // las llamas son largas arriba y cortas abajo (topness), y
    // muy desiguales entre sí — si todas miden lo mismo y salen
    // radiales, se lee como un sol. Estrechas y con inclinación
    // variada para que se lean como fuego de verdad.
    final flameCount = 16;
    final midR = photoR + ext * 0.5;
    final flameW = (2 * math.pi * midR / flameCount) * 0.7;
    for (var i = 0; i < flameCount; i++) {
      final a = i * 2 * math.pi / flameCount;
      final vary = _vary(i);
      // 1 arriba, 0 abajo (en Flutter la y crece hacia abajo).
      final topness = (1 - math.sin(a)) / 2;
      final h = ext * (0.35 + 0.5 * topness) * (0.7 + 0.4 * vary);
      final fw = flameW * (0.7 + 0.3 * _vary(i + 7));
      final lean = (_vary(i + 13) - 0.5) * 1.0;
      final pos = center + Offset(math.cos(a), math.sin(a)) * photoR;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(a + math.pi / 2);
      canvas.drawPath(
        _flame(fw, h, lean),
        Paint()..color = _outer,
      );
      canvas.drawPath(
        _flame(fw * 0.55, h * 0.62, lean),
        Paint()..color = _mid,
      );
      canvas.drawPath(
        _flame(fw * 0.28, h * 0.34, lean),
        Paint()..color = _core,
      );
      canvas.restore();
    }
    // Brasas: chispas en forma de rombo (NO círculos perfectos:
    // los puntos redondos se leían como los puntos de un sol),
    // flotando entre las llamas, en posiciones deterministas.
    for (var i = 0; i < 16; i++) {
      final a = _vary(i + 31) * 2 * math.pi;
      final r = photoR + ext * (0.3 + 0.6 * _vary(i + 47));
      final dot = center + Offset(math.cos(a), math.sin(a)) * r;
      final s = 1.5 + _vary(i + 59) * 2;
      final rot = _vary(i + 71) * math.pi;
      final spark = Path()
        ..moveTo(dot.dx + s * math.cos(rot - math.pi / 2),
            dot.dy + s * math.sin(rot - math.pi / 2))
        ..lineTo(dot.dx + s * math.cos(rot),
            dot.dy + s * math.sin(rot))
        ..lineTo(dot.dx + s * math.cos(rot + math.pi / 2),
            dot.dy + s * math.sin(rot + math.pi / 2))
        ..lineTo(dot.dx + s * math.cos(rot + math.pi),
            dot.dy + s * math.sin(rot + math.pi))
        ..close();
      canvas.drawPath(
        spark,
        Paint()..color = i.isEven ? _core : _mid,
      );
    }
  }

  @override
  bool shouldRepaint(_FlameRingPainter old) =>
      old.ringWidth != ringWidth || old.flameExtent != flameExtent;
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

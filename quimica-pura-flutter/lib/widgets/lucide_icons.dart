// Iconos modernos minimalistas de Lucide (https://lucide.dev,
// lucide-static 1.71.0, licencia ISC), convertidos de sus SVG
// oficiales a rutas de Flutter: sin ninguna dependencia nueva.
// Lucide dibuja con trazo fino (2 px en un viewBox de 24x24) y
// puntas redondas: ese es el estilo de TODA la app desde el
// rediseño de iconos (2026-11-10). Los Material Icons rústicos
// (corazones planos, banderita, círculo, llama gruesa...) quedan
// sustituidos por estas líneas limpias.
//
// Cómo se usa:
//   LucideIcon(LucideIcons.heart, size: 22, color: Colors.red)
// El widget acepta los mismos parámetros habituales de Icon
// (size, color) y además `filled: true` para rellenar la forma
// (estrella rellena, corazón relleno...).
//
// Iconos 3D (fix3, punto 6): `threeD: true` aplica el degradado
// de su propio color (en el relleno si el icono ya es `filled`,
// en el trazo si no — para conservar el detalle interno) y un
// brillito blanco arriba a la izquierda — el mismo tratamiento del
// corazón de las vidas (coral #FF6B6B → #EF4444 + brillo),
// generalizado a cualquier color de acento con
// [LucideIcon.threeDGradient]. Cada icono mantiene SU color (teal,
// violeta, ámbar...); solo cambia el render, nunca el path. Los
// iconos 3D son los más visibles (barra inferior, menú, tarjetas,
// estadísticas, quiz); los de campos de texto, la AppBar y los
// glifos blancos sobre disco de color siguen planos, a propósito.

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Un elemento de un icono SVG de Lucide: un path o una primitiva
/// (círculo, línea, polilínea, polígono o rectángulo).
abstract class LucideElement {
  const LucideElement();

  Path toPath();
}

/// Un `<path d="...">` de Lucide.
class _SvgPath extends LucideElement {
  const _SvgPath(this.d);

  final String d;

  @override
  Path toPath() => _parseSvgPath(d);
}

/// Un `<circle cx cy r>`.
class _SvgCircle extends LucideElement {
  const _SvgCircle(this.cx, this.cy, this.r);

  final double cx;
  final double cy;
  final double r;

  @override
  Path toPath() {
    return Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
  }
}

/// Una `<line x1 y1 x2 y2>`.
class _SvgLine extends LucideElement {
  const _SvgLine(this.x1, this.y1, this.x2, this.y2);

  final double x1;
  final double y1;
  final double x2;
  final double y2;

  @override
  Path toPath() {
    return Path()
      ..moveTo(x1, y1)
      ..lineTo(x2, y2);
  }
}

/// Un `<rect x y width height rx ry>`.
class _SvgRect extends LucideElement {
  const _SvgRect(this.x, this.y, this.w, this.h, this.rx, this.ry);

  final double x;
  final double y;
  final double w;
  final double h;
  final double rx;
  final double ry;

  @override
  Path toPath() {
    if (rx <= 0 && ry <= 0) {
      return Path()..addRect(Rect.fromLTWH(x, y, w, h));
    }
    // En SVG, si solo hay rx, ry vale lo mismo que rx.
    final radius = rx > 0 ? rx : ry;
    return Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        Radius.circular(radius),
      ));
  }
}

/// Los datos de un icono: su lista de elementos, en el orden del SVG.
class LucideIconData {
  const LucideIconData(this.elements);

  final List<LucideElement> elements;

  /// Las rutas del icono, listas para dibujar.
  List<Path> get paths => elements.map((e) => e.toPath()).toList();
}

/// Un icono Lucide, dibujado como vector con trazo fino y puntas
/// redondas, igual que en lucide.dev.
///
/// [filled] rellena las formas con [color] (o con [fillGradient])
/// en vez de dibujar solo el contorno: para el corazón de las vidas
/// y la estrella de los puntos.
///
/// [threeD] es el tratamiento 3D del corazón de las vidas aplicado
/// a cualquier icono: degradado de su propio color
/// ([threeDGradient]) + brillito blanco. El icono sigue siendo el
/// mismo path Lucide; solo cambia el render. Con [filled] el
/// degradado va en el relleno (estrella, llama); sin él, va en el
/// TRAZO, para no tapar el detalle interno (el reloj conserva sus
/// manecillas, el trofeo su copa, la gorra su ala...).
class LucideIcon extends StatelessWidget {
  const LucideIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth = 2,
    this.filled = false,
    this.fillGradient,
    this.threeD = false,
  });

  /// Degradado 3D para un color de acento: más claro arriba, el
  /// color base abajo. Es el mismo par del corazón de las vidas
  /// (coral claro #FF6B6B → coral base #EF4444) pero calculado
  /// desde cualquier acento: se aclara el color un 12 % de
  /// luminosidad (HSL) para la parte superior.
  static LinearGradient threeDGradient(Color accent) {
    final hsl = HSLColor.fromColor(accent);
    final light = hsl
        .withLightness((hsl.lightness + 0.12).clamp(0.0, 0.95))
        .toColor();
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [light, accent],
    );
  }

  final LucideIconData icon;
  final double size;
  final Color? color;
  final double strokeWidth;
  final bool filled;
  final Gradient? fillGradient;
  final bool threeD;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ??
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color ??
        Colors.black;
    // 3D (fix3, punto 6): el degradado es el de SU color (sin
    // tocar el path) y el pintor añade el brillo. OJO: 3D no
    // implica relleno — el relleno solo va cuando el icono ya era
    // relleno (estrella, llama); los de trazo conservan su trazo
    // con el degradado encima, para no perder su detalle interno.
    final effectiveGradient =
        threeD ? threeDGradient(effectiveColor) : fillGradient;
    // SizedBox con el tamaño nominal (auditoría fix2): el CustomPaint
    // solo respeta su `size` cuando el padre no le impone otras
    // medidas; en un Column con stretch o en el prefixIcon de un
    // TextField, el padre lo estiraba (la lupa de búsqueda salía
    // gigante). Con el SizedBox, el icono mide SIEMPRE `size`,
    // estire quien estire.
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _LucidePainter(
          data: icon,
          color: effectiveColor,
          strokeWidth: strokeWidth,
          filled: filled,
          fillGradient: effectiveGradient,
          threeD: threeD,
          nominalSize: size,
        ),
      ),
    );
  }
}

class _LucidePainter extends CustomPainter {
  _LucidePainter({
    required this.data,
    required this.color,
    required this.strokeWidth,
    required this.filled,
    required this.fillGradient,
    required this.threeD,
    required this.nominalSize,
  });

  final LucideIconData data;
  final Color color;
  final double strokeWidth;
  final bool filled;
  final Gradient? fillGradient;

  /// 3D (fix3, punto 6): tras rellenar, pinta el brillito blanco
  /// del corazón de las vidas sobre el glifo.
  final bool threeD;

  /// El tamaño que el icono DEBE dibujar, venga el lienzo como
  /// venga (el widget le pasa su `size`).
  final double nominalSize;

  @override
  void paint(Canvas canvas, Size size) {
    // Dibuja SIEMPRE al tamaño nominal, centrado en el lienzo
    // (auditoría fix2): el padre puede estirar el CustomPaint
    // (Column con stretch, prefixIcon de un TextField) y antes el
    // glifo crecía con el lienzo (la lupa gigante, el mando gigante).
    // Ahora el glifo mide `nominalSize` y queda centrado, estire
    // quien estire el hueco.
    final scale = nominalSize / 24;
    canvas.save();
    canvas.translate(
      (size.width - nominalSize) / 2,
      (size.height - nominalSize) / 2,
    );
    canvas.scale(scale, scale);
    final paths = data.paths;
    if (filled) {
      final fillPaint = Paint()..style = PaintingStyle.fill;
      if (fillGradient != null) {
        var bounds = paths.first.getBounds();
        for (final p in paths.skip(1)) {
          bounds = bounds.expandToInclude(p.getBounds());
        }
        fillPaint.shader = fillGradient!.createShader(bounds);
      } else {
        fillPaint.color = color;
      }
      for (final p in paths) {
        canvas.drawPath(p, fillPaint);
      }
    } else {
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      // 3D en trazo (fix3, punto 6): el degradado del color va en
      // el trazo, no en un relleno — el icono conserva su forma y
      // su detalle interno (manecillas del reloj, copa del trofeo).
      if (threeD && fillGradient != null && paths.isNotEmpty) {
        var bounds = paths.first.getBounds();
        for (final p in paths.skip(1)) {
          bounds = bounds.expandToInclude(p.getBounds());
        }
        strokePaint.shader = fillGradient!.createShader(bounds);
      }
      for (final p in paths) {
        canvas.drawPath(p, strokePaint);
      }
    }
    // Brillito 3D (fix3, punto 6): el mismo del corazón de las
    // vidas (óvalo blanco girado, 55 % de opacidad), pero centrado
    // en la parte superior-izquierda del glifo — no en un punto
    // fijo, porque cada icono ocupa el viewBox de forma distinta
    // (el mando es ancho y bajo, la llama alta y estrecha...).
    // Así el brillo cae siempre SOBRE el relleno, nunca flotando
    // en el vacío junto al icono.
    if (threeD && paths.isNotEmpty) {
      var bounds = paths.first.getBounds();
      for (final p in paths.skip(1)) {
        bounds = bounds.expandToInclude(p.getBounds());
      }
      if (bounds.width > 0 && bounds.height > 0) {
        canvas.save();
        canvas.translate(
          bounds.left + bounds.width * 0.30,
          bounds.top + bounds.height * 0.26,
        );
        canvas.rotate(-0.5);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: bounds.width * 0.30,
            height: bounds.height * 0.14,
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.55),
        );
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LucidePainter old) {
    return old.data != data ||
        old.color != color ||
        old.strokeWidth != strokeWidth ||
        old.filled != filled ||
        old.fillGradient != fillGradient ||
        old.threeD != threeD;
  }
}

// ---------------------------------------------------------------------------
// Mini analizador de rutas SVG (atributo d): M/L/H/V/C/S/Q/T/A/Z, en
// absoluto y relativo, con repetición implícita del comando.
// ---------------------------------------------------------------------------

class _SvgLexer {
  _SvgLexer(this._input);

  final String _input;
  int _pos = 0;

  void _skipSeparators() {
    while (_pos < _input.length) {
      final c = _input[_pos];
      if (c == ' ' ||
          c == ',' ||
          c == '\n' ||
          c == '\t' ||
          c == '\r') {
        _pos++;
      } else {
        break;
      }
    }
  }

  bool get done {
    _skipSeparators();
    return _pos >= _input.length;
  }

  bool get peekIsCommand {
    _skipSeparators();
    if (_pos >= _input.length) return false;
    final code = _input.codeUnitAt(_pos);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  String nextCommand() => _input[_pos++];

  bool get nextIsNumber {
    _skipSeparators();
    if (_pos >= _input.length) return false;
    final code = _input.codeUnitAt(_pos);
    return code == 43 || // +
        code == 45 || // -
        code == 46 || // .
        (code >= 48 && code <= 57);
  }

  double nextNumber() {
    _skipSeparators();
    final match = _numberRe.matchAsPrefix(_input, _pos);
    if (match == null) {
      throw FormatException('Invalid double', _input, _pos);
    }
    _pos = match.end;
    return double.parse(match.group(0)!);
  }

  /// Las banderas de arco (large-arc y sweep) son UN solo dígito y
  /// pueden ir pegadas entre sí y a la coordenada siguiente ("0022"
  /// es 0, 0, 22, no 22): se lee un solo carácter, nunca un número.
  bool nextFlag() {
    _skipSeparators();
    if (_pos >= _input.length) {
      throw const FormatException('Falta bandera de arco');
    }
    final c = _input[_pos++];
    if (c != '0' && c != '1') {
      throw FormatException('Bandera de arco inválida: $c', _input, _pos);
    }
    return c == '1';
  }

  static final _numberRe =
      RegExp(r'[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?');
}

Path _parseSvgPath(String d) {
  final path = Path();
  final lex = _SvgLexer(d);
  var cx = 0.0;
  var cy = 0.0;
  var startX = 0.0;
  var startY = 0.0;
  // Puntos de control anteriores (para S y T).
  var prevCubicX = 0.0;
  var prevCubicY = 0.0;
  var prevQuadX = 0.0;
  var prevQuadY = 0.0;
  var prevCommand = '';

  void lineTo(double x, double y) {
    path.lineTo(x, y);
    cx = x;
    cy = y;
  }

  while (!lex.done) {
    if (!lex.peekIsCommand) {
      // Sin comando explícito: se repite el anterior (salvo tras M,
      // que pasa a ser L).
      if (prevCommand.isEmpty) break;
    }
    final cmd = lex.peekIsCommand ? lex.nextCommand() : prevCommand;
    final relative = cmd == cmd.toLowerCase() && cmd != 'Z' && cmd != 'z';
    final c = cmd.toUpperCase();
    switch (c) {
      case 'M':
        {
          final x = lex.nextNumber() + (relative ? cx : 0);
          final y = lex.nextNumber() + (relative ? cy : 0);
          path.moveTo(x, y);
          cx = x;
          cy = y;
          startX = x;
          startY = y;
          // Los pares que siguen a M son L implícitos.
          prevCommand = relative ? 'l' : 'L';
          break;
        }
      case 'L':
        while (lex.nextIsNumber) {
          final x = lex.nextNumber() + (relative ? cx : 0);
          final y = lex.nextNumber() + (relative ? cy : 0);
          lineTo(x, y);
        }
        prevCommand = cmd;
        break;
      case 'H':
        while (lex.nextIsNumber) {
          final x = lex.nextNumber() + (relative ? cx : 0);
          lineTo(x, cy);
        }
        prevCommand = cmd;
        break;
      case 'V':
        while (lex.nextIsNumber) {
          final y = lex.nextNumber() + (relative ? cy : 0);
          lineTo(cx, y);
        }
        prevCommand = cmd;
        break;
      case 'C':
        while (lex.nextIsNumber) {
          final x1 = lex.nextNumber() + (relative ? cx : 0);
          final y1 = lex.nextNumber() + (relative ? cy : 0);
          final x2 = lex.nextNumber() + (relative ? cx : 0);
          final y2 = lex.nextNumber() + (relative ? cy : 0);
          final x = lex.nextNumber() + (relative ? cx : 0);
          final y = lex.nextNumber() + (relative ? cy : 0);
          path.cubicTo(x1, y1, x2, y2, x, y);
          prevCubicX = x2;
          prevCubicY = y2;
          prevQuadX = x;
          prevQuadY = y;
          cx = x;
          cy = y;
        }
        prevCommand = cmd;
        break;
      case 'S':
        while (lex.nextIsNumber) {
          final x1 = prevCommand == 'C' || prevCommand == 'c' || prevCommand == 'S' || prevCommand == 's'
              ? 2 * cx - prevCubicX
              : cx;
          final y1 = prevCommand == 'C' || prevCommand == 'c' || prevCommand == 'S' || prevCommand == 's'
              ? 2 * cy - prevCubicY
              : cy;
          final x2 = lex.nextNumber() + (relative ? cx : 0);
          final y2 = lex.nextNumber() + (relative ? cy : 0);
          final x = lex.nextNumber() + (relative ? cx : 0);
          final y = lex.nextNumber() + (relative ? cy : 0);
          path.cubicTo(x1, y1, x2, y2, x, y);
          prevCubicX = x2;
          prevCubicY = y2;
          prevQuadX = x;
          prevQuadY = y;
          cx = x;
          cy = y;
        }
        prevCommand = cmd;
        break;
      case 'Q':
        while (lex.nextIsNumber) {
          final x1 = lex.nextNumber() + (relative ? cx : 0);
          final y1 = lex.nextNumber() + (relative ? cy : 0);
          final x = lex.nextNumber() + (relative ? cx : 0);
          final y = lex.nextNumber() + (relative ? cy : 0);
          path.quadraticBezierTo(x1, y1, x, y);
          prevQuadX = x1;
          prevQuadY = y1;
          prevCubicX = x;
          prevCubicY = y;
          cx = x;
          cy = y;
        }
        prevCommand = cmd;
        break;
      case 'T':
        while (lex.nextIsNumber) {
          final x1 = prevCommand == 'Q' || prevCommand == 'q' || prevCommand == 'T' || prevCommand == 't'
              ? 2 * cx - prevQuadX
              : cx;
          final y1 = prevCommand == 'Q' || prevCommand == 'q' || prevCommand == 'T' || prevCommand == 't'
              ? 2 * cy - prevQuadY
              : cy;
          final x = lex.nextNumber() + (relative ? cx : 0);
          final y = lex.nextNumber() + (relative ? cy : 0);
          path.quadraticBezierTo(x1, y1, x, y);
          prevQuadX = x1;
          prevQuadY = y1;
          prevCubicX = x;
          prevCubicY = y;
          cx = x;
          cy = y;
        }
        prevCommand = cmd;
        break;
      case 'A':
        while (lex.nextIsNumber) {
          final rx = lex.nextNumber();
          final ry = lex.nextNumber();
          final rotation = lex.nextNumber();
          final largeArc = lex.nextFlag();
          final sweep = lex.nextFlag();
          final x = lex.nextNumber() + (relative ? cx : 0);
          final y = lex.nextNumber() + (relative ? cy : 0);
          _arcTo(path, cx, cy, rx, ry, rotation, largeArc, sweep, x, y);
          prevCubicX = x;
          prevCubicY = y;
          prevQuadX = x;
          prevQuadY = y;
          cx = x;
          cy = y;
        }
        prevCommand = cmd;
        break;
      case 'Z':
        path.close();
        cx = startX;
        cy = startY;
        prevCommand = cmd;
        break;
      default:
        // Comando desconocido: se salta.
        prevCommand = cmd;
        break;
    }
  }
  return path;
}

/// Arco elíptico SVG (punto final a centro), aproximado con tramos
/// de Bézier cúbica de como mucho 90º (fórmula estándar del W3C).
void _arcTo(
  Path path,
  double x1,
  double y1,
  double rxIn,
  double ryIn,
  double rotationDeg,
  bool largeArc,
  bool sweep,
  double x2,
  double y2,
) {
  if (rxIn == 0 || ryIn == 0) {
    path.lineTo(x2, y2);
    return;
  }
  var rx = rxIn.abs();
  var ry = ryIn.abs();
  final phi = rotationDeg * math.pi / 180;
  final cosPhi = math.cos(phi);
  final sinPhi = math.sin(phi);
  final dx = (x1 - x2) / 2;
  final dy = (y1 - y2) / 2;
  final x1p = cosPhi * dx + sinPhi * dy;
  final y1p = -sinPhi * dx + cosPhi * dy;
  final lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
  if (lambda > 1) {
    final s = math.sqrt(lambda);
    rx *= s;
    ry *= s;
  }
  final num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p;
  final den = rx * rx * y1p * y1p + ry * ry * x1p * x1p;
  var coef = den == 0 ? 0.0 : math.sqrt(math.max(0, num / den));
  if (largeArc == sweep) coef = -coef;
  final cxp = coef * rx * y1p / ry;
  final cyp = -coef * ry * x1p / rx;
  final cx = cosPhi * cxp - sinPhi * cyp + (x1 + x2) / 2;
  final cy = sinPhi * cxp + cosPhi * cyp + (y1 + y2) / 2;

  double angle(double ux, double uy, double vx, double vy) {
    final dot = ux * vx + uy * vy;
    final len = math.sqrt(ux * ux + uy * uy) * math.sqrt(vx * vx + vy * vy);
    var a = math.acos((dot / len).clamp(-1, 1));
    if (ux * vy - uy * vx < 0) a = -a;
    return a;
  }

  final theta1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry);
  var dTheta = angle(
    (x1p - cxp) / rx,
    (y1p - cyp) / ry,
    (-x1p - cxp) / rx,
    (-y1p - cyp) / ry,
  );
  if (!sweep && dTheta > 0) dTheta -= 2 * math.pi;
  if (sweep && dTheta < 0) dTheta += 2 * math.pi;

  Offset pointOnEllipse(double theta) {
    final ex = rx * math.cos(theta);
    final ey = ry * math.sin(theta);
    return Offset(
      cx + cosPhi * ex - sinPhi * ey,
      cy + sinPhi * ex + cosPhi * ey,
    );
  }

  final segments = (dTheta.abs() / (math.pi / 2)).ceil().clamp(1, 64);
  final delta = dTheta / segments;
  var theta = theta1;
  for (var i = 0; i < segments; i++) {
    final thetaNext = theta + delta;
    // Factor de los puntos de control (aproximación de Bézier).
    final k = 4 / 3 * math.tan(delta / 4);
    final p0 = pointOnEllipse(theta);
    final p3 = pointOnEllipse(thetaNext);
    // Derivadas en los extremos (tangentes a la elipse rotada).
    Offset tangent(double t) {
      final dxd = -rx * math.sin(t);
      final dyd = ry * math.cos(t);
      return Offset(
        cosPhi * dxd - sinPhi * dyd,
        sinPhi * dxd + cosPhi * dyd,
      );
    }

    final t0 = tangent(theta);
    final t1 = tangent(thetaNext);
    path.cubicTo(
      p0.dx + k * t0.dx,
      p0.dy + k * t0.dy,
      p3.dx - k * t1.dx,
      p3.dy - k * t1.dy,
      p3.dx,
      p3.dy,
    );
    theta = thetaNext;
  }
}

// ---------------------------------------------------------------------------
// Datos de iconos generados desde los SVG oficiales de Lucide
// (https://lucide.dev, lucide-static 1.71.0, licencia ISC).
// Generado por tools/convert_lucide.py: no editar a mano los datos.
// ---------------------------------------------------------------------------

class LucideIcons {
  LucideIcons._();

  static const LucideIconData alarmClock = LucideIconData([
    _SvgCircle(12, 13, 8),
    _SvgPath('M12 9v4l2 2'),
    _SvgPath('M5 3 2 6'),
    _SvgPath('m22 6-3-3'),
    _SvgPath('M6.38 18.7 4 21'),
    _SvgPath('M17.64 18.67 20 21'),
  ]);

  static const LucideIconData arrowLeftRight = LucideIconData([
    _SvgPath('M8 3 4 7l4 4'),
    _SvgPath('M4 7h16'),
    _SvgPath('m16 21 4-4-4-4'),
    _SvgPath('M20 17H4'),
  ]);

  static const LucideIconData arrowLeft = LucideIconData([
    _SvgPath('m12 19-7-7 7-7'),
    _SvgPath('M19 12H5'),
  ]);

  static const LucideIconData arrowRight = LucideIconData([
    _SvgPath('M5 12h14'),
    _SvgPath('m12 5 7 7-7 7'),
  ]);

  static const LucideIconData atom = LucideIconData([
    _SvgCircle(12, 12, 1),
    _SvgPath('M20.2 20.2c2.04-2.03.02-7.36-4.5-11.9-4.54-4.52-9.87-6.54-11.9-4.5-2.04 2.03-.02 7.36 4.5 11.9 4.54 4.52 9.87 6.54 11.9 4.5Z'),
    _SvgPath('M15.7 15.7c4.52-4.54 6.54-9.87 4.5-11.9-2.03-2.04-7.36-.02-11.9 4.5-4.52 4.54-6.54 9.87-4.5 11.9 2.03 2.04 7.36.02 11.9-4.5Z'),
  ]);

  static const LucideIconData award = LucideIconData([
    _SvgPath('m15.477 12.89 1.515 8.526a.5.5 0 0 1-.81.47l-3.58-2.687a1 1 0 0 0-1.197 0l-3.586 2.686a.5.5 0 0 1-.81-.469l1.514-8.526'),
    _SvgCircle(12, 8, 6),
  ]);

  static const LucideIconData badgeCheck = LucideIconData([
    _SvgPath('M3.85 8.62a4 4 0 0 1 4.78-4.77 4 4 0 0 1 6.74 0 4 4 0 0 1 4.78 4.78 4 4 0 0 1 0 6.74 4 4 0 0 1-4.77 4.78 4 4 0 0 1-6.75 0 4 4 0 0 1-4.78-4.77 4 4 0 0 1 0-6.76Z'),
    _SvgPath('m16 9-5.5 5.5L8 12'),
  ]);

  static const LucideIconData ban = LucideIconData([
    _SvgCircle(12, 12, 10),
    _SvgPath('M4.929 4.929 19.07 19.071'),
  ]);

  static const LucideIconData barChart3 = LucideIconData([
    _SvgPath('M3 3v16a2 2 0 0 0 2 2h16'),
    _SvgPath('M18 17V9'),
    _SvgPath('M13 17V5'),
    _SvgPath('M8 17v-3'),
  ]);

  static const LucideIconData beaker = LucideIconData([
    _SvgPath('M4.5 3h15'),
    _SvgPath('M6 3v16a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2V3'),
    _SvgPath('M6 14h12'),
  ]);

  static const LucideIconData bellRing = LucideIconData([
    _SvgPath('M10.268 21a2 2 0 0 0 3.464 0'),
    _SvgPath('M22 8c0-2.3-.8-4.3-2-6'),
    _SvgPath('M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326'),
    _SvgPath('M4 2C2.8 3.7 2 5.7 2 8'),
  ]);

  static const LucideIconData bell = LucideIconData([
    _SvgPath('M10.268 21a2 2 0 0 0 3.464 0'),
    _SvgPath('M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326'),
  ]);

  static const LucideIconData bookOpen = LucideIconData([
    _SvgPath('M12 5v16'),
    _SvgPath('M20.001 19A2 2 0 0022 17V5a2 2 0 00-1.999-2L16 3.002A5 5 0 0012 5a5 5 0 00-4-2H4a2 2 0 00-2 2v12a2 2 0 001.999 2H8a5 5 0 014 2 5 5 0 014-2z'),
  ]);

  static const LucideIconData book = LucideIconData([
    _SvgPath('M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H19a1 1 0 0 1 1 1v18a1 1 0 0 1-1 1H6.5a1 1 0 0 1 0-5H20'),
  ]);

  static const LucideIconData bookmark = LucideIconData([
    _SvgPath('M17 3a2 2 0 0 1 2 2v15a1 1 0 0 1-1.496.868l-4.512-2.578a2 2 0 0 0-1.984 0l-4.512 2.578A1 1 0 0 1 5 20V5a2 2 0 0 1 2-2z'),
  ]);

  static const LucideIconData brain = LucideIconData([
    _SvgPath('M12 18V5'),
    _SvgPath('M15 13a4.17 4.17 0 01-3-4 4.17 4.17 0 01-3 4'),
    _SvgPath('M17.707 6.294A3 3 0 1012 5a3 3 0 10-5.707 1.294'),
    _SvgPath('M17.996 5.125a4 4 0 012.526 5.77'),
    _SvgPath('M18 18a4 4 0 002-7.465'),
    _SvgPath('M19.967 17.482a4 4 0 11-7.967.517 4 4 0 11-7.967-.517'),
    _SvgPath('M6 18a4 4 0 01-2-7.465'),
    _SvgPath('M6.004 5.125a4 4 0 00-2.526 5.77'),
  ]);

  static const LucideIconData calculator = LucideIconData([
    _SvgRect(4, 2, 16, 20, 2, 0),
    _SvgLine(8, 6, 16, 6),
    _SvgLine(16, 14, 16, 18),
    _SvgPath('M16 10h.01'),
    _SvgPath('M12 10h.01'),
    _SvgPath('M8 10h.01'),
    _SvgPath('M12 14h.01'),
    _SvgPath('M8 14h.01'),
    _SvgPath('M12 18h.01'),
    _SvgPath('M8 18h.01'),
  ]);

  static const LucideIconData calendar = LucideIconData([
    _SvgPath('M8 2v3'),
    _SvgPath('M16 2v3'),
    _SvgRect(3, 3, 18, 18, 2, 0),
    _SvgPath('M3 9h18'),
  ]);

  static const LucideIconData chartColumn = LucideIconData([
    _SvgPath('M3 3v16a2 2 0 0 0 2 2h16'),
    _SvgPath('M18 17V9'),
    _SvgPath('M13 17V5'),
    _SvgPath('M8 17v-3'),
  ]);

  static const LucideIconData checkCheck = LucideIconData([
    _SvgPath('M18 6 7 17l-5-5'),
    _SvgPath('m22 10-7.5 7.5L13 16'),
  ]);

  static const LucideIconData check = LucideIconData([
    _SvgPath('M20 6 9 17l-5-5'),
  ]);

  static const LucideIconData chevronRight = LucideIconData([
    _SvgPath('m9 18 6-6-6-6'),
  ]);

  static const LucideIconData circleCheck = LucideIconData([
    _SvgCircle(12, 12, 10),
    _SvgPath('m16 9-5.5 5.5L8 12'),
  ]);

  static const LucideIconData circleDashed = LucideIconData([
    _SvgPath('M10.1 2.182a10 10 0 0 1 3.8 0'),
    _SvgPath('M13.9 21.818a10 10 0 0 1-3.8 0'),
    _SvgPath('M17.609 3.721a10 10 0 0 1 2.69 2.7'),
    _SvgPath('M2.182 13.9a10 10 0 0 1 0-3.8'),
    _SvgPath('M20.279 17.609a10 10 0 0 1-2.7 2.69'),
    _SvgPath('M21.818 10.1a10 10 0 0 1 0 3.8'),
    _SvgPath('M3.721 6.391a10 10 0 0 1 2.7-2.69'),
    _SvgPath('M6.391 20.279a10 10 0 0 1-2.69-2.7'),
  ]);

  static const LucideIconData circleHelp = LucideIconData([
    _SvgCircle(12, 12, 10),
    _SvgPath('M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3'),
    _SvgPath('M12 17h.01'),
  ]);

  static const LucideIconData circleX = LucideIconData([
    _SvgCircle(12, 12, 10),
    _SvgPath('m15 9-6 6'),
    _SvgPath('m9 9 6 6'),
  ]);

  static const LucideIconData circle = LucideIconData([
    _SvgCircle(12, 12, 10),
  ]);

  static const LucideIconData clipboardList = LucideIconData([
    _SvgRect(8, 2, 8, 4, 1, 1),
    _SvgPath('M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2'),
    _SvgPath('M12 11h4'),
    _SvgPath('M12 16h4'),
    _SvgPath('M8 11h.01'),
    _SvgPath('M8 16h.01'),
  ]);

  static const LucideIconData clock = LucideIconData([
    _SvgCircle(12, 12, 10),
    _SvgPath('M12 6v6l4 2'),
  ]);

  static const LucideIconData cloud = LucideIconData([
    _SvgPath('M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z'),
  ]);

  static const LucideIconData compass = LucideIconData([
    _SvgCircle(12, 12, 10),
    _SvgPath('m16.24 7.76-1.804 5.411a2 2 0 0 1-1.265 1.265L7.76 16.24l1.804-5.411a2 2 0 0 1 1.265-1.265z'),
  ]);

  static const LucideIconData copy = LucideIconData([
    _SvgRect(8, 8, 14, 14, 2, 2),
    _SvgPath('M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2'),
  ]);

  /// Corona (Lucide, añadida en la ronda de diseño 7.0): la
  /// insignia del 1º de la tabla de posiciones.
  static const LucideIconData crown = LucideIconData([
    _SvgPath(
        'M11.562 3.266a.5.5 0 0 1 .876 0L15.39 8.87a1 1 0 0 0 1.516.294L21.183 5.5a.5.5 0 0 1 .798.519l-2.834 10.246a1 1 0 0 1-.956.735H5.81a1 1 0 0 1-.957-.735L2.02 6.02a.5.5 0 0 1 .798-.519l4.276 3.664a1 1 0 0 0 1.516-.294z'),
    _SvgPath('M5 21h14'),
  ]);

  static const LucideIconData dna = LucideIconData([
    _SvgPath('m10 16 1.5 1.5'),
    _SvgPath('m14 8-1.5-1.5'),
    _SvgPath('M15 2c-1.798 1.998-2.518 3.995-2.807 5.993'),
    _SvgPath('m16.5 10.5 1 1'),
    _SvgPath('m17 6-2.891-2.891'),
    _SvgPath('M2 15c6.667-6 13.333 0 20-6'),
    _SvgPath('m20 9 .891.891'),
    _SvgPath('M3.109 14.109 4 15'),
    _SvgPath('m6.5 12.5 1 1'),
    _SvgPath('m7 18 2.891 2.891'),
    _SvgPath('M9 22c1.798-1.998 2.518-3.995 2.807-5.993'),
  ]);

  static const LucideIconData download = LucideIconData([
    _SvgPath('M12 15V3'),
    _SvgPath('M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4'),
    _SvgPath('m7 10 5 5 5-5'),
  ]);

  static const LucideIconData droplet = LucideIconData([
    _SvgPath('M12 22a7 7 0 0 0 7-7c0-2-1-3.9-3-5.5s-3.5-4-4-6.5c-.5 2.5-2 4.9-4 6.5C6 11.1 5 13 5 15a7 7 0 0 0 7 7z'),
  ]);

  static const LucideIconData eyeOff = LucideIconData([
    _SvgPath('M10.733 5.076a10.744 10.744 0 0 1 11.205 6.575 1 1 0 0 1 0 .696 10.747 10.747 0 0 1-1.444 2.49'),
    _SvgPath('M14.084 14.158a3 3 0 0 1-4.242-4.242'),
    _SvgPath('M17.479 17.499a10.75 10.75 0 0 1-15.417-5.151 1 1 0 0 1 0-.696 10.75 10.75 0 0 1 4.446-5.143'),
    _SvgPath('m2 2 20 20'),
  ]);

  static const LucideIconData eye = LucideIconData([
    _SvgPath('M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0'),
    _SvgCircle(12, 12, 3),
  ]);

  static const LucideIconData flag = LucideIconData([
    _SvgPath('M4 22V4a1 1 0 0 1 .4-.8A6 6 0 0 1 8 2c3 0 5 2 7.333 2q2 0 3.067-.8A1 1 0 0 1 20 4v10a1 1 0 0 1-.4.8A6 6 0 0 1 16 16c-3 0-5-2-8-2a6 6 0 0 0-4 1.528'),
  ]);

  static const LucideIconData flame = LucideIconData([
    _SvgPath('M12 3q1 4 4 6.5t3 5.5a1 1 0 0 1-14 0 5 5 0 0 1 1-3 1 1 0 0 0 5 0c0-2-1.5-3-1.5-5q0-2 2.5-4'),
  ]);

  static const LucideIconData flaskConical = LucideIconData([
    _SvgPath('M14 2v6a2 2 0 0 0 .245.96l5.51 10.08A2 2 0 0 1 18 22H6a2 2 0 0 1-1.755-2.96l5.51-10.08A2 2 0 0 0 10 8V2'),
    _SvgPath('M6.453 15h11.094'),
    _SvgPath('M8.5 2h7'),
  ]);

  static const LucideIconData gamepad2 = LucideIconData([
    _SvgLine(6, 11, 10, 11),
    _SvgLine(8, 9, 8, 13),
    _SvgLine(15, 12, 15.01, 12),
    _SvgLine(18, 10, 18.01, 10),
    _SvgPath('M17.32 5H6.68a4 4 0 0 0-3.978 3.59c-.006.052-.01.101-.017.152C2.604 9.416 2 14.456 2 16a3 3 0 0 0 3 3c1 0 1.5-.5 2-1l1.414-1.414A2 2 0 0 1 9.828 16h4.344a2 2 0 0 1 1.414.586L17 18c.5.5 1 1 2 1a3 3 0 0 0 3-3c0-1.545-.604-6.584-.685-7.258-.007-.05-.011-.1-.017-.151A4 4 0 0 0 17.32 5z'),
  ]);

  static const LucideIconData gift = LucideIconData([
    _SvgPath('M12 7v14'),
    _SvgPath('M20 11v8a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-8'),
    _SvgPath('M7.5 7a1 1 0 0 1 0-5A4.8 8 0 0 1 12 7a4.8 8 0 0 1 4.5-5 1 1 0 0 1 0 5'),
    _SvgRect(3, 7, 18, 4, 1, 0),
  ]);

  static const LucideIconData gitMerge = LucideIconData([
    _SvgCircle(18, 18, 3),
    _SvgCircle(6, 6, 3),
    _SvgPath('M6 21V9a9 9 0 0 0 9 9'),
  ]);

  static const LucideIconData globe = LucideIconData([
    _SvgCircle(12, 12, 10),
    _SvgPath('M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20'),
    _SvgPath('M2 12h20'),
  ]);

  static const LucideIconData graduationCap = LucideIconData([
    _SvgPath('M21.42 10.922a1 1 0 0 0-.019-1.838L12.83 5.18a2 2 0 0 0-1.66 0L2.6 9.08a1 1 0 0 0 0 1.832l8.57 3.908a2 2 0 0 0 1.66 0z'),
    _SvgPath('M22 10v6'),
    _SvgPath('M6 12.5V16a6 3 0 0 0 12 0v-3.5'),
  ]);

  static const LucideIconData heartPulse = LucideIconData([
    _SvgPath('M2 9.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 2.29-1.5 4-3 5.5l-5.492 5.313a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5'),
    _SvgPath('M3.22 13H9.5l.5-1 2 4.5 2-7 1.5 3.5h5.27'),
  ]);

  static const LucideIconData heart = LucideIconData([
    _SvgPath('M2 9.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 2.29-1.5 4-3 5.5l-5.492 5.313a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5'),
  ]);

  static const LucideIconData hexagon = LucideIconData([
    _SvgPath('M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z'),
  ]);

  static const LucideIconData history = LucideIconData([
    _SvgPath('M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8'),
    _SvgPath('M3 3v5h5'),
    _SvgPath('M12 7v5l4 2'),
  ]);

  static const LucideIconData home = LucideIconData([
    _SvgPath('M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8'),
    _SvgPath('M3 10a2 2 0 0 1 .709-1.528l7-6a2 2 0 0 1 2.582 0l7 6A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z'),
  ]);

  static const LucideIconData hourglass = LucideIconData([
    _SvgPath('M5 22h14'),
    _SvgPath('M5 2h14'),
    _SvgPath('M17 22v-4.172a2 2 0 0 0-.586-1.414L12 12l-4.414 4.414A2 2 0 0 0 7 17.828V22'),
    _SvgPath('M7 2v4.172a2 2 0 0 0 .586 1.414L12 12l4.414-4.414A2 2 0 0 0 17 6.172V2'),
  ]);

  static const LucideIconData image = LucideIconData([
    _SvgRect(3, 3, 18, 18, 2, 2),
    _SvgCircle(9, 9, 2),
    _SvgPath('m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21'),
  ]);

  static const LucideIconData info = LucideIconData([
    _SvgCircle(12, 12, 10),
    _SvgPath('M12 16v-4'),
    _SvgPath('M12 8h.01'),
  ]);

  static const LucideIconData keyboard = LucideIconData([
    _SvgRect(2, 4, 20, 16, 2, 0),
    _SvgPath('M6 8h.01'),
    _SvgPath('M10 8h.01'),
    _SvgPath('M14 8h.01'),
    _SvgPath('M18 8h.01'),
    _SvgPath('M6 12h.01'),
    _SvgPath('M10 12h.01'),
    _SvgPath('M14 12h.01'),
    _SvgPath('M18 12h.01'),
    _SvgPath('M7 16h10'),
  ]);

  static const LucideIconData landmark = LucideIconData([
    _SvgPath('M10 18v-7'),
    _SvgPath('M11.119 2.205a2 2 0 0 1 1.762 0l7.84 3.846A.5.5 0 0 1 20.5 7h-17a.5.5 0 0 1-.22-.949z'),
    _SvgPath('M14 18v-7'),
    _SvgPath('M18 18v-7'),
    _SvgPath('M3 22h18'),
    _SvgPath('M6 18v-7'),
  ]);

  static const LucideIconData languages = LucideIconData([
    _SvgPath('m5 8 6 6'),
    _SvgPath('m4 14 6-6 2-3'),
    _SvgPath('M2 5h12'),
    _SvgPath('M7 2h1'),
    _SvgPath('m22 22-5-10-5 10'),
    _SvgPath('M14 18h6'),
  ]);

  static const LucideIconData layers2 = LucideIconData([
    _SvgPath('M13 13.74a2 2 0 0 1-2 0L2.5 8.87a1 1 0 0 1 0-1.74L11 2.26a2 2 0 0 1 2 0l8.5 4.87a1 1 0 0 1 0 1.74z'),
    _SvgPath('m20 14.285 1.5.845a1 1 0 0 1 0 1.74L13 21.74a2 2 0 0 1-2 0l-8.5-4.87a1 1 0 0 1 0-1.74l1.5-.845'),
  ]);

  static const LucideIconData layers = LucideIconData([
    _SvgPath('M12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.91a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83z'),
    _SvgPath('M2 12a1 1 0 0 0 .58.91l8.6 3.91a2 2 0 0 0 1.65 0l8.58-3.9A1 1 0 0 0 22 12'),
    _SvgPath('M2 17a1 1 0 0 0 .58.91l8.6 3.91a2 2 0 0 0 1.65 0l8.58-3.9A1 1 0 0 0 22 17'),
  ]);

  static const LucideIconData layoutGrid = LucideIconData([
    _SvgRect(3, 3, 7, 7, 1, 0),
    _SvgRect(14, 3, 7, 7, 1, 0),
    _SvgRect(14, 14, 7, 7, 1, 0),
    _SvgRect(3, 14, 7, 7, 1, 0),
  ]);

  static const LucideIconData lightbulb = LucideIconData([
    _SvgPath('M15 14c.2-1 .7-1.7 1.5-2.5 1-.9 1.5-2.2 1.5-3.5A6 6 0 0 0 6 8c0 1 .2 2.2 1.5 3.5.7.7 1.3 1.5 1.5 2.5'),
    _SvgPath('M9 18h6'),
    _SvgPath('M10 22h4'),
  ]);

  static const LucideIconData link = LucideIconData([
    _SvgPath('M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71'),
    _SvgPath('M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71'),
  ]);

  static const LucideIconData loaderCircle = LucideIconData([
    _SvgPath('M21 12a9 9 0 1 1-6.219-8.56'),
  ]);

  static const LucideIconData lock = LucideIconData([
    _SvgRect(3, 11, 18, 11, 2, 2),
    _SvgPath('M7 11V7a5 5 0 0 1 10 0v4'),
  ]);

  static const LucideIconData logIn = LucideIconData([
    _SvgPath('m10 17 5-5-5-5'),
    _SvgPath('M15 12H3'),
    _SvgPath('M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4'),
  ]);

  static const LucideIconData logOut = LucideIconData([
    _SvgPath('m16 17 5-5-5-5'),
    _SvgPath('M21 12H9'),
    _SvgPath('M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4'),
  ]);

  static const LucideIconData menu = LucideIconData([
    _SvgPath('M4 5h16'),
    _SvgPath('M4 12h16'),
    _SvgPath('M4 19h16'),
  ]);

  static const LucideIconData messageCircle = LucideIconData([
    _SvgPath('M2.992 16.342a2 2 0 0 1 .094 1.167l-1.065 3.29a1 1 0 0 0 1.236 1.168l3.413-.998a2 2 0 0 1 1.099.092 10 10 0 1 0-4.777-4.719'),
  ]);

  static const LucideIconData microscope = LucideIconData([
    _SvgPath('M6 18h8'),
    _SvgPath('M3 22h18'),
    _SvgPath('M14 22a7 7 0 1 0 0-14h-1'),
    _SvgPath('M9 14h2'),
    _SvgPath('M9 12a2 2 0 0 1-2-2V6h6v4a2 2 0 0 1-2 2Z'),
    _SvgPath('M12 6V3a1 1 0 0 0-1-1H9a1 1 0 0 0-1 1v3'),
  ]);

  static const LucideIconData milestone = LucideIconData([
    _SvgPath('M12 13v8'),
    _SvgPath('M12 3v3'),
    _SvgPath('M18.172 6a2 2 0 0 1 1.414.586l2.06 2.06a1.207 1.207 0 0 1 0 1.708l-2.06 2.06a2 2 0 0 1-1.414.586H4a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1z'),
  ]);

  static const LucideIconData minus = LucideIconData([
    _SvgPath('M5 12h14'),
  ]);

  static const LucideIconData moon = LucideIconData([
    _SvgPath('M20.985 12.486a9 9 0 1 1-9.473-9.472c.405-.022.617.46.402.803a6 6 0 0 0 8.268 8.268c.344-.215.825-.004.803.401'),
  ]);

  static const LucideIconData network = LucideIconData([
    _SvgRect(16, 16, 6, 6, 1, 0),
    _SvgRect(2, 16, 6, 6, 1, 0),
    _SvgRect(9, 2, 6, 6, 1, 0),
    _SvgPath('M5 16v-3a1 1 0 0 1 1-1h12a1 1 0 0 1 1 1v3'),
    _SvgPath('M12 12V8'),
  ]);

  static const LucideIconData notebookPen = LucideIconData([
    _SvgPath('M13.4 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-7.4'),
    _SvgPath('M2 6h4'),
    _SvgPath('M2 10h4'),
    _SvgPath('M2 14h4'),
    _SvgPath('M2 18h4'),
    _SvgPath('M21.378 5.626a1 1 0 1 0-3.004-3.004l-5.01 5.012a2 2 0 0 0-.506.854l-.837 2.87a.5.5 0 0 0 .62.62l2.87-.837a2 2 0 0 0 .854-.506z'),
  ]);

  static const LucideIconData notebook = LucideIconData([
    _SvgPath('M2 6h4'),
    _SvgPath('M2 10h4'),
    _SvgPath('M2 14h4'),
    _SvgPath('M2 18h4'),
    _SvgRect(4, 2, 16, 20, 2, 0),
    _SvgPath('M16 2v20'),
  ]);

  static const LucideIconData pencil = LucideIconData([
    _SvgPath('M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z'),
    _SvgPath('m15 5 4 4'),
  ]);

  static const LucideIconData phone = LucideIconData([
    _SvgPath('M13.832 16.568a1 1 0 0 0 1.213-.303l.355-.465A2 2 0 0 1 17 15h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2A18 18 0 0 1 2 4a2 2 0 0 1 2-2h3a2 2 0 0 1 2 2v3a2 2 0 0 1-.8 1.6l-.468.351a1 1 0 0 0-.292 1.233 14 14 0 0 0 6.392 6.384'),
  ]);

  static const LucideIconData pipette = LucideIconData([
    _SvgPath('m12 9-8.414 8.414A2 2 0 0 0 3 18.828v1.344a2 2 0 0 1-.586 1.414A2 2 0 0 1 3.828 21h1.344a2 2 0 0 0 1.414-.586L15 12'),
    _SvgPath('m18 9 .4.4a1 1 0 1 1-3 3l-3.8-3.8a1 1 0 1 1 3-3l.4.4 3.4-3.4a1 1 0 1 1 3 3z'),
    _SvgPath('m2 22 .414-.414'),
  ]);

  static const LucideIconData play = LucideIconData([
    _SvgPath('M5 5a2 2 0 0 1 3.008-1.728l11.997 6.998a2 2 0 0 1 .003 3.458l-12 7A2 2 0 0 1 5 19z'),
  ]);

  static const LucideIconData plus = LucideIconData([
    _SvgPath('M5 12h14'),
    _SvgPath('M12 5v14'),
  ]);

  static const LucideIconData puzzle = LucideIconData([
    _SvgPath('M15.39 4.39a1 1 0 0 0 1.68-.474 2.5 2.5 0 1 1 3.014 3.015 1 1 0 0 0-.474 1.68l1.683 1.682a2.414 2.414 0 0 1 0 3.414L19.61 15.39a1 1 0 0 1-1.68-.474 2.5 2.5 0 1 0-3.014 3.015 1 1 0 0 1 .474 1.68l-1.683 1.682a2.414 2.414 0 0 1-3.414 0L8.61 19.61a1 1 0 0 0-1.68.474 2.5 2.5 0 1 1-3.014-3.015 1 1 0 0 0 .474-1.68l-1.683-1.682a2.414 2.414 0 0 1 0-3.414L4.39 8.61a1 1 0 0 1 1.68.474 2.5 2.5 0 1 0 3.014-3.015 1 1 0 0 1-.474-1.68l1.683-1.682a2.414 2.414 0 0 1 3.414 0z'),
  ]);

  static const LucideIconData refreshCw = LucideIconData([
    _SvgPath('M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8'),
    _SvgPath('M21 3v5h-5'),
    _SvgPath('M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16'),
    _SvgPath('M8 16H3v5'),
  ]);

  static const LucideIconData rocket = LucideIconData([
    _SvgPath('M12 15v5s3.03-.55 4-2c1.08-1.62 0-5 0-5'),
    _SvgPath('M4.5 16.5c-1.5 1.26-2 5-2 5s3.74-.5 5-2c.71-.84.7-2.13-.09-2.91a2.18 2.18 0 0 0-2.91-.09'),
    _SvgPath('M9 12a22 22 0 0 1 2-3.95A12.88 12.88 0 0 1 22 2c0 2.72-.78 7.5-6 11a22.4 22.4 0 0 1-4 2z'),
    _SvgPath('M9 12H4s.55-3.03 2-4c1.62-1.08 5 .05 5 .05'),
  ]);

  static const LucideIconData rotateCcw = LucideIconData([
    _SvgPath('M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8'),
    _SvgPath('M3 3v5h5'),
  ]);

  static const LucideIconData route = LucideIconData([
    _SvgCircle(6, 19, 3),
    _SvgPath('M9 19h8.5a3.5 3.5 0 0 0 0-7h-11a3.5 3.5 0 0 1 0-7H15'),
    _SvgCircle(18, 5, 3),
  ]);

  static const LucideIconData save = LucideIconData([
    _SvgPath('M15.2 3a2 2 0 0 1 1.4.6l3.8 3.8a2 2 0 0 1 .6 1.4V19a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z'),
    _SvgPath('M17 21v-7a1 1 0 0 0-1-1H8a1 1 0 0 0-1 1v7'),
    _SvgPath('M7 3v4a1 1 0 0 0 1 1h7'),
  ]);

  static const LucideIconData scale = LucideIconData([
    _SvgPath('M12 3v18'),
    _SvgPath('m19 8 3 8a5 5 0 0 1-6 0zV7'),
    _SvgPath('M3 7h1a17 17 0 0 0 8-2 17 17 0 0 0 8 2h1'),
    _SvgPath('m5 8 3 8a5 5 0 0 1-6 0zV7'),
    _SvgPath('M7 21h10'),
  ]);

  static const LucideIconData search = LucideIconData([
    _SvgPath('m21 21-4.34-4.34'),
    _SvgCircle(11, 11, 8),
  ]);

  static const LucideIconData settings = LucideIconData([
    _SvgPath('M9.671 4.136a2.34 2.34 0 0 1 4.659 0 2.34 2.34 0 0 0 3.319 1.915 2.34 2.34 0 0 1 2.33 4.033 2.34 2.34 0 0 0 0 3.831 2.34 2.34 0 0 1-2.33 4.033 2.34 2.34 0 0 0-3.319 1.915 2.34 2.34 0 0 1-4.659 0 2.34 2.34 0 0 0-3.32-1.915 2.34 2.34 0 0 1-2.33-4.033 2.34 2.34 0 0 0 0-3.831A2.34 2.34 0 0 1 6.35 6.051a2.34 2.34 0 0 0 3.319-1.915'),
    _SvgCircle(12, 12, 3),
  ]);

  static const LucideIconData share2 = LucideIconData([
    _SvgCircle(18, 5, 3),
    _SvgCircle(6, 12, 3),
    _SvgCircle(18, 19, 3),
    _SvgLine(8.59, 13.51, 15.42, 17.49),
    _SvgLine(15.41, 6.51, 8.59, 10.49),
  ]);

  static const LucideIconData shuffle = LucideIconData([
    _SvgPath('m18 14 4 4-4 4'),
    _SvgPath('m18 2 4 4-4 4'),
    _SvgPath('M2 18h1.973a4 4 0 0 0 3.3-1.7l5.454-8.6a4 4 0 0 1 3.3-1.7H22'),
    _SvgPath('M2 6h1.972a4 4 0 0 1 3.6 2.2'),
    _SvgPath('M22 18h-6.041a4 4 0 0 1-3.3-1.8l-.359-.45'),
  ]);

  static const LucideIconData sigma = LucideIconData([
    _SvgPath('M18 7V5a1 1 0 0 0-1-1H6.5a.5.5 0 0 0-.4.8l4.5 6a2 2 0 0 1 0 2.4l-4.5 6a.5.5 0 0 0 .4.8H17a1 1 0 0 0 1-1v-2'),
  ]);

  static const LucideIconData smile = LucideIconData([
    _SvgPath('M15 10V9'),
    _SvgPath('M16.472 15a6 6 0 01-8.943 0'),
    _SvgPath('M9 10V9'),
    _SvgCircle(12, 12, 10),
  ]);

  static const LucideIconData sparkle = LucideIconData([
    _SvgPath('M11.017 2.814a1 1 0 0 1 1.966 0l1.051 5.558a2 2 0 0 0 1.594 1.594l5.558 1.051a1 1 0 0 1 0 1.966l-5.558 1.051a2 2 0 0 0-1.594 1.594l-1.051 5.558a1 1 0 0 1-1.966 0l-1.051-5.558a2 2 0 0 0-1.594-1.594l-5.558-1.051a1 1 0 0 1 0-1.966l5.558-1.051a2 2 0 0 0 1.594-1.594z'),
  ]);

  static const LucideIconData sparkles = LucideIconData([
    _SvgPath('M11.017 2.814a1 1 0 0 1 1.966 0l1.051 5.558a2 2 0 0 0 1.594 1.594l5.558 1.051a1 1 0 0 1 0 1.966l-5.558 1.051a2 2 0 0 0-1.594 1.594l-1.051 5.558a1 1 0 0 1-1.966 0l-1.051-5.558a2 2 0 0 0-1.594-1.594l-5.558-1.051a1 1 0 0 1 0-1.966l5.558-1.051a2 2 0 0 0 1.594-1.594z'),
    _SvgPath('M20 2v4'),
    _SvgPath('M22 4h-4'),
    _SvgCircle(4, 20, 2),
  ]);

  static const LucideIconData star = LucideIconData([
    _SvgPath('M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z'),
  ]);

  static const LucideIconData sun = LucideIconData([
    _SvgCircle(12, 12, 4),
    _SvgPath('M12 2v2'),
    _SvgPath('M12 20v2'),
    _SvgPath('m4.93 4.93 1.41 1.41'),
    _SvgPath('m17.66 17.66 1.41 1.41'),
    _SvgPath('M2 12h2'),
    _SvgPath('M20 12h2'),
    _SvgPath('m6.34 17.66-1.41 1.41'),
    _SvgPath('m19.07 4.93-1.41 1.41'),
  ]);

  static const LucideIconData table = LucideIconData([
    _SvgPath('M12 3v18'),
    _SvgRect(3, 3, 18, 18, 2, 0),
    _SvgPath('M3 9h18'),
    _SvgPath('M3 15h18'),
  ]);

  static const LucideIconData target = LucideIconData([
    _SvgCircle(12, 12, 10),
    _SvgCircle(12, 12, 6),
    _SvgCircle(12, 12, 2),
  ]);

  static const LucideIconData thermometer = LucideIconData([
    _SvgPath('M14 4v10.54a4 4 0 1 1-4 0V4a2 2 0 0 1 4 0Z'),
  ]);

  static const LucideIconData timer = LucideIconData([
    _SvgLine(10, 2, 14, 2),
    _SvgLine(12, 14, 15, 11),
    _SvgCircle(12, 14, 8),
  ]);

  static const LucideIconData trash2 = LucideIconData([
    _SvgPath('M10 11v6'),
    _SvgPath('M14 11v6'),
    _SvgPath('M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6'),
    _SvgPath('M3 6h18'),
    _SvgPath('M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2'),
  ]);

  static const LucideIconData trendingUp = LucideIconData([
    _SvgPath('M16 7h6v6'),
    _SvgPath('m22 7-8.5 8.5-5-5L2 17'),
  ]);

  static const LucideIconData triangleAlert = LucideIconData([
    _SvgPath('m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3'),
    _SvgPath('M12 9v4'),
    _SvgPath('M12 17h.01'),
  ]);

  static const LucideIconData trophy = LucideIconData([
    _SvgPath('M10 14.66V17a1 1 0 0 1-1 1 2 2 0 0 0-2 2v2'),
    _SvgPath('M14 14.66V17a1 1 0 0 0 1 1 2 2 0 0 1 2 2v2'),
    _SvgPath('M17.916 10H19.5A2.5 2.5 0 0 0 22 7.5V5a1 1 0 0 0-1-1h-3'),
    _SvgPath('M4 22h16'),
    _SvgPath('M6 9a6 6 0 0 0 12 0V3a1 1 0 0 0-1-1H7a1 1 0 0 0-1 1z'),
    _SvgPath('M6.084 10H4.5A2.5 2.5 0 0 1 2 7.5V5a1 1 0 0 1 1-1h3'),
  ]);

  static const LucideIconData userRound = LucideIconData([
    _SvgCircle(12, 8, 5),
    _SvgPath('M20 21a8 8 0 0 0-16 0'),
  ]);

  static const LucideIconData volume2 = LucideIconData([
    _SvgPath('M11 4.702a.705.705 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.705.705 0 0 0 11 19.298z'),
    _SvgPath('M16 9a5 5 0 0 1 0 6'),
    _SvgPath('M19.364 18.364a9 9 0 0 0 0-12.728'),
  ]);

  static const LucideIconData wandSparkles = LucideIconData([
    _SvgPath('m21.64 3.64-1.28-1.28a1.21 1.21 0 0 0-1.72 0L2.36 18.64a1.21 1.21 0 0 0 0 1.72l1.28 1.28a1.2 1.2 0 0 0 1.72 0L21.64 5.36a1.2 1.2 0 0 0 0-1.72'),
    _SvgPath('m14 7 3 3'),
    _SvgPath('M5 6v4'),
    _SvgPath('M19 14v4'),
    _SvgPath('M10 2v2'),
    _SvgPath('M7 8H3'),
    _SvgPath('M21 16h-4'),
    _SvgPath('M11 3H9'),
  ]);

  static const LucideIconData wind = LucideIconData([
    _SvgPath('M12.8 19.6A2 2 0 1 0 14 16H2'),
    _SvgPath('M17.5 8a2.5 2.5 0 1 1 2 4H2'),
    _SvgPath('M9.8 4.4A2 2 0 1 1 11 8H2'),
  ]);

  static const LucideIconData x = LucideIconData([
    _SvgPath('M18 6 6 18'),
    _SvgPath('m6 6 12 12'),
  ]);

  static const LucideIconData zap = LucideIconData([
    _SvgPath('M15.914 4a1.5 1.5 0 00-2.474-1.561l-9 9A1.5 1.5 0 005.5 14h4.002a.5.5 0 01.471.666L8.086 20a1.5 1.5 0 002.475 1.56l9-9A1.5 1.5 0 0018.5 10h-3.997a.5.5 0 01-.472-.667z'),
  ]);

}

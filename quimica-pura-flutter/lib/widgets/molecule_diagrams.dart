// Diagramas de moléculas como modelos de bolas y varillas con aspecto 3D:
// esferas sombreadas con degradado radial (la luz viene de arriba a la
// izquierda) y varillas como enlaces. Todo dibujado con CustomPaint,
// sin imágenes externas ni emojis.
//
// Colores CPK habituales: C gris oscuro, H gris claro, O rojo, N azul.

import 'dart:math' as math;

import 'package:flutter/material.dart';

class _Atom {
  const _Atom(this.x, this.y, this.r, this.base, this.label);
  final double x; // 0..100
  final double y; // 0..100
  final double r; // radio en unidades del espacio 0..100
  final Color base;
  final String label;
}

class _Bond {
  const _Bond(this.a, this.b, [this.order = 1]);
  final int a;
  final int b;
  final int order; // 1 simple, 2 doble
}

class _Molecule {
  const _Molecule(this.atoms, this.bonds);
  final List<_Atom> atoms;
  final List<_Bond> bonds;
}

const Color _cCarbon = Color(0xFF455A64);
const Color _cHydrogen = Color(0xFFECEFF1);
const Color _cOxygen = Color(0xFFE53935);

/// Moléculas disponibles, por clave (la misma que usa StudyTopic.molecules).
const Map<String, ({String name, String formula})> moleculeInfo = {
  'metano': (name: 'Metano', formula: 'CH₄'),
  'etano': (name: 'Etano', formula: 'C₂H₆'),
  'eteno': (name: 'Eteno', formula: 'C₂H₄'),
  'etanol': (name: 'Etanol', formula: 'C₂H₅OH'),
  'acido-acetico': (name: 'Ácido acético', formula: 'CH₃COOH'),
  'benceno': (name: 'Benceno', formula: 'C₆H₆'),
};

Map<String, _Molecule> _molecules() {
  const h = _cHydrogen;
  const c = _cCarbon;
  const o = _cOxygen;
  return {
    'metano': const _Molecule(
      [
        _Atom(50, 50, 15, c, 'C'),
        _Atom(50, 14, 9, h, 'H'),
        _Atom(16, 66, 9, h, 'H'),
        _Atom(84, 66, 9, h, 'H'),
        _Atom(62, 84, 9, h, 'H'),
      ],
      [_Bond(0, 1), _Bond(0, 2), _Bond(0, 3), _Bond(0, 4)],
    ),
    'etano': const _Molecule(
      [
        _Atom(38, 50, 14, c, 'C'),
        _Atom(62, 50, 14, c, 'C'),
        _Atom(38, 16, 9, h, 'H'),
        _Atom(12, 64, 9, h, 'H'),
        _Atom(30, 82, 9, h, 'H'),
        _Atom(62, 16, 9, h, 'H'),
        _Atom(88, 64, 9, h, 'H'),
        _Atom(70, 82, 9, h, 'H'),
      ],
      [
        _Bond(0, 1),
        _Bond(0, 2),
        _Bond(0, 3),
        _Bond(0, 4),
        _Bond(1, 5),
        _Bond(1, 6),
        _Bond(1, 7),
      ],
    ),
    'eteno': const _Molecule(
      [
        _Atom(38, 50, 14, c, 'C'),
        _Atom(62, 50, 14, c, 'C'),
        _Atom(14, 28, 9, h, 'H'),
        _Atom(14, 72, 9, h, 'H'),
        _Atom(86, 28, 9, h, 'H'),
        _Atom(86, 72, 9, h, 'H'),
      ],
      [
        _Bond(0, 1, 2),
        _Bond(0, 2),
        _Bond(0, 3),
        _Bond(1, 4),
        _Bond(1, 5),
      ],
    ),
    'etanol': const _Molecule(
      [
        _Atom(26, 58, 14, c, 'C'),
        _Atom(52, 58, 14, c, 'C'),
        _Atom(78, 40, 13, o, 'O'),
        _Atom(26, 24, 9, h, 'H'),
        _Atom(6, 74, 9, h, 'H'),
        _Atom(26, 88, 9, h, 'H'),
        _Atom(48, 26, 9, h, 'H'),
        _Atom(56, 88, 9, h, 'H'),
        _Atom(94, 22, 9, h, 'H'),
      ],
      [
        _Bond(0, 1),
        _Bond(1, 2),
        _Bond(2, 8),
        _Bond(0, 3),
        _Bond(0, 4),
        _Bond(0, 5),
        _Bond(1, 6),
        _Bond(1, 7),
      ],
    ),
    'acido-acetico': const _Molecule(
      [
        _Atom(24, 58, 14, c, 'C'),
        _Atom(50, 58, 14, c, 'C'),
        _Atom(72, 34, 13, o, 'O'),
        _Atom(72, 82, 13, o, 'O'),
        _Atom(24, 24, 9, h, 'H'),
        _Atom(4, 70, 9, h, 'H'),
        _Atom(28, 88, 9, h, 'H'),
        _Atom(90, 92, 9, h, 'H'),
      ],
      [
        _Bond(0, 1),
        _Bond(1, 2, 2),
        _Bond(1, 3),
        _Bond(3, 7),
        _Bond(0, 4),
        _Bond(0, 5),
        _Bond(0, 6),
      ],
    ),
    'benceno': _benzene(),
  };
}

_Molecule _benzene() {
  // Anillo de 6 carbonos en hexágono, con 3 dobles enlaces alternos.
  final atoms = <_Atom>[];
  const cx = 50.0;
  const cy = 52.0;
  const rc = 26.0;
  const rh = 44.0;
  for (var i = 0; i < 6; i++) {
    final a = -math.pi / 2 + i * math.pi / 3;
    atoms.add(_Atom(
      cx + rc * math.cos(a),
      cy + rc * math.sin(a),
      12,
      _cCarbon,
      'C',
    ));
  }
  for (var i = 0; i < 6; i++) {
    final a = -math.pi / 2 + i * math.pi / 3;
    atoms.add(_Atom(
      cx + rh * math.cos(a),
      cy + rh * math.sin(a),
      8,
      _cHydrogen,
      'H',
    ));
  }
  final bonds = <_Bond>[];
  for (var i = 0; i < 6; i++) {
    final j = (i + 1) % 6;
    bonds.add(_Bond(i, j, i.isEven ? 2 : 1));
    bonds.add(_Bond(i, 6 + i));
  }
  return _Molecule(atoms, bonds);
}

class _MoleculePainter extends CustomPainter {
  _MoleculePainter(this.molecule);
  final _Molecule molecule;

  Offset _p(_Atom a, Size size) =>
      Offset(a.x / 100 * size.width, a.y / 100 * size.height);

  double _r(_Atom a, Size size) => a.r / 100 * size.width;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Enlaces (debajo de las esferas).
    final bondPaint = Paint()
      ..color = const Color(0xFF9E9E9E)
      ..strokeWidth = math.max(3, size.width * 0.02)
      ..strokeCap = StrokeCap.round;
    for (final bond in molecule.bonds) {
      final p1 = _p(molecule.atoms[bond.a], size);
      final p2 = _p(molecule.atoms[bond.b], size);
      if (bond.order == 1) {
        canvas.drawLine(p1, p2, bondPaint);
      } else {
        // Doble enlace: dos líneas paralelas.
        final dir = p2 - p1;
        final len = dir.distance;
        if (len == 0) continue;
        final perp = Offset(-dir.dy / len, dir.dx / len) *
            math.max(2.5, size.width * 0.014);
        canvas.drawLine(p1 + perp, p2 + perp, bondPaint);
        canvas.drawLine(p1 - perp, p2 - perp, bondPaint);
      }
    }
    // 2. Esferas con degradado radial (luz desde arriba a la izquierda).
    for (final atom in molecule.atoms) {
      final center = _p(atom, size);
      final r = _r(atom, size);
      final light = Color.lerp(Colors.white, atom.base, 0.25)!;
      final dark = Color.lerp(Colors.black, atom.base, 0.55)!;
      final paint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.45, -0.45),
          radius: 0.95,
          colors: [light, atom.base, dark],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawCircle(center, r, paint);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = dark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      // Etiqueta del elemento.
      final tp = TextPainter(
        text: TextSpan(
          text: atom.label,
          style: TextStyle(
            color: atom.base == _cHydrogen ? Colors.black87 : Colors.white,
            fontSize: r * 0.85,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        center - Offset(tp.width / 2, tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MoleculePainter oldDelegate) => false;
}

/// Tarjeta con el diagrama 3D de una molécula y su nombre.
class MoleculeCard extends StatelessWidget {
  const MoleculeCard({super.key, required this.moleculeKey});
  final String moleculeKey;

  @override
  Widget build(BuildContext context) {
    final info = moleculeInfo[moleculeKey];
    final molecule = _molecules()[moleculeKey];
    if (info == null || molecule == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SizedBox(
              height: 150,
              width: double.infinity,
              child: CustomPaint(
                painter: _MoleculePainter(molecule),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${info.name} — ${info.formula}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

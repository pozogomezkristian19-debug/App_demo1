// Iconos 3D de la barra inferior (Kristian 2026-11-17): cada
// pestaña con SU objeto y SU color, al estilo Duolingo — formas
// planas y gruesas, cara sólida + labio más oscuro (el mismo
// lenguaje 3D del círculo de Niveles), SIN emojis, SIN degradados
// ni brillo. Aprender = libro marrón (varios colores: tapa
// marrón, páginas crema, marcador rojo); Resolver = calculadora
// naranja; Tabla = rejilla de 3x3 con los colores de los
// elementos; Online = mundito azul con un continente verde y
// meridiano blanco. Niveles NO se toca (su círculo verde queda
// como está). De inactiva, la pestaña se dibuja con SU color
// propio pero clarito (pastel en claro, apagado en oscuro) —
// NUNCA gris, y nunca el color fuerte, para que la seleccionada
// se note. Cada icono mide 26 dp de cara + 3 dp de labio que
// asoma abajo.
import 'package:flutter/material.dart';

import '../services/accent.dart';

/// Las 4 pestañas de fuera (Niveles, el centro, no lleva icono
/// de estos: su círculo queda como está).
enum NavTabIconKind { learn, solver, table, online }

/// Paleta de un icono: cara, labio, claro y detalle, en claro y
/// en oscuro (en oscuro, versiones más claras para que se lean
/// sobre la tarjeta oscura).
class _NavPalette {
  const _NavPalette({
    required this.main,
    required this.dark,
    required this.light,
    required this.accent,
    required this.squares,
    required this.land,
  });

  final Color main;
  final Color dark;
  final Color light;
  final Color accent;

  /// Colores de las 9 casillas de la rejilla de Tabla (se ciclan).
  final List<Color> squares;

  /// Color de los continentes del mundito.
  final Color land;
}

_NavPalette _palette(NavTabIconKind kind, bool selected, bool isDark) {
  final full = _fullPalette(kind, isDark);
  if (selected) return full;
  // Sin seleccionar: su color propio pero clarito — nunca gris
  // (Kristian 2026-11-17). Se mezcla cada color hacia el fondo
  // de la barra (blanco en claro, tarjeta oscura en oscuro).
  final bg = isDark ? AppAccent.darkCard : Colors.white;
  final t = isDark ? 0.5 : 0.55;
  return _NavPalette(
    main: Color.lerp(full.main, bg, t)!,
    dark: Color.lerp(full.dark, bg, t)!,
    light: Color.lerp(full.light, bg, t)!,
    accent: Color.lerp(full.accent, bg, t)!,
    squares: [for (final c in full.squares) Color.lerp(c, bg, t)!],
    land: Color.lerp(full.land, bg, t)!,
  );
}

_NavPalette _fullPalette(NavTabIconKind kind, bool isDark) {
  switch (kind) {
    case NavTabIconKind.learn:
      return isDark
          ? const _NavPalette(
              main: Color(0xFFC08A5E),
              dark: Color(0xFF9C6644),
              light: Color(0xFFFFF6DB),
              accent: Color(0xFFF0715C),
              squares: [],
              land: Color(0xFF66BB6A),
            )
          : const _NavPalette(
              main: Color(0xFF9C6644),
              dark: Color(0xFF7A4A2B),
              light: Color(0xFFFFF6DB),
              accent: Color(0xFFE05D44),
              squares: [],
              land: Color(0xFF43A047),
            );
    case NavTabIconKind.solver:
      return isDark
          ? const _NavPalette(
              main: Color(0xFFFB923C),
              dark: Color(0xFFEA7C28),
              light: Color(0xFFFFF3D6),
              accent: Color(0xFFFFFFFF),
              squares: [],
              land: Color(0xFF66BB6A),
            )
          : const _NavPalette(
              main: Color(0xFFF97316),
              dark: Color(0xFFC2570B),
              light: Color(0xFFFFF3D6),
              accent: Color(0xFFFFFFFF),
              squares: [],
              land: Color(0xFF43A047),
            );
    case NavTabIconKind.table:
      return isDark
          ? const _NavPalette(
              main: Color(0xFFA78BFA),
              dark: Color(0xFF8B5CF6),
              light: Color(0xFFFFF6DB),
              accent: Color(0xFFFFFFFF),
              squares: [
                Color(0xFFA78BFA),
                Color(0xFF60A5FA),
                Color(0xFFFBBF24),
                Color(0xFF2DD4BF),
                Color(0xFFF472B6),
                Color(0xFFFB923C),
                Color(0xFF60A5FA),
                Color(0xFFA78BFA),
                Color(0xFFFBBF24),
              ],
              land: Color(0xFF66BB6A),
            )
          : const _NavPalette(
              main: Color(0xFF8B5CF6),
              dark: Color(0xFF6D28D9),
              light: Color(0xFFFFF6DB),
              accent: Color(0xFFFFFFFF),
              squares: [
                Color(0xFF8B5CF6),
                Color(0xFF3B82F6),
                Color(0xFFF59E0B),
                Color(0xFF14B8A6),
                Color(0xFFEC4899),
                Color(0xFFF97316),
                Color(0xFF3B82F6),
                Color(0xFF8B5CF6),
                Color(0xFFF59E0B),
              ],
              land: Color(0xFF43A047),
            );
    case NavTabIconKind.online:
      return isDark
          ? const _NavPalette(
              main: Color(0xFF60A5FA),
              dark: Color(0xFF3B82F6),
              light: Color(0xFFFFF6DB),
              accent: Color(0xFFFFFFFF),
              squares: [],
              land: Color(0xFF66BB6A),
            )
          : const _NavPalette(
              main: Color(0xFF3B82F6),
              dark: Color(0xFF1D4ED8),
              light: Color(0xFFFFF6DB),
              accent: Color(0xFFFFFFFF),
              squares: [],
              land: Color(0xFF43A047),
            );
  }
}

/// Color de la etiqueta de una pestaña: seleccionada, el tono
/// oscuro de su color en claro (se lee mejor sobre blanco) y el
/// tono claro en oscuro; sin seleccionar, su color propio pero
/// clarito, igual que el icono (nunca gris). La de Niveles no
/// pasa por aquí (sigue el acento, como su círculo).
Color navTabLabelColor(NavTabIconKind kind, bool selected, bool isDark) {
  final p = _palette(kind, selected, isDark);
  if (!selected) return p.main;
  return isDark ? p.main : p.dark;
}

/// Un icono 3D de la barra inferior: cara de 26 dp + labio de
/// 3 dp que asoma abajo (el labio es la misma forma, del color
/// oscuro, 3 dp más abajo).
class NavTabIcon extends StatelessWidget {
  const NavTabIcon({
    super.key,
    required this.kind,
    required this.selected,
    required this.isDark,
    this.size = 26,
  });

  final NavTabIconKind kind;
  final bool selected;
  final bool isDark;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = _palette(kind, selected, isDark);
    final s = size;
    return SizedBox(
      width: s,
      height: s + 3,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Labio: la misma forma, color oscuro, 3 dp más abajo.
          Positioned(top: 3, left: 0, child: _lip(p, s)),
          // Cara.
          Positioned(top: 0, left: 0, child: _face(p, s)),
        ],
      ),
    );
  }

  Widget _lip(_NavPalette p, double s) {
    switch (kind) {
      case NavTabIconKind.online:
        return Container(
          width: s,
          height: s,
          decoration: BoxDecoration(shape: BoxShape.circle, color: p.dark),
        );
      default:
        return Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            color: p.dark,
            borderRadius: BorderRadius.circular(5),
          ),
        );
    }
  }

  Widget _face(_NavPalette p, double s) {
    switch (kind) {
      case NavTabIconKind.learn:
        return _book(p, s);
      case NavTabIconKind.solver:
        return _calculator(p, s);
      case NavTabIconKind.table:
        return _grid(p, s);
      case NavTabIconKind.online:
        return _globe(p, s);
    }
  }

  /// Libro: tapa marrón, lomo oscuro a la izquierda, páginas
  /// crema en el borde derecho y marcador rojo colgando de arriba.
  Widget _book(_NavPalette p, double s) {
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: p.main,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          // Páginas: bloque crema en el borde derecho.
          Positioned(
            right: 0,
            top: 2,
            bottom: 2,
            width: 5,
            child: Container(
              decoration: BoxDecoration(
                color: p.light,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
            ),
          ),
          // Lomo: franja oscura a la izquierda.
          Positioned(
            left: 2.5,
            top: 3,
            bottom: 3,
            width: 3.5,
            child: Container(
              decoration: BoxDecoration(
                color: p.dark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Marcador rojo colgando de arriba.
          Positioned(
            left: s * 0.58,
            top: 0,
            width: 4.5,
            height: 9,
            child: Container(color: p.accent),
          ),
        ],
      ),
    );
  }

  /// Calculadora: cuerpo naranja, pantalla clara arriba y 6
  /// botones blancos (3 columnas x 2 filas).
  Widget _calculator(_NavPalette p, double s) {
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: p.main,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(3, 3, 3, 3),
              child: Column(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: p.light,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 2.5),
                  for (var row = 0; row < 2; row++) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (var col = 0; col < 3; col++)
                          Container(
                            width: 4.5,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: p.accent,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                      ],
                    ),
                    if (row == 0) const SizedBox(height: 2),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tabla periódica: rejilla de 3x3 con los colores de los
  /// elementos.
  Widget _grid(_NavPalette p, double s) {
    const gap = 1.5;
    final cell = (s - gap * 2) / 3;
    return SizedBox(
      width: s,
      height: s,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var row = 0; row < 3; row++)
            Padding(
              padding: EdgeInsets.only(top: row == 0 ? 0 : gap),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var col = 0; col < 3; col++)
                    Padding(
                      padding: EdgeInsets.only(left: col == 0 ? 0 : gap),
                      child: Container(
                        width: cell,
                        height: cell,
                        decoration: BoxDecoration(
                          color: p.squares[row * 3 + col],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Mundito: esfera azul con UN continente verde (una sola masa
  /// en diagonal, no manchas sueltas — las tres bolitas se veían
  /// raras) y un meridiano blanco fino. El meridiano es una
  /// elipse con borde, recortada por la esfera.
  Widget _globe(_NavPalette p, double s) {
    return SizedBox(
      width: s,
      height: s,
      child: ClipOval(
        child: Container(
          color: p.main,
          child: Stack(
            children: [
              // Continente: dos círculos solapados en diagonal
              // forman una sola masa verde.
              Positioned(
                left: s * 0.06,
                top: s * 0.10,
                width: s * 0.44,
                height: s * 0.36,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.land,
                  ),
                ),
              ),
              Positioned(
                left: s * 0.34,
                top: s * 0.34,
                width: s * 0.40,
                height: s * 0.32,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.land,
                  ),
                ),
              ),
              // Meridiano blanco: elipse vertical fina.
              Positioned(
                left: s * 0.30,
                top: -s * 0.12,
                width: s * 0.40,
                height: s * 1.24,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

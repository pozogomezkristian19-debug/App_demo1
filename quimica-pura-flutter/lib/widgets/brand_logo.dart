// Logo oficial de Melli-Qui (v6, decisión FINAL de Kristian
// 2026-11-10): como el primer logo, pero SIN LETRAS y con UN SOLO
// FONDO. El archivo es assets/logo.png: las dos muñequitas en el
// estilo ilustrado del primer logo (piel morena clara, pelo castaño
// con coletas y lacitos, ojos grandes, colorete), sobre un fondo
// marrón sólido único, sin texto ni panel crema. El logo anterior
// queda reemplazado por este. Es también el icono lanzador: las
// densidades mipmap se generan desde este mismo archivo (48/72/96/
// 144/192). Las variantes dibujadas a mano (molécula, matraz,
// hexágono, ligadura MQ, muñecas planas F/G) quedan descartadas
// como candidatos de logo.
//
// Las mascotas Brenda (violeta) y Britany (azul) se dibujan con el
// estilo de este logo: ver widgets/twin_avatars.dart.

import 'package:flutter/material.dart';

/// Colores de la marca (rediseño Duolingo-claro, color propio):
/// teal de Melli-Qui + violeta de Brenda + azul de Britany.
/// Se usan también en el tema de main.dart (claro y oscuro).
/// NUNCA verde Duolingo: el color propio de Melli-Qui es el teal.
class BrandColors {
  BrandColors._();

  /// Teal propio de Melli-Qui: color principal de la app.
  static const Color teal = Color(0xFF00C2A8);

  /// Teal oscuro: borde inferior de los botones píldora (efecto 3D).
  static const Color tealDark = Color(0xFF00A18D);

  /// Tinta: texto principal sobre fondo blanco.
  static const Color ink = Color(0xFF3C3C3C);

  /// Gris claro de tarjetas sobre fondo blanco.
  static const Color cardGray = Color(0xFFF7F7F7);

  /// Ámbar: acento cálido para logros y estrellas.
  static const Color amber = Color(0xFFF59E0B);

  /// Violeta principal de la marca (y color de Brenda).
  static const Color violet = Color(0xFF8B5CF6);
  static const Color violetDeep = Color(0xFF6D28D9);
  static const Color violetLight = Color(0xFFA78BFA);

  /// Menta: acento de química y color secundario de la app.
  static const Color mint = Color(0xFF14B8A6);
  static const Color mintLight = Color(0xFF2DD4BF);

  /// Coral: acento cálido para avisos y logros.
  static const Color coral = Color(0xFFF97316);

  /// Azul de Britany (#3B82F6).
  static const Color blue = Color(0xFF3B82F6);
}

/// El logo de la app: la imagen assets/logo.png.
///
/// ENCUADRE (fix3, punto 6): la imagen es cuadrada (512x512) pero
/// las gemelas ocupan solo la banda central (x 15-458, y 164-318,
/// medido sobre el archivo: ~30% de la altura). Mostrarla entera
/// en un cuadrado deja un cuadrado marrón gigante con las muñequitas
/// diminutas en el centro: eso es lo que se veía "gigante, raro y
/// cutre" en el menú, el onboarding y la cabecera de Resolver.
/// Por eso el logo NO se muestra cuadrado: se recorta a la banda de
/// las gemelas, en formato panorámico.
///
/// [size] es el ANCHO del logo; la altura es `size * 0.40` (la
/// ventana visible cubre ~205 px de los 512 de la imagen, centrada
/// en las gemelas con `Alignment(0, -0.10)`, así las dos muñecas
/// entran enteras, sin estirar ni aplastar: BoxFit.cover con
/// proporción fija, nunca un contenedor que imponga otra relación
/// de aspecto. El arte no cambia; solo el encuadre. El icono
/// lanzador sigue usando el archivo cuadrado tal cual.
///
/// [withBackground] y [color] se mantienen por compatibilidad con
/// las llamadas existentes: la imagen ya trae su fondo marrón
/// único, así que no cambian el dibujo.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 48,
    this.withBackground = true,
    this.color = BrandColors.violet,
  });

  final double size;
  final bool withBackground;
  final Color color;

  /// Relación alto/ancho del encuadre recortado a las gemelas.
  static const double aspectHeight = 0.40;

  @override
  Widget build(BuildContext context) {
    final height = size * aspectHeight;
    return SizedBox(
      width: size,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.10),
        child: Image.asset(
          'assets/logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          // Las gemelas están por encima del centro de la imagen
          // (centro de la banda y~241 de 512): se sube un poco el
          // encuadre para que queden centradas en el recorte.
          alignment: const Alignment(0, -0.10),
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

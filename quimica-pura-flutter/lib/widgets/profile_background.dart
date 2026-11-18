// Fondo animado del perfil — BORRADOR PARA FOTO (2026-11-17).
//
// Kristian quiere temas que le den VIDA a la app, no solo colores:
// cuando alguien entra al perfil de una persona que compró un
// tema, el fondo del perfil se mueve (animación Lottie, por
// ejemplo un dragón). Y el fondo viene del SERVIDOR: se puede
// actualizar sin actualizar la aplicación.
//
// Diseño real (a conectar cuando él elija el diseño): el tema
// equipado vive en Firestore (`shop_items`, kind 'theme' con
// `animationUrl`); la app lo descarga y lo guarda en caché en
// disco (como ShopImageCache con las fotos); sin internet o sin
// tema equipado, el perfil se ve plano, sin nada; al conectarse,
// el fondo aparece enseguida.
//
// Este borrador solo muestra CÓMO se ve: el fondo es un asset
// local de ejemplo (`lottieAsset`) que se pasa por parámetro, y
// `online` dice si hay internet. Sin asset o sin internet, el
// perfil queda como hoy (fondo plano). Ningún llamador actual
// pasa estos parámetros, así que nada cambia en la app hasta que
// se conecte el servidor.
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class ProfileBackground extends StatelessWidget {
  const ProfileBackground({
    super.key,
    required this.online,
    required this.lottieAsset,
    required this.child,
  });

  /// Hay internet (el fondo solo se ve con internet: sin
  /// conexión, el perfil se ve plano).
  final bool online;

  /// Ruta del asset Lottie del tema equipado (ejemplo en el
  /// borrador; en la versión real, la URL que manda el servidor).
  /// null = sin tema = fondo plano.
  final String? lottieAsset;

  /// El contenido del perfil (la cabecera con avatar y nombre).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!online || lottieAsset == null) return child;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Positioned.fill(
            child: Lottie.asset(
              lottieAsset!,
              fit: BoxFit.cover,
              repeat: true,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Fondo COMPLETO del perfil — BORRADOR PARA FOTO (2026-11-17).
///
/// Los fondos PREMIUM: la animación cubre TODA la pantalla, sobre
/// fondo NEGRO, y se ve atenuada y un poquito difuminada, para
/// que las letras se lean bien encima (Kristian 2026-11-17).
/// Ajuste 2026-11-17 19:0x: la primera versión (opacidad 0.35,
/// desenfoque 2.5) se veía tan poco que Kristian no distinguía
/// el fondo — ahora opacidad 0.6 y desenfoque 1.5, para que el
/// fondo SE VEA pero las letras sigan legibles. Igual que
/// [ProfileBackground]: sin internet o sin tema, el perfil queda
/// como hoy.
class ProfileFullBackground extends StatelessWidget {
  const ProfileFullBackground({
    super.key,
    required this.online,
    required this.lottieAsset,
    required this.child,
  });

  /// Hay internet (sin conexión, el perfil se ve plano).
  final bool online;

  /// Ruta del asset Lottie del fondo premium (ejemplo en el
  /// borrador; en la versión real, el vídeo que manda el
  /// servidor). null = sin fondo = perfil normal.
  final String? lottieAsset;

  /// El contenido del perfil.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!online || lottieAsset == null) return child;
    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0.6,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
              child: Lottie.asset(
                lottieAsset!,
                fit: BoxFit.cover,
                repeat: true,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

// Banderita de un idioma con la imagen REAL de la bandera
// (assets/flags/), no dibujada en código. Kristian 2026-11-13:
// imágenes reales, no creadas por mí. 'en' es EE. UU. (igual que
// en la instalación), no Reino Unido.
import 'package:flutter/material.dart';

import '../services/accent.dart';

/// Banderita de un idioma ('es', 'en', 'fr', 'it', 'pt', 'ru').
class FlagWidget extends StatelessWidget {
  const FlagWidget(
      {super.key, required this.code, this.width = 34, this.height = 24});
  final String code;
  final double width;
  final double height;

  static const _files = {
    'es': 'es',
    'en': 'us',
    'fr': 'fr',
    'it': 'it',
    'pt': 'pt',
    'ru': 'ru',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final file = _files[code] ?? 'es';
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        // Borde según el tema (auditoría 7.7): en oscuro el gris
        // claro se veía como un borde blanco feo.
        border: Border.all(
          color:
              isDark ? AppAccent.darkBorder : const Color(0xFFE8E8E8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Image.asset(
          'assets/flags/$file.png',
          width: width,
          height: height,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

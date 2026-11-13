// Botón "Continuar con Google" (diseño bonito, ronda de diseño 7.0):
// blanco, píldora, sombra suave, sin borde negro, y la G oficial
// de Google como imagen real (assets/google_g.png). Es el MISMO
// botón en el onboarding (perfil), en la puerta de Google de las
// pantallas online y en cualquier otro sitio que lo necesite: un
// solo widget, un solo aspecto.

import 'package:flutter/material.dart';

import '../services/localization.dart';
import 'shadows.dart';

/// La G oficial de Google, como imagen real (ronda 2): el logo de
/// marca, en sus cuatro colores, con fondo transparente. Antes se
/// dibujaba con CustomPaint y se veía fea.
class GoogleGIcon extends StatelessWidget {
  const GoogleGIcon({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/google_g.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
}

/// Botón de Google bonito de verdad: blanco, píldora, sombra suave
/// grisácea, sin borde negro, G en colores y texto oscuro. `busy`
/// muestra un spinner y lo deshabilita.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.busy = false,
  });

  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    // (foto72) La sombra difusa estándar ya no existe desde el
    // rediseño Duolingo 7.0: standardShadow es un no-op, así que el
    // botón blanco NO se veía sobre fondo blanco (solo se veían la
    // G y el texto, sin forma de botón). Borde fino gris claro en
    // claro — el color de línea fina del sistema (#E5E5E5) — y en
    // oscuro nada, porque la píldora blanca ya se ve sobre oscuro.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: isDark
            ? null
            : Border.all(color: const Color(0xFFE5E5E5), width: 2),
        boxShadow: [
          standardShadow(const Color(0xFF6B7280)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onPressed,
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else
                const GoogleGIcon(size: 24),
              const SizedBox(width: 12),
              // Flexible con puntos suspensivos: en un teléfono
              // estrecho (o con la fuente de tests, más ancha) el
              // texto no desborda el botón.
              Flexible(
                child: Text(
                  tr('googleContinue'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3C4043),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

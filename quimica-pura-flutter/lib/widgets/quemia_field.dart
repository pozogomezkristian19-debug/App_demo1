// Campo de texto de las pantallas de correo (antes privado en
// onboarding_screen.dart): el mismo estilo del campo de correo del
// registro — fondo blanco, radio 16, borde gris 2, foco teal claro —
// para que el correo, la contraseña y el nombre se vean iguales en
// claro y en oscuro. En modo oscuro la casilla es OSCURA como en
// Duolingo (Kristian 2026-11-13: en Duolingo no son blancas).
import 'package:flutter/material.dart';

import '../services/accent.dart';

class QuemiaField extends StatelessWidget {
  const QuemiaField({
    super.key,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    // En modo oscuro la casilla es OSCURA como en Duolingo
    // (Kristian 2026-11-13: en Duolingo no son blancas). Antes el
    // blanco estaba fijo y en oscuro se veía una caja blanca.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 56,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF4B4B4B),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.normal,
            color: isDark ? const Color(0xFFAFAFAF) : const Color(0xFF757575),
          ),
          suffixIcon: suffixIcon,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
          filled: true,
          fillColor: isDark ? AppAccent.darkCard : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            // Borde más marcado (Kristian 2026-11-13: las pantallas
            // de correo se veían "opacas", sin contraste): el gris
            // claro #E5E5E5 casi no se veía sobre blanco.
            borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : const Color(0xFFC7CBD1),
              width: 2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : const Color(0xFFC7CBD1),
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            // Enfocado: teal Quemia fuerte, no el menta pálido.
            borderSide: BorderSide(color: AppAccent.primary, width: 2),
          ),
        ),
      ),
    );
  }
}

// Lista de reglas de la contraseña segura + la comprobación
// (antes privados en onboarding_screen.dart): 8 caracteres como
// mínimo, una mayúscula, una minúscula, un número y un carácter
// especial. Se usan en el registro por correo y en Cuenta (ponerle
// contraseña a una cuenta de Google). La lista se enseña debajo
// del campo para que se vea qué falta sin adivinar.
import 'package:flutter/material.dart';

import '../services/accent.dart';
import '../services/localization.dart';

/// Contraseña segura (Kristian 2026-11-13: que no se pongan
/// contraseñas fáciles): 8 caracteres como mínimo, una mayúscula,
/// una minúscula, un número y un carácter especial. Solo se exige
/// al CREAR la contraseña (registro por correo y ponerle contraseña
/// a una cuenta de Google); al entrar con una cuenta vieja no se
/// pide nada (esa contraseña ya existe).
bool isStrongPassword(String password) {
  if (password.length < 8) return false;
  return password.contains(RegExp(r'[A-Z]')) &&
      password.contains(RegExp(r'[a-z]')) &&
      password.contains(RegExp(r'[0-9]')) &&
      password.contains(RegExp(r'[^A-Za-z0-9]'));
}

/// Lista de reglas de la contraseña segura: cada regla con su
/// check en teal cuando se cumple, gris cuando falta. Se enseña
/// debajo del campo de contraseña (registro y ponerle contraseña
/// a una cuenta de Google) para que se vea qué falta sin adivinar.
class PasswordRules extends StatelessWidget {
  const PasswordRules({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : const Color(0xFF4B4B4B);
    final sub =
        isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF757575);
    final rules = <(String, bool)>[
      (tr('obPasswordReqLength'), password.length >= 8),
      (tr('obPasswordReqUpper'), password.contains(RegExp(r'[A-Z]'))),
      (tr('obPasswordReqLower'), password.contains(RegExp(r'[a-z]'))),
      (tr('obPasswordReqNumber'), password.contains(RegExp(r'[0-9]'))),
      (tr('obPasswordReqSpecial'), password.contains(RegExp(r'[^A-Za-z0-9]'))),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, met) in rules) ...[
          Row(
            children: [
              Icon(
                met ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: met ? AppAccent.primary : sub,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: met ? FontWeight.w700 : FontWeight.normal,
                    color: met ? ink : sub,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

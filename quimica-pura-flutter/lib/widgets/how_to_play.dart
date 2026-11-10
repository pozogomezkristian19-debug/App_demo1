// Ventanita "¿Cómo se juega?" (v6, rediseño claro 2026-11-10): las
// reglas cortas del juego. Se muestra la primera vez que se entra a
// Niveles tras la v6 y se puede releer cuando se quiera desde la
// pantalla Cuenta.
import 'package:flutter/material.dart';

import '../services/localization.dart';

/// Tokens claros (paleta propia de Melli-Qui, sin verde Duolingo).
const _teal = Color(0xFF00C2A8);
const _ink = Color(0xFF3C3C3C);

Future<void> showHowToPlayDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        tr('howToPlayTitle'),
        style: const TextStyle(fontWeight: FontWeight.bold, color: _ink),
      ),
      content: SingleChildScrollView(
        child: Text(
          tr('howToPlayBody'),
          style: const TextStyle(color: _ink),
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            backgroundColor: _teal,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          ),
          child: Text(
            tr('closeWord'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

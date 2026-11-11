// Ventanita "¿Cómo se juega?" (v6, rediseño claro 2026-11-10; filas
// con icono en la ronda fix3, punto 1): antes era un solo Text con
// howToPlayBody, un muro de texto. Ahora cada regla es una fila
// corta con su icono — corazón (vidas), estrella (puntos), birrete
// (cómo se pasa) y flecha circular (repaso) — y cada regla tiene su
// propia clave i18n en los 6 idiomas (howToPlayLives, howToPlayPoints,
// howToPlayPass, howToPlayReview). El contenido de las reglas es el
// mismo, solo cambia la presentación.
//
// Los colores salen del tema (auditoría fix2): antes el fondo era
// blanco fijo y en modo oscuro la ventanita se quedaba blanca.

import 'package:flutter/material.dart';

import '../services/localization.dart';
import 'lives_chip.dart';
import 'lucide_icons.dart';

/// Teal propio de Melli-Qui, para el botón de cerrar.
const _teal = Color(0xFF00C2A8);

Future<void> showHowToPlayDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final scheme = Theme.of(context).colorScheme;
      // Estrella de los puntos: ámbar en claro, menta en oscuro
      // (como en la tarjeta de estadísticas, sin ámbar en oscuro).
      final starColor =
          isDark ? const Color(0xFF2DD4BF) : const Color(0xFFF59E0B);
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          tr('howToPlayTitle'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RuleRow(
                icon: const LivesHeart(size: 22),
                text: tr('howToPlayLives'),
              ),
              const SizedBox(height: 14),
              _RuleRow(
                icon: LucideIcon(
                  LucideIcons.star,
                  size: 22,
                  color: starColor,
                  filled: true,
                  threeD: true,
                ),
                text: tr('howToPlayPoints'),
              ),
              const SizedBox(height: 14),
              _RuleRow(
                icon: LucideIcon(
                  LucideIcons.graduationCap,
                  size: 22,
                  color: scheme.primary,
                  threeD: true,
                ),
                text: tr('howToPlayPass'),
              ),
              const SizedBox(height: 14),
              _RuleRow(
                icon: LucideIcon(
                  LucideIcons.refreshCw,
                  size: 22,
                  color: scheme.primary,
                  threeD: true,
                ),
                text: tr('howToPlayReview'),
              ),
            ],
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
      );
    },
  );
}

/// Una regla: icono en un círculo tintado + texto corto al lado.
class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.icon, required this.text});

  final Widget icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: icon,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(text),
          ),
        ),
      ],
    );
  }
}

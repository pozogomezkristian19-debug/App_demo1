// "¿Cómo se juega?" como PANTALLA COMPLETA (ronda fix5, punto 1,
// Quemia 6.2): antes era un diálogo deslizable (showHowToPlayDialog
// en widgets/how_to_play.dart). Ahora es una pantalla con TODO
// visible sin deslizar a 393x852: el título en la AppBar (como en
// las demás pantallas abiertas desde Cuenta, p. ej. ThemeScreen),
// las 5 reglas con su icono y un botón claro para cerrar/volver.
// Las 5 reglas usan las mismas claves i18n de siempre
// (howToPlayLives, howToPlayNoLives, howToPlayPoints, howToPlayPass,
// howToPlayReview: traducidas a los 6 idiomas) y los mismos iconos
// del diálogo: corazón (vidas), rayo (las vidas son solo de los
// niveles), estrella (puntos), birrete (cómo se pasa) y flecha
// circular (repaso). El auto-show de la primera entrada a Niveles
// ya NO existe: se entra aquí solo desde la fila de Cuenta.
import 'package:flutter/material.dart';

import '../services/localization.dart';
import '../widgets/duo_button.dart';
import '../widgets/lives_chip.dart';
import '../widgets/lucide_icons.dart';

/// Abre la pantalla "¿Cómo se juega?" (la usan el alias viejo de
/// widgets/how_to_play.dart y la fila de Cuenta vía
/// onOpenScreen('howToPlay') en main.dart).
Future<void> openHowToPlayScreen(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const HowToPlayScreen()),
  );
}

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    // Estrella de los puntos: ámbar en claro, el primario del tema
    // en oscuro (como la tarjeta de estadísticas, sin ámbar en
    // oscuro; Quemia 7.3 P12: antes menta fija en oscuro, verde con
    // el tema violeta).
    final starColor =
        isDark ? scheme.primary : const Color(0xFFF59E0B);
    return Scaffold(
      appBar: AppBar(title: Text(tr('howToPlayTitle'))),
      // SingleChildScrollView por seguridad (textos largos en otros
      // idiomas, fuente grande): a 393x852 el contenido cabe entero
      // y no hay nada que deslizar (ver test fix5_como_se_juega).
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RuleRow(
              icon: const LivesHeart(size: 22),
              text: tr('howToPlayLives'),
            ),
            const SizedBox(height: 14),
            _RuleRow(
              icon: LucideIcon(
                LucideIcons.zap,
                size: 22,
                color: scheme.primary,
                filled: true,
                threeD: true,
              ),
              text: tr('howToPlayNoLives'),
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
            const SizedBox(height: 28),
            // Botón 3D (ronda de diseño 7.0): antes era un
            // FilledButton plano con styleFrom teal liso.
            DuoButton.primary(
              label: tr('closeWord'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
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
        // Círculo del icono PLANO (reglas 1 y 3): tinte teal sólido
        // al 12 %, sin degradado y sin sombra borrosa. Antes era un
        // degradado suave con sombra tintada (ronda de diseño 7.0).
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
            child: Text(text, style: const TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}

// Aviso de la versión de prueba (SOLO WEB, Kristian 2026-11-15):
// "Versión de prueba · te quedan X días". Se enseña en Niveles
// (debajo del título) y en Cuenta (debajo de la cabecera) mientras
// la prueba de 3 días está activa; sin prueba, no ocupa nada.
// Estilo Duolingo: tarjeta plana con tinte del acento, sin
// degradados ni sombras borrosas.

import 'package:flutter/material.dart';

import '../services/accent.dart';
import '../services/localization.dart';
import '../services/trial.dart';
import 'lucide_icons.dart';

/// Banner de la prueba gratuita. Solo se pinta en web y con la
/// prueba activa; en móvil o sin prueba devuelve un hueco vacío.
class TrialBanner extends StatelessWidget {
  const TrialBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: TrialService.trialNotifier,
      builder: (context, active, _) {
        if (!active) return const SizedBox.shrink();
        return ValueListenableBuilder<int>(
          valueListenable: TrialService.trialDaysLeftNotifier,
          builder: (context, days, _) {
            final accent = AppAccent.primary;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              key: const ValueKey('trialBanner'),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: accent.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.14),
                    ),
                    alignment: Alignment.center,
                    child: LucideIcon(
                      LucideIcons.clock,
                      size: 20,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _trialText(days),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF4B4B4B),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// "Versión de prueba · te quedan X días" (singular con 1 día).
  static String _trialText(int days) {
    if (days <= 1) return tr('trialBannerDay');
    return tr('trialBannerDays').replaceFirst('%s', days.toString());
  }
}

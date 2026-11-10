// Tarjeta de estadísticas compartida (rediseño 2026-11-10, fix 3):
// Vidas, Puntos, Racha y Meta del día, con Logros opcional. Vive en
// Cuenta, debajo de la cabecera: ya NO está en Niveles, para que el
// camino de niveles suba y gane vista. Cada número aparece UNA sola
// vez: la cabecera de Cuenta ya no tiene su propia fila de
// estadísticas.
//
// Las vidas usan el chip de corazón + número (nunca la fila de 5
// corazones); la racha usa la llama de Lucide que parpadea; la meta
// del día es el objetivo moderno de Lucide (con palomita teal
// cuando está hecha), nunca la banderita con círculo rústica.

import 'package:flutter/material.dart';

import '../services/localization.dart';
import '../services/progress.dart';
import 'animated_number.dart';
import 'icon_animations.dart';
import 'lives_chip.dart';
import 'lucide_icons.dart';

/// Tarjeta de estadísticas: Vidas / Puntos / Racha / Meta del día,
/// y Logros si se pasa [achievementsLabel] (p. ej. "1/11").
class StatsCard extends StatelessWidget {
  const StatsCard({super.key, this.achievementsLabel});

  final String? achievementsLabel;

  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    final scheme = Theme.of(context).colorScheme;
    Widget cell(Widget icon, Widget value, String label) {
      return Expanded(
        child: Column(
          children: [
            icon,
            const SizedBox(height: 4),
            value,
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    const valueStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            cell(
              const LivesHeart(size: 22),
              AnimatedNumber(
                value: p.livesLeft,
                style: valueStyle,
              ),
              tr('livesTitle'),
            ),
            cell(
              const LucideIcon(
                LucideIcons.star,
                size: 22,
                color: Color(0xFFF59E0B),
                filled: true,
              ),
              AnimatedNumber(value: p.points, style: valueStyle),
              tr('pointsTitle'),
            ),
            cell(
              const FlickerWidget(
                child: LucideIcon(
                  LucideIcons.flame,
                  size: 22,
                  color: Colors.deepOrange,
                  filled: true,
                ),
              ),
              AnimatedNumber(value: p.streakNow, style: valueStyle),
              tr('streakWord'),
            ),
            cell(
              p.dailyGoalDone
                  ? const LucideIcon(
                      LucideIcons.circleCheck,
                      size: 22,
                      color: Color(0xFF00C2A8),
                    )
                  : const LucideIcon(
                      LucideIcons.target,
                      size: 22,
                      color: Color(0xFF9CA3AF),
                    ),
              // "Pendiente" es largo para una celda estrecha: se
              // encoge solo si hace falta, sin romper la fila.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  p.dailyGoalDone ? tr('doneWord') : tr('pendingWord'),
                  style: valueStyle,
                ),
              ),
              tr('dailyGoalTitle'),
            ),
            if (achievementsLabel != null)
              cell(
                const LucideIcon(
                  LucideIcons.trophy,
                  size: 22,
                  color: Color(0xFF8B5CF6),
                ),
                Text(achievementsLabel!, style: valueStyle),
                tr('accountAchievements'),
              ),
          ],
        ),
      ),
    );
  }
}

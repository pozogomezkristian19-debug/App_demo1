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
import '../services/accent.dart';

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
    // En modo oscuro, los iconos siguen el acento (item 8):
    // la estrella, la llama, el trofeo y la meta cambian al
    // color del acento en oscuro; en claro siguen ámbar,
    // naranja, violeta y teal.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // En oscuro los iconos siguen el acento (menta con Verde,
    // violeta claro con Violeta); en claro cada icono conserva
    // su color propio.
    final starColor =
        isDark ? scheme.primary : const Color(0xFFF59E0B);
    final flameColor =
        isDark ? scheme.primary : Colors.deepOrange;
    final trophyColor =
        isDark ? scheme.primary : const Color(0xFF8B5CF6);
    final goalColor =
        isDark ? scheme.primary : const Color(0xFF00C2A8);
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
      // Tarjeta con vida: radio 16 + sombra suave tintada del acento
      // (antes plana, radio 4 por defecto y sin sombra).
      elevation: 2,
      shadowColor: AppAccent.primary.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
              LucideIcon(
                LucideIcons.star,
                size: 22,
                color: starColor,
                filled: true,
                threeD: true,
              ),
              AnimatedNumber(value: p.points, style: valueStyle),
              tr('pointsTitle'),
            ),
            cell(
              FlickerWidget(
                child: LucideIcon(
                  LucideIcons.flame,
                  size: 22,
                  color: flameColor,
                  filled: true,
                  threeD: true,
                ),
              ),
              AnimatedNumber(value: p.streakNow, style: valueStyle),
              tr('streakWord'),
            ),
            cell(
              p.dailyGoalDone
                  ? LucideIcon(
                      LucideIcons.circleCheck,
                      size: 22,
                      color: goalColor,
                      threeD: true,
                    )
                  : const LucideIcon(
                      LucideIcons.target,
                      size: 22,
                      color: Color(0xFF9CA3AF),
                    ),
              // Fix3, punto 10: "Pendiente" (y "En attente" en
              // francés, aún más larga) pesaba más que los números
              // de las demás celdas. El icono de objetivo ya está
              // arriba: la palabra va en tamaño menor (13 frente a
              // 16), y el FittedBox sigue de seguridad por si en
              // algún idioma no cabe.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  p.dailyGoalDone ? tr('doneWord') : tr('pendingWord'),
                  style: valueStyle.copyWith(fontSize: 13),
                ),
              ),
              tr('dailyGoalTitle'),
            ),
            if (achievementsLabel != null)
              cell(
                LucideIcon(
                  LucideIcons.trophy,
                  size: 22,
                  color: trophyColor,
                  threeD: true,
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

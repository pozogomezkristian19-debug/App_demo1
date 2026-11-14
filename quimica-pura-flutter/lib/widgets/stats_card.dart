// Fila de estadísticas compartida (rediseño 2026-11-10, fix 3):
// Vidas, Puntos, Racha y Meta del día, con Logros opcional. Vive en
// Cuenta, debajo de la cabecera: ya NO está en Niveles, para que el
// camino de niveles suba y gane vista. Cada número aparece UNA sola
// vez: la cabecera de Cuenta ya no tiene su propia fila de
// estadísticas.
//
// Las vidas usan el chip de corazón + número (nunca la fila de 5
// corazones); los Puntos usan la ESTRELLA DORADA de Lucide (como
// la app predeterminada; Kristian, 2026-11-14 ~13:45: "Puntos,
// vidas ponlo como la app preterminada, no estos cambios que lo
// hicimos ahora") y la Racha la llama NARANJA "fireeeeee" COMO
// IMAGEN FIJA (la azul es solo para la página de racha; Kristian,
// 2026-11-14 ~12:08 y ~13:00: solo la llama queda como imagen,
// recortada al arte y sin fondo). CADA CELDA ES UNA SOLA LÍNEA
// (Kristian, 2026-11-14 ~14:57: "la parte donde dice vida punto
// racha, todo tiene que ir en una sola línea... El cinco, el cero,
// el cero, el pendiente y cero de diez también todo en una fila.
// Una fila, y todos los logos también en una fila, todo
// organizado"): icono + número juntos en una línea (como en las
// píldoras de la barra superior) y el letrero debajo, centrado;
// antes el icono iba en una línea y el número en otra. Los 5
// números van al mismo tamaño (16), incluido "Pendiente" — la
// regla vieja de fix3 punto 10 ("Pendiente" a 13 para que no
// dominara) queda sustituida por esta orden: al ir el número
// junto al icono, ya no hay columna estrecha que lo aplaste. La
// fila NO tiene fondo de tarjeta (Kristian 2026-11-14 ~12:15:
// "quitale el fondo para que no ocupe espacio"): va directa
// sobre el fondo de la página, sin tarjeta, sin sombra y sin
// relleno; la meta del día es el objetivo moderno de Lucide (con
// palomita teal cuando está hecha), nunca la banderita con
// círculo rústica.

import 'package:flutter/material.dart';

import '../services/localization.dart';
import '../services/progress.dart';
import 'animated_number.dart';
import 'lives_chip.dart';
import 'lucide_icons.dart';

/// Fila de estadísticas: Vidas / Puntos / Racha / Meta del día,
/// y Logros si se pasa [achievementsLabel] (p. ej. "1/11").
class StatsCard extends StatelessWidget {
  const StatsCard({super.key, this.achievementsLabel});

  final String? achievementsLabel;

  @override
  Widget build(BuildContext context) {
    final p = ProgressService.instance;
    final scheme = Theme.of(context).colorScheme;
    // En modo oscuro, los iconos siguen el acento (item 8):
    // el trofeo y la meta cambian al color del acento en oscuro;
    // en claro siguen violeta y teal. (Puntos es la estrella
    // dorada de Lucide, como la app predeterminada; Racha es la
    // imagen fija recortada de "fire"; lo demás son iconos
    // Lucide.)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final starColor =
        isDark ? scheme.primary : const Color(0xFFF59E0B);
    final trophyColor =
        isDark ? scheme.primary : const Color(0xFF8B5CF6);
    final goalColor =
        scheme.primary;
    Widget cell(Widget icon, Widget value, String label) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icono + número en UNA sola línea (Kristian 2026-11-14
          // ~14:57: "todo tiene que ir en una sola línea... Una
          // fila, y todos los logos también en una fila, todo
          // organizado"): antes el icono iba en una línea y el
          // número en otra; ahora van juntos, como en las
          // píldoras de la barra superior, y los 5 números quedan
          // a la misma altura. El letrero va debajo, centrado.
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 5),
              value,
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      );
    }

    const valueStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
    // SIN fondo (Kristian 2026-11-14 ~12:15: "si puedes quitale el
    // fondo para que no ocupe espacio"): la fila de celdas va
    // directa sobre el fondo de la página, sin tarjeta, sin sombra
    // y sin el relleno de la tarjeta; solo un poco de aire arriba
    // y abajo para que no se pegue a las tarjetas vecinas.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      // Una sola fila continua: cada celda mide lo que ocupa su
      // icono+número (sin columnas iguales forzadas), y el espacio
      // que sobra se reparte entre las 5 celdas para que queden
      // organizadas de borde a borde.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            // Puntos: la ESTRELLA DORADA de Lucide, como la app
            // predeterminada (Kristian 2026-11-14 ~13:45: "Puntos,
            // vidas ponlo como la app preterminada, no estos
            // cambios que lo hicimos ahora" — la medalla animada
            // "rewards" se quita).
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
            // Racha: la llama NARANJA como IMAGEN FIJA (Kristian
            // 2026-11-14 ~12:08: "la llama azul dejala para una
            // nueva racha y la otra color naranja fueguito dejala
            // para la parte de la cuenta"; 2026-11-14 ~12:51:
            // imagen en vez de animación, mismo motivo que la
            // medalla). La azul vive SOLO en la página de racha.
            Image.asset(
              'assets/streak_fire_orange.png',
              width: 28,
              height: 28,
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
              // La palabra de la meta va al MISMO tamaño que los
              // números (16, valueStyle; Kristian 2026-11-14
              // ~14:57: "El cinco, el cero, el cero, el pendiente
              // y cero de diez también todo en una fila" — el
              // "Pendiente" es uno más de la fila, no una palabra
              // aparte). La regla vieja de fix3 punto 10 ("Pendiente"
              // a 13 para que no dominara) queda sustituida: al ir
              // el número junto al icono, la celda mide lo que
              // ocupa y ya nada la aplasta.
              Text(
                p.dailyGoalDone ? tr('doneWord') : tr('pendingWord'),
                style: valueStyle,
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
    );
  }
}

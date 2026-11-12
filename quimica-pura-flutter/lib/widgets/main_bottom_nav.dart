// Barra inferior propia de Quemia (rediseño Duolingo 7.0,
// Zona A). RECONSTRUIDA 2026-11-11: la corrección urgente de
// Kristian ordenó que el navbar SE QUEDA COMO ESTABA en la
// 7.0 (el intento de barra pareja de 5 pestañas se revirtió y
// main.dart volvió a su versión 7.0). Sin copia del archivo
// original en el repo ni en staging, se reconstruyó midiendo
// los goldens fix8_navbar.png y fix6_cuenta.png (geometría,
// colores y tratamientos verificados contra ellos).
//
// - Altura 90 dp. Niveles es un círculo teal sólido de 60 dp
//   con labio de 4 pt más oscuro (un disco igual detrás,
//   desplazado 4 dp hacia abajo, del que solo asoma la
//   creciente inferior) y la única sombra del sistema
//   (floatingShadow). El círculo sobresale 4 dp por encima de
//   la barra (top: -4, Stack sin recorte). Icono de ruta
//   blanco, plano (no 3D); debajo, la etiqueta "Niveles".
// - Las 4 pestañas de fuera: icono sólido de 24 dp +
//   etiqueta de 12 pt. La seleccionada lleva fondo #F8F8F8 en
//   toda su franja, píldora #CCFBF1 de 64x32 dp detrás del
//   icono, icono y etiqueta en teal y negrita. En oscuro, la
//   franja es blanco al 6%, la píldora teal al 25% y el color
//   activo es tabColors[i] (en oscuro main.dart pasa el color
//   del acento para todas: menta o violeta claro). Las demás
//   pestañas: icono y etiqueta en gris #AFAFAF, etiqueta en
//   seminegrita.
// - El orden es Resolver (0), Aprender (1), Niveles (2,
//   centro), Tabla (3), Cuenta (4). onSelected recibe esos
//   mismos índices. El hueco central de la fila tiene flex 2.

import 'package:flutter/material.dart';

import '../services/accent.dart';
import '../services/localization.dart';
import 'lucide_icons.dart';
import 'shadows.dart';

/// Barra inferior con Niveles en el centro (círculo grande).
class MainBottomNav extends StatelessWidget {
  const MainBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.isDark,
    required this.tabColors,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool isDark;
  final List<Color> tabColors;

  /// El círculo central mide 60 dp; la barra 90 dp.
  static const double barHeight = 90.0;

  /// Tamaño del círculo central (60 dp, rediseño Duolingo §3.1).
  static const double _circleSize = 60.0;

  /// Color teal sólido de la marca.
  static const _teal = Color(0xFF00C2A8);

  /// Labio del círculo: teal 4 pt más oscuro.
  static const _lip = Color(0xFF00A18D);

  /// Gris de las pestañas inactivas.
  static const _inactive = Color(0xFFAFAFAF);

  /// Fondo de la franja de la pestaña seleccionada (claro).
  static const _selectedSlot = Color(0xFFF8F8F8);

  /// Píldora detrás del icono seleccionado (claro, verde #CCFBF1).
  static const _pill = Color(0xFFCCFBF1);

  /// Color activo de una pestaña de fuera: teal en claro (un
  /// solo color de acción); en oscuro, el color del acento que
  /// pasa main.dart en tabColors (menta o violeta claro).
  Color _activeColor(int index) =>
      isDark ? tabColors[index] : _teal;

  @override
  Widget build(BuildContext context) {
    // Orden de la barra (ronda #8): Resolver (0), Aprender (1),
    // Niveles (2, centro), Tabla (3), Cuenta (4).
    // La barra mide 90 dp + una línea fina de 1 dp arriba (el
    // borde superior): 91 dp en total. La línea va como hija
    // propia (Container de 1 dp), no como borde del fondo, para
    // que quede 1 dp por encima de la caja de 90 dp.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 1,
          color: isDark
              ? const Color(0xFF37464F)
              : const Color(0xFFE5E5E5),
        ),
        SizedBox(
          height: barHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Fondo de la barra.
              Positioned.fill(
                child: Container(
                  color: isDark ? AppAccent.darkCard : Colors.white,
                ),
              ),
          // Las 4 pestañas de fuera; el hueco central tiene flex 2.
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: _TabButton(
                    index: 0,
                    icon: LucideIcons.calculator,
                    label: tr('tabResolver'),
                    selectedIndex: selectedIndex,
                    onSelected: onSelected,
                    isDark: isDark,
                    activeColor: _activeColor(0),
                  ),
                ),
                Expanded(
                  child: _TabButton(
                    index: 1,
                    icon: LucideIcons.bookOpen,
                    label: tr('tabLearn'),
                    selectedIndex: selectedIndex,
                    onSelected: onSelected,
                    isDark: isDark,
                    activeColor: _activeColor(1),
                  ),
                ),
                const Expanded(flex: 2, child: SizedBox.shrink()),
                Expanded(
                  child: _TabButton(
                    index: 3,
                    icon: LucideIcons.layoutGrid,
                    label: tr('tabTable'),
                    selectedIndex: selectedIndex,
                    onSelected: onSelected,
                    isDark: isDark,
                    activeColor: _activeColor(3),
                  ),
                ),
                Expanded(
                  child: _TabButton(
                    index: 4,
                    icon: LucideIcons.userRound,
                    label: tr('accountTitle'),
                    selectedIndex: selectedIndex,
                    onSelected: onSelected,
                    isDark: isDark,
                    activeColor: _activeColor(4),
                  ),
                ),
              ],
            ),
          ),
          // El círculo central de Niveles, 4 dp por encima de la
          // barra, con su etiqueta debajo.
          Positioned(
            left: 0,
            right: 0,
            top: -4,
            child: Center(child: _centerTab()),
          ),
            ],
          ),
        ),
      ],
    );
  }

  /// El botón central de Niveles: círculo teal sólido de 60 dp
  /// con labio (disco oscuro de 58 dp detrás, 4 dp más abajo:
  /// su creciente inferior es el labio; ajustado contra el
  /// golden fix8_navbar), sombra flotante, icono de ruta blanco
  /// y etiqueta debajo.
  Widget _centerTab() {
    final selected = selectedIndex == 2;
    return GestureDetector(
      key: const ValueKey('nav-center-levels'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelected(2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _circleSize,
            // 60 dp de círculo + 4 dp de labio que asoma abajo.
            height: _circleSize + 4,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Labio: disco oscuro de 58 dp, 3 dp más abajo y
                // centrado (1 dp a cada lado): solo asoma su
                // creciente inferior, más fina que un disco igual
                // (centro medido a +2,75 dp contra el golden).
                Positioned(
                  top: 3,
                  left: 1,
                  child: Container(
                    width: _circleSize - 2,
                    height: _circleSize - 2,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _lip,
                    ),
                  ),
                ),
                // Círculo principal: teal sólido, sin degradado.
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    width: _circleSize,
                    height: _circleSize,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _teal,
                      boxShadow: [floatingShadow],
                    ),
                    alignment: Alignment.center,
                    child: const LucideIcon(
                      LucideIcons.route,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('tabLevels'),
            style: TextStyle(
              fontSize: 11,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.w600,
              color: selected ? _activeColor(2) : _inactive,
            ),
          ),
        ],
      ),
    );
  }
}

/// Una pestaña de fuera (Resolver, Aprender, Tabla, Cuenta):
/// icono sólido de 24 dp + etiqueta de 12 pt, centrados. La
/// seleccionada lleva fondo #F8F8F8 en toda su franja y píldora
/// #CCFBF1 de 64x32 dp detrás del icono.
class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.index,
    required this.icon,
    required this.label,
    required this.selectedIndex,
    required this.onSelected,
    required this.isDark,
    required this.activeColor,
  });

  final int index;
  final LucideIconData icon;
  final String label;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool isDark;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final selected = index == selectedIndex;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => onSelected(index),
        child: Container(
          // Franja de la seleccionada: gris muy claro en claro,
          // blanco al 6% en oscuro. El padding inferior de 4 dp
          // sube el contenido 2 dp: así icono y etiqueta quedan
          // a la misma altura que en la barra original (medido
          // contra los goldens fix8_navbar y fix6_cuenta); la
          // píldora queda 2 dp baja, diferencia menor que la de
          // icono/etiqueta.
          padding: const EdgeInsets.only(bottom: 4),
          color: selected
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : MainBottomNav._selectedSlot)
              : Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Píldora detrás del icono (solo la seleccionada).
              Container(
                width: 64,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? (isDark
                          ? MainBottomNav._teal
                              .withValues(alpha: 0.25)
                          : MainBottomNav._pill)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: LucideIcon(
                  icon,
                  size: 28,
                  color: selected
                      ? activeColor
                      : MainBottomNav._inactive,
                  threeD: selected,
                ),
              ),
              const SizedBox(height: 0),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.w600,
                  color: selected
                      ? activeColor
                      : MainBottomNav._inactive,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

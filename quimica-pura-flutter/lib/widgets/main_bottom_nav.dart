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
//   etiqueta de 12 pt. La seleccionada se distingue SOLO por el
//   color del icono y de la etiqueta (color del acento), SIN fondo
//   ni brillo detrás: ni la píldora #CCFBF1 detrás del icono ni la
//   franja #F8F8F8 (corrección de Kristian 2026-11-12: el
//   resaltado tipo píldora del tab activo es feo). En oscuro,
//   igual: sin píldora teal al 25 %. El color activo sigue al
//   acento en los dos temas: en claro AppAccent.primary (teal con
//   Verde, violeta con Violeta) y en oscuro el color del acento
//   que pasa main.dart en tabColors (menta o violeta claro).
//   Antes, en claro, el color activo, la píldora y el círculo
//   central eran teal FIJOS: con Violeta elegido, la barra entera
//   seguía verde (la mezcla de la captura de Kristian).
// - El orden es Aprender (0), Resolver (1), Niveles (2,
//   centro), Tabla (3), Cuenta (4) — Quemia 7.3: Aprender
//   primero, Resolver después. onSelected recibe esos
//   mismos índices. El hueco central de la fila tiene flex 1
//   (corrección 2026-11-12, alcance 7: con flex 2 los vecinos
//   —Aprender y Tabla— quedaban MUY separados del círculo
//   central; con flex 1 quedan pegados a él, sin tocar el
//   círculo ni cambiar las posiciones).

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

  /// Gris de las pestañas inactivas.
  static const _inactive = Color(0xFFAFAFAF);

  /// Color activo de una pestaña de fuera: el acento en los dos
  /// temas — en claro AppAccent.primary, en oscuro el color del
  /// acento que pasa main.dart en tabColors (menta o violeta
  /// claro). Antes en claro era teal fijo: con Violeta, la barra
  /// seguía verde.
  Color _activeColor(int index) =>
      isDark ? tabColors[index] : AppAccent.primary;

  @override
  Widget build(BuildContext context) {
    // Orden de la barra (ronda #8; 7.3: Aprender primero):
    // Aprender (0), Resolver (1), Niveles (2, centro), Tabla (3),
    // Cuenta (4).
    // La barra mide 90 dp + una línea fina de 1 dp arriba (el
    // borde superior): 91 dp en total. La línea va como hija
    // propia (Container de 1 dp), no como borde del fondo, para
    // que quede 1 dp por encima de la caja de 90 dp. SafeArea
    // inferior (alcance 8, 2026-11-12): en los teléfonos con
    // barra de gestos, la etiqueta "Niveles" quedaba medio
    // tapada por la barra del sistema; el SafeArea añade el
    // relleno inferior del sistema para que ninguna etiqueta
    // quede cubierta, en claro y en oscuro.
    return SafeArea(
      top: false,
      bottom: true,
      child: Column(
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
          // Las 4 pestañas de fuera; el hueco central tiene flex 1
          // (antes 2: los vecinos quedaban lejos del círculo).
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: _TabButton(
                    index: 0,
                    icon: LucideIcons.bookOpen,
                    label: tr('tabLearn'),
                    selectedIndex: selectedIndex,
                    onSelected: onSelected,
                    isDark: isDark,
                    activeColor: _activeColor(0),
                  ),
                ),
                Expanded(
                  child: _TabButton(
                    index: 1,
                    icon: LucideIcons.calculator,
                    label: tr('tabResolver'),
                    selectedIndex: selectedIndex,
                    onSelected: onSelected,
                    isDark: isDark,
                    activeColor: _activeColor(1),
                  ),
                ),
                const Expanded(flex: 1, child: SizedBox.shrink()),
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
    ),
    );
  }

  /// El botón central de Niveles: círculo sólido de 60 dp del
  /// color del acento (AppAccent.primary) con labio
  /// (AppAccent.primaryDark, disco oscuro de 58 dp detrás, 4 dp
  /// más abajo: su creciente inferior es el labio), sombra
  /// flotante, icono de ruta blanco y etiqueta debajo. El círculo
  /// NO se toca en forma ni tamaño (decisión de Kristian): solo
  /// su color sigue al acento, como los demás botones primarios.
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppAccent.primaryDark,
                    ),
                  ),
                ),
                // Círculo principal: color del acento, sólido, sin degradado.
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    width: _circleSize,
                    height: _circleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppAccent.primary,
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
/// seleccionada se distingue SOLO por el color del icono y de la
/// etiqueta (activeColor): SIN fondo ni brillo detrás (ni franja,
/// ni píldora detrás del icono — corrección 2026-11-12).
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
          // Sin fondo detrás de la seleccionada (ni franja ni
          // píldora): solo el color del icono y de la etiqueta la
          // distingue. El padding inferior de 4 dp sube el
          // contenido 2 dp: así icono y etiqueta quedan a la misma
          // altura que en la barra original (medido contra los
          // goldens fix8_navbar y fix6_cuenta).
          padding: const EdgeInsets.only(bottom: 4),
          color: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hueco del icono (64x36, como antes, pero SIN fondo:
              // la píldora de color detrás del icono está quitada).
              SizedBox(
                width: 64,
                height: 36,
                child: Center(
                  child: LucideIcon(
                    icon,
                    size: 28,
                    color: selected
                        ? activeColor
                        : MainBottomNav._inactive,
                    threeD: selected,
                  ),
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

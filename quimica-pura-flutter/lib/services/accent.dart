// Acento actual de Melli-Qui (fix2 2026-11-10): el usuario elige en
// Ajustes (Cuenta) entre el VERDE de siempre (teal #00C2A8) y el
// VIOLETA actual (#8B5CF6). Se guarda en UserPrefs.themeAccent y la
// app se reconstruye al cambiar (UserPrefs.themeAccentNotifier).
//
// El tema oscuro TAMBIÉN usa este acento (fix4, punto 2): con Verde
// es verde oscuro y con Violeta es violeta oscuro (ver main.dart).
// El acento tiñe el tema claro y el oscuro, y los elementos que
// toman su color del tema (botones, camino de niveles, barra
// inferior).

import 'package:flutter/material.dart';

import '../widgets/brand_logo.dart';
import 'user_prefs.dart';

class AppAccent {
  AppAccent._();

  /// true si el acento elegido es el violeta.
  static bool get isViolet => UserPrefs.themeAccent == 'violeta';

  /// Color principal del tema claro según el acento elegido.
  static Color get primary => isViolet ? BrandColors.violet : BrandColors.teal;

  /// Borde inferior oscuro de los botones píldora, según el acento.
  static Color get primaryDark =>
      isViolet ? BrandColors.violetDeep : BrandColors.tealDark;

  /// Color claro para fondos tintados con el acento.
  static Color get primarySoft =>
      isViolet ? const Color(0xFFEDE9FE) : const Color(0xFFCCFBF1);

  /// Fondo oscuro de las pantallas que pintan su propio fondo en modo
  /// oscuro (Estadísticas, Cuenta, Tema): verde para Verde, violeta
  /// para Violeta. Mismos valores que _darkTheme en main.dart.
  static Color get darkBackground =>
      isViolet ? const Color(0xFF17112A) : const Color(0xFF0A1F1A);

  /// Superficie oscura de las tarjetas que pintan su propio color en
  /// modo oscuro (Niveles, Tabla, Laboratorio, Estadísticas, Cuenta,
  /// Tema): verde para Verde, violeta para Violeta. Mismos valores
  /// que _darkTheme en main.dart.
  static Color get darkCard =>
      isViolet ? const Color(0xFF241B3D) : const Color(0xFF122B24);

  /// Texto suave en modo oscuro (el de las fábricas de colores de
  /// Estadísticas, Cuenta y Tema): gris verdoso para Verde, gris
  /// violáceo para Violeta.
  static Color get darkInkSoft =>
      isViolet ? const Color(0xFF9B8FC4) : const Color(0xFFB8CFC8);

  /// Borde sutil en modo oscuro: verde oscuro para Verde, violeta
  /// oscuro para Violeta.
  static Color get darkBorder =>
      isViolet ? const Color(0xFF2E2350) : const Color(0xFF1E4D42);

  /// Color del icono de cada pestaña cuando está seleccionada, en el
  /// tema claro: con el acento verde, cada pestaña conserva su color
  /// propio (aprobado en el rediseño); con el violeta, todas van en
  /// violeta. En modo oscuro la pestaña seleccionada lleva menta
  /// (Verde) o violeta claro (Violeta): ver main.dart.
  static Color tabColor(int index) {
    if (isViolet) return BrandColors.violet;
    return const [
      BrandColors.teal,
      BrandColors.violet,
      BrandColors.amber,
      BrandColors.blue,
      BrandColors.coral,
    ][index];
  }
}

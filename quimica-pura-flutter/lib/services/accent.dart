// Acento actual de Melli-Qui (fix2 2026-11-10): el usuario elige en
// Ajustes (Cuenta) entre el VERDE de siempre (teal #00C2A8) y el
// VIOLETA actual (#8B5CF6). Se guarda en UserPrefs.themeAccent y la
// app se reconstruye al cambiar (UserPrefs.themeAccentNotifier).
//
// El tema oscuro NO usa este acento: es verde siempre (fix2, item 8),
// como al principio. El acento solo tiñe el tema claro y los
// elementos que toman su color del tema (botones, camino de niveles,
// barra inferior).

import 'package:flutter/material.dart';

import '../widgets/brand_logo.dart';
import 'user_prefs.dart';

class AppAccent {
  AppAccent._();

  /// true si el acento elegido es el violeta.
  static bool get isViolet => UserPrefs.themeAccent == 'violeta';

  /// Color principal del tema claro según el acento elegido.
  static Color get primary =>
      isViolet ? BrandColors.violet : BrandColors.teal;

  /// Borde inferior oscuro de los botones píldora, según el acento.
  static Color get primaryDark =>
      isViolet ? BrandColors.violetDeep : BrandColors.tealDark;

  /// Color claro para fondos tintados con el acento.
  static Color get primarySoft =>
      isViolet ? const Color(0xFFEDE9FE) : const Color(0xFFCCFBF1);

  /// Color del icono de cada pestaña cuando está seleccionada, en el
  /// tema claro: con el acento verde, cada pestaña conserva su color
  /// propio (aprobado en el rediseño); con el violeta, todas van en
  /// violeta. En modo oscuro todos van en verde (ver main.dart).
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

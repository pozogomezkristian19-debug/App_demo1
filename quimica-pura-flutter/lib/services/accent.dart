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
import 'social_service.dart';
import 'user_prefs.dart';

class AppAccent {
  AppAccent._();

  /// true si el acento elegido es el violeta.
  static bool get isViolet => UserPrefs.themeAccent == 'violeta';

  /// Color principal del tema claro según el acento elegido.
  /// Quemia 7.0: un tema comprado en la tienda manda sobre
  /// Verde/Violeta (vive en SocialService, no en UserPrefs,
  /// porque UserPrefs solo acepta 'verde'/'violeta').
  static Color get primary {
    final shop = SocialService.equippedThemeColor;
    if (shop != null) return shop;
    return isViolet ? BrandColors.violet : BrandColors.teal;
  }

  /// Borde inferior oscuro de los botones píldora, según el acento.
  static Color get primaryDark {
    final shop = SocialService.equippedThemeColor;
    if (shop != null) {
      return Color.lerp(shop, Colors.black, 0.18)!;
    }
    return isViolet ? BrandColors.violetDeep : BrandColors.tealDark;
  }

  /// Color claro para fondos tintados con el acento.
  static Color get primarySoft {
    final shop = SocialService.equippedThemeColor;
    if (shop != null) {
      return Color.lerp(shop, Colors.white, 0.88)!;
    }
    return isViolet ? const Color(0xFFEDE9FE) : const Color(0xFFCCFBF1);
  }

  /// Versión clara y viva del acento, para iconos que se ven
  /// oscuros con el acento normal (Kristian, 2026-11-13, Tema:
  /// la luna de "Oscuro" se veía un poquito oscura en claro y
  /// el sol de "Claro" pedía ser más claro en oscuro). Verde:
  /// menta claro; Violeta: violeta claro.
  static Color get primaryLight {
    final shop = SocialService.equippedThemeColor;
    if (shop != null) {
      return Color.lerp(shop, Colors.white, 0.25)!;
    }
    return isViolet ? BrandColors.violetLight : BrandColors.mintLight;
  }

  /// Versión aún más clara del acento, para el botón "Claro"
  /// (Kristian, 2026-11-13: "pon el claro, más claro" — tiene
  /// que verse más claro que el botón de oscuro). Verde: teal
  /// claro; Violeta: violeta pálido.
  static Color get primaryLightest {
    final shop = SocialService.equippedThemeColor;
    if (shop != null) {
      return Color.lerp(shop, Colors.white, 0.5)!;
    }
    return isViolet
        ? const Color(0xFFC4B5FD)
        : const Color(0xFF5EEAD4);
  }

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

  /// Fondo oscuro de las píldoras de la barra superior (repaso y
  /// campana, Quemia 7.3): sigue al acento elegido, como todo lo
  /// demás. Con Verde es el teal oscuro aprobado por Kristian
  /// (#134E4A); con Violeta, violeta oscuro; con un tema de la
  /// tienda, una versión oscura de ese color.
  static Color get pillDarkBackground {
    final shop = SocialService.equippedThemeColor;
    if (shop != null) return Color.lerp(shop, Colors.black, 0.78)!;
    return isViolet ? const Color(0xFF2A1B52) : const Color(0xFF134E4A);
  }

  /// Color claro de dentro de esas píldoras (icono + número):
  /// menta #2DD4BF con Verde, violeta claro con Violeta.
  static Color get pillDarkForeground {
    final shop = SocialService.equippedThemeColor;
    if (shop != null) return Color.lerp(shop, Colors.white, 0.55)!;
    return isViolet ? const Color(0xFFC4B5FD) : const Color(0xFF2DD4BF);
  }

  /// Color de la pestaña seleccionada: UN
  /// SOLO color de acción (regla 9): el acento elegido (teal con
  /// Verde, violeta con Violeta), en claro y en oscuro lo pasa
  /// main.dart según el brillo. La lista de colores por pestaña de
  /// antes (cada pestaña con su color propio) queda retirada: la
  /// barra propia (MainBottomNav) usa este color único.
  static Color tabColor(int index) {
    return AppAccent.primary;
  }
}

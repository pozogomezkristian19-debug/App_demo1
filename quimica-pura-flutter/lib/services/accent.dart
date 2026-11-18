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

import 'dart:math' as math;

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

  /// Color del precio de los planes en el paywall (Kristian
  /// 2026-11-16): el acento, pero en claro se oscurece hasta que
  /// el contraste sobre la tarjeta sea ≥ 3,0 (WCAG texto grande,
  /// 16 pt extra-bold). El teal #00C2A8 sobre blanco daba 2,26;
  /// su versión oscura #00A18D (primaryDark) da 3,24. El violeta
  /// en claro ya da 4,23 y se queda; en oscuro el acento ya pasa
  /// (teal 6,65 / violeta 3,82 sobre la tarjeta oscura) y tampoco
  /// cambia. Si un tema de la tienda trae un acento que no llega,
  /// se oscurece (claro) o se aclara (oscuro) en pasos del 5 %
  /// hasta llegar (máx. 60 %).
  static Color planPriceColor({required bool isDark}) {
    final bg = isDark ? darkCard : Colors.white;
    var color = primary;
    if (wcagContrastRatio(color, bg) >= 3.0) return color;
    color = primaryDark;
    if (wcagContrastRatio(color, bg) >= 3.0) return color;
    var t = 0.0;
    while (wcagContrastRatio(color, bg) < 3.0 && t < 0.6) {
      t += 0.05;
      color = Color.lerp(
        primaryDark,
        isDark ? Colors.white : Colors.black,
        t,
      )!;
    }
    return color;
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
  /// para Violeta. Mismos valores que _darkTheme en main.dart. Con
  /// un tema de la tienda, un tinte muy oscuro de ese color
  /// (auditoría 7.7: antes el fondo oscuro era siempre verde aunque
  /// el acento fuera Coral/Rosa/Azul).
  static Color get darkBackground {
    final shop = SocialService.equippedThemeColor;
    if (shop != null) return Color.lerp(shop, Colors.black, 0.92)!;
    return isViolet ? const Color(0xFF17112A) : const Color(0xFF0A1F1A);
  }

  /// Superficie oscura de las tarjetas que pintan su propio color en
  /// modo oscuro (Niveles, Tabla, Laboratorio, Estadísticas, Cuenta,
  /// Tema): verde para Verde, violeta para Violeta. Mismos valores
  /// que _darkTheme en main.dart. Con tema de tienda, tinte oscuro
  /// de ese color (un poco más claro que el fondo).
  static Color get darkCard {
    final shop = SocialService.equippedThemeColor;
    if (shop != null) return Color.lerp(shop, Colors.black, 0.88)!;
    return isViolet ? const Color(0xFF241B3D) : const Color(0xFF122B24);
  }

  /// Texto suave en modo oscuro (el de las fábricas de colores de
  /// Estadísticas, Cuenta y Tema): gris verdoso para Verde, gris
  /// violáceo para Violeta. Con tema de tienda, tinte claro de ese
  /// color.
  static Color get darkInkSoft {
    final shop = SocialService.equippedThemeColor;
    if (shop != null) return Color.lerp(shop, Colors.white, 0.6)!;
    return isViolet ? const Color(0xFF9B8FC4) : const Color(0xFFB8CFC8);
  }

  /// Borde sutil en modo oscuro: verde oscuro para Verde, violeta
  /// oscuro para Violeta. Con tema de tienda, versión oscura de ese
  /// color.
  static Color get darkBorder {
    final shop = SocialService.equippedThemeColor;
    if (shop != null) return Color.lerp(shop, Colors.black, 0.75)!;
    return isViolet ? const Color(0xFF2E2350) : const Color(0xFF1E4D42);
  }

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

  /// Color del acento para Niveles (el círculo central y su
  /// etiqueta): el acento elegido (teal con Verde, violeta con
  /// Violeta), en claro y en oscuro lo pasa main.dart según el
  /// brillo. Las 4 pestañas de fuera ya NO usan este color único:
  /// desde 2026-11-17 cada una lleva su color propio
  /// (nav_icons.dart, Kristian: fuera el verde único para todas).
  static Color tabColor(int index) {
    return AppAccent.primary;
  }
}

/// Luminancia relativa WCAG 2.1 de un color opaco (0 negro – 1
/// blanco). La usa [wcagContrastRatio]; también la usan los tests
/// de contraste de los temas.
double wcagLuminance(Color color) {
  double channel(int value) {
    final x = value / 255;
    return x <= 0.04045
        ? x / 12.92
        : math.pow((x + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel((color.r * 255.0).round()) +
      0.7152 * channel((color.g * 255.0).round()) +
      0.0722 * channel((color.b * 255.0).round());
}

/// Contraste WCAG 2.1 entre dos colores opacos (1 – 21). Para
/// texto grande (≥ 14 pt negrita / 18 pt) el mínimo es 3,0.
double wcagContrastRatio(Color a, Color b) {
  final la = wcagLuminance(a);
  final lb = wcagLuminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

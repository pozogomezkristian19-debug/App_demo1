// Botón estilo Duolingo (rediseño 7.0, Zona A): cara SÓLIDA del
// color del botón + labio de 4 pt más oscuro abajo. SIN degradado,
// SIN banda de brillo blanca, SIN sombra borrosa — el labio ES la
// sombra. Al pulsar, el botón baja 4 pt y el labio colapsa, como
// una tecla física real.
//
//   - primary: cara sólida [bottomColor] (por defecto el color
//     del acento elegido: teal con Verde, violeta con Violeta),
//     labio [edgeColor] (por defecto el acento oscuro), texto
//     blanco. Los call-sites que pasan un color propio (p. ej.
//     el azul de compra #1CB0F6) lo conservan.
//   - secondary: cara blanca + borde 2 pt #E5E5E5 + labio 4 pt
//     #E5E5E5 + texto Eel #4B4B4B.
//   - deshabilitado (onPressed null): relleno #E5E5E5 en claro
//     (surfaceContainerHighest en oscuro), texto #AFAFAF en
//     claro (onSurface al 45 % en oscuro), sin labio.
//
// Texto: 17 pt, peso 800, tracking ~0.6 px. Radio píldora 999.
// REGLA DURA: la etiqueta se muestra TAL COMO LLEGA — el widget
// NO la convierte a mayúsculas (un toUpperCase automático
// alteraría etiquetas dinámicas). Las etiquetas de acción deben
// llegar ya en mayúsculas desde los call-sites (las zonas B/C/D
// ponen sus etiquetas estáticas en mayúsculas en sus propios
// call-sites).
// Altura 56 pt (fuente 17, ancho completo) / 48 pt en línea
// (fuente < 17, p. ej. los botones de torneos/tienda con
// fontSize 14-15).
//
// [topColor] y [shine] se conservan SOLO por compatibilidad con
// los call-sites existentes y se IGNORAN: la cara es sólida
// (topColor no se usa) y no hay brillo (shine es un no-op
// deprecado). La Zona D limpia los `shine: false` de torneos.

import 'package:flutter/material.dart';

import '../services/accent.dart';
import 'lucide_icons.dart';

class DuoButton extends StatefulWidget {
  const DuoButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    // Ignorado: la cara es sólida [bottomColor], sin degradado.
    this.topColor = const Color(0xFF14D3B8),
    // Sin color explícito: el color del acento elegido
    // (AppAccent.primary / primaryDark). Antes el defecto era
    // teal fijo y con Violeta los botones se quedaban verdes.
    this.bottomColor,
    this.edgeColor,
    this.textColor = Colors.white,
    this.icon,
    this.fontSize = 17,
    // Ignorado: no hay banda de brillo (no-op deprecado, ver abajo).
    this.shine = true,
  }) : _secondary = false;

  const DuoButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.textColor = const Color(0xFF4B4B4B),
    this.edgeColor = const Color(0xFFE5E5E5),
    this.icon,
    this.fontSize = 17,
  })  : _secondary = true,
        topColor = Colors.white,
        bottomColor = Colors.white,
        shine = true;

  final String label;
  final VoidCallback? onPressed;

  /// IGNORADO (rediseño Duolingo 7.0): la cara del botón es sólida
  /// [bottomColor]; no hay degradado. Se conserva el parámetro
  /// para no romper los call-sites que lo pasan (tienda, torneos).
  final Color topColor;

  /// Color sólido de la cara del botón (primary). null = el color
  /// del acento elegido (AppAccent.primary).
  final Color? bottomColor;

  /// Color del labio (borde inferior de 4 pt). En secondary es
  /// también el color del borde de 2 pt que rodea el botón.
  /// null = el acento oscuro (AppAccent.primaryDark).
  final Color? edgeColor;

  /// Color del texto. En secondary, los call-sites que pasan un
  /// color propio (p. ej. el botón de Google, que toca la Zona D)
  /// lo conservan; el resto usa el Eel #4B4B4B por defecto.
  final Color textColor;
  final LucideIconData? icon;
  final double fontSize;
  final bool _secondary;

  /// IGNORADO — no-op deprecado (rediseño Duolingo 7.0): no hay
  /// banda de brillo en ningún botón. Se conserva el parámetro
  /// para no romper los call-sites de torneos (`shine: false`);
  /// la Zona D lo limpia allí.
  final bool shine;

  @override
  State<DuoButton> createState() => _DuoButtonState();
}

class _DuoButtonState extends State<DuoButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final pressed = _pressed && !disabled;
    // Altura: 56 pt ancho completo (fuente 17), 48 pt en línea
    // (fuente menor, p. ej. 14-15 en torneos/tienda).
    final fullHeight = widget.fontSize >= 17;
    final minHeight = fullHeight ? 56.0 : 48.0;
    final verticalPadding = fullHeight ? 16.0 : 12.0;

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Cara y labio: el acento elegido si el call-site no pasa
    // color propio (buy-blue y demás explícitos se conservan).
    final bottomColor =
        widget.bottomColor ?? AppAccent.primary;
    final edgeColor = widget.edgeColor ?? AppAccent.primaryDark;

    final face = disabled
        ? (isDark
            ? scheme.surfaceContainerHighest
            : const Color(0xFFE5E5E5))
        : widget._secondary
            ? Colors.white
            : bottomColor;
    final text = disabled
        ? (isDark
            ? scheme.onSurface.withValues(alpha: 0.45)
            : const Color(0xFFAFAFAF))
        : widget.textColor;
    // Labio de 4 pt: colapsa a 0 al pulsar; sin labio si está
    // deshabilitado. En secondary el borde de 2 pt rodea el botón
    // con el mismo color del labio. Sin labio, el lado inferior
    // se OMITE (BorderSide.none / border null): un BorderSide
    // sólido de 0.0 con borderRadius no nulo lanza un assert
    // en debug ("hairline border ... can only be drawn when
    // BorderRadius is zero or null").
    final lipWidth = disabled || pressed ? 0.0 : 4.0;
    final Border? border = widget._secondary
        ? Border(
            top: BorderSide(color: edgeColor, width: 2),
            left: BorderSide(color: edgeColor, width: 2),
            right: BorderSide(color: edgeColor, width: 2),
            bottom: lipWidth > 0
                ? BorderSide(color: edgeColor, width: lipWidth)
                : BorderSide.none,
          )
        : lipWidth > 0
            ? Border(
                bottom:
                    BorderSide(color: edgeColor, width: lipWidth),
              )
            : null;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onPressed,
        onTapDown: (_) {
          if (!disabled) setState(() => _pressed = true);
        },
        onTapUp: (_) {
          if (!disabled) setState(() => _pressed = false);
        },
        onTapCancel: () {
          if (!disabled && _pressed) setState(() => _pressed = false);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
          // Al pulsar, el botón baja 4 pt (el labio colapsa).
          transform: pressed
              ? Matrix4.translationValues(0, 4, 0)
              : Matrix4.identity(),
          constraints: BoxConstraints(minHeight: minHeight),
          padding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: face,
            border: border,
            // Sin boxShadow borrosa: el labio ES la sombra.
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                LucideIcon(widget.icon!, size: 20, color: text),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    // Sin toUpperCase: la etiqueta llega ya en
                    // mayúsculas desde el call-site (ver cabecera).
                    widget.label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: widget.fontSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: text,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

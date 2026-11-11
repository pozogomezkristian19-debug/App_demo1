// Sistema de diseño de Quemia Admin — panel de administración profesional.
//
// Referencia: plantillas de panel de administración de CodeCanyon
// (Multipurpose Admin Dashboard UI Kit, Nazox, Unity, Dashify) y los
// principios de AdminLTE / Eleken para dashboards reales:
//  - La concha clásica: drawer de navegación + AppBar + contenido.
//  - Fila de KPIs arriba: icono en cuadrado tintado + etiqueta pequeña +
//    número grande. Tintes suaves, nunca cajas saturadas.
//  - Paleta neutra + UN acento (teal Quemia). El color saturado SOLO
//    para estado/acción.
//  - Tablas/listas limpias: cabecera pequeña gris, filas separadas por
//    línea fina. Sin tarjetas con sombra borrosa.
//  - Un solo sistema: una librería de iconos, una escala de espaciados,
//    un radio. Contraste WCAG (texto 4.5:1).
//
// Reglas duras:
//  - SIN degradados, SIN banda de brillo blanca, SIN sombra borrosa.
//  - Botón primario: cara SÓLIDA teal + labio 4 pt más oscuro (herencia
//    del botón aprobado de Quemia). Secundario: blanco + borde.
//  - Texto siempre legible: BLANCO en negrita sobre color; nunca texto
//    oscuro sobre tarjeta de color; nunca amarillo sobre verde.
//  - Avatares con CARA (assets/avatar_default.png), nunca inicial.
//  - Fuente Nunito empaquetada (la app funciona sin internet).

import 'package:flutter/material.dart';

/// Tokens de color del panel.
class AdminColors {
  AdminColors._();

  // Neutros (la base de todo el panel).
  static const Color pageBg = Color(0xFFF5F6F8);
  static const Color card = Colors.white;
  static const Color line = Color(0xFFE5E7EB);
  static const Color ink = Color(0xFF111827);
  static const Color body = Color(0xFF1F2937);
  static const Color muted = Color(0xFF6B7280);
  static const Color faint = Color(0xFF9CA3AF);

  // Acento de marca (Quemia teal): solo acción principal y activo.
  static const Color teal = Color(0xFF00C2A8);
  static const Color tealLip = Color(0xFF00A18D);
  static const Color tealDark = Color(0xFF0B7A6B);
  static const Color tealTint = Color(0xFFCCFBF1);

  // Estados (color SOLO para estado/acción).
  static const Color green = Color(0xFF16A34A);
  static const Color greenTint = Color(0xFFDCFCE7);
  static const Color greenDark = Color(0xFF15803D);
  static const Color amber = Color(0xFFD97706);
  static const Color amberTint = Color(0xFFFEF3C7);
  static const Color amberDark = Color(0xFFB45309);
  static const Color red = Color(0xFFDC2626);
  static const Color redLip = Color(0xFFB91C1C);
  static const Color redTint = Color(0xFFFEE2E2);
  static const Color redDark = Color(0xFFB91C1C);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueTint = Color(0xFFDBEAFE);
  static const Color blueDark = Color(0xFF1D4ED8);
  static const Color greyTint = Color(0xFFF3F4F6);

  // Compatibilidad con el código que ya usaba estos nombres.
  static const Color eel = ink;
  static const Color grey2 = faint;
  static const Color grey3 = muted;
  static const Color surface = pageBg;
  static const Color mint = tealTint;
  static const Color mintBorder = tealDark;
  static const Color yellow = amber;
}

/// Escala tipográfica del panel (Nunito).
class AdminText {
  AdminText._();

  static const TextStyle screenTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AdminColors.ink,
  );
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.0,
    color: AdminColors.muted,
  );
  static const TextStyle kpiValue = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    color: AdminColors.ink,
  );
  static const TextStyle kpiLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.8,
    color: AdminColors.muted,
  );
  static const TextStyle title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    color: AdminColors.ink,
  );
  static const TextStyle body = TextStyle(
    fontSize: 15,
    color: AdminColors.body,
  );
  static const TextStyle bodyBold = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AdminColors.body,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    color: AdminColors.muted,
  );
  static const TextStyle captionBold = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AdminColors.muted,
  );
}

/// Secciones del panel (lo que organiza el drawer).
enum AdminSection {
  panel,
  usuarios,
  avisos,
  editor,
  reportes,
  soporte,
  admins,
  ajustes,
}

/// Botón del panel: cara sólida + labio 4 pt en primario/destructivo,
/// blanco con borde en secundario. Radio 12 (profesional, no píldora).
/// La etiqueta llega TAL COMO SE MUESTRA: el widget NO la pasa a
/// mayúsculas; los call-sites ponen las etiquetas de acción en
/// mayúsculas cuando corresponde.
class AdminButton extends StatefulWidget {
  const AdminButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.faceColor = AdminColors.teal,
    this.lipColor = AdminColors.tealLip,
    this.textColor = Colors.white,
    this.icon,
    this.leading,
    this.fontSize = 15,
  }) : _kind = _ButtonKind.primary;

  const AdminButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.textColor = AdminColors.body,
    this.icon,
    this.leading,
    this.fontSize = 15,
  }) : _kind = _ButtonKind.secondary,
       faceColor = Colors.white,
       lipColor = AdminColors.line;

  const AdminButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.textColor = Colors.white,
    this.icon,
    this.leading,
    this.fontSize = 15,
  }) : _kind = _ButtonKind.destructive,
       faceColor = AdminColors.red,
       lipColor = AdminColors.redLip;

  final String label;
  final VoidCallback? onPressed;
  final Color faceColor;
  final Color lipColor;
  final Color textColor;
  final IconData? icon;
  final Widget? leading;
  final double fontSize;
  final _ButtonKind _kind;

  @override
  State<AdminButton> createState() => _AdminButtonState();
}

enum _ButtonKind { primary, secondary, destructive }

class _AdminButtonState extends State<AdminButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final pressed = _pressed && !disabled;
    final minHeight = widget.fontSize >= 17 ? 56.0 : 50.0;

    final face = disabled
        ? AdminColors.line
        : widget._kind == _ButtonKind.secondary
            ? Colors.white
            : widget.faceColor;
    final text = disabled ? AdminColors.faint : widget.textColor;
    // Labio de 4 pt: colapsa a 0 al pulsar; sin labio si deshabilitado.
    final lipWidth = disabled || pressed ? 0.0 : 4.0;
    final border = widget._kind == _ButtonKind.secondary
        ? Border(
            top: const BorderSide(color: AdminColors.line, width: 1.5),
            left: const BorderSide(color: AdminColors.line, width: 1.5),
            right: const BorderSide(color: AdminColors.line, width: 1.5),
            bottom: BorderSide(color: AdminColors.line, width: lipWidth),
          )
        : Border(
            bottom: BorderSide(color: widget.lipColor, width: lipWidth),
          );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
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
          transform: pressed
              ? Matrix4.translationValues(0, 4, 0)
              : Matrix4.identity(),
          constraints: BoxConstraints(minHeight: minHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: face,
            border: border,
            // Sin boxShadow borrosa: el labio ES la sombra.
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: 10),
              ] else if (widget.icon != null) ...[
                Icon(widget.icon, size: 20, color: text),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: widget.fontSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
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

/// Tarjeta blanca del panel: borde 1 pt #E5E7EB, radio 14, SIN sombra.
class AdminCard extends StatelessWidget {
  const AdminCard({super.key, required this.child, this.padding = 16});
  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.line, width: 1),
      ),
      child: child,
    );
  }
}

/// Etiqueta de sección: 12 pt, peso 800, MAYÚSCULAS, gris. La etiqueta
/// llega TAL COMO SE MUESTRA; los call-sites la pasan en mayúsculas.
class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: AdminText.sectionLabel)),
          ?trailing,
        ],
      ),
    );
  }
}

/// Alias usado por código anterior.
class AdminSectionTitle extends StatelessWidget {
  const AdminSectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return AdminSectionHeader(text.toUpperCase());
  }
}

/// Contenedor plano (alias de AdminCard, para compatibilidad).
class AdminFlatCard extends StatelessWidget {
  const AdminFlatCard({super.key, required this.child, this.padding = 16});
  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return AdminCard(padding: padding, child: child);
  }
}

/// Separador fino de lista.
class AdminRowDivider extends StatelessWidget {
  const AdminRowDivider({super.key});
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: AdminColors.line);
}

/// Tarjeta KPI: icono en cuadrado tintado + etiqueta + número grande.
/// El acento es el icono, no la caja: la tarjeta es blanca y neutra.
/// Tarjeta KPI del Panel (modelo Elite Quiz, mockup Quemia): icono en
/// cuadrado tintado, etiqueta en frase normal, número grande y, opcional,
/// una línea de referencia (delta) debajo, en color si se indica.
class AdminKpiCard extends StatelessWidget {
  const AdminKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    required this.iconColor,
    this.caption,
    this.captionColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String? caption;
  final Color? captionColor;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(label, style: AdminText.bodyBold),
          const SizedBox(height: 2),
          Text(value, style: AdminText.kpiValue),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                // Flecha dibujada (icono), no el carácter ↑: el subconjunto
                // de Nunito del preview no tiene ese glifo y salía como ▯.
                if (captionColor != null) ...[
                  Icon(
                    Icons.arrow_upward,
                    size: 13,
                    color: captionColor,
                  ),
                  const SizedBox(width: 2),
                ],
                Flexible(
                  child: Text(
                    caption!,
                    style: AdminText.caption.copyWith(
                      color: captionColor ?? AdminText.caption.color,
                      fontWeight: captionColor == null
                          ? AdminText.caption.fontWeight
                          : FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Fila etiqueta–valor de un resumen: etiqueta gris a la izquierda, valor
/// en negrita a la derecha, separadas por línea fina.
class AdminDetailRow extends StatelessWidget {
  const AdminDetailRow({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: AdminText.caption),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AdminText.bodyBold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip de estado: píldora con fondo TINTADO + texto oscuro del mismo
/// color (nunca texto blanco sobre tinte claro: no se lee). Contraste
/// verificado: texto oscuro sobre fondo claro.
class AdminStatusChip extends StatelessWidget {
  const AdminStatusChip({
    super.key,
    required this.label,
    required this.background,
    required this.textColor,
  });
  final String label;
  final Color background;
  final Color textColor;

  /// Abierto / sin responder: tinte teal + texto teal oscuro.
  const AdminStatusChip.open({super.key, required this.label})
    : background = AdminColors.tealTint,
      textColor = AdminColors.tealDark;

  /// Resuelto / arreglado: tinte gris + texto gris oscuro.
  const AdminStatusChip.done({super.key, required this.label})
    : background = AdminColors.greyTint,
      textColor = AdminColors.muted;

  /// Baneado: tinte rojo + texto rojo oscuro.
  const AdminStatusChip.banned({super.key, required this.label})
    : background = AdminColors.redTint,
      textColor = AdminColors.redDark;

  /// Dueño: tinte ámbar + texto ámbar oscuro.
  const AdminStatusChip.owner({super.key, required this.label})
    : background = AdminColors.amberTint,
      textColor = AdminColors.amberDark;

  /// Pendiente: tinte ámbar + texto ámbar oscuro.
  const AdminStatusChip.pending({super.key, required this.label})
    : background = AdminColors.amberTint,
      textColor = AdminColors.amberDark;

  /// Éxito: tinte verde + texto verde oscuro.
  const AdminStatusChip.success({super.key, required this.label})
    : background = AdminColors.greenTint,
      textColor = AdminColors.greenDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Avatar de usuario con CARA (nunca inicial). Anillo rojo = baneado,
/// teal = activo.
class AdminUserAvatar extends StatelessWidget {
  const AdminUserAvatar({super.key, this.radius = 20, this.banned = false});
  final double radius;
  final bool banned;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: banned ? AdminColors.red : AdminColors.teal,
          width: 2,
        ),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/avatar_default.png',
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// Logo G real de Google para el botón de inicio de sesión.
class GoogleGIcon extends StatelessWidget {
  const GoogleGIcon({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/google_g.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

/// Campo de búsqueda del panel: blanco, borde 1.5 pt, radio 12, 48 de alto.
class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
  });
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: AdminText.body,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, color: AdminColors.muted),
        hintText: hintText,
        hintStyle: const TextStyle(color: AdminColors.faint),
      ),
    );
  }
}

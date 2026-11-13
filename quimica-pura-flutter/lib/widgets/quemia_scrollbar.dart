// Barra de desplazamiento bonita (antes en lib/main.dart, Zona F).
//
// REGLA (corrección 2026-11-12, Kristian): la barra SOLO va en las
// pantallas de estudio (detalle de tema, glosario, cuaderno). En las
// pantallas principales (Niveles, Resolver, Aprender, Tabla, Cuenta
// y demás) NO hay barra. Por eso esto ya NO es el scrollBehavior
// global de la app: cada pantalla de estudio envuelve su scroll en
// ScrollConfiguration(behavior: const QuemiaScrollBehavior()).
// Sin ese envoltorio, Flutter en móvil no pone barra (comportamiento
// por defecto) y la pantalla principal queda limpia.
import 'package:flutter/material.dart';

import '../services/accent.dart';

/// Comportamiento de scroll SOLO para pantallas de estudio: en
/// móvil Flutter NO pone barra de desplazamiento por defecto;
/// esta clase la pone en los scrolls VERTICALES de la pantalla
/// que la envuelve (detalle de tema, glosario, cuaderno), con
/// el estilo del ScrollbarTheme global
/// (thumb del acento, redondeado, fino, siempre visible). Los
/// scrolls horizontales (chips de Tabla, historial de la
/// calculadora, tablas de Actividad/Solubilidad) quedan como
/// estaban, sin barra abajo.
/// OJO: el thumb NO lo dibuja el [Scrollbar] de Flutter, sino
/// [_QuemiaScrollThumb] (abajo): el Scrollbar necesita un
/// ScrollController con UNA sola posición, y en esta app el
/// PrimaryScrollController lo comparten todas las pestañas (el
/// AnimatedSwitcher de HomeScreen mantiene DOS scrollables vivos
/// durante el cambio de pestaña) → "ScrollController attached
/// to more than one ScrollPosition" (assert en debug, StateError
/// en release). El thumb propio se alimenta de las notificaciones
/// de SU scrollable, sin controlador compartido. El ScrollbarTheme
/// sigue siendo la única fuente de los valores (color, grosor,
/// radio, mínimo, margen): el thumb los lee de ahí.
class QuemiaScrollBehavior extends MaterialScrollBehavior {
  const QuemiaScrollBehavior();

  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    // OJO: ScrollableDetails.direction es un AxisDirection
    // (down/up/left/right), NO un Axis: comparar con
    // Axis.vertical siempre daba false y NUNCA se creaba la
    // barra (bug encontrado 2026-11-12 con una prueba mínima:
    // el thumb no se veía en ninguna pantalla). Vertical =
    // down o up.
    if (details.direction == AxisDirection.down ||
        details.direction == AxisDirection.up) {
      return _QuemiaScrollThumb(child: child);
    }
    return child;
  }
}

/// Thumb de desplazamiento propio (Zona F, corrección 2026-11-12):
/// una barrita del color del acento, redondeada y fina, a la
/// derecha del scroll vertical, SIEMPRE visible (también al
/// llegar, sin haber hecho scroll). Se alimenta de las
/// notificaciones de scroll de SU scrollable (depth 0, eje
/// vertical) y de una semilla inicial leída de la posición del
/// Scrollable que lo envuelve; NO usa ningún ScrollController,
/// así que no le afecta que el PrimaryScrollController se
/// comparta entre pestañas. No intercepta gestos (IgnorePointer):
/// el thumb es solo visual, no se arrastra.
class _QuemiaScrollThumb extends StatefulWidget {
  const _QuemiaScrollThumb({required this.child});
  final Widget child;

  @override
  State<_QuemiaScrollThumb> createState() => _QuemiaScrollThumbState();
}

class _QuemiaScrollThumbState extends State<_QuemiaScrollThumb> {
  // FOTO de las métricas, no el objeto vivo: n.metrics y la
  // posición son EL MISMO objeto mutable; si guardamos la
  // referencia, la comparación "pixels cambió" siempre da false
  // porque ambos lados ya ven el valor nuevo.
  FixedScrollMetrics? _metrics;

  FixedScrollMetrics _snap(ScrollMetrics m) => FixedScrollMetrics(
        minScrollExtent: m.minScrollExtent,
        maxScrollExtent: m.maxScrollExtent,
        pixels: m.pixels,
        viewportDimension: m.viewportDimension,
        axisDirection: m.axisDirection,
        devicePixelRatio: m.devicePixelRatio,
      );

  @override
  void initState() {
    super.initState();
    // Semilla inicial: sin hacer scroll no llega ninguna
    // notificación. El Scrollable que nos envuelve ES un
    // ancestro de este widget (el chrome lo construye el propio
    // Scrollable), así que lo buscamos subiendo por el árbol y
    // leemos su posición tras el primer frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _seed());
  }

  void _seed() {
    if (!mounted) return;
    ScrollableState? found;
    context.visitAncestorElements((e) {
      if (e.widget is Scrollable) {
        found = (e as StatefulElement).state as ScrollableState;
        return false;
      }
      return true;
    });
    final pos = found?.position;
    if (pos != null && pos.hasContentDimensions) {
      final snap = _snap(pos);
      if (_metrics == null || _metrics!.pixels != snap.pixels) {
        setState(() => _metrics = snap);
      }
    }
  }

  bool _onNotification(ScrollNotification n) {
    if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
      final snap = _snap(n.metrics);
      if (_metrics == null ||
          _metrics!.pixels != snap.pixels ||
          _metrics!.maxScrollExtent != snap.maxScrollExtent ||
          _metrics!.viewportDimension != snap.viewportDimension) {
        setState(() => _metrics = snap);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final m = _metrics;
    final theme = ScrollbarTheme.of(context);
    final thumbColor = theme.thumbColor?.resolve({}) ?? AppAccent.primary;
    final thickness = theme.thickness?.resolve({}) ?? 6.0;
    final radius = theme.radius ?? const Radius.circular(8);
    final minLength = theme.minThumbLength ?? 48.0;
    final margin = theme.crossAxisMargin ?? 2.0;
    Widget thumb = const SizedBox.shrink();
    if (m != null && m.maxScrollExtent > 0) {
      final trackH = m.viewportDimension;
      final thumbH = (trackH * trackH / (trackH + m.maxScrollExtent))
          .clamp(minLength, trackH);
      final thumbTop = (trackH - thumbH) *
          (m.pixels / m.maxScrollExtent).clamp(0.0, 1.0);
      thumb = Positioned(
        right: margin,
        top: thumbTop,
        child: IgnorePointer(
          child: Container(
            width: thickness,
            height: thumbH,
            decoration: BoxDecoration(
              color: thumbColor,
              borderRadius: BorderRadius.all(radius),
            ),
          ),
        ),
      );
    }
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onNotification,
          child: widget.child,
        ),
        thumb,
      ],
    );
  }
}

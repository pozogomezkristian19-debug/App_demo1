// Campo visible de respuesta para las preguntas de cálculo (ronda
// 7.2, Zona A): en las preguntas numéricas las opciones dejan paso
// al teclado, así que la respuesta que se lleva escrita no se veía
// en ningún sitio — había que abrir la calculadora para saber qué
// se había tecleado. Esta caja va debajo de la pregunta, donde hoy
// irían las opciones, y muestra el valor que lleva escrito (con su
// unidad si la hay) o el placeholder si está vacío. Al tocarla abre
// la calculadora (la abre quien la usa: el runner pasa `onTap`).
// La usan LOS DOS runners de preguntas (Niveles en
// screens/practicar_screen.dart y examen con tiempo / duelos /
// torneos en widgets/simple_quiz.dart): nunca arreglar solo en una
// pantalla.
//
// Diseño según las reglas de Kristian: caja SÓLIDA (blanca en
// claro, superficie del tema en oscuro), radio 16, sin degradado,
// sin brillo, sin sombra borrosa. En claro el borde es el gris muy
// suave #E5E5E5 de siempre; en oscuro NO hay borde (Kristian,
// 2026-11-13: la línea clara alrededor del campo se veía fea) —
// el campo se distingue por su relleno (surfaceContainerHighest)
// contra el fondo. Texto legible en los dos temas (onSurface /
// onSurfaceVariant del tema).
// Cuando la pregunta ya está contestada (`answered`) muestra el
// valor enviado con aspecto apagado y NO se puede tocar.
import 'package:flutter/material.dart';

import '../services/calculator.dart';
import '../services/localization.dart';
import 'lucide_icons.dart';

class NumericAnswerField extends StatelessWidget {
  const NumericAnswerField({
    super.key,
    required this.value,
    required this.unit,
    required this.answered,
    required this.onTap,
  });

  /// Valor que lleva escrito (borrador por pregunta o valor ya
  /// enviado); null = todavía no se ha escrito nada.
  final double? value;

  /// Unidad de la respuesta ('mol', 'g', 'L', 'pH'...); null = sin
  /// unidad, como el Qc.
  final String? unit;

  /// true = la pregunta ya está contestada: muestra el valor enviado
  /// apagado y no se puede tocar.
  final bool answered;

  /// Abre la calculadora; null = no editable (pregunta contestada).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasValue = value != null;
    final content = Row(
      children: [
        Expanded(
          child: Text(
            hasValue
                ? formatCalculatorResult(value!)
                : tr('numericAnswerPlaceholder'),
            key: const Key('numeric-answer-field-text'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: hasValue ? 20 : 17,
              fontWeight: FontWeight.bold,
              color: hasValue
                  ? scheme.onSurface
                  : scheme.onSurfaceVariant,
            ),
          ),
        ),
        if (unit != null) ...[
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              unit!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),
          ),
        ],
        if (!answered) ...[
          const SizedBox(width: 8),
          LucideIcon(
            LucideIcons.keyboard,
            size: 22,
            color: scheme.onSurfaceVariant,
            threeD: true,
          ),
        ],
      ],
    );
    return Opacity(
      opacity: answered ? 0.6 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? scheme.surfaceContainerHighest : Colors.white,
          borderRadius: BorderRadius.circular(16),
          // Sin borde en oscuro: la línea clara se veía fea (Kristian,
          // 2026-11-13); el relleno distingue el campo del fondo. En
          // claro queda el gris muy suave de siempre.
          border: isDark
              ? null
              : Border.all(
                  color: const Color(0xFFE5E5E5),
                  width: 2,
                ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: answered ? null : onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

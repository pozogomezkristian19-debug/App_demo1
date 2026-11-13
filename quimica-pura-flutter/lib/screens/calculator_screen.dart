// Pantalla completa de la calculadora (fix5, punto B, corrección
// 2026-11-11 00:26): la calculadora YA NO es un panel inline dentro
// de la pregunta (ese panel, de la ronda #3, desaparece por
// completo): es una página aparte (Navigator.push) que se abre con
// el botoncito de teclado y SE CIERRA para responder. A la hora de
// elegir la respuesta hay que cerrar el teclado: la calculadora
// nunca tapa las opciones ni bloquea la respuesta; al volver, la
// pregunta sigue intacta (sin resetear: ni el índice, ni la
// selección, ni el marcador, ni el progreso del nivel).
//
// - Pregunta de cálculo (respuesta numérica): modo científico y el
//   botón "Usar resultado" de la pantalla hace pop con el valor tecleado:
//   quien abrió la pantalla responde con él.
// - Opción múltiple: modo normal, solo para calcular a mano; se
//   cierra con la X o el botón atrás y se toca la opción que
//   coincide con el resultado calculado.
//
// Reutiliza NumericKeypad con el flag `scientific` (un solo
// componente, sin dos calculadoras) y los servicios de siempre
// (services/calculator.dart para evaluar, services/numeric_answer.dart
// para la tolerancia, que aplica quien responde, no esta pantalla).
import 'package:flutter/material.dart';

import '../services/localization.dart';
import '../widgets/lucide_icons.dart';
import '../widgets/numeric_keypad.dart';

/// La pantalla de la calculadora, a página completa.
///
/// [scientific] true = científica (pregunta de cálculo); false =
/// normal (las demás). En modo científico el botón "Usar resultado" del
/// teclado hace pop con el valor; en modo normal no hay nada que
/// entregar (el teclado no lleva Usar resultado) y se sale con la X o
/// atrás.
class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({
    super.key,
    required this.scientific,
    this.unit,
    this.initialValue,
    this.onDraftChanged,
  });

  final bool scientific;

  /// Unidad del campo de respuesta (solo en preguntas de cálculo).
  final String? unit;

  /// Valor con el que sembrar el campo de respuesta (ronda 7.2: lo
  /// tecleado persiste por pregunta; null = empezar vacía).
  final double? initialValue;

  /// Borrador actual en cada cambio (ronda 7.2); null = no se guarda.
  final ValueChanged<double?>? onDraftChanged;

  /// Abre la pantalla y devuelve el valor con el que responder, o
  /// null si se cierra sin más (X, atrás o gesto).
  static Future<double?> open(
    BuildContext context, {
    required bool scientific,
    String? unit,
    double? initialValue,
    ValueChanged<double?>? onDraftChanged,
  }) {
    return Navigator.of(context).push<double>(
      MaterialPageRoute(
        builder: (_) => CalculatorScreen(
          scientific: scientific,
          unit: unit,
          initialValue: initialValue,
          onDraftChanged: onDraftChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // X bien visible para cerrar: la calculadora se cierra para
        // responder, nunca se queda tapando las opciones.
        leading: IconButton(
          key: const Key('calculator-close'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const LucideIcon(LucideIcons.x, size: 24, threeD: true),
        ),
        title: Text(tr('calculate')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NumericKeypad(
            scientific: scientific,
            unit: unit,
            enabled: true,
            initialValue: initialValue,
            onDraftChanged: onDraftChanged,
            // Solo en modo científico hay algo que entregar: el
            // valor hace pop y quien abrió la pantalla responde
            // con él. En modo normal onSubmit es null y el teclado
            // no muestra el botón Usar resultado.
            onSubmit: scientific
                ? (value) => Navigator.of(context).pop<double>(value)
                : null,
          ),
        ],
      ),
    );
  }
}

/// El botoncito de teclado de una pregunta (fix5, punto B): el icono
/// sale en (casi) todas las preguntas, a un ladito del texto; al
/// tocarlo se abre la PANTALLA de la calculadora ([CalculatorScreen],
/// página completa con Navigator.push, no un panel inline) y al
/// cerrarla se vuelve a la pregunta intacta.
///
/// [scientific] true = pregunta de cálculo (respuesta numérica):
/// científica y al volver se responde con el valor; false = las
/// demás: normal, solo para calcular a mano.
/// [onResult] recibe el valor con el que responder (solo en
/// preguntas de cálculo); null = solo para calcular a mano.
class QuestionCalculatorButton extends StatelessWidget {
  const QuestionCalculatorButton({
    super.key,
    required this.question,
    required this.scientific,
    this.unit,
    this.onResult,
    this.initialValue,
    this.onDraftChanged,
  });

  /// El texto (o la tarjeta) de la pregunta: va a la izquierda del
  /// icono de teclado.
  final Widget question;

  /// true = científica (pregunta de cálculo); false = normal.
  final bool scientific;

  /// Unidad del campo de respuesta (solo en preguntas de cálculo).
  final String? unit;

  /// null = modo "para calcular a mano" (opción múltiple); no null =
  /// pregunta de cálculo: entrega el valor al volver de la pantalla.
  final ValueChanged<double>? onResult;

  /// Valor con el que sembrar el campo de respuesta (ronda 7.2: lo
  /// tecleado persiste por pregunta; solo en preguntas de cálculo).
  final double? initialValue;

  /// Borrador actual en cada cambio (ronda 7.2); solo en preguntas
  /// de cálculo — en opción múltiple no se persiste nada.
  final ValueChanged<double?>? onDraftChanged;

  Future<void> _open(BuildContext context) async {
    final value = await CalculatorScreen.open(
      context,
      scientific: scientific,
      unit: unit,
      initialValue: initialValue,
      onDraftChanged: onDraftChanged,
    );
    if (value != null) onResult?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: question),
        const SizedBox(width: 4),
        IconButton(
          key: const Key('calculator-toggle'),
          onPressed: () => _open(context),
          icon: LucideIcon(
            LucideIcons.keyboard,
            size: 22,
            color: scheme.onSurfaceVariant,
            threeD: true,
          ),
        ),
      ],
    );
  }
}

// Widgets compartidos por los solucionadores (Resolver).
import 'package:flutter/material.dart';
import '../services/advanced_solvers.dart';
import '../services/localization.dart';
import 'shadows.dart';

class SolverCard extends StatelessWidget {
  const SolverCard(
      {required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Tarjeta con vida (ronda de diseño 7.0): sombra tintada teal
    // sobre la del tema (radio 18 y fondo ya los pone el tema).
    return Card(
      elevation: 3,
      shadowColor:
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Campo numérico grande, cómodo de tocar y de leer en el teléfono.
class NumField extends StatelessWidget {
  const NumField({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 17),
        decoration: InputDecoration(
          labelText: label,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        ),
      ),
    );
  }
}

class Steps extends StatelessWidget {
  const Steps({required this.steps});
  final List<String> steps;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text('${tr('procedure')}:',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('${i + 1}. ${steps[i]}'),
          ),
      ],
    );
  }
}

double? parseNum(TextEditingController c) {
  final v = double.tryParse(c.text.replaceAll(',', '.').trim());
  return v;
}

String fmtResult(double v) {
  if (v == v.roundToDouble() && v.abs() < 1000) return v.toStringAsFixed(0);
  if (v.abs() >= 1000) return v.toStringAsExponential(2);
  if (v.abs() < 0.001 && v != 0) return v.toStringAsExponential(2);
  return v.toStringAsFixed(3);
}

/// Muestra el resultado de un solucionador avanzado: el resumen destacado
/// y los pasos, o el mensaje de error si los datos no son válidos.
class SolverResultView extends StatelessWidget {
  const SolverResultView({super.key, required this.result});
  final SolverResult result;
  @override
  Widget build(BuildContext context) {
    if (result.error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(result.error!,
            style: const TextStyle(color: Colors.redAccent)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              standardShadow(Theme.of(context).colorScheme.primary),
            ],
          ),
          child: Text(result.summary,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ),
        Steps(steps: result.lines),
      ],
    );
  }
}

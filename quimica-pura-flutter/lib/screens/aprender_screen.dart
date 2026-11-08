import 'package:flutter/material.dart';
import '../data/topics.dart';
import '../services/progress.dart';

class AprenderScreen extends StatefulWidget {
  const AprenderScreen({super.key});
  @override
  State<AprenderScreen> createState() => _AprenderScreenState();
}

class _AprenderScreenState extends State<AprenderScreen> {
  @override
  Widget build(BuildContext context) {
    final progress = ProgressService.instance;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Modo estudio',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Temas de universidad. Cada tema trae el resumen, las fórmulas clave, un ejemplo resuelto paso a paso, los errores que más cuestan puntos y un tip de examen.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Formulario rápido',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final f in formulary)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(f['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(f['expr'] ?? '', textAlign: TextAlign.right),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final topic in topics)
          Card(
            child: ExpansionTile(
              title: Text(topic.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(topic.level),
              trailing: Icon(
                progress.isMastered(topic.slug)
                    ? Icons.check_circle
                    : Icons.check_circle_outline,
                color: progress.isMastered(topic.slug) ? Colors.tealAccent : Colors.white54,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                for (final p in topic.summary)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(p),
                  ),
                const SizedBox(height: 8),
                const Text('Fórmulas clave', style: TextStyle(fontWeight: FontWeight.bold)),
                for (final f in topic.formulas)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('• ${f.name}: ${f.expr} — ${f.note}'),
                  ),
                const SizedBox(height: 12),
                Text('Ejemplo: ${topic.exampleTitle}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                for (var i = 0; i < topic.exampleSteps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${i + 1}. ${topic.exampleSteps[i]}'),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(topic.exampleAnswer,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.tealAccent)),
                ),
                const SizedBox(height: 12),
                const Text('Errores que cuestan puntos', style: TextStyle(fontWeight: FontWeight.bold)),
                for (final e in topic.errors)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('• $e'),
                  ),
                const SizedBox(height: 12),
                Text('Tip de examen: ${topic.tip}',
                    style: const TextStyle(fontStyle: FontStyle.italic)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => setState(() => progress.toggleMastered(topic.slug)),
                  icon: Icon(progress.isMastered(topic.slug) ? Icons.check : Icons.check_box_outline_blank),
                  label: Text(progress.isMastered(topic.slug) ? 'Dominado ✓' : 'Marcar como dominado'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

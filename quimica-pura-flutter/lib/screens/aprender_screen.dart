import 'package:flutter/material.dart';
import '../data/topics.dart';
import '../services/localization.dart';
import '../services/progress.dart';
import '../widgets/molecule_diagrams.dart';

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
        Text(
          tr('learnTitle'),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(tr('learnIntro')),
        const SizedBox(height: 12),
        Text(
          tr('formulary'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
        // Aprender guarda los temas de estudio principales. Orgánica y
        // Laboratorio viven en el menú de hamburguesa (Ramas y
        // Laboratorio), no aquí, para que nada esté escondido.
        for (final topic in topics.where((t) =>
            t.slug != 'organica' && t.slug != 'laboratorio'))
          Card(
            child: ExpansionTile(
              title: Text(topic.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(topic.level),
              trailing: Icon(
                progress.isMastered(topic.slug)
                    ? Icons.check_circle
                    : Icons.check_circle_outline,
                color: progress.isMastered(topic.slug)
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                for (final p in topic.summary)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(p),
                  ),
                const SizedBox(height: 8),
                Text(tr('formulasWord'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                for (final f in topic.formulas)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('• ${f.name}: ${f.expr} — ${f.note}'),
                  ),
                // Diagramas 3D de moléculas (tema de química orgánica).
                if (topic.molecules.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(tr('moleculesWord'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  for (final key in topic.molecules)
                    MoleculeCard(moleculeKey: key),
                ],
                const SizedBox(height: 12),
                Text('${tr('exampleWord')}: ${topic.exampleTitle}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                for (var i = 0; i < topic.exampleSteps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${i + 1}. ${topic.exampleSteps[i]}'),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(topic.exampleAnswer,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary)),
                ),
                const SizedBox(height: 12),
                Text(tr('errorsWord'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                for (final e in topic.errors)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('• $e'),
                  ),
                const SizedBox(height: 12),
                Text('${tr('tipWord')}: ${topic.tip}',
                    style: const TextStyle(fontStyle: FontStyle.italic)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => setState(() => progress.toggleMastered(topic.slug)),
                  icon: Icon(progress.isMastered(topic.slug) ? Icons.check : Icons.check_box_outline_blank),
                  label: Text(progress.isMastered(topic.slug)
                      ? tr('mastered')
                      : tr('markMastered')),
                ),
              ],
            ),
          ),
      ],
    );
  }
}


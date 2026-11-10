// Ramas de la química (v5): las cuatro ramas en su propia pantalla,
// cada una con sus temas. Antes la orgánica y el laboratorio vivían
// escondidos dentro de Aprender; ahora cada rama tiene su lugar en el
// menú de hamburguesa.

import 'package:flutter/material.dart';
import '../widgets/lucide_icons.dart';

import '../models.dart';
import '../services/localization.dart';
import 'topic_detail_screen.dart';

/// Una rama: su nombre, su descripción, su icono, su color y los temas
/// que la forman (por slug, en `topics` o en `branchTopics`).
class Branch {
  const Branch({
    required this.slug,
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    required this.topicSlugs,
  });

  final String slug;
  final String title;
  final String body;
  final LucideIconData icon;
  final Color color;
  final List<String> topicSlugs;
}

const List<Branch> branches = [
  Branch(
    slug: 'organica',
    title: 'Química orgánica',
    body: 'El carbono y sus compuestos: grupos funcionales, reacciones y estereoquímica.',
    icon: LucideIcons.network,
    color: Color(0xFF84CC16),
    topicSlugs: ['organica'],
  ),
  Branch(
    slug: 'inorganica',
    title: 'Química inorgánica',
    body: 'Óxidos, sales, iones y sus reacciones: lo que no es carbono.',
    icon: LucideIcons.flaskConical,
    color: Color(0xFF38BDF8),
    topicSlugs: [
      'reacciones-inorganicas',
      'color-iones',
      'identificacion-iones',
      'evidencias-reaccion',
    ],
  ),
  Branch(
    slug: 'analitica',
    title: 'Química analítica',
    body: 'Medir para saber: valoraciones, equilibrio iónico y pH.',
    icon: LucideIcons.dna,
    color: Color(0xFFA78BFA),
    topicSlugs: ['analitica', 'acido-base', 'equilibrio'],
  ),
  Branch(
    slug: 'fisicoquimica',
    title: 'Fisicoquímica',
    body: 'La física detrás de la química: energía, gases y velocidad.',
    icon: LucideIcons.thermometer,
    color: Color(0xFFEF4444),
    topicSlugs: ['fisicoquimica', 'termo-cinetica', 'gases'],
  ),
];

class BranchesScreen extends StatelessWidget {
  const BranchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('menuBranches'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'La química se divide en ramas. Cada una tiene sus temas, sus fórmulas y sus ejemplos.',
          ),
          const SizedBox(height: 12),
          for (final b in branches)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: b.color.withValues(alpha: 0.18),
                  child: LucideIcon(b.icon, color: b.color),
                ),
                title: Text(b.title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(b.body),
                trailing: const LucideIcon(LucideIcons.chevronRight),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => BranchDetailScreen(branch: b)),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class BranchDetailScreen extends StatelessWidget {
  const BranchDetailScreen({super.key, required this.branch});
  final Branch branch;

  @override
  Widget build(BuildContext context) {
    final items = <StudyTopic>[];
    for (final slug in branch.topicSlugs) {
      final t = findTopic(slug);
      if (t != null) items.add(t);
    }
    return Scaffold(
      appBar: AppBar(title: Text(branch.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: branch.color.withValues(alpha: 0.18),
                child: LucideIcon(branch.icon, color: branch.color, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(branch.body)),
            ],
          ),
          const SizedBox(height: 16),
          for (final t in items)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(t.title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(t.level),
                trailing: const LucideIcon(LucideIcons.chevronRight),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => TopicDetailScreen(topic: t)),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

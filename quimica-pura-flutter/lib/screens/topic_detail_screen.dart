// Vista de un tema de estudio (v5): la misma ficha completa que antes
// vivía dentro del ExpansionTile de Aprender, pero como pantalla propia.
// La usan Aprender (al tocar un tema), las Ramas de la química y la
// búsqueda. Incluye moléculas 3D, ejemplo, errores, consejo, el botón
// de cuestionario (tema de laboratorio) y la estrellita de favorito.

import 'package:flutter/material.dart';

import '../data/topics.dart';
import '../models.dart';
import '../services/favorites.dart';
import '../services/localization.dart';
import '../services/progress.dart';
import '../widgets/molecule_diagrams.dart';
import 'lab_quiz_screen.dart';

class TopicDetailScreen extends StatefulWidget {
  const TopicDetailScreen({super.key, required this.topic});
  final StudyTopic topic;

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final favId = 'topic:${widget.topic.slug}';
    final isFav = FavoritesService.instance.isFav(favId);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topic.title),
        actions: [
          IconButton(
            tooltip: 'Favorito',
            icon: Icon(
              isFav ? Icons.star : Icons.star_border,
              color: isFav ? Colors.amber : null,
            ),
            onPressed: () {
              FavoritesService.instance.toggle(favId);
              setState(() {});
            },
          ),
        ],
      ),
      body: TopicDetailView(topic: widget.topic),
    );
  }
}

/// Contenido completo de un tema, reutilizable en cualquier pantalla.
class TopicDetailView extends StatefulWidget {
  const TopicDetailView({super.key, required this.topic});
  final StudyTopic topic;

  @override
  State<TopicDetailView> createState() => _TopicDetailViewState();
}

class _TopicDetailViewState extends State<TopicDetailView> {
  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;
    final progress = ProgressService.instance;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(topic.level,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            )),
        const SizedBox(height: 8),
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
        // Cuestionario de laboratorio: 20 preguntas del tema.
        if (topic.slug == 'laboratorio')
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const LabQuizPage()),
                  );
                },
                icon: const Icon(Icons.quiz_outlined),
                label: Text(tr('labQuizButton')),
              ),
            ),
          ),
        ElevatedButton.icon(
          onPressed: () =>
              setState(() => progress.toggleMastered(topic.slug)),
          icon: Icon(progress.isMastered(topic.slug)
              ? Icons.check
              : Icons.check_box_outline_blank),
          label: Text(progress.isMastered(topic.slug)
              ? tr('mastered')
              : tr('markMastered')),
        ),
      ],
    );
  }
}

/// Busca un tema por su slug (en Aprender o en las ramas).
StudyTopic? findTopic(String slug) {
  for (final t in topics) {
    if (t.slug == slug) return t;
  }
  for (final t in branchTopics) {
    if (t.slug == slug) return t;
  }
  return null;
}

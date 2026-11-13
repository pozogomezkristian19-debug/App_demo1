// Vista de un tema de estudio (v5): la misma ficha completa que antes
// vivía dentro del ExpansionTile de Aprender, pero como pantalla propia.
// La usan Aprender (al tocar un tema), las Ramas de la química y la
// búsqueda. Incluye moléculas 3D, ejemplo, errores, consejo, el botón
// de cuestionario (tema de laboratorio) y la estrellita de favorito.

import 'package:flutter/material.dart';
import '../services/accent.dart';
import '../widgets/lucide_icons.dart';

import '../data/i18n/content_i18n.dart';
import '../data/topics.dart';
import '../models.dart';
import '../services/favorites.dart';
import '../services/localization.dart';
import '../widgets/molecule_diagrams.dart';
import '../widgets/quemia_scrollbar.dart';
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
        title: Text(localizedTopicName(widget.topic.slug)),
        actions: [
          IconButton(
            tooltip: 'Favorito',
            icon: LucideIcon(
              LucideIcons.star,
              filled: isFav,
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
    final topic = localizedTopic(widget.topic);
    // Diseño Duolingo §3.14 (solo tokens): secciones 20 pt peso 800
    // #4B4B4B, cuerpo 16 pt #4B4B4B.
    // Tinta según el tema: en oscuro el #4B4B4B fijo no se leía sobre
    // el fondo oscuro (bug del rediseño). onSurface es #4B4B4B en
    // claro y #E6F4EE (o #EDE9F7 violeta) en oscuro.
    // Corrección 2026-11-12 (Zona F): sin líneas divisorias
    // rústicas — las secciones se separan con aire (20 pt) y la
    // sección "Fórmulas" vive en su propia tarjeta, como el resto
    // de la app. El contenido y el orden no cambian.
    final ink = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppAccent.darkCard : Colors.white;
    // Borde oscuro tono sobre tono en oscuro (misma razón
    // que Aprender: la tarjeta es darkCard).
    final borderColor = isDark ? AppAccent.darkBorder : const Color(0xFFE5E5E5);
    final section =
        TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ink);
    final body = TextStyle(fontSize: 16, color: ink);
    const gap = SizedBox(height: 20);
    // Barra de desplazamiento bonita SOLO aquí (pantalla de estudio;
    // en las principales no hay barra, 2026-11-12).
    return ScrollConfiguration(
      behavior: const QuemiaScrollBehavior(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(topic.level,
              style: TextStyle(
                color: ink,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              )),
          const SizedBox(height: 8),
          for (final p in topic.summary)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(p, style: body),
            ),
          gap,
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('formulasWord'), style: section),
                  for (final f in topic.formulas)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('• ${f.name}: ${f.expr} — ${f.note}',
                          style: body),
                    ),
                ],
              ),
            ),
          ),
          // Diagramas 3D de moléculas (tema de química orgánica).
          if (topic.molecules.isNotEmpty) ...[
            gap,
            Text(tr('moleculesWord'), style: section),
            for (final key in topic.molecules) MoleculeCard(moleculeKey: key),
          ],
          gap,
          Text('${tr('exampleWord')}: ${topic.exampleTitle}', style: section),
          for (var i = 0; i < topic.exampleSteps.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${i + 1}. ${topic.exampleSteps[i]}', style: body),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(topic.exampleAnswer,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: ink)),
          ),
          gap,
          Text(tr('errorsWord'), style: section),
          for (final e in topic.errors)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('• $e', style: body),
            ),
          gap,
          Text('${tr('tipWord')}: ${topic.tip}',
              style: TextStyle(
                  fontSize: 16, fontStyle: FontStyle.italic, color: ink)),
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
                      MaterialPageRoute(builder: (_) => const LabQuizPage()),
                    );
                  },
                  icon: const LucideIcon(LucideIcons.circleHelp),
                  label: Text(tr('labQuizButton')),
                ),
              ),
            ),
        ],
      ),
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

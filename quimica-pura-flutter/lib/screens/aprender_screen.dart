import 'package:flutter/material.dart';
import '../widgets/lucide_icons.dart';
import '../data/i18n/content_i18n.dart';
import '../data/topics.dart';
import '../services/localization.dart';
import '../services/progress.dart';
import 'glossary_screen.dart';
import 'notes_screen.dart';
import 'tips_screen.dart';
import 'topic_detail_screen.dart';

class AprenderScreen extends StatefulWidget {
  const AprenderScreen({super.key});
  @override
  State<AprenderScreen> createState() => _AprenderScreenState();
}

class _AprenderScreenState extends State<AprenderScreen> {
  @override
  Widget build(BuildContext context) {
    final progress = ProgressService.instance;
    // Título e introducción con el estilo explícito del tema (igual
    // que en Tips): sin estilo, el texto depende del DefaultTextStyle
    // ambiente y puede pintarse roto; con bodyMedium/titleLarge es
    // siempre el cuerpo normal de la app, en claro y en oscuro.
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          tr('learnTitle'),
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(tr('learnIntro'), style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        // Glosario y cuaderno: antes solo se llegaba desde la búsqueda.
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const GlossaryScreen()),
                  );
                },
                icon: const LucideIcon(LucideIcons.bookOpen, size: 18),
                label: Text(tr('glossaryTitle')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const NotesScreen()),
                  );
                },
                icon: const LucideIcon(LucideIcons.notebookPen, size: 18),
                label: Text(tr('notesTitle')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Tips de examen: antes era una pestaña aparte; ahora vive aquí,
        // en Aprender, como tarjeta visible (v6).
        Card(
          child: ListTile(
            leading: const LucideIcon(LucideIcons.lightbulb, size: 28),
            title: Text(tr('tipsExamCard'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(tr('tipsExamSub')),
            trailing: const LucideIcon(LucideIcons.chevronRight),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TipsScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          tr('formulary'),
          style: theme.textTheme.titleMedium,
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
                          child: Text(localizedFormularyName(f['name'] ?? ''), style: const TextStyle(fontWeight: FontWeight.w600)),
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
        // Cada tema es una tarjeta limpia (título, nivel y marca de
        // dominado): al tocarla se abre su pantalla propia completa
        // (TopicDetailScreen, la misma que usan las Ramas y la
        // búsqueda). Nada se despliega dentro de la tarjeta.
        // Pulido: mismo aire que las tarjetas de Ramas (margen
        // inferior de 8), tarjeta alta con respiración vertical y el
        // chevron suave para que la marca de dominado sea el ancla.
        for (final topic in topics
            .where((t) => t.slug != 'organica' && t.slug != 'laboratorio')
            .map(localizedTopic))
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(topic.title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(topic.level),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LucideIcon(
                    progress.isMastered(topic.slug)
                        ? LucideIcons.circleCheck
                        : LucideIcons.circle,
                    color: progress.isMastered(topic.slug)
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.35),
                  ),
                  const SizedBox(width: 8),
                  LucideIcon(LucideIcons.chevronRight,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.45)),
                ],
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => TopicDetailScreen(topic: topic)),
                );
              },
            ),
          ),
      ],
    );
  }
}


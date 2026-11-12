// Favoritos (v5): elementos, temas y fórmulas marcados con la
// estrellita, todos juntos en su pantalla. Al tocar uno, se abre.

import 'package:flutter/material.dart';
import '../widgets/lucide_icons.dart';

import '../data/periodic_table.dart';
import '../models.dart';
import '../services/favorites.dart';
import '../services/localization.dart';
import '../widgets/element_sheet.dart';
import 'topic_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  Widget build(BuildContext context) {
    final favs = FavoritesService.instance;
    final elements = favs.favoriteElements
        .map((z) => allElements.firstWhere((e) => e.atomicNumber == z))
        .toList();
    final topics = favs.favoriteTopics
        .map(findTopic)
        .whereType<StudyTopic>()
        .toList();
    final formulas = favs.favoriteFormulas;
    return Scaffold(
      appBar: AppBar(title: Text(tr('menuFavorites'))),
      body: favs.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Aún no tienes favoritos. Toca la estrellita en un elemento, un tema o una fórmula para guardarlo aquí.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (elements.isNotEmpty) ...[
                  const Text('Elementos',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  for (final e in elements)
                    Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      elevation: 2,
                      shadowColor: const Color(0xFF00C2A8)
                          .withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(e.symbol,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(e.name),
                        subtitle: Text(
                            'Z = ${e.atomicNumber} · ${categoryNames[e.category]}'),
                        trailing: const LucideIcon(LucideIcons.chevronRight),
                        onTap: () => showElementSheet(context, e),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
                if (topics.isNotEmpty) ...[
                  const Text('Temas',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  for (final t in topics)
                    Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      elevation: 2,
                      shadowColor: const Color(0xFF00C2A8)
                          .withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: const LucideIcon(LucideIcons.bookOpen),
                        title: Text(t.title),
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
                  const SizedBox(height: 12),
                ],
                if (formulas.isNotEmpty) ...[
                  const Text('Fórmulas',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  for (final name in formulas)
                    Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      elevation: 2,
                      shadowColor: const Color(0xFF00C2A8)
                          .withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: const LucideIcon(LucideIcons.sigma),
                        title: Text(name),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

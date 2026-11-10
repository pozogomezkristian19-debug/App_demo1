// Formulario rápido (v5): todas las fórmulas de la app en una sola
// pantalla, agrupadas por tema. Cada fórmula se puede marcar como
// favorita con la estrellita.

import 'package:flutter/material.dart';

import '../data/topics.dart';
import '../services/favorites.dart';
import '../services/localization.dart';

class FormulaScreen extends StatefulWidget {
  const FormulaScreen({super.key});
  @override
  State<FormulaScreen> createState() => _FormulaScreenState();
}

class _FormulaScreenState extends State<FormulaScreen> {
  @override
  Widget build(BuildContext context) {
    // Todas las fórmulas: el formulario general + las de cada tema,
    // agrupadas por el nombre del tema.
    final groups = <String, List<(String, String, String)>>{};
    for (final f in formulary) {
      groups.putIfAbsent(f['group'] ?? 'Fórmulas', () => []).add((
        f['name'] ?? '',
        f['expr'] ?? '',
        '',
      ));
    }
    for (final t in topics) {
      for (final f in t.formulas) {
        groups.putIfAbsent(t.title, () => []).add((f.name, f.expr, f.note));
      }
    }
    return Scaffold(
      appBar: AppBar(title: Text(tr('menuFormulas'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Todas las fórmulas juntas, para consultar rápido antes del examen.',
          ),
          const SizedBox(height: 12),
          for (final group in groups.keys) ...[
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Text(group,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            for (final (name, expr, note) in groups[group]!)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  title: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(note.isEmpty ? expr : '$expr — $note'),
                  trailing: IconButton(
                    icon: Icon(
                      FavoritesService.instance.isFav('formula:$name')
                          ? Icons.star
                          : Icons.star_border,
                      color: FavoritesService.instance.isFav('formula:$name')
                          ? Colors.amber
                          : null,
                    ),
                    onPressed: () {
                      FavoritesService.instance.toggle('formula:$name');
                      setState(() {});
                    },
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// Formulario rápido (v5): todas las fórmulas de la app en una sola
// pantalla, agrupadas por tema. Cada fórmula se puede marcar como
// favorita con la estrellita.

import 'package:flutter/material.dart';

import '../data/i18n/content_i18n.dart';
import '../data/topics.dart';
import '../services/favorites.dart';
import '../services/localization.dart';
import '../widgets/lucide_icons.dart';

class FormulaScreen extends StatefulWidget {
  const FormulaScreen({super.key});
  @override
  State<FormulaScreen> createState() => _FormulaScreenState();
}

class _FormulaScreenState extends State<FormulaScreen> {
  @override
  Widget build(BuildContext context) {
    // Todas las fórmulas: el formulario general + las de cada tema,
    // agrupadas por el nombre del tema. Cada entrada guarda el nombre
    // español (para el id de favorito, que no depende del idioma) y el
    // nombre a mostrar (traducido, v6).
    final groups = <String, List<(String, String, String, String)>>{};
    // Sin duplicados (Kristian, 2026-11-13): "Gas ideal" salía 2
    // veces en el Formulario — una del listado general y otra del
    // tema "Gases ideales" (y otra más en "Química física"). Es la
    // misma fórmula, así que se queda la primera y se saltan las
    // demás con el mismo nombre.
    final seenNames = <String>{};
    for (final f in formulary) {
      final name = f['name'] ?? '';
      if (!seenNames.add(name)) continue;
      groups.putIfAbsent(
          localizedFormularyGroup(f['group'] ?? 'Fórmulas'), () => []).add((
        name,
        localizedFormularyName(name),
        f['expr'] ?? '',
        '',
      ));
    }
    for (final t in topics) {
      final lt = localizedTopic(t);
      for (var j = 0; j < t.formulas.length; j++) {
        final f = t.formulas[j];
        if (!seenNames.add(f.name)) continue;
        final tf = lt.formulas[j];
        groups.putIfAbsent(localizedTopicName(t.slug), () => []).add((
          f.name,
          tf.name,
          f.expr,
          tf.note,
        ));
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
            for (final (spanishName, name, expr, note) in groups[group]!)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  title: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(note.isEmpty ? expr : '$expr — $note'),
                  trailing: IconButton(
                    icon: LucideIcon(
                      LucideIcons.star,
                      filled: FavoritesService.instance
                          .isFav('formula:$spanishName'),
                      color: FavoritesService.instance.isFav('formula:$spanishName')
                          ? Colors.amber
                          : null,
                    ),
                    onPressed: () {
                      FavoritesService.instance.toggle('formula:$spanishName');
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

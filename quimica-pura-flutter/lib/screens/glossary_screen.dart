// Glosario (v5): términos de química explicados, con búsqueda.
// Al tocar un término desde la búsqueda se abre esta pantalla.

import 'package:flutter/material.dart';
import '../widgets/lucide_icons.dart';

import '../data/extra_content.dart';
import '../data/i18n/content_i18n.dart';
import '../services/localization.dart';
import '../widgets/quemia_scrollbar.dart';

class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key, this.initialQuery = ''});
  final String initialQuery;

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  late String _query;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
  }

  @override
  Widget build(BuildContext context) {
    final q = fold(_query.trim());
    // El glosario se muestra en el idioma activo (v6).
    final all = localizedGlossary();
    final visible = q.isEmpty
        ? all
        : all
            .where((g) =>
                fold(g.term).contains(q) || fold(g.definition).contains(q))
            .toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr('glossaryTitle'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                labelText: tr('searchWord'),
                prefixIcon: const LucideIcon(LucideIcons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            // Barra de desplazamiento bonita SOLO aquí (pantalla
            // de estudio; en las principales no hay barra,
            // 2026-11-12).
            child: ScrollConfiguration(
              behavior: const QuemiaScrollBehavior(),
              child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final g in visible)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.term,
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(g.definition),
                        ],
                      ),
                    ),
                  ),
                if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Nada por aquí. Prueba con otra palabra.',
                        textAlign: TextAlign.center),
                  ),
              ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

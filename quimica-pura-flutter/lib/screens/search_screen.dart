// Búsqueda global (v5): una barra que busca temas, solucionadores,
// elementos, fórmulas, glosario y pantallas. Al tocar un resultado se
// va directo a él. Se abre con la lupita de la barra de arriba.

import 'package:flutter/material.dart';

import '../data/search_index.dart';
import '../services/localization.dart';

const Map<String, IconData> _icons = {
  'hub': Icons.hub,
  'biotech': Icons.biotech,
  'bar_chart': Icons.bar_chart,
  'style': Icons.style,
  'timer': Icons.timer,
  'sports_esports': Icons.sports_esports,
  'book': Icons.book,
  'compare_arrows': Icons.compare_arrows,
  'note': Icons.note,
  'table_chart': Icons.table_chart,
  'functions': Icons.functions,
  'swap_horiz': Icons.swap_horiz,
  'star': Icons.star,
  'alarm': Icons.alarm,
  'swap_horizontal_circle': Icons.swap_horizontal_circle,
  'language': Icons.language,
  'quiz': Icons.quiz,
  'science': Icons.science,
  'replay': Icons.replay_circle_filled,
  'menu_book': Icons.menu_book,
  'route': Icons.route,
  'calculate': Icons.calculate,
  'grid_view': Icons.grid_view,
};

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.onEntryTap});
  final void Function(SearchEntry entry) onEntryTap;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final List<SearchEntry> _all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _all = buildSearchEntries();
  }

  String _kindLabel(String kind) {
    switch (kind) {
      case 'topic':
        return 'Tema';
      case 'solver':
        return 'Solucionador';
      case 'element':
        return 'Elemento';
      case 'formula':
        return 'Fórmula';
      case 'glossary':
        return 'Glosario';
      case 'levels':
        return 'Niveles';
      default:
        return 'Pantalla';
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = searchEntries(_all, _query);
    return Scaffold(
      appBar: AppBar(title: Text(tr('searchWord'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Busca temas, solucionadores, elementos…',
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: _query.trim().isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Escribe algo: un tema (orgánica, gases), un solucionador (pH, molaridad), un elemento (oxígeno, Fe) o una pantalla (estadísticas, glosario).',
                      textAlign: TextAlign.center,
                    ),
                  )
                : results.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Nada por aquí. Prueba con otra palabra.',
                            textAlign: TextAlign.center),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(8),
                        children: [
                          for (final e in results)
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.15),
                                child: Icon(
                                  _icons[e.icon] ?? Icons.search,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              title: Text(e.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text('${_kindLabel(e.kind)} · ${e.subtitle}'),
                              trailing:
                                  const Icon(Icons.chevron_right, size: 18),
                              onTap: () => widget.onEntryTap(e),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

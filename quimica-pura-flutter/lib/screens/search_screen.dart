// Búsqueda global (v5): una barra que busca temas, solucionadores,
// elementos, fórmulas, glosario y pantallas. Al tocar un resultado se
// va directo a él. Se abre con la lupita de la barra de arriba.

import 'package:flutter/material.dart';
import '../widgets/lucide_icons.dart';

import '../data/search_index.dart';
import '../services/localization.dart';
import '../services/progress.dart';

const Map<String, LucideIconData> _icons = {
  'hub': LucideIcons.network,
  'biotech': LucideIcons.dna,
  'bar_chart': LucideIcons.chartColumn,
  'style': LucideIcons.layers,
  'timer': LucideIcons.timer,
  'leaderboard': LucideIcons.trophy,
  'friends': LucideIcons.userRound,
  'tournament': LucideIcons.award,
  'shop': LucideIcons.gift,
  'groups': LucideIcons.network,
  'book': LucideIcons.bookOpen,
  'compare_arrows': LucideIcons.arrowLeftRight,
  'note': LucideIcons.notebookPen,
  'table_chart': LucideIcons.table,
  'functions': LucideIcons.sigma,
  'swap_horiz': LucideIcons.arrowLeftRight,
  'star': LucideIcons.star,
  'alarm': LucideIcons.alarmClock,
  'swap_horizontal_circle': LucideIcons.refreshCw,
  'language': LucideIcons.globe,
  'quiz': LucideIcons.circleHelp,
  'science': LucideIcons.flaskConical,
  'replay': LucideIcons.rotateCcw,
  'menu_book': LucideIcons.bookOpen,
  'route': LucideIcons.route,
  'calculate': LucideIcons.calculator,
  'grid_view': LucideIcons.layoutGrid,
};

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.onEntryTap});
  final void Function(SearchEntry entry) onEntryTap;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final List<SearchEntry> _all;
  final _controller = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _all = buildSearchEntries();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Guarda la consulta actual como reciente (si hay algo escrito).
  void _recordCurrentQuery() {
    final q = _query.trim();
    if (q.isNotEmpty) ProgressService.instance.recordSearch(q);
  }

  /// Corre una búsqueda reciente: la pone en la barra y la ejecuta.
  void _runRecent(String q) {
    _controller.text = q;
    setState(() => _query = q);
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
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Busca temas, solucionadores, elementos…',
                prefixIcon: const LucideIcon(LucideIcons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
              onSubmitted: (_) => _recordCurrentQuery(),
            ),
          ),
          Expanded(
            child: _query.trim().isEmpty
                ? _RecentSearches(onPick: _runRecent)
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
                            Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              elevation: 1,
                              shadowColor: const Color(0xFF00C2A8)
                                  .withValues(alpha: 0.12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.15),
                                child: LucideIcon(
                                  _icons[e.icon] ?? LucideIcons.search,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              title: Text(e.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text('${_kindLabel(e.kind)} · ${e.subtitle}'),
                              trailing:
                                  const LucideIcon(LucideIcons.chevronRight, size: 18),
                              onTap: () {
                                _recordCurrentQuery();
                                widget.onEntryTap(e);
                              },
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

/// Cuando no hay nada escrito: la pista de qué buscar y las últimas 5
/// búsquedas guardadas (v6), que se pueden tocar para repetirlas.
class _RecentSearches extends StatelessWidget {
  const _RecentSearches({required this.onPick});
  final void Function(String query) onPick;

  @override
  Widget build(BuildContext context) {
    final recent = ProgressService.instance.recentSearches;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Escribe algo: un tema (orgánica, gases), un solucionador (pH, molaridad), un elemento (oxígeno, Fe) o una pantalla (estadísticas, glosario).',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Text(tr('recentSearches'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        if (recent.isEmpty)
          Text(tr('noRecentSearches'))
        else
          for (final q in recent)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              elevation: 1,
              shadowColor:
                  const Color(0xFF00C2A8).withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const LucideIcon(LucideIcons.history),
                title: Text(q),
                trailing:
                    const LucideIcon(LucideIcons.chevronRight, size: 18),
                onTap: () => onPick(q),
              ),
            ),
      ],
    );
  }
}

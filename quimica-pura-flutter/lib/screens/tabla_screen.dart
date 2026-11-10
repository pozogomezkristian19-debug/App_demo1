import 'package:flutter/material.dart';
import '../widgets/lucide_icons.dart';
import '../data/i18n/content_i18n.dart';
import '../data/periodic_table.dart';
import '../data/reference_tables.dart';
import '../models.dart';
import '../services/localization.dart';
import '../services/nav_requests.dart';
import '../widgets/element_sheet.dart';
import 'compare_screen.dart';
import 'table_quiz_screen.dart';

class TablaScreen extends StatefulWidget {
  const TablaScreen({super.key});
  @override
  State<TablaScreen> createState() => _TablaScreenState();
}

class _TablaScreenState extends State<TablaScreen>
    with SingleTickerProviderStateMixin {
  String _query = '';
  int? _filterCategory;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Peticiones de la búsqueda o del menú: filtrar por texto o abrir
    // una pestaña concreta.
    if (NavRequests.tableQuery != null) {
      _query = NavRequests.tableQuery!;
      NavRequests.tableQuery = null;
    }
    if (NavRequests.tableTab != null) {
      _tabController.animateTo(NavRequests.tableTab!);
      NavRequests.tableTab = null;
    }
  }

  static const List<Color> _catColors = [
    Color(0xFFF4A261),
    Color(0xFFE9C46A),
    Color(0xFF8ECAE6),
    Color(0xFFA7C4A0),
    Color(0xFFB8B8D0),
    Color(0xFF90E0A8),
    Color(0xFFF2CC8F),
    Color(0xFFCDB4DB),
    Color(0xFFFFB4A2),
    Color(0xFFE5989B),
  ];

  List<ChemicalElement> get _visible {
    return allElements.where((e) {
      if (_filterCategory != null && e.category != _filterCategory) return false;
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return e.name.toLowerCase().contains(q) ||
          localizedElementName(e).toLowerCase().contains(q) ||
          e.symbol.toLowerCase() == q;
    }).toList();
  }

  void _showDetail(ChemicalElement e) {
    showElementSheet(context, e);
  }

  Widget _cell(BuildContext context, ChemicalElement? e) {
    if (e == null) return const SizedBox.shrink();
    final dimmed = _filterCategory != null && e.category != _filterCategory;
    return GestureDetector(
      onTap: () => _showDetail(e),
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: dimmed
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)
              : _catColors[e.category],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
        ),
        // Solo símbolo + número atómico, con FittedBox: nada puede
        // salirse de la cuadrícula, por estrecha que sea la pantalla.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(e.atomicNumber.toString(),
                  style: const TextStyle(fontSize: 7, color: Colors.black87)),
              Text(e.symbol,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: tr('tabPeriodic')),
            Tab(text: tr('tabActivity')),
            Tab(text: tr('tabSolubility')),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _periodicTab(context),
              _activityTab(context),
              _solubilityTab(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _periodicTab(BuildContext context) {
    // Rejilla 18 columnas × 10 filas (filas 9 y 10 = bloques f).
    final grid = List<ChemicalElement?>.filled(18 * 10, null);
    for (final e in allElements) {
      final idx = (e.row - 1) * 18 + (e.column - 1);
      if (idx >= 0 && idx < grid.length) grid[idx] = e;
    }
    final searching = _query.isNotEmpty || _filterCategory != null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              labelText: tr('searchHint'),
              prefixIcon: const LucideIcon(LucideIcons.search),
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const TableQuizScreen()),
                    );
                  },
                  icon: const LucideIcon(LucideIcons.circleHelp, size: 18),
                  label: Text(tr('tableQuizTitle')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const CompareScreen()),
                    );
                  },
                  icon: const LucideIcon(LucideIcons.arrowLeftRight, size: 18),
                  label: Text(tr('compareTitle')),
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              ChoiceChip(
                label: Text(tr('allWord')),
                selected: _filterCategory == null,
                onSelected: (_) => setState(() => _filterCategory = null),
              ),
              for (var i = 0; i < categoryNames.length; i++)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text(categoryNames[i]),
                    selected: _filterCategory == i,
                    onSelected: (_) => setState(
                        () => _filterCategory = _filterCategory == i ? null : i),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: searching
              ? ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Text('${_visible.length} ${tr('elementsWord')}',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        )),
                    for (final e in _visible)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _catColors[e.category],
                          child: Text(e.symbol,
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(localizedElementName(e)),
                        subtitle: Text(
                            'Z = ${e.atomicNumber} · ${tr('massWord')} ${e.mass} · ${localizedCategoryName(e.category)}'),
                        onTap: () => _showDetail(e),
                      ),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.all(8),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 18,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: grid.length,
                    itemBuilder: (context, i) {
                      // Marcadores 57–71 y 89–103 en la rejilla principal.
                      if (i == (6 - 1) * 18 + (3 - 1)) {
                        return Container(
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: _catColors[8],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('57–71',
                                style: TextStyle(
                                    fontSize: 7,
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold)),
                          ),
                        );
                      }
                      if (i == (7 - 1) * 18 + (3 - 1)) {
                        return Container(
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: _catColors[9],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('89–103',
                                style: TextStyle(
                                    fontSize: 7,
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold)),
                          ),
                        );
                      }
                      return _cell(context, grid[i]);
                    },
                  ),
                ),
        ),
        // Leyenda de colores debajo de la tabla.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            children: [
              Text(tr('legendWord'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < categoryNames.length; i++)
                    InkWell(
                      onTap: () => setState(() => _filterCategory =
                          _filterCategory == i ? null : i),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _catColors[i],
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                  color:
                                      Colors.black.withValues(alpha: 0.2)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(categoryNames[i],
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '118 ${tr('elementsWord')}.',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _activityTab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(tr('activityIntro'),
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.8))),
        const SizedBox(height: 12),
        for (var i = 0; i < metalActivitySeries.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: i < 11
                    ? Colors.teal.withValues(alpha: 0.18)
                    : Colors.grey.withValues(alpha: 0.25),
                child: Text(
                  metalActivitySeries[i].symbol,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              title: Text(
                  '${i + 1}. ${_activityName(metalActivitySeries[i])}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(localizedReferenceString(
                  metalActivitySeries[i].reaction)),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'El hidrógeno (H₂) es la referencia: los metales de arriba lo desplazan de los ácidos; los de abajo, no.',
          style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
        ),
      ],
    );
  }

  Widget _solubilityTab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color cellColor(String v) {
      switch (v) {
        case 'S':
          return Colors.green.withValues(alpha: 0.25);
        case 'I':
          return Colors.red.withValues(alpha: 0.18);
        default:
          return Colors.amber.withValues(alpha: 0.30);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(tr('solubilityIntro'),
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.8))),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 56,
            dataRowMinHeight: 40,
            columns: [
              const DataColumn(label: Text('Anión')),
              for (final c in solubilityColumns)
                DataColumn(
                    label: Text(localizedReferenceString(c),
                        textAlign: TextAlign.center)),
            ],
            rows: [
              for (final row in solubilityTable)
                DataRow(
                  cells: [
                    DataCell(Text(
                        '${row.anion}\n${localizedReferenceString(row.name)}',
                        style: const TextStyle(fontSize: 12))),
                    for (final v in row.cells)
                      DataCell(
                        Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: cellColor(v),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(v,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Reglas',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final rule in solubilityRules)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(rule)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Nombre del metal en el idioma activo: la serie guarda el nombre en
/// español; se resuelve el elemento por su símbolo.
String _activityName(ActivityEntry a) {
  final el = allElements.where((e) => e.symbol == a.symbol).firstOrNull;
  return el == null ? a.name : localizedElementName(el);
}

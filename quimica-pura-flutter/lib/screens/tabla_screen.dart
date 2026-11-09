import 'package:flutter/material.dart';
import '../data/periodic_table.dart';
import '../models.dart';

class TablaScreen extends StatefulWidget {
  const TablaScreen({super.key});
  @override
  State<TablaScreen> createState() => _TablaScreenState();
}

class _TablaScreenState extends State<TablaScreen> {
  String _query = '';
  int? _filterCategory;

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
      return e.name.toLowerCase().contains(q) || e.symbol.toLowerCase() == q;
    }).toList();
  }

  void _showDetail(ChemicalElement e) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: _catColors[e.category],
                  child: Text(e.symbol,
                      style: const TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      Text('Número atómico ${e.atomicNumber} · ${categoryNames[e.category]}'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Masa atómica: ${e.mass}'),
            Text('Periodo: ${e.period} · Grupo: ${e.column} · Bloque: ${e.block}'),
            Text('Categoría: ${categoryNames[e.category]}'),
            const SizedBox(height: 8),
            Text(
              'Los lantánidos (57–71) y actínidos (89–103) se muestran en las dos filas separadas de abajo, como en la tabla clásica.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
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
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(e.atomicNumber.toString(),
                style: const TextStyle(fontSize: 7, color: Colors.black87)),
            Text(e.symbol,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            decoration: const InputDecoration(
              labelText: 'Buscar por nombre o símbolo',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Todos'),
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
                    Text('${_visible.length} elementos',
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
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(e.name),
                        subtitle: Text('Z = ${e.atomicNumber} · Masa ${e.mass} · ${categoryNames[e.category]}'),
                        onTap: () => _showDetail(e),
                      ),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.all(8),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                          child: const Center(
                            child: Text('57–71',
                                style: TextStyle(fontSize: 7, color: Colors.black, fontWeight: FontWeight.bold)),
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
                          child: const Center(
                            child: Text('89–103',
                                style: TextStyle(fontSize: 7, color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                        );
                      }
                      return _cell(context, grid[i]);
                    },
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            '118 elementos. Toca cualquier elemento para ver su ficha: masa atómica, grupo, periodo, bloque y categoría.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

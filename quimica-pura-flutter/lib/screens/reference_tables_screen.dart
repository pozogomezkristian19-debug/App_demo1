// Tablas de referencia (v5): serie de actividad de los metales y tabla
// de solubilidad, en su propia pantalla del menú. Los mismos datos de
// siempre (lib/data/reference_tables.dart).

import 'package:flutter/material.dart';

import '../data/reference_tables.dart';
import '../services/localization.dart';

class ReferenceTablesScreen extends StatelessWidget {
  const ReferenceTablesScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('menuTables')),
          bottom: TabBar(
            tabs: [
              Tab(text: tr('tabActivity')),
              Tab(text: tr('tabSolubility')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ActivityTab(),
            _SolubilityTab(),
          ],
        ),
      ),
    );
  }
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab();

  @override
  Widget build(BuildContext context) {
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
                  '${i + 1}. ${metalActivitySeries[i].name}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(metalActivitySeries[i].reaction),
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
}

class _SolubilityTab extends StatelessWidget {
  const _SolubilityTab();

  Color _cellColor(String v) {
    switch (v) {
      case 'S':
        return Colors.green.withValues(alpha: 0.25);
      case 'I':
        return Colors.red.withValues(alpha: 0.18);
      default:
        return Colors.amber.withValues(alpha: 0.30);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                DataColumn(label: Text(c, textAlign: TextAlign.center)),
            ],
            rows: [
              for (final row in solubilityTable)
                DataRow(
                  cells: [
                    DataCell(Text('${row.anion}\n${row.name}',
                        style: const TextStyle(fontSize: 12))),
                    for (final v in row.cells)
                      DataCell(
                        Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _cellColor(v),
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

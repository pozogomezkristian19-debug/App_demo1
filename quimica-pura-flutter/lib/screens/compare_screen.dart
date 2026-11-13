// Comparar dos elementos (v5): elige dos elementos y mira sus
// propiedades lado a lado. Se abre desde Tabla y desde la búsqueda.

import 'package:flutter/material.dart';
import '../widgets/lucide_icons.dart';

import '../data/element_details.dart';
import '../data/periodic_table.dart';
import '../models.dart';
import '../services/localization.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});
  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  ChemicalElement _a = allElements[5]; // Carbono
  ChemicalElement _b = allElements[7]; // Oxígeno

  List<(String, String, String)> _rows() {
    String en(ChemicalElement e) {
      final v = electronegativity[e.atomicNumber];
      return v == null ? '—' : v.toStringAsFixed(2);
    }

    return [
      ('Símbolo', _a.symbol, _b.symbol),
      ('Número atómico (Z)', '${_a.atomicNumber}', '${_b.atomicNumber}'),
      ('Masa atómica', _a.mass, _b.mass),
      ('Categoría', categoryNames[_a.category], categoryNames[_b.category]),
      ('Periodo', '${_a.period}', '${_b.period}'),
      ('Grupo', '${_a.column}', '${_b.column}'),
      ('Bloque', _a.block, _b.block),
      ('Electronegatividad', en(_a), en(_b)),
      ('Estados de oxidación', oxidationStates[_a.atomicNumber] ?? '—',
          oxidationStates[_b.atomicNumber] ?? '—'),
      ('Configuración', electronConfig(_a.atomicNumber),
          electronConfig(_b.atomicNumber)),
      ('Estado a 25 °C', elementState(_a.atomicNumber),
          elementState(_b.atomicNumber)),
    ];
  }

  Widget _picker(String label, ChemicalElement value,
      void Function(ChemicalElement?) onChanged) {
    return Expanded(
      child: DropdownButtonFormField<ChemicalElement>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        isExpanded: true,
        items: allElements
            .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text('${e.symbol} · ${e.name}'),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('compareTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _picker('Elemento 1', _a, (v) {
                if (v != null) setState(() => _a = v);
              }),
              const SizedBox(width: 8),
              _picker('Elemento 2', _b, (v) {
                if (v != null) setState(() => _b = v);
              }),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      child: Text(_a.symbol,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20)),
                    ),
                    const SizedBox(height: 4),
                    Text(_a.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
              const LucideIcon(LucideIcons.arrowLeftRight, size: 32),
              Expanded(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      child: Text(_b.symbol,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20)),
                    ),
                    const SizedBox(height: 4),
                    Text(_b.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final (label, va, vb) in _rows())
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(va, textAlign: TextAlign.right),
                  ),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      // (foto72) La etiqueta larga ("Electronegatividad")
                      // se partía a mitad de palabra ("Electronegativ /
                      // ad") porque la columna es estrecha y la palabra
                      // no tiene espacios. Con una sola línea y
                      // scaleDown la etiqueta se achica un poco en vez
                      // de romperse; las cortas quedan igual.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: scheme.primary)),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(vb),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

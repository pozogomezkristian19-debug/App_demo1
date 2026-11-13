// Constantes y conversiones (v5): las constantes químicas más usadas
// y un conversor de unidades (longitud, masa, volumen, presión,
// energía y temperatura). Todo offline.

import 'package:flutter/material.dart';
import '../services/accent.dart';
import '../widgets/lucide_icons.dart';

import '../data/extra_content.dart';
import '../data/i18n/content_i18n.dart';
import '../services/localization.dart';

class _UnitCategory {
  const _UnitCategory({required this.name, required this.units});
  final String name;
  final List<(String, double)> units; // (nombre, factor a la unidad base)
}

const List<_UnitCategory> _categories = [
  _UnitCategory(name: 'Longitud (m)', units: [
    ('km', 1000),
    ('m', 1),
    ('cm', 0.01),
    ('mm', 0.001),
  ]),
  _UnitCategory(name: 'Masa (g)', units: [
    ('kg', 1000),
    ('g', 1),
    ('mg', 0.001),
  ]),
  _UnitCategory(name: 'Volumen (L)', units: [
    ('m³', 1000),
    ('L', 1),
    ('mL', 0.001),
  ]),
  _UnitCategory(name: 'Presión (atm)', units: [
    ('atm', 1),
    ('mmHg', 1 / 760),
    ('Pa', 1 / 101325),
    ('kPa', 100 / 101325),
  ]),
  _UnitCategory(name: 'Energía (J)', units: [
    ('kJ', 1000),
    ('J', 1),
    ('cal', 4.184),
    ('kcal', 4184),
  ]),
];

class ConstantsScreen extends StatefulWidget {
  const ConstantsScreen({super.key});
  @override
  State<ConstantsScreen> createState() => _ConstantsScreenState();
}

class _ConstantsScreenState extends State<ConstantsScreen> {
  int _catIndex = 0;
  String _from = 'm';
  String _to = 'cm';
  String _input = '';
  String? _result;
  bool _temperature = false;
  String _tempFrom = '°C';
  String _tempTo = 'K';

  void _convert() {
    final v = double.tryParse(_input.replaceAll(',', '.'));
    if (v == null) {
      setState(() => _result = null);
      return;
    }
    if (_temperature) {
      double kelvin;
      if (_tempFrom == '°C') {
        kelvin = v + 273.15;
      } else if (_tempFrom == 'K') {
        kelvin = v;
      } else {
        kelvin = (v - 32) * 5 / 9 + 273.15;
      }
      double out;
      if (_tempTo == '°C') {
        out = kelvin - 273.15;
      } else if (_tempTo == 'K') {
        out = kelvin;
      } else {
        out = (kelvin - 273.15) * 9 / 5 + 32;
      }
      setState(() => _result =
          '$v $_tempFrom = ${out.toStringAsFixed(2)} $_tempTo');
      return;
    }
    final cat = _categories[_catIndex];
    final fromFactor =
        cat.units.firstWhere((u) => u.$1 == _from, orElse: () => cat.units[1]).$2;
    final toFactor =
        cat.units.firstWhere((u) => u.$1 == _to, orElse: () => cat.units[1]).$2;
    final out = v * fromFactor / toFactor;
    setState(() => _result =
        '$v $_from = ${_format(out)} $_to');
  }

  String _format(double v) {
    if (v == 0) return '0';
    if (v.abs() >= 10000 || v.abs() < 0.001) return v.toStringAsExponential(3);
    return v.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final cat = _categories[_catIndex];
    return Scaffold(
      appBar: AppBar(title: Text(tr('menuConstants'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Constantes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final c in chemConstants)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                title: Text('${c.symbol} = ${c.value}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(localizedConstantNote(c.note)),
              ),
            ),
          const SizedBox(height: 16),
          const Text('Conversor de unidades',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < _categories.length; i++)
                ChoiceChip(
                  label: Text(_categories[i].name,
                      style: TextStyle(
                          color: !_temperature && _catIndex == i
                              ? Colors.white
                              : const Color(0xFF1F2937),
                          fontWeight: FontWeight.w700)),
                  selected: !_temperature && _catIndex == i,
                  onSelected: (_) => setState(() {
                    _temperature = false;
                    _catIndex = i;
                    _from = _categories[i].units.first.$1;
                    _to = _categories[i].units.last.$1;
                    _result = null;
                  }),
                  // Píldora 3D (ronda de diseño 7.0): color del acento + texto
                  // blanco + sombra tintada al seleccionar; blanco
                  // con sombra suave y borde gris claro sin
                  // seleccionar. Se mantiene ChoiceChip.
                  selectedColor: AppAccent.primary,
                  backgroundColor: Colors.white,
                  elevation: 3,
                  shadowColor:
                      AppAccent.primary.withValues(alpha: 0.35),
                  selectedShadowColor:
                      AppAccent.primary.withValues(alpha: 0.45),
                  checkmarkColor: Colors.white,
                  side: BorderSide(
                      color: !_temperature && _catIndex == i
                          ? AppAccent.primaryDark
                          : const Color(0xFFE8E8E8)),
                  shape: const StadiumBorder(),
                ),
              ChoiceChip(
                label: Text('Temperatura',
                    style: TextStyle(
                        color: _temperature
                            ? Colors.white
                            : const Color(0xFF1F2937),
                        fontWeight: FontWeight.w700)),
                selected: _temperature,
                onSelected: (_) => setState(() {
                  _temperature = true;
                  _result = null;
                }),
                selectedColor: AppAccent.primary,
                backgroundColor: Colors.white,
                elevation: 3,
                shadowColor:
                    AppAccent.primary.withValues(alpha: 0.35),
                selectedShadowColor:
                    AppAccent.primary.withValues(alpha: 0.45),
                checkmarkColor: Colors.white,
                side: BorderSide(
                    color: _temperature
                        ? AppAccent.primaryDark
                        : const Color(0xFFE8E8E8)),
                shape: const StadiumBorder(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Valor',
              // Fix3, punto 6 (ampliación): el icono del campo Valor
              // salía gigante en la captura (casi toda la altura del
              // campo). La causa: en la APK instalada LucideIcon aún
              // no llevaba el SizedBox de tamaño fijo y el
              // prefixIcon estiraba el CustomPaint a la altura del
              // campo. En el código actual el guard ya existe, pero
              // el tamaño se fija aquí explícito (24 px, como el
              // texto del campo) para que no vuelva a pasar.
              prefixIcon: LucideIcon(LucideIcons.logIn, size: 24),
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              _input = v;
              _convert();
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _temperature ? _tempFrom : _from,
                  decoration: const InputDecoration(labelText: 'De'),
                  items: (_temperature
                          ? ['°C', 'K', '°F']
                          : cat.units.map((u) => u.$1).toList())
                      .map((u) =>
                          DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      if (_temperature) {
                        _tempFrom = v;
                      } else {
                        _from = v;
                      }
                      _convert();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Flecha entre los desplegables De/A: 24 px explícitos,
              // acorde al texto de los desplegables (fix3, punto 6).
              const LucideIcon(LucideIcons.arrowRight, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _temperature ? _tempTo : _to,
                  decoration: const InputDecoration(labelText: 'A'),
                  items: (_temperature
                          ? ['°C', 'K', '°F']
                          : cat.units.map((u) => u.$1).toList())
                      .map((u) =>
                          DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      if (_temperature) {
                        _tempTo = v;
                      } else {
                        _to = v;
                      }
                      _convert();
                    });
                  },
                ),
              ),
            ],
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shadowColor: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.30),
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.15),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_result!,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

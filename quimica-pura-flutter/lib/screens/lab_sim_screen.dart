// Simulador de laboratorio (v5): mezcla un ácido con una base, elige
// los volúmenes y el indicador, y mira cómo cambia el color del vaso
// y cuál es el pH. Los cálculos son aproximaciones de libro
// (neutralización fuerte-fuerte exacta; tampón con Henderson-Hasselbalch;
// hidrólisis de la sal en el punto de equivalencia) y se dice cuando
// se aproxima. Todo offline.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/localization.dart';

class _Reagent {
  const _Reagent({required this.name, required this.formula, required this.strong});
  final String name;
  final String formula;
  final bool strong; // fuerte (true) o débil (false)
}

const List<_Reagent> _acids = [
  _Reagent(name: 'Ácido clorhídrico', formula: 'HCl 0.10 M', strong: true),
  _Reagent(name: 'Ácido acético', formula: 'CH₃COOH 0.10 M', strong: false),
  _Reagent(name: 'Ácido sulfúrico', formula: 'H₂SO₄ 0.05 M', strong: true),
];

const List<_Reagent> _bases = [
  _Reagent(name: 'Hidróxido de sodio', formula: 'NaOH 0.10 M', strong: true),
  _Reagent(name: 'Hidróxido de potasio', formula: 'KOH 0.10 M', strong: true),
  _Reagent(name: 'Amoníaco', formula: 'NH₃ 0.10 M', strong: false),
];

const double _kaAcetic = 1.8e-5;
const double _kbAmmonia = 1.8e-5;
const double _kw = 1.0e-14;

class LabSimScreen extends StatefulWidget {
  const LabSimScreen({super.key});
  @override
  State<LabSimScreen> createState() => _LabSimScreenState();
}

class _LabSimScreenState extends State<LabSimScreen> {
  int _acidIndex = 0;
  int _baseIndex = 0;
  double _acidVol = 50; // mL
  double _baseVol = 50; // mL
  String _indicator = 'Fenolftaleína';

  double _log10(double x) => math.log(x) / math.ln10;

  /// Devuelve (pH, explicación). Aproximaciones de libro.
  (double, String) _compute() {
    final acid = _acids[_acidIndex];
    final base = _bases[_baseIndex];
    final ca = acid.formula.contains('H₂SO₄') ? 0.05 : 0.10;
    const cb = 0.10;
    final na = ca * _acidVol / 1000; // moles de protón (H₂SO₄: primer protón)
    final nb = cb * _baseVol / 1000; // moles de OH⁻ equivalente
    final vTot = (_acidVol + _baseVol) / 1000; // L
    final note = acid.formula.contains('H₂SO₄')
        ? 'El H₂SO₄ se aproxima con su primer protón (el segundo es débil).'
        : '';

    if (acid.strong && base.strong) {
      final excess = na - nb;
      if (excess > 1e-12) {
        return (-_log10(excess / vTot), 'Queda ácido sin neutralizar. $note');
      }
      if (excess < -1e-12) {
        return (14 + _log10(-excess / vTot), 'Queda base sin neutralizar. $note');
      }
      return (7.0, 'Neutralización completa: solo queda la sal en agua. $note');
    }
    if (!acid.strong && base.strong) {
      // Acético + base fuerte.
      if (nb < na) {
        final ph = 4.74 + _log10(nb / (na - nb));
        return (ph, 'Tampón acético/acetato (Henderson-Hasselbalch).');
      }
      if ((nb - na).abs() < 1e-12) {
        final c = na / vTot;
        final oh = math.sqrt((_kw / _kaAcetic) * c);
        return (14 + _log10(oh), 'Punto de equivalencia: el acetato se hidroliza y el pH es básico.');
      }
      return (14 + _log10((nb - na) / vTot), 'La base fuerte sobra: manda el OH⁻ libre.');
    }
    if (acid.strong && !base.strong) {
      // Ácido fuerte + amoníaco.
      if (na < nb) {
        final poh = 4.74 + _log10(na / (nb - na));
        return (14 - poh, 'Tampón amonio/amoníaco (Henderson-Hasselbalch).');
      }
      if ((na - nb).abs() < 1e-12) {
        final c = nb / vTot;
        final ka = _kw / _kbAmmonia;
        final h = math.sqrt(ka * c);
        return (-_log10(h), 'Punto de equivalencia: el NH₄⁺ se hidroliza y el pH es ácido.');
      }
      return (-_log10((na - nb) / vTot), 'El ácido fuerte sobra: manda el H⁺ libre.');
    }
    // Ácido débil + base débil: aproximación del punto medio.
    return (
      7.0,
      'Ácido débil con base débil: el pH queda cerca de 7 (aproximación del punto medio entre los dos pKa).'
    );
  }

  Color _indicatorColor(double ph) {
    switch (_indicator) {
      case 'Tornasol':
        if (ph < 4.5) return const Color(0xFFE53935);
        if (ph > 8.3) return const Color(0xFF1E88E5);
        return const Color(0xFF8E24AA);
      case 'Universal':
        if (ph < 3) return const Color(0xFFD32F2F);
        if (ph < 5) return const Color(0xFFFB8C00);
        if (ph < 6) return const Color(0xFFFDD835);
        if (ph < 8) return const Color(0xFF43A047);
        if (ph < 10) return const Color(0xFF1E88E5);
        return const Color(0xFF8E24AA);
      default: // Fenolftaleína
        if (ph < 8.2) return const Color(0xFFECEFF1);
        if (ph > 10) return const Color(0xFFEC407A);
        return const Color(0xFFF48FB1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (ph, explanation) = _compute();
    final color = _indicatorColor(ph);
    final totalVol = _acidVol + _baseVol;
    final state = ph < 6.8
        ? 'Medio ácido'
        : ph > 7.2
            ? 'Medio básico'
            : 'Neutro';
    return Scaffold(
      appBar: AppBar(title: Text(tr('labSimTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Elige el ácido, la base y los volúmenes, y mira qué pasa en el vaso. El color depende del indicador y del pH.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _acidIndex,
            decoration: const InputDecoration(labelText: 'Ácido'),
            items: [
              for (var i = 0; i < _acids.length; i++)
                DropdownMenuItem(
                    value: i,
                    child: Text('${_acids[i].name} (${_acids[i].formula})')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _acidIndex = v);
            },
          ),
          const SizedBox(height: 8),
          Text('Volumen de ácido: ${_acidVol.round()} mL'),
          Slider(
            value: _acidVol,
            min: 10,
            max: 100,
            divisions: 18,
            label: '${_acidVol.round()} mL',
            onChanged: (v) => setState(() => _acidVol = v),
          ),
          DropdownButtonFormField<int>(
            initialValue: _baseIndex,
            decoration: const InputDecoration(labelText: 'Base'),
            items: [
              for (var i = 0; i < _bases.length; i++)
                DropdownMenuItem(
                    value: i,
                    child: Text('${_bases[i].name} (${_bases[i].formula})')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _baseIndex = v);
            },
          ),
          const SizedBox(height: 8),
          Text('Volumen de base: ${_baseVol.round()} mL'),
          Slider(
            value: _baseVol,
            min: 10,
            max: 100,
            divisions: 18,
            label: '${_baseVol.round()} mL',
            onChanged: (v) => setState(() => _baseVol = v),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _indicator,
            decoration: const InputDecoration(labelText: 'Indicador'),
            items: const ['Fenolftaleína', 'Tornasol', 'Universal']
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _indicator = v);
            },
          ),
          const SizedBox(height: 20),
          // El vaso: el líquido cambia de color con animación.
          Center(
            child: Container(
              width: 180,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(
                    color: Theme.of(context).colorScheme.onSurface, width: 2),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  width: 176,
                  height: 196 * (totalVol / 200),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(22)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('pH ≈ ${ph.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold)),
                  Text(state,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(explanation, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

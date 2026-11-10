// Simulador de laboratorio (v6): dos modos.
// - Ácido + base: 6 ácidos, 6 bases y 5 indicadores; elige los
//   volúmenes y mira cómo cambia el color del vaso y cuál es el pH.
// - Precipitación: 4 reacciones de precipitación (AgCl, BaSO4, PbI2,
//   CaCO3); elige los volúmenes y mira cuánto precipitado sale.
// Los cálculos son aproximaciones de libro (neutralización
// fuerte-fuerte exacta; tampón con Henderson-Hasselbalch; hidrólisis
// de la sal en el punto de equivalencia) y se dice cuando se aproxima.
// Todo offline.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/localization.dart';

class _Reagent {
  const _Reagent({
    required this.name,
    required this.formula,
    required this.strong,
    this.ka,
    this.kb,
  });
  final String name;
  final String formula;
  final bool strong; // fuerte (true) o débil (false)
  final double? ka; // ácido débil
  final double? kb; // base débil
}

const List<_Reagent> _acids = [
  _Reagent(name: 'Ácido clorhídrico', formula: 'HCl 0.10 M', strong: true),
  _Reagent(name: 'Ácido nítrico', formula: 'HNO₃ 0.10 M', strong: true),
  _Reagent(name: 'Ácido sulfúrico', formula: 'H₂SO₄ 0.05 M', strong: true),
  _Reagent(
      name: 'Ácido acético',
      formula: 'CH₃COOH 0.10 M',
      strong: false,
      ka: 1.8e-5),
  _Reagent(
      name: 'Ácido fórmico',
      formula: 'HCOOH 0.10 M',
      strong: false,
      ka: 1.8e-4),
  _Reagent(
      name: 'Ácido fluorhídrico',
      formula: 'HF 0.10 M',
      strong: false,
      ka: 6.6e-4),
];

const List<_Reagent> _bases = [
  _Reagent(name: 'Hidróxido de sodio', formula: 'NaOH 0.10 M', strong: true),
  _Reagent(
      name: 'Hidróxido de potasio', formula: 'KOH 0.10 M', strong: true),
  _Reagent(name: 'Hidróxido de litio', formula: 'LiOH 0.10 M', strong: true),
  _Reagent(
      name: 'Amoníaco',
      formula: 'NH₃ 0.10 M',
      strong: false,
      kb: 1.8e-5),
  _Reagent(
      name: 'Metilamina',
      formula: 'CH₃NH₂ 0.10 M',
      strong: false,
      kb: 4.4e-4),
  _Reagent(
      name: 'Etilamina',
      formula: 'C₂H₅NH₂ 0.10 M',
      strong: false,
      kb: 5.6e-4),
];

const List<String> _indicators = [
  'Fenolftaleína',
  'Tornasol',
  'Universal',
  'Naranja de metilo',
  'Azul de bromotimol',
];

class _PrecipReaction {
  const _PrecipReaction({
    required this.name,
    required this.sol1,
    required this.sol2,
    required this.precip,
    required this.color,
    required this.molarMass,
  });
  final String name;
  final String sol1;
  final String sol2;
  final String precip;
  final Color color;
  final double molarMass; // g/mol
}

const List<_PrecipReaction> _precipReactions = [
  _PrecipReaction(
      name: 'AgNO₃ + NaCl',
      sol1: 'AgNO₃ 0.10 M',
      sol2: 'NaCl 0.10 M',
      precip: 'AgCl',
      color: Color(0xFFF5F5F5),
      molarMass: 143.32),
  _PrecipReaction(
      name: 'BaCl₂ + Na₂SO₄',
      sol1: 'BaCl₂ 0.10 M',
      sol2: 'Na₂SO₄ 0.10 M',
      precip: 'BaSO₄',
      color: Color(0xFFECEFF1),
      molarMass: 233.39),
  _PrecipReaction(
      name: 'Pb(NO₃)₂ + KI',
      sol1: 'Pb(NO₃)₂ 0.10 M',
      sol2: 'KI 0.10 M',
      precip: 'PbI₂',
      color: Color(0xFFFDD835),
      molarMass: 461.01),
  _PrecipReaction(
      name: 'CaCl₂ + Na₂CO₃',
      sol1: 'CaCl₂ 0.10 M',
      sol2: 'Na₂CO₃ 0.10 M',
      precip: 'CaCO₃',
      color: Color(0xFFF5F5F5),
      molarMass: 100.09),
];

const double _kw = 1.0e-14;

class LabSimScreen extends StatefulWidget {
  const LabSimScreen({super.key});
  @override
  State<LabSimScreen> createState() => _LabSimScreenState();
}

class _LabSimScreenState extends State<LabSimScreen> {
  bool _precip = false;
  int _acidIndex = 0;
  int _baseIndex = 0;
  double _acidVol = 50; // mL
  double _baseVol = 50; // mL
  String _indicator = 'Fenolftaleína';
  int _precipIndex = 0;
  double _vol1 = 50; // mL
  double _vol2 = 50; // mL

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
      // Ácido débil + base fuerte (Ka propio de cada ácido).
      final ka = acid.ka ?? 1.8e-5;
      final pKa = -_log10(ka);
      if (nb < na) {
        final ph = pKa + _log10(nb / (na - nb));
        return (ph, 'Tampón ácido/débil-base (Henderson-Hasselbalch).');
      }
      if ((nb - na).abs() < 1e-12) {
        final c = na / vTot;
        final oh = math.sqrt((_kw / ka) * c);
        return (14 + _log10(oh),
            'Punto de equivalencia: la base conjugada se hidroliza y el pH es básico.');
      }
      return (14 + _log10((nb - na) / vTot), 'La base fuerte sobra: manda el OH⁻ libre.');
    }
    if (acid.strong && !base.strong) {
      // Ácido fuerte + base débil (Kb propio de cada base).
      final kb = base.kb ?? 1.8e-5;
      final pKb = -_log10(kb);
      if (na < nb) {
        final poh = pKb + _log10(na / (nb - na));
        return (14 - poh, 'Tampón ácido/base conjugada (Henderson-Hasselbalch).');
      }
      if ((na - nb).abs() < 1e-12) {
        final c = nb / vTot;
        final ka = _kw / kb;
        final h = math.sqrt(ka * c);
        return (-_log10(h),
            'Punto de equivalencia: el ácido conjugado se hidroliza y el pH es ácido.');
      }
      return (-_log10((na - nb) / vTot), 'El ácido fuerte sobra: manda el H⁺ libre.');
    }
    // Ácido débil + base débil: aproximación del punto medio.
    final ka = acid.ka ?? 1.8e-5;
    final kb = base.kb ?? 1.8e-5;
    final ph = 7 + 0.5 * (-_log10(ka) + _log10(kb));
    return (
      ph,
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
      case 'Naranja de metilo':
        if (ph < 3.1) return const Color(0xFFE53935);
        if (ph > 4.4) return const Color(0xFFFDD835);
        return const Color(0xFFFB8C00);
      case 'Azul de bromotimol':
        if (ph < 6.0) return const Color(0xFFFDD835);
        if (ph > 7.6) return const Color(0xFF1E88E5);
        return const Color(0xFF43A047);
      default: // Fenolftaleína
        if (ph < 8.2) return const Color(0xFFECEFF1);
        if (ph > 10) return const Color(0xFFEC407A);
        return const Color(0xFFF48FB1);
    }
  }

  /// Precipitación: moles de precipitado (reactivo limitante, 1:1),
  /// masa en mg y qué disolución queda en exceso (o nada).
  (double, double, String) _computePrecip() {
    final r = _precipReactions[_precipIndex];
    final n1 = 0.10 * _vol1 / 1000;
    final n2 = 0.10 * _vol2 / 1000;
    final nPrecip = math.min(n1, n2);
    final massMg = nPrecip * r.molarMass * 1000;
    String excess;
    if ((n1 - n2).abs() < 1e-12) {
      excess = 'Cantidades justas: todo precipita, no queda nada en exceso.';
    } else if (n1 < n2) {
      excess =
          'Queda ${r.sol2} en exceso: ${((n2 - n1) * 1000).toStringAsFixed(2)} mmol sin reaccionar.';
    } else {
      excess =
          'Queda ${r.sol1} en exceso: ${((n1 - n2) * 1000).toStringAsFixed(2)} mmol sin reaccionar.';
    }
    return (nPrecip, massMg, excess);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('labSimTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                  value: false, label: Text(tr('labModeAcidBase'))),
              ButtonSegment(
                  value: true, label: Text(tr('labModePrecip'))),
            ],
            selected: {_precip},
            onSelectionChanged: (s) => setState(() => _precip = s.first),
          ),
          const SizedBox(height: 16),
          if (_precip) ..._precipBody(context) else ..._acidBaseBody(context),
        ],
      ),
    );
  }

  List<Widget> _acidBaseBody(BuildContext context) {
    final (ph, explanation) = _compute();
    final color = _indicatorColor(ph);
    final totalVol = _acidVol + _baseVol;
    final state = ph < 6.8
        ? 'Medio ácido'
        : ph > 7.2
            ? 'Medio básico'
            : 'Neutro';
    return [
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
        items: _indicators
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
        color:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
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
    ];
  }

  List<Widget> _precipBody(BuildContext context) {
    final r = _precipReactions[_precipIndex];
    final (nPrecip, massMg, excess) = _computePrecip();
    final totalVol = _vol1 + _vol2;
    // La capa de precipitado crece con los moles: 0,01 mol la llena.
    final layerH = 196 * (nPrecip / 0.01).clamp(0.0, 1.0) * 0.45;
    return [
      const Text(
        'Mezcla dos disoluciones y mira cuánto precipitado sale: manda el reactivo que se acaba primero (reactivo limitante).',
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<int>(
        initialValue: _precipIndex,
        decoration: const InputDecoration(labelText: 'Reacción'),
        items: [
          for (var i = 0; i < _precipReactions.length; i++)
            DropdownMenuItem(
                value: i, child: Text(_precipReactions[i].name)),
        ],
        onChanged: (v) {
          if (v != null) setState(() => _precipIndex = v);
        },
      ),
      const SizedBox(height: 8),
      Text('Volumen de ${r.sol1}: ${_vol1.round()} mL'),
      Slider(
        value: _vol1,
        min: 10,
        max: 100,
        divisions: 18,
        label: '${_vol1.round()} mL',
        onChanged: (v) => setState(() => _vol1 = v),
      ),
      Text('Volumen de ${r.sol2}: ${_vol2.round()} mL'),
      Slider(
        value: _vol2,
        min: 10,
        max: 100,
        divisions: 18,
        label: '${_vol2.round()} mL',
        onChanged: (v) => setState(() => _vol2 = v),
      ),
      const SizedBox(height: 20),
      // El vaso: disolución clara arriba, precipitado abajo.
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
              decoration: const BoxDecoration(
                color: Color(0xFFB3E5FC),
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(22)),
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  width: 176,
                  height: layerH,
                  color: r.color,
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Card(
        color:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text('Precipitado: ${r.precip}',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                  '${(nPrecip * 1000).toStringAsFixed(2)} mmol · ${massMg.toStringAsFixed(1)} mg',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(excess, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ];
  }
}

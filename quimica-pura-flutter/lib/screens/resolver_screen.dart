import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/chemistry.dart';

class ResolverScreen extends StatelessWidget {
  const ResolverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _IntroCard(),
        SizedBox(height: 8),
        MolarMassSolver(),
        MassMolesSolver(),
        MolaritySolver(),
        DilutionSolver(),
        PhSolver(),
        GasSolver(),
        LimitingSolver(),
        SizedBox(height: 16),
      ],
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();
  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resolver problemas, paso a paso',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text(
              'Siete solucionadores que no solo dan el resultado: muestran el procedimiento completo, como lo escribirías en un examen.',
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Utilidades compartidas ----------

class _SolverCard extends StatelessWidget {
  const _SolverCard({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.steps});
  final List<String> steps;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        const Text('Procedimiento:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('${i + 1}. ${steps[i]}'),
          ),
      ],
    );
  }
}

double? _parse(TextEditingController c) {
  final v = double.tryParse(c.text.replaceAll(',', '.').trim());
  return v;
}

String _fmt(double v) {
  if (v == v.roundToDouble() && v.abs() < 1000) return v.toStringAsFixed(0);
  if (v.abs() >= 1000) return v.toStringAsExponential(2);
  if (v.abs() < 0.001 && v != 0) return v.toStringAsExponential(2);
  return v.toStringAsFixed(3);
}

// ---------- 1. Masa molar ----------

class MolarMassSolver extends StatefulWidget {
  const MolarMassSolver({super.key});
  @override
  State<MolarMassSolver> createState() => _MolarMassSolverState();
}

class _MolarMassSolverState extends State<MolarMassSolver> {
  final _formula = TextEditingController(text: 'H2SO4');
  List<String> _steps = [];
  String _error = '';

  void _calc() {
    try {
      final r = calculateMolarMass(_formula.text);
      setState(() {
        _error = '';
        _steps = [
          'Fórmula: ${_formula.text.trim()}',
          ...r.breakdown,
        ];
      });
    } on FormatException catch (e) {
      setState(() {
        _error = e.message;
        _steps = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SolverCard(
      title: 'Masa molar de un compuesto',
      subtitle: 'Escribe la fórmula (acepta paréntesis): H2SO4, Ca(OH)2, Al2(SO4)3…',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _formula,
            decoration: const InputDecoration(labelText: 'Fórmula química'),
          ),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: _calc, child: const Text('Calcular masa molar')),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error, style: const TextStyle(color: Colors.redAccent)),
            ),
          if (_steps.isNotEmpty) _Steps(steps: _steps),
        ],
      ),
    );
  }
}

// ---------- 2. Masa ⇄ moles ----------

class MassMolesSolver extends StatefulWidget {
  const MassMolesSolver({super.key});
  @override
  State<MassMolesSolver> createState() => _MassMolesSolverState();
}

class _MassMolesSolverState extends State<MassMolesSolver> {
  final _mass = TextEditingController();
  final _molar = TextEditingController();
  String _mode = 'moles';
  String _result = '';
  List<String> _steps = [];

  void _calc() {
    final m = _parse(_mass);
    final mm = _parse(_molar);
    if (mm == null || mm <= 0) {
      setState(() => _result = 'Introduce una masa molar válida (g/mol).');
      return;
    }
    if (_mode == 'moles') {
      if (m == null) {
        setState(() => _result = 'Introduce la masa en gramos.');
        return;
      }
      final n = m / mm;
      setState(() {
        _result = 'n = ${_fmt(n)} mol';
        _steps = [
          'Fórmula: n = m / M',
          'Sustitución: n = ${_fmt(m)} g ÷ ${_fmt(mm)} g/mol',
          'Resultado: n = ${_fmt(n)} mol',
        ];
      });
    } else {
      // Aquí _mass se reusa como moles en este modo.
      if (m == null) {
        setState(() => _result = 'Introduce los moles.');
        return;
      }
      final mass = m * mm;
      setState(() {
        _result = 'm = ${_fmt(mass)} g';
        _steps = [
          'Fórmula: m = n × M',
          'Sustitución: m = ${_fmt(m)} mol × ${_fmt(mm)} g/mol',
          'Resultado: m = ${_fmt(mass)} g',
        ];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SolverCard(
      title: 'Masa ⇄ moles ⇄ partículas',
      subtitle: 'n = m / M · N = n · 6.022×10²³',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButton<String>(
            value: _mode,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'moles', child: Text('Moles a partir de la masa')),
              DropdownMenuItem(value: 'masa', child: Text('Masa a partir de los moles')),
            ],
            onChanged: (v) => setState(() => _mode = v ?? 'moles'),
          ),
          _NumField(controller: _mass, label: _mode == 'moles' ? 'Masa (g)' : 'Moles (mol)'),
          _NumField(controller: _molar, label: 'Masa molar M (g/mol)'),
          ElevatedButton(onPressed: _calc, child: const Text('Calcular')),
          if (_result.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_result, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ),
          if (_steps.isNotEmpty) _Steps(steps: _steps),
        ],
      ),
    );
  }
}

// ---------- 3. Molaridad ----------

class MolaritySolver extends StatefulWidget {
  const MolaritySolver({super.key});
  @override
  State<MolaritySolver> createState() => _MolaritySolverState();
}

class _MolaritySolverState extends State<MolaritySolver> {
  final _moles = TextEditingController();
  final _vol = TextEditingController();
  String _result = '';
  List<String> _steps = [];

  void _calc() {
    final n = _parse(_moles);
    final v = _parse(_vol);
    if (n == null || v == null || v <= 0) {
      setState(() => _result = 'Introduce moles y volumen en litros (mayor que 0).');
      return;
    }
    final m = n / v;
    setState(() {
      _result = 'M = ${_fmt(m)} mol/L';
      _steps = [
        'Fórmula: M = n / V(L)',
        'Sustitución: M = ${_fmt(n)} mol ÷ ${_fmt(v)} L',
        'Resultado: M = ${_fmt(m)} mol/L',
        'Recuerda: V es el volumen de la disolución final, no del disolvente.',
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SolverCard(
      title: 'Molaridad de una disolución',
      subtitle: 'M = n / V(L)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NumField(controller: _moles, label: 'Moles de soluto (mol)'),
          _NumField(controller: _vol, label: 'Volumen (L)'),
          ElevatedButton(onPressed: _calc, child: const Text('Calcular')),
          if (_result.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_result, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ),
          if (_steps.isNotEmpty) _Steps(steps: _steps),
        ],
      ),
    );
  }
}

// ---------- 4. Dilución ----------

class DilutionSolver extends StatefulWidget {
  const DilutionSolver({super.key});
  @override
  State<DilutionSolver> createState() => _DilutionSolverState();
}

class _DilutionSolverState extends State<DilutionSolver> {
  final _c1 = TextEditingController();
  final _v1 = TextEditingController();
  final _c2 = TextEditingController();
  final _v2 = TextEditingController();
  String _result = '';
  List<String> _steps = [];

  void _calc() {
    final c1 = _parse(_c1);
    final v1 = _parse(_v1);
    final c2 = _parse(_c2);
    final v2 = _parse(_v2);
    final missing = [c1, v1, c2, v2].where((e) => e == null).length;
    if (missing != 1) {
      setState(() => _result = 'Deja vacío SOLO el dato que quieres calcular y rellena los otros tres.');
      return;
    }
    setState(() {
      if (c1 == null) {
        final r = c2! * v2! / v1!;
        _result = 'C₁ = ${_fmt(r)} mol/L';
        _steps = ['C₁V₁ = C₂V₂', 'C₁ = C₂V₂ / V₁ = ${_fmt(c2)} × ${_fmt(v2)} ÷ ${_fmt(v1)}', 'C₁ = ${_fmt(r)} mol/L'];
      } else if (v1 == null) {
        final r = c2! * v2! / c1;
        _result = 'V₁ = ${_fmt(r)} mL';
        _steps = ['C₁V₁ = C₂V₂', 'V₁ = C₂V₂ / C₁ = ${_fmt(c2)} × ${_fmt(v2)} ÷ ${_fmt(c1)}', 'V₁ = ${_fmt(r)} mL'];
      } else if (c2 == null) {
        final r = c1 * v1! / v2!;
        _result = 'C₂ = ${_fmt(r)} mol/L';
        _steps = ['C₁V₁ = C₂V₂', 'C₂ = C₁V₁ / V₂ = ${_fmt(c1)} × ${_fmt(v1)} ÷ ${_fmt(v2)}', 'C₂ = ${_fmt(r)} mol/L'];
      } else {
        final r = c1 * v1! / c2;
        _result = 'V₂ = ${_fmt(r)} mL';
        _steps = ['C₁V₁ = C₂V₂', 'V₂ = C₁V₁ / C₂ = ${_fmt(c1)} × ${_fmt(v1)} ÷ ${_fmt(c2)}', 'V₂ = ${_fmt(r)} mL'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SolverCard(
      title: 'Dilución · C₁V₁ = C₂V₂',
      subtitle: 'Deja vacío el dato que quieres calcular y rellena los otros tres.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NumField(controller: _c1, label: 'C₁ inicial (mol/L)'),
          _NumField(controller: _v1, label: 'V₁ inicial (mL)'),
          _NumField(controller: _c2, label: 'C₂ final (mol/L)'),
          _NumField(controller: _v2, label: 'V₂ final (mL)'),
          ElevatedButton(onPressed: _calc, child: const Text('Calcular el dato que falta')),
          if (_result.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_result, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ),
          if (_steps.isNotEmpty) _Steps(steps: _steps),
        ],
      ),
    );
  }
}

// ---------- 5. pH / pOH ----------

class PhSolver extends StatefulWidget {
  const PhSolver({super.key});
  @override
  State<PhSolver> createState() => _PhSolverState();
}

class _PhSolverState extends State<PhSolver> {
  final _value = TextEditingController();
  String _mode = 'h';
  String _result = '';
  List<String> _steps = [];

  void _calc() {
    final v = _parse(_value);
    if (v == null || v <= 0) {
      setState(() => _result = 'Introduce un valor mayor que 0.');
      return;
    }
    setState(() {
      if (_mode == 'h') {
        final ph = -math.log(v) / math.ln10;
        final poh = 14 - ph;
        _result = 'pH = ${ph.toStringAsFixed(2)} · pOH = ${poh.toStringAsFixed(2)}';
        _steps = [
          'Dato: [H⁺] = ${_fmt(v)} mol/L',
          'pH = −log[H⁺] = ${ph.toStringAsFixed(2)}',
          'A 25 °C: pH + pOH = 14 → pOH = ${poh.toStringAsFixed(2)}',
          ph < 7 ? 'Disolución ácida.' : (ph > 7 ? 'Disolución básica.' : 'Disolución neutra.'),
        ];
      } else if (_mode == 'ph') {
        final h = math.pow(10, -v).toDouble();
        _result = '[H⁺] = ${_fmt(h)} mol/L · pOH = ${(14 - v).toStringAsFixed(2)}';
        _steps = [
          'Dato: pH = ${_fmt(v)}',
          '[H⁺] = 10^(−pH) = ${_fmt(h)} mol/L',
          'pOH = 14 − pH = ${(14 - v).toStringAsFixed(2)}',
        ];
      } else {
        final oh = v;
        final poh = -math.log(oh) / math.ln10;
        final ph = 14 - poh;
        _result = 'pOH = ${poh.toStringAsFixed(2)} · pH = ${ph.toStringAsFixed(2)}';
        _steps = [
          'Dato: [OH⁻] = ${_fmt(oh)} mol/L',
          'pOH = −log[OH⁻] = ${poh.toStringAsFixed(2)}',
          'pH = 14 − pOH = ${ph.toStringAsFixed(2)}',
        ];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SolverCard(
      title: 'pH y pOH (a 25 °C)',
      subtitle: 'Puedes escribir la concentración como 0.001 o como 1e-3.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButton<String>(
            value: _mode,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'h', child: Text('Concentración [H⁺] (mol/L)')),
              DropdownMenuItem(value: 'ph', child: Text('pH')),
              DropdownMenuItem(value: 'oh', child: Text('Concentración [OH⁻] (mol/L)')),
            ],
            onChanged: (v) => setState(() => _mode = v ?? 'h'),
          ),
          _NumField(controller: _value, label: 'Valor'),
          ElevatedButton(onPressed: _calc, child: const Text('Calcular pH y pOH')),
          if (_result.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_result, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ),
          if (_steps.isNotEmpty) _Steps(steps: _steps),
        ],
      ),
    );
  }
}

// ---------- 6. Gas ideal ----------

class GasSolver extends StatefulWidget {
  const GasSolver({super.key});
  @override
  State<GasSolver> createState() => _GasSolverState();
}

class _GasSolverState extends State<GasSolver> {
  final _p = TextEditingController();
  final _v = TextEditingController();
  final _n = TextEditingController();
  final _t = TextEditingController();
  String _mode = 'V';
  String _result = '';
  List<String> _steps = [];
  static const double _r = 0.08206;

  void _calc() {
    final p = _parse(_p);
    final v = _parse(_v);
    final n = _parse(_n);
    final t = _parse(_t);
    setState(() {
      if (_mode == 'P') {
        if (v == null || n == null || t == null || v == 0) {
          _result = 'Introduce V, n y T (en kelvin).';
          return;
        }
        final r = n * _r * t / v;
        _result = 'P = ${_fmt(r)} atm';
        _steps = ['PV = nRT → P = nRT / V', 'P = ${_fmt(n)} × 0.08206 × ${_fmt(t)} ÷ ${_fmt(v)}', 'P = ${_fmt(r)} atm'];
      } else if (_mode == 'V') {
        if (p == null || n == null || t == null || p == 0) {
          _result = 'Introduce P, n y T (en kelvin).';
          return;
        }
        final r = n * _r * t / p;
        _result = 'V = ${_fmt(r)} L';
        _steps = ['PV = nRT → V = nRT / P', 'V = ${_fmt(n)} × 0.08206 × ${_fmt(t)} ÷ ${_fmt(p)}', 'V = ${_fmt(r)} L'];
      } else if (_mode == 'n') {
        if (p == null || v == null || t == null || t == 0) {
          _result = 'Introduce P, V y T (en kelvin).';
          return;
        }
        final r = p * v / (_r * t);
        _result = 'n = ${_fmt(r)} mol';
        _steps = ['PV = nRT → n = PV / RT', 'n = ${_fmt(p)} × ${_fmt(v)} ÷ (0.08206 × ${_fmt(t)})', 'n = ${_fmt(r)} mol'];
      } else {
        if (p == null || v == null || n == null || n == 0) {
          _result = 'Introduce P, V y n.';
          return;
        }
        final r = p * v / (_r * n);
        _result = 'T = ${_fmt(r)} K (${(r - 273.15).toStringAsFixed(1)} °C)';
        _steps = ['PV = nRT → T = PV / nR', 'T = ${_fmt(p)} × ${_fmt(v)} ÷ (0.08206 × ${_fmt(n)})', 'T = ${_fmt(r)} K'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SolverCard(
      title: 'Gas ideal · PV = nRT',
      subtitle: 'R = 0,08206 L·atm·mol⁻¹·K⁻¹. La temperatura siempre en kelvin (K = °C + 273,15).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButton<String>(
            value: _mode,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'P', child: Text('Calcular presión P (atm)')),
              DropdownMenuItem(value: 'V', child: Text('Calcular volumen V (L)')),
              DropdownMenuItem(value: 'n', child: Text('Calcular moles n (mol)')),
              DropdownMenuItem(value: 'T', child: Text('Calcular temperatura T (K)')),
            ],
            onChanged: (v) => setState(() => _mode = v ?? 'V'),
          ),
          _NumField(controller: _p, label: 'Presión P (atm)'),
          _NumField(controller: _v, label: 'Volumen V (L)'),
          _NumField(controller: _n, label: 'Moles n (mol)'),
          _NumField(controller: _t, label: 'Temperatura T (K)'),
          ElevatedButton(onPressed: _calc, child: const Text('Calcular')),
          if (_result.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_result, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ),
          if (_steps.isNotEmpty) _Steps(steps: _steps),
        ],
      ),
    );
  }
}

// ---------- 7. Reactivo limitante ----------

class LimitingSolver extends StatefulWidget {
  const LimitingSolver({super.key});
  @override
  State<LimitingSolver> createState() => _LimitingSolverState();
}

class _LimitingSolverState extends State<LimitingSolver> {
  final _ca = TextEditingController();
  final _na = TextEditingController();
  final _cb = TextEditingController();
  final _nb = TextEditingController();
  String _result = '';
  List<String> _steps = [];

  void _calc() {
    final ca = _parse(_ca);
    final na = _parse(_na);
    final cb = _parse(_cb);
    final nb = _parse(_nb);
    if (ca == null || na == null || cb == null || nb == null || ca <= 0 || cb <= 0) {
      setState(() => _result = 'Introduce coeficientes y moles válidos (mayores que 0).');
      return;
    }
    final qa = na / ca;
    final qb = nb / cb;
    setState(() {
      _steps = [
        'No compares moles a secas: divide moles entre coeficiente.',
        'Cociente A: ${_fmt(na)} ÷ ${_fmt(ca)} = ${_fmt(qa)}',
        'Cociente B: ${_fmt(nb)} ÷ ${_fmt(cb)} = ${_fmt(qb)}',
        'El cociente menor es el limitante: es el que da menos producto.',
      ];
      if (qa < qb) {
        _result = 'Limitante: A (cociente ${_fmt(qa)} < ${_fmt(qb)})';
      } else if (qb < qa) {
        _result = 'Limitante: B (cociente ${_fmt(qb)} < ${_fmt(qa)})';
      } else {
        _result = 'Ambos se agotan a la vez: mezcla estequiométrica.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SolverCard(
      title: 'Reactivo limitante',
      subtitle: 'Para una reacción a·A + b·B → productos. Introduce los coeficientes de la ecuación ajustada y los moles de partida.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NumField(controller: _ca, label: 'Coeficiente de A (a)'),
          _NumField(controller: _na, label: 'Moles de A'),
          _NumField(controller: _cb, label: 'Coeficiente de B (b)'),
          _NumField(controller: _nb, label: 'Moles de B'),
          ElevatedButton(onPressed: _calc, child: const Text('Encontrar el limitante')),
          if (_result.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_result, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ),
          if (_steps.isNotEmpty) _Steps(steps: _steps),
        ],
      ),
    );
  }
}

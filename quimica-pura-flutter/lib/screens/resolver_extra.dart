// Solucionadores nuevos de Melli-Qui v4: redox, pH poliprótico, mezclas,
// solubilidad/Ksp, pH de sales y valoraciones. La matemática vive en
// lib/services/advanced_solvers.dart (probada con valores conocidos).

import 'package:flutter/material.dart';
import '../services/advanced_solvers.dart';
import '../data/i18n/content_i18n.dart';
import '../services/localization.dart';
import '../widgets/solver_widgets.dart';

// ---------- Balanceo redox por semirreacciones ----------

class RedoxSolver extends StatefulWidget {
  const RedoxSolver({super.key});
  @override
  State<RedoxSolver> createState() => _RedoxSolverState();
}

class _RedoxSolverState extends State<RedoxSolver> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final r = redoxReactions[_index];
    return SolverCard(
      title: 'Balanceo redox (ion-electrón)',
      subtitle: 'Elige una reacción frecuente y mira el balanceo por semirreacciones.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButton<int>(
            value: _index,
            isExpanded: true,
            items: [
              for (var i = 0; i < redoxReactions.length; i++)
                DropdownMenuItem(value: i, child: Text(redoxReactions[i].name)),
            ],
            onChanged: (v) => setState(() => _index = v ?? 0),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(r.equation,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          Text('Oxidación: ${r.oxidation}'),
          const SizedBox(height: 4),
          Text('Reducción: ${r.reduction}'),
          Steps(steps: r.steps),
        ],
      ),
    );
  }
}

// ---------- pH de ácidos polipróticos ----------

class PolyproticPhSolver extends StatefulWidget {
  const PolyproticPhSolver({super.key});
  @override
  State<PolyproticPhSolver> createState() => _PolyproticPhSolverState();
}

class _PolyproticPhSolverState extends State<PolyproticPhSolver> {
  final _c = TextEditingController(text: '0.1');
  final _ka1 = TextEditingController(text: '4.3e-7');
  final _ka2 = TextEditingController(text: '5.6e-11');
  final _ka3 = TextEditingController(text: '4.8e-13');
  bool _triprotic = false;
  SolverResult? _result;

  void _calc() {
    final c = parseNum(_c);
    final ka1 = parseNum(_ka1);
    final ka2 = parseNum(_ka2);
    final ka3 = _triprotic ? parseNum(_ka3) : null;
    if (c == null || ka1 == null || ka2 == null) {
      setState(() => _result = const SolverResult(
          lines: [],
          summary: '',
          error: 'Introduce la concentración y las Ka (usa punto o coma decimal; la notación 4.3e-7 vale).'));
      return;
    }
    setState(() => _result =
        polyproticPh(c: c, ka1: ka1, ka2: ka2, ka3: ka3));
  }

  @override
  Widget build(BuildContext context) {
    return SolverCard(
      title: 'pH de ácidos polipróticos',
      subtitle: 'Dipróticos (H₂CO₃, H₂SO₄) y tripróticos (H₃PO₄), por aproximación por etapas.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NumField(controller: _c, label: 'Concentración del ácido (mol/L)'),
          NumField(controller: _ka1, label: 'Ka₁ (primera disociación)'),
          NumField(controller: _ka2, label: 'Ka₂ (segunda disociación)'),
          SwitchListTile(
            title: Text(localizedSolverString('Ácido triprótico (tercera etapa)')),
            value: _triprotic,
            onChanged: (v) => setState(() => _triprotic = v),
          ),
          if (_triprotic)
            NumField(controller: _ka3, label: 'Ka₃ (tercera disociación)'),
          ElevatedButton(onPressed: _calc, child: Text(tr('calculate'))),
          if (_result != null) SolverResultView(result: _result!),
        ],
      ),
    );
  }
}

// ---------- pH de mezclas de dos ácidos o dos bases ----------

class MixturePhSolver extends StatefulWidget {
  const MixturePhSolver({super.key});
  @override
  State<MixturePhSolver> createState() => _MixturePhSolverState();
}

class _MixtureComponentForm extends StatelessWidget {
  const _MixtureComponentForm({
    required this.title,
    required this.kind,
    required this.onKind,
    required this.c,
    required this.k,
  });
  final String title;
  final MixtureKind kind;
  final ValueChanged<MixtureKind> onKind;
  final TextEditingController c;
  final TextEditingController k;

  @override
  Widget build(BuildContext context) {
    const kinds = [
      (MixtureKind.strongAcid, 'Ácido fuerte'),
      (MixtureKind.weakAcid, 'Ácido débil'),
      (MixtureKind.strongBase, 'Base fuerte'),
      (MixtureKind.weakBase, 'Base débil'),
    ];
    final isWeak =
        kind == MixtureKind.weakAcid || kind == MixtureKind.weakBase;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        DropdownButton<MixtureKind>(
          value: kind,
          isExpanded: true,
          items: [
            for (final (value, label) in kinds)
              DropdownMenuItem(value: value, child: Text(label)),
          ],
          onChanged: (v) {
            if (v != null) onKind(v);
          },
        ),
        const SizedBox(height: 6),
        NumField(controller: c, label: 'Concentración (mol/L)'),
        if (isWeak)
          NumField(
              controller: k,
              label: kind == MixtureKind.weakAcid
                  ? 'Ka del ácido débil'
                  : 'Kb de la base débil'),
      ],
    );
  }
}

class _MixturePhSolverState extends State<MixturePhSolver> {
  var _kindA = MixtureKind.strongAcid;
  var _kindB = MixtureKind.strongAcid;
  final _cA = TextEditingController(text: '0.01');
  final _kA = TextEditingController();
  final _cB = TextEditingController(text: '0.01');
  final _kB = TextEditingController();
  SolverResult? _result;

  void _calc() {
    final cA = parseNum(_cA);
    final cB = parseNum(_cB);
    if (cA == null || cB == null) {
      setState(() => _result = const SolverResult(
          lines: [], summary: '', error: 'Introduce las dos concentraciones.'));
      return;
    }
    setState(() => _result = mixturePh(
          MixtureComponent(kind: _kindA, c: cA, k: parseNum(_kA)),
          MixtureComponent(kind: _kindB, c: cB, k: parseNum(_kB)),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return SolverCard(
      title: 'pH de mezclas que no reaccionan',
      subtitle: 'Dos ácidos o dos bases (fuertes o débiles, de igual o distinta fuerza).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MixtureComponentForm(
            title: 'Componente 1',
            kind: _kindA,
            onKind: (v) => setState(() => _kindA = v),
            c: _cA,
            k: _kA,
          ),
          const SizedBox(height: 8),
          _MixtureComponentForm(
            title: 'Componente 2',
            kind: _kindB,
            onKind: (v) => setState(() => _kindB = v),
            c: _cB,
            k: _kB,
          ),
          ElevatedButton(onPressed: _calc, child: Text(tr('calculate'))),
          if (_result != null) SolverResultView(result: _result!),
        ],
      ),
    );
  }
}

// ---------- Solubilidad y Ksp ----------

class SolubilitySolver extends StatefulWidget {
  const SolubilitySolver({super.key});
  @override
  State<SolubilitySolver> createState() => _SolubilitySolverState();
}

class _SolubilitySolverState extends State<SolubilitySolver> {
  bool _fromKsp = true;
  final _ksp = TextEditingController(text: '1.8e-10');
  final _s = TextEditingController(text: '1.34e-5');
  int _a = 1;
  int _b = 1;
  SolverResult? _result;

  void _calc() {
    if (_fromKsp) {
      final ksp = parseNum(_ksp);
      if (ksp == null) {
        setState(() => _result = const SolverResult(
            lines: [], summary: '', error: 'Introduce un Ksp válido.'));
        return;
      }
      setState(() => _result = solubilityFromKsp(ksp: ksp, a: _a, b: _b));
    } else {
      final s = parseNum(_s);
      if (s == null) {
        setState(() => _result = const SolverResult(
            lines: [],
            summary: '',
            error: 'Introduce una solubilidad válida (mol/L).'));
        return;
      }
      setState(() => _result = kspFromSolubility(s: s, a: _a, b: _b));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SolverCard(
      title: 'Solubilidad y Ksp',
      subtitle: 'De Ksp a solubilidad, o de solubilidad a Ksp, para sales AₐB_b.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButton<bool>(
            value: _fromKsp,
            isExpanded: true,
            items: [
              DropdownMenuItem(
                  value: true, child: Text(localizedSolverString('Solubilidad a partir de Ksp'))),
              DropdownMenuItem(
                  value: false, child: Text(localizedSolverString('Ksp a partir de la solubilidad'))),
            ],
            onChanged: (v) => setState(() => _fromKsp = v ?? true),
          ),
          const SizedBox(height: 6),
          if (_fromKsp)
            NumField(controller: _ksp, label: 'Ksp de la sal')
          else
            NumField(controller: _s, label: 'Solubilidad s (mol/L)'),
          Row(
            children: [
              Expanded(
                child: DropdownButton<int>(
                  value: _a,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(value: 1, child: Text(localizedSolverString('a = 1 (catión)'))),
                    DropdownMenuItem(value: 2, child: Text(localizedSolverString('a = 2 (catión)'))),
                    DropdownMenuItem(value: 3, child: Text(localizedSolverString('a = 3 (catión)'))),
                  ],
                  onChanged: (v) => setState(() => _a = v ?? 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<int>(
                  value: _b,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(value: 1, child: Text(localizedSolverString('b = 1 (anión)'))),
                    DropdownMenuItem(value: 2, child: Text(localizedSolverString('b = 2 (anión)'))),
                    DropdownMenuItem(value: 3, child: Text(localizedSolverString('b = 3 (anión)'))),
                  ],
                  onChanged: (v) => setState(() => _b = v ?? 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
              'Ejemplos: AgCl es AB (a = 1, b = 1); CaF₂ es AB₂ (a = 1, b = 2); Al₂(SO₄)₃ es A₂B₃.'),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: _calc, child: Text(tr('calculate'))),
          if (_result != null) SolverResultView(result: _result!),
        ],
      ),
    );
  }
}

// ---------- pH de disoluciones de sales (hidrólisis) ----------

class SaltPhSolver extends StatefulWidget {
  const SaltPhSolver({super.key});
  @override
  State<SaltPhSolver> createState() => _SaltPhSolverState();
}

class _SaltPhSolverState extends State<SaltPhSolver> {
  var _kind = SaltKind.basic;
  final _c = TextEditingController(text: '0.1');
  final _ka = TextEditingController(text: '1.8e-5');
  final _kb = TextEditingController();
  // Ka del HCO₃⁻ por defecto: dan pH 8.34, el ejemplo de los libros.
  final _ka1Amp = TextEditingController(text: '4.5e-7');
  final _ka2Amp = TextEditingController(text: '4.7e-11');
  SolverResult? _result;

  void _calc() {
    final c = parseNum(_c);
    if (c == null) {
      setState(() => _result = const SolverResult(
          lines: [], summary: '', error: 'Introduce la concentración.'));
      return;
    }
    setState(() => _result = saltPh(
          kind: _kind,
          c: c,
          ka: _kind == SaltKind.amphiproticAnion
              ? parseNum(_ka1Amp)
              : parseNum(_ka),
          kb: parseNum(_kb),
          ka2: _kind == SaltKind.amphiproticAnion
              ? parseNum(_ka2Amp)
              : null,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return SolverCard(
      title: 'pH de disoluciones de sales',
      subtitle: 'Con o sin hidrólisis: el pH depende de dónde venga la sal.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButton<SaltKind>(
            value: _kind,
            isExpanded: true,
            items: [
              DropdownMenuItem(
                  value: SaltKind.neutral,
                  child: Text(localizedSolverString('Ácido fuerte + base fuerte (neutra)'))),
              DropdownMenuItem(
                  value: SaltKind.acidic,
                  child: Text(localizedSolverString('Ácido fuerte + base débil (ácida)'))),
              DropdownMenuItem(
                  value: SaltKind.basic,
                  child: Text(localizedSolverString('Ácido débil + base fuerte (básica)'))),
              DropdownMenuItem(
                  value: SaltKind.amphoteric,
                  child: Text(localizedSolverString('Ácido débil + base débil (comparar Ka y Kb)'))),
              DropdownMenuItem(
                  value: SaltKind.amphiproticAnion,
                  child: Text(localizedSolverString('Anión anfiprótico (HCO₃⁻, H₂PO₄⁻)'))),
            ],
            onChanged: (v) => setState(() => _kind = v ?? SaltKind.basic),
          ),
          const SizedBox(height: 6),
          NumField(controller: _c, label: 'Concentración de la sal (mol/L)'),
          if (_kind == SaltKind.amphiproticAnion) ...[
            NumField(controller: _ka1Amp, label: 'Ka₁ del ácido conjugado (H₂CO₃: 4.5×10⁻⁷)'),
            NumField(controller: _ka2Amp, label: 'Ka₂ del anión (HCO₃⁻: 4.7×10⁻¹¹)'),
          ],
          if (_kind == SaltKind.acidic || _kind == SaltKind.amphoteric)
            NumField(controller: _ka, label: 'Ka del catión ácido'),
          if (_kind == SaltKind.basic)
            NumField(
                controller: _ka,
                label: 'Ka del ácido conjugado (para hallar Kb)'),
          if (_kind == SaltKind.basic)
            NumField(
                controller: _kb,
                label: 'Kb del anión (opcional si diste la Ka)'),
          if (_kind == SaltKind.amphoteric)
            NumField(controller: _kb, label: 'Kb del anión básico'),
          const Text(
              'Ejemplos: NH₄Cl (ácida, Ka = 5.6×10⁻¹⁰) · CH₃COONa (básica, Ka del acético = 1.8×10⁻⁵) · NaCl (neutra) · NaHCO₃ (anfiprótico, Ka₁ = 4.5×10⁻⁷, Ka₂ = 4.7×10⁻¹¹).'),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: _calc, child: Text(tr('calculate'))),
          if (_result != null) SolverResultView(result: _result!),
        ],
      ),
    );
  }
}

// ---------- Valoraciones: ácido-base, redox y por retroceso ----------

class TitrationSolver extends StatefulWidget {
  const TitrationSolver({super.key});
  @override
  State<TitrationSolver> createState() => _TitrationSolverState();
}

enum _TitrationMode { strongStrong, weakStrong, redox, back }

class _TitrationSolverState extends State<TitrationSolver> {
  var _mode = _TitrationMode.strongStrong;
  final _ca = TextEditingController(text: '0.1');
  final _va = TextEditingController(text: '25');
  final _ka = TextEditingController(text: '1.8e-5');
  final _cb = TextEditingController(text: '0.1');
  final _vb = TextEditingController(text: '25');
  final _mass = TextEditingController(text: '0.5');
  final _molarMass = TextEditingController(text: '100.09');
  final _cHcl = TextEditingController(text: '0.5');
  final _vHcl = TextEditingController(text: '50');
  final _cNaoh = TextEditingController(text: '0.5');
  final _vNaoh = TextEditingController(text: '31');
  int _hclPerAnalyte = 2;
  SolverResult? _result;

  void _calc() {
    switch (_mode) {
      case _TitrationMode.strongStrong:
        final ca = parseNum(_ca);
        final va = parseNum(_va);
        final cb = parseNum(_cb);
        final vb = parseNum(_vb);
        if (ca == null || va == null || cb == null || vb == null) {
          setState(() => _result = const SolverResult(
              lines: [],
              summary: '',
              error: 'Introduce las concentraciones y los volúmenes.'));
          return;
        }
        setState(() => _result =
            titrationStrongStrong(ca: ca, vaMl: va, cb: cb, vbMl: vb));
      case _TitrationMode.weakStrong:
        final ca = parseNum(_ca);
        final va = parseNum(_va);
        final ka = parseNum(_ka);
        final cb = parseNum(_cb);
        final vb = parseNum(_vb);
        if (ca == null || va == null || ka == null || cb == null || vb == null) {
          setState(() => _result = const SolverResult(
              lines: [],
              summary: '',
              error: 'Introduce las concentraciones, la Ka y los volúmenes.'));
          return;
        }
        setState(() => _result = titrationWeakStrong(
            ca: ca, vaMl: va, ka: ka, cb: cb, vbMl: vb));
      case _TitrationMode.redox:
        // _ca/_va = Fe²⁺; _cb = KMnO₄; _vb = volumen añadido.
        final cFe = parseNum(_ca);
        final vFe = parseNum(_va);
        final cMn = parseNum(_cb);
        final vAdded = parseNum(_vb);
        if (cFe == null || vFe == null || cMn == null || vAdded == null) {
          setState(() => _result = const SolverResult(
              lines: [],
              summary: '',
              error: 'Introduce las concentraciones y los volúmenes.'));
          return;
        }
        setState(() => _result = titrationRedox(
            cFe: cFe, vFeMl: vFe, cMnO4: cMn, vAddedMl: vAdded));
      case _TitrationMode.back:
        final mass = parseNum(_mass);
        final mm = parseNum(_molarMass);
        final cHcl = parseNum(_cHcl);
        final vHcl = parseNum(_vHcl);
        final cNaoh = parseNum(_cNaoh);
        final vNaoh = parseNum(_vNaoh);
        if (mass == null ||
            mm == null ||
            cHcl == null ||
            vHcl == null ||
            cNaoh == null ||
            vNaoh == null) {
          setState(() => _result = const SolverResult(
              lines: [],
              summary: '',
              error: 'Introduce la masa y todos los datos de la valoración.'));
          return;
        }
        setState(() => _result = backTitration(
              sampleMassG: mass,
              molarMass: mm,
              cHcl: cHcl,
              vHclMl: vHcl,
              cNaoh: cNaoh,
              vNaohMl: vNaoh,
              hclPerAnalyte: _hclPerAnalyte.toDouble(),
            ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SolverCard(
      title: 'Valoraciones',
      subtitle: 'Ácido-base (fuerte-fuerte y débil-fuerte), redox y por retroceso.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButton<_TitrationMode>(
            value: _mode,
            isExpanded: true,
            items: [
              DropdownMenuItem(
                  value: _TitrationMode.strongStrong,
                  child: Text(localizedSolverString('Ácido-base fuerte-fuerte'))),
              DropdownMenuItem(
                  value: _TitrationMode.weakStrong,
                  child: Text(localizedSolverString('Ácido-base débil-fuerte'))),
              DropdownMenuItem(
                  value: _TitrationMode.redox,
                  child: Text(localizedSolverString('Redox (KMnO₄ con Fe²⁺)'))),
              DropdownMenuItem(
                  value: _TitrationMode.back,
                  child: Text(localizedSolverString('Por retroceso (exceso + retitulación)'))),
            ],
            onChanged: (v) => setState(() => _mode = v ?? _mode),
          ),
          const SizedBox(height: 6),
          if (_mode == _TitrationMode.back) ...[
            NumField(controller: _mass, label: 'Masa de la muestra (g)'),
            NumField(
                controller: _molarMass,
                label: 'Masa molar del analito (g/mol)'),
            NumField(controller: _cHcl, label: 'Concentración del HCl (mol/L)'),
            NumField(
                controller: _vHcl, label: 'Volumen de HCl añadido (mL)'),
            NumField(
                controller: _cNaoh, label: 'Concentración del NaOH (mol/L)'),
            NumField(
                controller: _vNaoh,
                label: 'Volumen de NaOH gastado (mL)'),
            DropdownButton<int>(
              value: _hclPerAnalyte,
              isExpanded: true,
              items: [
                DropdownMenuItem(
                    value: 1, child: Text(localizedSolverString('1 mol de HCl por mol de analito'))),
                DropdownMenuItem(
                    value: 2, child: Text(localizedSolverString('2 mol de HCl por mol de analito'))),
              ],
              onChanged: (v) => setState(() => _hclPerAnalyte = v ?? 2),
            ),
          ] else if (_mode == _TitrationMode.redox) ...[
            NumField(controller: _ca, label: 'Concentración de Fe²⁺ (mol/L)'),
            NumField(controller: _va, label: 'Volumen de Fe²⁺ (mL)'),
            NumField(controller: _cb, label: 'Concentración de KMnO₄ (mol/L)'),
            NumField(
                controller: _vb, label: 'Volumen de KMnO₄ añadido (mL)'),
          ] else ...[
            NumField(controller: _ca, label: 'Concentración del ácido (mol/L)'),
            NumField(controller: _va, label: 'Volumen del ácido (mL)'),
            if (_mode == _TitrationMode.weakStrong)
              NumField(controller: _ka, label: 'Ka del ácido débil'),
            NumField(controller: _cb, label: 'Concentración de la base (mol/L)'),
            NumField(
                controller: _vb, label: 'Volumen de base añadido (mL)'),
          ],
          ElevatedButton(onPressed: _calc, child: Text(tr('calculate'))),
          if (_result != null) SolverResultView(result: _result!),
        ],
      ),
    );
  }
}

// ---------- Valoración potenciométrica ----------

class PotentiometricSolver extends StatefulWidget {
  const PotentiometricSolver({super.key});
  @override
  State<PotentiometricSolver> createState() => _PotentiometricSolverState();
}

class _PotentiometricSolverState extends State<PotentiometricSolver> {
  final _volumes = TextEditingController(text: '0, 10, 20, 24, 24.9, 25, 25.1, 26, 30');
  final _ph = TextEditingController(text: '1.0, 1.2, 1.5, 2.0, 3.0, 7.0, 11.0, 11.5, 12.0');
  SolverResult? _result;

  // Acepta punto o coma decimal ("24,9" es 24.9, no 24 y 9): se
  // buscan los números y lo que queda solo pueden ser separadores
  // (comas, punto y coma o espacios). Un carácter raro invalida la
  // lista en vez de corromper los datos en silencio.
  List<double>? _parseList(TextEditingController c) {
    final text = c.text;
    final number = RegExp(r'-?\d+(?:[.,]\d+)?(?:[eE][+-]?\d+)?');
    final out = <double>[];
    for (final m in number.allMatches(text)) {
      final v = double.tryParse(m.group(0)!.replaceAll(',', '.'));
      if (v == null) return null;
      out.add(v);
    }
    final rest = text
        .replaceAll(number, '')
        .replaceAll(RegExp(r'[\s,;]+'), '');
    if (out.isEmpty || rest.isNotEmpty) return null;
    return out;
  }

  void _calc() {
    final volumes = _parseList(_volumes);
    final ph = _parseList(_ph);
    if (volumes == null || ph == null) {
      setState(() => _result = const SolverResult(
          lines: [],
          summary: '',
          error: 'Escribe los números separados por comas (vale punto o coma decimal, p. ej. 24,9).'));
      return;
    }
    setState(() => _result = potentiometric(volumesMl: volumes, ph: ph));
  }

  @override
  Widget build(BuildContext context) {
    return SolverCard(
      title: 'Valoración potenciométrica',
      subtitle: 'El punto de equivalencia es donde el pH cambia más rápido (máximo de ΔpH/ΔV).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _volumes,
            keyboardType: TextInputType.text,
            style: const TextStyle(fontSize: 17),
            decoration: const InputDecoration(
              labelText: 'Volúmenes añadidos (mL), separados por comas',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ph,
            keyboardType: TextInputType.text,
            style: const TextStyle(fontSize: 17),
            decoration: const InputDecoration(
              labelText: 'pH medido, separados por comas',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: _calc, child: Text(tr('calculate'))),
          if (_result != null) SolverResultView(result: _result!),
        ],
      ),
    );
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/lucide_icons.dart';
import '../data/i18n/content_i18n.dart';
import '../services/chemistry.dart';
import '../services/localization.dart';
import '../services/nav_requests.dart';
import '../services/sound_service.dart';
import '../widgets/brand_logo.dart';
import '../widgets/solver_widgets.dart';
import 'resolver_extra.dart';

/// Un solucionador de la lista: su grupo, su título, su descripción,
/// su icono y su pantalla.
class SolverEntry {
  const SolverEntry({
    required this.id,
    required this.group,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.page,
  });
  final String id;
  final String group;
  final String title;
  final String subtitle;
  final LucideIconData icon;
  final Widget page;
}

/// Los 14 solucionadores, agrupados. Solo se abre uno a la vez: la lista
/// es limpia y el solucionador abierto tiene todo el espacio.
const List<SolverEntry> solverEntries = [
  SolverEntry(
    id: 'molar-mass',
    group: 'Cantidad de sustancia',
    title: 'Masa molar de un compuesto',
    subtitle: 'Escribe la fórmula (acepta paréntesis): H2SO4, Ca(OH)2, Al2(SO4)3…',
    icon: LucideIcons.flaskConical,
    page: MolarMassSolver(),
  ),
  SolverEntry(
    id: 'mass-moles',
    group: 'Cantidad de sustancia',
    title: 'Masa ⇄ moles ⇄ partículas',
    subtitle: 'n = m / M · N = n · 6.022×10²³',
    icon: LucideIcons.sigma,
    page: MassMolesSolver(),
  ),
  SolverEntry(
    id: 'molarity',
    group: 'Disoluciones',
    title: 'Molaridad',
    subtitle: 'Concentración: M = n / V',
    icon: LucideIcons.droplet,
    page: MolaritySolver(),
  ),
  SolverEntry(
    id: 'dilution',
    group: 'Disoluciones',
    title: 'Dilución',
    subtitle: 'M₁V₁ = M₂V₂: cómo preparar una disolución más diluida',
    icon: LucideIcons.droplet,
    page: DilutionSolver(),
  ),
  SolverEntry(
    id: 'ph',
    group: 'Ácidos y bases',
    title: 'pH y pOH',
    subtitle: 'Acidez y basicidad de disoluciones fuertes',
    icon: LucideIcons.droplet,
    page: PhSolver(),
  ),
  SolverEntry(
    id: 'polyprotic-ph',
    group: 'Ácidos y bases',
    title: 'pH de ácidos polipróticos',
    subtitle: 'Dipróticos y tripróticos, por etapas (H₂CO₃, H₂SO₄, H₃PO₄)',
    icon: LucideIcons.layers,
    page: PolyproticPhSolver(),
  ),
  SolverEntry(
    id: 'mixture-ph',
    group: 'Ácidos y bases',
    title: 'pH de mezclas que no reaccionan',
    subtitle: 'Dos ácidos o dos bases, fuertes o débiles',
    icon: LucideIcons.gitMerge,
    page: MixturePhSolver(),
  ),
  SolverEntry(
    id: 'salt-ph',
    group: 'Ácidos y bases',
    title: 'pH de disoluciones de sales',
    subtitle: 'Con o sin hidrólisis, según de dónde venga la sal',
    icon: LucideIcons.hexagon,
    page: SaltPhSolver(),
  ),
  SolverEntry(
    id: 'solubility',
    group: 'Equilibrio',
    title: 'Solubilidad y Ksp',
    subtitle: 'De Ksp a solubilidad, o de solubilidad a Ksp (AₐB_b)',
    icon: LucideIcons.scale,
    page: SolubilitySolver(),
  ),
  SolverEntry(
    id: 'redox',
    group: 'Redox',
    title: 'Balanceo redox (ion-electrón)',
    subtitle: 'Reacciones frecuentes, por semirreacciones',
    icon: LucideIcons.arrowLeftRight,
    page: RedoxSolver(),
  ),
  SolverEntry(
    id: 'gas',
    group: 'Gases y reacciones',
    title: 'Gas ideal',
    subtitle: 'PV = nRT: presión, volumen, moles y temperatura',
    icon: LucideIcons.wind,
    page: GasSolver(),
  ),
  SolverEntry(
    id: 'limiting',
    group: 'Gases y reacciones',
    title: 'Reactivo limitante',
    subtitle: 'Quién se agota primero en la reacción',
    icon: LucideIcons.hourglass,
    page: LimitingSolver(),
  ),
  SolverEntry(
    id: 'titration',
    group: 'Valoraciones',
    title: 'Valoraciones',
    subtitle: 'Ácido-base, redox y por retroceso',
    icon: LucideIcons.pipette,
    page: TitrationSolver(),
  ),
  SolverEntry(
    id: 'potentiometric',
    group: 'Valoraciones',
    title: 'Valoración potenciométrica',
    subtitle: 'El punto de equivalencia por el salto de pH',
    icon: LucideIcons.trendingUp,
    page: PotentiometricSolver(),
  ),
];

class ResolverScreen extends StatefulWidget {
  const ResolverScreen({super.key});
  @override
  State<ResolverScreen> createState() => _ResolverScreenState();
}

/// Grupos de solucionadores, en el orden en que aparecen.
const List<String> _solverGroupOrder = [
  'Cantidad de sustancia',
  'Disoluciones',
  'Ácidos y bases',
  'Equilibrio',
  'Redox',
  'Gases y reacciones',
  'Valoraciones',
];

class _ResolverScreenState extends State<ResolverScreen> {
  final _scroll = ScrollController();
  final _groupKeys = <String, GlobalKey>{
    for (final g in _solverGroupOrder) g: GlobalKey(),
  };

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Abre el solucionador en su propia pantalla completa (v6): con su
  /// AppBar y su botón atrás, sin el efecto raro de "descomprimirse"
  /// que tenía al abrirse dentro de la lista.
  void _openSolver(int i) {
    final entry = solverEntries[i];
    final t = localizedSolver(entry.id);
    SoundService.tap();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(t?.title ?? entry.title)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [entry.page, const SizedBox(height: 16)],
          ),
        ),
      ),
    );
  }

  /// Salta a un grupo de la lista (chips de arriba, sin desplazar).
  void _jumpToGroup(String group) {
    final ctx = _groupKeys[group]?.currentContext;
    if (ctx == null) return;
    SoundService.tap();
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      alignment: 0.0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _consumeNavRequests();
  }

  @override
  void didUpdateWidget(ResolverScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _consumeNavRequests();
  }

  /// Consume la petición de abrir un solucionador (NavRequests).
  /// Antes solo se miraba en didChangeDependencies: si ya estabas
  /// en Resolver al pedirlo desde la búsqueda, no se abría nada
  /// (auditoría fix2).
  void _consumeNavRequests() {
    // Petición de la búsqueda: abrir un solucionador por su título.
    final title = NavRequests.openSolverTitle;
    if (title != null) {
      NavRequests.openSolverTitle = null;
      final i = solverEntries.indexWhere((s) => s.title == title);
      if (i >= 0) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _openSolver(i));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      children: [
        const _LogoHeader(),
        const SizedBox(height: 8),
        const _IntroCard(),
        const SizedBox(height: 12),
        // Chips de sección (v6): saltar a cada grupo sin desplazar.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ActionChip(
                label: Text(tr('allSolvers')),
                onPressed: () {
                  SoundService.tap();
                  _scroll.animateTo(0,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut);
                },
              ),
              for (final g in _solverGroupOrder) ...[
                const SizedBox(width: 6),
                ActionChip(
                  label: Text(localizedSolverGroup(g)),
                  onPressed: () => _jumpToGroup(g),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Ronda #6: Resolver queda SOLO con los solvers. El Formulario
        // rápido y el Simulador de laboratorio ya viven en el menú
        // hamburguesa; aquí eran duplicados y se quitan.
        for (final group in _solverGroupOrder) ...[
          Padding(
            key: _groupKeys[group],
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(localizedSolverGroup(group),
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.bold)),
          ),
          for (var i = 0; i < solverEntries.length; i++)
            if (solverEntries[i].group == group)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.15),
                    child: LucideIcon(solverEntries[i].icon,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  title: Text(
                      localizedSolver(solverEntries[i].id)?.title ??
                          solverEntries[i].title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      localizedSolver(solverEntries[i].id)?.subtitle ??
                          solverEntries[i].subtitle),
                  trailing: const LucideIcon(LucideIcons.chevronRight),
                  onTap: () => _openSolver(i),
                ),
              ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

class _LogoHeader extends StatelessWidget {
  const _LogoHeader();
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        // Fix3, punto 6: logo panorámico recortado a las gemelas
        // (ancho 80, alto ~32), no el cuadrado marrón de 96.
        BrandLogo(size: 80),
        SizedBox(height: 8),
        Text(
          'Quemia',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        Text('Química Pura — Universidad'),
      ],
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('resolverTitle'),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(tr('resolverIntro')),
            const SizedBox(height: 6),
            Text(
              localizedSolverString('14 solucionadores que no solo dan el resultado: muestran el procedimiento completo, como lo escribirías en un examen.'),
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
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
    return SolverCard(
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
          ElevatedButton(onPressed: _calc, child: Text(localizedSolverString('Calcular masa molar'))),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error, style: const TextStyle(color: Colors.redAccent)),
            ),
          if (_steps.isNotEmpty) Steps(steps: _steps),
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
    final m = parseNum(_mass);
    final mm = parseNum(_molar);
    if (mm == null || mm <= 0) {
      setState(() => _result =
          'Revisa los datos: introduce una masa molar válida (g/mol), mayor que cero.');
      return;
    }
    if (_mode == 'moles') {
      if (m == null || m <= 0) {
        setState(() => _result =
            'Revisa los datos: introduce la masa en gramos (mayor que cero).');
        return;
      }
      final n = m / mm;
      setState(() {
        _result = 'n = ${fmtResult(n)} mol';
        _steps = [
          'Fórmula: n = m / M',
          'Sustitución: n = ${fmtResult(m)} g ÷ ${fmtResult(mm)} g/mol',
          'Resultado: n = ${fmtResult(n)} mol',
        ];
      });
    } else {
      // Aquí _mass se reusa como moles en este modo.
      if (m == null || m <= 0) {
        setState(() => _result =
            'Revisa los datos: introduce los moles (mayores que cero).');
        return;
      }
      final mass = m * mm;
      setState(() {
        _result = 'm = ${fmtResult(mass)} g';
        _steps = [
          'Fórmula: m = n × M',
          'Sustitución: m = ${fmtResult(m)} mol × ${fmtResult(mm)} g/mol',
          'Resultado: m = ${fmtResult(mass)} g',
        ];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SolverCard(
      title: 'Masa ⇄ moles ⇄ partículas',
      subtitle: 'n = m / M · N = n · 6.022×10²³',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButton<String>(
            value: _mode,
            isExpanded: true,
            items: [
              DropdownMenuItem(value: 'moles', child: Text(localizedSolverString('Moles a partir de la masa'))),
              DropdownMenuItem(value: 'masa', child: Text(localizedSolverString('Masa a partir de los moles'))),
            ],
            onChanged: (v) => setState(() => _mode = v ?? 'moles'),
          ),
          NumField(controller: _mass, label: _mode == 'moles' ? 'Masa (g)' : 'Moles (mol)'),
          NumField(controller: _molar, label: 'Masa molar M (g/mol)'),
          ElevatedButton(onPressed: _calc, child: Text(localizedSolverString('Calcular'))),
          if (_result.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_result, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ),
          if (_steps.isNotEmpty) Steps(steps: _steps),
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
    final n = parseNum(_moles);
    final v = parseNum(_vol);
    if (n == null || n <= 0 || v == null || v <= 0) {
      setState(() => _result =
          'Revisa los datos: introduce moles y volumen en litros, mayores que cero.');
      return;
    }
    final m = n / v;
    setState(() {
      _result = 'M = ${fmtResult(m)} mol/L';
      _steps = [
        'Fórmula: M = n / V(L)',
        'Sustitución: M = ${fmtResult(n)} mol ÷ ${fmtResult(v)} L',
        'Resultado: M = ${fmtResult(m)} mol/L',
        'Recuerda: V es el volumen de la disolución final, no del disolvente.',
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return SolverCard(
      title: 'Molaridad de una disolución',
      subtitle: 'M = n / V(L)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NumField(controller: _moles, label: 'Moles de soluto (mol)'),
          NumField(controller: _vol, label: 'Volumen (L)'),
          ElevatedButton(onPressed: _calc, child: Text(localizedSolverString('Calcular'))),
          if (_result.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_result, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ),
          if (_steps.isNotEmpty) Steps(steps: _steps),
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
    final c1 = parseNum(_c1);
    final v1 = parseNum(_v1);
    final c2 = parseNum(_c2);
    final v2 = parseNum(_v2);
    final missing = [c1, v1, c2, v2].where((e) => e == null).length;
    if (missing != 1) {
      setState(() => _result = 'Deja vacío SOLO el dato que quieres calcular y rellena los otros tres.');
      return;
    }
    if ([c1, v1, c2, v2].whereType<double>().any((e) => e <= 0)) {
      setState(() => _result =
          'Revisa los datos: concentraciones y volúmenes deben ser mayores que cero.');
      return;
    }
    setState(() {
      if (c1 == null) {
        final r = c2! * v2! / v1!;
        _result = 'C₁ = ${fmtResult(r)} mol/L';
        _steps = ['C₁V₁ = C₂V₂', 'C₁ = C₂V₂ / V₁ = ${fmtResult(c2)} × ${fmtResult(v2)} ÷ ${fmtResult(v1)}', 'C₁ = ${fmtResult(r)} mol/L'];
      } else if (v1 == null) {
        final r = c2! * v2! / c1;
        _result = 'V₁ = ${fmtResult(r)} mL';
        _steps = ['C₁V₁ = C₂V₂', 'V₁ = C₂V₂ / C₁ = ${fmtResult(c2)} × ${fmtResult(v2)} ÷ ${fmtResult(c1)}', 'V₁ = ${fmtResult(r)} mL'];
      } else if (c2 == null) {
        final r = c1 * v1 / v2!;
        _result = 'C₂ = ${fmtResult(r)} mol/L';
        _steps = ['C₁V₁ = C₂V₂', 'C₂ = C₁V₁ / V₂ = ${fmtResult(c1)} × ${fmtResult(v1)} ÷ ${fmtResult(v2)}', 'C₂ = ${fmtResult(r)} mol/L'];
      } else {
        final r = c1 * v1 / c2;
        _result = 'V₂ = ${fmtResult(r)} mL';
        _steps = ['C₁V₁ = C₂V₂', 'V₂ = C₁V₁ / C₂ = ${fmtResult(c1)} × ${fmtResult(v1)} ÷ ${fmtResult(c2)}', 'V₂ = ${fmtResult(r)} mL'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SolverCard(
      title: 'Dilución · C₁V₁ = C₂V₂',
      subtitle: 'Deja vacío el dato que quieres calcular y rellena los otros tres.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NumField(controller: _c1, label: 'C₁ inicial (mol/L)'),
          NumField(controller: _v1, label: 'V₁ inicial (mL)'),
          NumField(controller: _c2, label: 'C₂ final (mol/L)'),
          NumField(controller: _v2, label: 'V₂ final (mL)'),
          ElevatedButton(onPressed: _calc, child: Text(localizedSolverString('Calcular el dato que falta'))),
          if (_result.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_result, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ),
          if (_steps.isNotEmpty) Steps(steps: _steps),
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
    final v = parseNum(_value);
    if (v == null) {
      setState(() => _result = 'Revisa los datos: introduce un valor.');
      return;
    }
    // El pH = 0 es válido (ácido 1 M): solo las concentraciones
    // exigen un valor mayor que cero; el pH solo no puede ser negativo.
    if (_mode == 'ph') {
      if (v < 0) {
        setState(() => _result = 'Revisa los datos: el pH no puede ser negativo.');
        return;
      }
    } else if (v <= 0) {
      setState(() => _result = 'Revisa los datos: introduce un valor mayor que cero.');
      return;
    }
    setState(() {
      if (_mode == 'h') {
        final ph = -math.log(v) / math.ln10;
        final poh = 14 - ph;
        _result = 'pH = ${ph.toStringAsFixed(2)} · pOH = ${poh.toStringAsFixed(2)}';
        _steps = [
          'Dato: [H⁺] = ${fmtResult(v)} mol/L',
          'pH = −log[H⁺] = ${ph.toStringAsFixed(2)}',
          'A 25 °C: pH + pOH = 14 → pOH = ${poh.toStringAsFixed(2)}',
          ph < 7 ? 'Disolución ácida.' : (ph > 7 ? 'Disolución básica.' : 'Disolución neutra.'),
        ];
      } else if (_mode == 'ph') {
        final h = math.pow(10, -v).toDouble();
        _result = '[H⁺] = ${fmtResult(h)} mol/L · pOH = ${(14 - v).toStringAsFixed(2)}';
        _steps = [
          'Dato: pH = ${fmtResult(v)}',
          '[H⁺] = 10^(−pH) = ${fmtResult(h)} mol/L',
          'pOH = 14 − pH = ${(14 - v).toStringAsFixed(2)}',
        ];
      } else {
        final oh = v;
        final poh = -math.log(oh) / math.ln10;
        final ph = 14 - poh;
        _result = 'pOH = ${poh.toStringAsFixed(2)} · pH = ${ph.toStringAsFixed(2)}';
        _steps = [
          'Dato: [OH⁻] = ${fmtResult(oh)} mol/L',
          'pOH = −log[OH⁻] = ${poh.toStringAsFixed(2)}',
          'pH = 14 − pOH = ${ph.toStringAsFixed(2)}',
        ];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SolverCard(
      title: 'pH y pOH (a 25 °C)',
      subtitle: 'Puedes escribir la concentración como 0.001 o como 1e-3.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButton<String>(
            value: _mode,
            isExpanded: true,
            items: [
              DropdownMenuItem(value: 'h', child: Text(localizedSolverString('Concentración [H⁺] (mol/L)'))),
              DropdownMenuItem(value: 'ph', child: Text(localizedSolverString('pH'))),
              DropdownMenuItem(value: 'oh', child: Text(localizedSolverString('Concentración [OH⁻] (mol/L)'))),
            ],
            onChanged: (v) => setState(() => _mode = v ?? 'h'),
          ),
          NumField(controller: _value, label: 'Valor'),
          ElevatedButton(onPressed: _calc, child: Text(localizedSolverString('Calcular pH y pOH'))),
          if (_result.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_result, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ),
          if (_steps.isNotEmpty) Steps(steps: _steps),
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
    final p = parseNum(_p);
    final v = parseNum(_v);
    final n = parseNum(_n);
    final t = parseNum(_t);
    if ((p != null && p <= 0) ||
        (v != null && v <= 0) ||
        (n != null && n <= 0) ||
        (t != null && t <= 0)) {
      setState(() => _result =
          'Revisa los datos: la presión, el volumen, los moles y la temperatura deben ser mayores que cero.');
      return;
    }
    setState(() {
      if (_mode == 'P') {
        if (v == null || n == null || t == null || v == 0) {
          _result = 'Introduce V, n y T (en kelvin).';
          return;
        }
        final r = n * _r * t / v;
        _result = 'P = ${fmtResult(r)} atm';
        _steps = ['PV = nRT → P = nRT / V', 'P = ${fmtResult(n)} × 0.08206 × ${fmtResult(t)} ÷ ${fmtResult(v)}', 'P = ${fmtResult(r)} atm'];
      } else if (_mode == 'V') {
        if (p == null || n == null || t == null || p == 0) {
          _result = 'Introduce P, n y T (en kelvin).';
          return;
        }
        final r = n * _r * t / p;
        _result = 'V = ${fmtResult(r)} L';
        _steps = ['PV = nRT → V = nRT / P', 'V = ${fmtResult(n)} × 0.08206 × ${fmtResult(t)} ÷ ${fmtResult(p)}', 'V = ${fmtResult(r)} L'];
      } else if (_mode == 'n') {
        if (p == null || v == null || t == null || t == 0) {
          _result = 'Introduce P, V y T (en kelvin).';
          return;
        }
        final r = p * v / (_r * t);
        _result = 'n = ${fmtResult(r)} mol';
        _steps = ['PV = nRT → n = PV / RT', 'n = ${fmtResult(p)} × ${fmtResult(v)} ÷ (0.08206 × ${fmtResult(t)})', 'n = ${fmtResult(r)} mol'];
      } else {
        if (p == null || v == null || n == null || n == 0) {
          _result = 'Introduce P, V y n.';
          return;
        }
        final r = p * v / (_r * n);
        _result = 'T = ${fmtResult(r)} K (${(r - 273.15).toStringAsFixed(1)} °C)';
        _steps = ['PV = nRT → T = PV / nR', 'T = ${fmtResult(p)} × ${fmtResult(v)} ÷ (0.08206 × ${fmtResult(n)})', 'T = ${fmtResult(r)} K'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SolverCard(
      title: 'Gas ideal · PV = nRT',
      subtitle: 'R = 0,08206 L·atm·mol⁻¹·K⁻¹. La temperatura siempre en kelvin (K = °C + 273,15).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButton<String>(
            value: _mode,
            isExpanded: true,
            items: [
              DropdownMenuItem(value: 'P', child: Text(localizedSolverString('Calcular presión P (atm)'))),
              DropdownMenuItem(value: 'V', child: Text(localizedSolverString('Calcular volumen V (L)'))),
              DropdownMenuItem(value: 'n', child: Text(localizedSolverString('Calcular moles n (mol)'))),
              DropdownMenuItem(value: 'T', child: Text(localizedSolverString('Calcular temperatura T (K)'))),
            ],
            onChanged: (v) => setState(() => _mode = v ?? 'V'),
          ),
          NumField(controller: _p, label: 'Presión P (atm)'),
          NumField(controller: _v, label: 'Volumen V (L)'),
          NumField(controller: _n, label: 'Moles n (mol)'),
          NumField(controller: _t, label: 'Temperatura T (K)'),
          ElevatedButton(onPressed: _calc, child: Text(localizedSolverString('Calcular'))),
          if (_result.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_result, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ),
          if (_steps.isNotEmpty) Steps(steps: _steps),
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
    final ca = parseNum(_ca);
    final na = parseNum(_na);
    final cb = parseNum(_cb);
    final nb = parseNum(_nb);
    if (ca == null ||
        na == null ||
        cb == null ||
        nb == null ||
        ca <= 0 ||
        cb <= 0 ||
        na <= 0 ||
        nb <= 0) {
      setState(() => _result =
          'Revisa los datos: introduce coeficientes y moles mayores que cero.');
      return;
    }
    final qa = na / ca;
    final qb = nb / cb;
    setState(() {
      _steps = [
        'No compares moles a secas: divide moles entre coeficiente.',
        'Cociente A: ${fmtResult(na)} ÷ ${fmtResult(ca)} = ${fmtResult(qa)}',
        'Cociente B: ${fmtResult(nb)} ÷ ${fmtResult(cb)} = ${fmtResult(qb)}',
        'El cociente menor es el limitante: es el que da menos producto.',
      ];
      if (qa < qb) {
        _result = 'Limitante: A (cociente ${fmtResult(qa)} < ${fmtResult(qb)})';
      } else if (qb < qa) {
        _result = 'Limitante: B (cociente ${fmtResult(qb)} < ${fmtResult(qa)})';
      } else {
        _result = 'Ambos se agotan a la vez: mezcla estequiométrica.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SolverCard(
      title: 'Reactivo limitante',
      subtitle: 'Para una reacción a·A + b·B → productos. Introduce los coeficientes de la ecuación ajustada y los moles de partida.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NumField(controller: _ca, label: 'Coeficiente de A (a)'),
          NumField(controller: _na, label: 'Moles de A'),
          NumField(controller: _cb, label: 'Coeficiente de B (b)'),
          NumField(controller: _nb, label: 'Moles de B'),
          ElevatedButton(onPressed: _calc, child: Text(localizedSolverString('Encontrar el limitante'))),
          if (_result.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_result, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ),
          if (_steps.isNotEmpty) Steps(steps: _steps),
        ],
      ),
    );
  }
}

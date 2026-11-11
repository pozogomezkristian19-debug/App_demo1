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
import 'dart:ui' as ui;

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

  /// Mezcla dos colores (t en 0..1).
  Color _mix(Color a, Color b, double t) =>
      Color.lerp(a, b, t.clamp(0.0, 1.0))!;

  /// Color real del indicador según el pH, con el viraje GRADUAL
  /// dentro de cada intervalo de cambio: el color no salta de golpe,
  /// se intensifica o se mezcla a medida que el pH cruza la zona de
  /// viraje (como en el laboratorio de verdad). Los extremos son los
  /// colores clásicos de cada indicador:
  /// - Fenolftaleína: incolora < 8,2 · rosa 8,2–10 · rosa intenso > 10.
  /// - Tornasol: rojo < 4,5 · violeta 4,5–8,3 · azul > 8,3.
  /// - Universal: rojo-naranja-amarillo-verde-azul-violeta de 0 a 14.
  /// - Naranja de metilo: rojo < 3,1 · naranja 3,1–4,4 · amarillo > 4,4.
  /// - Azul de bromotimol: amarillo < 6,0 · verde 6,0–7,6 · azul > 7,6.
  Color _indicatorColor(double ph) {
    switch (_indicator) {
      case 'Tornasol':
        if (ph < 4.5) return const Color(0xFFE53935);
        if (ph < 6.4) {
          return _mix(const Color(0xFFE53935), const Color(0xFF8E24AA),
              (ph - 4.5) / 1.9);
        }
        if (ph < 8.3) {
          return _mix(const Color(0xFF8E24AA), const Color(0xFF1E88E5),
              (ph - 6.4) / 1.9);
        }
        return const Color(0xFF1E88E5);
      case 'Universal':
        const stops = <(double, Color)>[
          (0.0, Color(0xFFD32F2F)),
          (3.0, Color(0xFFFB8C00)),
          (5.0, Color(0xFFFDD835)),
          (6.5, Color(0xFF43A047)),
          (8.5, Color(0xFF1E88E5)),
          (11.0, Color(0xFF8E24AA)),
          (14.0, Color(0xFF8E24AA)),
        ];
        for (var i = 0; i < stops.length - 1; i++) {
          final (p0, c0) = stops[i];
          final (p1, c1) = stops[i + 1];
          if (ph >= p0 && ph <= p1) {
            return _mix(c0, c1, (ph - p0) / (p1 - p0));
          }
        }
        return const Color(0xFF8E24AA);
      case 'Naranja de metilo':
        if (ph < 3.1) return const Color(0xFFE53935);
        if (ph < 4.4) {
          return _mix(const Color(0xFFE53935), const Color(0xFFFDD835),
              (ph - 3.1) / 1.3);
        }
        return const Color(0xFFFDD835);
      case 'Azul de bromotimol':
        if (ph < 6.0) return const Color(0xFFFDD835);
        if (ph < 6.8) {
          return _mix(const Color(0xFFFDD835), const Color(0xFF43A047),
              (ph - 6.0) / 0.8);
        }
        if (ph < 7.6) {
          return _mix(const Color(0xFF43A047), const Color(0xFF1E88E5),
              (ph - 6.8) / 0.8);
        }
        return const Color(0xFF1E88E5);
      default: // Fenolftaleína
        if (ph < 8.2) return const Color(0xFFECEFF1);
        if (ph < 10.0) {
          return _mix(const Color(0xFFF8BBD0), const Color(0xFFEC407A),
              (ph - 8.2) / 1.8);
        }
        return const Color(0xFFEC407A);
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('labSimTitle'))),
      // ListView: el cuerpo ya es desplazable; el padding inferior
      // es generoso para que la tarjeta de resultado pueda subir
      // del todo por encima del borde inferior de la pantalla.
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          SegmentedButton<bool>(
            // Sin color fijo: el segmento seleccionado sigue el
            // primario del tema (teal con el acento verde en claro,
            // menta en oscuro; violeta solo si el usuario eligió
            // ese acento en Ajustes). Antes no tenía estilo propio
            // y heredaba el primario; ahora queda explícito.
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: scheme.primary,
              selectedForegroundColor: scheme.onPrimary,
              backgroundColor: scheme.surface,
              foregroundColor: scheme.onSurface,
              side: BorderSide(color: scheme.primary),
            ),
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
      // El vaso: dibujado con CustomPaint (pico vertedor, marcas de
      // volumen, nivel de líquido). El color cambia con animación.
      Center(
        child: _Beaker(
          liquidColor: color,
          fillFraction: totalVol / 200,
          precipColor: Colors.transparent,
          precipFraction: 0,
        ),
      ),
      const SizedBox(height: 4),
      Center(
        child: Text(
          '≈ ${totalVol.round()} mL en el vaso',
          style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.65)),
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
      // Espacio final para que la tarjeta suba del todo al hacer scroll.
      const SizedBox(height: 8),
    ];
  }

  List<Widget> _precipBody(BuildContext context) {
    final r = _precipReactions[_precipIndex];
    final (nPrecip, massMg, excess) = _computePrecip();
    final totalVol = _vol1 + _vol2;
    // La capa de precipitado crece con los moles: 0,01 mol la llena
    // (hasta el 45 % de la altura del vaso).
    final precipFraction = (nPrecip / 0.01).clamp(0.0, 1.0) * 0.45;
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
      // El vaso: disolución clara arriba, precipitado abajo (dibujado
      // con CustomPaint, con el mismo pico y marcas que en ácido-base).
      Center(
        child: _Beaker(
          liquidColor: const Color(0xFFB3E5FC),
          fillFraction: totalVol / 200,
          precipColor: r.color,
          precipFraction: precipFraction,
        ),
      ),
      const SizedBox(height: 4),
      Center(
        child: Text(
          '≈ ${totalVol.round()} mL en el vaso',
          style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.65)),
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
      // Espacio final para que la tarjeta suba del todo al hacer scroll.
      const SizedBox(height: 8),
    ];
  }
}

/// Vaso de precipitados con animación: el nivel del líquido, su color
/// y la capa de precipitado cambian suavemente (800 ms) al mover los
/// controles. El dibujo lo hace [_BeakerPainter].
class _Beaker extends StatefulWidget {
  const _Beaker({
    required this.liquidColor,
    required this.fillFraction,
    required this.precipColor,
    required this.precipFraction,
  });

  /// Color del líquido (indicador/pH o disolución clara azulada).
  final Color liquidColor;

  /// Fracción de la altura del vaso ocupada por el líquido (0..1).
  final double fillFraction;

  /// Color del precipitado (transparente si no hay).
  final Color precipColor;

  /// Fracción de la altura del vaso ocupada por el precipitado (0..1).
  final double precipFraction;

  @override
  State<_Beaker> createState() => _BeakerState();
}

class _BeakerState extends State<_Beaker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _fill;
  late Animation<double> _precip;
  late Animation<Color?> _liquid;
  late Animation<Color?> _precipColor;

  Animation<double> _tweenDouble(double value) =>
      Tween<double>(begin: value, end: value).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  Animation<Color?> _tweenColor(Color value) =>
      ColorTween(begin: value, end: value).animate(_controller);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fill = _tweenDouble(widget.fillFraction);
    _precip = _tweenDouble(widget.precipFraction);
    _liquid = _tweenColor(widget.liquidColor);
    _precipColor = _tweenColor(widget.precipColor);
  }

  @override
  void didUpdateWidget(_Beaker oldWidget) {
    super.didUpdateWidget(oldWidget);
    var changed = false;
    if (widget.fillFraction != oldWidget.fillFraction) {
      _fill = Tween<double>(begin: _fill.value, end: widget.fillFraction)
          .animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
      changed = true;
    }
    if (widget.precipFraction != oldWidget.precipFraction) {
      _precip =
          Tween<double>(begin: _precip.value, end: widget.precipFraction)
              .animate(CurvedAnimation(
                  parent: _controller, curve: Curves.easeInOut));
      changed = true;
    }
    if (widget.liquidColor != oldWidget.liquidColor) {
      _liquid = ColorTween(begin: _liquid.value, end: widget.liquidColor)
          .animate(_controller);
      changed = true;
    }
    if (widget.precipColor != oldWidget.precipColor) {
      _precipColor =
          ColorTween(begin: _precipColor.value, end: widget.precipColor)
              .animate(_controller);
      changed = true;
    }
    if (changed) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: const Size(220, 228),
        painter: _BeakerPainter(
          liquidColor: _liquid.value ?? widget.liquidColor,
          fillFraction: _fill.value,
          precipColor: _precipColor.value ?? widget.precipColor,
          precipFraction: _precip.value,
          // Sedimentación: cuánto del montículo nuevo ya creció
          // (0 = recién mezclado, 1 = asentado). Cuando el vaso
          // monta con precipitado ya creado, el valor animado ya es
          // el final y settle sale 1: partículas asentadas.
          settle: widget.precipFraction > 0
              ? (_precip.value / widget.precipFraction).clamp(0.0, 1.0)
              : 1.0,
          onSurface: scheme.onSurface,
          glassFill: scheme.onSurface.withValues(alpha: 0.05),
        ),
      ),
    );
  }
}

/// Dibuja un vaso de precipitados con aspecto real: vidrio con
/// degradado vertical, paredes gruesas (trazo ancho de vidrio por
/// dentro del contorno + base pesada en el fondo), pico vertedor,
/// graduaciones cada 25 mL (con número cada 50 mL), reflejos del
/// vidrio por encima del líquido, superficie con menisco cóncavo y
/// brillo, líquido con degradado vertical (más claro arriba, más
/// intenso abajo) y —en precipitación— líquido turbio/lechoso con
/// partículas en suspensión y un precipitado granuloso, de densidad
/// y tamaño crecientes hacia el fondo, acumulado sobre el fondo del
/// vaso.
///
/// El vidrio, las marcas y el contorno siguen `onSurface` del tema,
/// así que se ven bien en modo claro (fondo blanco) y en modo oscuro
/// (fondo verde oscuro). El líquido y el precipitado son los colores
/// de la reacción, iguales en ambos temas.
class _BeakerPainter extends CustomPainter {
  _BeakerPainter({
    required this.liquidColor,
    required this.fillFraction,
    required this.precipColor,
    required this.precipFraction,
    required this.settle,
    required this.onSurface,
    required this.glassFill,
  });

  final Color liquidColor;
  final double fillFraction;
  final Color precipColor;
  final double precipFraction;

  /// Sedimentación de las partículas en suspensión: 0 = recién
  /// mezcladas (repartidas por el líquido), 1 = asentadas sobre el
  /// montículo. Sube con la misma animación que hace crecer el
  /// montículo, así las partículas caen mientras este se forma.
  final double settle;

  final Color onSurface;
  final Color glassFill;

  // Caja de dibujo: 220 x 228.
  static const double _left = 46;
  static const double _right = 178;
  static const double _top = 22;
  static const double _bottom = 208;

  Path _outline() {
    return Path()
      ..moveTo(_left, _top)
      ..lineTo(_right - 6, _top)
      ..lineTo(_right + 10, _top + 12) // pico vertedor
      ..lineTo(_right - 6, _top + 24)
      ..lineTo(_right - 6, _bottom - 16)
      ..quadraticBezierTo(_right - 6, _bottom, _right - 22, _bottom)
      ..lineTo(_left + 16, _bottom)
      ..quadraticBezierTo(_left, _bottom, _left, _bottom - 16)
      ..close();
  }

  /// Borde superior ondulado de la capa de precipitado.
  Path _wavyTop(double y) {
    const step = 16.0;
    final path = Path()..moveTo(_left - 2, y + 4);
    var x = _left - 2;
    var up = true;
    while (x < _right + 12) {
      final nx = math.min(x + step, _right + 12);
      path.quadraticBezierTo(
          (x + nx) / 2, y + (up ? 0 : 7), nx, y + 4);
      x = nx;
      up = !up;
    }
    return path;
  }

  void _paintLabel(Canvas canvas, String text, Offset offset) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: onSurface.withValues(alpha: 0.75),
              fontSize: 10,
              fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  /// Aclara (amount > 0) u oscurece (amount < 0) un color moviendo su
  /// luminosidad HSL. amount en [-1, 1].
  static Color _shade(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outline = _outline();
    final innerH = _bottom - _top;
    final cx = (_left + _right) / 2;

    // ---- Vidrio: degradado vertical sutil (más claro arriba).
    canvas.drawPath(
        outline,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(0, _top),
            const Offset(0, _bottom),
            [
              Colors.white.withValues(alpha: 0.16),
              glassFill,
              Colors.white.withValues(alpha: 0.05),
            ],
            const [0.0, 0.55, 1.0],
          ));

    // ---- Líquido, recortado por la silueta del vaso.
    final liquidH = (innerH * fillFraction).clamp(0.0, innerH);
    // Turbidez de la precipitación: 0 sin precipitado, 1 con el
    // máximo (el montículo llega al 45 % de la altura del vaso).
    final turbidity = (precipFraction / 0.45).clamp(0.0, 1.0);
    if (liquidH > 2) {
      final liquidTop = _bottom - liquidH;
      // Un líquido casi blanco (fenolftaleína en medio ácido) es
      // agua incolora: se dibuja como agua (de casi blanca arriba a
      // gris azulado pálido abajo), no como un gris plano.
      final isWater =
          HSLColor.fromColor(liquidColor).lightness > 0.92;
      final topColor =
          isWater ? const Color(0xFFF7FAFB) : _shade(liquidColor, 0.22);
      final bottomColor =
          isWater ? const Color(0xFFD3DEE4) : _shade(liquidColor, -0.10);
      // Superficie con menisco: se hunde un poco en el centro.
      final liquidPath = Path()
        ..moveTo(_left - 2, liquidTop)
        ..quadraticBezierTo(cx, liquidTop + 6, _right + 12, liquidTop)
        ..lineTo(_right + 12, _bottom + 2)
        ..lineTo(_left - 2, _bottom + 2)
        ..close();
      canvas.save();
      canvas.clipPath(outline);
      // Degradado vertical del líquido: claro arriba, intenso abajo.
      canvas.drawPath(
          liquidPath,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, liquidTop),
              Offset(0, _bottom),
              [topColor, liquidColor, bottomColor],
              const [0.0, 0.45, 1.0],
            ));
      // Menisco: línea de la superficie, un poco más oscura que el
      // líquido, para que el nivel se lea aunque el líquido sea
      // incoloro.
      final surface = Path()
        ..moveTo(_left - 2, liquidTop)
        ..quadraticBezierTo(cx, liquidTop + 6, _right + 12, liquidTop);
      canvas.drawPath(
          surface,
          Paint()
            ..color = _shade(liquidColor, isWater ? -0.30 : -0.22)
                .withValues(alpha: 0.65)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8);
      // Brillo justo bajo la superficie del líquido.
      final shine = Path()
        ..moveTo(_left + 8, liquidTop + 7)
        ..quadraticBezierTo(cx, liquidTop + 12, _right - 2, liquidTop + 7);
      canvas.drawPath(
          shine,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round);

      // ---- Precipitación: turbidez, suspensión y montículo.
      if (precipFraction > 0.01) {
        // Todo lo del precipitado queda dentro del líquido.
        canvas.save();
        canvas.clipPath(liquidPath);
        // El líquido se vuelve turbio/lechoso según la cantidad de
        // precipitado, con un leve tinte de su color real.
        canvas.drawPath(
            liquidPath,
            Paint()..color = Colors.white.withValues(alpha: 0.55 * turbidity));
        canvas.drawPath(
            liquidPath,
            Paint()
              ..color = precipColor.withValues(alpha: 0.18 * turbidity));
        final precipTopY = _bottom - innerH * precipFraction;
        // Partículas en suspensión, con caída al fondo: cada una
        // tiene su punto de partida repartido por el líquido (como
        // recién mezcladas) y su punto de llegada justo sobre el
        // montículo; `settle` las va bajando mientras el montículo
        // crece, así se ve la sedimentación en el tiempo. Más densas
        // y visibles abajo, casi invisibles arriba. Semilla fija (11)
        // para que cada partícula mantenga su sitio entre repintados
        // y el descenso se vea continuo, no un salto.
        final rnd = math.Random(11);
        final suspended = (26 * turbidity).round();
        for (var i = 0; i < suspended; i++) {
          final startY = liquidTop +
              10 +
              rnd.nextDouble() *
                  math.max(1.0, precipTopY - liquidTop - 14);
          final endY = precipTopY - 2 - rnd.nextDouble() * 6;
          final y = startY + (endY - startY) * settle;
          final depth =
              ((y - liquidTop) / math.max(1.0, innerH)).clamp(0.0, 1.0);
          canvas.drawCircle(
              Offset(_left + 8 + rnd.nextDouble() * (_right - _left - 16),
                  y),
              0.9 + rnd.nextDouble() * 1.3,
              Paint()
                ..color = _shade(precipColor, -0.30)
                    .withValues(alpha: (0.25 + 0.45 * depth) * turbidity));
        }
        // Montículo de precipitado acumulado en el fondo, con
        // degradado (claro arriba, oscuro abajo) y borde superior
        // ondulado más oscuro.
        final precipH = innerH * precipFraction;
        if (precipH > 2) {
          final precipTop = _bottom - precipH;
          final body = _wavyTop(precipTop)
            ..lineTo(_right + 12, _bottom + 2)
            ..lineTo(_left - 2, _bottom + 2)
            ..close();
          canvas.drawPath(
              body,
              Paint()
                ..shader = ui.Gradient.linear(
                  Offset(0, precipTop),
                  Offset(0, _bottom),
                  [
                    _shade(precipColor, 0.10),
                    precipColor,
                    _shade(precipColor, -0.22),
                  ],
                  const [0.0, 0.5, 1.0],
                ));
          final edgeColor = _shade(precipColor, -0.35);
          canvas.drawPath(
              _wavyTop(precipTop),
              Paint()
                ..color = edgeColor
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5);
          // Gránulos dentro del montículo (semilla fija: estables):
          // densidad y tamaño crecen hacia el fondo, cada uno con su
          // propio tono, para que el precipitado no sea una mancha
          // plana. Los blancos se oscurecen lo bastante para verse
          // sobre fondo blanco.
          final gr = math.Random(7);
          canvas.save();
          canvas.clipPath(body);
          for (var i = 0; i < 80; i++) {
            final depth = math.pow(gr.nextDouble(), 0.55);
            final gx = _left + 5 + gr.nextDouble() * (_right - _left - 10);
            final gy = precipTop + 3 + depth * (_bottom - precipTop - 6);
            final r = 1.1 + gr.nextDouble() * 2.6 + depth * 1.4;
            final shade = -0.32 + gr.nextDouble() * 0.45;
            canvas.drawCircle(
                Offset(gx, gy),
                r,
                Paint()
                  ..color = _shade(precipColor, shade)
                      .withValues(alpha: 0.75));
          }
          canvas.restore();
        }
        canvas.restore();
      }
      canvas.restore();
    }

    // ---- Graduaciones: marcas menores cada 25 mL y números cada 50.
    for (final v in [25, 50, 75, 100, 125, 150, 175, 200]) {
      final y = _bottom - innerH * (v / 200);
      final major = v % 50 == 0;
      canvas.drawLine(
          Offset(_left + 2, y),
          Offset(_left + (major ? 20 : 12), y),
          Paint()
            ..color = onSurface.withValues(alpha: major ? 0.65 : 0.35)
            ..strokeWidth = major ? 2 : 1.5
            ..strokeCap = StrokeCap.round);
      if (major) _paintLabel(canvas, '$v', Offset(_left - 26, y - 6));
    }
    _paintLabel(canvas, 'mL', Offset(_left - 26, _top - 15));

    // ---- Pared gruesa, base pesada y reflejos del vidrio (todo
    // recortado a la silueta, por encima del líquido).
    canvas.save();
    canvas.clipPath(outline);
    // Pared: trazo ancho claro por dentro del contorno.
    canvas.drawPath(
        outline,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeJoin = StrokeJoin.round);
    // Base pesada: banda inferior más gruesa y oscura (vidrio
    // grueso del fondo del vaso).
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(_left + 1, _bottom - 9, _right - _left - 7, 9),
            const Radius.circular(4)),
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(0, 199),
            Offset(0, _bottom),
            [
              onSurface.withValues(alpha: 0.10),
              onSurface.withValues(alpha: 0.30),
            ],
            const [0.0, 1.0],
          ));
    // Reflejo principal a la izquierda (ancho y suave).
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(_left + 9, _top + 14, 10, _bottom - _top - 60),
            const Radius.circular(5)),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(_left + 9, 0),
            Offset(_left + 19, 0),
            [
              Colors.white.withValues(alpha: 0.05),
              Colors.white.withValues(alpha: 0.38),
              Colors.white.withValues(alpha: 0.05),
            ],
            const [0.0, 0.5, 1.0],
          ));
    // Raya brillante fina junto al reflejo principal.
    canvas.drawLine(
        Offset(_left + 26, _top + 20),
        Offset(_left + 26, _bottom - 52),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round);
    // Reflejo fino a la derecha, junto al pico vertedor.
    canvas.drawLine(
        Offset(_right - 13, _top + 34),
        Offset(_right - 13, _bottom - 66),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.20)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round);
    canvas.restore();

    // Contorno del vaso.
    canvas.drawPath(
        outline,
        Paint()
          ..color = onSurface
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round);

    // Mesa sobre la que está el vaso.
    canvas.drawLine(
        const Offset(28, 218),
        const Offset(192, 218),
        Paint()
          ..color = onSurface.withValues(alpha: 0.25)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _BeakerPainter old) =>
      liquidColor != old.liquidColor ||
      fillFraction != old.fillFraction ||
      precipColor != old.precipColor ||
      precipFraction != old.precipFraction ||
      settle != old.settle ||
      onSurface != old.onSurface ||
      glassFill != old.glassFill;
}

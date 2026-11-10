// Sistema de inteligencia de Melli-Qui: genera preguntas nuevas de química
// con números aleatorios, para que el banco nunca se acabe.
//
// Cada pregunta generada tiene:
//   - un id estable 'gen:<tipo>:<forma>:<parámetros>' (la misma id siempre
//     reconstruye la misma pregunta, con las mismas opciones y la misma
//     explicación, así las preguntas falladas se pueden volver a mostrar
//     aunque la app se cierre y se vuelva a abrir),
//   - 4 opciones distintas con una sola correcta,
//   - una explicación paso a paso calculada con los mismos números.
//
// Es Dart puro (sin Flutter), para poder comprobarlo con `dart analyze`
// y con un script de comprobación. No toca las 108 preguntas del banco.

import 'dart:math';

import '../data/periodic_table.dart';
import '../models.dart';

/// Una pregunta generada junto con su id estable.
class GeneratedQuestion {
  const GeneratedQuestion({required this.id, required this.question});
  final String id;
  final QuizQuestion question;
}

// ---------------------------------------------------------------------------
// Utilidades de formato y de opciones
// ---------------------------------------------------------------------------

/// Formatea un número quitando ceros sobrantes: 2.50 -> '2.5', 3.00 -> '3'.
String fmtNum(double v, [int decimals = 2]) {
  var s = v.toStringAsFixed(decimals);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return s == '-0' ? '0' : s;
}

/// Normaliza un número a su representación en la id (2 decimales): así
/// construir desde los parámetros es una función pura de la id y la
/// reconstrucción da exactamente la misma pregunta. Sin esto, 17 * 0.1
/// (= 1.7000000000000002) y double.parse('1.70') (= 1.7) redondean
/// distinto en los límites .xx5.
double norm2(double v) => double.parse(v.toStringAsFixed(2));

/// Superíndices Unicode para los exponentes (10⁻³, 10⁻¹⁰...).
String sup(int n) {
  const digits = ['⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹'];
  final s = n.abs().toString();
  final body = s.split('').map((c) => digits[int.parse(c)]).join();
  return n < 0 ? '⁻$body' : body;
}

/// Construye 4 opciones distintas a partir de una lista de candidatas
/// (la primera es la correcta) y devuelve las opciones barajadas con el
/// índice de la correcta. Si faltan candidatas distintas, se rellenan
/// perturbando la correcta.
({List<String> options, int answer}) buildOptions(
  List<String> candidates,
  Random rng,
) {
  final seen = <String>{};
  final unique = <String>[];
  for (final c in candidates) {
    if (seen.add(c)) unique.add(c);
  }
  if (unique.length < 4) {
    throw StateError('No hay suficientes opciones distintas: $candidates');
  }
  final options = unique.take(4).toList()..shuffle(rng);
  return (options: options, answer: options.indexOf(candidates.first));
}

/// Opciones numéricas: la correcta más los distractores dados (ya
/// calculados), con relleno automático si alguno coincide con la correcta.
({List<String> options, int answer}) numericOptions(
  double correct,
  List<double> wrongs,
  String Function(double) fmt,
  Random rng,
) {
  final candidates = <String>[fmt(correct)];
  for (final w in wrongs) {
    candidates.add(fmt(w));
  }
  const factors = [1.05, 0.95, 1.2, 0.8, 1.5, 0.5, 2.0];
  var i = 0;
  while (candidates.toSet().length < 4 && i < factors.length) {
    candidates.add(fmt(correct * factors[i]));
    i++;
  }
  var j = 1;
  while (candidates.toSet().length < 4) {
    candidates.add(fmt(correct + j));
    candidates.add(fmt(correct - j));
    j++;
  }
  return buildOptions(candidates, rng);
}

// ---------------------------------------------------------------------------
// Masas atómicas y compuestos (para masa molar y masa <-> moles)
// ---------------------------------------------------------------------------

const Map<String, double> _atomicMass = {
  'H': 1.008,
  'C': 12.011,
  'N': 14.007,
  'O': 15.999,
  'Na': 22.99,
  'Mg': 24.305,
  'Al': 26.98,
  'S': 32.06,
  'Cl': 35.45,
  'K': 39.10,
  'Ca': 40.08,
  'Fe': 55.85,
  'Cu': 63.55,
  'Zn': 65.38,
};

class _Compound {
  const _Compound(this.formula, this.name, this.parts);
  final String formula;
  final String name;
  final Map<String, int> parts; // símbolo -> cantidad

  double get molarMass {
    var m = 0.0;
    parts.forEach((el, n) => m += n * _atomicMass[el]!);
    return m;
  }

  /// Masa ignorando un subíndice (el error clásico): el elemento con
  /// mayor cantidad pasa a contar como 1.
  double get massIgnoringSubscript {
    var m = 0.0;
    var worst = '';
    var worstN = 1;
    parts.forEach((el, n) {
      if (n > worstN) {
        worst = el;
        worstN = n;
      }
    });
    parts.forEach((el, n) {
      m += (el == worst ? 1 : n) * _atomicMass[el]!;
    });
    return m;
  }

  String get massSteps {
    final bits = parts.entries.map((e) {
      final m = _atomicMass[e.key]!;
      return e.value == 1
          ? '${fmtNum(m)} (${e.key})'
          : '${e.value}×${fmtNum(m)} (${e.key})';
    }).join(' + ');
    return '$bits = ${fmtNum(molarMass)} g/mol';
  }
}

const List<_Compound> _compounds = [
  _Compound('H2O', 'agua', {'H': 2, 'O': 1}),
  _Compound('NaCl', 'cloruro de sodio', {'Na': 1, 'Cl': 1}),
  _Compound('CO2', 'dióxido de carbono', {'C': 1, 'O': 2}),
  _Compound('NH3', 'amoníaco', {'N': 1, 'H': 3}),
  _Compound('CH4', 'metano', {'C': 1, 'H': 4}),
  _Compound('HCl', 'ácido clorhídrico', {'H': 1, 'Cl': 1}),
  _Compound('NaOH', 'hidróxido de sodio', {'Na': 1, 'O': 1, 'H': 1}),
  _Compound('KCl', 'cloruro de potasio', {'K': 1, 'Cl': 1}),
  _Compound('CaCO3', 'carbonato de calcio', {'Ca': 1, 'C': 1, 'O': 3}),
  _Compound('H2SO4', 'ácido sulfúrico', {'H': 2, 'S': 1, 'O': 4}),
  _Compound('Ca(OH)2', 'hidróxido de calcio', {'Ca': 1, 'O': 2, 'H': 2}),
  _Compound('Al2(SO4)3', 'sulfato de aluminio', {'Al': 2, 'S': 3, 'O': 12}),
  _Compound('C6H12O6', 'glucosa', {'C': 6, 'H': 12, 'O': 6}),
  _Compound('MgSO4', 'sulfato de magnesio', {'Mg': 1, 'S': 1, 'O': 4}),
  _Compound('Fe2O3', 'óxido de hierro(III)', {'Fe': 2, 'O': 3}),
  _Compound('CuSO4', 'sulfato de cobre(II)', {'Cu': 1, 'S': 1, 'O': 4}),
];

_Compound _compoundByFormula(String formula) =>
    _compounds.firstWhere((c) => c.formula == formula);

// ---------------------------------------------------------------------------
// 1. Masa molar
// ---------------------------------------------------------------------------

GeneratedQuestion buildMolarMass(String formula) {
  final c = _compoundByFormula(formula);
  final id = 'gen:molar-mass:direct:$formula';
  final rng = Random(id.hashCode);
  final m = c.molarMass;
  final wrongs = <double>[
    c.massIgnoringSubscript,
    c.parts.containsKey('O') ? m - _atomicMass['O']! : m + 16.0,
    m * 1.1,
  ];
  final built = numericOptions(m, wrongs, (v) => '${fmtNum(v)} g/mol', rng);
  return GeneratedQuestion(
    id: id,
    question: QuizQuestion(
      topic: 'estequiometria',
      question: '¿Cuál es la masa molar del ${c.name} (${c.formula})?',
      options: built.options,
      answer: built.answer,
      explanation:
          'M = ${c.massSteps}. Suma cada elemento multiplicado por su subíndice.',
    ),
  );
}

GeneratedQuestion generateMolarMass(Random rng) =>
    buildMolarMass(_compounds[rng.nextInt(_compounds.length)].formula);

// ---------------------------------------------------------------------------
// 2. Masa <-> moles
// ---------------------------------------------------------------------------

GeneratedQuestion buildMassMoles(String form, String formula, double value) {
  value = norm2(value);
  final c = _compoundByFormula(formula);
  final m = c.molarMass;
  late final double correct;
  late final String question;
  late final String explanation;
  late final List<double> wrongs;
  if (form == 'moles') {
    // value = gramos (entero). ¿Cuántos moles hay en X g?
    final grams = value;
    correct = grams / m;
    question =
        '¿Cuántos moles hay en ${fmtNum(grams, 0)} g de ${c.name} (${c.formula})?';
    wrongs = [grams * m, grams / c.massIgnoringSubscript, correct * 10];
    explanation =
        'n = m/M = ${fmtNum(grams, 0)} g ÷ ${fmtNum(m)} g/mol = ${fmtNum(correct)} mol.';
  } else {
    // form == 'mass': value = moles. ¿Qué masa tienen n mol?
    final moles = value;
    correct = moles * m;
    question =
        '¿Qué masa tienen ${fmtNum(moles)} mol de ${c.name} (${c.formula})?';
    wrongs = [moles / m, moles * c.massIgnoringSubscript, correct * 10];
    explanation =
        'm = n × M = ${fmtNum(moles)} mol × ${fmtNum(m)} g/mol = ${fmtNum(correct)} g.';
  }
  final id = 'gen:mass-moles:$form:${formula}_${value.toStringAsFixed(2)}';
  final rng = Random(id.hashCode);
  final built = numericOptions(
    correct,
    wrongs,
    (v) => form == 'moles' ? '${fmtNum(v)} mol' : '${fmtNum(v)} g',
    rng,
  );
  return GeneratedQuestion(
    id: id,
    question: QuizQuestion(
      topic: 'estequiometria',
      question: question,
      options: built.options,
      answer: built.answer,
      explanation: explanation,
    ),
  );
}

GeneratedQuestion generateMassMoles(Random rng) {
  final c = _compounds[rng.nextInt(_compounds.length)];
  if (rng.nextBool()) {
    // gramos enteros de 10 a 200, de 5 en 5.
    final grams = (2 + rng.nextInt(39)) * 5.0;
    return buildMassMoles('moles', c.formula, grams);
  }
  // moles de 0.25 a 5.00, de 0.25 en 0.25.
  final moles = (1 + rng.nextInt(20)) * 0.25;
  return buildMassMoles('mass', c.formula, moles);
}

// ---------------------------------------------------------------------------
// 3. Molaridad
// ---------------------------------------------------------------------------

GeneratedQuestion buildMolarity(String form, double a, double volMl) {
  a = norm2(a);
  volMl = norm2(volMl);
  late final double correct;
  late final String question;
  late final String explanation;
  late final List<double> wrongs;
  if (form == 'molarity') {
    // a = moles, volMl = volumen en mL. M = n / V(L).
    correct = a / (volMl / 1000);
    question =
        'Disuelves ${fmtNum(a)} mol de un soluto y aforas a ${fmtNum(volMl, 0)} mL. ¿Cuál es la molaridad?';
    wrongs = [a / volMl, a * (volMl / 1000), a / (volMl / 100)];
    explanation =
        'Pasa el volumen a litros: ${fmtNum(volMl, 0)} mL = ${fmtNum(volMl / 1000)} L. '
        'M = n/V = ${fmtNum(a)} mol ÷ ${fmtNum(volMl / 1000)} L = ${fmtNum(correct)} M.';
  } else {
    // form == 'moles': a = molaridad, volMl = volumen. n = M × V(L).
    correct = a * (volMl / 1000);
    question =
        '¿Cuántos moles de soluto hay en ${fmtNum(volMl, 0)} mL de una disolución ${fmtNum(a)} M?';
    wrongs = [a * volMl, a / (volMl / 1000), a * (volMl / 100)];
    explanation =
        'Pasa el volumen a litros: ${fmtNum(volMl, 0)} mL = ${fmtNum(volMl / 1000)} L. '
        'n = M × V = ${fmtNum(a)} M × ${fmtNum(volMl / 1000)} L = ${fmtNum(correct)} mol.';
  }
  final id = 'gen:molarity:$form:${a.toStringAsFixed(2)}_${fmtNum(volMl, 0)}';
  final rng = Random(id.hashCode);
  final built = numericOptions(correct, wrongs, (v) => form == 'molarity' ? '${fmtNum(v)} M' : '${fmtNum(v)} mol', rng);
  return GeneratedQuestion(
    id: id,
    question: QuizQuestion(
      topic: 'disoluciones',
      question: question,
      options: built.options,
      answer: built.answer,
      explanation: explanation,
    ),
  );
}

GeneratedQuestion generateMolarity(Random rng) {
  final volMl = (2 + rng.nextInt(39)) * 50.0; // 100 a 2000 mL
  if (rng.nextBool()) {
    final moles = (1 + rng.nextInt(40)) * 0.05; // 0.05 a 2.00 mol
    return buildMolarity('molarity', moles, volMl);
  }
  final m = (1 + rng.nextInt(20)) * 0.1; // 0.10 a 2.00 M
  return buildMolarity('moles', m, volMl);
}

// ---------------------------------------------------------------------------
// 4. Dilución (C1V1 = C2V2)
// ---------------------------------------------------------------------------

GeneratedQuestion buildDilution(String form, double a, double b, double c) {
  a = norm2(a);
  b = norm2(b);
  c = norm2(c);
  late final double correct;
  late final String question;
  late final String explanation;
  late final List<double> wrongs;
  if (form == 'c2') {
    // a = C1, b = V1 (mL), c = V2 (mL). C2 = C1·V1/V2.
    correct = a * b / c;
    question =
        'Tienes una disolución ${fmtNum(a)} M y tomas ${fmtNum(b, 0)} mL. Los diluyes hasta ${fmtNum(c, 0)} mL. ¿Cuál es la concentración final?';
    wrongs = [a * c / b, a * b / (b + c), a];
    explanation =
        'C₁V₁ = C₂V₂, así que C₂ = C₁V₁/V₂ = ${fmtNum(a)} × ${fmtNum(b, 0)} ÷ ${fmtNum(c, 0)} = ${fmtNum(correct)} M.';
  } else {
    // form == 'v1': a = C1, b = C2, c = V2 (mL). V1 = C2·V2/C1.
    correct = b * c / a;
    question =
        'Quieres preparar ${fmtNum(c, 0)} mL de una disolución ${fmtNum(b)} M a partir de una concentrada ${fmtNum(a)} M. ¿Qué volumen de la concentrada necesitas?';
    wrongs = [b * c * a, a * c / b, c];
    explanation =
        'C₁V₁ = C₂V₂, así que V₁ = C₂V₂/C₁ = ${fmtNum(b)} × ${fmtNum(c, 0)} ÷ ${fmtNum(a)} = ${fmtNum(correct)} mL.';
  }
  final id =
      'gen:dilution:$form:${a.toStringAsFixed(2)}_${b.toStringAsFixed(2)}_${c.toStringAsFixed(2)}';
  final rng = Random(id.hashCode);
  final built = numericOptions(
    correct,
    wrongs,
    (v) => form == 'c2' ? '${fmtNum(v)} M' : '${fmtNum(v)} mL',
    rng,
  );
  return GeneratedQuestion(
    id: id,
    question: QuizQuestion(
      topic: 'disoluciones',
      question: question,
      options: built.options,
      answer: built.answer,
      explanation: explanation,
    ),
  );
}

GeneratedQuestion generateDilution(Random rng) {
  if (rng.nextBool()) {
    final c1 = (5 + rng.nextInt(56)) * 0.1; // 0.50 a 6.00 M
    final v1 = (1 + rng.nextInt(25)) * 10.0; // 10 a 250 mL
    final v2 = (5 + rng.nextInt(36)) * 50.0; // 250 a 2000 mL
    return buildDilution('c2', c1, v1, v2);
  }
  final c1 = (5 + rng.nextInt(56)) * 0.1;
  final c2 = (1 + rng.nextInt(20)) * 0.1; // 0.10 a 2.00 M
  final v2 = (5 + rng.nextInt(36)) * 50.0;
  return buildDilution('v1', c1, c2, v2);
}

// ---------------------------------------------------------------------------
// 5. pH / pOH
// ---------------------------------------------------------------------------

GeneratedQuestion buildPh(String form, int mantissa, int exponent) {
  // [ion] = mantissa × 10^-exponente.
  final logM = log(mantissa) / ln10;
  final p = exponent - logM; // pH o pOH del ion dado
  late final double correct;
  late final String question;
  late final String explanation;
  if (form == 'ph') {
    correct = p;
    question =
        'El pH de una disolución con [H₃O⁺] = $mantissa×10${sup(-exponent)} M es:';
    explanation =
        'pH = −log[H⁺] = −log($mantissa×10${sup(-exponent)}) = $exponent − log $mantissa = ${p.toStringAsFixed(2)}.';
  } else if (form == 'poh') {
    correct = p;
    question =
        'El pOH de una disolución con [OH⁻] = $mantissa×10${sup(-exponent)} M es:';
    explanation =
        'pOH = −log[OH⁻] = −log($mantissa×10${sup(-exponent)}) = $exponent − log $mantissa = ${p.toStringAsFixed(2)}.';
  } else {
    // form == 'ph-from-oh': dan [OH-] y piden el pH.
    correct = 14 - p;
    question =
        'Una disolución tiene [OH⁻] = $mantissa×10${sup(-exponent)} M. Su pH a 25 °C es:';
    explanation =
        'Primero pOH = −log($mantissa×10${sup(-exponent)}) = ${p.toStringAsFixed(2)}. '
        'A 25 °C, pH + pOH = 14, así que pH = 14 − ${p.toStringAsFixed(2)} = ${correct.toStringAsFixed(2)}.';
  }
  final wrongs = <double>[
    exponent + logM, // error de signo clásico
    14 - correct,
    correct + 1,
  ];
  final id = 'gen:ph:$form:${mantissa}_$exponent';
  final rng = Random(id.hashCode);
  final built = numericOptions(
    correct,
    wrongs,
    (v) => v.toStringAsFixed(2),
    rng,
  );
  return GeneratedQuestion(
    id: id,
    question: QuizQuestion(
      topic: 'acido-base',
      question: question,
      options: built.options,
      answer: built.answer,
      explanation: explanation,
    ),
  );
}

GeneratedQuestion generatePh(Random rng) {
  final forms = ['ph', 'poh', 'ph-from-oh'];
  final form = forms[rng.nextInt(forms.length)];
  final mantissa = 1 + rng.nextInt(9); // 1 a 9
  final exponent = 1 + rng.nextInt(12); // 1 a 12
  return buildPh(form, mantissa, exponent);
}

// ---------------------------------------------------------------------------
// 6. Gas ideal (PV = nRT, R = 0.08206 L·atm·mol⁻¹·K⁻¹)
// ---------------------------------------------------------------------------

const double _rGas = 0.08206;

GeneratedQuestion buildGas(String form, double x, double tC, double y) {
  x = norm2(x);
  tC = norm2(tC);
  y = norm2(y);
  final tK = tC + 273.15;
  late final double correct;
  late final String question;
  late final String explanation;
  late final List<double> wrongs;
  if (form == 'volume') {
    // x = n (mol), y = P (atm). V = nRT/P.
    correct = x * _rGas * tK / y;
    question =
        '¿Qué volumen ocupan ${fmtNum(x)} mol de un gas ideal a ${fmtNum(tC, 0)} °C y ${fmtNum(y)} atm?';
    wrongs = [
      x * _rGas * tC / y, // usar °C en vez de K: el error clásico
      x * 8.314 * tK / y, // R equivocado para estas unidades
      x * _rGas * tK * y, // despeje al revés
    ];
    explanation =
        'La temperatura va en kelvin: T = ${fmtNum(tC, 0)} + 273.15 = ${fmtNum(tK)} K. '
        'V = nRT/P = ${fmtNum(x)} × 0.08206 × ${fmtNum(tK)} ÷ ${fmtNum(y)} = ${fmtNum(correct)} L.';
  } else if (form == 'moles') {
    // x = P (atm), y = V (L). n = PV/RT.
    correct = x * y / (_rGas * tK);
    question =
        '¿Cuántos moles hay en ${fmtNum(y)} L de un gas ideal a ${fmtNum(tC, 0)} °C y ${fmtNum(x)} atm?';
    wrongs = [
      x * y / (_rGas * tC),
      x * y * _rGas * tK,
      x * y / (8.314 * tK),
    ];
    explanation =
        'La temperatura va en kelvin: T = ${fmtNum(tC, 0)} + 273.15 = ${fmtNum(tK)} K. '
        'n = PV/RT = ${fmtNum(x)} × ${fmtNum(y)} ÷ (0.08206 × ${fmtNum(tK)}) = ${fmtNum(correct)} mol.';
  } else {
    // form == 'pressure': x = n (mol), y = V (L). P = nRT/V.
    correct = x * _rGas * tK / y;
    question =
        '¿Qué presión ejerce ${fmtNum(x)} mol de un gas ideal en ${fmtNum(y)} L a ${fmtNum(tC, 0)} °C?';
    wrongs = [
      x * _rGas * tC / y,
      x * _rGas * tK * y,
      x * 8.314 * tK / y,
    ];
    explanation =
        'La temperatura va en kelvin: T = ${fmtNum(tC, 0)} + 273.15 = ${fmtNum(tK)} K. '
        'P = nRT/V = ${fmtNum(x)} × 0.08206 × ${fmtNum(tK)} ÷ ${fmtNum(y)} = ${fmtNum(correct)} atm.';
  }
  final id =
      'gen:gas:$form:${x.toStringAsFixed(2)}_${fmtNum(tC, 0)}_${y.toStringAsFixed(2)}';
  final rng = Random(id.hashCode);
  final built = numericOptions(
    correct,
    wrongs,
    (v) => form == 'volume'
        ? '${fmtNum(v)} L'
        : form == 'moles'
            ? '${fmtNum(v)} mol'
            : '${fmtNum(v)} atm',
    rng,
  );
  return GeneratedQuestion(
    id: id,
    question: QuizQuestion(
      topic: 'gases',
      question: question,
      options: built.options,
      answer: built.answer,
      explanation: explanation,
    ),
  );
}

GeneratedQuestion generateGas(Random rng) {
  final forms = ['volume', 'moles', 'pressure'];
  final form = forms[rng.nextInt(forms.length)];
  final tC = (rng.nextInt(13)) * 10.0 + 7; // 7 a 127 °C
  if (form == 'volume') {
    final n = (2 + rng.nextInt(11)) * 0.25; // 0.50 a 3.00 mol
    final p = (1 + rng.nextInt(10)) * 0.25; // 0.25 a 2.50 atm
    return buildGas('volume', n, tC, p);
  }
  if (form == 'moles') {
    final p = (1 + rng.nextInt(12)) * 0.25; // 0.25 a 3.00 atm
    final v = (2 + rng.nextInt(20)) * 1.0; // 2 a 21 L
    return buildGas('moles', p, tC, v);
  }
  final n = (2 + rng.nextInt(11)) * 0.25;
  final v = (2 + rng.nextInt(20)) * 1.0;
  return buildGas('pressure', n, tC, v);
}

// ---------------------------------------------------------------------------
// 7. Estequiometría (reacciones balanceadas)
// ---------------------------------------------------------------------------

class _Reaction {
  const _Reaction(this.equation, this.a, this.b, this.ca, this.cb);
  final String equation;
  final String a; // reactivo dado
  final String b; // producto (o reactivo) pedido
  final int ca; // coeficiente de a
  final int cb; // coeficiente de b
}

const List<_Reaction> _reactions = [
  _Reaction('2 H₂ + O₂ → 2 H₂O', 'H₂', 'H₂O', 2, 2),
  _Reaction('N₂ + 3 H₂ → 2 NH₃', 'H₂', 'NH₃', 3, 2),
  _Reaction('2 Mg + O₂ → 2 MgO', 'Mg', 'MgO', 2, 2),
  _Reaction('CH₄ + 2 O₂ → CO₂ + 2 H₂O', 'CH₄', 'CO₂', 1, 1),
  _Reaction('2 KClO₃ → 2 KCl + 3 O₂', 'KClO₃', 'O₂', 2, 3),
  _Reaction('CaCO₃ → CaO + CO₂', 'CaCO₃', 'CO₂', 1, 1),
  _Reaction('2 Na + Cl₂ → 2 NaCl', 'Na', 'NaCl', 2, 2),
  _Reaction('C + O₂ → CO₂', 'C', 'CO₂', 1, 1),
];

GeneratedQuestion buildStoichiometry(String form, int reaction, double moles) {
  moles = norm2(moles);
  final r = _reactions[reaction];
  late final double correct;
  late final String question;
  if (form == 'product') {
    correct = moles * r.cb / r.ca;
    question =
        'En la reacción ${r.equation}, si reaccionan ${fmtNum(moles)} mol de ${r.a}, ¿cuántos moles de ${r.b} se forman?';
  } else {
    correct = moles * r.ca / r.cb;
    question =
        'En la reacción ${r.equation}, ¿cuántos moles de ${r.a} se necesitan para formar ${fmtNum(moles)} mol de ${r.b}?';
  }
  final wrongs = <double>[
    form == 'product' ? moles * r.ca / r.cb : moles * r.cb / r.ca, // proporción al revés
    moles, // ignorar los coeficientes
    correct * 2,
  ];
  final id = 'gen:stoichiometry:$form:${reaction}_${moles.toStringAsFixed(2)}';
  final rng = Random(id.hashCode);
  final built = numericOptions(correct, wrongs, (v) => '${fmtNum(v)} mol', rng);
  final ratio = form == 'product'
      ? 'La proporción ${r.a}:${r.b} es ${r.ca}:${r.cb}, así que ${fmtNum(moles)} mol × (${r.cb}/${r.ca}) = ${fmtNum(correct)} mol.'
      : 'La proporción ${r.b}:${r.a} es ${r.cb}:${r.ca}, así que ${fmtNum(moles)} mol × (${r.ca}/${r.cb}) = ${fmtNum(correct)} mol.';
  return GeneratedQuestion(
    id: id,
    question: QuizQuestion(
      topic: 'estequiometria',
      question: question,
      options: built.options,
      answer: built.answer,
      explanation: ratio,
    ),
  );
}

GeneratedQuestion generateStoichiometry(Random rng) {
  final reaction = rng.nextInt(_reactions.length);
  final moles = (1 + rng.nextInt(20)) * 0.5; // 0.50 a 10.00 mol
  final form = rng.nextBool() ? 'product' : 'reactant';
  return buildStoichiometry(form, reaction, moles);
}

// ---------------------------------------------------------------------------
// 8. Equilibrio: cociente de reacción Qc
// ---------------------------------------------------------------------------

class _EquilibriumReaction {
  const _EquilibriumReaction(this.equation, this.a, this.b, this.c, this.ca,
      this.cb, this.cc);
  final String equation;
  final String a;
  final String b;
  final String c;
  final int ca;
  final int cb;
  final int cc;
}

const List<_EquilibriumReaction> _equilibriumReactions = [
  _EquilibriumReaction('N₂ + 3 H₂ ⇌ 2 NH₃', 'N₂', 'H₂', 'NH₃', 1, 3, 2),
  _EquilibriumReaction('H₂ + I₂ ⇌ 2 HI', 'H₂', 'I₂', 'HI', 1, 1, 2),
  _EquilibriumReaction('2 SO₂ + O₂ ⇌ 2 SO₃', 'SO₂', 'O₂', 'SO₃', 2, 1, 2),
];

double _powInt(double base, int exp) {
  var r = 1.0;
  for (var i = 0; i < exp; i++) {
    r *= base;
  }
  return r;
}

GeneratedQuestion buildEquilibrium(
    int reaction, double concA, double concB, double concC) {
  concA = norm2(concA);
  concB = norm2(concB);
  concC = norm2(concC);
  final r = _equilibriumReactions[reaction];
  final q = _powInt(concC, r.cc) /
      (_powInt(concA, r.ca) * _powInt(concB, r.cb));
  final qInv = 1 / q;
  final qNoExp = concC / (concA * concB);
  final id =
      'gen:equilibrium-q:qc:${reaction}_${concA.toStringAsFixed(2)}_${concB.toStringAsFixed(2)}_${concC.toStringAsFixed(2)}';
  final rng = Random(id.hashCode);
  String fmtQ(double v) => v < 0.1 ? v.toStringAsFixed(3) : fmtNum(v);
  final built = numericOptions(q, [qInv, qNoExp, q * 10], fmtQ, rng);
  return GeneratedQuestion(
    id: id,
    question: QuizQuestion(
      topic: 'equilibrio',
      question:
          'Para la reacción ${r.equation}, con [${r.a}] = ${fmtNum(concA)} M, [${r.b}] = ${fmtNum(concB)} M y [${r.c}] = ${fmtNum(concC)} M, calcula el cociente de reacción Qc.',
      options: built.options,
      answer: built.answer,
      explanation:
          'Qc = [${r.c}]^${r.cc} / ([${r.a}]^${r.ca} × [${r.b}]^${r.cb}) = ${fmtNum(_powInt(concC, r.cc))} ÷ (${fmtNum(_powInt(concA, r.ca))} × ${fmtNum(_powInt(concB, r.cb))}) = ${fmtQ(q)}. '
          'Los exponentes son los coeficientes: olvidarlos es el error clásico.',
    ),
  );
}

GeneratedQuestion generateEquilibrium(Random rng) {
  const concs = [0.5, 1.0, 1.5, 2.0];
  final reaction = rng.nextInt(_equilibriumReactions.length);
  return buildEquilibrium(
    reaction,
    concs[rng.nextInt(concs.length)],
    concs[rng.nextInt(concs.length)],
    concs[rng.nextInt(concs.length)],
  );
}

// ---------------------------------------------------------------------------
// 9. Termoquímica: calor q = m·c·ΔT
// ---------------------------------------------------------------------------

class _HeatSubstance {
  const _HeatSubstance(this.name, this.c);
  final String name;
  final double c; // J/g·°C
}

const List<_HeatSubstance> _heatSubstances = [
  _HeatSubstance('agua', 4.184),
  _HeatSubstance('aluminio', 0.90),
  _HeatSubstance('hierro', 0.45),
];

GeneratedQuestion buildThermo(int mass, int substance, int dT) {
  final s = _heatSubstances[substance];
  final qJ = mass * s.c * dT;
  final qKj = qJ / 1000;
  final id = 'gen:thermo:heat:${mass}_${substance}_$dT';
  final rng = Random(id.hashCode);
  final built = numericOptions(
    qKj,
    [qJ, mass * dT / 1000, s.c * dT / 1000], // sin convertir a kJ; sin c; sin m
    (v) => '${fmtNum(v)} kJ',
    rng,
  );
  return GeneratedQuestion(
    id: id,
    question: QuizQuestion(
      topic: 'termo-cinetica',
      question:
          '¿Cuánto calor (en kJ) se necesita para calentar $mass g de ${s.name} $dT °C? (c = ${fmtNum(s.c)} J/g·°C)',
      options: built.options,
      answer: built.answer,
      explanation:
          'q = m·c·ΔT = $mass g × ${fmtNum(s.c)} J/g·°C × $dT °C = ${fmtNum(qJ)} J = ${fmtNum(qKj)} kJ. '
          'Recuerda pasar de J a kJ dividiendo entre 1000.',
    ),
  );
}

GeneratedQuestion generateThermo(Random rng) {
  final mass = (5 + rng.nextInt(46)) * 10; // 50 a 500 g
  final substance = rng.nextInt(_heatSubstances.length);
  final dT = (1 + rng.nextInt(10)) * 5; // 5 a 50 °C
  return buildThermo(mass, substance, dT);
}

// ---------------------------------------------------------------------------
// 10. Tabla periódica (datos reales de los 118 elementos)
// ---------------------------------------------------------------------------

GeneratedQuestion buildPeriodic(String form, String symbol) {
  final e = allElements.firstWhere((el) => el.symbol == symbol);
  final id = 'gen:periodic:$form:$symbol';
  final rng = Random(id.hashCode);
  late final String question;
  late final List<String> candidates;
  late final String explanation;
  if (form == 'z') {
    question = '¿Cuál es el número atómico del ${e.name}?';
    candidates = [
      e.atomicNumber.toString(),
      (e.atomicNumber + 1).toString(),
      (e.atomicNumber - 1).toString(),
      (e.atomicNumber + 10).toString(),
    ];
    explanation =
        'El número atómico es la cantidad de protones: el ${e.name} tiene Z = ${e.atomicNumber}.';
  } else if (form == 'symbol') {
    final others = List<ChemicalElement>.of(allElements)
      ..shuffle(rng)
      ..removeWhere((el) => el.symbol == symbol);
    question = '¿Cuál es el símbolo químico del ${e.name}?';
    candidates = [e.symbol, ...others.take(3).map((el) => el.symbol)];
    explanation = 'El símbolo del ${e.name} es ${e.symbol}.';
  } else if (form == 'mass') {
    question = '¿Cuál es la masa atómica aproximada del ${e.name}?';
    final m = e.numericMass;
    candidates = [
      fmtNum(m),
      fmtNum(m + 2),
      fmtNum(m * 1.1),
      fmtNum(m * 0.9),
    ];
    explanation =
        'La masa atómica del ${e.name} es ${e.mass} u (aprox. ${fmtNum(m)} u).';
  } else {
    // form == 'group': 4 grupos distintos (el periodo puede coincidir
    // con el grupo, así que se rellena con grupos vecinos válidos).
    question = '¿En qué grupo de la tabla periódica está el ${e.name}?';
    final groups = <String>[e.column.toString()];
    for (final v in [
      e.column + 1,
      e.column - 1,
      e.period,
      e.column + 2,
      e.column - 2,
      18,
      7,
    ]) {
      if (groups.length >= 4) break;
      if (v >= 1 && v <= 18 && !groups.contains(v.toString())) {
        groups.add(v.toString());
      }
    }
    candidates = groups;
    explanation =
        'El ${e.name} está en el grupo ${e.column} y en el periodo ${e.period}.';
  }
  final built = buildOptions(candidates, rng);
  return GeneratedQuestion(
    id: id,
    question: QuizQuestion(
      topic: 'tabla',
      question: question,
      options: built.options,
      answer: built.answer,
      explanation: explanation,
    ),
  );
}

GeneratedQuestion generatePeriodic(Random rng) {
  final forms = ['z', 'symbol', 'mass', 'group'];
  final form = forms[rng.nextInt(forms.length)];
  final e = allElements[rng.nextInt(allElements.length)];
  return buildPeriodic(form, e.symbol);
}

// ---------------------------------------------------------------------------
// 11. Enlace químico (geometría y tipo de enlace)
// ---------------------------------------------------------------------------

class _Molecule {
  const _Molecule(this.formula, this.name, this.geometry, this.bond);
  final String formula;
  final String name;
  final String? geometry; // null si no tiene geometría molecular
  final String bond; // 'Iónico', 'Covalente' o 'Covalente polar'
}

const List<_Molecule> _molecules = [
  _Molecule('CH₄', 'metano', 'Tetraédrica', 'Covalente'),
  _Molecule('NH₃', 'amoníaco', 'Piramidal trigonal', 'Covalente polar'),
  _Molecule('H₂O', 'agua', 'Angular', 'Covalente polar'),
  _Molecule('CO₂', 'dióxido de carbono', 'Lineal', 'Covalente'),
  _Molecule('BF₃', 'trifluoruro de boro', 'Plana trigonal', 'Covalente'),
  _Molecule('NaCl', 'cloruro de sodio', null, 'Iónico'),
  _Molecule('HCl', 'cloruro de hidrógeno', 'Lineal', 'Covalente polar'),
  _Molecule('O₂', 'oxígeno', 'Lineal', 'Covalente'),
];

const _geometries = [
  'Tetraédrica',
  'Piramidal trigonal',
  'Angular',
  'Lineal',
  'Plana trigonal',
];

const _bondTypes = [
  'Iónico',
  'Covalente',
  'Covalente polar',
  'Metálico',
  'De hidrógeno',
];

GeneratedQuestion buildBonding(String form, String formula) {
  final m = _molecules.firstWhere((x) => x.formula == formula);
  if (form == 'geometry' && m.geometry == null) {
    throw ArgumentError('La molécula $formula no tiene geometría molecular');
  }
  final id = 'gen:bonding:$form:$formula';
  final rng = Random(id.hashCode);
  late final String question;
  late final List<String> candidates;
  late final String explanation;
  if (form == 'geometry') {
    question = '¿Qué geometría molecular tiene el ${m.name} (${m.formula})?';
    candidates = [m.geometry!, ..._geometries.where((g) => g != m.geometry)];
    explanation =
        'El ${m.name} (${m.formula}) tiene geometría ${m.geometry!.toLowerCase()} según la teoría VSEPR.';
  } else {
    question = '¿Qué tipo de enlace predomina en el ${m.name} (${m.formula})?';
    candidates = [m.bond, ..._bondTypes.where((b) => b != m.bond)];
    explanation =
        'En el ${m.name} (${m.formula}) predomina el enlace ${m.bond.toLowerCase()}.';
  }
  final built = buildOptions(candidates, rng);
  return GeneratedQuestion(
    id: id,
    question: QuizQuestion(
      topic: 'enlace',
      question: question,
      options: built.options,
      answer: built.answer,
      explanation: explanation,
    ),
  );
}

GeneratedQuestion generateBonding(Random rng) {
  if (rng.nextBool()) {
    final withGeometry =
        _molecules.where((m) => m.geometry != null).toList();
    final m = withGeometry[rng.nextInt(withGeometry.length)];
    return buildBonding('geometry', m.formula);
  }
  final m = _molecules[rng.nextInt(_molecules.length)];
  return buildBonding('bond', m.formula);
}

// ---------------------------------------------------------------------------
// Entrada general: por tema, adaptativa y reconstrucción desde la id
// ---------------------------------------------------------------------------

/// Qué tipos de generador alimentan cada tema.
const Map<String, List<String>> topicGeneratorTypes = {
  'estequiometria': ['molar-mass', 'mass-moles', 'stoichiometry'],
  'gases': ['gas'],
  'disoluciones': ['molarity', 'dilution'],
  'acido-base': ['ph'],
  'equilibrio': ['equilibrium-q'],
  'termo-cinetica': ['thermo'],
  'tabla': ['periodic'],
  'enlace': ['bonding'],
  // Bachillerato: mismos generadores, con números del nivel básico.
  'bach-estequiometria': ['molar-mass', 'mass-moles', 'stoichiometry'],
  'bach-gases': ['gas'],
  'bach-disoluciones': ['molarity', 'dilution'],
  'bach-acido-base': ['ph'],
  // 'organica' y 'laboratorio' no tienen generador: sus niveles son
  // solo de banco (ver PracticarScreen._levelCount).
};

GeneratedQuestion generateOfType(String type, Random rng) {
  switch (type) {
    case 'molar-mass':
      return generateMolarMass(rng);
    case 'mass-moles':
      return generateMassMoles(rng);
    case 'molarity':
      return generateMolarity(rng);
    case 'dilution':
      return generateDilution(rng);
    case 'ph':
      return generatePh(rng);
    case 'gas':
      return generateGas(rng);
    case 'stoichiometry':
      return generateStoichiometry(rng);
    case 'equilibrium-q':
      return generateEquilibrium(rng);
    case 'thermo':
      return generateThermo(rng);
    case 'periodic':
      return generatePeriodic(rng);
    case 'bonding':
      return generateBonding(rng);
    default:
      throw ArgumentError('Tipo de generador desconocido: $type');
  }
}

/// Genera una pregunta nueva del tema dado.
GeneratedQuestion generateForTopic(String topic, Random rng) {
  final types = topicGeneratorTypes[topic] ?? topicGeneratorTypes['estequiometria']!;
  return generateOfType(types[rng.nextInt(types.length)], rng);
}

/// Genera una pregunta pesando hacia los temas más débiles: el 65% de las
/// veces sale del primer tema de [weakestFirst] (el más débil) y el resto
/// de cualquiera de la lista.
GeneratedQuestion generateAdaptive(List<String> weakestFirst, Random rng) {
  if (weakestFirst.isEmpty) {
    return generateForTopic('estequiometria', rng);
  }
  final topic = rng.nextDouble() < 0.65
      ? weakestFirst.first
      : weakestFirst[rng.nextInt(weakestFirst.length)];
  return generateForTopic(topic, rng);
}

/// Reconstruye exactamente la pregunta de una id estable. Devuelve null
/// si la id no se reconoce o sus parámetros no son válidos.
GeneratedQuestion? rebuildGenerated(String id) {
  try {
    final parts = id.split(':');
    if (parts.length < 4 || parts[0] != 'gen') return null;
    final type = parts[1];
    final form = parts[2];
    final params = parts.sublist(3).join(':');
    switch (type) {
      case 'molar-mass':
        return buildMolarMass(params);
      case 'mass-moles':
        final p = params.split('_');
        return buildMassMoles(form, p[0], double.parse(p[1]));
      case 'molarity':
        final p = params.split('_');
        return buildMolarity(form, double.parse(p[0]), double.parse(p[1]));
      case 'dilution':
        final p = params.split('_');
        return buildDilution(form, double.parse(p[0]), double.parse(p[1]),
            double.parse(p[2]));
      case 'ph':
        final p = params.split('_');
        return buildPh(form, int.parse(p[0]), int.parse(p[1]));
      case 'gas':
        final p = params.split('_');
        return buildGas(form, double.parse(p[0]), double.parse(p[1]),
            double.parse(p[2]));
      case 'stoichiometry':
        final p = params.split('_');
        return buildStoichiometry(form, int.parse(p[0]), double.parse(p[1]));
      case 'equilibrium-q':
        final p = params.split('_');
        return buildEquilibrium(int.parse(p[0]), double.parse(p[1]),
            double.parse(p[2]), double.parse(p[3]));
      case 'thermo':
        final p = params.split('_');
        return buildThermo(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
      case 'periodic':
        return buildPeriodic(form, params);
      case 'bonding':
        return buildBonding(form, params);
      default:
        return null;
    }
  } catch (_) {
    return null;
  }
}

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

import '../data/i18n/generator_i18n.dart';

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
/// Redondeo mitad hacia arriba: 2×1.008 + 15.999 es 18.015 en decimal,
/// pero en coma flotante es 18.014999… y toStringAsFixed lo bajaría a
/// 18.01; el agua debe salir 18.02 (auditoría A23). El +1e-9 absorbe
/// solo el error de representación (≪ 1e-9), no cambia ningún valor
/// que esté de verdad por debajo de la mitad.
String fmtNum(double v, [int decimals = 2]) {
  final factor = pow(10, decimals).toDouble();
  final rounded = ((v * factor) + 1e-9).round() / factor;
  var s = rounded.toStringAsFixed(decimals);
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
  // Valores de libro con 2 decimales: el cálculo tiene que coincidir
  // con los datos que se muestran ("Datos: H = 1,01...") — con 3
  // decimales la suma de los datos mostrados difería 0,01 g/mol de
  // la respuesta (7.0: Al₂(SO₄)₃, H₂SO₄, Ca(OH)₂, C₆H₁₂O₆, CH₄, NH₃).
  'H': 1.01,
  'C': 12.01,
  'N': 14.01,
  'O': 16.0,
  'Na': 22.99,
  'Mg': 24.31,
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

  /// Masa ignorando TODOS los subíndices: cada elemento cuenta como 1.
  /// Es otro error clásico, distinto del anterior cuando el compuesto
  /// tiene varios elementos con subíndice (p. ej. H₂SO₄: 50.08 frente
  /// a 49.07; en Ca(OH)₂: 58.1 frente a 57.09).
  double get massIgnoringAllSubscripts {
    var m = 0.0;
    parts.forEach((el, _) => m += _atomicMass[el]!);
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

  /// Masas atómicas de los elementos del compuesto, SIN la suma:
  /// para la pregunta de masa molar (la suma ES la respuesta, así
  /// que el desglose con el total no vale ahí; fix5, punto 14).
  String get atomicMassList {
    final bits = parts.entries.map((e) {
      final m = _atomicMass[e.key]!;
      return '${e.key} = ${fmtNum(m)}';
    }).join('; ');
    return bits;
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

/// Masas molares ERRÓNEAS de un compuesto, cada una de un error químico
/// distinto (ignorar subíndices, omitir un elemento, contarlo de más),
/// ordenadas del error más clásico al menos. Sirve para que los
/// distractores de masa molar y de masa<->moles nunca colapsen con la
/// correcta ni entre sí (auditoría A14): "ignorar el subíndice" vale lo
/// mismo que la masa correcta cuando todos los subíndices son 1 (NaCl,
/// HCl, NaOH…), y "restar un O" vale lo mismo que "ignorar el
/// subíndice" en Ca(OH)₂ (58.1 en los dos casos). `numericOptions`
/// elimina los duplicados y toma los 3 primeros distintos.
List<double> _wrongMassPool(_Compound c) {
  final m = c.molarMass;
  var worstMass = 0.0;
  var worstN = 1;
  c.parts.forEach((el, n) {
    if (n > worstN) {
      worstN = n;
      worstMass = _atomicMass[el]!;
    }
  });
  final first = c.parts.entries.first;
  final last = c.parts.entries.last;
  return [
    c.massIgnoringSubscript,
    c.massIgnoringAllSubscripts,
    if (c.parts.containsKey('O')) m - _atomicMass['O']!,
    if (c.parts.containsKey('H'))
      m - c.parts['H']! * _atomicMass['H']!,
    m + worstMass, // contar de más el elemento mayoritario
    m - first.value * _atomicMass[first.key]!, // omitir un elemento
    m - last.value * _atomicMass[last.key]!,
    m + first.value * _atomicMass[first.key]!, // contarlo dos veces
    m + last.value * _atomicMass[last.key]!,
  ];
}

/// Una masa molar errónea del compuesto, distinta de la correcta:
/// el primer valor del pool que no coincide con ella.
double _wrongMass(_Compound c) {
  final m = c.molarMass;
  for (final w in _wrongMassPool(c)) {
    if (fmtNum(w) != fmtNum(m)) return w;
  }
  return m * 2;
}

// ---------------------------------------------------------------------------
// 1. Masa molar
// ---------------------------------------------------------------------------

GeneratedQuestion buildMolarMass(String formula) {
  final c = _compoundByFormula(formula);
  final id = 'gen:molar-mass:direct:$formula';
  final rng = Random(id.hashCode);
  final m = c.molarMass;
  // Distractores: errores químicos distintos (ver _wrongMassPool).
  // numericOptions elimina duplicados y toma los 3 primeros
  // distintos, así que si dos errores clásicos dan el mismo número
  // (Ca(OH)₂: ignorar el subíndice y restar un O valen 58.1),
  // entra el siguiente error de la lista y no hay relleno ±5 %.
  final wrongs = _wrongMassPool(c);
  final built = numericOptions(m, wrongs, (v) => '${fmtNum(v)} g/mol', rng);
  return GeneratedQuestion(
    id: id,
    question: QuizQuestion(
      topic: 'estequiometria',
      // Fix5, punto 14: la pregunta da las masas atómicas (el dato
      // que hace falta para sumar); el desglose con el total NO
      // vale aquí porque ese total ES la respuesta.
      question: gt('molarMassQ', {
        'name': genSubstanceName(c.name),
        'formula': c.formula,
        'data': c.atomicMassList,
      }),
      options: built.options,
      answer: built.answer,
      explanation:
          gt('molarMassE', {'steps': c.massSteps}),
      // Pregunta de cálculo (fix3, punto 7): se contesta con el
      // teclado numérico; la unidad se muestra junto al campo.
      numericAnswer: m,
      numericUnit: 'g/mol',
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
  // Fix5, punto 14: la masa molar con su desglose va EN la pregunta
  // (n = m/M no se puede resolver sin ella, y en mitad de un nivel
  // no se puede salir a buscarla). El desglose enseña, además.
  final data = 'M(${c.formula}) = ${c.massSteps}';
  late final double correct;
  late final String question;
  late final String explanation;
  late final List<double> wrongs;
  if (form == 'moles') {
    // value = gramos (entero). ¿Cuántos moles hay en X g?
    final grams = value;
    correct = grams / m;
    question = gt('massMolesQ', {
      'g': fmtNum(grams, 0),
      'name': genSubstanceName(c.name),
      'formula': c.formula,
      'data': data,
    });
    wrongs = [grams * m, grams / _wrongMass(c), correct * 10];
    explanation =
        gt('massMolesE', {'g': fmtNum(grams, 0), 'm': fmtNum(m), 'v': fmtNum(correct)});
  } else {
    // form == 'mass': value = moles. ¿Qué masa tienen n mol?
    final moles = value;
    correct = moles * m;
    question = gt('massMassQ', {
      'n': fmtNum(moles),
      'name': genSubstanceName(c.name),
      'formula': c.formula,
      'data': data,
    });
    wrongs = [moles / m, moles * _wrongMass(c), correct * 10];
    explanation =
        gt('massMassE', {'n': fmtNum(moles), 'm': fmtNum(m), 'v': fmtNum(correct)});
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
      // Pregunta de cálculo (fix3, punto 7): teclado numérico.
      numericAnswer: correct,
      numericUnit: form == 'moles' ? 'mol' : 'g',
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
        gt('molarityQ', {'n': fmtNum(a), 'v': fmtNum(volMl, 0)});
    wrongs = [a / volMl, a * (volMl / 1000), a / (volMl / 100)];
    explanation =
        gt('molarityE', {'v': fmtNum(volMl, 0), 'l': fmtNum(volMl / 1000), 'n': fmtNum(a), 'c': fmtNum(correct)});
  } else {
    // form == 'moles': a = molaridad, volMl = volumen. n = M × V(L).
    correct = a * (volMl / 1000);
    question =
        gt('molesFromMQ', {'v': fmtNum(volMl, 0), 'm': fmtNum(a)});
    wrongs = [a * volMl, a / (volMl / 1000), a * (volMl / 100)];
    explanation =
        gt('molesFromME', {'v': fmtNum(volMl, 0), 'l': fmtNum(volMl / 1000), 'm': fmtNum(a), 'c': fmtNum(correct)});
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
      // Pregunta de cálculo (fix3, punto 7): teclado numérico.
      numericAnswer: correct,
      numericUnit: form == 'molarity' ? 'M' : 'mol',
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
        gt('dilutionC2Q', {'c1': fmtNum(a), 'v1': fmtNum(b, 0), 'v2': fmtNum(c, 0)});
    // Distractores: errores químicos distintos. "a" (responder con C₁,
    // ignorando los volúmenes) colapsa con la correcta cuando V₁ = V₂,
    // así que el pool sigue con otros dos errores y numericOptions
    // toma los 3 primeros distintos (auditoría A14).
    wrongs = [
      a * c / b, // volúmenes al revés
      a * b / (b + c), // usar el volumen total
      a, // ignorar los volúmenes
      a * c / (b + c), // V₂ sobre el volumen total
      a * (b + c) / c, // volúmenes sumados en el numerador
      a * b * 1000 / c, // desliz de unidades mL/L (solo si todo lo demás colapsa: V₁ = V₂)
    ];
    explanation =
        gt('dilutionC2E', {'c1': fmtNum(a), 'v1': fmtNum(b, 0), 'v2': fmtNum(c, 0), 'c': fmtNum(correct)});
  } else {
    // form == 'v1': a = C1, b = C2, c = V2 (mL). V1 = C2·V2/C1.
    correct = b * c / a;
    question =
        gt('dilutionV1Q', {'v2': fmtNum(c, 0), 'c2': fmtNum(b), 'c1': fmtNum(a)});
    // Distractores: errores químicos distintos. "c" (responder con V₂,
    // ignorando las concentraciones) colapsa con la correcta cuando
    // C₁ = C₂, así que el pool sigue con otros dos errores y
    // numericOptions toma los 3 primeros distintos (auditoría A14).
    wrongs = [
      b * c * a, // multiplicar en vez de dividir
      a * c / b, // concentraciones al revés
      c, // ignorar las concentraciones
      b * c / (a + b), // C₂·V₂/(C₁+C₂)
      c * (a + b) / b, // V₂·(C₁+C₂)/C₂
    ];
    explanation =
        gt('dilutionV1E', {'c2': fmtNum(b), 'v2': fmtNum(c, 0), 'c1': fmtNum(a), 'v': fmtNum(correct)});
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
      // Pregunta de cálculo (fix3, punto 7): teclado numérico.
      numericAnswer: correct,
      numericUnit: form == 'c2' ? 'M' : 'mL',
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
  // 'v1': al diluir, C2 SIEMPRE es menor que C1 (7.0: antes C2 podía
  // superar a C1 y pedía V1 > V2, o sea concentrar al diluir, imposible).
  final c1 = (10 + rng.nextInt(51)) * 0.1; // 1.00 a 6.00 M
  final c2 = (1 + rng.nextInt(9)) * 0.1; // 0.10 a 0.90 M, siempre < C1
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
        gt('phQ', {'mant': '$mantissa', 'sup': sup(-exponent)});
    explanation =
        gt('phE', {'mant': '$mantissa', 'sup': sup(-exponent), 'exp': '$exponent', 'p': p.toStringAsFixed(2)});
  } else if (form == 'poh') {
    correct = p;
    question =
        gt('pohQ', {'mant': '$mantissa', 'sup': sup(-exponent)});
    explanation =
        gt('pohE', {'mant': '$mantissa', 'sup': sup(-exponent), 'exp': '$exponent', 'p': p.toStringAsFixed(2)});
  } else {
    // form == 'ph-from-oh': dan [OH-] y piden el pH.
    correct = 14 - p;
    question = gt('phFromOhQ', {
      'mant': '$mantissa',
      'sup': sup(-exponent),
      // Fix5, punto 14: pH + pOH = 14 es el dato que hace falta
      // para pasar del pOH al pH; sin él la pregunta no se puede
      // resolver.
      'data': 'pH + pOH = 14',
    });
    explanation =
        gt('phFromOhE', {'mant': '$mantissa', 'sup': sup(-exponent), 'p': p.toStringAsFixed(2), 'c': correct.toStringAsFixed(2)});
  }
  // Distractores: errores químicos distintos. Con mantisa 1 el "error
  // de signo" (exponente + logM) y "14 − correcta" valen lo mismo que
  // la correcta cuando p = 7 ([H⁺] = 1×10⁻⁷), así que el pool sigue
  // con otros errores y numericOptions toma los 3 primeros distintos
  // (auditoría A14). El orden conserva los 3 primeros de antes en
  // todos los casos no degenerados.
  final wrongs = <double>[
    exponent + logM, // error de signo clásico
    14 - correct,
    correct + 1,
    correct - 1,
    -correct, // signo cambiado
    p, // para 'ph-from-oh': responder con el pOH en vez del pH
    exponent.toDouble(), // ignorar la mantisa
    14 - (exponent + logM),
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
      // Pregunta de cálculo (fix3, punto 7): teclado numérico.
      // En el formulario 'poh' lo que se pide es el pOH, así que la
      // unidad/etiqueta es "pOH" (auditoría A7); en 'ph' y en
      // 'ph-from-oh' el resultado pedido es el pH.
      numericAnswer: correct,
      numericUnit: form == 'poh' ? 'pOH' : 'pH',
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
  // Fix5, punto 14: R es el dato que hace falta para PV = nRT;
  // sin él la pregunta no se puede resolver. (_rGas.toString() da
  // '0.08206'; fmtNum lo recortaría a 2 decimales.)
  final data = 'R = ${_rGas.toString()} L·atm/(mol·K)';
  late final double correct;
  late final String question;
  late final String explanation;
  late final List<double> wrongs;
  if (form == 'volume') {
    // x = n (mol), y = P (atm). V = nRT/P.
    correct = x * _rGas * tK / y;
    question = gt('gasVolumeQ', {
      'n': fmtNum(x),
      't': fmtNum(tC, 0),
      'p': fmtNum(y),
      'data': data,
    });
    wrongs = [
      x * _rGas * tC / y, // usar °C en vez de K: el error clásico
      x * 8.314 * tK / y, // R equivocado para estas unidades
      x * _rGas * tK * y, // despeje al revés
    ];
    explanation =
        gt('gasVolumeE', {'t': fmtNum(tC, 0), 'tk': fmtNum(tK), 'n': fmtNum(x), 'p': fmtNum(y), 'v': fmtNum(correct)});
  } else if (form == 'moles') {
    // x = P (atm), y = V (L). n = PV/RT.
    correct = x * y / (_rGas * tK);
    question = gt('gasMolesQ', {
      'v': fmtNum(y),
      't': fmtNum(tC, 0),
      'p': fmtNum(x),
      'data': data,
    });
    wrongs = [
      x * y / (_rGas * tC),
      x * y * _rGas * tK,
      x * y / (8.314 * tK),
    ];
    explanation =
        gt('gasMolesE', {'t': fmtNum(tC, 0), 'tk': fmtNum(tK), 'p': fmtNum(x), 'v': fmtNum(y), 'n': fmtNum(correct)});
  } else {
    // form == 'pressure': x = n (mol), y = V (L). P = nRT/V.
    correct = x * _rGas * tK / y;
    question = gt('gasPressureQ', {
      'n': fmtNum(x),
      'v': fmtNum(y),
      't': fmtNum(tC, 0),
      'data': data,
    });
    wrongs = [
      x * _rGas * tC / y,
      x * _rGas * tK * y,
      x * 8.314 * tK / y,
    ];
    explanation =
        gt('gasPressureE', {'t': fmtNum(tC, 0), 'tk': fmtNum(tK), 'n': fmtNum(x), 'v': fmtNum(y), 'p': fmtNum(correct)});
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
      // Pregunta de cálculo (fix3, punto 7): teclado numérico.
      numericAnswer: correct,
      numericUnit: form == 'volume'
          ? 'L'
          : form == 'moles'
              ? 'mol'
              : 'atm',
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
  // Auditoría A9: en 6 de 8 reacciones ca = cb y la respuesta era
  // copiar el número dado. Ahora todas ejercitan la proporción
  // (ca ≠ cb): se pregunta por la especie cuyo coeficiente difiere
  // del de la dada. Las reacciones 1 (N₂+3H₂→2NH₃) y 4 (KClO₃) ya
  // la ejercitaban y NO se tocan: mismas especies, mismos
  // coeficientes y mismas respuestas correctas.
  _Reaction('2 H₂ + O₂ → 2 H₂O', 'O₂', 'H₂O', 1, 2),
  _Reaction('N₂ + 3 H₂ → 2 NH₃', 'H₂', 'NH₃', 3, 2),
  _Reaction('2 Mg + O₂ → 2 MgO', 'O₂', 'MgO', 1, 2),
  _Reaction('CH₄ + 2 O₂ → CO₂ + 2 H₂O', 'CH₄', 'H₂O', 1, 2),
  _Reaction('2 KClO₃ → 2 KCl + 3 O₂', 'KClO₃', 'O₂', 2, 3),
  _Reaction('2 H₂O → 2 H₂ + O₂', 'H₂O', 'O₂', 2, 1),
  _Reaction('2 Na + Cl₂ → 2 NaCl', 'Cl₂', 'NaCl', 1, 2),
  _Reaction('4 Fe + 3 O₂ → 2 Fe₂O₃', 'Fe', 'Fe₂O₃', 4, 2),
];

GeneratedQuestion buildStoichiometry(String form, int reaction, double moles) {
  moles = norm2(moles);
  final r = _reactions[reaction];
  late final double correct;
  late final String question;
  if (form == 'product') {
    correct = moles * r.cb / r.ca;
    question =
        gt('stoichProductQ', {'eq': r.equation, 'n': fmtNum(moles), 'a': r.a, 'b': r.b});
  } else {
    correct = moles * r.ca / r.cb;
    question =
        gt('stoichReactantQ', {'eq': r.equation, 'a': r.a, 'n': fmtNum(moles), 'b': r.b});
  }
  // Distractores: errores químicos distintos. Con ca ≠ cb la
  // proporción al revés y "ignorar los coeficientes" ya no valen lo
  // mismo que la correcta; pero "correcta × 2" colapsa con "ignorar
  // los coeficientes" cuando cb = ca/2 (p. ej. 2:1), así que el pool
  // sigue con "sumar los coeficientes" y numericOptions toma los 3
  // primeros distintos (auditoría A9/A14).
  final sumRatio = form == 'product'
      ? moles * (r.ca + r.cb) / r.ca
      : moles * (r.ca + r.cb) / r.cb;
  final wrongs = <double>[
    form == 'product' ? moles * r.ca / r.cb : moles * r.cb / r.ca, // proporción al revés
    moles, // ignorar los coeficientes
    correct * 2,
    sumRatio, // sumar los coeficientes en vez de usar la proporción
  ];
  final id = 'gen:stoichiometry:$form:${reaction}_${moles.toStringAsFixed(2)}';
  final rng = Random(id.hashCode);
  final built = numericOptions(correct, wrongs, (v) => '${fmtNum(v)} mol', rng);
  final ratio = form == 'product'
      ? gt('stoichProductE', {'a': r.a, 'b': r.b, 'ca': '${r.ca}', 'cb': '${r.cb}', 'n': fmtNum(moles), 'v': fmtNum(correct)})
      : gt('stoichReactantE', {'b': r.b, 'a': r.a, 'cb': '${r.cb}', 'ca': '${r.ca}', 'n': fmtNum(moles), 'v': fmtNum(correct)});
  return GeneratedQuestion(
    id: id,
    question: QuizQuestion(
      topic: 'estequiometria',
      question: question,
      options: built.options,
      answer: built.answer,
      explanation: ratio,
      // Pregunta de cálculo (fix3, punto 7): teclado numérico.
      numericAnswer: correct,
      numericUnit: 'mol',
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
          gt('equilibQ', {'eq': r.equation, 'a': r.a, 'ca': fmtNum(concA), 'b': r.b, 'cb': fmtNum(concB), 'c': r.c, 'cc': fmtNum(concC)}),
      options: built.options,
      answer: built.answer,
      explanation:
          gt('equilibE', {'c': r.c, 'cc': '${r.cc}', 'a': r.a, 'ca': '${r.ca}', 'b': r.b, 'cb': '${r.cb}', 'qc1': fmtNum(_powInt(concC, r.cc)), 'qa': fmtNum(_powInt(concA, r.ca)), 'qb': fmtNum(_powInt(concB, r.cb)), 'q': fmtQ(q)}),
      // Pregunta de cálculo (fix3, punto 7): teclado numérico. El Qc
      // es adimensional, así que no lleva unidad.
      numericAnswer: q,
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
          gt('thermoQ', {'m': '$mass', 'name': genSubstanceName(s.name), 'dt': '$dT', 'c': fmtNum(s.c)}),
      options: built.options,
      answer: built.answer,
      explanation:
          gt('thermoE', {'m': '$mass', 'c': fmtNum(s.c), 'dt': '$dT', 'qj': fmtNum(qJ), 'qk': fmtNum(qKj)}),
      // Pregunta de cálculo (fix3, punto 7): teclado numérico.
      numericAnswer: qKj,
      numericUnit: 'kJ',
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
    question = gt('periodicZQ', {'name': genElementName(e.atomicNumber, e.name)});
    // (7.0): los distractores tienen que ser números atómicos reales
    // (1–118): Z−1 era 0 para el hidrógeno y Z+1/Z+10 se pasaban de
    // 118 para el oganesón. Se rodean dentro del rango válido.
    final z = e.atomicNumber;
    final plus1 = z + 1 <= 118 ? z + 1 : z - 2;
    final minus1 = z - 1 >= 1 ? z - 1 : z + 2;
    final plus10 = z + 10 <= 118 ? z + 10 : z - 10;
    candidates = [
      z.toString(),
      plus1.toString(),
      minus1.toString(),
      plus10.toString(),
    ];
    explanation =
        gt('periodicZE', {'name': genElementName(e.atomicNumber, e.name), 'z': '${e.atomicNumber}'});
  } else if (form == 'symbol') {
    final others = List<ChemicalElement>.of(allElements)
      ..shuffle(rng)
      ..removeWhere((el) => el.symbol == symbol);
    question = gt('periodicSymbolQ', {'name': genElementName(e.atomicNumber, e.name)});
    candidates = [e.symbol, ...others.take(3).map((el) => el.symbol)];
    explanation = gt('periodicSymbolE', {'name': genElementName(e.atomicNumber, e.name), 'symbol': e.symbol});
  } else if (form == 'mass') {
    question = gt('periodicMassQ', {'name': genElementName(e.atomicNumber, e.name)});
    final m = e.numericMass;
    candidates = [
      fmtNum(m),
      fmtNum(m + 2),
      fmtNum(m * 1.1),
      fmtNum(m * 0.9),
    ];
    explanation =
        gt('periodicMassE', {'name': genElementName(e.atomicNumber, e.name), 'mass': e.mass, 'm': fmtNum(m)});
  } else {
    // form == 'group': 4 grupos distintos (el periodo puede coincidir
    // con el grupo, así que se rellena con grupos vecinos válidos).
    question = gt('periodicGroupQ', {'name': genElementName(e.atomicNumber, e.name)});
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
        gt('periodicGroupE', {'name': genElementName(e.atomicNumber, e.name), 'g': '${e.column}', 'p': '${e.period}'});
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
  _Molecule('CO₂', 'dióxido de carbono', 'Lineal', 'Covalente polar'),
  _Molecule('BF₃', 'trifluoruro de boro', 'Plana trigonal', 'Covalente polar'),
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
    question = gt('bondingGeometryQ', {'name': genSubstanceName(m.name), 'formula': m.formula});
    candidates = [genGeometry(m.geometry!), ..._geometries.where((g) => g != m.geometry).map(genGeometry)];
    explanation =
        gt('bondingGeometryE', {'name': genSubstanceName(m.name), 'formula': m.formula, 'geom': genGeometry(m.geometry!).toLowerCase()});
  } else {
    question = gt('bondingBondQ', {'name': genSubstanceName(m.name), 'formula': m.formula});
    candidates = [genBond(m.bond), ..._bondTypes.where((b) => b != m.bond).map(genBond)];
    explanation =
        gt('bondingBondE', {'name': genSubstanceName(m.name), 'formula': m.formula, 'bond': genBond(m.bond).toLowerCase()});
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
  final g = _generateOfTypeRaw(type, rng);
  return _withDifficulty(g);
}

GeneratedQuestion _generateOfTypeRaw(String type, Random rng) {
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

/// Dificultad de cada tipo de pregunta generada (ver points.dart):
/// el cálculo estequiométrico y el equilibrio son lo más difícil;
/// reconocer un elemento de la tabla es lo más fácil.
int difficultyForType(String type) {
  switch (type) {
    case 'stoichiometry':
    case 'equilibrium-q':
      return 3;
    case 'periodic':
      return 1;
    default:
      return 2;
  }
}

GeneratedQuestion _withDifficulty(GeneratedQuestion g) {
  final type = g.id.split(':').length > 1 ? g.id.split(':')[1] : '';
  return GeneratedQuestion(
    id: g.id,
    question: g.question.copyWith(difficulty: difficultyForType(type)),
  );
}

/// Genera una VARIANTE de una pregunta fallada (v6): el mismo concepto
/// con otros datos, nunca la misma pregunta. Para una id generada,
/// otra pregunta del mismo tipo; para una del banco cuyo tema tiene
/// generador, una pregunta nueva de ese tema; para banco sin generador
/// (orgánica, laboratorio), null: el repaso usa otra pregunta del banco
/// del mismo tema (ver PracticarScreen).
GeneratedQuestion? generateVariantForFailed(
    String failedId, String topic, Random rng) {
  var guard = 0;
  if (failedId.startsWith('gen:')) {
    final type = failedId.split(':')[1];
    while (guard < 10) {
      guard++;
      final g = generateOfType(type, rng);
      if (g.id != failedId) return g;
    }
    return generateOfType(type, rng);
  }
  if (topicGeneratorTypes.containsKey(topic)) {
    return generateForTopic(topic, rng);
  }
  return null;
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
  final g = _rebuildRaw(id);
  return g == null ? null : _withDifficulty(g);
}

GeneratedQuestion? _rebuildRaw(String id) {
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

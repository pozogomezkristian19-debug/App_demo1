// Solucionadores avanzados de Melli-Qui v4 (matemática pura, sin Flutter).
// Cada función devuelve un SolverResult con los pasos y el resumen.
// Las fórmulas son las aproximaciones estándar de los libros de texto:
// el pH poliprótico resuelve la primera disociación con la cuadrática y
// suma la contribución de la segunda (y tercera) etapa; las mezclas
// suman las contribuciones de [H⁺] o [OH⁻] de cada componente; la
// solubilidad usa s = (Ksp / (a^a · b^b))^(1/(a+b)); las valoraciones
// usan los balances de moles y, para el ácido débil, Henderson-
// Hasselbalch e hidrólisis en el punto de equivalencia.

import 'dart:math' as math;

const double _kw = 1.0e-14; // producto iónico del agua a 25 °C

double _log10(double x) => math.log(x) / math.ln10;

double _pow10(double x) => math.pow(10, x).toDouble();

/// Número con 4 cifras significativas, en notación científica cuando
/// conviene (p. ej. 1.34×10⁻⁵).
String fmtNum(double x) {
  if (x == 0) return '0';
  final ax = x.abs();
  if (ax >= 1000 || ax < 0.001) {
    final e = _log10(ax).floor();
    final m = x / _pow10(e.toDouble());
    final mant = (double.parse(m.toStringAsPrecision(3))).toString();
    const sup = {'-': '⁻', '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹'};
    final exp = e.toString().split('').map((c) => sup[c] ?? c).join();
    return '$mant×10$exp';
  }
  return double.parse(x.toStringAsPrecision(4)).toString();
}

String fmtPh(double x) => x.toStringAsFixed(2);

/// Resultado de un solucionador: pasos + resumen, o un error explicado.
class SolverResult {
  const SolverResult({required this.lines, required this.summary, this.error});
  final List<String> lines;
  final String summary;
  final String? error;
}

/// Raíz positiva de x² + K·x − K·C = 0 (disociación de un ácido o base
/// débil de concentración C y constante K).
double _quadraticDissociation(double k, double c) {
  return (-k + math.sqrt(k * k + 4 * k * c)) / 2;
}

// ---------------------------------------------------------------------------
// pH de ácidos polipróticos (dipróticos y tripróticos)
// ---------------------------------------------------------------------------

SolverResult polyproticPh({
  required double c,
  required double ka1,
  required double ka2,
  double? ka3,
}) {
  if (c <= 0 || ka1 <= 0 || ka2 <= 0) {
    return const SolverResult(
      lines: [],
      summary: '',
      error: 'Revisa los datos: la concentración y las Ka deben ser mayores que cero.',
    );
  }
  final x1 = _quadraticDissociation(ka1, c);
  // Segunda etapa con el ion común H⁺ de la primera: se resuelve
  // y² + (x₁ + Ka₂)·y − Ka₂·x₁ = 0.
  final y2 =
      (-(x1 + ka2) + math.sqrt((x1 + ka2) * (x1 + ka2) + 4 * ka2 * x1)) / 2;
  var h = x1 + y2;
  final lines = <String>[
    'Primera disociación: H₂A ⇌ H⁺ + HA⁻ (Ka₁ = ${fmtNum(ka1)}).',
    'Se resuelve x² + Ka₁·x − Ka₁·C = 0 con C = ${fmtNum(c)} mol/L.',
    'x₁ = ${fmtNum(x1)} mol/L: es la [H⁺] de la primera etapa (grado de disociación ${(x1 / c * 100).toStringAsFixed(1)} %).',
    'Segunda disociación: HA⁻ ⇌ H⁺ + A²⁻ (Ka₂ = ${fmtNum(ka2)}). Con el H⁺ ya presente, aporta y₂ = ${fmtNum(y2)} mol/L.',
  ];
  if (ka3 != null && ka3 > 0) {
    final h2 = h;
    final y3 =
        (-(h2 + ka3) + math.sqrt((h2 + ka3) * (h2 + ka3) + 4 * ka3 * h2)) / 2;
    h += y3;
    lines.add('Tercera disociación: aporta y₃ = ${fmtNum(y3)} mol/L (despreciable frente a las otras dos).');
  }
  lines.add('[H⁺] total ≈ ${fmtNum(x1)} + ${fmtNum(y2)}${ka3 != null && ka3 > 0 ? ' + …' : ''} = ${fmtNum(h)} mol/L.');
  final ph = -_log10(h);
  lines.add('pH = −log(${fmtNum(h)}) = ${fmtPh(ph)}.');
  return SolverResult(
    lines: lines,
    summary: 'pH ≈ ${fmtPh(ph)}  ([H⁺] ≈ ${fmtNum(h)} mol/L)',
  );
}

// ---------------------------------------------------------------------------
// pH de mezclas de dos ácidos o dos bases que NO reaccionan entre sí
// ---------------------------------------------------------------------------

enum MixtureKind { strongAcid, weakAcid, strongBase, weakBase }

class MixtureComponent {
  const MixtureComponent({required this.kind, required this.c, this.k});
  final MixtureKind kind;
  final double c; // mol/L
  final double? k; // Ka (ácido débil) o Kb (base débil)
}

SolverResult mixturePh(MixtureComponent a, MixtureComponent b) {
  final aAcid = a.kind == MixtureKind.strongAcid || a.kind == MixtureKind.weakAcid;
  final bAcid = b.kind == MixtureKind.strongAcid || b.kind == MixtureKind.weakAcid;
  if (aAcid != bAcid) {
    return const SolverResult(
      lines: [],
      summary: '',
      error:
          'Un ácido y una base SÍ reaccionan entre sí (neutralización). Este solucionador es solo para mezclas que no reaccionan: dos ácidos o dos bases.',
    );
  }
  if (a.c <= 0 || b.c <= 0) {
    return const SolverResult(
      lines: [],
      summary: '',
      error: 'Las concentraciones deben ser mayores que cero.',
    );
  }
  double contribution(MixtureComponent comp) {
    switch (comp.kind) {
      case MixtureKind.strongAcid:
      case MixtureKind.strongBase:
        return comp.c;
      case MixtureKind.weakAcid:
      case MixtureKind.weakBase:
        final k = comp.k;
        if (k == null || k <= 0) return 0;
        return _quadraticDissociation(k, comp.c);
    }
  }

  String describe(MixtureComponent comp) {
    switch (comp.kind) {
      case MixtureKind.strongAcid:
        return 'ácido fuerte ${fmtNum(comp.c)} M → aporta ${fmtNum(comp.c)} mol/L de H⁺';
      case MixtureKind.weakAcid:
        return 'ácido débil ${fmtNum(comp.c)} M (Ka = ${fmtNum(comp.k ?? 0)}) → aporta ${fmtNum(contribution(comp))} mol/L de H⁺';
      case MixtureKind.strongBase:
        return 'base fuerte ${fmtNum(comp.c)} M → aporta ${fmtNum(comp.c)} mol/L de OH⁻';
      case MixtureKind.weakBase:
        return 'base débil ${fmtNum(comp.c)} M (Kb = ${fmtNum(comp.k ?? 0)}) → aporta ${fmtNum(contribution(comp))} mol/L de OH⁻';
    }
  }

  final ca = contribution(a);
  final cb = contribution(b);
  final total = ca + cb;
  if (aAcid) {
    final ph = -_log10(total);
    return SolverResult(
      lines: [
        'Componente 1: ${describe(a)}.',
        'Componente 2: ${describe(b)}.',
        'Como no reaccionan entre sí, las [H⁺] se suman: [H⁺] = ${fmtNum(ca)} + ${fmtNum(cb)} = ${fmtNum(total)} mol/L.',
        'pH = −log(${fmtNum(total)}) = ${fmtPh(ph)}.',
      ],
      summary: 'pH ≈ ${fmtPh(ph)}  ([H⁺] ≈ ${fmtNum(total)} mol/L)',
    );
  }
  final poh = -_log10(total);
  final ph = 14 - poh;
  return SolverResult(
    lines: [
      'Componente 1: ${describe(a)}.',
      'Componente 2: ${describe(b)}.',
      'Como no reaccionan entre sí, las [OH⁻] se suman: [OH⁻] = ${fmtNum(ca)} + ${fmtNum(cb)} = ${fmtNum(total)} mol/L.',
      'pOH = −log(${fmtNum(total)}) = ${fmtPh(poh)}; pH = 14 − pOH = ${fmtPh(ph)}.',
    ],
    summary: 'pH ≈ ${fmtPh(ph)}  ([OH⁻] ≈ ${fmtNum(total)} mol/L)',
  );
}

// ---------------------------------------------------------------------------
// Solubilidad y Ksp (sal A_aB_b)
// ---------------------------------------------------------------------------

SolverResult solubilityFromKsp({
  required double ksp,
  required int a,
  required int b,
}) {
  if (ksp <= 0 || a < 1 || b < 1) {
    return const SolverResult(
      lines: [],
      summary: '',
      error: 'Revisa los datos: Ksp > 0 y los subíndices a y b deben ser al menos 1.',
    );
  }
  final denom = math.pow(a, a) * math.pow(b, b);
  final s = math.pow(ksp / denom, 1 / (a + b)).toDouble();
  return SolverResult(
    lines: [
      'Para la sal AₐB_b: AₐB_b(s) ⇌ a A + b B, con Ksp = aᵃ·bᵇ·s^(a+b).',
      'Ksp = ${fmtNum(ksp)}; a = $a, b = $b → aᵃ·bᵇ = ${fmtNum(denom.toDouble())}.',
      's = (Ksp / ${fmtNum(denom.toDouble())})^(1/${a + b}) = ${fmtNum(s)} mol/L.',
      '[A] = a·s = ${fmtNum(a * s)} mol/L; [B] = b·s = ${fmtNum(b * s)} mol/L.',
    ],
    summary: 'Solubilidad s ≈ ${fmtNum(s)} mol/L',
  );
}

SolverResult kspFromSolubility({
  required double s,
  required int a,
  required int b,
}) {
  if (s <= 0 || a < 1 || b < 1) {
    return const SolverResult(
      lines: [],
      summary: '',
      error: 'Revisa los datos: la solubilidad debe ser mayor que cero y a, b al menos 1.',
    );
  }
  final ksp = math.pow(a, a) * math.pow(b, b) * math.pow(s, a + b);
  return SolverResult(
    lines: [
      'Para la sal AₐB_b: Ksp = aᵃ·bᵇ·s^(a+b).',
      'a = $a, b = $b, s = ${fmtNum(s)} mol/L.',
      'Ksp = ${a}ᵃ·${b}ᵇ·(${fmtNum(s)})^${a + b} = ${fmtNum(ksp.toDouble())}.',
    ],
    summary: 'Ksp ≈ ${fmtNum(ksp.toDouble())}',
  );
}

// ---------------------------------------------------------------------------
// pH de disoluciones de sales (con o sin hidrólisis)
// ---------------------------------------------------------------------------

enum SaltKind { neutral, acidic, basic, amphoteric }

SolverResult saltPh({
  required SaltKind kind,
  required double c,
  double? ka,
  double? kb,
}) {
  if (c <= 0) {
    return const SolverResult(
      lines: [],
      summary: '',
      error: 'La concentración debe ser mayor que cero.',
    );
  }
  switch (kind) {
    case SaltKind.neutral:
      return const SolverResult(
        lines: [
          'La sal viene de un ácido fuerte y una base fuerte.',
          'Ni el catión ni el anión se hidrolizan: no aportan H⁺ ni OH⁻.',
          'La disolución es neutra.',
        ],
        summary: 'pH = 7.00',
      );
    case SaltKind.acidic:
      if (ka == null || ka <= 0) {
        return const SolverResult(
          lines: [],
          summary: '',
          error: 'Falta la Ka del catión ácido (por ejemplo, Ka(NH₄⁺) = 5.6×10⁻¹⁰).',
        );
      }
      final h = _quadraticDissociation(ka, c);
      final ph = -_log10(h);
      return SolverResult(
        lines: [
          'La sal viene de un ácido fuerte y una base débil: el catión se hidroliza y actúa como ácido débil (Ka = ${fmtNum(ka)}).',
          '[H⁺] se calcula con x² + Ka·x − Ka·C = 0, con C = ${fmtNum(c)} mol/L.',
          '[H⁺] = ${fmtNum(h)} mol/L.',
          'pH = −log(${fmtNum(h)}) = ${fmtPh(ph)}.',
        ],
        summary: 'pH ≈ ${fmtPh(ph)}  (disolución ácida)',
      );
    case SaltKind.basic:
      double? kbValue = kb;
      if (kbValue == null && ka != null && ka > 0) {
        kbValue = _kw / ka;
      }
      if (kbValue == null || kbValue <= 0) {
        return const SolverResult(
          lines: [],
          summary: '',
          error:
              'Falta la Kb del anión básico (o la Ka del ácido conjugado, de donde Kb = Kw / Ka).',
        );
      }
      final oh = _quadraticDissociation(kbValue, c);
      final poh = -_log10(oh);
      final ph = 14 - poh;
      return SolverResult(
        lines: [
          'La sal viene de un ácido débil y una base fuerte: el anión se hidroliza y actúa como base débil (Kb = ${fmtNum(kbValue)}).',
          '[OH⁻] se calcula con x² + Kb·x − Kb·C = 0, con C = ${fmtNum(c)} mol/L.',
          '[OH⁻] = ${fmtNum(oh)} mol/L; pOH = ${fmtPh(poh)}.',
          'pH = 14 − pOH = ${fmtPh(ph)}.',
        ],
        summary: 'pH ≈ ${fmtPh(ph)}  (disolución básica)',
      );
    case SaltKind.amphoteric:
      if (ka == null || ka <= 0 || kb == null || kb <= 0) {
        return const SolverResult(
          lines: [],
          summary: '',
          error:
              'Faltan la Ka del catión ácido y la Kb del anión básico para compararlas.',
        );
      }
      final pka = -_log10(ka);
      final pkb = -_log10(kb);
      final ph = 7 + 0.5 * (pka - pkb);
      // El veredicto se decide con el pH redondeado a 2 decimales,
      // para no llamar "ácida" a una disolución de pH 7.00.
      final rounded = double.parse(ph.toStringAsFixed(2));
      final verdict = rounded > 7
          ? 'básica (el anión hidroliza más que el catión)'
          : rounded < 7
              ? 'ácida (el catión hidroliza más que el anión)'
              : 'neutra (ambos hidrolizan igual)';
      return SolverResult(
        lines: [
          'La sal viene de un ácido débil y una base débil: se hidrolizan el catión (Ka = ${fmtNum(ka)}) y el anión (Kb = ${fmtNum(kb)}).',
          'El pH no depende de la concentración: pH = 7 + ½(pKa − pKb).',
          'pKa = ${fmtPh(pka)}; pKb = ${fmtPh(pkb)}.',
          'pH = 7 + ½(${fmtPh(pka)} − ${fmtPh(pkb)}) = ${fmtPh(ph)}.',
        ],
        summary: 'pH ≈ ${fmtPh(ph)}  (disolución $verdict)',
      );
  }
}

// ---------------------------------------------------------------------------
// Valoraciones
// ---------------------------------------------------------------------------

SolverResult titrationStrongStrong({
  required double ca,
  required double vaMl,
  required double cb,
  required double vbMl,
}) {
  if (ca <= 0 || vaMl <= 0 || cb <= 0 || vbMl < 0) {
    return const SolverResult(
      lines: [],
      summary: '',
      error: 'Revisa los datos: concentraciones y volúmenes deben ser positivos.',
    );
  }
  final veq = ca * vaMl / cb;
  final lines = <String>[
    'Moles de ácido: n = Cₐ·Vₐ = ${fmtNum(ca)} × ${fmtNum(vaMl)} mL = ${fmtNum(ca * vaMl / 1000)} mol.',
    'Volumen de equivalencia: Veq = Cₐ·Vₐ / C_b = ${fmtNum(veq)} mL.',
  ];
  String summary;
  if ((vbMl - veq).abs() < 1e-9) {
    lines.add('Has añadido exactamente el volumen de equivalencia: solo queda la sal, que no se hidroliza.');
    summary = 'pH = 7.00 (punto de equivalencia)';
  } else if (vbMl < veq) {
    final h = (ca * vaMl - cb * vbMl) / (vaMl + vbMl);
    final ph = -_log10(h);
    lines.add('Antes de la equivalencia sobra ácido: [H⁺] = (CₐVₐ − C_bV_b) / (Vₐ + V_b) = ${fmtNum(h)} mol/L.');
    lines.add('pH = −log(${fmtNum(h)}) = ${fmtPh(ph)}.');
    summary = 'pH ≈ ${fmtPh(ph)}  (antes de la equivalencia)';
  } else {
    final oh = (cb * vbMl - ca * vaMl) / (vaMl + vbMl);
    final ph = 14 + _log10(oh);
    lines.add('Después de la equivalencia sobra base: [OH⁻] = (C_bV_b − CₐVₐ) / (Vₐ + V_b) = ${fmtNum(oh)} mol/L.');
    lines.add('pH = 14 + log(${fmtNum(oh)}) = ${fmtPh(ph)}.');
    summary = 'pH ≈ ${fmtPh(ph)}  (después de la equivalencia)';
  }
  return SolverResult(lines: lines, summary: summary);
}

SolverResult titrationWeakStrong({
  required double ca,
  required double vaMl,
  required double ka,
  required double cb,
  required double vbMl,
}) {
  if (ca <= 0 || vaMl <= 0 || cb <= 0 || ka <= 0 || vbMl < 0) {
    return const SolverResult(
      lines: [],
      summary: '',
      error: 'Revisa los datos: concentraciones, Ka y volúmenes deben ser positivos.',
    );
  }
  final veq = ca * vaMl / cb;
  final pka = -_log10(ka);
  final lines = <String>[
    'Ácido débil (Ka = ${fmtNum(ka)}, pKa = ${fmtPh(pka)}) con base fuerte.',
    'Volumen de equivalencia: Veq = Cₐ·Vₐ / C_b = ${fmtNum(veq)} mL.',
    'Semiequivalencia (V_b = ${fmtNum(veq / 2)} mL): pH = pKa = ${fmtPh(pka)}.',
  ];
  String summary;
  if (vbMl < 1e-9) {
    final h = _quadraticDissociation(ka, ca);
    final ph = -_log10(h);
    lines.add('Sin base añadida: [H⁺] del ácido débil = ${fmtNum(h)} mol/L; pH = ${fmtPh(ph)}.');
    summary = 'pH ≈ ${fmtPh(ph)}  (ácido solo)';
  } else if ((vbMl - veq).abs() < 1e-9) {
    final cSalt = ca * vaMl / (vaMl + veq);
    final kb = _kw / ka;
    final oh = _quadraticDissociation(kb, cSalt);
    final ph = 14 + _log10(oh);
    lines.add('En la equivalencia solo queda la base conjugada A⁻ (${fmtNum(cSalt)} M), que se hidroliza: Kb = Kw/Ka = ${fmtNum(kb)}.');
    lines.add('[OH⁻] = ${fmtNum(oh)} mol/L; pH = ${fmtPh(ph)}.');
    summary = 'pH ≈ ${fmtPh(ph)}  (punto de equivalencia, básico)';
  } else if (vbMl < veq) {
    final ratio = vbMl / (veq - vbMl);
    final ph = pka + _log10(ratio);
    lines.add('Zona tampón: pH = pKa + log([A⁻]/[HA]) = ${fmtPh(pka)} + log(${fmtNum(ratio)}) = ${fmtPh(ph)}.');
    summary = 'pH ≈ ${fmtPh(ph)}  (zona tampón)';
  } else {
    final oh = (cb * vbMl - ca * vaMl) / (vaMl + vbMl);
    final ph = 14 + _log10(oh);
    lines.add('Después de la equivalencia sobra base: [OH⁻] = ${fmtNum(oh)} mol/L; pH = ${fmtPh(ph)}.');
    summary = 'pH ≈ ${fmtPh(ph)}  (después de la equivalencia)';
  }
  return SolverResult(lines: lines, summary: summary);
}

SolverResult titrationRedox({
  required double cFe,
  required double vFeMl,
  required double cMnO4,
  required double vAddedMl,
}) {
  if (cFe <= 0 || vFeMl <= 0 || cMnO4 <= 0 || vAddedMl < 0) {
    return const SolverResult(
      lines: [],
      summary: '',
      error: 'Revisa los datos: concentraciones y volúmenes deben ser positivos.',
    );
  }
  // MnO₄⁻ + 5 Fe²⁺ + 8 H⁺ → Mn²⁺ + 5 Fe³⁺ + 4 H₂O
  final nFe = cFe * vFeMl / 1000;
  final veq = (nFe / 5) / cMnO4 * 1000;
  final lines = <String>[
    'Reacción: MnO₄⁻ + 5 Fe²⁺ + 8 H⁺ → Mn²⁺ + 5 Fe³⁺ + 4 H₂O (1 mol de MnO₄⁻ oxida 5 mol de Fe²⁺).',
    'Moles de Fe²⁺: n = ${fmtNum(cFe)} × ${fmtNum(vFeMl)} mL = ${fmtNum(nFe)} mol.',
    'Moles de MnO₄⁻ en la equivalencia: ${fmtNum(nFe)} / 5 = ${fmtNum(nFe / 5)} mol.',
    'Volumen de equivalencia: Veq = ${fmtNum(nFe / 5)} / ${fmtNum(cMnO4)} = ${fmtNum(veq)} mL.',
  ];
  String summary;
  if ((vAddedMl - veq).abs() < 1e-9) {
    lines.add('Has añadido exactamente el volumen de equivalencia: todo el Fe²⁺ se oxidó a Fe³⁺.');
    summary = 'Punto de equivalencia: ${fmtNum(veq)} mL de KMnO₄';
  } else if (vAddedMl < veq) {
    final nRemaining = nFe - 5 * cMnO4 * vAddedMl / 1000;
    lines.add('Antes de la equivalencia: quedan ${fmtNum(nRemaining)} mol de Fe²⁺ sin oxidar.');
    summary = 'Faltan ${fmtNum(veq - vAddedMl)} mL de KMnO₄ para la equivalencia';
  } else {
    final nExcess = cMnO4 * vAddedMl / 1000 - nFe / 5;
    lines.add('Después de la equivalencia: sobran ${fmtNum(nExcess)} mol de MnO₄⁻ (la disolución se tiñe de rosa).');
    summary = 'Exceso de KMnO₄: ${fmtNum(nExcess)} mol (te pasaste ${fmtNum(vAddedMl - veq)} mL)';
  }
  return SolverResult(lines: lines, summary: summary);
}

SolverResult backTitration({
  required double sampleMassG,
  required double molarMass,
  required double cHcl,
  required double vHclMl,
  required double cNaoh,
  required double vNaohMl,
  required double hclPerAnalyte,
}) {
  if (sampleMassG <= 0 ||
      molarMass <= 0 ||
      cHcl <= 0 ||
      vHclMl <= 0 ||
      cNaoh <= 0 ||
      vNaohMl < 0 ||
      hclPerAnalyte < 1) {
    return const SolverResult(
      lines: [],
      summary: '',
      error: 'Revisa los datos: masas, concentraciones y volúmenes deben ser positivos.',
    );
  }
  final nHclAdded = cHcl * vHclMl / 1000;
  final nNaoh = cNaoh * vNaohMl / 1000;
  final nHclReacted = nHclAdded - nNaoh;
  if (nHclReacted <= 0) {
    return const SolverResult(
      lines: [],
      summary: '',
      error:
          'El NaOH gastado es mayor o igual que el HCl añadido: no queda HCl que haya reaccionado con la muestra. Revisa los volúmenes.',
    );
  }
  final nAnalyte = nHclReacted / hclPerAnalyte;
  final massAnalyte = nAnalyte * molarMass;
  final percent = massAnalyte / sampleMassG * 100;
  return SolverResult(
    lines: [
      'HCl añadido (en exceso): n = ${fmtNum(cHcl)} × ${fmtNum(vHclMl)} mL = ${fmtNum(nHclAdded)} mol.',
      'HCl sobrante (lo que gasta el NaOH): n = ${fmtNum(cNaoh)} × ${fmtNum(vNaohMl)} mL = ${fmtNum(nNaoh)} mol.',
      'HCl que reaccionó con la muestra: ${fmtNum(nHclAdded)} − ${fmtNum(nNaoh)} = ${fmtNum(nHclReacted)} mol.',
      'Moles de analito: ${fmtNum(nHclReacted)} / $hclPerAnalyte = ${fmtNum(nAnalyte)} mol.',
      'Masa de analito: ${fmtNum(nAnalyte)} × ${fmtNum(molarMass)} g/mol = ${fmtNum(massAnalyte)} g.',
      'Porcentaje en la muestra: ${fmtNum(massAnalyte)} / ${fmtNum(sampleMassG)} × 100 = ${percent.toStringAsFixed(1)} %.',
    ],
    summary: 'La muestra contiene ${percent.toStringAsFixed(1)} % de analito (${fmtNum(massAnalyte)} g)',
  );
}

SolverResult potentiometric({
  required List<double> volumesMl,
  required List<double> ph,
}) {
  if (volumesMl.length != ph.length || volumesMl.length < 3) {
    return const SolverResult(
      lines: [],
      summary: '',
      error: 'Escribe al menos 3 pares de datos (volumen y pH) separados por comas.',
    );
  }
  final lines = <String>[
    'El punto de equivalencia es donde el pH cambia más rápido: se busca el máximo de ΔpH/ΔV (primera derivada).',
  ];
  var bestIndex = 0;
  var bestSlope = -1.0;
  for (var i = 0; i < volumesMl.length - 1; i++) {
    final dv = volumesMl[i + 1] - volumesMl[i];
    if (dv <= 0) {
      return const SolverResult(
        lines: [],
        summary: '',
        error: 'Los volúmenes deben ir en orden creciente.',
      );
    }
    final slope = (ph[i + 1] - ph[i]) / dv;
    lines.add(
        'Entre ${fmtNum(volumesMl[i])} y ${fmtNum(volumesMl[i + 1])} mL: ΔpH/ΔV = ${slope.toStringAsFixed(2)} por mL.');
    if (slope > bestSlope) {
      bestSlope = slope;
      bestIndex = i;
    }
  }
  final veq = (volumesMl[bestIndex] + volumesMl[bestIndex + 1]) / 2;
  lines.add(
      'El salto mayor está entre ${fmtNum(volumesMl[bestIndex])} y ${fmtNum(volumesMl[bestIndex + 1])} mL.');
  return SolverResult(
    lines: lines,
    summary: 'Punto de equivalencia ≈ ${fmtNum(veq)} mL',
  );
}

// ---------------------------------------------------------------------------
// Balanceo redox por el método de semirreacciones (ion-electrón)
// ---------------------------------------------------------------------------

class RedoxReaction {
  const RedoxReaction({
    required this.name,
    required this.equation,
    required this.oxidation,
    required this.reduction,
    required this.steps,
  });
  final String name;
  final String equation;
  final String oxidation;
  final String reduction;
  final List<String> steps;
}

const List<RedoxReaction> redoxReactions = [
  RedoxReaction(
    name: 'Permanganato + Fe²⁺ (medio ácido)',
    equation: 'MnO₄⁻ + 5 Fe²⁺ + 8 H⁺ → Mn²⁺ + 5 Fe³⁺ + 4 H₂O',
    oxidation: 'Fe²⁺ → Fe³⁺ + e⁻  (×5)',
    reduction: 'MnO₄⁻ + 8 H⁺ + 5 e⁻ → Mn²⁺ + 4 H₂O',
    steps: [
      'El Mn pasa de +7 (en MnO₄⁻) a +2 (en Mn²⁺): gana 5 e⁻, se reduce.',
      'El Fe pasa de +2 a +3: pierde 1 e⁻, se oxida.',
      'La semirreacción de oxidación se multiplica por 5 para igualar los 5 electrones.',
      'Se suman ambas semirreacciones y se cancelan los electrones.',
    ],
  ),
  RedoxReaction(
    name: 'Dicromato + Fe²⁺ (medio ácido)',
    equation: 'Cr₂O₇²⁻ + 6 Fe²⁺ + 14 H⁺ → 2 Cr³⁺ + 6 Fe³⁺ + 7 H₂O',
    oxidation: 'Fe²⁺ → Fe³⁺ + e⁻  (×6)',
    reduction: 'Cr₂O₇²⁻ + 14 H⁺ + 6 e⁻ → 2 Cr³⁺ + 7 H₂O',
    steps: [
      'El Cr pasa de +6 a +3: cada Cr gana 3 e⁻; con 2 Cr son 6 e⁻ en total.',
      'El Fe²⁺ pierde 1 e⁻: su semirreacción se multiplica por 6.',
      'Se balancean los O con H₂O y los H con H⁺ (medio ácido).',
      'Se suman las semirreacciones y se cancelan los 6 electrones.',
    ],
  ),
  RedoxReaction(
    name: 'Zinc + Cu²⁺',
    equation: 'Zn + Cu²⁺ → Zn²⁺ + Cu',
    oxidation: 'Zn → Zn²⁺ + 2 e⁻',
    reduction: 'Cu²⁺ + 2 e⁻ → Cu',
    steps: [
      'El Zn pasa de 0 a +2: pierde 2 e⁻, se oxida (es el reductor).',
      'El Cu²⁺ pasa a Cu⁰: gana 2 e⁻, se reduce (es el oxidante).',
      'Los 2 electrones ya están igualados: se suman directamente.',
    ],
  ),
  RedoxReaction(
    name: 'Cobre + HNO₃ concentrado',
    equation: 'Cu + 4 HNO₃ → Cu(NO₃)₂ + 2 NO₂↑ + 2 H₂O',
    oxidation: 'Cu → Cu²⁺ + 2 e⁻',
    reduction: 'NO₃⁻ + 2 H⁺ + e⁻ → NO₂ + H₂O  (×2)',
    steps: [
      'El Cu pasa de 0 a +2: pierde 2 e⁻.',
      'El N pasa de +5 (en NO₃⁻) a +4 (en NO₂): gana 1 e⁻ por cada NO₃⁻.',
      'Se multiplica la reducción por 2 para igualar los electrones.',
      'Dos iones NO₃⁻ más quedan como espectadores en el Cu(NO₃)₂: por eso hacen falta 4 HNO₃ en total.',
    ],
  ),
  RedoxReaction(
    name: 'Permanganato + H₂O₂ (medio ácido)',
    equation: '2 MnO₄⁻ + 5 H₂O₂ + 6 H⁺ → 2 Mn²⁺ + 5 O₂↑ + 8 H₂O',
    oxidation: 'H₂O₂ → O₂ + 2 H⁺ + 2 e⁻  (×5)',
    reduction: 'MnO₄⁻ + 8 H⁺ + 5 e⁻ → Mn²⁺ + 4 H₂O  (×2)',
    steps: [
      'El O pasa de −1 (en H₂O₂) a 0 (en O₂): pierde 2 e⁻ por molécula.',
      'El Mn pasa de +7 a +2: gana 5 e⁻.',
      'El mínimo común múltiplo es 10 e⁻: oxidación ×5 y reducción ×2.',
      'Se suman y se cancelan los 10 electrones.',
    ],
  ),
  RedoxReaction(
    name: 'Cloro + Br⁻',
    equation: 'Cl₂ + 2 Br⁻ → 2 Cl⁻ + Br₂',
    oxidation: '2 Br⁻ → Br₂ + 2 e⁻',
    reduction: 'Cl₂ + 2 e⁻ → 2 Cl⁻',
    steps: [
      'El Cl pasa de 0 a −1: gana 2 e⁻, se reduce.',
      'El Br pasa de −1 a 0: pierde 2 e⁻, se oxida.',
      'Los electrones ya están igualados: se suman directamente.',
    ],
  ),
  RedoxReaction(
    name: 'Magnesio + HCl',
    equation: 'Mg + 2 HCl → MgCl₂ + H₂↑',
    oxidation: 'Mg → Mg²⁺ + 2 e⁻',
    reduction: '2 H⁺ + 2 e⁻ → H₂',
    steps: [
      'El Mg pasa de 0 a +2: pierde 2 e⁻.',
      'El H⁺ pasa a H₂: gana 2 e⁻.',
      'El Cl⁻ es espectador: no cambia su número de oxidación.',
    ],
  ),
  RedoxReaction(
    name: 'Yodo + tiosulfato (yodometría)',
    equation: 'I₂ + 2 S₂O₃²⁻ → 2 I⁻ + S₄O₆²⁻',
    oxidation: '2 S₂O₃²⁻ → S₄O₆²⁻ + 2 e⁻',
    reduction: 'I₂ + 2 e⁻ → 2 I⁻',
    steps: [
      'El I pasa de 0 a −1: gana 2 e⁻.',
      'El S pasa de +2 (en S₂O₃²⁻) a +2.5 de media (en S₄O₆²⁻): entre los dos iones pierde 2 e⁻.',
      'Es la reacción de la yodometría: el tiosulfato valora el yodo.',
    ],
  ),
];

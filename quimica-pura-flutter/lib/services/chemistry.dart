// Cálculo de masas molares a partir de una fórmula química.
// Acepta paréntesis, p. ej. H2SO4, Ca(OH)2, Al2(SO4)3.

import '../data/periodic_table.dart';

class MolarMassResult {
  const MolarMassResult({required this.mass, required this.breakdown});
  final double mass;
  final List<String> breakdown; // p. ej. "Ca: 1 × 40.08 = 40.08 g/mol"
}

MolarMassResult calculateMolarMass(String rawFormula) {
  final formula = rawFormula.replaceAll(' ', '').trim();
  if (formula.isEmpty) throw const FormatException('Escribe una fórmula.');
  final counts = _parseFormulaImpl(formula);
  if (counts.isEmpty) throw const FormatException('No se pudo leer la fórmula.');
  double total = 0;
  final breakdown = <String>[];
  for (final entry in counts.entries) {
    final mass = atomicMassBySymbol[entry.key];
    if (mass == null) {
      throw FormatException('Elemento desconocido: ${entry.key}');
    }
    final subtotal = mass * entry.value;
    total += subtotal;
    breakdown.add(
      '${entry.key}: ${entry.value} × ${mass.toStringAsFixed(3)} = ${subtotal.toStringAsFixed(2)} g/mol',
    );
  }
  breakdown.add('Total: ${total.toStringAsFixed(2)} g/mol');
  return MolarMassResult(mass: total, breakdown: breakdown);
}

// Analizador recursivo sencillo: símbolos (mayúscula + minúscula opcional),
// números, y grupos entre paréntesis con multiplicador.
Map<String, int> _parseFormulaImpl(String formula) {
  int i = 0;

  int readNumber() {
    var s = '';
    while (i < formula.length &&
        formula.codeUnitAt(i) >= 48 &&
        formula.codeUnitAt(i) <= 57) {
      s += formula[i];
      i++;
    }
    return s.isEmpty ? 1 : int.parse(s);
  }

  Map<String, int> parseGroup() {
    final counts = <String, int>{};
    while (i < formula.length) {
      final ch = formula[i];
      if (ch == '(') {
        i++;
        final inner = parseGroup();
        if (i >= formula.length || formula[i] != ')') {
          throw const FormatException('Paréntesis sin cerrar.');
        }
        i++;
        final mult = readNumber();
        inner.forEach((k, v) => counts[k] = (counts[k] ?? 0) + v * mult);
      } else if (ch == ')') {
        return counts;
      } else if (ch.codeUnitAt(0) >= 65 && ch.codeUnitAt(0) <= 90) {
        var symbol = ch;
        i++;
        if (i < formula.length &&
            formula[i].codeUnitAt(0) >= 97 &&
            formula[i].codeUnitAt(0) <= 122) {
          symbol += formula[i];
          i++;
        }
        final n = readNumber();
        counts[symbol] = (counts[symbol] ?? 0) + n;
      } else {
        throw FormatException('Carácter no válido en la fórmula: $ch');
      }
    }
    return counts;
  }

  return parseGroup();
}

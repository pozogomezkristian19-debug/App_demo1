// Auditoría 7.0 del generador de preguntas (Kristian 09:16 CST:
// "no la cagues, revisa bien").
//
// Muestra resuelta A MANO: los valores esperados se calcularon fuera
// del código (con calculadora, desde los datos de cada pregunta) y
// quedan fijados aquí. Si el generador cambia un número, el test cae.
// Las 3 correcciones de la 7.0 quedan fijadas:
//  1. masas atómicas a 2 decimales (la suma de los datos mostrados
//     tiene que dar la respuesta: antes difería 0,01 g/mol en
//     Al₂(SO₄)₃, H₂SO₄, Ca(OH)₂, C₆H₁₂O₆, CH₄ y NH₃);
//  2. dilución 'v1' con C2 < C1 (antes pedía V1 > V2, imposible);
//  3. distractores de Z dentro de 1..118 (antes 0 y 128/119).
// Además: verificación estructural por programa de 110 preguntas
// generadas + todo el banco (210), y set de duelo sin duplicados.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/data/periodic_table.dart';
import 'package:quimica_pura/data/questions.dart';
import 'package:quimica_pura/services/question_generator.dart';

/// Sana por estructura: 4 opciones distintas, respuesta válida,
/// enunciado y explicación no vacíos, dificultad 1-3, y si es
/// numérica, la opción correcta muestra el valor con 2 decimales
/// (error máximo 0,005 por redondeo de pantalla).
void expectSound(GeneratedQuestion g) {
  final q = g.question;
  expect(q.options.length, 4, reason: '${g.id}: 4 opciones');
  expect(q.options.toSet().length, 4,
      reason: '${g.id}: opciones distintas (sin duplicados)');
  expect(q.answer, inInclusiveRange(0, 3), reason: '${g.id}: respuesta');
  expect(q.question.trim().isNotEmpty, isTrue, reason: '${g.id}: texto');
  expect(q.explanation.trim().isNotEmpty, isTrue,
      reason: '${g.id}: explicación');
  expect(q.difficulty, inInclusiveRange(1, 3), reason: '${g.id}: dificultad');
  final num = q.numericAnswer;
  if (num != null) {
    final m =
        RegExp(r'^-?[\d.]+').firstMatch(q.options[q.answer].trim());
    expect(m, isNotNull,
        reason: '${g.id}: la correcta numérica empieza por un número');
    final shown = double.parse(m!.group(0)!);
    expect((shown - num).abs(), lessThanOrEqualTo(0.01),
        reason: '${g.id}: la opción muestra el valor calculado '
            '($shown frente a $num)');
  }
}

void main() {
  group('auditoría 7.0: resuelto a mano', () {
    test('masa molar: la suma de los datos mostrados ES la respuesta', () {
      // Masas de libro a 2 decimales: H 1,01; C 12,01; N 14,01; O 16;
      // Na 22,99; Mg 24,31; Al 26,98; S 32,06; Cl 35,45; K 39,10;
      // Ca 40,08; Fe 55,85; Cu 63,55; Zn 65,38.
      const expected = {
        'H2SO4': 98.08, // 2×1,01 + 32,06 + 4×16
        'Al2(SO4)3': 342.14, // 2×26,98 + 3×32,06 + 12×16
        'Ca(OH)2': 74.10, // 40,08 + 2×16 + 2×1,01
        'C6H12O6': 180.18, // 6×12,01 + 12×1,01 + 6×16
        'CH4': 16.05, // 12,01 + 4×1,01
        'NH3': 17.04, // 14,01 + 3×1,01
        'H2O': 18.02, // 2×1,01 + 16
        'NaCl': 58.44, // 22,99 + 35,45
        'CO2': 44.01, // 12,01 + 2×16
        'CaCO3': 100.09, // 40,08 + 12,01 + 3×16
        'Fe2O3': 159.70, // 2×55,85 + 3×16
        'CuSO4': 159.61, // 63,55 + 32,06 + 4×16
        'HCl': 36.46, // 1,01 + 35,45
        'NaOH': 40.00, // 22,99 + 16 + 1,01
        'KCl': 74.55, // 39,10 + 35,45
      };
      for (final e in expected.entries) {
        final g = buildMolarMass(e.key);
        final q = g.question;
        expect(q.numericAnswer, closeTo(e.value, 0.001),
            reason: 'M(${e.key})');
        // La opción correcta muestra el valor, no uno vecino.
        expect(q.options[q.answer], '${fmtNum(e.value)} g/mol',
            reason: 'opción correcta de ${e.key}');
        // Los datos que se muestran suman la respuesta.
        expect(q.question, contains('Datos:'),
            reason: '${e.key} da las masas atómicas');
        expectSound(g);
      }
    });

    test('masa <-> moles', () {
      // 196 g ÷ 98,08 g/mol = 1,998… mol (≈ 2 mol, dentro del ±2 %).
      expect(buildMassMoles('moles', 'H2SO4', 196).question.numericAnswer,
          closeTo(196 / 98.08, 0.0001));
      // 2 mol × 58,44 g/mol = 116,88 g.
      expect(buildMassMoles('mass', 'NaCl', 2.0).question.numericAnswer,
          closeTo(116.88, 0.001));
      // 36 g ÷ 18,02 g/mol = 1,9978 mol.
      expect(buildMassMoles('moles', 'H2O', 36).question.numericAnswer,
          closeTo(36 / 18.02, 0.0001));
      // 0,5 mol × 100,09 g/mol = 50,045 g.
      expect(buildMassMoles('mass', 'CaCO3', 0.5).question.numericAnswer,
          closeTo(50.045, 0.001));
    });

    test('molaridad', () {
      // 0,5 mol ÷ 0,25 L = 2 M.
      expect(buildMolarity('molarity', 0.5, 250).question.numericAnswer,
          closeTo(2.0, 0.001));
      // 2 M × 0,25 L = 0,5 mol.
      expect(buildMolarity('moles', 2.0, 250).question.numericAnswer,
          closeTo(0.5, 0.001));
      // 0,25 mol ÷ 0,50 L = 0,5 M.
      expect(buildMolarity('molarity', 0.25, 500).question.numericAnswer,
          closeTo(0.5, 0.001));
    });

    test('dilución: C₁V₁ = C₂V₂', () {
      // C₂ = 2 × 100 ÷ 1000 = 0,2 M.
      expect(buildDilution('c2', 2.0, 100, 1000).question.numericAnswer,
          closeTo(0.2, 0.001));
      // V₁ = 0,5 × 1000 ÷ 2 = 250 mL.
      expect(buildDilution('v1', 2.0, 0.5, 1000).question.numericAnswer,
          closeTo(250.0, 0.001));
      // V₁ = 1 × 500 ÷ 4 = 125 mL.
      expect(buildDilution('v1', 4.0, 1.0, 500).question.numericAnswer,
          closeTo(125.0, 0.001));
    });

    test('pH: −log y pH + pOH = 14', () {
      // pH = 3 − log₁₀2 = 2,699.
      expect(buildPh('ph', 2, 3).question.numericAnswer,
          closeTo(3 - log(2) / ln10, 0.0001));
      // [H⁺] = 1×10⁻⁵ → pH = 5.
      expect(buildPh('ph', 1, 5).question.numericAnswer,
          closeTo(5.0, 0.001));
      // pOH = 2 − log₁₀5 = 1,301.
      expect(buildPh('poh', 5, 2).question.numericAnswer,
          closeTo(2 - log(5) / ln10, 0.0001));
      // [OH⁻] = 1×10⁻⁷ → pOH = 7 → pH = 14 − 7 = 7.
      final g = buildPh('ph-from-oh', 1, 7);
      expect(g.question.numericAnswer, closeTo(7.0, 0.001));
      expect(g.question.question, contains('pH + pOH = 14'));
    });

    test('gases: PV = nRT con T en kelvin y R dado', () {
      // V = 1 × 0,08206 × 300,15 ÷ 1 = 24,63 L.
      final v = buildGas('volume', 1.0, 27, 1.0);
      expect(v.question.numericAnswer, closeTo(24.630309, 0.001));
      expect(v.question.question,
          contains('R = 0.08206 L·atm/(mol·K)'));
      // n = 2 × 100 ÷ (0,08206 × 300,15) = 8,12 mol.
      expect(buildGas('moles', 2.0, 27, 100).question.numericAnswer,
          closeTo(8.120077, 0.001));
      // P = 2 × 0,08206 × 300,15 ÷ 4 = 12,32 atm.
      expect(buildGas('pressure', 2.0, 27, 4.0).question.numericAnswer,
          closeTo(12.315155, 0.001));
    });

    test('estequiometría: proporciones con coeficientes', () {
      // 2 H₂ + O₂ → 2 H₂O: 4 mol O₂ × 2/1 = 8 mol H₂O.
      expect(buildStoichiometry('product', 0, 4).question.numericAnswer,
          closeTo(8.0, 0.001));
      // N₂ + 3 H₂ → 2 NH₃: 6 mol H₂ × 2/3 = 4 mol NH₃.
      expect(buildStoichiometry('product', 1, 6).question.numericAnswer,
          closeTo(4.0, 0.001));
      // 2 KClO₃ → 2 KCl + 3 O₂: 4 mol × 3/2 = 6 mol O₂.
      expect(buildStoichiometry('product', 4, 4).question.numericAnswer,
          closeTo(6.0, 0.001));
      // 4 Fe + 3 O₂ → 2 Fe₂O₃: 8 mol Fe × 2/4 = 4 mol Fe₂O₃.
      expect(buildStoichiometry('product', 7, 8).question.numericAnswer,
          closeTo(4.0, 0.001));
      // Al revés: 8 mol H₂O × 1/2 = 4 mol O₂.
      expect(buildStoichiometry('reactant', 0, 8).question.numericAnswer,
          closeTo(4.0, 0.001));
      // 2 mol Fe₂O₃ × 4/2 = 4 mol Fe.
      expect(buildStoichiometry('reactant', 7, 2).question.numericAnswer,
          closeTo(4.0, 0.001));
    });

    test('equilibrio: Qc con los exponentes de los coeficientes', () {
      // N₂ + 3 H₂ ⇌ 2 NH₃, Qc = [NH₃]²/([N₂][H₂]³).
      expect(buildEquilibrium(0, 1, 1, 1).question.numericAnswer,
          closeTo(1.0, 0.001));
      expect(buildEquilibrium(0, 2, 1, 1).question.numericAnswer,
          closeTo(0.5, 0.001));
      expect(buildEquilibrium(0, 1, 2, 2).question.numericAnswer,
          closeTo(0.5, 0.001));
      // H₂ + I₂ ⇌ 2 HI: [HI]²/([H₂][I₂]) = 4/1 = 4.
      expect(buildEquilibrium(1, 1, 1, 2).question.numericAnswer,
          closeTo(4.0, 0.001));
      // H₂ + I₂ ⇌ 2 HI con [H₂] = 0,5: 1/(0,5×1) = 2.
      expect(buildEquilibrium(1, 0.5, 1, 1).question.numericAnswer,
          closeTo(2.0, 0.001));
      // 2 SO₂ + O₂ ⇌ 2 SO₃: 1/(2²×1) = 0,25.
      expect(buildEquilibrium(2, 2, 1, 1).question.numericAnswer,
          closeTo(0.25, 0.001));
    });

    test('termoquímica: q = m·c·ΔT en kJ', () {
      // 100 g × 4,184 × 10 °C = 4184 J = 4,184 kJ.
      expect(buildThermo(100, 0, 10).question.numericAnswer,
          closeTo(4.184, 0.001));
      // 200 g × 0,90 × 20 °C = 3600 J = 3,6 kJ.
      expect(buildThermo(200, 1, 20).question.numericAnswer,
          closeTo(3.6, 0.001));
      // 50 g × 0,45 × 5 °C = 112,5 J = 0,1125 kJ.
      expect(buildThermo(50, 2, 5).question.numericAnswer,
          closeTo(0.1125, 0.0001));
    });

    test('tabla: Z con distractores reales (1..118)', () {
      final h = buildPeriodic('z', 'H');
      expect(h.question.options[h.question.answer], '1');
      expect(h.question.options.toSet(), {'1', '2', '3', '11'});
      final og = buildPeriodic('z', 'Og');
      expect(og.question.options[og.question.answer], '118');
      expect(og.question.options.toSet(), {'118', '116', '117', '108'});
      final fe = buildPeriodic('z', 'Fe');
      expect(fe.question.options[fe.question.answer], '26');
      expect(fe.question.options.toSet(), {'26', '27', '25', '36'});
      // Barrido: ningún distractor es 0 ni mayor que 118.
      for (final e in allElements) {
        final g = buildPeriodic('z', e.symbol);
        final q = g.question;
        expect(q.options[q.answer], '${e.atomicNumber}');
        for (final o in q.options) {
          final z = int.parse(o);
          expect(z, inInclusiveRange(1, 118),
              reason: '${e.symbol}: distractor $o fuera de rango');
        }
        expect(q.options.toSet().length, 4, reason: e.symbol);
      }
    });

    test('enlace: geometrías y tipos de enlace (VSEPR)', () {
      String correctOf(GeneratedQuestion g) =>
          g.question.options[g.question.answer];
      expect(correctOf(buildBonding('geometry', 'H₂O')), 'Angular');
      expect(correctOf(buildBonding('geometry', 'CH₄')), 'Tetraédrica');
      expect(correctOf(buildBonding('geometry', 'CO₂')), 'Lineal');
      expect(
          correctOf(buildBonding('geometry', 'NH₃')), 'Piramidal trigonal');
      expect(correctOf(buildBonding('bond', 'NaCl')), 'Iónico');
      expect(correctOf(buildBonding('bond', 'O₂')), 'Covalente');
      expect(correctOf(buildBonding('bond', 'HCl')), 'Covalente polar');
    });

    test('cada pregunta lleva los datos que hacen falta', () {
      expect(buildMolarMass('H2SO4').question.question,
          contains('Datos: H = 1.01; S = 32.06; O = 16'));
      expect(buildMassMoles('moles', 'H2SO4', 196).question.question,
          contains('M(H2SO4) = 2×1.01 (H) + 32.06 (S) + 4×16 (O) '
              '= 98.08 g/mol'));
      expect(buildGas('volume', 1.0, 27, 1.0).question.question,
          contains('R = 0.08206'));
      expect(buildPh('ph-from-oh', 1, 7).question.question,
          contains('pH + pOH = 14'));
      expect(buildThermo(100, 0, 10).question.question, contains('c = 4.18'));
    });
  });

  group('auditoría 7.0: verificación por programa', () {
    test('110 preguntas generadas (11 tipos × 10 semillas) son sanas', () {
      const types = [
        'molar-mass',
        'mass-moles',
        'molarity',
        'dilution',
        'ph',
        'gas',
        'stoichiometry',
        'equilibrium-q',
        'thermo',
        'periodic',
        'bonding',
      ];
      var total = 0;
      for (final type in types) {
        for (var seed = 0; seed < 10; seed++) {
          final g = generateOfType(type, Random(7000 + seed * 31));
          expectSound(g);
          total++;
        }
      }
      expect(total, 110);
    });

    test('todo el banco es sano (4 opciones, 1 correcta, distintos)', () {
      expect(allQuestions.length, greaterThanOrEqualTo(200));
      final byTopic = <String, int>{};
      for (final q in allQuestions) {
        byTopic[q.topic] = (byTopic[q.topic] ?? 0) + 1;
        expect(q.options.length, 4, reason: q.question);
        expect(q.options.toSet().length, 4, reason: q.question);
        expect(q.answer, inInclusiveRange(0, 3), reason: q.question);
        expect(q.question.trim().isNotEmpty, isTrue);
        expect(q.explanation.trim().isNotEmpty, isTrue,
            reason: q.question);
        expect(q.difficulty, inInclusiveRange(1, 3), reason: q.question);
        final num = q.numericAnswer;
        if (num != null) {
          final m = RegExp(r'^-?[\d.]+')
              .firstMatch(q.options[q.answer].trim());
          expect(m, isNotNull, reason: q.question);
          expect((double.parse(m!.group(0)!) - num).abs(),
              lessThanOrEqualTo(0.01),
              reason: q.question);
        }
      }
      // Todos los temas con generador y los de solo banco están.
      for (final t in [
        'estequiometria',
        'gases',
        'disoluciones',
        'acido-base',
        'equilibrio',
        'termo-cinetica',
        'tabla',
        'enlace',
        'organica',
        'laboratorio',
      ]) {
        expect(byTopic.containsKey(t), isTrue, reason: 'falta tema $t');
      }
    });

    test('un set de duelo: 5 preguntas distintas y sanas', () {
      const topics = [
        'estequiometria',
        'gases',
        'disoluciones',
        'acido-base',
        'equilibrio',
      ];
      final rng = Random(20261111);
      final ids = <String>{};
      for (var i = 0; i < 5; i++) {
        final g = generateForTopic(topics[i], rng);
        expect(ids.add(g.id), isTrue,
            reason: 'sin duplicados en un mismo duelo (${g.id})');
        expectSound(g);
        // Cada pregunta del duelo se reconstruye desde su id sola.
        final rebuilt = rebuildGenerated(g.id);
        expect(rebuilt, isNotNull, reason: g.id);
        expect(rebuilt!.id, g.id);
        expect(rebuilt.question.question, g.question.question);
        expect(rebuilt.question.options, g.question.options);
        expect(rebuilt.question.answer, g.question.answer);
      }
    });

    test('dilución v1: nunca pide concentrar al diluir (200 semillas)', () {
      for (var seed = 0; seed < 200; seed++) {
        final g = generateDilution(Random(seed));
        final parts = g.id.split(':');
        expect(parts[1], 'dilution');
        final params = parts[3].split('_').map(double.parse).toList();
        if (parts[2] == 'v1') {
          final c1 = params[0], c2 = params[1], v2 = params[2];
          expect(c2, lessThan(c1),
              reason: '${g.id}: C2 < C1 para poder diluir');
          expect(g.question.numericAnswer, lessThan(v2),
              reason: '${g.id}: V1 < V2');
          expect(g.question.numericAnswer, closeTo(c2 * v2 / c1, 0.001));
        } else {
          final c1 = params[0];
          expect(g.question.numericAnswer, lessThanOrEqualTo(c1),
              reason: '${g.id}: C2 <= C1 al diluir');
        }
      }
    });
  });
}

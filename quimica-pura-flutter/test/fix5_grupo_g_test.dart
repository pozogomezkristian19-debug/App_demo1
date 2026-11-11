// Pruebas del GRUPO G (ronda #5, v6.2): hallazgos A6, A7, A8, A9, A14,
// A22 y A23 de la auditoría propia 2026-11-11. Lógica pura del
// generador y del banco; sin widgets ni previews.
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/data/i18n/generator_i18n.dart';
import 'package:quimica_pura/data/questions.dart';
import 'package:quimica_pura/services/question_generator.dart';

void main() {
  setUp(() {
    genLang = 'es';
  });

  tearDown(() {
    genLang = 'es';
  });

  group('A6: BF3 y CO2 con el enlace covalente polar', () {
    test('CO2 y BF3 responden "Covalente polar"', () {
      for (final formula in ['CO₂', 'BF₃']) {
        final q = buildBonding('bond', formula).question;
        expect(q.options[q.answer], 'Covalente polar', reason: formula);
      }
    });

    test('el resto de la lista sigue como estaba (revisado a mano)', () {
      const expected = {
        'CH₄': 'Covalente', // ΔEN C-H = 0.35
        'NH₃': 'Covalente polar', // ΔEN N-H = 0.84
        'H₂O': 'Covalente polar', // ΔEN O-H = 1.24
        'NaCl': 'Iónico',
        'HCl': 'Covalente polar', // ΔEN H-Cl = 0.96
        'O₂': 'Covalente', // ΔEN = 0
      };
      expected.forEach((formula, bond) {
        final q = buildBonding('bond', formula).question;
        expect(q.options[q.answer], bond, reason: formula);
      });
    });
  });

  group('A7: la pregunta de pOH se etiqueta pOH', () {
    test('poh lleva pOH; ph y ph-from-oh llevan pH', () {
      expect(buildPh('poh', 2, 5).question.numericUnit, 'pOH');
      expect(buildPh('ph', 1, 7).question.numericUnit, 'pH');
      expect(buildPh('ph-from-oh', 1, 7).question.numericUnit, 'pH');
    });
  });

  group('A8: Al2(SO4)3 = 342.14', () {
    test('la correcta es 342.14, no 342.15', () {
      final q = allQuestions
          .firstWhere((q) => q.question.contains('Al₂(SO₄)₃'));
      expect(q.options[q.answer], '342.14 g/mol');
      expect(q.explanation, contains('342.14 g/mol'));
    });

    test('ninguna pregunta del banco trae 342.15', () {
      for (final q in allQuestions) {
        expect(q.options.join(' '), isNot(contains('342.15')),
            reason: q.question);
      }
    });
  });

  group('A9: estequiometría ejercita la proporción', () {
    test('ninguna reacción es copiar el número dado', () {
      for (var r = 0; r < 8; r++) {
        for (final form in ['product', 'reactant']) {
          for (var m = 0.5; m <= 10.0; m += 0.5) {
            final q = buildStoichiometry(form, r, m).question;
            expect(q.numericAnswer, isNot(closeTo(m, 0.001)),
                reason: 'reacción $r, $form, $m mol');
            expect(q.options.toSet().length, 4,
                reason: 'reacción $r, $form, $m mol: ${q.options}');
          }
        }
      }
    });

    test('las reacciones 1 y 4 no cambian de respuesta', () {
      // N₂ + 3 H₂ → 2 NH₃ y 2 KClO₃ → 2 KCl + 3 O₂ ya ejercitaban
      // la proporción y no se tocan.
      expect(buildStoichiometry('product', 1, 6).question.numericAnswer,
          closeTo(4.0, 0.001));
      expect(buildStoichiometry('reactant', 1, 6).question.numericAnswer,
          closeTo(9.0, 0.001));
      expect(buildStoichiometry('product', 4, 6).question.numericAnswer,
          closeTo(9.0, 0.001));
      expect(buildStoichiometry('reactant', 4, 6).question.numericAnswer,
          closeTo(4.0, 0.001));
    });

    test('las reacciones nuevas ejercitan la proporción', () {
      // 2 H₂ + O₂ → 2 H₂O, preguntando por O₂ → H₂O (1:2).
      expect(buildStoichiometry('product', 0, 4).question.numericAnswer,
          closeTo(8.0, 0.001));
      // 4 Fe + 3 O₂ → 2 Fe₂O₃, preguntando por Fe → Fe₂O₃ (4:2).
      expect(buildStoichiometry('product', 7, 4).question.numericAnswer,
          closeTo(2.0, 0.001));
      // 2 H₂O → 2 H₂ + O₂, preguntando por H₂O → O₂ (2:1).
      expect(buildStoichiometry('product', 5, 4).question.numericAnswer,
          closeTo(2.0, 0.001));
    });
  });

  group('A14: distractores que no colapsan', () {
    const formulas = [
      'H2O', 'NaCl', 'CO2', 'NH3', 'CH4', 'HCl', 'NaOH', 'KCl', 'CaCO3',
      'H2SO4', 'Ca(OH)2', 'Al2(SO4)3', 'C6H12O6', 'MgSO4', 'Fe2O3',
      'CuSO4',
    ];

    test('masa molar: 4 opciones distintas en los 16 compuestos', () {
      for (final formula in formulas) {
        final q = buildMolarMass(formula).question;
        expect(q.options.toSet().length, 4,
            reason: '$formula: ${q.options}');
        expect(q.options[q.answer], '${fmtNum(q.numericAnswer!)} g/mol',
            reason: formula);
      }
    });

    test('Ca(OH)2: los dos errores clásicos ya no valen lo mismo', () {
      // Ignorar el subíndice (58.1) y restar un O (58.1) colapsaban;
      // ahora el segundo distractor es ignorar TODOS los subíndices.
      final q = buildMolarMass('Ca(OH)2').question;
      expect(q.options, contains('58.1 g/mol'));
      expect(q.options, contains('57.09 g/mol'));
      expect(q.options.toSet().length, 4);
    });

    test('NaCl/HCl/NaOH: 4 opciones distintas, la correcta solo una vez',
        () {
      for (final formula in ['NaCl', 'HCl', 'NaOH']) {
        final q = buildMolarMass(formula).question;
        expect(q.options.toSet().length, 4,
            reason: '$formula: ${q.options}');
      }
    });

    test('masa <-> moles: 4 opciones distintas en todos los compuestos',
        () {
      for (final formula in formulas) {
        for (final grams in [10.0, 36.0, 100.0, 200.0]) {
          final q = buildMassMoles('moles', formula, grams).question;
          expect(q.options.toSet().length, 4,
              reason: '$formula, $grams g: ${q.options}');
        }
        for (final moles in [0.25, 1.0, 2.5, 5.0]) {
          final q = buildMassMoles('mass', formula, moles).question;
          expect(q.options.toSet().length, 4,
              reason: '$formula, $moles mol: ${q.options}');
        }
      }
    });

    test('pH: 4 opciones distintas para mantisa 1-9 y exponente 1-12',
        () {
      for (final form in ['ph', 'poh', 'ph-from-oh']) {
        for (var mantissa = 1; mantissa <= 9; mantissa++) {
          for (var exponent = 1; exponent <= 12; exponent++) {
            final q = buildPh(form, mantissa, exponent).question;
            expect(q.options.toSet().length, 4,
                reason: '$form $mantissa×10^-$exponent: ${q.options}');
          }
        }
      }
    });

    test('pH 1×10⁻⁷: los distractores ya no son la respuesta', () {
      final q = buildPh('ph', 1, 7).question;
      expect(q.options[q.answer], '7.00');
      expect(q.options, contains('8.00'));
      expect(q.options, contains('6.00'));
      expect(q.options.toSet().length, 4);
    });

    test('dilución C1=C2 y V1=V2: 4 opciones distintas', () {
      expect(
          buildDilution('v1', 2.0, 2.0, 500).question.options.toSet().length,
          4);
      expect(
          buildDilution('c2', 2.0, 250, 250).question.options.toSet().length,
          4);
    });

    test('dilución: barrido de 4 opciones distintas', () {
      for (final c1 in [0.5, 1.0, 2.0, 6.0]) {
        for (final c2 in [0.1, 0.5, 1.0, 1.5, 2.0]) {
          for (final v2 in [250.0, 500.0, 2000.0]) {
            final q = buildDilution('v1', c1, c2, v2).question;
            expect(q.options.toSet().length, 4,
                reason: 'v1 C1=$c1 C2=$c2 V2=$v2: ${q.options}');
          }
        }
        for (final v1 in [10.0, 100.0, 250.0]) {
          for (final v2 in [250.0, 500.0, 1000.0, 2000.0]) {
            final q = buildDilution('c2', c1, v1, v2).question;
            expect(q.options.toSet().length, 4,
                reason: 'c2 C1=$c1 V1=$v1 V2=$v2: ${q.options}');
          }
        }
      }
    });
  });

  group('A22: un solo término y un solo valor en el banco', () {
    test('el banco no contiene TPE ni 22.4 L/mol', () {
      for (final q in allQuestions) {
        final text =
            '${q.question} ${q.explanation} ${q.options.join(' ')}';
        expect(text, isNot(contains('TPE')), reason: q.question);
        expect(text, isNot(contains('22.4 L/mol')), reason: q.question);
      }
    });

    test('la pregunta de Bach usa TPN y 22.41 L/mol', () {
      final q = allQuestions.firstWhere((q) =>
          q.topic == 'bach-gases' &&
          q.question.contains('litros ocupa 1 mol'));
      expect(q.question, contains('a TPN (0 °C, 1 atm)'));
      expect(q.explanation, contains('22.41 L/mol'));
      expect(q.options[q.answer], '22.4 L'); // 22.41 redondeado a 1 decimal
    });
  });

  group('A23: la masa molar del agua es 18.02', () {
    test('el redondeo mitad hacia arriba da 18.02', () {
      // 2×1.008 + 15.999 = 18.015 en decimal; en coma flotante es
      // 18.014999… y toStringAsFixed lo bajaba a 18.01.
      expect(fmtNum(2 * 1.008 + 15.999), '18.02');
    });

    test('la masa molar del agua generada es 18.02', () {
      final g = buildMolarMass('H2O');
      expect(g.question.options[g.question.answer], '18.02 g/mol');
      expect(g.question.explanation, contains('= 18.02 g/mol'));
      expect(g.question.numericAnswer, closeTo(18.02, 0.01));
    });
  });
}

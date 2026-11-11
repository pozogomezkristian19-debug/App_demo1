// Ronda #5, punto 14 (Quemia 6.2): LAS PREGUNTAS NO DAN LOS DATOS.
// La captura de Kristian: "¿Cuántos moles hay en 170 g de óxido de
// hierro(III) (Fe2O3)?" sin ninguna masa molar. Para resolverla hay
// que saber M(Fe2O3) = 159,7 g/mol, y en mitad de un nivel no se
// puede salir a buscarla (la barra inferior está oculta y salir
// cuesta una vida). Desde aquí, TODA pregunta generada que necesite
// un dato lo MUESTRA EN LA PROPIA PREGUNTA, en una línea "Datos:"
// visible sin tocar nada. La app usa punto decimal en los números
// (como todo el contenido: "18.02 g/mol"), así que los tests afirman
// "159.7", no "159,7".
// Las respuestas correctas y la tolerancia (±2 %) NO cambian.
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

  group('La captura de Kristian: 170 g de Fe2O3', () {
    test('la pregunta de moles da M(Fe2O3) con su desglose', () {
      final g = buildMassMoles('moles', 'Fe2O3', 170);
      expect(g.question.question,
          '¿Cuántos moles hay en 170 g de óxido de hierro(III) (Fe2O3)?\n'
          'Datos: M(Fe2O3) = 2×55.85 (Fe) + 3×16 (O) = 159.7 g/mol');
      expect(g.question.question, contains('159.7'));
      expect(g.question.question, contains('Datos:'));
      // La respuesta no cambia: 170 ÷ 159,7 ≈ 1,06 mol.
      expect(g.question.numericAnswer, closeTo(1.0645, 0.001));
      expect(g.question.options, hasLength(4));
    });

    test('la pregunta de masa también da M con su desglose', () {
      final g = buildMassMoles('mass', 'Fe2O3', 2);
      expect(g.question.question, contains('Datos: M(Fe2O3) = '));
      expect(g.question.question, contains('159.7'));
      expect(g.question.numericAnswer, closeTo(319.39, 0.01));
    });

    test('la reconstrucción desde la id estable trae la línea de datos',
        () {
      final g = buildMassMoles('moles', 'Fe2O3', 170);
      final rebuilt = rebuildGenerated(g.id);
      expect(rebuilt, isNotNull);
      expect(rebuilt!.question.question, g.question.question);
    });
  });

  group('Masa molar: masas atómicas, nunca la suma', () {
    test('Fe2O3 da Fe y O, pero no el total (el total ES la respuesta)',
        () {
      final g = buildMolarMass('Fe2O3');
      expect(g.question.question,
          contains('Datos: Fe = 55.85; O = 16'));
      expect(g.question.question, contains('Fe = 55.85'));
      expect(g.question.question, contains('O = 16'));
      expect(g.question.question, isNot(contains('159.7')));
      expect(g.question.numericAnswer, closeTo(159.7, 0.01));
    });

    test('NaCl y H2O dan sus masas atómicas', () {
      expect(buildMolarMass('NaCl').question.question,
          contains('Datos: Na = 22.99; Cl = 35.45'));
      expect(buildMolarMass('H2O').question.question,
          contains('Datos: H = 1.01; O = 16'));
    });

    test('todos los compuestos dan sus masas atómicas', () {
      for (final formula in [
        'H2O',
        'NaCl',
        'CO2',
        'NH3',
        'CH4',
        'HCl',
        'NaOH',
        'KCl',
        'CaCO3',
        'H2SO4',
        'Ca(OH)2',
        'Al2(SO4)3',
        'C6H12O6',
        'MgSO4',
        'Fe2O3',
        'CuSO4',
      ]) {
        final q = buildMolarMass(formula).question.question;
        expect(q, contains('Datos:'), reason: formula);
        expect(q, isNot(contains('= 159.7')), reason: formula);
      }
    });
  });

  group('Gases: R va en la pregunta', () {
    test('volumen, moles y presión dan R = 0.08206', () {
      for (final g in [
        buildGas('volume', 2, 27, 1),
        buildGas('moles', 1, 27, 10),
        buildGas('pressure', 1, 27, 10),
      ]) {
        expect(g.question.question,
            contains('Datos: R = 0.08206 L·atm/(mol·K)'));
      }
    });

    test('la respuesta del volumen no cambia', () {
      final g = buildGas('volume', 2, 27, 1);
      // V = nRT/P = 2 × 0.08206 × 300.15 ÷ 1 ≈ 49,26 L.
      expect(g.question.numericAnswer, closeTo(49.26, 0.01));
      final rebuilt = rebuildGenerated(g.id);
      expect(rebuilt!.question.question, g.question.question);
    });
  });

  group('pH desde [OH-]: pH + pOH = 14 va en la pregunta', () {
    test('ph-from-oh da la relación pH + pOH = 14', () {
      final g = buildPh('ph-from-oh', 1, 7);
      expect(g.question.question, contains('Datos: pH + pOH = 14'));
      expect(g.question.numericAnswer, 7.0);
    });

    test('pH y pOH directos no necesitan línea de datos', () {
      // La concentración ya viene dada en la pregunta; el log es
      // una operación, no un dato que falte.
      expect(buildPh('ph', 3, 4).question.question,
          isNot(contains('Datos:')));
      expect(buildPh('poh', 2, 5).question.question,
          isNot(contains('Datos:')));
    });
  });

  group('Auditoría: tipos del generador que ya estaban bien', () {
    test('molaridad y dilución dan todos los datos', () {
      expect(buildMolarity('molarity', 0.5, 500).question.question,
          isNot(contains('Datos:')));
      expect(buildMolarity('moles', 1, 500).question.question,
          contains('500 mL'));
      expect(buildDilution('c2', 2, 100, 400).question.question,
          isNot(contains('Datos:')));
      expect(buildDilution('v1', 2, 0.5, 400).question.question,
          isNot(contains('Datos:')));
    });

    test('estequiometría y equilibrio dan la ecuación y los datos', () {
      expect(
          buildStoichiometry('product', 0, 4).question.question,
          contains('2 H₂ + O₂ → 2 H₂O'));
      expect(buildStoichiometry('product', 0, 4).question.question,
          isNot(contains('Datos:')));
      expect(buildEquilibrium(0, 1, 1.5, 2).question.question,
          contains('[N₂] = 1 M'));
      expect(buildEquilibrium(0, 1, 1.5, 2).question.question,
          isNot(contains('Datos:')));
    });

    test('termoquímica ya daba el calor específico en la pregunta', () {
      expect(buildThermo(100, 0, 20).question.question,
          contains('(c = 4.18 J/g·°C)'));
    });

    test('tabla y enlace son de recuerdo, no de cálculo', () {
      expect(buildPeriodic('z', 'Fe').question.question,
          isNot(contains('Datos:')));
      expect(buildPeriodic('mass', 'Fe').question.question,
          isNot(contains('Datos:')));
      expect(buildBonding('geometry', 'CH₄').question.question,
          isNot(contains('Datos:')));
      expect(buildBonding('bond', 'NaCl').question.question,
          isNot(contains('Datos:')));
    });
  });

  group('La etiqueta "Datos:" se traduce; los números no', () {
    test('inglés, francés, italiano, portugués y ruso', () {
      genLang = 'en';
      expect(buildMassMoles('moles', 'Fe2O3', 170).question.question,
          contains('Data: M(Fe2O3)'));
      expect(buildGas('volume', 1, 27, 1).question.question,
          contains('Data: R = 0.08206'));
      genLang = 'fr';
      expect(buildMassMoles('moles', 'Fe2O3', 170).question.question,
          contains('Données : M(Fe2O3)'));
      expect(buildMolarMass('Fe2O3').question.question,
          contains('Données : Fe = 55.85'));
      genLang = 'it';
      expect(buildMassMoles('moles', 'Fe2O3', 170).question.question,
          contains('Dati: M(Fe2O3)'));
      genLang = 'pt';
      expect(buildMassMoles('moles', 'Fe2O3', 170).question.question,
          contains('Dados: M(Fe2O3)'));
      genLang = 'ru';
      expect(buildMassMoles('moles', 'Fe2O3', 170).question.question,
          contains('Данные: M(Fe2O3)'));
    });

    test('el valor numérico es el mismo en todos los idiomas', () {
      genLang = 'es';
      final es = buildMassMoles('moles', 'Fe2O3', 170).question.question;
      genLang = 'en';
      final en = buildMassMoles('moles', 'Fe2O3', 170).question.question;
      expect(es, contains('159.7'));
      expect(en, contains('159.7'));
    });
  });

  group('Auditoría del banco: preguntas sin datos, corregidas', () {
    test('moléculas en 0.25 mol de CO2: dan el número de Avogadro', () {
      final q = allQuestions.firstWhere(
          (x) => x.question.startsWith('¿Cuántas moléculas hay en 0.25'));
      expect(q.question, contains('Nₐ = 6.022×10²³'));
      expect(q.answer, 0);
      expect(q.options[0], '1.51×10²³');
    });

    test('átomos de H en 1 mol de H2SO4: dan el número de Avogadro', () {
      final q = allQuestions.firstWhere(
          (x) => x.question.startsWith('¿Cuántos átomos de H hay'));
      expect(q.question, contains('Nₐ = 6.022×10²³'));
      expect(q.answer, 1);
      expect(q.options[1], '1.204×10²⁴');
    });

    test('gases a TPN: dan el volumen molar 22.41 L/mol', () {
      final q1 = allQuestions.firstWhere(
          (x) => x.question.startsWith('¿Cuántos moles hay en 11.2 L'));
      expect(q1.question, contains('Vm = 22.41 L/mol'));
      expect(q1.answer, 1);
      expect(q1.options[1], '0.50 mol');
      final q2 = allQuestions.firstWhere((x) =>
          x.question.startsWith('A TPN (0 °C, 1 atm), 2 mol'));
      expect(q2.question, contains('Vm = 22.41 L/mol'));
      expect(q2.answer, 2);
      expect(q2.options[2], '44.8 L');
    });

    test('masa molar del NaCl (bach): dan las masas atómicas', () {
      final q = allQuestions.firstWhere(
          (x) => x.question.startsWith('La masa molar del NaCl'));
      expect(q.question, contains('Na = 23'));
      expect(q.question, contains('Cl = 35.5'));
      expect(q.answer, 0);
      expect(q.options[0], '58.5 g/mol');
    });
  });

  group('Banco: preguntas de recuerdo que NO se tocan', () {
    test('cuando la constante ES la respuesta, darla sería regalarla',
        () {
      final avogadro = allQuestions.firstWhere(
          (x) => x.question.startsWith('El número de Avogadro'));
      expect(avogadro.question,
          'El número de Avogadro es aproximadamente:');
      final vm = allQuestions.firstWhere(
          (x) => x.question.startsWith('¿Qué volumen ocupa 1 mol'));
      expect(vm.question, '¿Qué volumen ocupa 1 mol de gas ideal a TPN?');
      final r = allQuestions.firstWhere(
          (x) => x.question.startsWith('En PV = nRT, ¿qué valor de R'));
      expect(r.question,
          'En PV = nRT, ¿qué valor de R usas con P en atm y V en L?');
    });
  });
}

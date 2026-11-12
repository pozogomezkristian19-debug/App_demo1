// Pruebas de la lógica nueva de la v6: puntos, vidas, nota por puntos,
// búsquedas recientes, repaso por niveles con variantes y traducción
// del generador. Lógica pura y ProgressService con SharedPreferences
// simuladas (flutter test).
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/data/i18n/generator_i18n.dart';
import 'package:quimica_pura/services/points.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/question_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    genLang = 'es';
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
  });

  tearDown(() {
    genLang = 'es';
  });

  group('Tabla de puntos (v6, items 3 y 9)', () {
    test('acierto: fácil +3, media +5, difícil +8', () {
      expect(pointsForCorrect(1), 3);
      expect(pointsForCorrect(2), 5);
      expect(pointsForCorrect(3), 8);
    });

    test('fallo: fácil −5, media −8, difícil −12 (pesa más que el acierto)',
        () {
      expect(pointsForWrong(1), -5);
      expect(pointsForWrong(2), -8);
      expect(pointsForWrong(3), -12);
      expect(pointsForWrong(1).abs(), greaterThan(pointsForCorrect(1)));
      expect(pointsForWrong(2).abs(), greaterThan(pointsForCorrect(2)));
      expect(pointsForWrong(3).abs(), greaterThan(pointsForCorrect(3)));
    });
  });

  group('Pasar de nivel por aciertos (fix5, punto 13: 4/5 siempre pasa)', () {
    test('4/5 correctas pasa SIEMPRE, falle la fácil, la media o la difícil', () {
      expect(levelPassed(4, 5), isTrue);
      // La nota ponderada cambia según qué se falló, pero la puerta
      // es el conteo, no la nota.
      expect(
          levelScore5([2, 2, 2, 2, 2], [true, true, true, true, false]),
          4.0);
      // 4 medias + 1 fácil fallada: 20/24 × 5 = 4,17.
      expect(
          levelScore5([2, 2, 2, 2, 1], [true, true, true, true, false]),
          closeTo(4.17, 0.01));
      // 4 medias + 1 difícil fallada: 20/26 × 5 = 3,85 (antes no
      // pasaba; con la regla por conteo, sí).
      expect(
          levelScore5([2, 2, 2, 2, 3], [true, true, true, true, false]),
          closeTo(3.85, 0.01));
    });

    test('3/5 no pasa y 5/5 pasa', () {
      expect(levelPassed(3, 5), isFalse);
      expect(levelPassed(5, 5), isTrue);
      expect(levelPassed(0, 5), isFalse);
    });

    test('puntos máximos por dificultad: fácil 4, media 5, difícil 6', () {
      expect(levelMaxPoints(1), 4);
      expect(levelMaxPoints(2), 5);
      expect(levelMaxPoints(3), 6);
    });
  });

  group('Vidas (v6, item 1)', () {
    test('día nuevo repone las 5 vidas (función pura)', () {
      expect(livesLeftToday(0, '2026-11-09', '2026-11-10'), 5);
      expect(livesLeftToday(0, null, '2026-11-10'), 5);
      expect(canStartLevel(0, '2026-11-09', '2026-11-10'), isTrue);
    });

    test('con 0 vidas hoy no se puede empezar un nivel', () {
      expect(livesLeftToday(0, '2026-11-10', '2026-11-10'), 0);
      expect(canStartLevel(0, '2026-11-10', '2026-11-10'), isFalse);
    });

    test('ProgressService: 5 vidas, abandonar cuesta 1', () {
      final p = ProgressService.instance;
      expect(p.livesLeft, 5);
      expect(p.canStartLevel, isTrue);
      p.loseLifeOnAbandon();
      p.loseLifeOnAbandon();
      expect(p.livesLeft, 3);
      for (var i = 0; i < 5; i++) {
        p.loseLifeOnAbandon();
      }
      expect(p.livesLeft, 0);
      expect(p.canStartLevel, isFalse);
    });

    test('ganar un nivel completo restaura 1 vida (hasta 5)', () {
      final p = ProgressService.instance;
      // Con 5 no suma nada.
      expect(p.restoreLifeOnPass(), isFalse);
      expect(p.livesLeft, 5);
      // Abandonar 1 y ganar 1: vuelve a 5.
      p.loseLifeOnAbandon();
      expect(p.livesLeft, 4);
      expect(p.restoreLifeOnPass(), isTrue);
      expect(p.livesLeft, 5);
      // Abandonar 2 y ganar 1: queda 4 (solo +1 por nivel ganado).
      p.loseLifeOnAbandon();
      p.loseLifeOnAbandon();
      expect(p.livesLeft, 3);
      expect(p.restoreLifeOnPass(), isTrue);
      expect(p.livesLeft, 4);
      expect(p.restoreLifeOnPass(), isTrue);
      expect(p.livesLeft, 5);
      expect(p.restoreLifeOnPass(), isFalse);
    });

    test('de 0 vidas, ganar un nivel devuelve solo 1', () {
      final p = ProgressService.instance;
      for (var i = 0; i < 5; i++) {
        p.loseLifeOnAbandon();
      }
      expect(p.livesLeft, 0);
      expect(p.restoreLifeOnPass(), isTrue);
      expect(p.livesLeft, 1);
      expect(p.canStartLevel, isTrue);
    });
  });

  group('Puntos guardados y búsquedas recientes (v6, items 3 y 7)', () {
    test('el saldo de puntos se suma y persiste en el servicio', () {
      final p = ProgressService.instance;
      expect(p.points, 0);
      p.addPoints(5);
      p.addPoints(-8);
      expect(p.points, -3);
    });

    test('las búsquedas recientes guardan 5 como máximo y sin repetir', () {
      final p = ProgressService.instance;
      for (final q in ['a', 'b', 'c', 'd', 'e', 'f']) {
        p.recordSearch(q);
      }
      expect(p.recentSearches.length, 5);
      expect(p.recentSearches.first, 'f');
      expect(p.recentSearches, isNot(contains('a')));
      p.recordSearch('c');
      expect(p.recentSearches.first, 'c');
      expect(p.recentSearches.where((s) => s == 'c').length, 1);
    });
  });

  group('Repaso por niveles con variantes (v6, items 10 y 12)', () {
    test('addFailed guarda el nivel y failedGroups agrupa por (tema, nivel)',
        () {
      final p = ProgressService.instance;
      p.addFailed(const FailedEntry(id: 'bank:tabla:q1', topic: 'tabla', question: 'q1', level: 2));
      p.addFailed(const FailedEntry(id: 'bank:tabla:q2', topic: 'tabla', question: 'q2', level: 2));
      p.addFailed(const FailedEntry(id: 'bank:gases:q1', topic: 'gases', question: 'q3', level: 1));
      final groups = p.failedGroups();
      expect(groups.length, 2);
      expect(groups.firstWhere((g) => g.topic == 'tabla').entries.length, 2);
      expect(groups.firstWhere((g) => g.topic == 'tabla').level, 2);
    });

    test('hacen falta 3 aciertos SEGUIDOS en el repaso para borrar un error',
        () {
      final p = ProgressService.instance;
      const id = 'bank:tabla:q1';
      p.addFailed(const FailedEntry(id: id, topic: 'tabla', question: 'q1'));
      expect(p.recordReviewAnswer(id, true), isFalse);
      expect(p.recordReviewAnswer(id, true), isFalse);
      expect(p.recordReviewAnswer(id, false), isFalse); // la racha se rompe
      expect(p.isFailed(id), isTrue);
      expect(p.recordReviewAnswer(id, true), isFalse);
      expect(p.recordReviewAnswer(id, true), isFalse);
      expect(p.recordReviewAnswer(id, true), isTrue); // 3 seguidos: borrada
      expect(p.isFailed(id), isFalse);
    });

    test('la variante nunca es la misma pregunta (generada)', () {
      final rng = Random(7);
      final failed = generateOfType('ph', Random(3));
      final variant =
          generateVariantForFailed(failed.id, 'acido-base', rng);
      expect(variant, isNotNull);
      expect(variant!.id, isNot(failed.id));
      expect(variant.question.question, isNot(failed.question.question));
    });

    test('la variante de un fallo del banco usa el generador de su tema', () {
      final v = generateVariantForFailed(
          'bank:gases:pregunta vieja', 'gases', Random(11));
      expect(v, isNotNull);
      expect(v!.question.topic, 'gases');
    });

    test('orgánica y laboratorio no tienen generador: la variante es null '
        '(el repaso usa otra pregunta del banco del mismo tema)', () {
      expect(generateVariantForFailed('bank:organica:q', 'organica', Random(1)), isNull);
      expect(generateVariantForFailed('bank:laboratorio:q', 'laboratorio', Random(1)), isNull);
    });
  });

  group('Dificultad de las preguntas generadas', () {
    test('estequiometría y equilibrio son difíciles; tabla es fácil', () {
      expect(generateOfType('stoichiometry', Random(1)).question.difficulty, 3);
      expect(generateOfType('equilibrium-q', Random(1)).question.difficulty, 3);
      expect(generateOfType('periodic', Random(1)).question.difficulty, 1);
      expect(generateOfType('ph', Random(1)).question.difficulty, 2);
      expect(generateOfType('thermo', Random(1)).question.difficulty, 2);
    });

    test('rebuildGenerated conserva la dificultad', () {
      final g = generateOfType('stoichiometry', Random(5));
      final rebuilt = rebuildGenerated(g.id);
      expect(rebuilt, isNotNull);
      expect(rebuilt!.question.difficulty, 3);
      expect(rebuilt.question.question, g.question.question);
    });
  });

  group('Traducción del generador (v6, item 8)', () {
    test('en español la pregunta trae la línea de datos (fix5, punto 14)',
        () {
      genLang = 'es';
      final g = buildMolarMass('H2SO4');
      expect(g.question.question,
          '¿Cuál es la masa molar del ácido sulfúrico (H2SO4)?\nDatos: H = 1.01; S = 32.06; O = 16');
      expect(g.question.explanation,
          startsWith('M = 2×1.01 (H) + 32.06 (S) + 4×16 (O) = 98.08 g/mol.'));
      // (7.0): 98,08, no 98,07 — con masas a 2 decimales la suma de
      // los datos mostrados es la respuesta (antes difería 0,01).
    });

    test('en francés la pregunta sale en francés', () {
      genLang = 'fr';
      final g = buildMolarMass('H2SO4');
      expect(g.question.question, contains('masse molaire du composé'));
      expect(g.question.question, contains('acide sulfurique'));
      expect(g.question.question, isNot(contains('¿')));
    });

    test('en ruso la pregunta sale en ruso', () {
      genLang = 'ru';
      final g = buildMolarMass('H2SO4');
      expect(g.question.question, contains('молярная масса соединения'));
      expect(g.question.question, contains('серная кислота'));
    });

    test('en inglés el termo sale en inglés y el pH en francés', () {
      genLang = 'en';
      expect(buildThermo(100, 0, 20).question.question,
          contains('How much heat'));
      genLang = 'fr';
      expect(buildPh('ph', 5, 3).question.question, contains('Le pH'));
      expect(buildPh('ph', 5, 3).question.question, isNot(contains('El pH')));
    });

    test('las preguntas de la tabla usan el nombre del elemento traducido',
        () {
      genLang = 'en';
      final g = buildPeriodic('z', 'H');
      expect(g.question.question, contains('Hydrogen'));
      expect(g.question.question, isNot(contains('Hidrógeno')));
      genLang = 'fr';
      final g2 = buildPeriodic('symbol', 'C');
      expect(g2.question.question, contains('Carbone'));
    });
  });
}

// Pruebas de la lógica nueva de v5: racha, desbloqueo secuencial,
// índice de búsqueda y meta diaria. No prueban widgets, solo la lógica
// pura que decide qué se desbloquea y qué se muestra.
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/data/extra_content.dart';
import 'package:quimica_pura/data/search_index.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Racha (streak)', () {
    test('racha actual con días seguidos hasta hoy', () {
      final today = DateTime.now();
      final days = {
        for (var i = 0; i < 5; i++) ProgressService.dateKey(
            today.subtract(Duration(days: i))),
      };
      expect(ProgressService.currentStreak(days, today), 5);
    });

    test('racha actual sin practicar hoy pero con ayer', () {
      final today = DateTime.now();
      final days = {
        for (var i = 1; i <= 3; i++) ProgressService.dateKey(
            today.subtract(Duration(days: i))),
      };
      // La racha sigue viva si ayer se practicó (hoy todavía puede).
      expect(ProgressService.currentStreak(days, today), 3);
    });

    test('la racha se corta con un día sin practicar', () {
      final today = DateTime.now();
      final days = {
        ProgressService.dateKey(today),
        ProgressService.dateKey(today.subtract(const Duration(days: 2))),
        ProgressService.dateKey(today.subtract(const Duration(days: 3))),
      };
      expect(ProgressService.currentStreak(days, today), 1);
    });

    test('sin días, racha 0', () {
      expect(ProgressService.currentStreak({}, DateTime.now()), 0);
    });

    test('mejor racha toma el tramo más largo', () {
      final today = DateTime.now();
      final days = {
        ProgressService.dateKey(today),
        ProgressService.dateKey(today.subtract(const Duration(days: 1))),
        // tramo viejo de 4 días seguidos
        for (var i = 5; i <= 8; i++) ProgressService.dateKey(
            today.subtract(Duration(days: i))),
      };
      expect(ProgressService.bestStreak(days), 4);
      expect(ProgressService.currentStreak(days, today), 2);
    });

    test('dateKey tiene formato yyyy-MM-dd', () {
      expect(ProgressService.dateKey(DateTime(2026, 11, 9)), '2026-11-09');
      expect(ProgressService.dateKey(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });

  group('Desbloqueo secuencial de temas', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ProgressService.load();
      ProgressService.track = ProgressService.trackUni;
    });

    test('sin nada pasado, ningún tema está completo', () {
      expect(ProgressService.instance.isTopicComplete('estequiometria'), false);
    });

    test('al pasar todos los niveles, el tema queda completo', () {
      final p = ProgressService.instance;
      final count =
          ProgressService.levelCountForTopic('estequiometria');
      expect(count, greaterThan(0));
      for (var level = 1; level <= count; level++) {
        p.recordLevelPass('estequiometria', level);
      }
      expect(p.isTopicComplete('estequiometria'), true);
    });

    test('con un nivel sin pasar, el tema no está completo', () {
      final p = ProgressService.instance;
      final count =
          ProgressService.levelCountForTopic('estequiometria');
      for (var level = 1; level < count; level++) {
        p.recordLevelPass('estequiometria', level);
      }
      expect(p.isTopicComplete('estequiometria'), false);
    });

    test('levelCountForTopic coincide con el banco de preguntas', () {
      // estequiometría tiene 18 preguntas del banco: 4 niveles de 5
      // (18/5 = 3.6 → 4) + 2 niveles extra generados = 6.
      expect(ProgressService.levelCountForTopic('estequiometria'), 6);
    });
  });

  group('Meta diaria', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ProgressService.load();
    });

    test('0 niveles hoy → meta no cumplida; 1 nivel → cumplida', () {
      final p = ProgressService.instance;
      expect(p.levelsPassedToday(), 0);
      expect(p.dailyGoalDone, false);
      p.recordLevelPass('estequiometria', 1);
      expect(p.levelsPassedToday(), 1);
      expect(p.dailyGoalDone, true);
      p.recordLevelPass('estequiometria', 2);
      expect(p.levelsPassedToday(), 1,
          reason: 'pasar dos niveles el mismo día cuenta como 1 día');
    });
  });

  group('Búsqueda', () {
    test('fold quita acentos y minúsculas', () {
      expect(fold('Ácido'), 'acido');
      expect(fold('ÓXIGENO'), 'oxigeno');
      expect(fold('Físicoquímica'), 'fisicoquimica');
    });

    test('el índice tiene entradas de todo tipo', () {
      final entries = buildSearchEntries();
      expect(entries.length, greaterThan(100));
      expect(entries.any((e) => e.kind == 'element'), true);
      expect(entries.any((e) => e.kind == 'solver'), true);
      expect(entries.any((e) => e.kind == 'topic'), true);
      expect(entries.any((e) => e.kind == 'screen'), true);
      expect(entries.any((e) => e.kind == 'glossary'), true);
    });

    test('buscar "oxigeno" encuentra el elemento Oxígeno', () {
      final results = searchEntries(buildSearchEntries(), 'oxigeno');
      expect(results.any((e) => e.title == 'Oxígeno'), true);
    });

    test('buscar sin acento encuentra "ácido"', () {
      final results = searchEntries(buildSearchEntries(), 'acido');
      expect(results.any((e) => e.title.contains('cido')), true);
    });

    test('buscar "ph" encuentra el solucionador de pH', () {
      final results = searchEntries(buildSearchEntries(), 'ph');
      expect(results.any((e) => e.kind == 'solver'), true);
    });

    test('una búsqueda sin sentido no devuelve nada', () {
      expect(searchEntries(buildSearchEntries(), 'zzzqqq'), isEmpty);
    });

    test('la búsqueda vacía no devuelve nada', () {
      expect(searchEntries(buildSearchEntries(), ''), isEmpty);
    });
  });

  group('Pregunta y elemento del día', () {
    test('la misma fecha da la misma pregunta y el mismo elemento', () {
      final d = DateTime(2026, 11, 10);
      final q1 = questionOfTheDay(d);
      final q2 = questionOfTheDay(d);
      expect(q1.question, q2.question);
      expect(elementOfTheDay(d).atomicNumber,
          elementOfTheDay(d).atomicNumber);
    });

    test('días distintos suelen dar preguntas distintas', () {
      final qs = {
        for (var i = 0; i < 10; i++)
          questionOfTheDay(DateTime(2026, 11, 10 + i)).question,
      };
      expect(qs.length, greaterThan(5));
    });

    test('el elemento del día tiene un dato curioso', () {
      final e = elementOfTheDay(DateTime(2026, 11, 10));
      expect(elementFact(e).isNotEmpty, true);
    });
  });
}

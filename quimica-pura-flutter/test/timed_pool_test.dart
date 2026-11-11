// Prueba del examen con tiempo (v6): la lista no se acaba nunca
// antes que el tiempo y los ids van en paralelo a las preguntas.
// Tamaño 275 (fix3): el banco sigue siendo 210 (verificado en
// lib/data/questions.dart) y el generador completa hasta el tope
// _poolSize = 275 de timed_exam_screen.dart — 210 de banco + 65
// generadas. La expectativa anterior (310 = 210 + 100) quedó
// desactualizada cuando el tope bajó a 275; 275 sigue sobrando
// para 30 minutos (nadie responde 275 preguntas en media hora).
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/timed_exam_screen.dart';

void main() {
  test('la lista del examen con tiempo tiene 275 preguntas con ids únicos', () {
    final pool = buildTimedPool(Random(7));
    expect(pool.questions.length, 275);
    expect(pool.ids.length, 275);
    expect(pool.ids.toSet().length, 275);
    for (final id in pool.ids) {
      expect(id.startsWith('bank:') || id.startsWith('gen:'), isTrue);
    }
    expect(pool.ids.where((i) => i.startsWith('bank:')).length, 210);
    expect(pool.ids.where((i) => i.startsWith('gen:')).length, 65);
    for (var i = 0; i < pool.questions.length; i++) {
      final q = pool.questions[i];
      if (pool.ids[i].startsWith('bank:')) {
        expect(pool.ids[i], 'bank:${q.topic}:${q.question}');
      }
    }
  });

  test('dos listas barajadas con semillas distintas no son iguales', () {
    final a = buildTimedPool(Random(1));
    final b = buildTimedPool(Random(2));
    expect(a.ids, isNot(equals(b.ids)));
  });
}

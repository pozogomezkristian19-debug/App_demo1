// Pruebas de la ronda Quemia 7.3 (Kristian: el teclado está en TODAS
// las preguntas): helpers puros para contestar una pregunta de opción
// múltiple con el valor tecleado en la calculadora — parsear el número
// y la unidad de una opción, y encontrar la opción que coincide con
// el valor tecleado.
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/models.dart';
import 'package:quimica_pura/services/numeric_answer.dart';

QuizQuestion _q(List<String> options, int answer) => QuizQuestion(
      topic: 'test',
      question: '¿Cuánto?',
      options: options,
      answer: answer,
      explanation: '',
      difficulty: 1,
    );

void main() {
  group('parseOptionNumber', () {
    test('extrae el número inicial con unidad', () {
      expect(parseOptionNumber('0.50 mol'), 0.5);
      expect(parseOptionNumber('2.00 mol'), 2.0);
      expect(parseOptionNumber('18.02 g/mol'), 18.02);
      expect(parseOptionNumber('5'), 5.0);
    });

    test('acepta negativos y coma decimal', () {
      expect(parseOptionNumber('-3 g'), -3.0);
      expect(parseOptionNumber('0,50 mol'), 0.5);
      expect(parseOptionNumber('+12.5 L'), 12.5);
    });

    test('null si no empieza por número', () {
      expect(parseOptionNumber('Hidrógeno'), isNull);
      expect(parseOptionNumber('mol'), isNull);
      expect(parseOptionNumber(''), isNull);
      expect(parseOptionNumber('  '), isNull);
    });
  });

  group('parseOptionUnit', () {
    test('el texto tras el número', () {
      expect(parseOptionUnit('0.50 mol'), 'mol');
      expect(parseOptionUnit('342.14 g/mol'), 'g/mol');
      expect(parseOptionUnit('7.4 pH'), 'pH');
    });

    test('null si no queda nada o no hay número', () {
      expect(parseOptionUnit('5'), isNull);
      expect(parseOptionUnit('mol'), isNull);
      expect(parseOptionUnit(''), isNull);
    });
  });

  group('displayedIndexForTypedOptionValue', () {
    final options = ['0.25 mol', '2.00 mol', '0.50 mol', '1.00 mol'];

    test('coincidencia exacta en el orden visible', () {
      final q = _q(options, 2);
      expect(
          displayedIndexForTypedOptionValue(
              typed: 0.5, question: q, order: [0, 1, 2, 3]),
          2);
      expect(
          displayedIndexForTypedOptionValue(
              typed: 2.0, question: q, order: [0, 1, 2, 3]),
          1);
    });

    test('respeta el orden barajado', () {
      final q = _q(options, 2);
      expect(
          displayedIndexForTypedOptionValue(
              typed: 0.5, question: q, order: [2, 0, 3, 1]),
          0);
      expect(
          displayedIndexForTypedOptionValue(
              typed: 2.0, question: q, order: [2, 0, 3, 1]),
          3);
    });

    test('por tolerancia (dentro del 2 %)', () {
      final q = _q(options, 2);
      expect(
          displayedIndexForTypedOptionValue(
              typed: 0.51, question: q, order: [0, 1, 2, 3]),
          2);
    });

    test('sin coincidencia -> null', () {
      final q = _q(options, 2);
      expect(
          displayedIndexForTypedOptionValue(
              typed: 0.75, question: q, order: [0, 1, 2, 3]),
          isNull);
      expect(
          displayedIndexForTypedOptionValue(
              typed: 10.0, question: q, order: [0, 1, 2, 3]),
          isNull);
    });

    test('la más cercana gana', () {
      final q = _q(['1.00 mol', '1.03 mol', '2.00 mol', '3.00 mol'], 1);
      // 1.02 está dentro de la tolerancia de 1.00 y de 1.03, pero
      // está más cerca de 1.03.
      expect(
          displayedIndexForTypedOptionValue(
              typed: 1.02, question: q, order: [0, 1, 2, 3]),
          1);
    });

    test('opciones no numéricas -> null', () {
      final q = _q(['Hidrógeno', 'Oxígeno', 'Nitrógeno', 'Carbono'], 1);
      expect(
          displayedIndexForTypedOptionValue(
              typed: 5, question: q, order: [0, 1, 2, 3]),
          isNull);
    });

    test('opciones con 3 decimales usan el suelo fino', () {
      final q = _q(['0.016', '0.012', '0.020', '0.008'], 0);
      expect(
          displayedIndexForTypedOptionValue(
              typed: 0.016, question: q, order: [0, 1, 2, 3]),
          0);
      // Dentro del suelo fino (±0,0005): 0,0124 pasa frente a 0,012.
      expect(
          displayedIndexForTypedOptionValue(
              typed: 0.0124, question: q, order: [0, 1, 2, 3]),
          1);
      // Fuera del suelo fino: 0,0126 no coincide con ninguna.
      expect(
          displayedIndexForTypedOptionValue(
              typed: 0.0126, question: q, order: [0, 1, 2, 3]),
          isNull);
    });
  });
}

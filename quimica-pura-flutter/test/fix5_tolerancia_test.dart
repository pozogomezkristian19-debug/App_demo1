// Pruebas fix5 (cierre, A15): la tolerancia distingue los decimales
// con los que se muestra el valor correcto. Con 3 decimales (Qc) el
// suelo es ±0,0005: teclear 0,012 frente a Qc = 0,015625 debe fallar.
// Con 2 decimales el suelo sigue ±0,005.
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/models.dart';
import 'package:quimica_pura/services/numeric_answer.dart';

QuizQuestion _qcQuestion() => const QuizQuestion(
      topic: 'equilibrio',
      question: 'Qc?',
      options: ['0.012', '0.016', '0.020', '0.025'],
      answer: 1,
      explanation: 'Qc = 0,015625',
      numericAnswer: 0.015625,
    );

void main() {
  group('A15: suelo de tolerancia según decimales mostrados', () {
    test('Qc = 0.015625, teclear 0.012 debe fallar (3 decimales)', () {
      expect(isNumericAnswerCorrect(0.012, 0.015625, displayDecimals: 3),
          isFalse);
    });

    test('Qc = 0.015625, teclear 0.016 o 0.0156 debe pasar', () {
      expect(isNumericAnswerCorrect(0.016, 0.015625, displayDecimals: 3),
          isTrue);
      expect(isNumericAnswerCorrect(0.0156, 0.015625, displayDecimals: 3),
          isTrue);
    });

    test('con 2 decimales el suelo sigue ±0,005 (sin cambios)', () {
      expect(isNumericAnswerCorrect(0.012, 0.015625, displayDecimals: 2),
          isTrue);
      expect(isNumericAnswerCorrect(0.02, 0.02176), isTrue);
      expect(isNumericAnswerCorrect(0.03, 0.02176), isFalse);
    });

    test('el índice mostrado usa los decimales de la opción correcta',
        () {
      final q = _qcQuestion();
      // 0,012 no es la correcta (índice 0) y debe traducirse a un
      // índice que NO es la correcta.
      final fail = displayedIndexForNumericAnswer(
          typed: 0.012, question: q, order: [0, 1, 2, 3]);
      expect(fail, isNot(1));
      // 0,016 sí es la correcta.
      final ok = displayedIndexForNumericAnswer(
          typed: 0.016, question: q, order: [0, 1, 2, 3]);
      expect(ok, 1);
    });
  });
}

// Teclado numérico de Melli-Qui (ronda fix3, punto 7): lógica pura
// para las preguntas de cálculo. Se puede probar sin Flutter
// (ver test/fix3_numeric_keypad_test.dart).
//
// ## Qué preguntas son de cálculo
// Solo las generadas con un valor numérico limpio llevan
// `QuizQuestion.numericAnswer` (ver question_generator.dart): masa
// molar, masa <-> moles, molaridad, dilución, pH/pOH, gas ideal,
// estequiometría, cociente de reacción Qc y termoquímica (q = m·c·ΔT).
// Las generadas conceptuales (tabla periódica: Z, símbolo, masa, grupo;
// enlace: geometría y tipo de enlace) y TODAS las del banco se quedan
// con las 4 opciones de texto.
//
// ## Validación con tolerancia
// El generador calcula la respuesta exacta (`correct`) pero muestra la
// opción correcta redondeada a 2 decimales (`fmtNum` en el generador;
// 3 decimales para el Qc menor que 0,1). Por eso la tolerancia es ±2 %
// relativo del valor exacto, con un suelo absoluto de ±0,005: sin ese
// suelo, un valor pequeño como n = 0,02176 mol (gas ideal) se muestra
// como "0,02 mol" y teclear exactamente lo que la app muestra fallaría
// (0,02 está a 8 % del valor exacto, pero a 0,0018 del redondeo). El
// suelo cubre el redondeo de la pantalla sin dejar pasar respuestas de
// otro orden de magnitud (0,03 frente a 0,02176 sigue siendo fallo:
// difiere en 0,0082 > 0,005).
// Correcta = mismos puntos que una opción correcta; incorrecta = lo
// mismo que fallar una opción (ver cada runner: la respuesta numérica
// se traduce al índice de opción que le corresponde y pasa por el
// mismo `_answer` de siempre, con la misma explicación y el mismo
// repaso de errores).

import 'dart:math';

import '../models.dart';

/// Tolerancia relativa aceptada (±2 % del valor correcto).
const double numericToleranceRelative = 0.02;

/// Suelo absoluto de la tolerancia (±0,005): absorbe el redondeo a 2
/// decimales con el que el generador muestra la respuesta correcta.
const double numericToleranceAbsolute = 0.005;

/// ¿La respuesta tecleada se acepta como correcta?
bool isNumericAnswerCorrect(double typed, double correct) {
  if (correct == 0) return typed.abs() <= numericToleranceAbsolute;
  final allowed =
      max(numericToleranceRelative * correct.abs(), numericToleranceAbsolute);
  // El +1e-9 absorbe el ruido de la coma flotante justo en el límite
  // (0,51 − 0,50 da 0,010000000000000009 y no 0,01): sin él, teclear
  // el 2 % exacto fallaría por un pelo.
  return (typed - correct).abs() <= allowed + 1e-9;
}

/// Convierte lo tecleado en el teclado a número. Devuelve null si no
/// hay un número válido (campo vacío, solo '.', solo '-', '-.'...).
/// El teclado solo produce dígitos, un punto y un menos inicial, así
/// que el punto es el separador decimal; no se acepta la coma.
double? parseNumericInput(String text) {
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

/// Traduce una respuesta numérica al índice de opción visible (en las
/// opciones barajadas `order`) que le corresponde, para que el runner
/// pueda pasar por su `_answer` de siempre sin cambiar nada de puntos,
/// vidas, sonidos ni repaso de errores:
/// - correcta -> el índice donde está la opción correcta;
/// - incorrecta -> el primer índice donde NO está la correcta.
/// Requiere que la pregunta sea numérica (`numericAnswer != null`).
int displayedIndexForNumericAnswer({
  required double typed,
  required QuizQuestion question,
  required List<int> order,
}) {
  final correct =
      isNumericAnswerCorrect(typed, question.numericAnswer!);
  if (correct) return order.indexOf(question.answer);
  return order.indexWhere((real) => real != question.answer);
}

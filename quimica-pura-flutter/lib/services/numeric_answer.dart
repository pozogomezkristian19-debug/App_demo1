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
// con las 4 opciones de texto. Quemia 7.3 (Kristian: el teclado está
// en TODAS las preguntas): en las de opción múltiple hay además un
// botón Calculadora debajo de las opciones — si las opciones son
// numéricas, "Usar resultado" contesta la opción que coincida con el
// valor tecleado (displayedIndexForTypedOptionValue); si son
// conceptuales, la calculadora es solo borrador.
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
// difiere en 0,0082 > 0,005). Cuando el valor se muestra con 3
// decimales (Qc menor que 0,1) el suelo es ±0,0005 (fix5 A15), porque
// con ±0,005 un 0,012 pasaba como bueno frente a Qc = 0,015625.
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

/// Suelo absoluto cuando el valor se muestra con 3 decimales (±0,0005,
/// fix5 A15): el Qc menor que 0,1 se muestra con 3 decimales, y con el
/// suelo de 2 decimales una respuesta de otro orden pasaba como buena
/// (0,012 frente a Qc = 0,015625 difiere en 0,0036 < 0,005).
const double numericToleranceAbsolute3Decimals = 0.0005;

/// ¿La respuesta tecleada se acepta como correcta?
/// [displayDecimals] es con cuántos decimales se muestra el valor
/// correcto en pantalla (2 por defecto; 3 para el Qc menor que 0,1).
bool isNumericAnswerCorrect(double typed, double correct,
    {int displayDecimals = 2}) {
  final floor = displayDecimals >= 3
      ? numericToleranceAbsolute3Decimals
      : numericToleranceAbsolute;
  if (correct == 0) return typed.abs() <= floor;
  final allowed = max(numericToleranceRelative * correct.abs(), floor);
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

/// Extrae el número inicial de una opción de texto ("0.50 mol" ->
/// 0.50, "-3 g" -> -3). Acepta punto o coma decimal. null si la opción
/// no empieza por un número (pregunta conceptual).
double? parseOptionNumber(String option) {
  final match = _leadingNumberMatch(option);
  if (match == null) return null;
  return double.tryParse(match.group(0)!.replaceAll(',', '.'));
}

/// El texto tras el número inicial de una opción, recortado
/// ("0.50 mol" -> "mol", "342.14 g/mol" -> "g/mol"); null si no queda
/// nada (opción sin unidad) o si la opción no empieza por número.
String? parseOptionUnit(String option) {
  final match = _leadingNumberMatch(option);
  if (match == null) return null;
  final rest = option.trim().substring(match.end).trim();
  return rest.isEmpty ? null : rest;
}

/// Número inicial de un texto (con signo, punto o coma decimal):
/// "0.50 mol" -> "0.50", "-3 g" -> "-3". null si no empieza por uno.
RegExpMatch? _leadingNumberMatch(String option) {
  return RegExp(r'^[+-]?(\d+([.,]\d*)?|[.,]\d+)')
      .firstMatch(option.trim());
}

/// Busca entre las opciones visibles (en el orden barajado `order`)
/// la que tenga número y coincida con el valor tecleado en la
/// calculadora, según [isNumericAnswerCorrect] con los decimales que
/// muestra esa opción (Quemia 7.3, Kristian: el teclado está en TODAS
/// las preguntas, así que una de opción múltiple con números también
/// se puede contestar desde la calculadora). Si varias coinciden,
/// devuelve la más cercana (menor diferencia relativa). null si
/// ninguna coincide o si las opciones no son numéricas. Solo para
/// preguntas de opción múltiple (no numéricas): aquí no hay un
/// `numericAnswer` exacto, cada opción se compara con su propio
/// valor mostrado.
int? displayedIndexForTypedOptionValue({
  required double typed,
  required QuizQuestion question,
  required List<int> order,
}) {
  int? bestDisplayed;
  double? bestRelativeDiff;
  for (var displayed = 0; displayed < order.length; displayed++) {
    final shown = question.options[order[displayed]];
    final value = parseOptionNumber(shown);
    if (value == null) continue;
    if (!isNumericAnswerCorrect(typed, value,
        displayDecimals: _displayDecimalsOfOption(shown))) {
      continue;
    }
    final diff = value == 0
        ? (typed - value).abs()
        : (typed - value).abs() / value.abs();
    if (bestRelativeDiff == null || diff < bestRelativeDiff) {
      bestRelativeDiff = diff;
      bestDisplayed = displayed;
    }
  }
  return bestDisplayed;
}
/// - correcta -> el índice donde está la opción correcta;
/// - incorrecta -> el primer índice donde NO está la correcta.
/// Requiere que la pregunta sea numérica (`numericAnswer != null`).
int displayedIndexForNumericAnswer({
  required double typed,
  required QuizQuestion question,
  required List<int> order,
}) {
  final correct = isNumericAnswerCorrect(typed, question.numericAnswer!,
      displayDecimals: _displayDecimals(question));
  if (correct) return order.indexOf(question.answer);
  return order.indexWhere((real) => real != question.answer);
}

/// Decimales con los que se muestra la opción correcta en pantalla
/// (fix5 A15): el texto de la opción lleva el redondeo del generador
/// ("0.016" -> 3 decimales, Qc; "18.02" -> 2).
int _displayDecimals(QuizQuestion question) {
  return _displayDecimalsOfOption(question.options[question.answer]);
}

/// Decimales con los que se muestra un valor en el texto de una
/// opción. Los decimales se cuentan hasta el primer carácter que no
/// es dígito, así que una unidad pegada ("342.14 g/mol") no estorba.
int _displayDecimalsOfOption(String shown) {
  final dot = shown.indexOf('.');
  if (dot < 0) return 0;
  var n = 0;
  for (var i = dot + 1;
      i < shown.length &&
          shown.codeUnitAt(i) >= 48 &&
          shown.codeUnitAt(i) <= 57;
      i++) {
    n++;
  }
  return n;
}

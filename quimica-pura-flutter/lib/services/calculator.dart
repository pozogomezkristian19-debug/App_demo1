// Evaluador de expresiones para la calculadora científica de Melli-Qui
// (ronda fix3, punto 7): Dart puro, sin dependencias (no hay red para
// pub get de paquetes nuevos). Descenso recursivo con la precedencia
// habitual y paréntesis:
//
//   expr  := term (('+' | '-') term)*
//   term  := power (('*' | '/') power)*
//   power := unary ('^' power)?            // la potencia asocia a la derecha
//   unary := ('+' | '-') unary | primary
//   primary := número | 'e' | 'π' | func '(' expr ')' | '(' expr ')'
//   func  := log (base 10) | ln | sqrt
//
// Acepta los símbolos que muestra el teclado: '−' (menos), '×', '÷',
// '√' (raíz), 'π' y la 'e' de Euler. La tecla '×10^' escribe '×10^' y
// tecla '10^x' escribe '10^': ambas se evalúan con los operadores de
// siempre, sin sintaxis especial. La notación científica '1.5e-3'
// también se entiende dentro de un número.
//
// Devuelve null si la expresión está incompleta o no es válida
// (paréntesis sin cerrar, '2+', log(0), log(-1), √(-4), división
// entre cero, resultado no finito...): la calculadora muestra entonces
// el resultado en blanco y la tecla '=' no hace nada.
import 'dart:math' as math;

enum _TokKind { number, op, lparen, rparen, func, constant }

class _Token {
  const _Token(this.kind, this.text, [this.value = 0]);
  final _TokKind kind;
  final String text;
  final double value;
}

/// Evalúa la expresión tal como se escribió en el teclado. Null si no
/// es una expresión válida y completa.
double? evaluateExpression(String input) {
  final tokens = _tokenize(input);
  if (tokens == null || tokens.isEmpty) return null;
  final parser = _Parser(tokens);
  final value = parser.parse();
  if (value == null || !value.isFinite) return null;
  return value;
}

List<_Token>? _tokenize(String input) {
  // Los símbolos bonitos del teclado a sintaxis de siempre.
  final s = input
      .replaceAll('−', '-')
      .replaceAll('×', '*')
      .replaceAll('÷', '/');
  final out = <_Token>[];
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (c == ' ') {
      i++;
      continue;
    }
    if (c == '(') {
      out.add(const _Token(_TokKind.lparen, '('));
      i++;
      continue;
    }
    if (c == ')') {
      out.add(const _Token(_TokKind.rparen, ')'));
      i++;
      continue;
    }
    if ('+-*/^'.contains(c)) {
      out.add(_Token(_TokKind.op, c));
      i++;
      continue;
    }
    if (c == '√') {
      out.add(const _Token(_TokKind.func, 'sqrt'));
      i++;
      continue;
    }
    if (c == 'π') {
      out.add(const _Token(_TokKind.constant, 'pi'));
      i++;
      continue;
    }
    if (_isDigit(c) || c == '.') {
      // Número, con su parte exponencial si la lleva ('1.5e-3'). La
      // 'e' solo se traga como exponente si después viene un exponente
      // válido; si no, queda como la constante de Euler ('2e^3' no
      // es un número: es 2, la constante e y la potencia).
      var j = i;
      var dots = 0;
      while (j < s.length && (_isDigit(s[j]) || s[j] == '.')) {
        if (s[j] == '.') dots++;
        j++;
      }
      if (dots > 1) return null;
      var k = j;
      if (k < s.length && (s[k] == 'e' || s[k] == 'E')) {
        var e = k + 1;
        if (e < s.length && (s[e] == '+' || s[e] == '-')) e++;
        final digitsStart = e;
        while (e < s.length && _isDigit(s[e])) {
          e++;
        }
        if (e > digitsStart) j = e;
      }
      final value = double.tryParse(s.substring(i, j));
      if (value == null) return null;
      out.add(_Token(_TokKind.number, s.substring(i, j), value));
      i = j;
      continue;
    }
    if (_isLetter(c)) {
      var j = i;
      while (j < s.length && _isLetter(s[j])) {
        j++;
      }
      final word = s.substring(i, j);
      switch (word) {
        case 'log':
        case 'ln':
        case 'sqrt':
          out.add(_Token(_TokKind.func, word));
        case 'e':
          out.add(const _Token(_TokKind.constant, 'e'));
        case 'pi':
          out.add(const _Token(_TokKind.constant, 'pi'));
        default:
          return null;
      }
      i = j;
      continue;
    }
    return null;
  }
  return out;
}

bool _isDigit(String c) =>
    c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

bool _isLetter(String c) =>
    (c.codeUnitAt(0) >= 97 && c.codeUnitAt(0) <= 122) ||
    (c.codeUnitAt(0) >= 65 && c.codeUnitAt(0) <= 90);

class _Parser {
  _Parser(this.tokens);

  final List<_Token> tokens;
  var _pos = 0;

  bool get _done => _pos >= tokens.length;
  _Token get _peek => tokens[_pos];
  _Token _take() => tokens[_pos++];

  double? parse() {
    final value = _expr();
    if (value == null || !_done) return null;
    return value;
  }

  double? _expr() {
    final first = _term();
    if (first == null) return null;
    // Copia no nula: sin ella, el analizador pierde la promoción de
    // `first` al reasignar dentro del bucle.
    var value = first;
    while (!_done &&
        _peek.kind == _TokKind.op &&
        (_peek.text == '+' || _peek.text == '-')) {
      final op = _take().text;
      final rhs = _term();
      if (rhs == null) return null;
      value = op == '+' ? value + rhs : value - rhs;
    }
    return value;
  }

  double? _term() {
    final first = _power();
    if (first == null) return null;
    var value = first;
    while (!_done &&
        _peek.kind == _TokKind.op &&
        (_peek.text == '*' || _peek.text == '/')) {
      final op = _take().text;
      final rhs = _power();
      if (rhs == null) return null;
      if (op == '/' && rhs == 0) return null;
      value = op == '*' ? value * rhs : value / rhs;
    }
    return value;
  }

  double? _power() {
    final base = _unary();
    if (base == null) return null;
    if (!_done && _peek.kind == _TokKind.op && _peek.text == '^') {
      _take();
      final exponent = _power();
      if (exponent == null) return null;
      final result = math.pow(base, exponent).toDouble();
      if (result.isNaN || result.isInfinite) return null;
      return result;
    }
    return base;
  }

  double? _unary() {
    if (!_done &&
        _peek.kind == _TokKind.op &&
        (_peek.text == '-' || _peek.text == '+')) {
      final op = _take().text;
      final value = _unary();
      if (value == null) return null;
      return op == '-' ? -value : value;
    }
    return _primary();
  }

  double? _primary() {
    if (_done) return null;
    final token = _take();
    switch (token.kind) {
      case _TokKind.number:
        return token.value;
      case _TokKind.constant:
        return token.text == 'pi' ? math.pi : math.e;
      case _TokKind.lparen:
        final value = _expr();
        if (value == null) return null;
        if (_done || _peek.kind != _TokKind.rparen) return null;
        _take();
        return value;
      case _TokKind.func:
        if (_done || _peek.kind != _TokKind.lparen) return null;
        _take();
        final arg = _expr();
        if (arg == null) return null;
        if (_done || _peek.kind != _TokKind.rparen) return null;
        _take();
        switch (token.text) {
          case 'log':
            if (arg <= 0) return null;
            return math.log(arg) / math.ln10;
          case 'ln':
            if (arg <= 0) return null;
            return math.log(arg);
          case 'sqrt':
            if (arg < 0) return null;
            return math.sqrt(arg);
        }
        return null;
      default:
        return null;
    }
  }
}

/// Cómo se muestra un resultado en el campo de respuesta: entero sin
/// decimales ('2'), hasta 6 decimales sin ceros sobrantes ('2.5',
/// '0.333333') y notación exponencial solo para valores muy grandes o
/// muy pequeños ('1.2345e-7'). Sirve también para la vista previa en
/// vivo de la calculadora.
String formatCalculatorResult(double value) {
  if (value == 0) return '0';
  if (!value.isFinite) return 'Error';
  final abs = value.abs();
  if (abs >= 1e12 || abs < 1e-6) {
    return value.toStringAsExponential(4);
  }
  if (value == value.truncateToDouble()) {
    return value.toStringAsFixed(0);
  }
  var s = value.toStringAsFixed(6);
  s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  return s == '-0' ? '0' : s;
}

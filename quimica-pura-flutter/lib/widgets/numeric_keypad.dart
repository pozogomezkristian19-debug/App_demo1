// Calculadora propia de Melli-Qui (ronda fix3, punto 7; pantalla
// completa desde la fix5, punto B, corrección 2026-11-11 00:26),
// estilo Duolingo: teclas grandes y redondeadas, sin el teclado del
// sistema. Junto al campo se ve la unidad esperada ('mol', 'g', 'L',
// 'pH'...) para que se sepa qué escribir. NO es un panel inline
// dentro de la pregunta: vive en su propia pantalla
// (screens/calculator_screen.dart), que se abre con el botoncito de
// teclado de la pregunta y SE CIERRA para responder; al volver, la
// pregunta sigue intacta. La calculadora NUNCA se abre sola.
//
// Dos modos, un solo componente ([scientific]):
// - Científica: log, ln, potencias, raíces, π y notación científica
//   (×10^). Es la de las preguntas de cálculo (respuesta numérica):
//   '=' rellena el campo de respuesta y "Usar resultado" entrega el valor.
// - Normal: solo dígitos, + − × ÷, paréntesis y '='. Es la de las
//   demás preguntas (opción múltiple): no hay campo de respuesta que
//   rellenar; la calculadora es para calcular a mano y el resultado se
//   ve en su propio visor, sin botón Usar resultado ([onSubmit] null).
//
// Flujo: el usuario escribe el cálculo (p. ej. pH = −log[H⁺]: escribe
// "−log(0.01)"), ve la expresión y el resultado en vivo, pulsa '='
// y el resultado queda en el campo de respuesta; luego "Usar resultado"
// es el equivalente a tocar una opción: llama a `onSubmit` con ese
// valor y el runner pasa por su `_answer` de siempre (mismos puntos,
// mismas vidas, misma explicación y mismo repaso de errores, con la
// tolerancia ±2 % de services/numeric_answer.dart).
//
// Persistencia por pregunta (ronda 7.2): lo tecleado no se pierde al
// cerrar la calculadora sin pulsar '=' ni al reabrirla — el runner
// guarda el borrador que reporta `onDraftChanged` (también el
// resultado EN VIVO de la expresión, no solo el de '=') y lo vuelve
// a sembrar con `initialValue` al abrir. En opción múltiple no se
// persiste nada: la calculadora es solo para calcular a mano.
//
// Funciones: dígitos, punto decimal, + − × ÷, paréntesis, log (base
// 10), ln, 10^x, e^x, x², √, π y notación científica (×10^). La
// expresión se evalúa con el evaluador propio de
// services/calculator.dart (sin dependencias nuevas): si la expresión
// está incompleta o no es válida (paréntesis sin cerrar, log(0),
// división entre cero...), la vista previa se queda en blanco y '='
// no hace nada.
//
// En las preguntas de cálculo (`QuizQuestion.isNumeric`) la
// calculadora es científica y entrega la respuesta; en las demás es
// normal y solo sirve para calcular a mano. El campo es de solo
// lectura a propósito: no es un TextField, así que el teclado del
// sistema nunca se abre encima.

import 'package:flutter/material.dart';

import '../services/accent.dart';
import '../services/calculator.dart';
import '../services/localization.dart';
import '../services/numeric_answer.dart';
import 'shadows.dart';

/// Calculadora para responder una pregunta de cálculo o para calcular
/// a mano en una de opción múltiple (ver la cabecera del archivo).
///
/// [unit] es la etiqueta de unidad que se muestra junto al campo
/// (null = la respuesta no lleva unidad, como el Qc).
/// [enabled] false cuando la pregunta ya está contestada: las teclas
/// se apagan pero el valor tecleado sigue visible.
/// [onSubmit] recibe el número del campo de respuesta al pulsar
/// "Usar resultado" (solo se activa después de pulsar '='); null = modo
/// para calcular a mano, sin botón Usar resultado.
/// [scientific] false esconde las teclas científicas (log, ln,
/// potencias, raíces, π, notación científica y '^'): queda la
/// calculadora normal (dígitos, + − × ÷, paréntesis, =).
/// [initialValue] siembra el campo de respuesta (ronda 7.2): el valor
/// tecleado persiste POR PREGUNTA — al reabrir la calculadora el campo
/// trae lo que se llevaba escrito (como si se acabara de pulsar '=',
/// así un dígito empieza un cálculo nuevo y un operador sigue desde
/// ese valor). null = empezar vacía, como siempre.
/// [onDraftChanged] se llama en cada cambio con el borrador actual
/// (ver [_draft]): lo que se lleva escrito, aunque no se haya pulsado
/// '='. null = a nadie le importa el borrador (opción múltiple: la
/// calculadora es solo para calcular a mano y no persiste nada).
class NumericKeypad extends StatefulWidget {
  const NumericKeypad({
    super.key,
    required this.unit,
    required this.enabled,
    this.onSubmit,
    this.scientific = true,
    this.initialValue,
    this.onDraftChanged,
  });

  final String? unit;
  final bool enabled;
  final ValueChanged<double>? onSubmit;
  final bool scientific;
  final double? initialValue;
  final ValueChanged<double?>? onDraftChanged;

  @override
  State<NumericKeypad> createState() => _NumericKeypadState();
}

class _NumericKeypadState extends State<NumericKeypad> {
  /// Expresión que se va escribiendo ("−log(0.01)").
  var _expr = '';

  /// Resultado de la última '=': lo que hay en el campo de respuesta.
  var _answer = '';

  /// Acabamos de pulsar '=': un dígito empieza un cálculo nuevo y
  /// un operador sigue calculando desde el resultado.
  var _justEvaluated = false;

  double? get _liveResult => _expr.isEmpty ? null : evaluateExpression(_expr);

  double? get _answerValue => parseNumericInput(_answer);

  /// Borrador actual (ronda 7.2): lo que se guardaría si se cerrara
  /// la calculadora ahora mismo. Es el resultado EN VIVO de la
  /// expresión sin pulsar '=' (Kristian escribe el número y cierra
  /// sin '=' para mirar un dato y lo pierde), o el valor de '=' si
  /// lo hay. No es literalmente `_answerValue ?? _liveResult`: tras
  /// '=' el `_answer` viejo quedaría por delante del número nuevo
  /// que se está escribiendo (p. ej. '=' deja 5 y luego se teclea
  /// '3': el borrador debe ser 3, no 5). Por eso, mientras se
  /// escribe una expresión nueva manda el resultado en vivo; si la
  /// expresión está incompleta ('5+'), se conserva el último valor
  /// válido en vez de perderlo.
  double? get _draft {
    if (_justEvaluated) return _answerValue;
    if (_expr.isNotEmpty) return _liveResult ?? _answerValue;
    return _answerValue;
  }

  /// Avisa del borrador actual a quien lo guarda (el runner, por
  /// pregunta). Se llama después de cada cambio de tecla.
  void _notifyDraft() => widget.onDraftChanged?.call(_draft);

  @override
  void initState() {
    super.initState();
    // Siembra el campo de respuesta (ronda 7.2): al reabrir la
    // calculadora el valor que se llevaba escrito ya está en el
    // campo, como si se acabara de pulsar '=' (un dígito empieza un
    // cálculo nuevo y un operador sigue desde ese valor).
    final seed = widget.initialValue;
    if (seed != null) {
      _answer = formatCalculatorResult(seed);
      _justEvaluated = true;
    }
  }

  static bool _isDigit(String c) =>
      c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  bool get _endsWithValue {
    if (_expr.isEmpty) return false;
    final c = _expr[_expr.length - 1];
    return _isDigit(c) || c == ')';
  }

  bool get _endsWithOperator {
    if (_expr.isEmpty) return false;
    return '+-×÷^'.contains(_expr[_expr.length - 1]);
  }

  bool get _endsWithOpenParen => _expr.isNotEmpty && _expr.endsWith('(');

  int get _unclosedParens {
    var n = 0;
    for (var i = 0; i < _expr.length; i++) {
      if (_expr[i] == '(') n++;
      if (_expr[i] == ')') n--;
    }
    return n;
  }

  /// Empieza un cálculo nuevo si acabamos de pulsar '='.
  void _freshStartIfEvaluated() {
    if (_justEvaluated) {
      _expr = '';
      _justEvaluated = false;
    }
  }

  void _pressDigit(String d) {
    if (!widget.enabled) return;
    setState(() {
      _freshStartIfEvaluated();
      _expr += d;
    });
    _notifyDraft();
  }

  void _pressDot() {
    if (!widget.enabled) return;
    setState(() {
      _freshStartIfEvaluated();
      // ¿El número que se está escribiendo ya tiene punto?
      var i = _expr.length - 1;
      while (i >= 0 && (_isDigit(_expr[i]) || _expr[i] == '.')) {
        i--;
      }
      final segment = _expr.substring(i + 1);
      if (segment.contains('.')) return;
      // Empezar por el punto escribe "0." para que siempre se vea
      // un número válido.
      _expr += segment.isEmpty ? '0.' : '.';
    });
    _notifyDraft();
  }

  void _pressOperator(String op) {
    if (!widget.enabled) return;
    setState(() {
      if (_expr.isEmpty) {
        // Con la expresión vacía solo cabe el menos: al principio
        // ("−log(0.01)") o para seguir desde el resultado.
        if (op == '−') _expr = _answer.isEmpty ? '−' : '$_answer−';
        return;
      }
      if (_justEvaluated) {
        // Seguir calculando desde el resultado: "5×".
        _expr = '$_answer$op';
        _justEvaluated = false;
        return;
      }
      if (_endsWithOpenParen) {
        // Tras '(' solo cabe el menos unario: "(−3".
        if (op == '−') _expr += op;
        return;
      }
      if (_endsWithOperator) {
        if (op == '−') {
          // Menos unario tras un operador: "2×−3".
          _expr += op;
        } else {
          // Cambiar el operador: "2+" y luego "×" deja "2×".
          _expr = _expr.substring(0, _expr.length - 1) + op;
        }
        return;
      }
      _expr += op;
    });
    _notifyDraft();
  }

  /// Función o constante que, escrita tras un número o ')', lleva una
  /// multiplicación implícita delante ("2log(" es "2×log(").
  void _pressOperandStart(String text) {
    if (!widget.enabled) return;
    setState(() {
      _freshStartIfEvaluated();
      if (_endsWithValue) _expr += '×';
      _expr += text;
    });
    _notifyDraft();
  }

  /// x²: eleva al cuadrado lo último escrito ("3" -> "3^2").
  void _pressSquare() {
    if (!widget.enabled) return;
    if (!_endsWithValue) return;
    setState(() {
      if (_justEvaluated) {
        _expr = _answer;
        _justEvaluated = false;
      }
      _expr += '^2';
    });
    _notifyDraft();
  }

  /// "×10^": notación científica, solo tras un número ("2×10^3").
  void _pressTimesPow10() {
    if (!widget.enabled) return;
    if (!_endsWithValue) return;
    setState(() {
      if (_justEvaluated) {
        _expr = _answer;
        _justEvaluated = false;
      }
      _expr += '×10^';
    });
    _notifyDraft();
  }

  void _pressOpenParen() => _pressOperandStart('(');

  void _pressCloseParen() {
    if (!widget.enabled) return;
    if (_unclosedParens <= 0) return;
    if (_endsWithOperator || _endsWithOpenParen) return;
    setState(() => _expr += ')');
    _notifyDraft();
  }

  void _backspace() {
    if (!widget.enabled) return;
    setState(() {
      if (_expr.isNotEmpty) {
        // Borra el último token visible entero: 'log(' y '√(' no se
        // borran letra a letra.
        if (_expr.endsWith('×10^')) {
          _expr = _expr.substring(0, _expr.length - 4);
        } else if (_expr.endsWith('log(') || _expr.endsWith('ln(')) {
          _expr = _expr.substring(0, _expr.length - 4);
        } else if (_expr.endsWith('10^')) {
          _expr = _expr.substring(0, _expr.length - 3);
        } else if (_expr.endsWith('√(') || _expr.endsWith('e^')) {
          _expr = _expr.substring(0, _expr.length - 2);
        } else {
          _expr = _expr.substring(0, _expr.length - 1);
        }
        _justEvaluated = false;
      } else if (_answer.isNotEmpty) {
        _answer = '';
        _justEvaluated = false;
      }
    });
    _notifyDraft();
  }

  void _clear() {
    if (!widget.enabled) return;
    setState(() {
      _expr = '';
      _answer = '';
      _justEvaluated = false;
    });
    _notifyDraft();
  }

  /// '=': evalúa la expresión y pone el resultado en el campo de
  /// respuesta. Sin resultado válido no hace nada.
  void _equals() {
    if (!widget.enabled) return;
    final result = _liveResult;
    if (result == null) return;
    setState(() {
      _answer = formatCalculatorResult(result);
      _justEvaluated = true;
    });
    _notifyDraft();
  }

  void _submit() {
    final value = _answerValue;
    final submit = widget.onSubmit;
    if (!widget.enabled || value == null || submit == null) return;
    submit(value);
  }

  Widget _key({
    required String label,
    required VoidCallback onTap,
    double height = 56,
    double fontSize = 22,
    bool accent = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = !widget.enabled;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Tecla SÓLIDA, sin degradado (corrección 2026-11-12, Kristian:
    // "esos degradados, esos blancos contra blanco"). El degradado
    // y el blanco sobre blanco se ven feos: ahora la tecla es un
    // color plano con labio oscuro, como Duolingo. Y la tecla
    // SIEMPRE se distingue del fondo: en claro es gris visible
    // (#E8ECF0, no blanca sobre blanco); en oscuro es blanca,
    // como en 7.0 (resalta sobre el fondo oscuro). El texto es
    // oscuro fijo (#4B4B4B) en los dos temas, así se lee siempre.
    // El degradado y el borde los pinta el Container de fuera: el
    // FilledButton de dentro es transparente (los tests buscan las
    // teclas por FilledButton). Dígitos en gris/blanco, operadores
    // con tinte del acento.
    final fill = accent
        ? scheme.primary.withValues(alpha: 0.15)
        : isDark
            ? Colors.white
            : const Color(0xFFE8ECF0);
    final edge = accent
        ? scheme.primary.withValues(alpha: 0.45)
        : isDark
            ? const Color(0xFFE5E7EB)
            : const Color(0xFFCBD5E1);
    final shadow = accent ? scheme.primary : const Color(0xFF64748B);
    final fg = accent ? scheme.primary : const Color(0xFF4B4B4B);
    return SizedBox(
      height: height,
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: fill,
            border: Border(bottom: BorderSide(color: edge, width: 3)),
            boxShadow: [
              standardShadow(shadow),
            ],
          ),
          child: FilledButton(
            onPressed: widget.enabled ? onTap : null,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              elevation: 0,
              foregroundColor: fg,
              disabledForegroundColor: fg.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: EdgeInsets.zero,
            ),
            child: Text(
              label,
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _smallKey({
    required String label,
    required VoidCallback onTap,
    bool primary = false,
    bool enabled = true,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final onPressed = widget.enabled && enabled ? onTap : null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Tecla pequeña SÓLIDA, sin degradado (corrección 2026-11-12,
    // Kristian: "esos degradados, esos blancos contra blanco"):
    // color plano con labio oscuro, como Duolingo. '=' en el color
    // del acento sólido; "Borrar" y "Limpiar" en gris visible en
    // claro (#E8ECF0) y blancas en oscuro (como en 7.0), con texto
    // oscuro fijo en los dos temas. El botón de dentro es
    // transparente: el color lo pinta el Container (los tests
    // buscan las teclas por FilledButton/OutlinedButton).
    if (primary) {
      return SizedBox(
        height: 48,
        child: Opacity(
          opacity: onPressed == null ? 0.45 : 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppAccent.primary,
              border: Border(
                  bottom: BorderSide(color: AppAccent.primaryDark, width: 3)),
              boxShadow: [
                standardShadow(scheme.primary),
              ],
            ),
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                foregroundColor: Colors.white,
                // Blanco entero al deshabilitar (antes white70
                // + Opacity 0.45: texto oscuro sobre teal
                // oscurecido, ilegible).
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                // Padding corto: en modo normal hay 4 teclas pequeñas y
                // con el padding por defecto "Limpiar" no cabe y se parte
                // en dos líneas.
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 48,
      child: Opacity(
        opacity: onPressed == null ? 0.45 : 1,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isDark ? Colors.white : const Color(0xFFE8ECF0),
            border: Border(
                bottom: BorderSide(
                    color: isDark
                        ? const Color(0xFFE5E7EB)
                        : const Color(0xFFCBD5E1),
                    width: 3)),
            boxShadow: [
              standardShadow(const Color(0xFF64748B)),
            ],
          ),
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              elevation: 0,
              // Texto oscuro fijo en los dos temas: la tecla es
              // gris visible en claro y blanca en oscuro.
              foregroundColor: const Color(0xFF4B4B4B),
              // Sin contorno: el del tema es teal de 2 px y chocaría
              // con el borde inferior gris del Container.
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              // Padding corto: como arriba, "Limpiar" no cabe con el
              // padding por defecto cuando hay 4 teclas pequeñas.
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(label,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _row(List<Widget> children, {double gap = 8}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canEquals = widget.enabled && _liveResult != null;
    final canSubmit = widget.enabled && _answerValue != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Campo de respuesta: el resultado de '=', grande, con la
        // unidad al lado (solo el número, sin unidades ni fórmulas).
        // Cuando tiene valor se tiñe suave de primario: es el dato
        // que importa y tiene que saltar a la vista frente a la caja
        // de la expresión. Sombra suave (ronda de diseño 7.0).
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _answer.isEmpty
                ? scheme.surfaceContainerHighest
                : scheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            // Sin borde en oscuro cuando está vacío: la línea
            // clara se veía fea (Kristian, 2026-11-13); el relleno
            // distingue la caja. Con valor, el borde del acento.
            border: (_answer.isEmpty && isDark)
                ? null
                : Border.all(
                    color: _answer.isEmpty
                        ? scheme.outlineVariant
                        : scheme.primary.withValues(alpha: 0.45),
                  ),
            boxShadow: [
              standardShadow(
                  (_answer.isEmpty ? const Color(0xFF64748B) : scheme.primary)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _answer.isEmpty ? '0' : _answer,
                  key: const Key('numeric-keypad-display'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _answer.isEmpty
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
              ),
              if (widget.unit != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    widget.unit!,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Expresión que se va escribiendo y su resultado en vivo.
        // Mismo radio y borde que el campo de respuesta, mismo
        // padding vertical (12): las dos cajas van parejas.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            // Sin borde en oscuro (misma razón que el campo de
            // respuesta): el relleno distingue la caja.
            border: isDark ? null : Border.all(color: scheme.outlineVariant),
            boxShadow: [
              standardShadow(const Color(0xFF64748B)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Text(
                  _expr.isEmpty ? tr('calcHint') : _expr,
                  key: const Key('calculator-expression'),
                  style: TextStyle(
                    fontSize: 20,
                    color: _expr.isEmpty
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
              ),
              Text(
                _liveResult == null
                    ? ''
                    : '= ${formatCalculatorResult(_liveResult!)}',
                key: const Key('calculator-result'),
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Filas científicas (teclas compactas): solo en modo
        // científico. En modo normal no salen log, ln, raíz, x²,
        // 10^x, e^x, ×10^x, π ni '^': queda la calculadora normal.
        if (widget.scientific) ...[
          // Fila científica (teclas compactas): log, ln, raíz, x², 10^x.
          _row([
            _key(
                label: 'log',
                onTap: () => _pressOperandStart('log('),
                height: 44,
                fontSize: 16),
            _key(
                label: 'ln',
                onTap: () => _pressOperandStart('ln('),
                height: 44,
                fontSize: 16),
            _key(
                label: '√',
                onTap: () => _pressOperandStart('√('),
                height: 44,
                fontSize: 20),
            _key(label: 'x²', onTap: _pressSquare, height: 44, fontSize: 16),
            _key(
                label: '10^x',
                onTap: () => _pressOperandStart('10^'),
                height: 44,
                fontSize: 16),
          ]),
          // Segunda fila científica: e^x, paréntesis, notación
          // científica y π. Cinco teclas como la fila de arriba: la
          // retícula queda simétrica (antes eran cuatro, más anchas).
          _row([
            _key(
                label: 'e^x',
                onTap: () => _pressOperandStart('e^'),
                height: 44,
                fontSize: 16),
            _key(label: '(', onTap: _pressOpenParen, height: 44, fontSize: 20),
            _key(label: ')', onTap: _pressCloseParen, height: 44, fontSize: 20),
            _key(
                label: '×10^x',
                onTap: _pressTimesPow10,
                height: 44,
                fontSize: 16),
            _key(
                label: 'π',
                onTap: () => _pressOperandStart('π'),
                height: 44,
                fontSize: 20),
          ]),
        ],
        // Teclas grandes: dígitos y operadores (no GridView: el grid
        // fuerza celdas cuadradas y las teclas saldrían gigantes en
        // pantallas anchas; aquí cada tecla mide 56 de alto siempre).
        _row([
          _key(label: '7', onTap: () => _pressDigit('7')),
          _key(label: '8', onTap: () => _pressDigit('8')),
          _key(label: '9', onTap: () => _pressDigit('9')),
          _key(label: '÷', onTap: () => _pressOperator('÷'), accent: true),
        ]),
        _row([
          _key(label: '4', onTap: () => _pressDigit('4')),
          _key(label: '5', onTap: () => _pressDigit('5')),
          _key(label: '6', onTap: () => _pressDigit('6')),
          _key(label: '×', onTap: () => _pressOperator('×'), accent: true),
        ]),
        _row([
          _key(label: '1', onTap: () => _pressDigit('1')),
          _key(label: '2', onTap: () => _pressDigit('2')),
          _key(label: '3', onTap: () => _pressDigit('3')),
          _key(label: '−', onTap: () => _pressOperator('−'), accent: true),
        ]),
        _row([
          _key(label: '0', onTap: () => _pressDigit('0')),
          _key(label: '.', onTap: _pressDot),
          // En modo normal el paréntesis de abrir ocupa el sitio de
          // '^': la normal lleva paréntesis, no potencias.
          if (widget.scientific)
            _key(label: '^', onTap: () => _pressOperator('^'), accent: true)
          else
            _key(label: '(', onTap: _pressOpenParen),
          _key(label: '+', onTap: () => _pressOperator('+'), accent: true),
        ]),
        Row(
          children: [
            // En modo normal el paréntesis de cerrar va aquí: en
            // científico ya está en la segunda fila científica. Con
            // cuatro teclas pequeñas, ')' lleva flex 1 y las demás
            // flex 2: si no, "Borrar" y "Limpiar" no caben y se
            // parten en dos líneas.
            if (!widget.scientific) ...[
              Expanded(
                  flex: 1,
                  child: _smallKey(label: ')', onTap: _pressCloseParen)),
              const SizedBox(width: 8),
            ],
            Expanded(
                flex: widget.scientific ? 1 : 2,
                child: _smallKey(label: tr('keypadDelete'), onTap: _backspace)),
            const SizedBox(width: 8),
            Expanded(
                flex: widget.scientific ? 1 : 2,
                child: _smallKey(label: tr('keypadClear'), onTap: _clear)),
            const SizedBox(width: 8),
            Expanded(
                flex: widget.scientific ? 1 : 2,
                child: _smallKey(
                    label: '=',
                    onTap: _equals,
                    primary: true,
                    // '=' solo se enciende con un resultado válido:
                    // con la expresión incompleta no hace nada.
                    enabled: canEquals)),
          ],
        ),
        // "Usar resultado" solo en las preguntas de cálculo (onSubmit no
        // null): en modo "para calcular a mano" no hay nada que
        // entregar; '=' ya deja el resultado en el visor.
        // Botón 3D del tema (ronda de diseño 7.0): sin styleFrom
        // propio, usa la píldora teal del tema; el styleFrom plano
        // de antes lo dejaba sin vida.
        if (widget.onSubmit != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: canSubmit ? _submit : null,
              child: Text(
                tr('calcUseResult'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

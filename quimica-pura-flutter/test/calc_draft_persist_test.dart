// Regresión del reporte de Kristian (2026-11-13): en una pregunta
// de nivel, abre la calculadora, escribe datos, vuelve atrás a la
// pregunta y al reabrir el teclado todo lo escrito se eliminó.
// Causa: el borrador (_draft) era nulo cuando la expresión quedaba
// incompleta ("2+"), y ese nulo borraba lo guardado. Ahora el
// teclado reporta el último valor válido; solo borrar todo (o
// borrar hasta el final) reporta nulo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/widgets/numeric_keypad.dart';

void main() {
  Future<double?> typeKeys(
    WidgetTester tester,
    List<String> keys, {
    double? initialValue,
  }) async {
    double? draft;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NumericKeypad(
            scientific: false,
            enabled: true,
            unit: null,
            initialValue: initialValue,
            onDraftChanged: (v) => draft = v,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final k in keys) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    return draft;
  }

  testWidgets('teclear 5 reporta 5', (tester) async {
    expect(await typeKeys(tester, ['5']), 5);
  });

  testWidgets('expresión a medias ("2+") NO pierde el 2', (tester) async {
    expect(await typeKeys(tester, ['2', '+']), 2);
  });

  testWidgets('expresión completa ("2+3") reporta 5', (tester) async {
    expect(await typeKeys(tester, ['2', '+', '3']), 5);
  });

  testWidgets('borrar todo ("Limpiar") reporta nulo', (tester) async {
    expect(await typeKeys(tester, ['7', 'Limpiar']), isNull);
  });

  testWidgets('semilla 5 + operador a medias conserva el 5',
      (tester) async {
    expect(await typeKeys(tester, ['−'], initialValue: 5), 5);
  });

  // Corrección de Kristian 2026-11-13 ("Sea lo que sea que deje se
  // queda"): la EXPRESIÓN tal cual se dejó persiste, no solo el
  // valor — "2+" y "2+5" vuelven tal cual al reabrir.
  Future<String?> typeKeysExpr(
    WidgetTester tester,
    List<String> keys, {
    String? initialExpression,
  }) async {
    String? expr;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NumericKeypad(
            scientific: false,
            enabled: true,
            unit: null,
            initialExpression: initialExpression,
            onExpressionChanged: (e) => expr = e,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final k in keys) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    return expr;
  }

  testWidgets('teclear "2+" reporta la expresión "2+"', (tester) async {
    expect(await typeKeysExpr(tester, ['2', '+']), '2+');
  });

  testWidgets('teclear "2+5" reporta la expresión "2+5"',
      (tester) async {
    expect(await typeKeysExpr(tester, ['2', '+', '5']), '2+5');
  });

  testWidgets('reabrir con "2+" muestra "2+" en la expresión',
      (tester) async {
    await typeKeysExpr(tester, [], initialExpression: '2+');
    expect(find.text('2+'), findsOneWidget);
  });

  testWidgets('reabrir con "2+5" y pulsar "=" da 7', (tester) async {
    String? expr;
    double? draft;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NumericKeypad(
            scientific: false,
            enabled: true,
            unit: null,
            initialExpression: '2+5',
            onExpressionChanged: (e) => expr = e,
            onDraftChanged: (v) => draft = v,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2+5'), findsOneWidget);
    await tester.tap(find.text('='));
    await tester.pump();
    expect(draft, 7);
    // Tras '=', la expresión está consumida: se reporta null para
    // que al reabrir se siembre el valor (7), no la expresión vieja.
    expect(expr, isNull);
  });

  testWidgets('Limpiar borra la expresión (reporta null)', (tester) async {
    expect(await typeKeysExpr(tester, ['2', '+', 'Limpiar']), isNull);
  });
}

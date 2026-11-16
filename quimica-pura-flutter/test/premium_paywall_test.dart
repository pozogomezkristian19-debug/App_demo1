// Paywall Premium (solo web): la pantalla se pinta y el flujo
// planes → pago enseña los precios y los datos de Transfermóvil
// (ejemplos, con la marca EJEMPLO). Sin Firebase: los notifiers
// usan sus valores por defecto (sin Premium, sin solicitud).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quimica_pura/screens/premium_paywall_screen.dart';
import 'package:quimica_pura/services/premium_service.dart';
import 'package:quimica_pura/services/remote_tuning.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadNunitoFonts();
  });

  setUp(() {
    RemoteTuning.resetForTests();
    PremiumService.resetForTests();
  });

  tearDown(() {
    PremiumService.resetForTests();
    RemoteTuning.resetForTests();
  });

  Future<void> pumpPaywall(WidgetTester tester) async {
    // El paywall es una pantalla FIJA, sin deslizar (2026-11-15):
    // todo cabe sin scroll, así que no hay que desplazar nada.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(home: PremiumPaywallScreen()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('planes: comparación + 3 planes con precios de ejemplo',
      (tester) async {
    await pumpPaywall(tester);
    expect(find.text('Quemia Premium'), findsOneWidget);
    expect(find.text('250 CUP'), findsOneWidget);
    expect(find.text('600 CUP'), findsOneWidget);
    expect(find.text('1.800 CUP'), findsOneWidget);
    // La Tabla periódica NO lleva fila en la comparación
    // (2026-11-15): sigue gratis, solo no aparece aquí.
    expect(find.text('Tabla periódica'), findsNothing);
    expect(find.text('CONTINUAR'), findsOneWidget);
  });

  testWidgets('paywall fijo: sin Scrollable y cabe en 393x852',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(home: PremiumPaywallScreen()),
    );
    // Un desbordamiento (overflow) falla el test solo.
    await tester.pumpAndSettle();
    expect(find.byType(Scrollable), findsNothing);
    expect(find.text('1.800 CUP'), findsOneWidget);
    expect(find.text('CONTINUAR'), findsOneWidget);
  });

  testWidgets('pago fijo: cabe en 393x852 sin desbordar',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(home: PremiumPaywallScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUAR'));
    // Un desbordamiento (overflow) falla el test solo.
    await tester.pumpAndSettle();
    expect(find.text('Paga con Transfermóvil'), findsOneWidget);
    expect(find.text('ELEGIR CAPTURA'), findsOneWidget);
  });

  testWidgets('pago: monto, tarjeta EJEMPLO y pedir captura',
      (tester) async {
    await pumpPaywall(tester);
    await tester.tap(find.text('12 meses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUAR'));
    await tester.pumpAndSettle();
    expect(find.text('Paga con Transfermóvil'), findsOneWidget);
    expect(find.text('Plan de 12 meses · 1.800 CUP'), findsOneWidget);
    expect(find.text('Tarjeta destino (EJEMPLO)'), findsOneWidget);
    expect(find.text('9225 1234 5678 9012'), findsOneWidget);
    expect(find.text('ELEGIR CAPTURA'), findsOneWidget);
    // Sin captura no se puede enviar.
    expect(find.text('ENVIAR SOLICITUD'), findsOneWidget);
    await tester.tap(find.text('ENVIAR SOLICITUD'));
    await tester.pumpAndSettle();
    // Sigue en el paso de pago: no se creó ninguna solicitud.
    expect(find.text('Paga con Transfermóvil'), findsOneWidget);
    expect(find.text('En revisión'), findsNothing);
  });
}

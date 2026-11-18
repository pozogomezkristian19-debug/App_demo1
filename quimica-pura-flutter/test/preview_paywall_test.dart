// Fotos del paywall para Kristian (2026-11-17): la parte de
// información de pago y la tabla de comparación ya arreglada
// (flex 4/2/2, "10 al día"). Solo genera las fotos en
// ../../melli-qui-v6-previews/; no son goldens de regresión
// (no se comparan en verde salvo que existan).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/premium_paywall_screen.dart';
import 'package:quimica_pura/services/premium_service.dart';
import 'package:quimica_pura/services/remote_tuning.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Nunito REAL de assets/fonts (la misma del teléfono): sin
    // ella el texto sale en bloques negros (la fuente de pruebas
    // es Ahem) y, peor, el MaterialApp por defecto dibuja con
    // Roboto/Ahem y las medidas de "¿cabe?" no son las del
    // teléfono. El theme de pumpPaywall usa fontFamily 'Nunito'
    // para que la foto sea la que Kristian ve en su teléfono.
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
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Nunito'),
        home: const PremiumPaywallScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../melli-qui-v6-previews/$name'),
    );
  }

  testWidgets('paywall_planes: planes + comparación arreglada',
      (tester) async {
    await pumpPaywall(tester);
    expect(find.text('Quemia Premium'), findsOneWidget);
    expect(find.text('10 al día'), findsOneWidget);
    expect(find.text('CONTINUAR'), findsOneWidget);
    await shot(tester, 'paywall_planes.png');
  });

  testWidgets('paywall_pago: información de pago Transfermóvil',
      (tester) async {
    await pumpPaywall(tester);
    await tester.tap(find.text('CONTINUAR'));
    await tester.pumpAndSettle();
    expect(find.text('Paga con Transfermóvil'), findsOneWidget);
    expect(find.text('Tarjeta destino (EJEMPLO)'), findsOneWidget);
    expect(find.text('ELEGIR CAPTURA'), findsOneWidget);
    await shot(tester, 'paywall_pago.png');
  });
}

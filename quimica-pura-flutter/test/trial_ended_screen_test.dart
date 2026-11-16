// Pantalla "Se acabó tu prueba" (Kristian 2026-11-16): se pinta
// cuando terminan los 3 días gratis y explica que las pantallas
// bloqueadas necesitan Premium, pagado por Transfermóvil.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/trial_ended_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/premium_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppLang.code = 'es';
    PremiumService.resetForTests();
  });

  tearDown(() {
    PremiumService.resetForTests();
  });

  Future<void> pumpOpened(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TrialEndedScreen(),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text(tr('trialEndedTitle')), findsOneWidget);
  }

  testWidgets('se pinta: título, cuerpo, pago y lo gratis', (tester) async {
    await pumpOpened(tester);
    expect(find.text(tr('trialEndedBody')), findsOneWidget);
    expect(find.text(tr('trialEndedPayNote')), findsOneWidget);
    expect(find.text(tr('trialEndedFreeNote')), findsOneWidget);
    expect(
      find.text(tr('trialEndedSeePremium').toUpperCase()),
      findsOneWidget,
    );
    expect(
      find.text(tr('trialEndedContinueFree').toUpperCase()),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Ver Premium" cierra y pide el paywall', (tester) async {
    await pumpOpened(tester);
    await tester
        .tap(find.text(tr('trialEndedSeePremium').toUpperCase()));
    await tester.pumpAndSettle();
    expect(PremiumService.paywallRequested.value, 1);
    expect(find.text(tr('trialEndedTitle')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Seguir gratis" cierra sin pedir nada', (tester) async {
    await pumpOpened(tester);
    await tester
        .tap(find.text(tr('trialEndedContinueFree').toUpperCase()));
    await tester.pumpAndSettle();
    expect(PremiumService.paywallRequested.value, 0);
    expect(find.text(tr('trialEndedTitle')), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

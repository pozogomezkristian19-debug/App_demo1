// Corazones Premium: con Premium PAGADO vigente (solo web) al
// lado del corazón sale el símbolo de infinito (∞) EN VEZ DE UN
// NÚMERO, en todos los lugares donde se muestran los corazones:
// la píldora de la barra superior (LivesChip), la tarjeta de
// Cuenta (StatsCard) y Mis estadísticas (LivesChip compacto). El
// corazón sigue siendo el mismo; solo el número pasa a ∞. En
// móvil, siempre el número.
//
// La prueba de 3 días NO da ∞ (Kristian 2026-11-16): abre el
// contenido pero los corazones siguen siendo 5 al día, como
// gratis. Solo el Premium PAGADO tiene ∞.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quimica_pura/services/premium_service.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/lives_chip.dart';
import 'package:quimica_pura/widgets/stats_card.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadRobotoFonts();
    await loadNunitoFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.isDark = false;
    PremiumService.resetForTests();
  });

  tearDown(() {
    PremiumService.resetForTests();
  });

  Future<void> pumpChip(
    WidgetTester tester, {
    bool? unlimited,
    bool showMax = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LivesChip(
            lives: 3,
            showMax: showMax,
            unlimited: unlimited,
            // Sin pulso en tests: el corazón respira en bucle y
            // pumpAndSettle no terminaría nunca.
            pulse: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sin premium: el chip enseña el número, no ∞',
      (tester) async {
    await pumpChip(tester);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('∞'), findsNothing);
  });

  testWidgets('unlimited explícito: el chip enseña ∞ en vez del número',
      (tester) async {
    await pumpChip(tester, unlimited: true);
    expect(find.text('∞'), findsOneWidget);
    expect(find.text('3'), findsNothing);
  });

  testWidgets('con showMax y premium: solo ∞, sin "/10"', (tester) async {
    await pumpChip(tester, unlimited: true, showMax: true);
    expect(find.text('∞'), findsOneWidget);
    expect(find.text('3/10'), findsNothing);
  });

  testWidgets('automático: ∞ solo con Premium PAGADO; la prueba no da ∞',
      (tester) async {
    await pumpChip(tester);
    expect(find.text('3'), findsOneWidget);
    // La prueba da acceso completo (premiumNotifier) pero NO ∞:
    // los corazones siguen limitados (Kristian 2026-11-16).
    PremiumService.premiumNotifier.value = true;
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
    expect(find.text('∞'), findsNothing);
    // Aprobar en Admin (Premium pagado): el estado en vivo cambia
    // el chip solo a ∞.
    PremiumService.paidPremiumNotifier.value = true;
    await tester.pumpAndSettle();
    expect(find.text('∞'), findsOneWidget);
    expect(find.text('3'), findsNothing);
    // Vencer: vuelve el número solo.
    PremiumService.paidPremiumNotifier.value = false;
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
    expect(find.text('∞'), findsNothing);
  });

  testWidgets('automático en móvil: ∞ con Premium PAGADO (puerta kIsWeb quitada)',
      (tester) async {
    // La puerta kIsWeb se quitó 2026-11-16: en móvil, con Premium
    // PAGADO vigente, el chip muestra ∞ igual que en web.
    PremiumService.paidPremiumNotifier.value = true;
    await pumpChip(tester);
    expect(find.text('∞'), findsOneWidget);
    expect(find.text('3'), findsNothing);
  });

  testWidgets('StatsCard (Cuenta): ∞ con Premium pagado, número sin él',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StatsCard())),
    );
    await tester.pumpAndSettle();
    // Sin premium: el número de vidas (10 al empezar el día).
    expect(find.text('10'), findsOneWidget);
    expect(find.text('∞'), findsNothing);
    // La prueba (acceso completo sin pagar) NO da ∞.
    PremiumService.premiumNotifier.value = true;
    await tester.pumpAndSettle();
    expect(find.text('10'), findsOneWidget);
    expect(find.text('∞'), findsNothing);
    // Con Premium pagado: el corazón sigue, el número pasa a ∞.
    PremiumService.paidPremiumNotifier.value = true;
    await tester.pumpAndSettle();
    expect(find.text('∞'), findsOneWidget);
  });
}

// Precio de los planes más oscuro en el tema claro (Kristian
// 2026-11-16): el teal #00C2A8 sobre blanco daba contraste 2,26
// (WCAG pide 3,0 para texto grande, 16 pt extra-bold). El color
// del precio (`AppAccent.planPriceColor`) oscurece el acento en
// claro hasta ≥ 3,0; el violeta en claro ya daba 4,23 y se queda;
// en oscuro el acento ya pasa (teal 6,65 / violeta 3,82) y
// tampoco cambia.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/premium_paywall_screen.dart';
import 'package:quimica_pura/services/accent.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/brand_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
  });

  tearDown(() {
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
  });

  void setAccent(String accent) {
    UserPrefs.themeAccent = accent;
    UserPrefs.themeAccentNotifier.value = accent;
  }

  group('contraste WCAG del precio (≥ 3,0 en los 4 temas)', () {
    test('claro+verde: el teal (2,26) pasa a teal oscuro (3,24)', () {
      setAccent('verde');
      // ANTES: el acento tal cual, sobre blanco, no llegaba.
      expect(
        wcagContrastRatio(BrandColors.teal, Colors.white),
        lessThan(3.0),
      );
      // AHORA: el precio usa el acento oscurecido.
      expect(
        AppAccent.planPriceColor(isDark: false),
        BrandColors.tealDark,
      );
      expect(
        wcagContrastRatio(
          AppAccent.planPriceColor(isDark: false),
          Colors.white,
        ),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('claro+violeta: el violeta ya daba 4,23 y se queda', () {
      setAccent('violeta');
      expect(
        AppAccent.planPriceColor(isDark: false),
        BrandColors.violet,
      );
      expect(
        wcagContrastRatio(
          AppAccent.planPriceColor(isDark: false),
          Colors.white,
        ),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('oscuro: el acento ya pasa y no cambia (verde ni violeta)', () {
      for (final accent in ['verde', 'violeta']) {
        setAccent(accent);
        expect(
          AppAccent.planPriceColor(isDark: true),
          AppAccent.primary,
          reason: accent,
        );
        expect(
          wcagContrastRatio(
            AppAccent.planPriceColor(isDark: true),
            AppAccent.darkCard,
          ),
          greaterThanOrEqualTo(3.0),
          reason: accent,
        );
      }
    });
  });

  group('paywall: el precio pintado es el color oscuro en claro+verde',
      () {
    testWidgets('250 CUP en teal oscuro, no en teal claro',
        (tester) async {
      setAccent('verde');
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const Scaffold(body: PremiumPaywallScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // El precio de la tarjeta del plan (no el de la fila Monto
      // de Transfermóvil): el ancestro Card del título '1 mes'.
      final card = find
          .ancestor(
            of: find.text('1 mes'),
            matching: find.byType(Card),
          )
          .last;
      final price = tester.widget<Text>(
        find.descendant(of: card, matching: find.textContaining('CUP')),
      );
      expect(price.style!.color, BrandColors.tealDark);
      expect(
        wcagContrastRatio(price.style!.color!, Colors.white),
        greaterThanOrEqualTo(3.0),
      );
      expect(tester.takeException(), isNull);
    });
  });
}

// Premium REAL (solo web): lógica pura.
// Cálculo de vencimiento por plan, formato del contador
// días·hh:mm:ss, parseo de precios/tarjeta con fallbacks y
// decisión de candado gratis/premium. Sin Firebase ni widgets.

import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/services/premium.dart';

void main() {
  group('vencimiento por plan', () {
    test('1m son 30 días, 3m son 90, 12m son 365', () {
      final start = DateTime(2026, 11, 15, 12, 0);
      expect(premiumExpiryFor('1m', start), DateTime(2026, 12, 15, 12, 0));
      expect(premiumExpiryFor('3m', start), DateTime(2027, 2, 13, 12, 0));
      expect(premiumExpiryFor('12m', start), DateTime(2027, 11, 15, 12, 0));
    });

    test('plan desconocido no tiene vencimiento', () {
      expect(premiumExpiryFor('6m', DateTime.now()), isNull);
      expect(premiumExpiryFor('', DateTime.now()), isNull);
      expect(premiumExpiryFor(null, DateTime.now()), isNull);
    });

    test('ids de plan válidos', () {
      expect(isValidPremiumPlan('1m'), isTrue);
      expect(isValidPremiumPlan('3m'), isTrue);
      expect(isValidPremiumPlan('12m'), isTrue);
      expect(isValidPremiumPlan('2m'), isFalse);
      expect(premiumPlanById('3m')?.monthsLabel, '3 meses');
      expect(premiumPlanById('12m')?.days, 365);
    });
  });

  group('vigencia', () {
    test('vencimiento futuro es Premium, pasado no', () {
      final now = DateTime(2026, 11, 15, 12, 0);
      expect(
        isPremiumActive(DateTime(2026, 11, 16), now: now),
        isTrue,
      );
      expect(
        isPremiumActive(DateTime(2026, 11, 15, 11, 59, 59), now: now),
        isFalse,
      );
      expect(isPremiumActive(null, now: now), isFalse);
      expect(
        isPremiumActive(DateTime(2026, 11, 15, 12, 0), now: now),
        isFalse,
      );
    });

    test('tiempo restante: cero si venció o no hay vencimiento', () {
      final now = DateTime(2026, 11, 15, 12, 0);
      expect(
        premiumRemaining(DateTime(2026, 11, 16, 12, 0), now: now),
        const Duration(days: 1),
      );
      expect(premiumRemaining(DateTime(2026, 11, 14), now: now),
          Duration.zero);
      expect(premiumRemaining(null, now: now), Duration.zero);
    });
  });

  group('contador días · hh:mm:ss', () {
    test('con días', () {
      expect(
        formatPremiumCountdown(
          const Duration(days: 12, hours: 4, minutes: 5, seconds: 6),
        ),
        '12 d · 04:05:06',
      );
      expect(
        formatPremiumCountdown(const Duration(days: 1)),
        '1 d · 00:00:00',
      );
    });

    test('menos de un día: solo el reloj', () {
      expect(
        formatPremiumCountdown(
          const Duration(hours: 4, minutes: 5, seconds: 6),
        ),
        '04:05:06',
      );
      expect(formatPremiumCountdown(Duration.zero), '00:00:00');
      expect(
        formatPremiumCountdown(const Duration(seconds: -5)),
        '00:00:00',
      );
    });

    test('fecha corta dd/mm/aaaa', () {
      expect(formatPremiumDate(DateTime(2026, 12, 15)), '15/12/2026');
      expect(formatPremiumDate(DateTime(2027, 2, 3)), '03/02/2027');
    });
  });

  group('precios con fallbacks', () {
    test('sin mapa: los ejemplos 250 / 600 / 1800', () {
      final prices = parsePlanPrices(null);
      expect(prices, {'1m': 250, '3m': 600, '12m': 1800});
    });

    test('mapa remoto sano manda', () {
      final prices = parsePlanPrices({'1m': 300, '3m': 700, '12m': 2000});
      expect(prices, {'1m': 300, '3m': 700, '12m': 2000});
    });

    test('parcial o roto: solo lo sano cambia, el resto ejemplo', () {
      final prices = parsePlanPrices({'1m': 300, '3m': 'caro', '12m': -5});
      expect(prices['1m'], 300);
      expect(prices['3m'], 600);
      expect(prices['12m'], 1800);
      final zero = parsePlanPrices({'1m': 0, '3m': 1000000});
      expect(zero['1m'], 250);
      expect(zero['3m'], 600);
    });

    test('precio por plan', () {
      expect(premiumPriceFor('1m', {'1m': 250}), 250);
      expect(premiumPriceFor('3m', {}), 600);
    });

    test('precio en CUP con separador de miles', () {
      expect(formatCupPrice(250), '250');
      expect(formatCupPrice(600), '600');
      expect(formatCupPrice(1800), '1.800');
      expect(formatCupPrice(12500), '12.500');
      expect(formatCupPrice(0), '0');
    });
  });

  group('datos de Transfermóvil con fallbacks', () {
    test('sin campos: ejemplos y marca EJEMPLO', () {
      final tm = parseTransfermovilDetails({});
      expect(tm.card, kExampleTransfermovilCard);
      expect(tm.number, kExampleTransfermovilNumber);
      expect(tm.details, kExamplePaymentDetails);
      expect(tm.isExample, isTrue);
    });

    test('campos reales: sin marca EJEMPLO', () {
      final tm = parseTransfermovilDetails({
        'transfermovilCard': '9225 9999 8888 7777',
        'transfermovilNumber': '5355555555',
        'paymentDetails': 'Titular: Quemia',
      });
      expect(tm.card, '9225 9999 8888 7777');
      expect(tm.isExample, isFalse);
    });

    test('un campo real y los demás vacíos: sigue siendo ejemplo', () {
      final tm = parseTransfermovilDetails({
        'transfermovilCard': '9225 9999 8888 7777',
        'transfermovilNumber': '   ',
      });
      expect(tm.number, kExampleTransfermovilNumber);
      expect(tm.isExample, isTrue);
    });
  });

  group('decisión de candado / diamante / vidas', () {
    test('gratis: candado en Aprender, Resolver, Temas y Mis errores (web y móvil)', () {
      for (final section in PremiumLockedSection.values) {
        expect(
          premiumSectionLocked(
            isPremium: false,
            section: section,
          ),
          isTrue,
          reason: '$section debe tener candado si es gratis',
        );
      }
    });

    test('premium: sin candado en ninguna sección', () {
      for (final section in PremiumLockedSection.values) {
        expect(
          premiumSectionLocked(
            isPremium: true,
            section: section,
          ),
          isFalse,
        );
      }
    });

    // El diamante flotante se ELIMINÓ (Kristian 2026-11-15:
    // tapaba el texto del botón DESBLOQUEAR CON PREMIUM): ya no
    // hay función premiumDiamondVisible ni widget que probar. La
    // entrada a Premium queda en los botones DESBLOQUEAR y en la
    // fila Premium de Cuenta.
    // Corazones ilimitados: `isPremium` aquí es el Premium
    // PAGADO (la prueba NO da ∞, Kristian 2026-11-16).
    test('corazones ilimitados: solo con Premium PAGADO (web y móvil)', () {
      expect(premiumUnlimitedLives(isPremium: true), isTrue);
      expect(premiumUnlimitedLives(isPremium: false), isFalse);
    });

    test('sesión para Premium: Google o correo; el anónimo no', () {
      expect(
        premiumIsSignedIn(googleLinked: true, emailLinked: false),
        isTrue,
      );
      expect(
        premiumIsSignedIn(googleLinked: false, emailLinked: true),
        isTrue,
      );
      expect(
        premiumIsSignedIn(googleLinked: true, emailLinked: true),
        isTrue,
      );
      expect(
        premiumIsSignedIn(googleLinked: false, emailLinked: false),
        isFalse,
      );
    });

    test('paywall exige sesión si no hay sesión (web y móvil)', () {
      expect(
        premiumPaywallNeedsSignIn(isSignedIn: false),
        isTrue,
      );
      expect(
        premiumPaywallNeedsSignIn(isSignedIn: true),
        isFalse,
      );
    });
  });
}

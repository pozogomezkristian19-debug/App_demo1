// Prueba GRATIS de 3 días (Kristian 2026-11-15) + aviso visible
// + diamante ausente + paywall con planes separados + tarjeta de
// contraseña compacta en Cuenta.
//
// La prueba funciona en web Y en móvil (la puerta kIsWeb se quitó
// 2026-11-16).
// Todo local (SharedPreferences con mock): sin internet, sin
// Firestore real.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/account_screen.dart';
import 'package:quimica_pura/screens/premium_paywall_screen.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/auth_service.dart';
import 'package:quimica_pura/services/device_id.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/premium.dart';
import 'package:quimica_pura/services/premium_service.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/trial.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/trial_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  // La Roboto REAL (la altura de la tarjeta de contraseña depende
  // de cómo envuelve el texto: 175 pt con Roboto, 156 con la
  // fuente de test; el límite 190 vale para las dos).
  setUpAll(loadRobotoFonts);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    UserPrefs.userName = 'kristian';
    // OJO con el orden: PremiumService.resetForTests() llama a
    // TrialService.resetForTests().
    PremiumService.resetForTests();
    TrialService.resetForTests();
    AnalyticsSync.resetForTests();
    addTearDown(() {
      TrialService.instance.stop();
      TrialService.resetForTests();
      PremiumService.resetForTests();
      AuthService.resetForTests();
      DeviceId.resetForTests();
      UserPrefs.userName = '';
    });
  });

  group('lógica pura: 3 días, cuenta atrás, caducidad', () {
    test('la duración es 3 días', () {
      expect(trialDurationDays, 3);
    });

    test('activa al empezar, inactiva a los 3 días exactos', () {
      final now = DateTime(2026, 11, 15, 12, 0);
      final start = DateTime(2026, 11, 15, 12, 0);
      expect(trialActive(start, now: now), isTrue);
      expect(trialActive(null, now: now), isFalse);
      expect(
        trialActive(start, now: DateTime(2026, 11, 18, 11, 59, 59)),
        isTrue,
      );
      // A los 3 días exactos se ACABA SOLA.
      expect(
        trialActive(start, now: DateTime(2026, 11, 18, 12, 0)),
        isFalse,
      );
      expect(
        trialActive(start, now: DateTime(2026, 11, 19, 12, 0)),
        isFalse,
      );
    });

    test('días que quedan: redondeo hacia arriba, 0 al vencer', () {
      final start = DateTime(2026, 11, 15, 12, 0);
      expect(trialDaysLeft(start, now: start), 3);
      // Quedan 2 días y 23 horas → 3.
      expect(
        trialDaysLeft(start, now: DateTime(2026, 11, 15, 13, 0)),
        3,
      );
      // Quedan 2 días exactos → 2.
      expect(
        trialDaysLeft(start, now: DateTime(2026, 11, 16, 12, 0)),
        2,
      );
      // Queda media hora → 1.
      expect(
        trialDaysLeft(start, now: DateTime(2026, 11, 18, 11, 30)),
        1,
      );
      // Vencida → 0.
      expect(
        trialDaysLeft(start, now: DateTime(2026, 11, 18, 12, 0)),
        0,
      );
      expect(trialDaysLeft(null), 0);
    });

    test('el inicio más antiguo entre local y nube es el que manda',
        () {
      final local = DateTime(2026, 11, 15, 12, 0);
      final cloud = DateTime(2026, 11, 14, 12, 0);
      expect(trialEarliestStart(local, cloud), cloud);
      expect(trialEarliestStart(cloud, local), cloud);
      expect(trialEarliestStart(local, null), local);
      expect(trialEarliestStart(null, cloud), cloud);
      expect(trialEarliestStart(null, null), isNull);
    });

    test('el inicio más antiguo entre local, nube y teléfono manda',
        () {
      final local = DateTime(2026, 11, 15, 12, 0);
      final cloud = DateTime(2026, 11, 14, 12, 0);
      final device = DateTime(2026, 11, 13, 12, 0);
      expect(trialEarliestStart3(local, cloud, device), device);
      expect(trialEarliestStart3(device, local, cloud), device);
      expect(trialEarliestStart3(local, cloud, null), cloud);
      expect(trialEarliestStart3(local, null, null), local);
      expect(trialEarliestStart3(null, null, device), device);
      expect(trialEarliestStart3(null, null, null), isNull);
    });

    test('pantalla "Se acabó tu prueba": solo si la hubo y terminó',
        () {
      const base = (
        hadTrial: true,
        trialActiveNow: false,
        hasPaidPremium: false,
        alreadyShown: false,
      );
      // Prueba terminada, sin Premium, sin verla: SALE.
      expect(
        shouldShowTrialEnded(
          hadTrial: base.hadTrial,
          trialActiveNow: base.trialActiveNow,
          hasPaidPremium: base.hasPaidPremium,
          alreadyShown: base.alreadyShown,
        ),
        isTrue,
      );
      // Sin prueba: no sale (no hay nada que se haya acabado).
      expect(
        shouldShowTrialEnded(
          hadTrial: false,
          trialActiveNow: false,
          hasPaidPremium: false,
          alreadyShown: false,
        ),
        isFalse,
      );
      // Prueba activa: no sale.
      expect(
        shouldShowTrialEnded(
          hadTrial: true,
          trialActiveNow: true,
          hasPaidPremium: false,
          alreadyShown: false,
        ),
        isFalse,
      );
      // Con Premium pagado: no sale.
      expect(
        shouldShowTrialEnded(
          hadTrial: true,
          trialActiveNow: false,
          hasPaidPremium: true,
          alreadyShown: false,
        ),
        isFalse,
      );
      // Ya vista: no sale otra vez.
      expect(
        shouldShowTrialEnded(
          hadTrial: true,
          trialActiveNow: false,
          hasPaidPremium: false,
          alreadyShown: true,
        ),
        isFalse,
      );
    });
  });

  group('servicio: empieza sola al primer arranque, sin internet',
      () {
    test('primer arranque: guarda el inicio en local y avisa', () async {
      await TrialService.instance.start();
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(trialPrefsKey);
      expect(saved, isNotNull);
      expect(
        DateTime.now().millisecondsSinceEpoch - saved!,
        lessThan(5000),
      );
      expect(TrialService.isTrialActiveNow, isTrue);
      expect(TrialService.trialNotifier.value, isTrue);
      expect(TrialService.daysLeftNow, 3);
    });

    test('segundo arranque: NO sobrescribe el inicio guardado',
        () async {
      final twoDaysAgo =
          DateTime.now().subtract(const Duration(days: 2)).millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({trialPrefsKey: twoDaysAgo});
      await TrialService.instance.start();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(trialPrefsKey), twoDaysAgo);
      expect(TrialService.isTrialActiveNow, isTrue);
      expect(TrialService.daysLeftNow, 1);
    });

    test('inicio de hace 4 días: la prueba ya caducó, sin red',
        () async {
      final fourDaysAgo =
          DateTime.now().subtract(const Duration(days: 4)).millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({trialPrefsKey: fourDaysAgo});
      await TrialService.instance.start();
      expect(TrialService.isTrialActiveNow, isFalse);
      expect(TrialService.trialNotifier.value, isFalse);
      expect(TrialService.daysLeftNow, 0);
    });

    test('invitado y registrado: la prueba local no pide sesión',
        () async {
      // Sin sesión (invitado): arranca igual.
      AuthService.setProviderForTests(FakeAuthProvider());
      await TrialService.instance.start();
      expect(TrialService.isTrialActiveNow, isTrue);
      TrialService.instance.stop();
      TrialService.resetForTests();

      // Con sesión (registrado): mismo inicio local.
      SharedPreferences.setMockInitialValues({});
      final fake = FakeAuthProvider()..uid = 'fake-uid';
      AuthService.setProviderForTests(fake);
      await TrialService.instance.start();
      expect(TrialService.isTrialActiveNow, isTrue);
    });

    test('la nube más antigua gana; la más reciente no retrocede',
        () async {
      await TrialService.instance.start();
      final localStart = TrialService.instance.effectiveStart!;
      final localMs = localStart.millisecondsSinceEpoch;
      final older = localStart
          .subtract(const Duration(days: 2))
          .millisecondsSinceEpoch;
      TrialService.instance.applyCloudStart(older);
      // Comparar por milisegundos: DateTime.== distingue UTC de
      // local aunque sea el mismo instante (la nube se parsea UTC).
      expect(TrialService.instance.effectiveStart!.millisecondsSinceEpoch,
          older);
      expect(TrialService.daysLeftNow, 1);

      // Si la nube trae un inicio MÁS RECIENTE que el local, el
      // que manda sigue siendo el local (el más antiguo de los
      // dos): la prueba no se alarga por reinstalar ni por un
      // documento más nuevo.
      final newer = DateTime.now().millisecondsSinceEpoch;
      TrialService.instance.applyCloudStart(newer);
      expect(TrialService.instance.effectiveStart!.millisecondsSinceEpoch,
          localMs);
      expect(TrialService.daysLeftNow, 3);
    });
  });

  group('prueba por teléfono: no se borra ni reinstalando', () {
    const deviceId = 'android:test-device-1';

    test('primer arranque: crea el registro del teléfono', () async {
      DeviceId.setOverrideForTests(deviceId);
      final repo = InMemoryAnalyticsRepository();
      AnalyticsSync.setRepositoryForTests(repo);
      await TrialService.instance.start();
      await TrialService.instance.syncDeviceTrial();
      final doc =
          await repo.getDoc(deviceTrialsCollection, deviceId);
      expect(doc, isNotNull);
      final prefs = await SharedPreferences.getInstance();
      expect(doc![deviceTrialStartField], prefs.getInt(trialPrefsKey));
      expect(TrialService.instance.effectiveStart, isNotNull);
      expect(TrialService.isTrialActiveNow, isTrue);
      expect(TrialService.instance.hadTrial, isTrue);
    });

    test('reinstalar (local vacío, teléfono viejo): manda el teléfono',
        () async {
      DeviceId.setOverrideForTests(deviceId);
      final repo = InMemoryAnalyticsRepository();
      AnalyticsSync.setRepositoryForTests(repo);
      // El teléfono ya tuvo una prueba hace 5 días (vencida): el
      // registro existe antes de abrir la app "reinstalada" (sin
      // inicio local).
      final oldStart =
          DateTime.now().subtract(const Duration(days: 5));
      await repo.setDoc(deviceTrialsCollection, deviceId, {
        deviceTrialStartField: oldStart.millisecondsSinceEpoch,
        deviceTrialCreatedField: oldStart.millisecondsSinceEpoch,
      });
      await TrialService.instance.start();
      await TrialService.instance.syncDeviceTrial();
      // El inicio efectivo es el del teléfono (el más antiguo):
      // la prueba sigue VENCIDA aunque el local sea nuevo.
      expect(
        TrialService.instance.effectiveStart!.millisecondsSinceEpoch,
        oldStart.millisecondsSinceEpoch,
      );
      expect(TrialService.isTrialActiveNow, isFalse);
      expect(TrialService.daysLeftNow, 0);
      expect(TrialService.instance.hadTrial, isTrue);
    });

    test('sin id estable (web): no crea registro, no rompe nada',
        () async {
      // Sin override: en tests Platform no es Android ni iOS y
      // stableId() da null, como en web.
      final repo = InMemoryAnalyticsRepository();
      AnalyticsSync.setRepositoryForTests(repo);
      await TrialService.instance.start();
      await TrialService.instance.syncDeviceTrial();
      expect(
        await repo.getDoc(deviceTrialsCollection, deviceId),
        isNull,
      );
      expect(TrialService.isTrialActiveNow, isTrue);
    });
  });

  group('integración con Premium: acceso efectivo y candados', () {
    test('con prueba activa: Premium efectivo, sin candados', () async {
      await TrialService.instance.start();
      PremiumService.instance.recomputeNow();
      expect(PremiumService.premiumNotifier.value, isTrue);
      expect(
        premiumSectionLocked(

          isPremium: PremiumService.premiumNotifier.value,
          section: PremiumLockedSection.resolver,
        ),
        isFalse,
      );
      expect(
        premiumSectionLocked(

          isPremium: PremiumService.premiumNotifier.value,
          section: PremiumLockedSection.aprender,
        ),
        isFalse,
      );
      expect(
        premiumSectionLocked(

          isPremium: PremiumService.premiumNotifier.value,
          section: PremiumLockedSection.misErrores,
        ),
        isFalse,
      );
    });

    test('con prueba caducada: vuelven los candados y 10 corazones',
        () async {
      final fourDaysAgo =
          DateTime.now().subtract(const Duration(days: 4)).millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({trialPrefsKey: fourDaysAgo});
      await TrialService.instance.start();
      PremiumService.instance.recomputeNow();
      expect(PremiumService.premiumNotifier.value, isFalse);
      expect(PremiumService.hasPaidPremium, isFalse);
      expect(
        premiumSectionLocked(

          isPremium: PremiumService.premiumNotifier.value,
          section: PremiumLockedSection.resolver,
        ),
        isTrue,
      );
      expect(premiumUnlimitedLives(isPremium: false), isFalse);
    });
  });

  group('prueba: corazones LIMITADOS (solo el Premium pagado tiene ∞)', () {
    test('con prueba activa: acceso completo, pero sin ∞ y las vidas se gastan',
        () async {
      await TrialService.instance.start();
      PremiumService.instance.recomputeNow();
      // La prueba abre el contenido...
      expect(PremiumService.premiumNotifier.value, isTrue);
      // ...pero NO da corazones ilimitados (Kristian 2026-11-16).
      expect(PremiumService.paidPremiumNotifier.value, isFalse);
      expect(PremiumFlags.hasPaidPremium, isFalse);
      final p = ProgressService.instance;
      expect(p.livesLeft, 10);
      expect(p.canStartLevel, isTrue);
      p.loseLifeOnAbandon();
      expect(p.livesLeft, 9);
      expect(p.canStartLevel, isTrue);
      TrialService.instance.stop();
    });

    test('con Premium pagado: ∞ (las vidas no se gastan)', () async {
      PremiumService.expiresNotifier.value =
          DateTime.now().add(const Duration(days: 30));
      PremiumService.instance.recomputeNow();
      expect(PremiumService.paidPremiumNotifier.value, isTrue);
      expect(PremiumFlags.hasPaidPremium, isTrue);
      // La función pura: con Premium PAGADO, ∞.
      expect(premiumUnlimitedLives(isPremium: true), isTrue);
      // Y las vidas del servicio también son ilimitadas ahora
      // (la puerta kIsWeb se quitó 2026-11-16: ∞ en móvil también).
      expect(ProgressService.instance.livesLeft, 10);
      expect(ProgressService.instance.canStartLevel, isTrue);
    });
  });

  group('aviso visible de la versión de prueba', () {
    Future<void> pumpBanner(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const Scaffold(body: TrialBanner()),
        ),
      );
      await tester.pump();
    }

    testWidgets('con prueba: banner con los días que quedan',
        (tester) async {
      await TrialService.instance.start();
      await pumpBanner(tester);
      expect(find.byKey(const ValueKey('trialBanner')), findsOneWidget);
      expect(find.textContaining('te quedan 3 días'), findsOneWidget);
      // El temporizador de 30 s de la prueba hay que pararlo
      // DENTRO del cuerpo del test: el framework comprueba que
      // no queden temporizadores antes de correr los tearDown.
      TrialService.instance.stop();
    });

    testWidgets('sin prueba: el banner no ocupa nada', (tester) async {
      await pumpBanner(tester);
      expect(find.byKey(const ValueKey('trialBanner')), findsNothing);
    });
  });

  group('paywall: aviso de prueba y planes separados', () {
    Future<void> pumpPaywall(WidgetTester tester) async {
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
    }

    Finder planCardFor(String monthsLabel, WidgetTester tester) {
      final ancestors = find.ancestor(
        of: find.text(monthsLabel),
        matching: find.byType(Card),
      );
      // El título también puede salir en la tabla comparativa
      // (arriba): la tarjeta del plan es el ÚLTIMO ancestro.
      return ancestors.last;
    }

    testWidgets('con prueba: el paywall dice que estás en prueba',
        (tester) async {
      await TrialService.instance.start();
      await pumpPaywall(tester);
      expect(find.byKey(const ValueKey('trialNoticeCard')), findsOneWidget);
      expect(find.textContaining('te quedan 3 días'), findsOneWidget);
      // Parar el temporizador dentro del cuerpo (ver banner).
      TrialService.instance.stop();
    });

    testWidgets('sin prueba: el paywall no muestra el aviso',
        (tester) async {
      await pumpPaywall(tester);
      expect(find.byKey(const ValueKey('trialNoticeCard')), findsNothing);
    });

    testWidgets('las tarjetas de los planes van MUY separadas',
        (tester) async {
      await pumpPaywall(tester);
      final card1 = planCardFor('1 mes', tester);
      final card3 = planCardFor('3 meses', tester);
      final card12 = planCardFor('12 meses', tester);
      expect(card1, findsOneWidget);
      expect(card3, findsOneWidget);
      expect(card12, findsOneWidget);
      final y1 = tester.getCenter(card1).dy;
      final y3 = tester.getCenter(card3).dy;
      final y12 = tester.getCenter(card12).dy;
      // Antes iban pegadas (centros a ~50 pt); ahora cada tarjeta
      // es más alta y lleva 16 pt de margen: centros a más de 60.
      expect(y3 - y1, greaterThan(60));
      expect(y12 - y3, greaterThan(60));
    });
  });

  group('Cuenta: tarjeta de contraseña compacta y separada', () {
    testWidgets('compacta (baja) y con hueco respecto a la cabecera',
        (tester) async {
      final fake = FakeAuthProvider()
        ..uid = 'fake-uid'
        ..googleLinked = true
        ..emailLinked = false;
      AuthService.setProviderForTests(fake);
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          // AccountProfilePage (no AccountScreen suelta): el nombre
          // vive en la cabecera (AppBar, perfil estilo Duolingo
          // 2026-11-16) y es el ancla del hueco que mide el test;
          // en AccountScreen sola ya no hay ningún texto con el
          // nombre.
          home: AccountProfilePage(
            onOpenScreen: (_) {},
            onShowAbout: () {},
            onShowShareApp: () {},
            trackTopics: const ['estequiometria'],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final card = find.byKey(const ValueKey('passwordPromptCard'));
      expect(card, findsOneWidget);
      final box = tester.getSize(card);
      // Compacta: mide 175 pt con la Roboto real; la tarjeta
      // vieja (padding 16, icono 48, textos 16/14) pasaba de
      // 195. El límite 190 caza una vuelta a los tamaños viejos.
      expect(box.height, lessThan(190));
      // Separación: entre el nombre de la cabecera (AppBar,
      // "kristian") y la tarjeta hay el resto de la cabecera +
      // hueco (12) + hueco (12) = más de 24 pt. Antes la tarjeta
      // iba pegada a la de Cuenta (unos 12 pt hasta el saludo).
      final nameBottom =
          tester.getBottomLeft(find.textContaining('kristian')).dy;
      final cardTop = tester.getTopLeft(card).dy;
      expect(cardTop - nameBottom, greaterThan(24));
    });
  });

  group('diamante flotante: ausente en todas partes', () {
    testWidgets('ninguna pantalla muestra el diamante', (tester) async {
      // El widget ya no existe en la app: la clave no aparece ni
      // en el paywall (la pantalla con el botón DESBLOQUEAR que
      // tapaba en las capturas de Kristian).
      await TrialService.instance.start();
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
      expect(find.byKey(const ValueKey('premiumDiamondFab')), findsNothing);
      // Parar el temporizador dentro del cuerpo (ver banner).
      TrialService.instance.stop();
    });
  });

  group('traducciones del aviso (todas las claves existen)', () {
    test('español: banner, paywall y fila de Cuenta', () {
      expect(
        tr('trialBannerDays').replaceFirst('%s', '3'),
        'Versión de prueba · te quedan 3 días',
      );
      expect(tr('trialBannerDay'), 'Versión de prueba · te queda 1 día');
      expect(
        tr('trialPaywallDays').replaceFirst('%s', '3'),
        contains('te quedan 3 días'),
      );
      expect(tr('accountPremium'), 'Premium');
      expect(tr('accountPremiumFree'), 'Estudia sin límites');
    });
  });
}

// Vistas previas de Referidos (Quemia 7.3). Se ejecuta con
// --update-goldens para ESCRIBIR los PNG en
// ~/workspace/melli-qui-v6-previews/ (nombres foto73_referidos_*).
// Viewport 393x852 (dpr 2), Roboto + MaterialIcons + Nunito
// reales. Los temas se reutilizan de preview_quemia73_test.dart.
// El calentamiento precachea las imágenes (gemelas, logos de
// WhatsApp/Messenger y avatares de recompensa) con runAsync +
// precacheImage, como en preview_quemia73_test.dart: sin eso la
// primera captura sale con los huecos en blanco.
//
// - foto73_referidos_invitar_claro / _oscuro: Invitar con el
//   código Q8M4K2, 2 de 10 referidos, 5 de 10 usos, aviso de
//   Vanessa0394 y los que más invitan.
// - foto73_referidos_canjear_claro / _oscuro: Canjear código con
//   las 6 casillas y el regalo.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/referrals_screen.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/auth_service.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/social_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preview_quemia73_test.dart' as q73;
import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadRobotoFonts();
    await loadMaterialIcons();
    await loadNunitoFonts();
  });

  late InMemoryAnalyticsRepository fake;
  late FakeAuthProvider authFake;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'referral_my_code': 'Q8M4K2',
      'referral_count': 2,
      'referral_last_invitee': 'Vanessa0394',
    });
    await ProgressService.load();
    ProgressService.track = ProgressService.trackUni;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global/events'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (call) async => 'America/Havana',
    );
    UserPrefs.rulesSeenV6 = true;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    await UserPrefs.saveThemeMode('claro');
    UserPrefs.isDark = false;
    UserPrefs.onboardingDone = true;
    UserPrefs.userName = 'Kristian';
    UserPrefs.userGender = 'Masculino';
    UserPrefs.publicUsername = '';
    UserPrefs.track = 'uni';
    SocialService.setRepositoryForTests(InMemorySocialRepository());
    AnalyticsSync.resetForTests();
    AnalyticsSync.markFirebaseReady();
    fake = InMemoryAnalyticsRepository();
    authFake = FakeAuthProvider();
    AnalyticsSync.setRepositoryForTests(fake);
    AuthService.setProviderForTests(authFake);
    await AuthService.ensureAnonymous();
    await authFake.linkWithGoogle();
    // Semilla: el código Q8M4K2 con 5 usos ya gastados (quedan
    // 5 de 10) y tres usuarios en la tabla de los que más invitan.
    await fake.setDoc('referral_codes', 'Q8M4K2', {
      'uid': 'fake-anon-uid',
      'createdAtMs': 1,
      'maxUses': 10,
    }, merge: false);
    for (var i = 0; i < 5; i++) {
      await fake.createDoc('referrals', {
        'code': 'Q8M4K2',
        'inviterUid': 'fake-anon-uid',
        'inviteeUid': 'guest-$i',
        'inviteeUsername': 'Guest$i',
        'status': 'rewarded',
        'inviterRewarded': true,
        'createdAtMs': 1,
      });
    }
    await fake.setUser(
        'top-1', {'username': 'Ana', 'referralsCount': 12});
    await fake.setUser(
        'top-2', {'username': 'Luis', 'referralsCount': 8});
    await fake.setUser('top-3', {'username': 'Mia', 'referralsCount': 5});
  });

  tearDown(() {
    SocialService.resetForTests();
    AnalyticsSync.resetForTests();
    AuthService.resetForTests();
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = false;
    UserPrefs.isDark = false;
    UserPrefs.userName = '';
    UserPrefs.publicUsername = '';
  });

  Future<void> setPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../melli-qui-v6-previews/$name'),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    bool dark = false,
  }) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? q73.melliDarkTheme() : q73.melliLightTheme(),
        home: screen,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  // Calentamiento: decodifica las imágenes (gemelas, logos de
  // WhatsApp/Messenger, avatares de recompensa) ANTES de la
  // primera captura, esperando la decodificación de verdad con
  // runAsync + precacheImage.
  testWidgets('warm-up imágenes referidos', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: q73.melliLightTheme(),
        home: const Scaffold(
          body: Row(
            key: Key('warmup'),
            children: [
              Image(image: AssetImage('assets/brenda.png'),
                  width: 40, height: 40),
              Image(image: AssetImage('assets/britany.png'),
                  width: 40, height: 40),
              Image(image: AssetImage('assets/whatsapp.png'),
                  width: 40, height: 40),
              Image(image: AssetImage('assets/messenger.png'),
                  width: 40, height: 40),
              Image(image: AssetImage('assets/avatar_embajador.png'),
                  width: 40, height: 40),
              Image(image: AssetImage('assets/avatar_leyenda.png'),
                  width: 40, height: 40),
              Image(image: AssetImage('assets/avatar_default.png'),
                  width: 40, height: 40),
            ],
          ),
        ),
      ),
    );
    final context = tester.element(find.byKey(const Key('warmup')));
    await tester.runAsync(() async {
      for (final name in [
        'brenda',
        'britany',
        'whatsapp',
        'messenger',
        'avatar_embajador',
        'avatar_leyenda',
        'avatar_default',
      ]) {
        await precacheImage(AssetImage('assets/$name.png'), context);
      }
    });
    await settle(tester);
  });

  group('foto73 referidos invitar', () {
    testWidgets('foto73_referidos_invitar_claro', (tester) async {
      await pumpScreen(
          tester, const ReferralsScreen(isGoogleLinked: true));
      await settle(tester);
      expect(find.text('Q8M4K2'), findsOneWidget);
      await shot(tester, 'foto73_referidos_invitar_claro.png');
    });

    testWidgets('foto73_referidos_invitar_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const ReferralsScreen(isGoogleLinked: true),
        dark: true,
      );
      await settle(tester);
      expect(find.text('Q8M4K2'), findsOneWidget);
      await shot(tester, 'foto73_referidos_invitar_oscuro.png');
    });
  });

  group('foto73 referidos canjear', () {
    testWidgets('foto73_referidos_canjear_claro', (tester) async {
      await pumpScreen(
          tester, const RedeemCodeScreen(isGoogleLinked: true));
      await shot(tester, 'foto73_referidos_canjear_claro.png');
    });

    testWidgets('foto73_referidos_canjear_oscuro', (tester) async {
      await pumpScreen(
        tester,
        const RedeemCodeScreen(isGoogleLinked: true),
        dark: true,
      );
      await shot(tester, 'foto73_referidos_canjear_oscuro.png');
    });
  });
}

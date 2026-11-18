// Fotos del fondo animado del perfil para Kristian (2026-11-17):
// el perfil de alguien que compró un tema, con el fondo en
// movimiento cuando hay internet, y plano sin internet. La
// animación es el confetti de ejemplo (el dragón que pidió se
// descarga aparte: LottieFiles exige cuenta para bajarlo). Solo
// genera las fotos en ../../melli-qui-v6-previews/; no son
// goldens de regresión (no se comparan en verde salvo que
// existan).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/public_profile_screen.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/auth_service.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/social_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadNunitoFonts();
  });

  late FakeAuthProvider fakeAuth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    UserPrefs.userName = 'Kristian Pozo';
    UserPrefs.publicUsername = '';
    AppLang.code = 'es';
    fakeAuth = FakeAuthProvider()
      ..uid = 'dev-kristian'
      ..googleLinked = true
      ..email = 'kristian@example.com'
      ..displayName = 'Kristian Pozo';
    AuthService.setProviderForTests(fakeAuth);
    SocialService.setRepositoryForTests(
      InMemorySocialRepository(seedDemo: true),
    );
    AnalyticsSync.setRepositoryForTests(InMemoryAnalyticsRepository());
  });

  tearDown(() {
    SocialService.resetForTests();
    AnalyticsSync.resetForTests();
    AuthService.resetForTests();
    UserPrefs.userName = '';
    UserPrefs.publicUsername = '';
  });

  /// Avance acotado (nunca pumpAndSettle: el Lottie en bucle no
  /// se asienta). Cubre la carga del perfil y deja que la
  /// animación avance para que la foto la coja en movimiento.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> pumpProfile(
    WidgetTester tester, {
    required String? backgroundAsset,
    required bool backgroundOnline,
    String? fullBackgroundAsset,
    bool fullBackgroundOnline = true,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Nunito', brightness: brightness),
        home: PublicProfileScreen(
          uid: 'dev-laura',
          backgroundAsset: backgroundAsset,
          backgroundOnline: backgroundOnline,
          fullBackgroundAsset: fullBackgroundAsset,
          fullBackgroundOnline: fullBackgroundOnline,
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/avatar_default.png'),
        tester.element(find.byType(MaterialApp)),
      );
    });
    await settle(tester);
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../melli-qui-v6-previews/$name'),
    );
  }

  testWidgets('perfil_fondo_animado: fondo en movimiento con internet',
      (tester) async {
    await pumpProfile(
      tester,
      backgroundAsset: 'assets/confetti.json',
      backgroundOnline: true,
    );
    expect(find.text('SEGUIR'), findsOneWidget);
    await shot(tester, 'perfil_fondo_animado.png');
  });

  testWidgets('perfil_sin_internet: fondo plano sin internet',
      (tester) async {
    await pumpProfile(
      tester,
      backgroundAsset: 'assets/confetti.json',
      backgroundOnline: false,
    );
    expect(find.text('SEGUIR'), findsOneWidget);
    await shot(tester, 'perfil_sin_internet.png');
  });

  testWidgets(
      'perfil_fondo_completo: fondo premium negro, animación '
      'atenuada y difuminada, letras legibles', (tester) async {
    await pumpProfile(
      tester,
      backgroundAsset: null,
      backgroundOnline: true,
      // Confetti otra vez (2026-11-17 19:0x): el fuego resultó
      // ser un personajito que tapa el perfil; el confetti con
      // la opacidad nueva (0.6) sí se debe ver sin tapar nada.
      fullBackgroundAsset: 'assets/confetti.json',
      fullBackgroundOnline: true,
      brightness: Brightness.dark,
    );
    expect(find.text('SEGUIR'), findsOneWidget);
    await shot(tester, 'perfil_fondo_completo.png');
  });
}

// Zona E2 — splash del logo en cada arranque en frío (Quemia 7.1).
//
// El logo (anillo órbita: assets/app_icon.png en claro,
// assets/ring_logo.png transparente en oscuro, NUNCA las gemelas)
// sobre el fondo del tema, ~1 s, y luego a la principal o al
// onboarding si es la primera vez. Sin red ni Firebase en la espera.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/onboarding_screen.dart';
import 'package:quimica_pura/screens/splash_screen.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

ThemeData _lightTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF00C2A8),
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: Color(0xFF4B4B4B),
        surfaceContainerHighest: Color(0xFFF7F7F7),
        error: Color(0xFFFF4B4B),
      ),
    );

ThemeData _darkTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF131F24),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF5EEAD4),
        onPrimary: Color(0xFF131F24),
        surface: Color(0xFF1F2C34),
        onSurface: Color(0xFFE6F4EE),
        surfaceContainerHighest: Color(0xFF1B3A31),
        error: Color(0xFFFF4B4B),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  Future<void> setPhone(
    WidgetTester tester, {
    double width = 360,
    double height = 800,
  }) async {
    tester.view.physicalSize = Size(width * 2, height * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> pumpSplash(
    WidgetTester tester, {
    required ThemeData theme,
    VoidCallback? onDone,
    Duration holdDuration = kSplashHoldDuration,
    double width = 360,
    double height = 800,
  }) async {
    await setPhone(tester, width: width, height: height);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: SplashScreen(
          onDone: onDone ?? () {},
          holdDuration: holdDuration,
        ),
      ),
    );
    await tester.pump();
  }

  group('Zona E2 — el splash enseña el logo sobre el fondo del tema', () {
    testWidgets('tema claro: logo del anillo centrado sobre fondo blanco',
        (tester) async {
      await pumpSplash(tester, theme: _lightTheme());
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.white);
      final image = tester.widget<Image>(find.byKey(const Key('splashLogo')));
      expect((image.image as AssetImage).assetName, 'assets/app_icon.png');
      // Centrado en la pantalla de 360x800. 128 dp (Quemia 7.5):
      // el anillo visible queda en ~94 dp, igual que el splash
      // nativo (splash_logo.png 512 px en xxxhdpi, anillo 73%);
      // a 180 dp el logo pegaba un salto a más grande y parecía
      // que la app cargaba dos veces.
      final rect = tester.getRect(find.byKey(const Key('splashLogo')));
      expect(rect.center, const Offset(180, 400));
      expect(rect.width, 128);
      expect(rect.height, 128);
      // Sin desbordamiento: el logo cabe entero en la pantalla.
      expect(rect.left, greaterThanOrEqualTo(0.0));
      expect(rect.top, greaterThanOrEqualTo(0.0));
      expect(rect.right, lessThanOrEqualTo(360.0));
      expect(rect.bottom, lessThanOrEqualTo(800.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('tema oscuro: anillo transparente sin baldosa sobre fondo oscuro #131F24',
        (tester) async {
      await pumpSplash(tester, theme: _darkTheme());
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFF131F24));
      final image = tester.widget<Image>(find.byKey(const Key('splashLogo')));
      // En oscuro el anillo va SIN la baldosa blanca (Kristian,
      // 2026-11-12): assets/ring_logo.png, el PNG transparente.
      expect((image.image as AssetImage).assetName, 'assets/ring_logo.png');
      final rect = tester.getRect(find.byKey(const Key('splashLogo')));
      expect(rect.center, const Offset(180, 400));
      expect(tester.takeException(), isNull);
    });

    testWidgets('nunca usa el logo de las gemelas (assets/logo.png)',
        (tester) async {
      for (final theme in [_lightTheme(), _darkTheme()]) {
        await pumpSplash(tester, theme: theme);
        final images = tester.widgetList<Image>(find.byType(Image));
        expect(
          images.where((w) => (w.image as AssetImage).assetName ==
              'assets/logo.png'),
          isEmpty,
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin texto ni botones: solo el logo, sin scroll',
        (tester) async {
      await pumpSplash(tester, theme: _lightTheme());
      expect(find.byType(Text), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(Scrollable), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Zona E2 — la espera de ~1 s y el paso a la siguiente pantalla', () {
    testWidgets('onDone NO se llama antes de 1 s y SÍ justo después',
        (tester) async {
      var done = 0;
      await pumpSplash(tester,
          theme: _lightTheme(), onDone: () => done++);
      expect(done, 0);
      await tester.pump(const Duration(milliseconds: 999));
      expect(done, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(done, 1);
      // Una sola vez, aunque pase más tiempo.
      await tester.pump(const Duration(seconds: 2));
      expect(done, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la duración por defecto es 1 s exactos', (tester) async {
      expect(kSplashHoldDuration, const Duration(milliseconds: 1000));
    });
  });

  group('Zona E2 — la app entera: splash y luego principal u onboarding',
      () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ProgressService.load();
      UserPrefs.themeAccent = 'verde';
      UserPrefs.themeAccentNotifier.value = 'verde';
      await UserPrefs.saveThemeMode('claro');
      UserPrefs.isDark = false;
      UserPrefs.userName = 'kristian';
    });

    Future<void> pumpApp(WidgetTester tester) async {
      await setPhone(tester);
      await tester.pumpWidget(const MelliQuiApp());
      await tester.pump();
    }

    testWidgets('con onboarding hecho: logo ~1 s y luego la principal',
        (tester) async {
      UserPrefs.onboardingDone = true;
      await pumpApp(tester);
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      await tester.pump(const Duration(milliseconds: 999));
      expect(find.byType(SplashScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      // Y no vuelve a salir el logo al reconstruir.
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('primera vez: tras el logo sale el onboarding, no la '
        'principal', (tester) async {
      UserPrefs.onboardingDone = false;
      await pumpApp(tester);
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

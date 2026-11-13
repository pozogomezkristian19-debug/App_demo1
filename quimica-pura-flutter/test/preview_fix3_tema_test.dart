// Vistas previas del ÚLTIMO cambio de la ronda fix3 (2026-11-10):
// Tema ya no es una tarjeta inline en Cuenta, es una fila táctil
// ("Verde · Claro") que abre su propia pantalla dedicada. Se
// ejecuta con --update-goldens para ESCRIBIR los PNG en
// ~/workspace/melli-qui-v6-previews/ (nombres fix3_*). Viewport
// 360x800 (dpr 2), Roboto real, temas fieles de la app. Mismo patrón
// que test/preview_fix3_tanda3_test.dart. Archivo SEPARADO: no
// tocar test/preview_fix3_test.dart ni
// test/preview_fix3_tanda3_test.dart (otros agentes los usan).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/account_screen.dart';
import 'package:quimica_pura/screens/theme_screen.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

/// Réplica fiel del tema claro de MelliQuiApp (ver
/// preview_fix3_tanda3_test.dart): teal #00C2A8 con acento Verde.
ThemeData melliLightTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.light(
        primary: const Color(0xFF00C2A8),
        onPrimary: Colors.white,
        secondary: const Color(0xFF8B5CF6),
        surface: Colors.white,
        onSurface: const Color(0xFF3C3C3C),
        surfaceContainerHighest: const Color(0xFFF7F7F7),
        error: const Color(0xFFEF4444),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF3C3C3C),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Color(0xFF3C3C3C),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.10),
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );

/// Carga la fuente de iconos Material del SDK para que los iconos
/// (campana, menú, flechas) se dibujen de verdad en las capturas.
Future<void> loadMaterialIcons() async {
  final home = Platform.environment['HOME'] ?? '';
  final file = File('$home/sdks/flutter-3.47.9/bin/cache/artifacts/'
      'material_fonts/MaterialIcons-Regular.otf');
  if (!await file.exists()) return;
  final bytes = await file.readAsBytes();
  final loader = FontLoader('MaterialIcons');
  loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadRobotoFonts();
    await loadMaterialIcons();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    UserPrefs.rulesSeenV6 = true;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    await UserPrefs.saveThemeMode('claro');
    UserPrefs.onboardingDone = true;
    UserPrefs.isDark = false;
    // Nombre y género para que el saludo muestre SOLO el primer
    // nombre ("Kristian", 2026-11-13) como en el teléfono real.
    UserPrefs.userName = 'Kristian';
    UserPrefs.userGender = 'Masculino';
    // Los tres compañeros ya se presentaron: las burbujas muestran
    // la frase variada que toca, no el saludo de presentación.
    UserPrefs.metBrenda = true;
    UserPrefs.metBritany = true;
    UserPrefs.metKristian = true;
  });

  tearDown(() {
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = false;
    UserPrefs.isDark = false;
    UserPrefs.userName = '';
    UserPrefs.userGender = '';
    UserPrefs.metBrenda = false;
    UserPrefs.metBritany = false;
    UserPrefs.metKristian = false;
  });

  Future<void> setPhone(WidgetTester tester,
      {double width = 360, double height = 800}) async {
    tester.view.physicalSize = Size(width * 2, height * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> shot(WidgetTester tester, String name) async {
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

  /// Una pantalla suelta con el tema real de la app.
  Future<void> pumpScreen(WidgetTester tester, Widget child,
      {double height = 800}) async {
    await setPhone(tester, height: height);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: melliLightTheme(),
        home: Scaffold(body: child),
      ),
    );
    await settle(tester);
  }

  // Calentamiento: decodifica las imágenes (los tres compañeros,
  // logo, WhatsApp y el avatar por defecto del círculo de Cuenta)
  // ANTES de la primera captura, esperando la decodificación de
  // verdad con runAsync + precacheImage.
  testWidgets('warm-up imágenes', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Row(
            key: Key('warmup'),
            children: [
              Image(
                  image: AssetImage('assets/brenda.png'),
                  width: 40,
                  height: 40),
              Image(
                  image: AssetImage('assets/britany.png'),
                  width: 40,
                  height: 40),
              Image(
                  image: AssetImage('assets/kristian.png'),
                  width: 40,
                  height: 40),
              Image(
                  image: AssetImage('assets/logo.png'), width: 40, height: 40),
              Image(
                  image: AssetImage('assets/whatsapp.png'),
                  width: 40,
                  height: 40),
              Image(
                  image: AssetImage('assets/avatar_default.png'),
                  width: 40,
                  height: 40),
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
        'kristian',
        'logo',
        'whatsapp',
        'avatar_default'
      ]) {
        await precacheImage(AssetImage('assets/$name.png'), context);
      }
    });
    await settle(tester);
  });

  testWidgets('fix3_cuenta (fila Tema, cabecera Quemia)', (tester) async {
    await pumpScreen(
        tester,
        AccountScreen(
          onOpenScreen: (_) {},
          onShowAbout: () {},
          onShowShareApp: () {},
          trackTopics: const ['estequiometria'],
        ));
    // El avatar del círculo (kristian: género Masculino en el
    // setUp de este archivo) y la miniatura de "Hoy te acompaña…"
    // (compañero del día) se decodifican en real-async: sin
    // precache, la primera captura del proceso los pilla vacíos
    // (el warm-up no corre cuando el test se lanza solo con
    // --plain-name). Precargarlos aquí hace el golden
    // determinista en ambos casos.
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(AccountScreen));
      await precacheImage(
        const AssetImage('assets/kristian.png'),
        ctx,
      );
      for (final name in ['brenda', 'britany']) {
        await precacheImage(AssetImage('assets/$name.png'), ctx);
      }
    });
    await settle(tester);
    await shot(tester, 'fix3_cuenta.png');
  });

  testWidgets('fix3_tema (pantalla dedicada, color + modo)', (tester) async {
    // Se entra como en la app real (una ruta empujada sobre Cuenta,
    // para que la captura tenga la AppBar "Tema" con la flecha
    // atrás), pero sin tocar la fila: el toque suena (SoundService)
    // y en el entorno de test el plugin de audio no existe, lo que
    // deja una excepción asíncrona que marca el test como fallido
    // aunque la captura salga bien. La navegación por toque ya la
    // cubre fix3_theme_mode_test.dart.
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: melliLightTheme(),
        home: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ThemeScreen()),
              );
            });
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );
    await settle(tester);
    expect(find.byType(ThemeScreen), findsOneWidget);
    await shot(tester, 'fix3_tema.png');
  });
}

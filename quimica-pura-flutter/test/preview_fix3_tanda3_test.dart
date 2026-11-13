// Vistas previas de la ronda fix3, TERCERA TANDA (2026-11-10): Niveles,
// Cuenta y la calculadora científica en el quiz. Se ejecuta con
// --update-goldens para ESCRIBIR los PNG en
// ~/workspace/melli-qui-v6-previews/ (nombres fix3_*). Viewport
// 360x800 (dpr 2), Roboto real, temas fieles de la app. Mismo patrón
// que test/preview_fix3_test.dart. NO tocar lib/ desde aquí: solo
// capturas. NO tocar los fix2_*.png.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/account_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/question_generator.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/simple_quiz.dart';
import 'package:quimica_pura/widgets/twin_avatars.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

/// Réplica fiel del tema claro de MelliQuiApp (ver
/// preview_fix3_test.dart): teal #00C2A8 con acento Verde.
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

/// Réplica fiel del tema oscuro de MelliQuiApp (_darkTheme):
/// fondo verde muy oscuro, acentos SOLO menta/teal.
ThemeData melliDarkTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0A1F1A),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF7DE8D3),
        onPrimary: Color(0xFF0A1F1A),
        secondary: Color(0xFF00C2A8),
        surface: Color(0xFF122B24),
        onSurface: Color(0xFFE6F4EE),
        surfaceContainerHighest: Color(0xFF1B3A31),
        error: Color(0xFFEF4444),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A1F1A),
        foregroundColor: Color(0xFFE6F4EE),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Color(0xFFE6F4EE),
        ),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF122B24),
        elevation: 0,
        margin: EdgeInsets.symmetric(vertical: 6),
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
    UserPrefs.onboardingDone = true;
    UserPrefs.isDark = false;
    // Nombre y género para que el saludo muestre SOLO el primer
    // nombre ("Kristian", 2026-11-13) como en el teléfono real
    // (en fix2 el nombre estaba vacío y salía solo "Hola").
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

  /// La app real: Niveles (home).
  Future<void> pumpApp(WidgetTester tester) async {
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
  }

  /// Una pantalla suelta con el tema real de la app.
  Future<void> pumpScreen(WidgetTester tester, Widget child,
      {bool dark = false, double height = 800}) async {
    await setPhone(tester, height: height);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? melliDarkTheme() : melliLightTheme(),
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

  testWidgets('fix3_niveles (barra limpia, camino)', (tester) async {
    // El compañero del día lo decide la fecha (día % 3): hoy
    // 2026-11-10 → 10 % 3 = 1 → Britany. No se puede forzar a
    // Kristian desde el test: PracticarScreen llama a
    // companionOfTheDay() sin fecha.
    await pumpApp(tester);
    await shot(tester, 'fix3_niveles.png');
  });

  testWidgets('fix3_cuenta (cabecera compañero, Tema completo)',
      (tester) async {
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

  // Quiz de cálculo con la calculadora científica: pregunta de pH
  // ([H+] = 1×10^-2 → pH = 2) y la expresión −log(0.01) tecleada
  // en la PANTALLA de la calculadora (ronda fix5: ya no es un panel
  // inline), con el resultado 2 en el visor. La burbuja es de
  // Brenda (companionForTurn(0)) con su frase variada de pregunta.
  Future<void> pumpPhQuiz(WidgetTester tester, {bool dark = false}) async {
    final q = buildPh('ph', 1, 2).question;
    await pumpScreen(
        tester,
        SimpleQuizRunner(
          title: 'Ácido-base · Nivel 1',
          items: [q],
          onFinished: (_, __) {},
          onExit: () {},
        ),
        dark: dark,
        height: 1050);
    // Se abre la pantalla de la calculadora desde el campo de
    // respuesta (seguimiento 7.2: el botoncito junto a la pregunta
    // se quitó) y se teclea ahí. Las teclas son FilledButton u
    // OutlinedButton con su etiqueta.
    await tester.tap(find.byKey(const Key('numeric-answer-field')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    Finder key(String label) {
      final filled = find.widgetWithText(FilledButton, label);
      if (filled.evaluate().isNotEmpty) return filled;
      return find.widgetWithText(OutlinedButton, label);
    }

    for (final label in ['−', 'log', '0', '.', '0', '1', ')', '=']) {
      await tester.tap(key(label));
      await tester.pump();
    }
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('fix3_quiz_calculadora (pH con calculadora abierta)',
      (tester) async {
    await pumpPhQuiz(tester);
    await shot(tester, 'fix3_quiz_calculadora.png');
  });

  testWidgets('fix3_quiz_calculadora_dark (pH, tema oscuro)', (tester) async {
    await pumpPhQuiz(tester, dark: true);
    await shot(tester, 'fix3_quiz_calculadora_dark.png');
  });

  // Burbuja de pregunta con otro compañero (Kristian) y frase
  // variada: la burbuja sola con la pregunta debajo, como en el
  // quiz, pero sin teclado (conceptual).
  testWidgets('fix3_burbuja (Kristian, frase variada)', (tester) async {
    await pumpScreen(
        tester,
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MascotBubble(
                companion: Companion.kristian,
                text: tr(mascotLineKey(Companion.kristian, MascotLine.ask, 2)),
              ),
              const SizedBox(height: 16),
              const Text(
                '¿Qué es el reactivo limitante?',
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3C3C3C)),
              ),
            ],
          ),
        ));
    await shot(tester, 'fix3_burbuja.png');
  });
}

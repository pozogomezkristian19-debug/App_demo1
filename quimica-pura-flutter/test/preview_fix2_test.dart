// Vistas previas de la ronda fix2 (2026-11-10): capturas reales de
// la app con golden files. Se ejecuta con --update-goldens para
// ESCRIBIR los PNG en ~/workspace/melli-qui-v6-previews/ (nombres
// fix2_*). Un test por pantalla, viewport 360x800 (dpr 2), Roboto
// real. Las pantallas principales se montan con la app REAL
// (MelliQuiApp: tema teal/violeta y oscuro verde de verdad); las
// sueltas, con una réplica fiel de ese tema (melliLightTheme /
// melliDarkTheme). Pumps de 2 s: las tarjetas entran con FadeSlideIn
// (320 ms) y con 300 ms quedaban transparentes. Si un test cuelga,
// correrlo solo con --plain-name.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/account_screen.dart';
import 'package:quimica_pura/screens/challenge_screen.dart';
import 'package:quimica_pura/screens/lab_screen.dart';
import 'package:quimica_pura/screens/lab_sim_screen.dart';
import 'package:quimica_pura/screens/reminder_screen.dart';
import 'package:quimica_pura/screens/stats_screen.dart';
import 'package:quimica_pura/screens/tabla_screen.dart';
import 'package:quimica_pura/screens/timed_exam_screen.dart';
import 'package:quimica_pura/services/accent.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/brand_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

/// Réplica fiel del tema claro de MelliQuiApp (_lightTheme en
/// main.dart): teal #00C2A8 con acento Verde, o violeta con acento
/// Violeta (según UserPrefs.themeAccent).
ThemeData melliLightTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.light(
        primary: AppAccent.primary,
        onPrimary: Colors.white,
        secondary:
            AppAccent.isViolet ? BrandColors.teal : BrandColors.violet,
        surface: Colors.white,
        onSurface: BrandColors.ink,
        surfaceContainerHighest: BrandColors.cardGray,
        error: const Color(0xFFEF4444),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: BrandColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: BrandColors.ink,
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
        primary: BrandColors.mintLight,
        onPrimary: Color(0xFF0A1F1A),
        secondary: BrandColors.mint,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    UserPrefs.rulesSeenV6 = true;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = true;
    UserPrefs.isDark = false;
  });

  tearDown(() {
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = false;
    UserPrefs.isDark = false;
  });

  Future<void> setPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(720, 1600);
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
    // Dos pumps de 2 s: el primero dispara los Future.delayed de
    // las animaciones de entrada (FadeSlideIn) y el segundo pinta
    // ya con la opacidad a 1. Con un solo pump quedaban a 0.
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
  }

  /// La app real: Niveles, drawer, quiz, onboarding y popups.
  Future<void> pumpApp(WidgetTester tester) async {
    await setPhone(tester);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
  }

  /// Una pantalla suelta con el tema real de la app.
  Future<void> pumpScreen(WidgetTester tester, Widget child,
      {bool dark = false}) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? melliDarkTheme() : melliLightTheme(),
        home: Scaffold(body: child),
      ),
    );
    await settle(tester);
  }

  // Calentamiento: decodifica las imágenes (gemelas, logo, WhatsApp)
  // ANTES de la primera captura, esperando la decodificación de
  // verdad con runAsync + precacheImage. Sin esto, la primera
  // pantalla (Niveles claro) salía con el avatar de Brenda vacío y
  // el pie del drawer sin el logo de WhatsApp: con solo hacer pump,
  // la decodificación seguía pendiente al capturar.
  testWidgets('warm-up imágenes', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: melliLightTheme(),
        home: const Scaffold(
          body: Row(
            key: Key('warmup'),
            children: [
              Image(image: AssetImage('assets/brenda.png'),
                  width: 40, height: 40),
              Image(image: AssetImage('assets/britany.png'),
                  width: 40, height: 40),
              Image(image: AssetImage('assets/logo.png'),
                  width: 40, height: 40),
              Image(image: AssetImage('assets/whatsapp.png'),
                  width: 40, height: 40),
            ],
          ),
        ),
      ),
    );
    final context = tester.element(find.byKey(const Key('warmup')));
    await tester.runAsync(() async {
      for (final name in ['brenda', 'britany', 'logo', 'whatsapp']) {
        await precacheImage(AssetImage('assets/$name.png'), context);
      }
    });
    await settle(tester);
  });

  testWidgets('fix2_niveles (claro)', (tester) async {
    await pumpApp(tester);
    await shot(tester, 'fix2_niveles.png');
  });

  testWidgets('fix2_niveles_dark (oscuro, tarjetas legibles)',
      (tester) async {
    UserPrefs.isDark = true;
    await pumpApp(tester);
    await shot(tester, 'fix2_niveles_dark.png');
  });

  testWidgets('fix2_niveles_violeta (acento violeta)', (tester) async {
    UserPrefs.themeAccent = 'violeta';
    UserPrefs.themeAccentNotifier.value = 'violeta';
    await pumpApp(tester);
    await shot(tester, 'fix2_niveles_violeta.png');
  });

  testWidgets('fix2_drawer (menú con búsqueda fija y Soporte al pie)',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip(tr('menuWord')));
    await settle(tester);
    await shot(tester, 'fix2_drawer.png');
  });

  testWidgets('fix2_tabla (claro)', (tester) async {
    await pumpScreen(tester, const TablaScreen());
    await shot(tester, 'fix2_tabla.png');
  });

  testWidgets('fix2_tabla_filtro (filtro activo, sin leyenda)',
      (tester) async {
    await pumpScreen(tester, const TablaScreen());
    await tester.tap(find.byType(ChoiceChip).at(1));
    await settle(tester);
    await shot(tester, 'fix2_tabla_filtro.png');
  });

  testWidgets('fix2_onboarding (primera pantalla, sin logo abajo)',
      (tester) async {
    UserPrefs.onboardingDone = false;
    await pumpApp(tester);
    await shot(tester, 'fix2_onboarding.png');
  });

  testWidgets('fix2_cuenta (claro)', (tester) async {
    await pumpScreen(
        tester,
        AccountScreen(
          onOpenScreen: (_) {},
          onShowAbout: () {},
          onShowShareApp: () {},
          trackTopics: const ['estequiometria'],
        ));
    await shot(tester, 'fix2_cuenta.png');
  });

  testWidgets('fix2_cuenta_dark (oscuro)', (tester) async {
    await pumpScreen(
        tester,
        AccountScreen(
          onOpenScreen: (_) {},
          onShowAbout: () {},
          onShowShareApp: () {},
          trackTopics: const ['estequiometria'],
        ),
        dark: true);
    await shot(tester, 'fix2_cuenta_dark.png');
  });

  testWidgets('fix2_reto (nombres, mando en círculo)', (tester) async {
    await pumpScreen(tester, const ChallengeScreen());
    await shot(tester, 'fix2_reto.png');
  });

  // Golden OMITIDO (skip): el quiz no puede tener un golden
  // estable — el quiz de nivel baraja preguntas Y opciones con
  // Random() sin semilla (a propósito, para no memorizar posiciones:
  // no se toca), y cada ejecución pinta una pregunta distinta, así
  // que la comparación de píxeles falla aunque la pantalla esté
  // bien. Además, tocar el nodo reproduce un sonido y en el entorno
  // de pruebas el plugin de audio no existe (MissingPluginException).
  // La imagen fix2_quiz.png YA existe y se verificó leyéndola: es el
  // quiz de nivel 1 ("Estequiometría · Nivel 1 · Pregunta 1 de 5",
  // opciones legibles en oscuro sobre blanco, sin navbar ni AppBar,
  // Brenda visible, botón Salir). Para regenerarla: quitar el skip
  // y correr con --update-goldens, y leer la imagen después.
  testWidgets('fix2_quiz (pregunta con opciones, sin navbar ni AppBar)',
      (tester) async {
    await pumpApp(tester);
    // El nodo del nivel 1 es un círculo con el "1" dentro y es
    // táctil: tocarlo empieza el quiz del nivel.
    await tester.tap(find.text('1').first);
    await settle(tester);
    await shot(tester, 'fix2_quiz.png');
  }, skip: true);

  testWidgets('fix2_labsim (vaso de precipitados)', (tester) async {
    await pumpScreen(tester, const LabSimScreen());
    await shot(tester, 'fix2_labsim.png');
  });

  testWidgets('fix2_stats (mis estadísticas)', (tester) async {
    await pumpScreen(
        tester, const StatsScreen(trackTopics: ['estequiometria']));
    await shot(tester, 'fix2_stats.png');
  });

  testWidgets('fix2_timed (examen con tiempo, configuración)',
      (tester) async {
    await pumpScreen(tester, const TimedExamScreen());
    await shot(tester, 'fix2_timed.png');
  });

  testWidgets('fix2_lab (menú Lab: simulador primero)', (tester) async {
    await pumpScreen(tester, const LabScreen());
    await shot(tester, 'fix2_lab.png');
  });

  testWidgets('fix2_recordatorios (campana)', (tester) async {
    await pumpScreen(tester, const ReminderScreen());
    await shot(tester, 'fix2_recordatorios.png');
  });

  testWidgets('fix2_elemento_dia (popup del elemento del día)',
      (tester) async {
    // El elemento no se ha mostrado hoy: se pone una fecha vieja
    // (la clave es 'melli_progress_element_day_shown').
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'melli_progress_element_day_shown', '2000-01-01');
    await pumpApp(tester);
    await shot(tester, 'fix2_elemento_dia.png');
  });

  testWidgets('fix2_como_se_juega (popup Cómo se juega)', (tester) async {
    UserPrefs.rulesSeenV6 = false;
    await pumpApp(tester);
    await shot(tester, 'fix2_como_se_juega.png');
  });

  testWidgets('fix2_notificacion (ejemplo de aviso del sistema)',
      (tester) async {
    // Maqueta de cómo se ve un aviso de Melli-Qui en el teléfono:
    // no es una captura del sistema, es la tarjeta tal como la
    // dibuja Android (icono, app, hora, título y cuerpo).
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: melliLightTheme(),
        home: Scaffold(
          backgroundColor: const Color(0xFF101418),
          body: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Image(
                    image: AssetImage('assets/logo.png'),
                    width: 40,
                    height: 40,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Quemia',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Spacer(),
                            Text('ahora',
                                style: TextStyle(
                                    color: Color(0xFF757575),
                                    fontSize: 12)),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text('¡Brenda te extraña!',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(height: 2),
                        Text(
                            'Llevas un día sin practicar. Tu racha está en juego: haz un nivel rápido.',
                            style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    await shot(tester, 'fix2_notificacion.png');
  });
}

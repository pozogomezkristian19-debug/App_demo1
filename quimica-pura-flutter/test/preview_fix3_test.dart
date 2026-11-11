// Vistas previas de la ronda fix3 (2026-11-10), PRIMERA TANDA:
// solo las partes ya completas y estables (Tabla, Actividad, Tips,
// Ramas, Examen con tiempo). Se ejecuta con --update-goldens para
// ESCRIBIR los PNG en ~/workspace/melli-qui-v6-previews/ (nombres
// fix3_*). Un test por pantalla, viewport 360x800 (dpr 2), Roboto
// real. Mismo patrón que test/preview_fix2_test.dart (temas fieles
// de la app, pumps de 2 s por las animaciones de entrada).
// NO tocar lib/ desde aquí: solo capturas.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/branches_screen.dart';
import 'package:quimica_pura/screens/constants_screen.dart';
import 'package:quimica_pura/screens/lab_sim_screen.dart';
import 'package:quimica_pura/screens/onboarding_notifications_page.dart';
import 'package:quimica_pura/screens/reference_tables_screen.dart';
import 'package:quimica_pura/screens/tabla_screen.dart';
import 'package:quimica_pura/screens/timed_exam_screen.dart';
import 'package:quimica_pura/screens/tips_screen.dart';
import 'package:quimica_pura/services/accent.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/widgets/brand_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

/// Réplica fiel del tema claro de MelliQuiApp (ver
/// preview_fix2_test.dart): teal #00C2A8 con acento Verde.
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

/// Réplica mínima y fiel del textTheme y la AppBar de MelliQuiApp
/// para Tips (ver fix3_tips_test.dart): cuerpo 16 Roboto con el
/// color del tema, título de AppBar 20 w800.
ThemeData melliTextTheme({required bool dark}) => ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor:
          dark ? const Color(0xFF0A1F1A) : Colors.white,
      colorScheme: dark
          ? const ColorScheme.dark(
              primary: BrandColors.mintLight,
              onSurface: Color(0xFFE6F4EE),
              surface: Color(0xFF122B24),
            )
          : const ColorScheme.light(
              primary: BrandColors.teal,
              onSurface: BrandColors.ink,
              surface: Colors.white,
            ),
      appBarTheme: AppBarTheme(
        backgroundColor:
            dark ? const Color(0xFF0A1F1A) : Colors.white,
        foregroundColor:
            dark ? const Color(0xFFE6F4EE) : BrandColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: dark ? const Color(0xFFE6F4EE) : BrandColors.ink,
        ),
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(
            fontSize: 16,
            height: 1.45,
            color:
                dark ? const Color(0xFFE6F4EE) : BrandColors.ink),
        bodyLarge: TextStyle(
            fontSize: 17,
            height: 1.45,
            color:
                dark ? const Color(0xFFE6F4EE) : BrandColors.ink),
        titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color:
                dark ? const Color(0xFFE6F4EE) : BrandColors.ink),
      ).apply(fontFamily: 'Roboto'),
    );

/// Carga la fuente de iconos Material del SDK para que la flecha
/// atrás de la AppBar (y cualquier Icons.*) se dibuje de verdad en
/// las capturas. Sin ella sale un cuadrado vacío: en los tests no
/// hay fallback de fuentes del sistema, pero en el teléfono sí
/// (la app usa uses-material-design: true).
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

  void _noop() {}

  /// Una pantalla suelta con el tema claro de la app.
  Future<void> pumpScreen(WidgetTester tester, Widget child,
      {double width = 360, double height = 800}) async {
    await setPhone(tester, width: width, height: height);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: melliLightTheme(),
        home: Scaffold(body: child),
      ),
    );
    await settle(tester);
  }

  /// Una pantalla suelta con su propio Scaffold, empujada sobre una
  /// ruta vacía para que la AppBar muestre la flecha atrás (como en
  /// la app real, que se abre desde el menú o desde Aprender).
  Future<void> pumpPushed(WidgetTester tester, Widget screen,
      {bool dark = false}) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: melliTextTheme(dark: dark),
        home: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => screen),
              );
            });
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );
    await settle(tester);
  }

  // CAUSA DEL DUPLICADO (ronda #3, tanda 2): este test llamaba a
  // pumpScreen() sin ancho, y pumpScreen usa 360 px por defecto, el
  // MISMO viewport que fix3_tabla_360. Al correr --update-goldens la
  // imagen de 360 px se escribió en los dos nombres. La vista de
  // ancho normal es a 800 px (18 columnas H…Rn sin scroll).
  testWidgets('fix3_tabla (filtro Todos, leyenda abajo en flujo)',
      (tester) async {
    await pumpScreen(tester, const TablaScreen(), width: 800, height: 800);
    await shot(tester, 'fix3_tabla.png');
  });

  testWidgets('fix3_tabla_filtro (filtro de categoría, sin leyenda)',
      (tester) async {
    await pumpScreen(tester, const TablaScreen());
    await tester.tap(find.byType(ChoiceChip).at(1));
    await settle(tester);
    await shot(tester, 'fix3_tabla_filtro.png');
  });

  testWidgets('fix3_tabla_360 (rejilla a 360 px, celdas de 40 px)',
      (tester) async {
    await pumpScreen(tester, const TablaScreen());
    // Sin arrastrar: la tabla se renderiza desde la posición inicial
    // (columna 1, H, a la izquierda) con celdas grandes, y el fade
    // del borde derecho muestra que se puede desplazar. La versión
    // anterior arrastraba al centro (Cr–Sn) y confundía el inicio.
    await shot(tester, 'fix3_tabla_360.png');
  });

  testWidgets('fix3_tabla_ancho (rejilla a ancho normal, 800 px)',
      (tester) async {
    await pumpScreen(tester, const TablaScreen(), width: 800, height: 800);
    await shot(tester, 'fix3_tabla_ancho.png');
  });

  testWidgets(
      'fix3_actividad (nota del hidrógeno arriba, H no H₂)',
      (tester) async {
    await pumpScreen(tester, const TablaScreen());
    await tester.tap(find.text(tr('tabActivity')));
    await settle(tester);
    await shot(tester, 'fix3_actividad.png');
  });

  testWidgets('fix3_tips (texto normal legible, AppBar Tips)',
      (tester) async {
    await pumpPushed(tester, const TipsScreen());
    await shot(tester, 'fix3_tips.png');
  });

  testWidgets('fix3_tips_dark (Tips en oscuro)', (tester) async {
    await pumpPushed(tester, const TipsScreen(), dark: true);
    await shot(tester, 'fix3_tips_dark.png');
  });

  testWidgets('fix3_ramas (las 4 ramas iguales)', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: melliLightTheme(),
        home: const BranchesScreen(),
      ),
    );
    await settle(tester);
    await shot(tester, 'fix3_ramas.png');
  });

  testWidgets('fix3_timed (cronómetro pequeño en círculo)', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: melliLightTheme(),
        home: const TimedExamScreen(),
      ),
    );
    await settle(tester);
    await shot(tester, 'fix3_timed.png');
  });

  // ---- SEGUNDA TANDA (ronda #3): solo partes estables. ----

  testWidgets('fix3_labsim_acido (simulador ácido+base, indicador Universal)',
      (tester) async {
    // 360x1100: a 800 px el vaso (228 px) y la tarjeta de pH quedan
    // por debajo del pliegue. Indicador Universal: a pH 7 el líquido
    // se ve verde, así se aprecia el color según pH.
    await pumpScreen(tester, const LabSimScreen(),
        width: 360, height: 1100);
    await tester.tap(find.text('Fenolftaleína'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Universal').last);
    await settle(tester);
    await shot(tester, 'fix3_labsim_acido.png');
  });

  testWidgets('fix3_labsim_precip (simulador precipitación, AgCl)',
      (tester) async {
    await pumpScreen(tester, const LabSimScreen(),
        width: 360, height: 1100);
    await tester.tap(find.text('Precipitación'));
    await settle(tester);
    await shot(tester, 'fix3_labsim_precip.png');
  });

  testWidgets('fix3_onboarding_notif (permiso de notificaciones)',
      (tester) async {
    await pumpScreen(
        tester,
        OnboardingNotificationsPage(onNext: _noop),
        width: 360,
        height: 800);
    await shot(tester, 'fix3_onboarding_notif.png');
  });

  testWidgets('fix3_tablas_ref (Tablas de referencia, nota del H arriba)',
      (tester) async {
    await pumpScreen(tester, const ReferenceTablesScreen());
    await shot(tester, 'fix3_tablas_ref.png');
  });

  testWidgets('fix3_constantes (Vm 22.4 y 24.8 TPEA + conversor)',
      (tester) async {
    // 360x1450: las dos entradas de Vm (9.ª y 10.ª de 14 constantes)
    // y el campo Valor del conversor no caben a 800 px; a 1200 px
    // la lista de constantes llena sola toda la vista.
    await pumpScreen(tester, const ConstantsScreen(),
        width: 360, height: 1450);
    await shot(tester, 'fix3_constantes.png');
  });
}

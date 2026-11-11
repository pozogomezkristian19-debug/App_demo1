// Preview de la ronda #4, punto 9b (corrección de Kristian): el
// simulador EN TIEMPO REAL, no 5 fotos estáticas. La pantalla es la
// misma de siempre (desplegables, deslizantes, vaso, pH) capturada
// a mitad de una transición: HCl 65 mL + NaOH 75 mL (pH 11,85,
// rosa intenso) y, al bajar la base a 10 mL, el fotograma a los
// 400 ms de la animación de 800 ms — el líquido a mitad de camino,
// rosa desvaneciéndose hacia el incoloro final, sin blanco ni
// salto. La prueba de que el degradado es continuo está en
// test/fix4_labsim_test.dart (barrido 75→10 en pasos de 5 mL y
// arrastre continuo con lecturas en cada paso).
//
// La captura se bombea con la app REAL (MelliQuiApp), NO con un
// MaterialApp pelado: el tema de verdad lleva los desplegables
// como cajas con borde redondeado y relleno (InputDecorationTheme
// con OutlineInputBorder), las tarjetas planas sin borde
// (cardTheme con elevation 0) y el teal de la marca. Con el
// MaterialApp pelado salían desplegables con subrayado, tarjetas
// con borde y morado, y los iconos Material (la flecha ▼ del
// desplegable, el ✓ del segmento seleccionado) salían como ▯
// porque no se cargaba la fuente MaterialIcons. En el teléfono
// todo eso se ve bien (la propia captura de Kristian en oscuro
// muestra la flecha ▼ correcta); el ▯ era solo un artefacto del
// render, no un bug de la app.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/lab_sim_screen.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadRobotoFonts();
    await loadMaterialIcons();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
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
    UserPrefs.rulesSeenV6 = true;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    await UserPrefs.saveThemeMode('claro');
    UserPrefs.isDark = false;
    UserPrefs.onboardingDone = true;
    ProgressService.instance.markElementDayShown();
  });

  tearDown(() {
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = false;
    UserPrefs.isDark = false;
  });

  Future<void> pumpSim(WidgetTester tester) async {
    // Pantalla alta (360x1100): entra todo el cuerpo del simulador
    // (desplegables, deslizantes, vaso, "≈ 75 mL en el vaso" y la
    // tarjeta de pH) sin desplazar, como en la captura de Kristian.
    tester.view.physicalSize = const Size(360 * 2, 1100 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    // Con la app real (tema de verdad): se empuja el simulador
    // sobre Niveles con el Navigator.
    await tester.pumpWidget(const MelliQuiApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    tester.state<NavigatorState>(find.byType(Navigator)).push(
      MaterialPageRoute(builder: (_) => const LabSimScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> setSlider(
      WidgetTester tester, int which, double value) async {
    final slider = find.byType(Slider).at(which);
    final box = tester.renderObject<RenderBox>(slider);
    final fraction = ((value - 10) / 90).clamp(0.0, 1.0);
    await tester.tapAt(box.localToGlobal(Offset(
      box.size.width * (0.02 + 0.96 * fraction),
      box.size.height / 2,
    )));
    await tester.pump();
  }

  testWidgets('simulador en vivo a mitad de transición (fix4, punto 9b)',
      (tester) async {
    await pumpSim(tester);
    // Estado de Kristian: HCl 65 + NaOH 75, pH 11,85, rosa intenso.
    await setSlider(tester, 0, 65);
    await setSlider(tester, 1, 75);
    await tester.pump(const Duration(milliseconds: 900));
    // Bajar la base a 10 mL y capturar a mitad de la animación
    // (800 ms): el líquido va por la mitad del degradado. La
    // pantalla es alta y ya muestra el vaso y la tarjeta de pH.
    await setSlider(tester, 1, 10);
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
          '../../melli-qui-v6-previews/fix4_labsim_realtime.png'),
    );
  });
}

// Ronda #4, punto 9: el vaso del simulador NO se deforma al mover
// los controles.
//
// Bug encontrado: `_Beaker.didUpdateWidget` solo recreaba el tween
// del valor que cambiaba y luego reiniciaba el controlador desde 0
// (`_controller.forward(from: 0)`). Los demás tweens conservaban su
// `begin` antiguo, así que al reiniciar saltaban a ese valor: cambiar
// el indicador, el ácido o la reacción hacía que el nivel del líquido
// (y el montículo de precipitado) se desplomaran y volvieran a
// crecer en 800 ms, aunque el volumen no hubiera cambiado. El menisco
// "saltaba" con cada cambio de desplegable.
// La solución: al cambiar CUALQUIER valor, rebasar TODOS los tweens
// desde el valor que se está mostrando ahora mismo.
//
// Estos tests lo reproducen a nivel de pintor: leen fillFraction /
// precipFraction del _BeakerPainter (vía dynamic) a mitad de la
// animación, justo después de un cambio que SOLO toca el color.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/lab_sim_screen.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  Future<void> pumpSim(WidgetTester tester) async {
    // Pantalla alta como en fix3_lab_sim_test: con 1400 px todo el
    // cuerpo (controles, vaso y tarjeta) está construido, sin scroll.
    tester.view.physicalSize = const Size(800 * 2, 1400 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      const MaterialApp(home: LabSimScreen()),
    );
    await tester.pump();
  }

  /// Lee (fillFraction, precipFraction) del _BeakerPainter.
  (double, double) beakerLevels(WidgetTester tester) {
    final paints = find
        .byType(CustomPaint)
        .evaluate()
        .map((e) => e.widget as CustomPaint)
        .where((c) =>
            c.painter != null &&
            c.painter.runtimeType.toString() == '_BeakerPainter');
    expect(paints.length, 1, reason: 'debe haber un solo vaso');
    final painter = paints.first.painter as dynamic;
    return (
      painter.fillFraction as double,
      painter.precipFraction as double,
    );
  }

  /// Lee el color del líquido del _BeakerPainter.
  Color beakerColor(WidgetTester tester) {
    final paints = find
        .byType(CustomPaint)
        .evaluate()
        .map((e) => e.widget as CustomPaint)
        .where((c) =>
            c.painter != null &&
            c.painter.runtimeType.toString() == '_BeakerPainter');
    expect(paints.length, 1, reason: 'debe haber un solo vaso');
    final painter = paints.first.painter as dynamic;
    return painter.liquidColor as Color;
  }

  /// Pone un Slider (0 = primero, 1 = segundo) en el valor dado
  /// (min 10, máx 100) tocando su pista en la fracción adecuada.
  Future<void> setSlider(
      WidgetTester tester, int which, double value) async {
    final slider = find.byType(Slider).at(which);
    final box = tester.renderObject<RenderBox>(slider);
    final fraction = ((value - 10) / 90).clamp(0.0, 1.0);
    final x = box.localToGlobal(Offset(
      box.size.width * (0.02 + 0.96 * fraction),
      box.size.height / 2,
    ));
    await tester.tapAt(x);
    await tester.pump();
  }

  /// Cambia un desplegable: toca el texto visible y luego la opción.
  Future<void> pickDropdown(
      WidgetTester tester, String current, String option) async {
    await tester.tap(find.text(current));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pump();
  }

  group('el vaso no salta al cambiar los controles (fix4, punto 9)', () {
    testWidgets('cambiar el indicador no mueve el nivel del líquido',
        (tester) async {
      await pumpSim(tester);
      // Llenar el vaso: ácido 100 + base 100 = 200 mL (fill 1.0).
      await setSlider(tester, 0, 100);
      await setSlider(tester, 1, 100);
      await tester.pump(const Duration(milliseconds: 900));
      var (fill, _) = beakerLevels(tester);
      expect(fill, closeTo(1.0, 0.01));

      // Cambiar SOLO el indicador (el color): el volumen no cambia.
      await pickDropdown(tester, 'Fenolftaleína', 'Universal');
      // A mitad de la animación de color (800 ms): el nivel debe
      // seguir en 1.0 — antes del arreglo saltaba a 0.75 (el `begin`
      // del tween anterior) y volvía a subir.
      await tester.pump(const Duration(milliseconds: 400));
      (fill, _) = beakerLevels(tester);
      expect(fill, closeTo(1.0, 0.02));
      await tester.pump(const Duration(milliseconds: 900));
      (fill, _) = beakerLevels(tester);
      expect(fill, closeTo(1.0, 0.01));
    });

    testWidgets('cambiar el ácido no mueve el nivel del líquido',
        (tester) async {
      await pumpSim(tester);
      await setSlider(tester, 0, 100);
      await setSlider(tester, 1, 100);
      await tester.pump(const Duration(milliseconds: 900));
      var (fill, _) = beakerLevels(tester);
      expect(fill, closeTo(1.0, 0.01));

      // Cambiar el ácido cambia el pH (y el color), no el volumen.
      await pickDropdown(
          tester, 'Ácido clorhídrico (HCl 0.10 M)', 'Ácido acético (CH₃COOH 0.10 M)');
      await tester.pump(const Duration(milliseconds: 400));
      (fill, _) = beakerLevels(tester);
      expect(fill, closeTo(1.0, 0.02));
      await tester.pump(const Duration(milliseconds: 900));
      (fill, _) = beakerLevels(tester);
      expect(fill, closeTo(1.0, 0.01));
    });

    testWidgets(
        'cambiar la reacción no mueve el nivel ni el montículo de precipitado',
        (tester) async {
      await pumpSim(tester);
      await tester.tap(find.text('Precipitación'));
      await tester.pumpAndSettle();
      // Vaso lleno con el máximo precipitado (100 + 100 mL).
      await setSlider(tester, 0, 100);
      await setSlider(tester, 1, 100);
      await tester.pump(const Duration(milliseconds: 900));
      var (fill, precip) = beakerLevels(tester);
      expect(fill, closeTo(1.0, 0.01));
      expect(precip, closeTo(0.45, 0.01));

      // Cambiar SOLO la reacción (el color del precipitado): ni el
      // nivel ni el montículo deben moverse.
      await pickDropdown(tester, 'AgNO₃ + NaCl', 'Pb(NO₃)₂ + KI');
      await tester.pump(const Duration(milliseconds: 400));
      (fill, precip) = beakerLevels(tester);
      expect(fill, closeTo(1.0, 0.02));
      expect(precip, closeTo(0.45, 0.02));
      await tester.pump(const Duration(milliseconds: 900));
      (fill, precip) = beakerLevels(tester);
      expect(fill, closeTo(1.0, 0.01));
      expect(precip, closeTo(0.45, 0.01));
    });

    testWidgets('barrer los volúmenes no saca el líquido del vaso',
        (tester) async {
      await pumpSim(tester);
      // Barrido completo de los dos deslizantes en ácido-base.
      for (final v in [10.0, 25.0, 50.0, 75.0, 100.0, 60.0, 10.0]) {
        await setSlider(tester, 0, v);
        await setSlider(tester, 1, v);
        await tester.pump(const Duration(milliseconds: 100));
        final (fill, precip) = beakerLevels(tester);
        // El nivel nunca sale de la capacidad del vaso (0..1) y no
        // hay precipitado en esta pestaña.
        expect(fill, inInclusiveRange(0.0, 1.0));
        expect(precip, 0.0);
      }
      await tester.pump(const Duration(milliseconds: 900));
      final (fill, _) = beakerLevels(tester);
      expect(fill, closeTo(0.1, 0.01)); // 10 + 10 mL de 200 mL.
    });

    testWidgets('cambiar de pestaña no deja el vaso a medias',
        (tester) async {
      await pumpSim(tester);
      await tester.tap(find.text('Precipitación'));
      await tester.pumpAndSettle();
      await setSlider(tester, 0, 100);
      await setSlider(tester, 1, 100);
      await tester.pump(const Duration(milliseconds: 900));
      var (fill, precip) = beakerLevels(tester);
      expect(fill, closeTo(1.0, 0.01));
      expect(precip, closeTo(0.45, 0.01));
      // Volver a ácido-base: el precipitado se va y el nivel queda
      // en lo que mandan los volúmenes (50 + 50 = 0.5).
      await tester.tap(find.text('Ácido + base'));
      await tester.pump(const Duration(milliseconds: 400));
      (fill, precip) = beakerLevels(tester);
      expect(fill, inInclusiveRange(0.0, 1.0));
      await tester.pump(const Duration(milliseconds: 900));
      (fill, precip) = beakerLevels(tester);
      expect(fill, closeTo(0.5, 0.01));
      expect(precip, closeTo(0.0, 0.01));
    });
  });

  group('el color hace degradado al bajar la base (fix4, punto 9b)', () {
    // Fallo que reportó Kristian con captura: HCl 0.10 M 65 mL +
    // NaOH 0.10 M 75 mL, fenolftaleína, líquido rosa, pH ≈ 11,85.
    // Al bajar el deslizante de base el líquido se ponía BLANCO y
    // después SALTABA al color final, en vez de degradarse poco a
    // poco. Dos discontinuidades reales en el código:
    // (1) `_indicatorColor` de la fenolftaleína era un escalón en
    // pH 8,2 (de rosa claro 0xFFF8BBD0 a casi blanco 0xFFECEFF1 en
    // un solo paso de pH); ahora el rosa aparece poco a poco entre
    // pH 7 y 8,2.
    // (2) el pintor tenía una rama "agua incolora" que se activaba
    // de golpe cuando la luminosidad pasaba de 0,92: en mitad de la
    // animación del color el degradado saltaba a blanco; ahora el
    // líquido se dibuja siempre con el mismo degradado a partir de
    // su color (un líquido casi blanco ya sale casi blanco, sin
    // salto).
    testWidgets(
        'al bajar la base el color pasa por el rosa, sin blanco de golpe',
        (tester) async {
      await pumpSim(tester);
      // Estado de Kristian: HCl 65 + NaOH 75, pH 11,85.
      await setSlider(tester, 0, 65);
      await setSlider(tester, 1, 75);
      await tester.pump(const Duration(milliseconds: 900));
      final start = beakerColor(tester);
      expect(start.r * 255, closeTo(236, 2));
      expect(start.g * 255, closeTo(64, 2));
      expect(start.b * 255, closeTo(122, 2));
      // Bajar la base de golpe a 10 mL (pH ácido, incoloro al final).
      await setSlider(tester, 1, 10);
      // A mitad de la animación (800 ms) el color debe estar a
      // mitad de camino: rosa intermedio, ni blanco ni rosa intenso.
      await tester.pump(const Duration(milliseconds: 400));
      final mid = beakerColor(tester);
      expect(mid.r * 255, closeTo(236, 5));
      expect(mid.g * 255, greaterThan(100));
      expect(mid.g * 255, lessThan(200));
      expect(mid.b * 255, greaterThan(130));
      expect(mid.b * 255, lessThan(215));
      await tester.pump(const Duration(milliseconds: 900));
      final end = beakerColor(tester);
      // Final correcto: fenolftaleína incolora en medio ácido.
      expect(end.r * 255, closeTo(236, 2));
      expect(end.g * 255, closeTo(239, 2));
      expect(end.b * 255, closeTo(241, 2));
    });

    testWidgets('el viraje de la fenolftaleína es continuo con el pH',
        (tester) async {
      await pumpSim(tester);
      await setSlider(tester, 0, 65); // HCl 65 mL.
      await pickDropdown(tester, 'Hidróxido de sodio (NaOH 0.10 M)',
          'Amoníaco (NH₃ 0.10 M)');
      // Con NH₃ el pH sube poco a poco por el tampón, así que al
      // barrer la base de 100 a 65 mL el color debe pasar por todos
      // los rosas intermedios sin ningún salto: antes, al cruzar
      // pH 8,2 (base 70), el verde saltaba +70 en un solo paso de
      // 5 mL (de rosa claro a casi blanco).
      final colors = <Color>[];
      for (final v in [100.0, 90.0, 80.0, 75.0, 70.0, 65.0]) {
        await setSlider(tester, 1, v);
        await tester.pump(const Duration(milliseconds: 900));
        colors.add(beakerColor(tester));
      }
      for (var i = 1; i < colors.length; i++) {
        final a = colors[i - 1];
        final b = colors[i];
        expect((a.r - b.r).abs() * 255, lessThan(60),
            reason: 'paso $i: el rojo no debe saltar');
        expect((a.g - b.g).abs() * 255, lessThan(60),
            reason: 'paso $i: el verde no debe saltar');
        expect((a.b - b.b).abs() * 255, lessThan(60),
            reason: 'paso $i: el azul no debe saltar');
      }
      // Extremos: rosa visible a pH ~9 e incoloro en medio ácido.
      expect(colors.first.g * 255, lessThan(170));
      expect(colors.last.g * 255, greaterThan(220));
    });

    testWidgets('con Universal el color también pasa por los intermedios',
        (tester) async {
      await pumpSim(tester);
      await pickDropdown(tester, 'Fenolftaleína', 'Universal');
      await setSlider(tester, 0, 65);
      await setSlider(tester, 1, 75);
      await tester.pump(const Duration(milliseconds: 900));
      final start = beakerColor(tester);
      // Violeta del Universal a pH 11,85.
      expect(start.r * 255, closeTo(142, 2));
      expect(start.g * 255, closeTo(36, 2));
      expect(start.b * 255, closeTo(170, 2));
      await setSlider(tester, 1, 10);
      await tester.pump(const Duration(milliseconds: 400));
      final mid = beakerColor(tester);
      // A mitad de la animación: entre violeta y rojo-naranja.
      expect(mid.r * 255, greaterThan(140));
      expect(mid.r * 255, lessThan(210));
      expect(mid.g * 255, lessThan(120));
      expect(mid.b * 255, greaterThan(80));
      expect(mid.b * 255, lessThan(160));
      await tester.pump(const Duration(milliseconds: 900));
      final end = beakerColor(tester);
      // pH ≈ 1,1: rojo-naranja del Universal.
      expect(end.r * 255, greaterThan(200));
      expect(end.g * 255, lessThan(120));
    });

    testWidgets('el texto de la base no se corta bajo la flecha',
        (tester) async {
      await pumpSim(tester);
      // Los desplegables de ácido-base ocupan todo el ancho y el
      // texto largo se recorta con puntos suspensivos, en vez de
      // correr bajo la flecha ▼ ("Hidróxido de sodio (NaOH 0.10 M)"
      // se cortaba por la derecha en la captura de Kristian).
      // `isExpanded` vive en el DropdownButton interno del campo.
      final buttons = find
          .byType(DropdownButton<int>)
          .evaluate()
          .map((e) => e.widget as DropdownButton<int>);
      expect(buttons.length, 2);
      expect(buttons.every((b) => b.isExpanded), isTrue);
      final baseText = tester.widget<Text>(
          find.text('Hidróxido de sodio (NaOH 0.10 M)'));
      expect(baseText.overflow, TextOverflow.ellipsis);
      final acidText = tester.widget<Text>(
          find.text('Ácido clorhídrico (HCl 0.10 M)'));
      expect(acidText.overflow, TextOverflow.ellipsis);
    });

    // EN TIEMPO REAL (corrección de Kristian a la ronda #4): lo que
    // importa no es una foto compuesta de 5 estados, sino que al
    // mover el deslizante el color cambie en vivo, fotograma a
    // fotograma, como una función continua del pH/volumen: sin
    // blanco intermedio y sin salto brusco entre pasos.
    testWidgets(
        'barrer la base de 75 a 10 en pasos de 5 mL es un degradado continuo',
        (tester) async {
      await pumpSim(tester);
      await setSlider(tester, 0, 65); // HCl 65 mL.
      await pickDropdown(tester, 'Hidróxido de sodio (NaOH 0.10 M)',
          'Amoníaco (NH₃ 0.10 M)');
      // Con NH₃ el pH pasa poco a poco por el viraje (tampón), así
      // que el color asentado en cada paso debe ser una
      // interpolación continua del anterior: nunca blanco de golpe
      // y nunca un salto brusco. (10 mL es el mínimo del
      // deslizante: no se puede bajar a 0.)
      final colors = <Color>[];
      for (final v in [
        75.0,
        70.0,
        65.0,
        60.0,
        55.0,
        50.0,
        45.0,
        40.0,
        35.0,
        30.0,
        25.0,
        20.0,
        15.0,
        10.0,
      ]) {
        await setSlider(tester, 1, v);
        await tester.pump(const Duration(milliseconds: 900));
        colors.add(beakerColor(tester));
      }
      for (var i = 1; i < colors.length; i++) {
        final a = colors[i - 1];
        final b = colors[i];
        expect((a.r - b.r).abs() * 255, lessThan(60),
            reason: 'paso $i: el rojo no debe saltar');
        expect((a.g - b.g).abs() * 255, lessThan(60),
            reason: 'paso $i: el verde no debe saltar');
        expect((a.b - b.b).abs() * 255, lessThan(60),
            reason: 'paso $i: el azul no debe saltar');
        // El líquido solo se apaga hacia el blanco, nunca vuelve
        // a rosa: sin blanco intermedio que luego desaparezca.
        final la = HSLColor.fromColor(a).lightness;
        final lb = HSLColor.fromColor(b).lightness;
        expect(lb, greaterThanOrEqualTo(la - 0.02),
            reason: 'paso $i: la luminosidad no debe retroceder');
      }
      // A base 70 (pH ≈ 8,15) todavía es rosa visible, no blanco:
      // el blanco solo llega cuando el pH ya es ácido (base ≤ 65).
      expect(colors[1].g * 255, lessThan(210));
      expect(colors[2].g * 255, greaterThan(220));
      // Final: incoloro en medio ácido.
      expect(colors.last.r * 255, closeTo(236, 2));
      expect(colors.last.g * 255, closeTo(239, 2));
      expect(colors.last.b * 255, closeTo(241, 2));
    });

    testWidgets(
        'al arrastrar la base el color se mueve en vivo, sin blanco ni salto',
        (tester) async {
      await pumpSim(tester);
      // Estado de Kristian: HCl 65 + NaOH 75, rosa intenso.
      await setSlider(tester, 0, 65);
      await setSlider(tester, 1, 75);
      await tester.pump(const Duration(milliseconds: 900));
      // Arrastre continuo: un paso de 5 mL cada 100 ms, sin dejar
      // asentar la animación (como el dedo en el teléfono). El
      // color mostrado debe moverse fotograma a fotograma hacia el
      // color final, sin pasarse de blanco y sin volver atrás.
      final greens = <double>[];
      for (final v in [
        70.0,
        65.0,
        60.0,
        55.0,
        50.0,
        45.0,
        40.0,
        35.0,
        30.0,
        25.0,
        20.0,
        15.0,
        10.0,
      ]) {
        await setSlider(tester, 1, v);
        await tester.pump(const Duration(milliseconds: 100));
        final c = beakerColor(tester);
        greens.add(c.g * 255);
        // Dentro del segmento rosa intenso → incoloro: el rojo no
        // se mueve (236 en los dos extremos) y el azul acompaña
        // sin pasarse.
        expect(c.r * 255, closeTo(236, 5));
        expect(c.b * 255, greaterThanOrEqualTo(122));
        expect(c.b * 255, lessThanOrEqualTo(241));
      }
      for (var i = 1; i < greens.length; i++) {
        expect(greens[i], greaterThanOrEqualTo(greens[i - 1] - 2),
            reason: 'el verde no debe retroceder durante el arrastre');
      }
      // Durante el arrastre el líquido nunca llega a blanco: solo
      // al soltar el deslizante y asentar.
      for (final g in greens) {
        expect(g, lessThan(220));
      }
      await tester.pump(const Duration(milliseconds: 900));
      final end = beakerColor(tester);
      expect(end.r * 255, closeTo(236, 2));
      expect(end.g * 255, closeTo(239, 2));
      expect(end.b * 255, closeTo(241, 2));
    });
  });
}

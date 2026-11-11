// Pruebas de la ronda #5 (Quemia 6.2), punto del CONFETI AL GANAR
// UN NIVEL. Causa del bug (verificada en celebration.dart): cada
// pieza caía con `p = (progress * speed)` y speed 0,5–1,0, así que
// al terminar la animación las piezas lentas quedaban a mitad de
// pantalla con alfa 1,0, CONGELADAS y opacas para siempre, y el
// overlay nunca se desmontaba (practicar_screen.dart ~2000 lo deja
// montado cuando passedLevel). Aquí se verifica la física nueva
// (retardo por pieza + progreso local que llega a 1 para todas),
// el desmontaje al terminar y que los botones "Repetir"/"Volver"
// se pueden tocar TAMBIÉN DURANTE la celebración.
// Las dos capturas (fix5_confeti_mitad / fix5_confeti_limpio) se
// generan con --update-goldens SOLO sobre este archivo.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/widgets/celebration.dart';
import 'package:quimica_pura/widgets/twin_avatars.dart';
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
    // Sin mock, el AudioPlayer estático de SoundService activa el
    // stream global de audioplayers y lanza MissingPluginException
    // (error asíncrono que el test reporta como fallo).
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
  });

  Future<void> setPhone(
    WidgetTester tester, {
    double width = 393,
    double height = 852,
  }) async {
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

  /// Réplica 1:1 de la pantalla de resultado de nivel aprobado de
  /// practicar_screen.dart (~1918-2002): mismo cuerpo (nota,
  /// puntos, "¡Nivel superado! Nivel 1", MascotBubble, botones
  /// "Repetir"/"Volver") y mismo Stack con el CelebrationOverlay
  /// en Positioned.fill. _QuizRunner es privado, así que la
  /// pantalla real no se puede bombear directamente; la réplica
  /// usa su misma estructura exacta.
  Widget resultScreen({
    required VoidCallback onRepeat,
    required VoidCallback onExit,
  }) {
    final resultBody = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('quizResult'),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Nota: 4,7 / 5',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Text(
            '${tr('pointsTitle')}: +18',
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${tr('quizLevelPassed')} ${tr('levelWord')} 1.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const MascotBubble(
            companion: Companion.brenda,
            mood: TwinMood.happy,
            text: '¡Muy bien! ¡Lo lograste!',
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRepeat,
            child: Text(tr('quizRepeat')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onExit,
            child: Text(tr('quizBack')),
          ),
        ],
      ),
    );
    return Stack(
      children: [
        resultBody,
        const Positioned.fill(child: CelebrationOverlay()),
      ],
    );
  }

  Future<void> pumpResult(
    WidgetTester tester, {
    required VoidCallback onRepeat,
    required VoidCallback onExit,
  }) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: resultScreen(onRepeat: onRepeat, onExit: onExit),
        ),
      ),
    );
    await tester.pump();
  }

  // Calentamiento: decodifica la foto de Brenda ANTES de la
  // primera captura (patrón de preview_fix2_test.dart).
  testWidgets('warm-up imágenes', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Image(
            image: AssetImage('assets/brenda.png'),
            width: 40,
            height: 40,
          ),
        ),
      ),
    );
    final context = tester.element(find.byType(Image));
    await tester.runAsync(
      () async => precacheImage(
        const AssetImage('assets/brenda.png'),
        context,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
  });

  group('Física del confeti (confettiPieceState)', () {
    const size = Size(393, 852);

    test('al final TODAS las piezas salen por abajo y su alfa es 0',
        () {
      for (var i = 0; i < 110; i++) {
        final s = confettiPieceState(i, 1.0, size);
        expect(s.y, greaterThan(size.height),
            reason: 'pieza $i debe estar por debajo de la pantalla');
        expect(s.alpha, 0, reason: 'pieza $i debe estar desvanecida');
      }
    });

    test('a mitad de la animación las 110 piezas caen visibles', () {
      var visibles = 0;
      for (var i = 0; i < 110; i++) {
        final s = confettiPieceState(i, 0.5, size);
        if (s.y > 0 && s.y < size.height && s.alpha > 0) visibles++;
      }
      expect(visibles, 110);
    });

    test('al empezar ninguna pieza se ve todavía (alfa 0, arriba)',
        () {
      for (var i = 0; i < 110; i++) {
        final s = confettiPieceState(i, 0.0, size);
        expect(s.alpha, 0, reason: 'pieza $i');
        expect(s.y, lessThanOrEqualTo(0), reason: 'pieza $i');
      }
    });

    test('las piezas lentas ya no se quedan a mitad al final', () {
      // El bug viejo: con speed 0,5 la pieza quedaba en p = 0,5
      // (y ≈ mitad de pantalla, alfa 1,0). Con el progreso local,
      // a progress = 0,99 incluso la pieza con más retardo ya casi
      // salió y casi se desvaneció.
      for (var i = 0; i < 110; i++) {
        final s = confettiPieceState(i, 0.99, size);
        expect(s.y, greaterThan(size.height * 0.8),
            reason: 'pieza $i');
        expect(s.alpha, lessThan(0.5), reason: 'pieza $i');
      }
    });
  });

  group('CelebrationOverlay en pantalla', () {
    testWidgets('se desmonta al terminar: no queda ninguna pieza '
        'pintada', (tester) async {
      var repetido = false;
      await pumpResult(
        tester,
        onRepeat: () => repetido = true,
        onExit: () {},
      );
      // A mitad de la celebración el confeti está pintando.
      await tester.pump(const Duration(milliseconds: 2100));
      expect(
        find.descendant(
          of: find.byType(CelebrationOverlay),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      // Tras la animación (4,2 s) el overlay se encoge: ya no
      // pinta nada.
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(CelebrationOverlay),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(CelebrationOverlay),
          matching: find.byType(SizedBox),
        ),
        findsOneWidget,
      );
      // Y los botones siguen funcionando después de la celebración.
      await tester.tap(find.text('Repetir'));
      await tester.pump();
      expect(repetido, isTrue);
    });

    testWidgets('los botones "Repetir"/"Volver" se pueden tocar '
        'TAMBIÉN DURANTE la celebración', (tester) async {
      var repetido = false;
      var salido = false;
      await pumpResult(
        tester,
        onRepeat: () => repetido = true,
        onExit: () => salido = true,
      );
      // A 1 s (progreso ~0,24) el confeti está cayendo a tope.
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.descendant(
          of: find.byType(CelebrationOverlay),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Repetir'));
      await tester.pump();
      expect(repetido, isTrue);
      await tester.tap(find.text('Volver'));
      await tester.pump();
      expect(salido, isTrue);
    });

    testWidgets('harness mínimo: un botón bajo el overlay se puede '
        'tocar durante la celebración', (tester) async {
      var tocado = false;
      await setPhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Stack(
              children: [
                Center(
                  child: ElevatedButton(
                    onPressed: () => tocado = true,
                    child: const Text('Tócame'),
                  ),
                ),
                const Positioned.fill(child: CelebrationOverlay()),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('Tócame'));
      await tester.pump();
      expect(tocado, isTrue);
    });
  });

  group('Previews fix5 (goldens)', () {
    testWidgets('fix5_confeti_mitad: resultado con el confeti '
        'cayendo a mitad de la animación', (tester) async {
      await pumpResult(tester, onRepeat: () {}, onExit: () {});
      await tester.pump(const Duration(milliseconds: 2100));
      await shot(tester, 'fix5_confeti_mitad.png');
    });

    testWidgets('fix5_confeti_limpio: el mismo resultado ya limpio, '
        'sin piezas congeladas', (tester) async {
      await pumpResult(tester, onRepeat: () {}, onExit: () {});
      await tester.pumpAndSettle();
      await shot(tester, 'fix5_confeti_limpio.png');
    });
  });
}

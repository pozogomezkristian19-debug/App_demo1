// Pruebas de la ronda #5 (Quemia 6.2), punto del CONFETI AL GANAR
// UN NIVEL. Causa del bug (verificada en celebration.dart): el
// confeti dibujado por código se quedaba CONGELADO y opaco al
// terminar, tapando los botones, y el overlay nunca se desmontaba
// (practicar_screen.dart ~2000 lo deja montado cuando passedLevel).
// El arreglo fix5 (retardo por pieza + desmontaje al terminar) se
// mantuvo, y el 2026-11-14 el confeti dibujado se cambió por la
// animación "confetti" de LottieFiles que mandó Kristian
// (https://lottiefiles.com/free-animation/confetti-3ofTs67sBx):
// una sola pasada de ~5 s y al terminar el overlay se desmonta.
// Aquí se verifica el Lottie en pantalla, el desmontaje al terminar
// y que los botones "Repetir"/"Volver" se pueden tocar TAMBIÉN
// DURANTE la celebración.
// Las dos capturas (fix5_confeti_mitad / fix5_confeti_limpio) se
// generan con --update-goldens SOLO sobre este archivo.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
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

  group('Confeti Lottie (assets/confetti.json)', () {
    testWidgets('la lluvia Lottie está en pantalla al aparecer',
        (tester) async {
      await pumpResult(tester, onRepeat: () {}, onExit: () {});
      expect(
        find.descendant(
          of: find.byType(CelebrationOverlay),
          matching: find.byType(Lottie),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a mitad de la pasada (2,5 s) el confeti sigue '
        'cayendo', (tester) async {
      await pumpResult(tester, onRepeat: () {}, onExit: () {});
      await tester.pump(const Duration(milliseconds: 2500));
      expect(
        find.descendant(
          of: find.byType(CelebrationOverlay),
          matching: find.byType(Lottie),
        ),
        findsOneWidget,
      );
      // Y ya no queda nada pintado después de la pasada (~5 s).
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(CelebrationOverlay),
          matching: find.byType(Lottie),
        ),
        findsNothing,
      );
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
      // A mitad de la celebración el confeti está cayendo.
      await tester.pump(const Duration(milliseconds: 2100));
      expect(
        find.descendant(
          of: find.byType(CelebrationOverlay),
          matching: find.byType(Lottie),
        ),
        findsOneWidget,
      );
      // Tras la animación (~5 s) el overlay se encoge: ya no
      // pinta nada.
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(CelebrationOverlay),
          matching: find.byType(Lottie),
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
      // A 1 s (progreso ~0,2) el confeti está cayendo a tope.
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.descendant(
          of: find.byType(CelebrationOverlay),
          matching: find.byType(Lottie),
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

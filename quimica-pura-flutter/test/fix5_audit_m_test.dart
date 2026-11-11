// Pruebas de la ronda #5 (Quemia 6.2), grupo Miscelánea de la
// auditoría propia 2026-11-11: A2 (Estadísticas cuentan como no
// pasados niveles que sí están pasados), A5 (el logro "Primer
// nivel" usa la nota vieja), A13 (en Constantes, c y e no están al
// principio) y A21 (la búsqueda no incluye Tema, Notificaciones,
// "¿Cómo se juega?" ni Tips).
//
// Este archivo NO importa practicar_screen.dart ni main.dart: el
// árbol está roto ahora mismo (otro agente dejó practicar_screen
// a medias) y ninguna de estas pruebas los necesita.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/data/extra_content.dart';
import 'package:quimica_pura/data/search_index.dart';
import 'package:quimica_pura/screens/stats_screen.dart';
import 'package:quimica_pura/services/achievements.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

/// Temas de la pista Universidad, en orden (los mismos que
/// StatsScreen._topicsOf). Total de niveles: 55.
const _uniTopics = [
  'estequiometria',
  'gases',
  'disoluciones',
  'acido-base',
  'equilibrio',
  'termo-cinetica',
  'tabla',
  'enlace',
  'organica',
  'laboratorio',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadRobotoFonts();
    await loadMaterialIcons();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({'melli_rules_seen_v6': true});
    ProgressService.track = ProgressService.trackUni;
    await UserPrefs.load();
    await ProgressService.load();
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
    UserPrefs.rulesSeenV6 = true;
    UserPrefs.onboardingDone = true;
  });

  tearDown(() {
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.onboardingDone = false;
  });

  /// Viewport de teléfono real (393x852, dpr 2).
  Future<void> setPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> pumpStats(WidgetTester tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(
          body: StatsScreen(trackTopics: _uniTopics),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('A2 — Estadísticas: "pasado" es lo mismo que en Niveles', () {
    testWidgets(
        'nivel pasado 4/5 fallando la difícil (nota 3.8 → 76 %) '
        'cuenta como pasado', (tester) async {
      final p = ProgressService.instance;
      // El caso del informe: preguntas [fácil, media, media, media,
      // difícil], 4/5 fallando la difícil → nota 3.8 → mejor 76 %.
      // Con la regla vieja (best >= 81) no se contaba.
      p.recordScore('level:estequiometria:1', 76);
      p.recordLevelPass('estequiometria', 1);
      expect(p.unlockedLevel('estequiometria'), 2);

      await pumpStats(tester);

      // Tarjeta de resumen y fila de detalle: 1 de 55, igual que el
      // contador "Superado: 1 / 55" del camino de Niveles.
      expect(find.text('Niveles: 1 / 55'), findsOneWidget);
      expect(find.text('1 / 55'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dos niveles pasados en dos temas: 2 / 55',
        (tester) async {
      final p = ProgressService.instance;
      p.recordScore('level:estequiometria:1', 76);
      p.recordLevelPass('estequiometria', 1);
      p.recordScore('level:gases:1', 80);
      p.recordLevelPass('gases', 1);

      await pumpStats(tester);

      expect(find.text('Niveles: 2 / 55'), findsOneWidget);
      expect(find.text('2 / 55'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'un 80 % guardado bajo la regla vieja, SIN pase, no se '
        'cuenta: la migración 80→81 no lo convierte en pasado',
        (tester) async {
      final p = ProgressService.instance;
      // Bajo la regla vieja, 4/5 en medias guardaba 80 % y NO
      // pasaba (la puerta era > 4,0). Sin desbloqueo, no está
      // pasado aunque la nota diga 80.
      p.recordScore('level:estequiometria:1', 80);
      expect(p.unlockedLevel('estequiometria'), 1);

      await pumpStats(tester);

      expect(find.text('Niveles: 0 / 55'), findsOneWidget);
      expect(find.text('0 / 55'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('A5 — El logro "Primer nivel" salta al pasar por conteo', () {
    test('4/5 fallando la difícil (nota 76 %): sin pase no hay '
        'logro; con el pase, sí', () {
      final p = ProgressService.instance;
      p.recordScore('level:estequiometria:1', 76);
      expect(achievementUnlocked('firstLevel', p, _uniTopics), isFalse);
      p.recordLevelPass('estequiometria', 1);
      expect(achievementUnlocked('firstLevel', p, _uniTopics), isTrue);
    });

    test('un 80 % guardado bajo la regla vieja, sin pase: no hay '
        'logro', () {
      final p = ProgressService.instance;
      p.recordScore('level:estequiometria:1', 80);
      expect(achievementUnlocked('firstLevel', p, _uniTopics), isFalse);
    });

    test('el examen mixto sigue con su propio listón del 80 % '
        '(no es un nivel: su logro no cambia)', () {
      final p = ProgressService.instance;
      p.recordScore('mixto', 79);
      expect(achievementUnlocked('mixedPass', p, _uniTopics), isFalse);
      p.recordScore('mixto', 80);
      expect(achievementUnlocked('mixedPass', p, _uniTopics), isTrue);
    });
  });

  group('A13 — Constantes: c y e al principio', () {
    test('c primera, e segunda, con los mismos valores', () {
      expect(chemConstants.length, 14);
      expect(chemConstants[0].symbol, 'c');
      expect(chemConstants[0].value, '3.00 × 10⁸ m·s⁻¹');
      expect(chemConstants[0].note, 'Velocidad de la luz en el vacío');
      expect(chemConstants[1].symbol, 'e');
      expect(chemConstants[1].value, '1.602 × 10⁻¹⁹ C');
      expect(chemConstants[1].note, 'Carga elemental');
    });

    test('el resto del orden no cambia y Vm a TPEA sigue en 24.8',
        () {
      expect(chemConstants[2].symbol, 'NA');
      expect(chemConstants.last.symbol, 'mp');
      final vm = chemConstants.where((c) => c.symbol == 'Vm').toList();
      expect(vm.length, 2);
      expect(vm[0].value, '22.4 L·mol⁻¹');
      expect(vm[1].value, '24.8 L·mol⁻¹');
      expect(vm[1].note, 'Volumen molar a TPEA (25 °C y 1 atm)');
    });
  });

  group('A21 — La búsqueda encuentra Tema, Notificaciones, '
      '"¿Cómo se juega?" y Tips', () {
    late List<SearchEntry> all;

    setUp(() {
      all = buildSearchEntries();
    });

    test('las cuatro pantallas están en el índice con la clave de '
        '_openScreenKey', () {
      for (final target in [
        'theme',
        'notifications',
        'howToPlay',
        'tips',
      ]) {
        expect(
          all.any((e) => e.kind == 'screen' && e.target == target),
          isTrue,
          reason: 'falta la pantalla $target en appScreens',
        );
      }
    });

    test('buscar "Tema" encuentra la pantalla Tema', () {
      final hits = searchEntries(all, 'Tema');
      expect(hits.any((e) => e.target == 'theme'), isTrue);
    });

    test('buscar "Notificaciones" encuentra la pantalla', () {
      final hits = searchEntries(all, 'Notificaciones');
      expect(hits.any((e) => e.target == 'notifications'), isTrue);
    });

    test('buscar "Cómo se juega" encuentra la pantalla (también '
        'sin tildes y en minúscula)', () {
      expect(
        searchEntries(all, 'Cómo se juega')
            .any((e) => e.target == 'howToPlay'),
        isTrue,
      );
      expect(
        searchEntries(all, 'como se juega')
            .any((e) => e.target == 'howToPlay'),
        isTrue,
      );
    });

    test('buscar "Tips" encuentra la pantalla', () {
      final hits = searchEntries(all, 'Tips');
      expect(hits.any((e) => e.target == 'tips'), isTrue);
    });
  });

}

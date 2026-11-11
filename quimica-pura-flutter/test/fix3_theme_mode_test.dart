// Pruebas de la ronda fix3 2026-11-10 (punto 13: el cambio de tema
// vive SOLO en Cuenta): el modo Claro / Oscuro / Sistema se elige
// en Cuenta, se guarda en el teléfono y cambia el tema de toda la
// app en el acto, sin el icono de sol/luna de la AppBar. El selector
// de color Verde/Violeta sigue donde estaba. Último cambio de la
// ronda: en Cuenta Tema ya NO es una tarjeta inline, es una fila
// táctil ("Verde · Claro") que abre su propia pantalla dedicada
// (ThemeScreen) con el color y el modo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/account_screen.dart';
import 'package:quimica_pura/screens/theme_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

Future<void> pumpAccount(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: AccountScreen(
          onOpenScreen: (_) {},
          onShowAbout: () {},
          onShowShareApp: () {},
          trackTopics: const ['estequiometria'],
        ),
      ),
    ),
  );
  await tester.pump();
  // Avanza 100 ms: la tarjeta de estadísticas va en un FadeSlideIn
  // con retardo de 80 ms (Future.delayed); sin este pump el Timer
  // queda pendiente al terminar el test ("Timer is still pending").
  // Así lo hace también el test de Cuenta de fix2_test.dart.
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> pumpTheme(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: ThemeScreen(),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRobotoFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    UserPrefs.rulesSeenV6 = true;
    UserPrefs.onboardingDone = true;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    await UserPrefs.saveThemeMode('claro');
    // Sin el popup del elemento del día, que si no se abre solo al
    // montar la pantalla principal y tapa los tests.
  });

  tearDown(() async {
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.onboardingDone = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    await UserPrefs.saveThemeMode('claro');
  });

  group('UserPrefs: modo de tema', () {
    test('guardar el modo persiste, avisa y sanea valores raros',
        () async {
      var avisos = 0;
      void oyente() => avisos++;
      UserPrefs.themeModeNotifier.addListener(oyente);
      addTearDown(
          () => UserPrefs.themeModeNotifier.removeListener(oyente));

      await UserPrefs.saveThemeMode('oscuro');
      expect(UserPrefs.themeMode, 'oscuro');
      expect(UserPrefs.isDark, true);
      expect(UserPrefs.themeModeNotifier.value, 'oscuro');
      expect(avisos, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('melli_theme_mode'), 'oscuro');
      expect(prefs.getBool('melli_dark_mode'), true);

      await UserPrefs.saveThemeMode('sistema');
      expect(UserPrefs.themeMode, 'sistema');
      expect(prefs.getString('melli_theme_mode'), 'sistema');

      // Un valor raro se sanea a claro, no rompe la app.
      await UserPrefs.saveThemeMode('loco');
      expect(UserPrefs.themeMode, 'claro');
      expect(UserPrefs.isDark, false);
      expect(prefs.getString('melli_theme_mode'), 'claro');
    });

    test('effectiveDark: claro no, oscuro sí, sistema sigue al teléfono',
        () async {
      await UserPrefs.saveThemeMode('claro');
      expect(UserPrefs.effectiveDark, false);
      await UserPrefs.saveThemeMode('oscuro');
      expect(UserPrefs.effectiveDark, true);
      // En el entorno de test el teléfono está claro.
      await UserPrefs.saveThemeMode('sistema');
      expect(UserPrefs.effectiveDark, false);
    });

    test('load() migra el viejo booleano si no hay modo guardado',
        () async {
      SharedPreferences.setMockInitialValues({'melli_dark_mode': true});
      await UserPrefs.load();
      expect(UserPrefs.themeMode, 'oscuro');
      expect(UserPrefs.isDark, true);

      // Fix6, ítem 3: sin modo guardado, isDark=false ya NO da 'claro':
      // el defecto es 'sistema' (sigue al brillo del teléfono).
      SharedPreferences.setMockInitialValues({'melli_dark_mode': false});
      await UserPrefs.load();
      expect(UserPrefs.themeMode, 'sistema');
      expect(UserPrefs.isDark, false);

      // Un modo guardado raro se sanea a claro al cargar.
      SharedPreferences.setMockInitialValues(
          {'melli_theme_mode': 'raro', 'melli_dark_mode': true});
      await UserPrefs.load();
      expect(UserPrefs.themeMode, 'claro');
      expect(UserPrefs.isDark, false);
    });

    test('saveDarkMode (viejo interruptor) queda en sync con el modo',
        () async {
      await UserPrefs.saveDarkMode(true);
      expect(UserPrefs.themeMode, 'oscuro');
      await UserPrefs.saveDarkMode(false);
      expect(UserPrefs.themeMode, 'claro');
    });

    test('las 6 lenguas tienen las claves nuevas del modo', () {
      final maps = AppLang.allStrings;
      final esKeys = maps['es']!.keys.toSet();
      for (final e in maps.entries) {
        expect(e.value.keys.toSet(), esKeys, reason: e.key);
        expect(e.value['themeSystem'], isNotEmpty);
        expect(e.value['themeModeLabel'], isNotEmpty);
        expect(e.value['themeSub'], isNotEmpty);
      }
    });
  });

  group('Cuenta: fila "Tema" + pantalla dedicada', () {
    testWidgets('la fila Tema muestra la selección actual en el '
        'subtítulo', (tester) async {
      await pumpAccount(tester);
      expect(find.text(tr('themeTitle')), findsOneWidget);
      expect(
          find.text('${tr('themeGreen')} · ${tr('lightWord')}'),
          findsOneWidget);
      // Las opciones viven en la pantalla dedicada, no en Cuenta.
      expect(find.text(tr('themeViolet')), findsNothing);
      expect(find.text(tr('themeModeLabel')), findsNothing);
      expect(find.text(tr('darkWord')), findsNothing);
      expect(find.text(tr('themeSystem')), findsNothing);
    });

    testWidgets('el subtítulo sigue al cambio (Violeta · Oscuro)',
        (tester) async {
      await UserPrefs.saveThemeAccent('violeta');
      await UserPrefs.saveThemeMode('oscuro');
      await pumpAccount(tester);
      expect(
          find.text('${tr('themeViolet')} · ${tr('darkWord')}'),
          findsOneWidget);
    });

    testWidgets('tocar la fila Tema abre la pantalla dedicada',
        (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: AccountScreen(
              onOpenScreen: opened.add,
              onShowAbout: () {},
              onShowShareApp: () {},
              trackTopics: const ['estequiometria'],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.ensureVisible(find.text(tr('themeTitle')));
      await tester.pump();
      await tester.tap(find.text(tr('themeTitle')));
      await tester.pump();
      expect(opened, ['theme']);
    });

    testWidgets('la pantalla dedicada tiene color Y modo', (tester) async {
      await pumpTheme(tester);
      expect(find.text(tr('themeTitle')), findsOneWidget);
      expect(find.text(tr('themeSub')), findsOneWidget);
      expect(find.text(tr('themeGreen')), findsOneWidget);
      expect(find.text(tr('themeViolet')), findsOneWidget);
      expect(find.text(tr('themeModeLabel')), findsOneWidget);
      expect(find.text(tr('lightWord')), findsOneWidget);
      expect(find.text(tr('darkWord')), findsOneWidget);
      expect(find.text(tr('themeSystem')), findsOneWidget);
    });

    testWidgets('tocar Oscuro / Sistema / Claro cambia el modo guardado',
        (tester) async {
      await pumpTheme(tester);
      expect(UserPrefs.themeMode, 'claro');

      await tester.tap(find.text(tr('darkWord')));
      await tester.pump();
      expect(UserPrefs.themeMode, 'oscuro');
      expect(UserPrefs.isDark, true);

      await tester.ensureVisible(find.text(tr('themeSystem')));
      await tester.pump();
      await tester.tap(find.text(tr('themeSystem')));
      await tester.pump();
      expect(UserPrefs.themeMode, 'sistema');

      await tester.tap(find.text(tr('lightWord')));
      await tester.pump();
      expect(UserPrefs.themeMode, 'claro');
      expect(UserPrefs.isDark, false);
    });

    testWidgets('el selector de color sigue funcionando', (tester) async {
      await pumpTheme(tester);
      await tester.tap(find.text(tr('themeViolet')));
      await tester.pump();
      expect(UserPrefs.themeAccent, 'violeta');
      await tester.tap(find.text(tr('themeGreen')));
      await tester.pump();
      expect(UserPrefs.themeAccent, 'verde');
    });

    testWidgets('círculos paralelos: anillo en las 5, relleno solo la '
        'seleccionada', (tester) async {
      // Verde y Claro seleccionados por defecto: 2 rellenos, 3 huecos.
      await pumpTheme(tester);
      final circles = find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final d = w.decoration;
        if (d is! BoxDecoration || d.shape != BoxShape.circle) {
          return false;
        }
        // Solo los círculos del tema: su anillo es de 2 px.
        final border = d.border;
        return border is Border && border.top.width == 2;
      });
      expect(circles, findsNWidgets(5));
      var filled = 0;
      final ringColors = <Color>{};
      for (final e in circles.evaluate()) {
        final d = (e.widget as Container).decoration as BoxDecoration;
        // Anillo de 2 px SIEMPRE, en las 5 opciones por igual.
        final border = d.border as Border;
        expect(border.top.width, 2);
        ringColors.add(border.top.color);
        if (d.color != null && d.color != Colors.transparent) filled++;
      }
      expect(filled, 2);
      // Los anillos tienen el color propio de cada opción (5
      // opciones, 5 colores: Verde teal, Violeta violeta, Claro
      // ámbar, Oscuro pizarra, Sistema azul).
      expect(
        ringColors,
        {
          const Color(0xFF00C2A8), // teal (Verde)
          const Color(0xFF8B5CF6), // violeta
          const Color(0xFFF59E0B), // ámbar (Claro)
          const Color(0xFF64748B), // pizarra (Oscuro)
          const Color(0xFF3B82F6), // azul (Sistema)
        },
      );
    });
  });

  group('La app entera sigue al modo elegido en Cuenta', () {
    testWidgets('cambiar el modo en Cuenta cambia el ThemeMode',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await UserPrefs.saveThemeMode('claro');
      await tester.pumpWidget(const MelliQuiApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      ThemeMode currentMode() =>
          tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;
      expect(currentMode(), ThemeMode.light);

      await UserPrefs.saveThemeMode('oscuro');
      await tester.pump();
      expect(currentMode(), ThemeMode.dark);

      await UserPrefs.saveThemeMode('sistema');
      await tester.pump();
      expect(currentMode(), ThemeMode.system);
    });
  });
}

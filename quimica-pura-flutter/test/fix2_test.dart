// Pruebas de la ronda fix2 2026-11-10 (13 puntos de Kristian +
// tema Verde/Violeta + auditoría): presencia y comportamiento de
// los cambios, sin capturar píxeles.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/data/i18n/content_i18n.dart';
import 'package:quimica_pura/data/questions.dart';
import 'package:quimica_pura/screens/account_screen.dart';
import 'package:quimica_pura/screens/challenge_screen.dart';
import 'package:quimica_pura/screens/lab_quiz_screen.dart';
import 'package:quimica_pura/screens/lab_screen.dart';
import 'package:quimica_pura/screens/onboarding_screen.dart';
import 'package:quimica_pura/screens/practicar_screen.dart';
import 'package:quimica_pura/screens/tabla_screen.dart';
import 'package:quimica_pura/screens/table_quiz_screen.dart';
import 'package:quimica_pura/screens/theme_screen.dart';
import 'package:quimica_pura/screens/timed_exam_screen.dart';
import 'package:quimica_pura/services/accent.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/avatar.dart';
import 'package:quimica_pura/widgets/brand_logo.dart';
import 'package:quimica_pura/widgets/lucide_icons.dart';
import 'package:quimica_pura/widgets/support_button.dart';
import 'package:quimica_pura/widgets/twin_avatars.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Roboto real: sin ella las medidas salen ~2x más anchas que en
  // el teléfono (ver test_helpers.dart).
  setUpAll(loadRobotoFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    UserPrefs.rulesSeenV6 = true;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    // Sin el popup del elemento del día, que si no se abre solo al
    // montar la pantalla principal y tapa los tests.
    ProgressService.instance.markElementDayShown();
  });

  tearDown(() {
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
  });

  Finder lucide(LucideIconData icon) => find.byWidgetPredicate(
        (w) => w is LucideIcon && w.icon == icon,
      );

  group('tema Verde/Violeta (item 12)', () {
    test('las 6 lenguas tienen las mismas claves (con las 4 nuevas)', () {
      final maps = AppLang.allStrings;
      expect(maps.keys.toSet(),
          {'es', 'en', 'fr', 'it', 'pt', 'ru'});
      final esKeys = maps['es']!.keys.toSet();
      expect(esKeys.length, greaterThan(100));
      for (final e in maps.entries) {
        expect(e.value.keys.toSet(), esKeys, reason: e.key);
        expect(e.value['themeTitle'], isNotEmpty);
        expect(e.value['themeSub'], isNotEmpty);
        expect(e.value['themeGreen'], isNotEmpty);
        expect(e.value['themeViolet'], isNotEmpty);
      }
    });

    test('AppAccent: verde = teal, violeta = violeta', () {
      UserPrefs.themeAccent = 'verde';
      expect(AppAccent.primary, const Color(0xFF00C2A8));
      expect(AppAccent.primaryDark, const Color(0xFF00A18D));
      expect(AppAccent.tabColor(0), const Color(0xFF00C2A8));
      expect(AppAccent.tabColor(1), const Color(0xFF8B5CF6));
      UserPrefs.themeAccent = 'violeta';
      expect(AppAccent.primary, const Color(0xFF8B5CF6));
      // Con violeta, TODAS las pestañas llevan violeta.
      for (var i = 0; i < 5; i++) {
        expect(AppAccent.tabColor(i), const Color(0xFF8B5CF6));
      }
    });

    test('el acento se guarda y se recupera (persistido)', () async {
      await UserPrefs.saveThemeAccent('violeta');
      expect(UserPrefs.themeAccent, 'violeta');
      expect(UserPrefs.themeAccentNotifier.value, 'violeta');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('melli_theme_accent'), 'violeta');
      // Un valor raro se sanea a verde, no rompe la app.
      await UserPrefs.saveThemeAccent('rojo');
      expect(UserPrefs.themeAccent, 'verde');
    });
  });

  group('AppBar (items 2 y 6)', () {
    Future<void> pumpHome(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: HomeScreen(
            isDark: false,
            onToggleTheme: () {},
            onTrackChanged: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('campana + repaso arriba, sin avatar y sin lupa',
        (tester) async {
      await pumpHome(tester);
      expect(lucide(LucideIcons.bell), findsOneWidget);
      expect(lucide(LucideIcons.rotateCcw), findsOneWidget);
      expect(find.byType(MelliAvatar), findsNothing);
      // La lupa ya no está en la barra: la búsqueda vive en el menú
      // (la del menú es la del cajón, fuera de la AppBar).
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: lucide(LucideIcons.search),
        ),
        findsNothing,
      );
    });

    testWidgets('sin errores, el repaso avisa; con errores, el número sube',
        (tester) async {
      await pumpHome(tester);
      await tester.tap(lucide(LucideIcons.rotateCcw));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('quizNoErrors')), findsOneWidget);

      // Un error nuevo: el numerito del chip pasa de 0 a 1.
      ProgressService.instance.addFailed(FailedEntry(
        id: 'fix2-test-1',
        topic: 'estequiometria',
        question: 'Pregunta de prueba',
        level: 1,
      ));
      await tester.pump();
      // La fila del chip (ancestro Row más cercano al icono) tiene
      // un solo Text: el número de errores.
      final chipRow = find.ancestor(
        of: lucide(LucideIcons.rotateCcw),
        matching: find.byType(Row),
      ).first;
      final chipText = find.descendant(
        of: chipRow,
        matching: find.byType(Text),
      );
      expect(tester.widget<Text>(chipText).data, '1');
    });

    testWidgets('menú: búsqueda fija arriba; sin simulador duplicado',
        (tester) async {
      await pumpHome(tester);
      await tester.tap(find.byTooltip(tr('menuWord')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // La barra de búsqueda es un TextField y está ARRIBA del todo.
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      final header = find.text('Quemia');
      expect(
        tester.getTopLeft(searchField).dy,
        lessThan(tester.getTopLeft(header).dy),
      );
      // Fix3 (segunda pasada): el simulador NO tiene entrada aparte
      // en el menú (estaba duplicado). No aparece en el cajón; la
      // vía de acceso es Laboratorio, cuya descripción lo anuncia.
      expect(find.text(tr('labSimTitle')), findsNothing);
      expect(find.text(tr('menuLab')), findsOneWidget);
      expect(find.text('Seguridad, cuestionario y simulador'),
          findsOneWidget);
      // Y ya no queda ningún "Buscar" suelto al final del menú.
      expect(find.text(tr('searchWord')), findsOneWidget);
    });
  });

  group('Niveles compacto (item 3)', () {
    testWidgets('sin intro, con gemela + pregunta del día + camino arriba',
        (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: PracticarScreen(onOpenScreen: (_) {}),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // La introducción larga ya no está.
      expect(find.text(tr('levelsIntro')), findsNothing);
      // Gemela del día, pregunta del día y las 2 tarjetas.
      expect(find.textContaining('Hoy te acompaña'), findsOneWidget);
      expect(find.text('Pregunta del día'), findsOneWidget);
      // El primer nivel del camino se ve sin deslizar (viewport
      // 360x800 con barra y navegación: cabe antes de los 660 px).
      final firstLevel = tester.getTopLeft(find.text('Nivel 1').first);
      expect(firstLevel.dy, lessThan(660));
    });

    testWidgets('el mando del Reto va en su círculo, sin deformarse',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: PracticarScreen(onOpenScreen: (_) {}),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final gamepad = lucide(LucideIcons.gamepad2);
      expect(gamepad, findsOneWidget);
      expect(
        tester.widget<LucideIcon>(gamepad).size,
        28,
      );
    });
  });

  group('Tabla (items 9 y 10; fix3 punto 2 REVISADO: leyenda solo en "Todos")', () {
    testWidgets('lupa pequeña y leyenda solo sin filtro de categoría',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const Scaffold(body: TablaScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // La lupa de búsqueda mide 18, no 24 ni 28.
      final search = lucide(LucideIcons.search);
      expect(search, findsOneWidget);
      expect(tester.widget<LucideIcon>(search).size, 18);
      // Fix3 punto 2 revisado (comportamiento ronda #2): sin filtro
      // ("Todos") la leyenda SÍ se muestra, con sus 10 categorías y
      // la línea "118 elementos.".
      expect(find.text(tr('legendWord')), findsOneWidget);
      expect(find.text('118 ${tr('elementsWord')}.'), findsOneWidget);
      // Con el filtro de metal alcalino, la leyenda desaparece.
      final chips = find.byType(ChoiceChip);
      await tester.tap(chips.at(1));
      await tester.pump();
      expect(find.text(tr('legendWord')), findsNothing);
      expect(find.text('118 ${tr('elementsWord')}.'), findsNothing);
      // Quitando el filtro, la leyenda vuelve.
      await tester.tap(chips.at(1));
      await tester.pump();
      expect(find.text(tr('legendWord')), findsOneWidget);
      expect(find.text('118 ${tr('elementsWord')}.'), findsOneWidget);
    });
  });

  group('Onboarding (item 5)', () {
    testWidgets('la primera pantalla ya no trae la imagen de las gemelas',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: OnboardingScreen(onFinished: () {}),
        ),
      );
      await tester.pump();
      final twinsImage = find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == 'assets/twins.png',
      );
      expect(twinsImage, findsNothing);
      expect(find.byType(BrandLogo), findsOneWidget);
      expect(find.text(tr('obWelcome')), findsOneWidget);
    });
  });

  group('Cuenta (items 6 y 12)', () {
    testWidgets('sin selector de avatar propio; con fila Tema que abre '
        'su pantalla', (tester) async {
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
      expect(find.byType(MelliAvatar), findsNothing);
      expect(find.text(tr('accountAvatarTitle')), findsNothing);
      // Corrección fix3: en Cuenta NO hay avatar del USUARIO ni su
      // selector (eso fue lo único que se pidió quitar), PERO la
      // foto de la compañera del día SÍ está (48 px, con su aro de
      // color, junto a la línea "Hoy te acompaña…"). No son
      // TwinAvatarA/B (la API nueva es CompanionAvatar, que cubre
      // a los tres, incluido Kristian) ni hay etiqueta de nombre
      // bajo la foto.
      expect(find.byType(TwinAvatarA), findsNothing);
      expect(find.byType(TwinAvatarB), findsNothing);
      expect(find.text(tr('accountTitle')), findsOneWidget);
      expect(
          find.text(
              tr(companionOfDayKey(companionOfTheDay()))),
          findsOneWidget);
      // Tema ya NO es una tarjeta inline en Cuenta (fix3, último
      // cambio): es una fila táctil como las demás, con el
      // subtítulo de la selección actual ("Verde · Claro"), que
      // abre su propia pantalla dedicada. Las opciones viven allí,
      // no en Cuenta.
      expect(find.text(tr('themeTitle')), findsOneWidget);
      expect(
          find.text(
              '${tr('themeGreen')} · ${tr('lightWord')}'),
          findsOneWidget);
      expect(find.text(tr('themeViolet')), findsNothing);
      expect(find.text(tr('themeModeLabel')), findsNothing);
      // Tocar la fila abre la pantalla Tema.
      await tester.ensureVisible(find.text(tr('themeTitle')));
      await tester.pump();
      await tester.tap(find.text(tr('themeTitle')));
      await tester.pump();
      expect(opened, ['theme']);
      // En la pantalla dedicada, el selector de color funciona.
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: ThemeScreen(),
        ),
      );
      await tester.pump();
      expect(find.text(tr('themeGreen')), findsOneWidget);
      expect(find.text(tr('themeViolet')), findsOneWidget);
      await tester.tap(find.text(tr('themeViolet')));
      await tester.pump();
      expect(UserPrefs.themeAccent, 'violeta');
      await tester.tap(find.text(tr('themeGreen')));
      await tester.pump();
      expect(UserPrefs.themeAccent, 'verde');
    });
  });

  group('Laboratorio y Reto (items 4 y 7)', () {
    testWidgets('en Lab, el simulador va ANTES que el cuestionario',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const LabScreen(),
        ),
      );
      await tester.pump();
      // El simulador es la primera tarjeta (el contenido del tema
      // va debajo, así que la primera del árbol es él).
      final firstCard = find.byType(Card).first;
      expect(
        find.descendant(
          of: firstCard,
          matching: find.text(tr('labSimTitle')),
        ),
        findsOneWidget,
      );
      // Icono ARRIBA del texto y ambas tarjetas iguales de alto
      // (auditoría fix2: los botones viejos partían el texto en
      // 3 líneas apretado).
      final icon = find.descendant(
        of: firstCard,
        matching: lucide(LucideIcons.flaskConical),
      );
      expect(icon, findsOneWidget);
      expect(tester.getCenter(icon).dy,
          lessThan(tester.getCenter(find.text(tr('labSimTitle'))).dy));
      final sizes = find.byType(Card).evaluate().map((e) {
        final box = e.renderObject as RenderBox;
        return box.size.height;
      }).toList();
      expect(sizes.first, sizes.last);
    });

    testWidgets('el mando del Reto va en un círculo de 96',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const ChallengeScreen(),
        ),
      );
      await tester.pump();
      final gamepad = lucide(LucideIcons.gamepad2);
      expect(gamepad, findsOneWidget);
      expect(tester.widget<LucideIcon>(gamepad).size, 48);
      // Algún Container ancestro mide 96x96 y es un círculo.
      final circles = find.ancestor(
        of: gamepad,
        matching: find.byType(Container),
      );
      var found = false;
      for (var i = 0; i < circles.evaluate().length; i++) {
        final c = tester.widget<Container>(circles.at(i));
        final dec = c.decoration;
        if (tester.getSize(circles.at(i)) == const Size(96, 96) &&
            dec is BoxDecoration &&
            dec.shape == BoxShape.circle) {
          found = true;
        }
      }
      expect(found, isTrue);
    });
  });

  group('Encabezado del quiz (bug 6: sin ids internos)', () {
    test('localizedTopicName devuelve el nombre, no el slug', () {
      expect(localizedTopicName('bach-estequiometria'),
          'Estequiometría básica');
      expect(localizedTopicName('bach-gases'), 'Gases');
      expect(localizedTopicName('bach-disoluciones'), 'Disoluciones');
      expect(localizedTopicName('bach-acido-base'), 'Ácido-base');
      expect(localizedTopicName('estequiometria'), 'Estequiometría');
      expect(localizedTopicName('organica'), 'Química orgánica');
      expect(localizedTopicName('laboratorio'), 'Laboratorio');
      // Un slug desconocido se muestra legible, sin guiones ni
      // prefijos, nunca crudo (fix3).
      expect(localizedTopicName('tema-que-no-existe'), 'Tema que no existe');
    });
  });

  group('Tarjetas en oscuro (bug 2)', () {
    Future<void> pumpDark(
        WidgetTester tester, Widget child, String route) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme:
              ThemeData(brightness: Brightness.dark, useMaterial3: true),
          home: Scaffold(body: child),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('Niveles: ninguna tarjeta es gris claro en oscuro',
        (tester) async {
      await pumpDark(
          tester, PracticarScreen(onOpenScreen: (_) {}), 'niveles');
      // La pregunta del día y las 3 "Practicar de otra forma".
      expect(find.text('Pregunta del día'), findsOneWidget);
      for (final e in find.byType(Card).evaluate()) {
        final c = e.widget as Card;
        expect(c.color, isNot(BrandColors.cardGray));
      }
    });

    testWidgets('Tabla: los botones no son gris claro en oscuro',
        (tester) async {
      await pumpDark(tester, const TablaScreen(), 'tabla');
      for (final e in find.byType(Card).evaluate()) {
        final c = e.widget as Card;
        expect(c.color, isNot(BrandColors.cardGray));
      }
    });
  });

  group('AppBar sin título (fix3, punto 6) y Soporte en el menú', () {
    Future<void> pumpHomeScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: HomeScreen(
            isDark: false,
            onToggleTheme: () {},
            onTrackChanged: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('sin título de texto: la barra es solo controles',
        (tester) async {
      await pumpHomeScreen(tester);
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      // Fix3, punto 6 (ampliación): el nombre de la pantalla se
      // quitó de la barra porque se recortaba ("Ni..."); ya está
      // como título grande dentro del contenido de cada pestaña.
      expect(appBar.title, isNull);
      // Ni el nombre de la sección ni el saludo aparecen recortados
      // en la barra.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(tr('tabLevels')),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.textContaining('Bienvenid'),
        ),
        findsNothing,
      );
      // Los controles siguen: menú, vidas, repaso, campana y tema.
      expect(find.byTooltip(tr('menuWord')), findsOneWidget);
      expect(lucide(LucideIcons.bell), findsOneWidget);
      expect(lucide(LucideIcons.rotateCcw), findsOneWidget);
    });

    testWidgets('sin botón flotante; Soporte vive al pie del menú',
        (tester) async {
      await pumpHomeScreen(tester);
      expect(find.byType(SupportButton), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      await tester.tap(find.byTooltip(tr('menuWord')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Soporte está en el menú, al final (debajo de Notas).
      expect(find.text(tr('supportWord')), findsOneWidget);
      final supportY =
          tester.getTopLeft(find.text(tr('supportWord'))).dy;
      final notesY = tester.getTopLeft(find.text(tr('notesTitle'))).dy;
      expect(supportY, greaterThan(notesY));
    });

    testWidgets('el logo de WhatsApp va en su círculo verde',
        (tester) async {
      // El asset es el glifo BLANCO: sin el círculo verde era
      // invisible sobre el fondo blanco del drawer (auditoría).
      await pumpHomeScreen(tester);
      await tester.tap(find.byTooltip(tr('menuWord')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final logo = find.byWidgetPredicate((w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == 'assets/whatsapp.png');
      expect(logo, findsOneWidget);
      final greenCircle = find.ancestor(
        of: logo,
        matching: find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color ==
                const Color(0xFF25D366) &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle),
      );
      expect(greenCircle, findsOneWidget);
    });
  });

  group('Botones de Tabla (bug 13: icono arriba, texto debajo)', () {
    testWidgets('icono arriba y mismo tamaño en los dos botones',
        (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const Scaffold(body: TablaScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      for (final labelKey in ['tableQuizTitle', 'compareTitle']) {
        final label = find.text(tr(labelKey));
        expect(label, findsOneWidget);
        final card = find
            .ancestor(of: label, matching: find.byType(Card))
            .first;
        final icon = find.descendant(
            of: card, matching: find.byType(LucideIcon));
        expect(icon, findsOneWidget);
        expect(tester.getCenter(icon).dy,
            lessThan(tester.getCenter(label).dy));
      }
      // Los dos botones miden exactamente lo mismo.
      final quizCard = find
          .ancestor(
              of: find.text(tr('tableQuizTitle')),
              matching: find.byType(Card))
          .first;
      final compareCard = find
          .ancestor(
              of: find.text(tr('compareTitle')),
              matching: find.byType(Card))
          .first;
      expect(tester.getSize(quizCard), tester.getSize(compareCard));
    });
  });

  group('Bloqueo de sesión (ronda 2)', () {
    Future<void> pumpHomeScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: HomeScreen(
            isDark: false,
            onToggleTheme: () {},
            onTrackChanged: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    /// Una pantalla empujada desde un botón, para probar el botón
    /// atrás (la raíz no se puede cerrar con pop).
    Future<void> pumpPushable(
        WidgetTester tester, Widget screen) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => screen),
                  ),
                  child: const Text('Abrir pantalla'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Abrir pantalla'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    /// El botón atrás muestra el aviso; quedarse no sale; salir
    /// confirma, quita 1 vida y cierra la pantalla.
    Future<void> checkBackWarning(WidgetTester tester) async {
      expect(ProgressService.instance.livesLeft, 5);
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('exitLevelTitle')), findsOneWidget);
      // Quedarse: la pantalla sigue.
      await tester.tap(find.text(tr('exitLevelStay')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('exitLevelTitle')), findsNothing);
      expect(find.text('Abrir pantalla'), findsNothing);
      // Salir: −1 vida y vuelta a la pantalla anterior.
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(tr('exitLevelLeave')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(ProgressService.instance.livesLeft, 4);
      expect(find.text('Abrir pantalla'), findsOneWidget);
    }

    testWidgets(
        'en un repaso se ocultan AppBar y navbar; las opciones se leen',
        (tester) async {
      await pumpHomeScreen(tester);
      // Un error real del banco, para que el repaso tenga variantes.
      final q = allQuestions.firstWhere(
          (element) => element.topic == 'estequiometria');
      ProgressService.instance.addFailed(FailedEntry(
        id: 'bank:${q.topic}:${q.question}',
        topic: q.topic,
        question: q.question,
        level: 1,
      ));
      await tester.pump();
      await tester.tap(lucide(LucideIcons.rotateCcw));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Sesión activa: sin AppBar ni navbar; sí botón Salir.
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text(tr('quizExit')), findsOneWidget);
      expect(find.textContaining('Pregunta 1 de'), findsOneWidget);
      // Las opciones se leen: el color del texto no es blanco.
      for (final e in find.byType(ElevatedButton).evaluate()) {
        final b = e.widget as ElevatedButton;
        final fg =
            b.style?.foregroundColor?.resolve(<WidgetState>{});
        if (fg != null) expect(fg, isNot(Colors.white));
      }
      // Salir del repaso es directo (no es un nivel) y la barra vuelve.
      await tester.tap(find.text(tr('quizExit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('Reto: el botón atrás pide confirmar con pérdida de vida',
        (tester) async {
      await pumpPushable(tester, const ChallengeScreen());
      await tester.enterText(
          find.byType(TextField).at(0), 'Kristian (tú)');
      await tester.enterText(find.byType(TextField).at(1), 'Britany');
      await tester.tap(find.text(tr('challengeStart')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Pregunta 1 de'), findsOneWidget);
      await checkBackWarning(tester);
    });

    testWidgets(
        'Examen con tiempo: el botón atrás pide confirmar con vida',
        (tester) async {
      await pumpPushable(tester, const TimedExamScreen());
      await tester.tap(find.text(tr('timedStart')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Pregunta 1'), findsOneWidget);
      await checkBackWarning(tester);
    });

    testWidgets(
        'Cuestionario de laboratorio: el botón atrás pide confirmar',
        (tester) async {
      await pumpPushable(tester, const LabQuizPage());
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Pregunta 1 de'), findsOneWidget);
      await checkBackWarning(tester);
    });

    testWidgets('Quiz de la tabla: el botón atrás pide confirmar',
        (tester) async {
      await pumpPushable(tester, const TableQuizScreen());
      await tester.pump(const Duration(milliseconds: 300));
      await checkBackWarning(tester);
    });

  });

  group('LucideIcon no se estira (auditoría)', () {
    // El hueco que le da el padre PUEDE estirarse (un Column con
    // stretch o el slot del prefixIcon): lo que no puede estirarse
    // es el GLIFO. El pintor dibuja siempre al tamaño nominal,
    // centrado. Se comprueba que el CustomPaint lleva el tamaño
    // nominal; el píxel se verifica en las previews (drawer, Tabla).
    testWidgets('en un Column con stretch el glifo sigue a 24',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LucideIcon(LucideIcons.gamepad2),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final icon = lucide(LucideIcons.gamepad2);
      expect(icon, findsOneWidget);
      expect(
          tester.widget<CustomPaint>(find.descendant(
              of: icon, matching: find.byType(CustomPaint)))
              .size,
          const Size(24, 24));
    });

    testWidgets('en el prefixIcon de un TextField el glifo sigue a 18',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              decoration: InputDecoration(
                hintText: tr('searchWord'),
                prefixIcon:
                    const LucideIcon(LucideIcons.search, size: 18),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final icon = lucide(LucideIcons.search);
      expect(icon, findsOneWidget);
      expect(
          tester.widget<CustomPaint>(find.descendant(
              of: icon, matching: find.byType(CustomPaint)))
              .size,
          const Size(18, 18));
    });
  });
}

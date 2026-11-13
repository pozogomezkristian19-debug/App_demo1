// Pruebas de la ronda fix2 2026-11-10 (13 puntos de Kristian +
// tema Verde/Violeta + auditoría): presencia y comportamiento de
// los cambios, sin capturar píxeles.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/data/i18n/content_i18n.dart';
import 'package:quimica_pura/data/questions.dart';
import 'package:quimica_pura/screens/account_screen.dart';
import 'package:quimica_pura/screens/lab_quiz_screen.dart';
import 'package:quimica_pura/screens/lab_screen.dart';
import 'package:quimica_pura/screens/onboarding_screen.dart';
import 'package:quimica_pura/screens/practicar_screen.dart';
import 'package:quimica_pura/screens/settings_screen.dart';
import 'package:quimica_pura/screens/compare_screen.dart';
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
import 'package:quimica_pura/widgets/main_bottom_nav.dart';
import 'package:quimica_pura/widgets/social_avatar.dart';
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
      expect(maps.keys.toSet(), {'es', 'en', 'fr', 'it', 'pt', 'ru'});
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
      // Regla 9 (rediseño Duolingo): UN solo color de acción — todas
      // las pestañas llevan el acento elegido, no un color por
      // pestaña. La lista de colores por pestaña quedó retirada
      // (ver AppAccent.tabColor en accent.dart).
      for (var i = 0; i < 5; i++) {
        expect(AppAccent.tabColor(i), const Color(0xFF00C2A8));
      }
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
      final chipRow = find
          .ancestor(
            of: lucide(LucideIcons.rotateCcw),
            matching: find.byType(Row),
          )
          .first;
      final chipText = find.descendant(
        of: chipRow,
        matching: find.byType(Text),
      );
      expect(tester.widget<Text>(chipText).data, '1');
    });

    testWidgets(
        'menú: búsqueda fija arriba; simulador en Referencia (fix4, punto 12)',
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
      // Fix4, punto 12 (sustituye la regla de fix3): el simulador
      // TIENE entrada propia en el menú, en Referencia, UNA sola
      // vez (no duplicado). La vía de acceso Laboratorio sigue
      // existiendo, con su descripción anunciándolo.
      expect(find.text(tr('labSimTitle')), findsOneWidget);
      expect(find.text(tr('menuLab')), findsOneWidget);
      expect(find.text('Seguridad, cuestionario y simulador'), findsOneWidget);
      // Y ya no queda ningún "Buscar" suelto al final del menú.
      expect(find.text(tr('searchWord')), findsOneWidget);
    });
  });

  group('Niveles compacto (item 3)', () {
    testWidgets(
        'sin intro, pregunta del día ancha con la foto del acompañante'
        ' + camino arriba (fix4, punto 13 REVISADO)', (tester) async {
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
      // El banner "Hoy te acompaña…" ya NO está en Niveles (fix4,
      // punto 13 REVISADO: lo quitó Kristian); la pregunta del día
      // se eliminó por completo de la app en la ronda #6.
      expect(find.textContaining('Hoy te acompaña'), findsNothing);
      expect(find.text('Pregunta del día'), findsNothing);
      expect(find.byType(CompanionAvatar), findsWidgets);
      // El primer nivel del camino se ve sin deslizar (viewport
      // 360x800 con barra y navegación: cabe antes de los 660 px).
      // La etiqueta "Nivel 1" ya no existe (§3.2.2): se usa el
      // número del nodo.
      final firstLevel = tester.getTopLeft(find.text('1').first);
      expect(firstLevel.dy, lessThan(660));
    });

    // (fix6, ronda #6): la tarjeta "Practicar de otra forma" (con
    // el mando del Reto) se quitó de Niveles, así que este test se
    // elimina. (7.0: el Reto se quitó entero de la app.)
  });

  group('Tabla (items 9 y 10; fix3 punto 2 REVISADO: leyenda solo en "Todos")',
      () {
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
    testWidgets(
        'avatar editable en el círculo; sin género escrito; Tema '
        'vive en Ajustes y abre su pantalla', (tester) async {
      // Con nombre y género puestos, el saludo es "Bienvenido
      // Kristian" SIN "· Masculino" (alcance 10).
      UserPrefs.userName = 'Kristian';
      UserPrefs.userGender = 'Masculino';
      addTearDown(() {
        UserPrefs.userName = '';
        UserPrefs.userGender = '';
      });
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
      // Nada de avatares dibujados con código (eso sigue
      // rechazado) ni del selector viejo.
      expect(find.byType(MelliAvatar), findsNothing);
      expect(find.text(tr('accountAvatarTitle')), findsNothing);
      // Alcance 9: el CÍRCULO GRANDE (96 dp) es el avatar del
      // USUARIO (SocialAvatar, con su lápiz), no la compañera.
      // Tocar ahí abre la galería (clave 'avatar').
      expect(find.byType(SocialAvatar), findsOneWidget);
      expect(tester.getSize(find.byType(SocialAvatar)), const Size(96, 96));
      await tester.tap(find.byType(SocialAvatar));
      await tester.pump();
      expect(opened, ['avatar']);
      // La compañera del día sigue, pero en MINIATURA (22 dp)
      // junto a la línea "Hoy te acompaña…": no es TwinAvatarA/B
      // (la API nueva es CompanionAvatar, que cubre a los tres,
      // incluido Kristian) ni hay etiqueta de nombre bajo la foto.
      expect(find.byType(CompanionAvatar), findsOneWidget);
      expect(tester.getSize(find.byType(CompanionAvatar)), const Size(22, 22));
      expect(find.byType(TwinAvatarA), findsNothing);
      expect(find.byType(TwinAvatarB), findsNothing);
      expect(find.text(tr('accountTitle')), findsOneWidget);
      expect(find.text(tr(companionOfDayKey(companionOfTheDay()))),
          findsOneWidget);
      // Alcance 10: el saludo dice "Bienvenido Kristian" y el
      // género NO se muestra escrito en ningún sitio de Cuenta.
      expect(find.text('Bienvenido Kristian'), findsOneWidget);
      expect(find.text('Masculino'), findsNothing);
      expect(find.text('Femenino'), findsNothing);
      // Alcance 6: la fila Tema ya NO está en Cuenta; vive en
      // Ajustes. Fix6, ítem 3: el tema por defecto es 'sistema'
      // (el estático nace así y load() sin nada guardado también),
      // así que el subtítulo de la fila Tema es "Verde · Sistema".
      expect(find.text(tr('themeTitle')), findsNothing);
      await UserPrefs.saveThemeMode('sistema');
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: SettingsScreen(
              onOpenScreen: opened.add,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(tr('themeTitle')), findsOneWidget);
      expect(find.text('${tr('themeGreen')} · ${tr('themeSystem')}'),
          findsOneWidget);
      expect(find.text(tr('themeViolet')), findsNothing);
      expect(find.text(tr('themeModeLabel')), findsNothing);
      // Tocar la fila abre la pantalla Tema.
      await tester.scrollUntilVisible(
        find.text(tr('themeTitle')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text(tr('themeTitle')));
      await tester.pump();
      expect(opened, ['avatar', 'theme']);
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

  group('Laboratorio (item 4)', () {
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
      // Icono ARRIBA del texto y ambas tarjetas DE ACCIÓN iguales
      // de alto (auditoría fix2: los botones viejos partían el
      // texto en 3 líneas apretado). Se comparan por su etiqueta,
      // no "primera y última Card del árbol": el contenido del tema
      // debajo también trae tarjetas desde la 7.1 (ítem 5a) y la
      // última del árbol ya no es la del cuestionario.
      final icon = find.descendant(
        of: firstCard,
        matching: lucide(LucideIcons.flaskConical),
      );
      expect(icon, findsOneWidget);
      expect(tester.getCenter(icon).dy,
          lessThan(tester.getCenter(find.text(tr('labSimTitle'))).dy));
      final simCard = find
          .ancestor(
            of: find.text(tr('labSimTitle')),
            matching: find.byType(Card),
          )
          .first;
      final quizCard = find
          .ancestor(
            of: find.text(tr('labQuizButton')),
            matching: find.byType(Card),
          )
          .first;
      expect(
        tester.getSize(simCard).height,
        tester.getSize(quizCard).height,
      );
    });
  });

  group('Encabezado del quiz (bug 6: sin ids internos)', () {
    test('localizedTopicName devuelve el nombre, no el slug', () {
      expect(
          localizedTopicName('bach-estequiometria'), 'Estequiometría básica');
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
          theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
          home: Scaffold(body: child),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('Niveles: ninguna tarjeta es gris claro en oscuro',
        (tester) async {
      await pumpDark(tester, PracticarScreen(onOpenScreen: (_) {}), 'niveles');
      // La pregunta del día y "Practicar de otra forma" ya no están
      // en Niveles (ronda #6).
      expect(find.text('Pregunta del día'), findsNothing);
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

  group(
      'AppBar sin título (fix3, punto 6) y Soporte fuera del menú '
      '(fix4, punto 11)', () {
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
          matching: find.textContaining('Kristian'),
        ),
        findsNothing,
      );
      // Los controles siguen: menú, vidas, repaso, campana y tema.
      expect(find.byTooltip(tr('menuWord')), findsOneWidget);
      expect(lucide(LucideIcons.bell), findsOneWidget);
      expect(lucide(LucideIcons.rotateCcw), findsOneWidget);
    });

    testWidgets(
        'sin botón flotante; el menú ya no trae Soporte (vive en Cuenta)',
        (tester) async {
      await pumpHomeScreen(tester);
      expect(find.byType(SupportButton), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      await tester.tap(find.byTooltip(tr('menuWord')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // El Soporte salió del menú por completo (fix4, punto 11): ni
      // la fila ni el logo de WhatsApp están ya en el drawer. Vive
      // en Cuenta como última opción (ver fix4_cuenta_soporte_test).
      expect(find.text(tr('supportWord')), findsNothing);
      expect(
        find.byWidgetPredicate((w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == 'assets/whatsapp.png'),
        findsNothing,
      );
      // Fix6, ítem 5: "Mi cuaderno" salió del menú; la última fila
      // es ahora Comparar, que cierra la lista.
      expect(find.text(tr('compareTitle')), findsOneWidget);
    });
  });

  // Rediseño Tabla 2026-11-12 (mockup flotante aprobado): las dos
  // tarjetas grandes se quitaron; Comparar y Quiz son ahora
  // píldoras flotantes abajo a la derecha, una encima de la otra
  // (Comparar arriba, Quiz abajo), con icono a la IZQUIERDA del
  // texto corto, misma altura (44 pt) y alineadas a la derecha.
  // El bug 13 original (icono arriba, texto debajo, en tarjetas)
  // ya no aplica: aquí el icono va al lado del texto.
  group('Botones flotantes de Tabla (rediseño 2026-11-12)', () {
    Future<void> pumpTabla(WidgetTester tester) async {
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
    }

    Finder pillOf(String labelKey) => find
        .ancestor(
          of: find.text(tr(labelKey)),
          matching: find.byType(InkWell),
        )
        .first;

    testWidgets('icono a la izquierda del texto y misma altura',
        (tester) async {
      await pumpTabla(tester);
      for (final labelKey in ['quizShort', 'compareShort']) {
        final label = find.text(tr(labelKey));
        expect(label, findsOneWidget);
        final pill = pillOf(labelKey);
        final icon =
            find.descendant(of: pill, matching: find.byType(LucideIcon));
        expect(icon, findsOneWidget);
        // Icono a la izquierda del texto, en la misma línea.
        expect(tester.getCenter(icon).dx, lessThan(tester.getCenter(label).dx));
        expect(tester.getCenter(icon).dy,
            closeTo(tester.getCenter(label).dy, 1.0));
        // Altura 44 pt en los dos.
        expect(tester.getSize(pill).height, 44);
      }
    });

    testWidgets(
        'apilados abajo a la derecha: Comparar arriba, '
        'Quiz abajo, alineados a la derecha', (tester) async {
      await pumpTabla(tester);
      final compare = pillOf('compareShort');
      final quiz = pillOf('quizShort');
      // Comparar encima de Quiz.
      expect(tester.getCenter(compare).dy, lessThan(tester.getCenter(quiz).dy));
      // Alineados al borde derecho (mismo borde derecho).
      expect(tester.getBottomRight(compare).dx,
          closeTo(tester.getBottomRight(quiz).dx, 1.0));
      // Abajo del todo de la pantalla (800 pt de alto): el borde
      // inferior de Quiz queda a 16 pt del borde inferior.
      expect(tester.getBottomRight(quiz).dy, closeTo(800 - 16, 1.0));
      // Sin tarjetas grandes: ya no hay ningún Card de acción.
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('el flotante Quiz abre el quiz de la tabla', (tester) async {
      await pumpTabla(tester);
      await tester.tap(find.text(tr('quizShort')));
      await tester.pumpAndSettle();
      expect(find.byType(TableQuizScreen), findsOneWidget);
    });

    testWidgets('el flotante Comparar abre la comparación', (tester) async {
      await pumpTabla(tester);
      await tester.tap(find.text(tr('compareShort')));
      await tester.pumpAndSettle();
      expect(find.byType(CompareScreen), findsOneWidget);
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
    Future<void> pumpPushable(WidgetTester tester, Widget screen) async {
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

    /// El botón atrás en una actividad SIN vidas (fix4, punto 5):
    /// muestra el aviso nuevo, quedarse no sale, y salir NO quita
    /// vidas (los puntos ganados hasta ahí se quedan).
    Future<void> checkBackWarningNoLives(WidgetTester tester) async {
      expect(ProgressService.instance.livesLeft, 5);
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('exitNoLivesTitle')), findsOneWidget);
      // Quedarse: la pantalla sigue.
      await tester.tap(find.text(tr('exitLevelStay')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('exitNoLivesTitle')), findsNothing);
      expect(find.text('Abrir pantalla'), findsNothing);
      // Salir: las vidas NO cambian y vuelta a la pantalla anterior.
      // El botón "Salir" del diálogo dice igual que el botón Salir
      // del quiz que hay detrás: se busca dentro del diálogo.
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(tr('exitNoLivesLeave')),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(ProgressService.instance.livesLeft, 5);
      expect(find.text('Abrir pantalla'), findsOneWidget);
    }

    /// El botón atrás en un NIVEL: salir sí cuesta 1 vida.
    /// La sesión de quiz no tiene AppBar ni botón atrás del sistema
    /// (ronda 2): la única salida es la X del quiz (§3.3.1).
    Future<void> checkBackWarningLevel(WidgetTester tester) async {
      expect(ProgressService.instance.livesLeft, 5);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('exitLevelTitle')), findsOneWidget);
      // Quedarse: la sesión sigue.
      await tester.tap(find.text(tr('exitLevelStay')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('exitLevelTitle')), findsNothing);
      expect(find.textContaining('Pregunta 1 de'), findsOneWidget);
      // Salir: −1 vida y vuelta a Niveles.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(tr('exitLevelLeave')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(ProgressService.instance.livesLeft, 4);
      // De vuelta en Niveles (el título aparece 2 veces: cabecera
      // de la pantalla y etiqueta de la barra inferior).
      expect(find.text(tr('levelsTitle')), findsWidgets);
      expect(find.byType(AppBar), findsOneWidget);
    }

    testWidgets(
        'Nivel: el botón atrás pide confirmar y salir cuesta '
        '1 vida (fix4, punto 5)', (tester) async {
      await pumpHomeScreen(tester);
      // Toca el nodo del Nivel 1 del primer tema: su número es el
      // único texto "1" suelto en la pantalla (la etiqueta "Nivel 1"
      // ya no existe, §3.2.2).
      await tester.tap(find.text('1').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Pregunta 1 de'), findsOneWidget);
      await checkBackWarningLevel(tester);
    });

    testWidgets('en un repaso se ocultan AppBar y navbar; las opciones se leen',
        (tester) async {
      await pumpHomeScreen(tester);
      // Un error real del banco, para que el repaso tenga variantes.
      final q = allQuestions
          .firstWhere((element) => element.topic == 'estequiometria');
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
      // Sesión activa: sin AppBar ni navbar; sí botón X de salida.
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(MainBottomNav), findsNothing);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.textContaining('Pregunta 1 de'), findsOneWidget);
      // Las opciones se leen: el color del texto no es blanco.
      for (final e in find.byType(ElevatedButton).evaluate()) {
        final b = e.widget as ElevatedButton;
        final fg = b.style?.foregroundColor?.resolve(<WidgetState>{});
        if (fg != null) expect(fg, isNot(Colors.white));
      }
      // Salir del repaso es directo (no es un nivel) y la barra vuelve.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(MainBottomNav), findsOneWidget);
    });

    testWidgets(
        'Examen con tiempo: el botón atrás avisa sin pérdida de vida (fix4, punto 5)',
        (tester) async {
      await pumpPushable(tester, const TimedExamScreen());
      await tester.tap(find.text(tr('timedStart')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Pregunta 1'), findsOneWidget);
      await checkBackWarningNoLives(tester);
    });

    testWidgets(
        'Cuestionario de laboratorio: el botón atrás avisa sin pérdida de vida (fix4, punto 5)',
        (tester) async {
      await pumpPushable(tester, const LabQuizPage());
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Pregunta 1 de'), findsOneWidget);
      await checkBackWarningNoLives(tester);
    });

    testWidgets(
        'Quiz de la tabla: el botón atrás avisa sin pérdida de vida (fix4, punto 5)',
        (tester) async {
      await pumpPushable(tester, const TableQuizScreen());
      await tester.pump(const Duration(milliseconds: 300));
      await checkBackWarningNoLives(tester);
    });
  });

  group('LucideIcon no se estira (auditoría)', () {
    // El hueco que le da el padre PUEDE estirarse (un Column con
    // stretch o el slot del prefixIcon): lo que no puede estirarse
    // es el GLIFO. El pintor dibuja siempre al tamaño nominal,
    // centrado. Se comprueba que el CustomPaint lleva el tamaño
    // nominal; el píxel se verifica en las previews (drawer, Tabla).
    testWidgets('en un Column con stretch el glifo sigue a 24', (tester) async {
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
          tester
              .widget<CustomPaint>(
                  find.descendant(of: icon, matching: find.byType(CustomPaint)))
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
                prefixIcon: const LucideIcon(LucideIcons.search, size: 18),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final icon = lucide(LucideIcons.search);
      expect(icon, findsOneWidget);
      expect(
          tester
              .widget<CustomPaint>(
                  find.descendant(of: icon, matching: find.byType(CustomPaint)))
              .size,
          const Size(18, 18));
    });
  });
}

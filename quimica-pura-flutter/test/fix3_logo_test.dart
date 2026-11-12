// Pruebas de la ronda fix3 2026-11-10 (punto 6: logos de las
// gemelas gigantes / cuadrados marrones): el logo ya no se muestra
// cuadrado con las muñequitas diminutas, sino panorámico y
// recortado a la banda de las gemelas, sin deformar; los avatares
// de Brenda/Britany siguen cuadrados (foto cuadrada sobre marco
// cuadrado, sin estirar).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/constants_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/brand_logo.dart';
import 'package:quimica_pura/widgets/lucide_icons.dart';
import 'package:quimica_pura/widgets/main_bottom_nav.dart';
import 'package:quimica_pura/widgets/twin_avatars.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRobotoFonts);

  group('BrandLogo (fix3, punto 6)', () {
    testWidgets('panorámico: alto = 0.40 x ancho, no cuadrado',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: BrandLogo(size: 100)),
          ),
        ),
      );
      await tester.pump();
      final size = tester.getSize(find.byType(BrandLogo));
      expect(size.width, 100);
      // 100 x 40: la banda de las gemelas, sin el cuadrado marrón.
      expect(size.height, 40);
    });

    testWidgets('onboarding (104) y menú (60) con ese mismo encuadre',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                BrandLogo(size: 104),
                BrandLogo(size: 60),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final logos = tester.getSize(find.byType(BrandLogo).first);
      expect(logos.width, 104);
      expect(logos.height, moreOrLessEquals(104 * 0.40));
      final menu = tester.getSize(find.byType(BrandLogo).last);
      expect(menu.width, 60);
      expect(menu.height, moreOrLessEquals(60 * 0.40));
    });

    testWidgets('el encuadre recorta a la banda de las gemelas',
        (tester) async {
      // Revisión de pulido (directriz "lo más lindo posible"):
      // el encuadre panorámico es lo que hace que el logo se vea
      // limpio; si alguien vuelve a poner el cuadrado entero o
      // cambia el recorte, este test lo caza. La banda de las
      // gemelas en el archivo es y 164-318 de 512: con alto 0.40
      // y Alignment(0, -0.10) la ventana visible es y 138-343,
      // o sea las muñecas centradas con ~25 px de margen.
      expect(BrandLogo.aspectHeight, 0.40);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: BrandLogo(size: 100)),
          ),
        ),
      );
      await tester.pump();
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.cover);
      expect(image.alignment, const Alignment(0, -0.10));
      final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clip.borderRadius, BorderRadius.circular(10));
    });
  });

  group('AppBar limpia (fix3, punto 6)', () {
    testWidgets('sin título y sin sol/luna; solo controles',
        (tester) async {
      // Revisión de pulido: la barra limpia es solo controles.
      // Si alguien vuelve a poner el título (se recortaba) o el
      // botón de tema (vive solo en Cuenta), este test lo caza.
      SharedPreferences.setMockInitialValues({});
      await ProgressService.load();
      UserPrefs.rulesSeenV6 = true;
      addTearDown(() => UserPrefs.rulesSeenV6 = false);
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
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.title, isNull);
      Finder inAppBar(LucideIconData icon) => find.descendant(
            of: find.byType(AppBar),
            matching: find.byWidgetPredicate(
                (w) => w is LucideIcon && w.icon == icon),
          );
      expect(inAppBar(LucideIcons.sun), findsNothing);
      expect(inAppBar(LucideIcons.moon), findsNothing);
      expect(inAppBar(LucideIcons.cloud), findsNothing);
      expect(inAppBar(LucideIcons.menu), findsOneWidget);
      expect(inAppBar(LucideIcons.bell), findsOneWidget);
      expect(inAppBar(LucideIcons.rotateCcw), findsOneWidget);
    });
  });

  group('Avatares de las gemelas (fix3, punto 6)', () {
    testWidgets('Brenda y Britany: cuadrados, sin deformar',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                TwinAvatarA(size: 40),
                TwinAvatarB(size: 36),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.getSize(find.byType(TwinAvatarA)),
          const Size(40, 40));
      expect(tester.getSize(find.byType(TwinAvatarB)),
          const Size(36, 36));
    });

    testWidgets('la burbuja del quiz usa el avatar de 52 por defecto',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MascotBubble(twinA: true, text: '¡Hola!'),
          ),
        ),
      );
      await tester.pump();
      // La burbuja ya no construye TwinAvatarA/B directamente
      // (punto 11: tercer compañero Kristian): construye el
      // CompanionAvatar genérico, con el mismo tamaño 52.
      expect(tester.getSize(find.byType(CompanionAvatar)),
          const Size(52, 52));
    });
  });

  group('Iconos de campos: Constantes y conversiones (fix3, punto 6)', () {
    testWidgets('el icono del campo Valor mide 24 px, no el campo entero',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ConstantsScreen()),
      );
      await tester.pump();
      // El conversor está debajo del pliegue (la lista de
      // constantes ocupa la primera pantalla): se desplaza hasta
      // el campo Valor para que se construya.
      final login = find.byWidgetPredicate((w) =>
          w is LucideIcon && w.icon == LucideIcons.logIn);
      await tester.scrollUntilVisible(login, 300);
      await tester.pump();
      expect(login, findsOneWidget);
      // Se mide el GLIFO (el CustomPaint), no la caja exterior:
      // el hueco del prefixIcon mide 48 por especificación de
      // Material, pero el glifo dibujado es de 24 (auditoría fix2,
      // grupo 'LucideIcon no se estira'). Eso es lo que se veía
      // gigante en la captura: el glifo llenaba el campo.
      Size glyphSize(Finder iconFinder) => tester
          .widget<CustomPaint>(find.descendant(
              of: iconFinder, matching: find.byType(CustomPaint)))
          .size;
      expect(glyphSize(login), const Size(24, 24));
      // Flecha entre los desplegables De/A: glifo de 24.
      final arrow = find.byWidgetPredicate((w) =>
          w is LucideIcon && w.icon == LucideIcons.arrowRight);
      expect(arrow, findsOneWidget);
      expect(glyphSize(arrow), const Size(24, 24));
      // Flechas de los desplegables De/A (icono por defecto
      // de Flutter): tamaño nominal 24, acorde al texto.
      final drops = find.byIcon(Icons.arrow_drop_down);
      expect(drops, findsNWidgets(2));
      expect(tester.widget<Icon>(drops.at(0)).size ?? 24, 24);
      expect(tester.widget<Icon>(drops.at(1)).size ?? 24, 24);
    });
  });

  group('Iconos 3D (fix3, punto 6)', () {
    test('threeDGradient: más claro arriba, color base abajo',
        () {
      // El patrón del corazón de las vidas (coral claro arriba,
      // coral base abajo) generalizado a cada acento: nadie sale
      // todo coral.
      for (final accent in [
        const Color(0xFF00C2A8), // teal de la app
        const Color(0xFF8B5CF6), // violeta
        const Color(0xFFF59E0B), // ámbar
      ]) {
        final g = LucideIcon.threeDGradient(accent);
        expect(g.colors[1], accent);
        final top = HSLColor.fromColor(g.colors[0]);
        final base = HSLColor.fromColor(accent);
        expect(top.lightness, greaterThan(base.lightness));
      }
    });

    testWidgets('3D no cambia el tamaño ni rellena un icono de trazo',
        (tester) async {
      // El reloj conserva sus manecillas: 3D sin `filled` pinta
      // el degradado en el TRAZO, no un disco sólido. Y el glifo
      // sigue midiendo su tamaño nominal aunque el padre estire
      // (auditoría fix2).
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LucideIcon(LucideIcons.timer,
                    size: 28,
                    color: Color(0xFF00C2A8),
                    threeD: true),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final icon =
          tester.widget<LucideIcon>(find.byType(LucideIcon));
      expect(icon.threeD, isTrue);
      expect(icon.filled, isFalse);
      final glyph = tester.widget<CustomPaint>(
          find.descendant(
              of: find.byType(LucideIcon),
              matching: find.byType(CustomPaint)));
      expect(glyph.size, const Size(28, 28));
    });

    testWidgets(
        'barra inferior: círculo central sólido y plano (sin anillo ni 3D), las demás pestañas planas',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await ProgressService.load();
      UserPrefs.rulesSeenV6 = true;
      addTearDown(() => UserPrefs.rulesSeenV6 = false);
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
      bool is3D(LucideIconData data) => tester
          .widgetList<LucideIcon>(find.byWidgetPredicate(
              (w) => w is LucideIcon && w.icon == data))
          .any((w) => w.threeD);
      // Niveles (índice 2) está activa: es el círculo central
      // sólido teal + labio (rediseño Duolingo §3.1, Zona A: sin
      // degradado, sin anillo brillante) con el icono de ruta en
      // blanco, plano (no 3D). La clave del centro es
      // 'nav-center-levels' (la antigua 'nav-center-ring' era
      // del anillo del diseño anterior, ya eliminado).
      expect(find.byKey(const ValueKey('nav-center-levels')),
          findsOneWidget);
      final routeInNav = find.descendant(
        of: find.byType(MainBottomNav),
        matching: find.byWidgetPredicate(
            (w) => w is LucideIcon && w.icon == LucideIcons.route),
      );
      expect(routeInNav, findsOneWidget);
      expect(tester.widget<LucideIcon>(routeInNav).color, Colors.white);
      expect(tester.widget<LucideIcon>(routeInNav).threeD, isFalse);
      // Las demás pestañas siguen planas y grises.
      expect(is3D(LucideIcons.calculator), isFalse);
      expect(is3D(LucideIcons.bookOpen), isFalse);
      expect(is3D(LucideIcons.layoutGrid), isFalse);
      expect(is3D(LucideIcons.userRound), isFalse);
    });

    testWidgets('menú: iconos principales planos, flecha plana', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await ProgressService.load();
      UserPrefs.rulesSeenV6 = true;
      addTearDown(() => UserPrefs.rulesSeenV6 = false);
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
      await tester.tap(find.byTooltip(tr('menuWord')));
      // Sin pumpAndSettle: el corazón de las vidas late sin parar
      // y el settle nunca termina (patrón de los tests fix2).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Rediseño Duolingo (§3.15, Zona A): las filas del menú son
      // planas — el icono va en un círculo tintado, sin 3D ni
      // degradado; la flechita de la derecha sigue plana.
      // Quemia 7.0: hay DOS iconos de red en el menú (Ramas y
      // Grupos de estudio); los dos son planos ahora.
      final networks = tester.widgetList<LucideIcon>(
          find.byWidgetPredicate((w) =>
              w is LucideIcon && w.icon == LucideIcons.network));
      expect(networks.length, 2);
      expect(networks.every((w) => !w.threeD), isTrue);
      final chevron = find.byWidgetPredicate(
          (w) => w is LucideIcon && w.icon == LucideIcons.chevronRight);
      expect(chevron, findsWidgets);
      expect(
          tester
              .widgetList<LucideIcon>(chevron)
              .every((w) => !w.threeD),
          isTrue);
    });
  });
}

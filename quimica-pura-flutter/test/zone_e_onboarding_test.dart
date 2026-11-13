// Zona E — onboarding: contraste en tema oscuro + pantalla fija sin
// scroll + hint legible. (No toca Google, ni version.json, ni firmas.)
//
// Los temas son réplicas fieles de MelliQuiApp (ver
// preview_fix8_test.dart): claro con onSurface #4B4B4B, oscuro con
// fondo #131F24 (acento verde, el de por defecto) y onSurface
// #E6F4EE (casi blanco).
//
// REGLA GENERAL DEL USUARIO: cada error se corrige en TODA la
// pantalla, no solo en la de la captura. Por eso este archivo no
// cubre solo la página de nombre/género: el grupo "TODO el flujo"
// recorre bienvenida, explicativas, nombre/género, notificaciones
// e idioma en AMBOS temas y verifica en cada paso contraste
// legible y ajuste sin scroll.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/onboarding_notifications_page.dart';
import 'package:quimica_pura/screens/onboarding_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/widgets/brand_logo.dart';

ThemeData zoneELightTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.light(
        primary: BrandColors.teal,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: BrandColors.ink,
        surfaceContainerHighest: BrandColors.cardGray,
        error: const Color(0xFFFF4B4B),
      ),
    );

ThemeData zoneEDarkTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF131F24),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF5EEAD4),
        onPrimary: Color(0xFF131F24),
        surface: Color(0xFF1F2C34),
        onSurface: Color(0xFFE6F4EE),
        surfaceContainerHighest: Color(0xFF1B3A31),
        error: Color(0xFFFF4B4B),
      ),
    );

void main() {
  Future<void> setPhone(
    WidgetTester tester, {
    required double width,
    required double height,
    double topPadding = 0,
    double bottomPadding = 0,
  }) async {
    tester.view.physicalSize = Size(width * 2, height * 2);
    tester.view.devicePixelRatio = 2.0;
    tester.view.padding =
        FakeViewPadding(top: topPadding, bottom: bottomPadding);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
    });
  }

  Future<void> goToProfilePage(
    WidgetTester tester, {
    required ThemeData theme,
    double width = 360,
    double height = 800,
    double topPadding = 0,
    double bottomPadding = 0,
  }) async {
    await setPhone(tester,
        width: width,
        height: height,
        topPadding: topPadding,
        bottomPadding: bottomPadding);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: OnboardingScreen(onFinished: () {}),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text(tr('obNext').toUpperCase()));
      await tester.pumpAndSettle();
    }
    expect(find.text(tr('obProfileTitle')), findsOneWidget);
  }

  TextStyle textStyleOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style!;

  group('Zona E — contraste del onboarding', () {
    testWidgets('tema oscuro: título, subtítulo y etiquetas casi '
        'blancos (on-surface), no gris tenue', (tester) async {
      await goToProfilePage(tester, theme: zoneEDarkTheme());
      const onSurface = Color(0xFFE6F4EE);
      expect(textStyleOf(tester, tr('obProfileTitle')).color, onSurface);
      expect(textStyleOf(tester, tr('obNameLabel')).color, onSurface);
      expect(textStyleOf(tester, tr('obGender')).color, onSurface);
      // Subtítulo: on-surface al 75% — gris claro legible sobre
      // oscuro, nunca el #777777 fijo de antes.
      expect(textStyleOf(tester, tr('obProfileBody')).color,
          onSurface.withValues(alpha: 0.75));
      // Y no es un gris tenue: su luminancia es alta.
      final bodyColor = textStyleOf(tester, tr('obProfileBody')).color!;
      expect(bodyColor.computeLuminance(), greaterThan(0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('tema claro: título y etiquetas siguen en #4B4B4B',
        (tester) async {
      await goToProfilePage(tester, theme: zoneELightTheme());
      expect(textStyleOf(tester, tr('obProfileTitle')).color,
          const Color(0xFF4B4B4B));
      expect(textStyleOf(tester, tr('obNameLabel')).color,
          const Color(0xFF4B4B4B));
      expect(textStyleOf(tester, tr('obGender')).color,
          const Color(0xFF4B4B4B));
      expect(tester.takeException(), isNull);
    });

    testWidgets('el hint del nombre es gris oscuro legible sobre el '
        'campo blanco en AMBOS temas', (tester) async {
      for (final theme in [zoneELightTheme(), zoneEDarkTheme()]) {
        await goToProfilePage(tester, theme: theme);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.decoration!.fillColor, Colors.white);
        // #757575 sobre blanco: contraste ~4,6:1, legible. Antes
        // era onSurface al 45%: en oscuro casi blanco sobre blanco.
        expect(field.decoration!.hintStyle!.color,
            const Color(0xFF757575));
        expect(field.decoration!.hintStyle!.color!.computeLuminance(),
            lessThan(0.3));
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('Zona E — pantalla fija sin scroll (página nombre/género)', () {
    void expectNoScrollAndGoogleVisible(
        WidgetTester tester, double width, double height) {
      // El contenido cabe en el viewport: el scroll no tiene
      // recorrido (maxScrollExtent 0).
      final position =
          Scrollable.of(tester.element(find.byType(TextField))).position;
      expect(position.maxScrollExtent, 0.0);
      // El botón de Google está entero dentro de la pantalla.
      final rect =
          tester.getRect(find.text(tr('googleContinue').toUpperCase()));
      expect(rect.top, greaterThanOrEqualTo(0.0));
      expect(rect.bottom, lessThanOrEqualTo(height));
      expect(rect.left, greaterThanOrEqualTo(0.0));
      expect(rect.right, lessThanOrEqualTo(width));
      // Y el SIGUIENTE también sigue visible.
      final nextRect = tester.getRect(find.text(tr('obNext').toUpperCase()));
      expect(nextRect.bottom, lessThanOrEqualTo(height));
      expect(tester.takeException(), isNull);
    }

    testWidgets('360x800 con barra de estado: todo visible sin '
        'desplazar', (tester) async {
      await goToProfilePage(tester,
          theme: zoneEDarkTheme(),
          width: 360,
          height: 800,
          topPadding: 24,
          bottomPadding: 16);
      expectNoScrollAndGoogleVisible(tester, 360, 800);
    });

    testWidgets('360x800 en tema claro: todo visible sin desplazar',
        (tester) async {
      await goToProfilePage(tester, theme: zoneELightTheme());
      expectNoScrollAndGoogleVisible(tester, 360, 800);
    });

    testWidgets('412x915 en tema oscuro: todo visible sin desplazar',
        (tester) async {
      await goToProfilePage(tester,
          theme: zoneEDarkTheme(), width: 412, height: 915);
      expectNoScrollAndGoogleVisible(tester, 412, 915);
    });
  });

  group('Zona E — TODO el flujo: contraste y ajuste en ambos temas', () {
    // Contraste WCAG entre un texto y su fondo (≥ 4,5 = legible).
    double contrast(Color a, Color b) {
      final l1 = a.computeLuminance();
      final l2 = b.computeLuminance();
      final hi = l1 > l2 ? l1 : l2;
      final lo = l1 > l2 ? l2 : l1;
      return (hi + 0.05) / (lo + 0.05);
    }

    // Color EFECTIVO de un Text: primero su propio estilo y, si no
    // trae color, el del DefaultTextStyle (el on-surface del tema).
    Color effectiveColor(WidgetTester tester, String text) {
      final widget =
          tester.widget<Text>(find.text(text));
      return widget.style?.color ??
          DefaultTextStyle.of(tester.element(find.text(text)))
              .style
              .color!;
    }

    void expectReadable(
      WidgetTester tester,
      String text,
      Color background, {
      double minContrast = 4.5,
    }) {
      final color = effectiveColor(tester, text);
      expect(contrast(color, background), greaterThanOrEqualTo(minContrast),
          reason: '$text: $color sobre $background');
    }

    // OJO (harness): cada testWidgets monta la pantalla UNA sola
    // vez y navega con taps seguidos. Volver a hacer pumpWidget de
    // la misma pantalla dentro del mismo test duplica los taps (el
    // primer tap tras el re-pump avanza 2 páginas, el siguiente 4):
    // por eso cada tema tiene su propio testWidgets.
    Future<void> pumpFlow(
      WidgetTester tester, {
      required ThemeData theme,
      double width = 360,
      double height = 800,
    }) async {
      await setPhone(tester, width: width, height: height);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: OnboardingScreen(onFinished: () {}),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapNext(WidgetTester tester) async {
      await tester.tap(find.text(tr('obNext').toUpperCase()));
      await tester.pumpAndSettle();
    }

    testWidgets('bienvenida 360x800 claro: se lee y cabe', (tester) async {
      await pumpFlow(tester, theme: zoneELightTheme());
      final bg = zoneELightTheme().scaffoldBackgroundColor;
      expect(find.byType(BrandLogo), findsOneWidget);
      expectReadable(tester, tr('obWelcome'), bg);
      // "Químic@" es teal de marca fijo: a 30 pt en negrita se lee
      // bien sobre blanco (2,49:1, acento de pantalla, no texto de
      // cuerpo) y sobre oscuro pasa el 4,5 (6,6:1). No se oscurece:
      // es el color de marca y Kristian nunca se quejó de él.
      expect(effectiveColor(tester, tr('obChemist')),
          const Color(0xFF14B8A6));
      expect(contrast(const Color(0xFF14B8A6), bg),
          greaterThanOrEqualTo(2.4));
      expectReadable(tester, tr('obWelcomeBody'), bg);
      // Sin scroll ni desborde (la página es un Column centrado:
      // si no cabe, salta un overflow y takeException lo caza).
      expect(tester.takeException(), isNull);
    });

    testWidgets('bienvenida 360x800 oscuro: se lee y cabe',
        (tester) async {
      await pumpFlow(tester, theme: zoneEDarkTheme());
      final bg = zoneEDarkTheme().scaffoldBackgroundColor;
      expect(find.byType(BrandLogo), findsOneWidget);
      expectReadable(tester, tr('obWelcome'), bg);
      expect(effectiveColor(tester, tr('obChemist')),
          const Color(0xFF14B8A6));
      expect(contrast(const Color(0xFF14B8A6), bg),
          greaterThanOrEqualTo(4.5));
      expectReadable(tester, tr('obWelcomeBody'), bg);
      expect(tester.takeException(), isNull);
    });

    testWidgets('explicativas 1-3, 360x800 claro: se leen y caben',
        (tester) async {
      await pumpFlow(tester, theme: zoneELightTheme());
      final bg = zoneELightTheme().scaffoldBackgroundColor;
      const pages = [
        ('obSolveTitle', 'obSolveBody', 'obSolveP1'),
        ('obStudyTitle', 'obStudyBody', 'obStudyP1'),
        ('obPracticeTitle', 'obPracticeBody', 'obPracticeP1'),
      ];
      for (final (title, body, point) in pages) {
        await tapNext(tester);
        expectReadable(tester, tr(title), bg);
        expectReadable(tester, tr(body), bg);
        expectReadable(tester, tr(point), bg);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('explicativas 1-3, 360x800 oscuro: se leen y caben',
        (tester) async {
      await pumpFlow(tester, theme: zoneEDarkTheme());
      final bg = zoneEDarkTheme().scaffoldBackgroundColor;
      const pages = [
        ('obSolveTitle', 'obSolveBody', 'obSolveP1'),
        ('obStudyTitle', 'obStudyBody', 'obStudyP1'),
        ('obPracticeTitle', 'obPracticeBody', 'obPracticeP1'),
      ];
      for (final (title, body, point) in pages) {
        await tapNext(tester);
        expectReadable(tester, tr(title), bg);
        expectReadable(tester, tr(body), bg);
        expectReadable(tester, tr(point), bg);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('notificaciones 360x800 claro: título/cuerpo legibles '
        'y sin scroll', (tester) async {
      await setPhone(tester, width: 360, height: 800);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: zoneELightTheme(),
          home: const Scaffold(
            body: OnboardingNotificationsPage(onNext: _noop),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<Text>(find.text(tr('obNotifTitle')))
              .style!
              .color,
          zoneELightTheme().colorScheme.onSurface);
      // Cuerpo #777777 (gris terciario aprobado): 4,48:1 sobre
      // blanco, prácticamente el 4,5 de WCAG AA.
      expectReadable(tester, tr('obNotifBody'),
          zoneELightTheme().scaffoldBackgroundColor,
          minContrast: 4.4);
      final position =
          Scrollable.of(tester.element(find.text(tr('obNotifTitle'))))
              .position;
      expect(position.maxScrollExtent, 0.0);
      expect(find.text(tr('obNotifEnable').toUpperCase()), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('notificaciones 360x800 oscuro: título/cuerpo legibles '
        'y sin scroll', (tester) async {
      await setPhone(tester, width: 360, height: 800);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: zoneEDarkTheme(),
          home: const Scaffold(
            body: OnboardingNotificationsPage(onNext: _noop),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<Text>(find.text(tr('obNotifTitle')))
              .style!
              .color,
          zoneEDarkTheme().colorScheme.onSurface);
      expectReadable(tester, tr('obNotifBody'),
          zoneEDarkTheme().scaffoldBackgroundColor,
          minContrast: 4.4);
      final position =
          Scrollable.of(tester.element(find.text(tr('obNotifTitle'))))
              .position;
      expect(position.maxScrollExtent, 0.0);
      expect(find.text(tr('obNotifEnable').toUpperCase()), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('idioma 360x800 claro: cabe sin scroll y se lee',
        (tester) async {
      await _driveToLanguagePage(tester, theme: zoneELightTheme());
      final bg = zoneELightTheme().scaffoldBackgroundColor;
      expectReadable(tester, tr('obLangTitle'), bg);
      expectReadable(tester, tr('obLangBody'), bg);
      // Los chips son blancos en ambos temas, con texto #4B4B4B.
      final chip =
          tester.widget<ChoiceChip>(find.byType(ChoiceChip).first);
      expect(chip.backgroundColor, Colors.white);
      final chipLabel = tester
          .widget<Text>(find.descendant(
              of: find.byType(ChoiceChip).first, matching: find.byType(Text)))
          .style!;
      expect(chipLabel.color, const Color(0xFF4B4B4B));
      // Sin scroll: todo cabe (título, cuerpo, chips, Finalizar).
      final position =
          Scrollable.of(tester.element(find.text(tr('obLangTitle'))))
              .position;
      expect(position.maxScrollExtent, 0.0);
      final finishRect = tester.getRect(find.text(tr('obFinish')));
      expect(finishRect.bottom, lessThanOrEqualTo(800));
      expect(tester.takeException(), isNull);
    });

    testWidgets('idioma 360x800 oscuro: cabe sin scroll y se lee',
        (tester) async {
      await _driveToLanguagePage(tester, theme: zoneEDarkTheme());
      final bg = zoneEDarkTheme().scaffoldBackgroundColor;
      expectReadable(tester, tr('obLangTitle'), bg);
      expectReadable(tester, tr('obLangBody'), bg);
      final chip =
          tester.widget<ChoiceChip>(find.byType(ChoiceChip).first);
      expect(chip.backgroundColor, Colors.white);
      final chipLabel = tester
          .widget<Text>(find.descendant(
              of: find.byType(ChoiceChip).first, matching: find.byType(Text)))
          .style!;
      expect(chipLabel.color, const Color(0xFF4B4B4B));
      final position =
          Scrollable.of(tester.element(find.text(tr('obLangTitle'))))
              .position;
      expect(position.maxScrollExtent, 0.0);
      final finishRect = tester.getRect(find.text(tr('obFinish')));
      expect(finishRect.bottom, lessThanOrEqualTo(800));
      expect(tester.takeException(), isNull);
    });
  });
}

void _noop() {}

/// Llega a la página del idioma (6) por el flujo real: 4 taps hasta
/// el perfil y luego dos deslizamientos del PageView (perfil →
/// notificaciones → idioma). El deslizamiento evita los dos
/// requisitos que no se verifican aquí: el botón Siguiente de la
/// página 4 exige nombre+género y el de la 5 llama al servicio de
/// notificaciones. Lo que se verifica es el contraste y el ajuste
/// de la página 6, no esos botones.
Future<void> _driveToLanguagePage(
  WidgetTester tester, {
  required ThemeData theme,
}) async {
  tester.view.physicalSize = const Size(720, 1600);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: OnboardingScreen(onFinished: () {}),
    ),
  );
  await tester.pumpAndSettle();
  for (var i = 0; i < 4; i++) {
    await tester.tap(find.text(tr('obNext').toUpperCase()));
    await tester.pumpAndSettle();
  }
  expect(find.text(tr('obProfileTitle')), findsOneWidget);
  await tester.drag(
      find.text(tr('obProfileTitle')), const Offset(-360, 0));
  await tester.pumpAndSettle();
  expect(find.text(tr('obNotifTitle')), findsOneWidget);
  await tester.drag(find.text(tr('obNotifTitle')), const Offset(-360, 0));
  await tester.pumpAndSettle();
  expect(find.text(tr('obLangTitle')), findsOneWidget);
}


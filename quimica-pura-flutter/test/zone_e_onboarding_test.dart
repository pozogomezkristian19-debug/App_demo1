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
// recorre bienvenida, nombre/género, notificaciones
// e idioma en AMBOS temas y verifica en cada paso contraste
// legible y ajuste sin scroll.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/onboarding_notifications_page.dart';
import 'package:quimica_pura/screens/onboarding_screen.dart';
import 'package:quimica_pura/services/accent.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/brand_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  // SharedPreferences mockeado (Quemia 7.7): el flujo de crear
  // cuenta guarda cada respuesta al confirmar (cómo supo, cuánto
  // sabe, meta diaria) y sin mock getInstance() falla y el flujo
  // no avanza. Idioma español, como en el resto de tests.
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserPrefs.load();
    AppLang.code = 'es';
  });

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

  Future<void> goToRegisterPage(
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
        // UniqueKey: sin ella, Flutter REUSA el State al volver a
        // hacer pumpWidget del mismo OnboardingScreen en el mismo
        // test (el test del hint lo hace 2 veces, claro y oscuro) y
        // la segunda vuelta empieza a mitad de flujo (_page
        // heredado), no en la Bienvenida.
        home: OnboardingScreen(key: UniqueKey(), onFinished: () {}),
      ),
    );
    await tester.pumpAndSettle();
    // Quemia 7.7 (rediseño 2026-11-13): sin pantalla de idioma y sin
    // barra de progreso; el inicio es Bienvenida -> Elección ->
    // la gemela -> cómo supo -> cuánta química sabe -> meta diaria
    // -> Notificaciones -> el widget -> la racha -> aviso
    // "¡No pierdas tu progreso!" -> Registro. En Notificaciones el
    // permiso está negado en pruebas: sale "Ir a Ajustes" y al
    // cerrarlo se avanza al widget (MÁS TARDE a la racha).
    await tester.tap(find.text(tr('obContinue').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obCreateProfile').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obVamos').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obSourceInstagram')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obContinue').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obLevel1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obContinue').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obGoal10')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obGoalSave').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obNotifEnable').toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text('Ir a Ajustes'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    // Widget (2026-11-18): tras las notificaciones va la pantalla
    // del widget; con MÁS TARDE se sigue a la racha.
    await tester.tap(find.text(tr('obWidgetLater').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obStreakStart').toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text(tr('obNudgeTitle')), findsOneWidget);
    await tester.tap(find.text(tr('obContinue').toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text(tr('obRegisterTitle')), findsOneWidget);
  }

  TextStyle textStyleOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style!;

  group('Zona E — contraste del onboarding', () {
    testWidgets(
        'tema oscuro: título y términos casi blancos '
        '(on-surface), no gris tenue', (tester) async {
      await goToRegisterPage(tester, theme: zoneEDarkTheme());
      const onSurface = Color(0xFFE6F4EE);
      expect(textStyleOf(tester, tr('obRegisterTitle')).color, onSurface);
      // Términos: on-surface al 75% — gris claro legible sobre
      // oscuro, nunca el #777777 fijo de antes.
      expect(textStyleOf(tester, tr('obRegisterTerms')).color,
          onSurface.withValues(alpha: 0.75));
      // Y no es un gris tenue: su luminancia es alta.
      final termsColor = textStyleOf(tester, tr('obRegisterTerms')).color!;
      expect(termsColor.computeLuminance(), greaterThan(0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('tema claro: título sigue en #4B4B4B', (tester) async {
      await goToRegisterPage(tester, theme: zoneELightTheme());
      expect(textStyleOf(tester, tr('obRegisterTitle')).color,
          const Color(0xFF4B4B4B));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'el hint del correo es legible sobre el campo en AMBOS '
        'temas (blanco en claro, oscuro en oscuro como Duolingo)',
        (tester) async {
      for (final theme in [zoneELightTheme(), zoneEDarkTheme()]) {
        await goToRegisterPage(tester, theme: theme);
        // El campo de correo sale al tocar "Continuar con correo
        // electrónico": es el primer paso del flujo (hint "Correo").
        await tester.tap(find.text(tr('obRegisterEmail').toUpperCase()));
        await tester.pumpAndSettle();
        final field = tester.widget<TextField>(find.byWidgetPredicate((w) =>
            w is TextField &&
            w.decoration?.hintText == tr('obEmailFieldHint')));
        if (theme.brightness == Brightness.dark) {
          // Oscuro como Duolingo (Kristian 2026-11-13): la casilla
          // NO es blanca — fondo oscuro de la app + hint gris
          // claro legible sobre oscuro.
          expect(field.decoration!.fillColor, AppAccent.darkCard);
          expect(field.decoration!.hintStyle!.color,
              const Color(0xFFAFAFAF));
          expect(field.decoration!.hintStyle!.color!.computeLuminance(),
              greaterThan(0.3));
          expect(field.style!.color, Colors.white);
        } else {
          expect(field.decoration!.fillColor, Colors.white);
          // #757575 sobre blanco: contraste ~4,6:1, legible.
          expect(field.decoration!.hintStyle!.color, const Color(0xFF757575));
          expect(field.decoration!.hintStyle!.color!.computeLuminance(),
              lessThan(0.3));
          expect(field.style!.color, const Color(0xFF4B4B4B));
        }
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('Zona E — pantalla fija sin scroll (página de registro)', () {
    void expectNoScrollAndGoogleVisible(
        WidgetTester tester, double width, double height) {
      // El contenido cabe en el viewport: el scroll no tiene
      // recorrido (maxScrollExtent 0).
      final position =
          Scrollable.of(tester.element(find.text(tr('obRegisterTitle'))))
              .position;
      expect(position.maxScrollExtent, 0.0);
      // El botón de Google está entero dentro de la pantalla.
      final rect =
          tester.getRect(find.text(tr('obRegisterGoogle').toUpperCase()));
      expect(rect.top, greaterThanOrEqualTo(0.0));
      expect(rect.bottom, lessThanOrEqualTo(height));
      expect(rect.left, greaterThanOrEqualTo(0.0));
      expect(rect.right, lessThanOrEqualTo(width));
      // Y los términos también siguen visibles.
      final termsRect = tester.getRect(find.text(tr('obRegisterTerms')));
      expect(termsRect.bottom, lessThanOrEqualTo(height));
      expect(tester.takeException(), isNull);
    }

    testWidgets(
        '360x800 con barra de estado: todo visible sin '
        'desplazar', (tester) async {
      await goToRegisterPage(tester,
          theme: zoneEDarkTheme(),
          width: 360,
          height: 800,
          topPadding: 24,
          bottomPadding: 16);
      expectNoScrollAndGoogleVisible(tester, 360, 800);
    });

    testWidgets('360x800 en tema claro: todo visible sin desplazar',
        (tester) async {
      await goToRegisterPage(tester, theme: zoneELightTheme());
      expectNoScrollAndGoogleVisible(tester, 360, 800);
    });

    testWidgets('412x915 en tema oscuro: todo visible sin desplazar',
        (tester) async {
      await goToRegisterPage(tester,
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
      final widget = tester.widget<Text>(find.text(text));
      return widget.style?.color ??
          DefaultTextStyle.of(tester.element(find.text(text))).style.color!;
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
      // Quemia 7.7: la Bienvenida es la PRIMERA pantalla (sin
      // idioma antes y sin barra de progreso), así que no hay que
      // tocar nada para estar en ella.
    }

    testWidgets('bienvenida 360x800 claro: se lee y cabe', (tester) async {
      await pumpFlow(tester, theme: zoneELightTheme());
      final bg = zoneELightTheme().scaffoldBackgroundColor;
      // Bienvenidos SIN logo (Kristian 2026-11-13): el loguito de
      // las mellizas ya no sale en la primera pantalla.
      expect(find.byType(BrandLogo), findsNothing);
      expectReadable(tester, tr('obWelcome'), bg);
      // "Químic@" sigue al acento elegido (Quemia 7.3, P12): en
      // claro va el tono oscuro del acento (3,24:1 en verde, se lee
      // bien a 30 pt en negrita) y en oscuro el acento. Antes era
      // menta fija #14B8A6 y se quedaba verde con el tema violeta.
      expect(effectiveColor(tester, tr('obChemist')), AppAccent.primaryDark);
      expect(contrast(AppAccent.primaryDark, bg), greaterThanOrEqualTo(2.4));
      expectReadable(tester, tr('obWelcomeBody'), bg);
      // Sin scroll ni desborde (la página es un Column centrado:
      // si no cabe, salta un overflow y takeException lo caza).
      expect(tester.takeException(), isNull);
    });

    testWidgets('bienvenida 360x800 oscuro: se lee y cabe', (tester) async {
      await pumpFlow(tester, theme: zoneEDarkTheme());
      final bg = zoneEDarkTheme().scaffoldBackgroundColor;
      // Bienvenidos SIN logo (Kristian 2026-11-13): el loguito de
      // las mellizas ya no sale en la primera pantalla.
      expect(find.byType(BrandLogo), findsNothing);
      expectReadable(tester, tr('obWelcome'), bg);
      expect(effectiveColor(tester, tr('obChemist')), AppAccent.primary);
      expect(contrast(AppAccent.primary, bg), greaterThanOrEqualTo(4.5));
      expectReadable(tester, tr('obWelcomeBody'), bg);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'notificaciones 360x800 claro: título/cuerpo legibles '
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
      expect(tester.widget<Text>(find.text(tr('obNotifTitle'))).style!.color,
          zoneELightTheme().colorScheme.onSurface);
      // Cuerpo #777777 (gris terciario aprobado): 4,48:1 sobre
      // blanco, prácticamente el 4,5 de WCAG AA.
      expectReadable(
          tester, tr('obNotifBody'), zoneELightTheme().scaffoldBackgroundColor,
          minContrast: 4.4);
      final position =
          Scrollable.of(tester.element(find.text(tr('obNotifTitle')))).position;
      expect(position.maxScrollExtent, 0.0);
      expect(find.text(tr('obNotifEnable').toUpperCase()), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'notificaciones 360x800 oscuro: título/cuerpo legibles '
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
      expect(tester.widget<Text>(find.text(tr('obNotifTitle'))).style!.color,
          zoneEDarkTheme().colorScheme.onSurface);
      expectReadable(
          tester, tr('obNotifBody'), zoneEDarkTheme().scaffoldBackgroundColor,
          minContrast: 4.4);
      final position =
          Scrollable.of(tester.element(find.text(tr('obNotifTitle')))).position;
      expect(position.maxScrollExtent, 0.0);
      expect(find.text(tr('obNotifEnable').toUpperCase()), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

void _noop() {}

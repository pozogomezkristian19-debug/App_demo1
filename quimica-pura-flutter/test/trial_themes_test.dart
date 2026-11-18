// Los 5 cambios en TODOS los temas (Kristian 2026-11-15 23:42):
// claro/oscuro × verde/violeta. La prueba, la imagen de agregar
// amigo, el paywall, la tarjeta de contraseña y la ausencia del
// diamante se comprueban en las 4 combinaciones: que todo se
// pinte, que el texto se lea (contraste WCAG ≥ 4,5 en los textos
// de los cambios) y que nada se rompa al cambiar de tema.
//
// Los colores se leen del widget real (no del diseño en papel):
// el color del Text, el fondo de la tarjeta y el acento activo.
// El precio de los planes va en el color del acento, oscurecido
// en claro hasta contraste ≥ 3,0 (Kristian 2026-11-16: el teal
// sobre blanco daba 2,26); en claro+violeta ya daba 4,23 y se
// queda, y en oscuro el acento ya pasa y tampoco cambia.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/account_screen.dart';
import 'package:quimica_pura/screens/friends_screen.dart';
import 'package:quimica_pura/screens/premium_paywall_screen.dart';
import 'package:quimica_pura/services/accent.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/auth_service.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/premium_service.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/social_service.dart';
import 'package:quimica_pura/services/trial.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/lucide_icons.dart';
import 'package:quimica_pura/widgets/trial_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

/// Las 4 combinaciones: (oscuro, acento).
const _combos = [
  (false, 'verde'),
  (false, 'violeta'),
  (true, 'verde'),
  (true, 'violeta'),
];

String _comboName(bool dark, String accent) =>
    '${dark ? 'oscuro' : 'claro'}+$accent';

/// Contraste WCAG entre dos colores opacos.
double _luminance(Color c) {
  double lin(int v) {
    final x = v / 255;
    return x <= 0.04045
        ? x / 12.92
        : math.pow((x + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * lin((c.r * 255.0).round()) +
      0.7152 * lin((c.g * 255.0).round()) +
      0.0722 * lin((c.b * 255.0).round());
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Color que se ve al pintar [fg] con opacidad [alpha] sobre [bg].
Color _onTop(Color fg, double alpha, Color bg) =>
    Color.alphaBlend(fg.withValues(alpha: alpha), bg);

void main() {
  late InMemorySocialRepository repo;

  // La Roboto REAL (sin ella el texto mide más ancho y las
  // tarjetas se desbordan en el test aunque en la app no).
  setUpAll(loadRobotoFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    UserPrefs.userName = 'kristian';
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    // OJO con el orden: PremiumService.resetForTests() llama a
    // TrialService.resetForTests().
    PremiumService.resetForTests();
    TrialService.resetForTests();
    AnalyticsSync.resetForTests();
    repo = InMemorySocialRepository(seedDemo: true);
    SocialService.setRepositoryForTests(repo);
    addTearDown(() {
      TrialService.instance.stop();
      TrialService.resetForTests();
      PremiumService.resetForTests();
      AuthService.resetForTests();
      SocialService.resetForTests();
      AnalyticsSync.resetForTests();
      UserPrefs.userName = '';
      UserPrefs.themeAccent = 'verde';
      UserPrefs.themeAccentNotifier.value = 'verde';
    });
  });

  /// MaterialApp con el tema de la combinación (brillo + acento).
  /// El fondo es el real de la app: blanco en claro,
  /// AppAccent.darkBackground en oscuro (sigue al acento).
  Future<void> pumpThemed(
    WidgetTester tester,
    Widget child, {
    required bool dark,
    required String accent,
    Size size = const Size(360, 800),
  }) async {
    UserPrefs.themeAccent = accent;
    UserPrefs.themeAccentNotifier.value = accent;
    tester.view.physicalSize = Size(size.width * 2, size.height * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: dark ? Brightness.dark : Brightness.light,
          useMaterial3: true,
          scaffoldBackgroundColor:
              dark ? AppAccent.darkBackground : Colors.white,
        ),
        home: Scaffold(body: child),
      ),
    );
    await tester.pump();
    // MaterialApp anima el cambio de tema (AnimatedTheme, ~200 ms):
    // a los 100 ms los colores van a mitad de camino entre el tema
    // viejo y el nuevo; hay que esperar a que termine la animación
    // para medir los colores finales.
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Fondo sobre el que se pinta el aviso (banner/paywall): el
  /// tinte del acento al 10% sobre el fondo de la pantalla.
  Color trialNoticeBg(bool dark) => _onTop(
        AppAccent.primary,
        0.10,
        dark ? AppAccent.darkBackground : Colors.white,
      );

  group('banner de la prueba: legible en los 4 temas', () {
    testWidgets('texto + reloj con el acento, contraste ≥ 4,5',
        (tester) async {
      await TrialService.instance.start();
      for (final (dark, accent) in _combos) {
        // Sin const: con const el widget es idéntico entre
        // combinaciones y el framework no lo reconstruye (es el
        // mismo defecto que se arregló en Niveles/Cuenta).
        await pumpThemed(tester, TrialBanner(),
            dark: dark, accent: accent);
        expect(find.byKey(const ValueKey('trialBanner')), findsOneWidget,
            reason: _comboName(dark, accent));
        final text = tester.widget<Text>(
          find.textContaining('te quedan 3 días'),
        );
        final textColor = text.style!.color!;
        expect(
          _contrast(textColor, trialNoticeBg(dark)),
          greaterThanOrEqualTo(4.5),
          reason: '${_comboName(dark, accent)}: texto del banner',
        );
        final icon = tester.widget<LucideIcon>(find.byType(LucideIcon));
        expect(icon.color, AppAccent.primary,
            reason: '${_comboName(dark, accent)}: reloj con el acento');
        expect(tester.takeException(), isNull);
      }
      // El temporizador de 30 s de la prueba hay que pararlo
      // DENTRO del cuerpo del test: el framework comprueba que
      // no queden temporizadores antes de correr los tearDown.
      TrialService.instance.stop();
    });
  });

  group('paywall: aviso + planes legibles en los 4 temas', () {
    Finder planCardFor(String monthsLabel) {
      final ancestors = find.ancestor(
        of: find.text(monthsLabel),
        matching: find.byType(Card),
      );
      // El título también sale en la tabla comparativa (arriba):
      // la tarjeta del plan es el ÚLTIMO ancestro.
      return ancestors.last;
    }

    testWidgets('aviso, títulos, precios y separación en cada tema',
        (tester) async {
      await TrialService.instance.start();
      for (final (dark, accent) in _combos) {
        await pumpThemed(
          tester,
          // Sin const: si no, el paywall no se reconstruye entre
          // combinaciones y los precios se quedan con el acento
          // viejo (mismo defecto que el banner).
          PremiumPaywallScreen(),
          dark: dark,
          accent: accent,
          size: const Size(400, 2000),
        );
        final name = _comboName(dark, accent);
        // Aviso de prueba con contraste.
        expect(find.byKey(const ValueKey('trialNoticeCard')), findsOneWidget,
            reason: name);
        final noticeText = tester.widget<Text>(
          find.textContaining('te quedan 3 días'),
        );
        expect(
          _contrast(noticeText.style!.color!, trialNoticeBg(dark)),
          greaterThanOrEqualTo(4.5),
          reason: '$name: texto del aviso del paywall',
        );
        // Planes: título con el color de superficie del tema y
        // contraste alto sobre la tarjeta; precio con el acento.
        final cardBg = dark ? AppAccent.darkCard : Colors.white;
        for (final label in ['1 mes', '3 meses', '12 meses']) {
          final card = planCardFor(label);
          expect(card, findsOneWidget, reason: '$name: tarjeta $label');
          final title = tester.widget<Text>(
            find.descendant(of: card, matching: find.text(label)),
          );
          expect(
            _contrast(title.style!.color!, cardBg),
            greaterThanOrEqualTo(4.5),
            reason: '$name: título $label',
          );
          final price = tester.widget<Text>(
            find.descendant(of: card, matching: find.textContaining('CUP')),
          );
          // Precio en el acento, oscurecido en claro hasta
          // contraste ≥ 3,0 sobre la tarjeta (Kristian 2026-11-16).
          expect(price.style!.color, AppAccent.planPriceColor(isDark: dark),
              reason: '$name: precio $label con el color del precio');
          expect(
            _contrast(price.style!.color!, cardBg),
            greaterThanOrEqualTo(3.0),
            reason: '$name: precio $label con contraste ≥ 3,0',
          );
        }
        // Separación entre tarjetas en todos los temas.
        final y1 = tester.getCenter(planCardFor('1 mes')).dy;
        final y3 = tester.getCenter(planCardFor('3 meses')).dy;
        final y12 = tester.getCenter(planCardFor('12 meses')).dy;
        expect(y3 - y1, greaterThan(60), reason: name);
        expect(y12 - y3, greaterThan(60), reason: name);
        // Sin diamante en ningún tema.
        expect(find.byKey(const ValueKey('premiumDiamondFab')), findsNothing,
            reason: name);
        expect(tester.takeException(), isNull);
      }
      // Parar el temporizador dentro del cuerpo (ver banner).
      TrialService.instance.stop();
    });
  });

  group('amigos: la imagen se ve en los 4 temas', () {
    testWidgets('buscar camila: imagen a la derecha, sin errores',
        (tester) async {
      for (final (dark, accent) in _combos) {
        await pumpThemed(
          tester,
          // Sin const: si no, la pantalla conserva el estado (el
          // texto buscado) entre combinaciones.
          FriendsScreen(isGoogleLinked: true),
          dark: dark,
          accent: accent,
          size: const Size(360, 1000),
        );
        final name = _comboName(dark, accent);
        await tester.enterText(
          find.widgetWithText(TextField, tr('friendsSearchHint')),
          'cami',
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        // Prefijo 'cami': la casilla muestra 'cami' y el
        // resultado 'camila' (buscar 'camila' exacto hace que el
        // texto salga dos veces: casilla + resultado).
        expect(find.text('camila'), findsOneWidget, reason: name);
        // La imagen es un PNG con sus propios colores (no depende
        // del tema): lo que se comprueba es que carga en claro y
        // en oscuro, sin error de asset, a la derecha del nombre.
        final image = find.byKey(const ValueKey('addFriendImage-camila'));
        expect(image, findsOneWidget, reason: name);
        final imageWidget = tester.widget<Image>(
          find.descendant(of: image, matching: find.byType(Image)),
        );
        expect(imageWidget.image, isA<AssetImage>(), reason: name);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('cuenta: tarjeta compacta + banner de prueba en los 4 temas', () {
    testWidgets('compacta, separada y legible en cada tema',
        (tester) async {
      final fake = FakeAuthProvider()
        ..uid = 'fake-uid'
        ..googleLinked = true
        ..emailLinked = false;
      AuthService.setProviderForTests(fake);
      await TrialService.instance.start();
      for (final (dark, accent) in _combos) {
        final name = _comboName(dark, accent);
        await pumpThemed(
          tester,
          // AccountProfilePage (no AccountScreen suelta): el
          // nombre vive en la cabecera (AppBar, perfil estilo
          // Duolingo 2026-11-16) y es el ancla del hueco que
          // mide el test; en AccountScreen sola ya no hay ningún
          // texto con el nombre. La clave por combinación
          // reconstruye la lista desde arriba en cada tema: sin
          // ella el framework reutiliza el ListView y la
          // posición del scroll (bajada a Premium en el tema
          // anterior) sobrevive y el banner queda fuera de la
          // ventana sin construirse.
          AccountProfilePage(
            key: ValueKey(name),
            onOpenScreen: (_) {},
            onShowAbout: () {},
            onShowShareApp: () {},
            trackTopics: const ['estequiometria'],
          ),
          dark: dark,
          accent: accent,
          size: const Size(400, 1500),
        );
        // Banner de prueba dentro de Cuenta.
        expect(find.byKey(const ValueKey('trialBanner')), findsOneWidget,
            reason: name);
        expect(find.textContaining('te quedan 3 días'), findsWidgets,
            reason: name);
        // Tarjeta de contraseña: compacta y separada. Se mide
        // ANTES de bajar a las filas: al hacer scroll la tarjeta
        // sube y el hueco ya no se puede medir.
        final card = find.byKey(const ValueKey('passwordPromptCard'));
        expect(card, findsOneWidget, reason: name);
        // Compacta: mide 175 pt con la Roboto real (156 con la
        // fuente de test); la vieja (padding 16, icono 48, textos
        // 16/14) pasaba de 195. El límite 190 caza una vuelta a
        // los tamaños viejos en ambas fuentes.
        expect(tester.getSize(card).height, lessThan(190), reason: name);
        // Separación desde el nombre de la cabecera (AppBar, con
        // la prueba activa el banner va en medio: el hueco es aún
        // mayor; el mínimo 24 caza la tarjeta pegada de antes).
        final nameBottom =
            tester.getBottomLeft(find.textContaining('kristian')).dy;
        expect(tester.getTopLeft(card).dy - nameBottom, greaterThan(24),
            reason: name);
        // Título de la tarjeta legible sobre su fondo.
        final title = tester.widget<Text>(
          find.text(tr('accountSetPasswordTitle')),
        );
        final container = tester.widget<Container>(card);
        final cardBg =
            (container.decoration as BoxDecoration).color!;
        expect(_contrast(title.style!.color!, cardBg),
            greaterThanOrEqualTo(4.5),
            reason: '$name: título de la tarjeta de contraseña');
        // La fila Premium VOLVIÓ a Cuenta (Kristian 2026-11-16:
        // "saca tienda y premium de configuraciones, déjalo en
        // cuenta"); el estado de la prueba se ve en el banner y
        // en el subtítulo de la fila. Tienda ya NO vive en Cuenta
        // (2026-11-17, reorganización Online): vive en Online.
        // La lista es perezosa: hay que bajar hasta las filas
        // para que se construyan.
        final scrollable = find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text(tr('accountPremium')),
          300,
          scrollable: scrollable,
        );
        await tester.pump();
        expect(find.text(tr('accountPremium')), findsOneWidget,
            reason: name);
        expect(find.text(tr('accountShop')), findsNothing,
            reason: name);
        expect(tester.takeException(), isNull);
      }
      // Parar el temporizador dentro del cuerpo (ver banner).
      TrialService.instance.stop();
    });
  });
}

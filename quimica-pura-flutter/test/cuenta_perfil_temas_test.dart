// Lote de perfil en TODOS los temas (Kristian 2026-11-16, orden:
// claro/oscuro × verde/violeta, perfectamente): la pantalla de
// Cuenta (fondo del avatar, RESUMEN con los iconos nuevos, banner
// de prueba, tarjeta de completar perfil, sugerencias), el perfil
// público y la tarjeta QR se comprueban en las 4 combinaciones:
// que todo se pinte, que el texto se lea (contraste WCAG ≥ 4,5)
// y que nada se rompa al cambiar de tema. Los colores se leen del
// widget real, no del diseño en papel.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quimica_pura/screens/account_screen.dart';
import 'package:quimica_pura/screens/profile_qr_screen.dart';
import 'package:quimica_pura/screens/public_profile_screen.dart';
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
import 'package:quimica_pura/widgets/social_avatar.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRobotoFonts);

  late FakeAuthProvider fakeAuth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    UserPrefs.rulesSeenV6 = true;
    UserPrefs.onboardingDone = true;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.userName = 'Kristian Pozo';
    UserPrefs.publicUsername = '';
    AppLang.code = 'es';
    PremiumService.resetForTests();
    TrialService.resetForTests();
    fakeAuth = FakeAuthProvider()
      ..uid = 'dev-kristian'
      ..googleLinked = true
      ..email = 'kristian@example.com'
      ..displayName = 'Kristian Pozo';
    AuthService.setProviderForTests(fakeAuth);
    SocialService.setRepositoryForTests(
        InMemorySocialRepository(seedDemo: true));
    AnalyticsSync.setRepositoryForTests(InMemoryAnalyticsRepository());
    addTearDown(() {
      TrialService.instance.stop();
      TrialService.resetForTests();
      PremiumService.resetForTests();
      AuthService.resetForTests();
      SocialService.resetForTests();
      AnalyticsSync.resetForTests();
      UserPrefs.rulesSeenV6 = false;
      UserPrefs.onboardingDone = false;
      UserPrefs.themeAccent = 'verde';
      UserPrefs.themeAccentNotifier.value = 'verde';
      UserPrefs.userName = '';
      UserPrefs.publicUsername = '';
    });
  });

  /// MaterialApp con el tema de la combinación (brillo + acento).
  Future<void> pumpThemed(
    WidgetTester tester,
    Widget child, {
    required bool dark,
    required String accent,
    Size size = const Size(400, 3000),
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
    // MaterialApp anima el cambio de tema (~200 ms) y las cargas
    // async (sugerencias, contadores) necesitan unos frames.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Color _screenBg(bool dark) =>
      dark ? AppAccent.darkBackground : Colors.white;

  group('Cuenta en los 4 temas', () {
    testWidgets('avatar SIN fondo distinto, RESUMEN con iconos '
        'nuevos, banner, tarjeta y sugerencias', (tester) async {
      await TrialService.instance.start();
      for (final (dark, accent) in _combos) {
        final name = _comboName(dark, accent);
        // Sin const: si no, el framework reutiliza el widget
        // entre combinaciones y los colores no cambian.
        await pumpThemed(
          tester,
          AccountScreen(
            key: UniqueKey(),
            onOpenScreen: (_) {},
            onShowAbout: () {},
            onShowShareApp: () {},
            trackTopics: const ['estequiometria'],
          ),
          dark: dark,
          accent: accent,
        );
        // Zona del avatar: SIN fondo distinto (Kristian
        // 2026-11-16, como Duolingo) — el avatar va directo sobre
        // el fondo de la pantalla, sin cuadrado ni color aparte.
        final bigAvatar = find.byWidgetPredicate(
          (w) => w is SocialAvatar && w.size == 160,
        );
        expect(bigAvatar, findsOneWidget, reason: name);
        final zones = find
            .ancestor(of: bigAvatar, matching: find.byType(Container))
            .evaluate()
            .map((e) => e.widget as Container)
            .where((c) => c.decoration is BoxDecoration)
            .toList();
        expect(zones, isEmpty,
            reason: '$name: el avatar va directo sobre el fondo');
        // RESUMEN con los iconos nuevos: rayo (puntos), medalla
        // (logros) y trofeo (trofeos) — dentro de su celda (el
        // Column más cercano a la etiqueta; el trofeo también
        // sale en LOGROS y en filas, por eso no vale buscarlo
        // en toda la pantalla).
        Finder iconInCell(String label, LucideIconData icon) {
          final cell = find
              .ancestor(of: find.text(label), matching: find.byType(Column))
              .last;
          return find.descendant(
            of: cell,
            matching: find.byWidgetPredicate(
                (w) => w is LucideIcon && w.icon == icon),
          );
        }

        expect(iconInCell('Puntos', LucideIcons.zap), findsOneWidget,
            reason: '$name: rayo en Puntos');
        expect(iconInCell('Logros', LucideIcons.medal), findsOneWidget,
            reason: '$name: medalla en Logros');
        expect(iconInCell('Trofeos', LucideIcons.trophy), findsOneWidget,
            reason: '$name: trofeo en Trofeos');
        // Banner de prueba legible.
        expect(find.byKey(const ValueKey('trialBanner')), findsOneWidget,
            reason: name);
        // 2026-11-16: la fila Premium de Cuenta (09:12) muestra el
        // MISMO texto de la prueba, así que el buscador se acota
        // al banner para no coger el de la fila.
        final bannerText = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const ValueKey('trialBanner')),
            matching: find.textContaining('te quedan 3 días'),
          ),
        );
        final bannerBg = _onTop(
          AppAccent.primary,
          0.10,
          _screenBg(dark),
        );
        expect(_contrast(bannerText.style!.color!, bannerBg),
            greaterThanOrEqualTo(4.5),
            reason: '$name: texto del banner');
        // Tarjeta de completar perfil: título legible sobre su
        // tarjeta.
        expect(find.byKey(const ValueKey('completeProfileCard')),
            findsOneWidget,
            reason: name);
        final card = tester.widget<Container>(
          find.byKey(const ValueKey('completeProfileCard')),
        );
        final cardBg = (card.decoration as BoxDecoration).color!;
        final cardTitle = tester.widget<Text>(
          find.text(tr('accountCompleteProfileTitle')),
        );
        expect(_contrast(cardTitle.style!.color!, cardBg),
            greaterThanOrEqualTo(4.5),
            reason: '$name: título de la tarjeta');
        // Sugerencias: título + al menos una persona con SEGUIR.
        expect(
            find.text(tr('accountSuggestionsTitle').toUpperCase()),
            findsOneWidget,
            reason: name);
        expect(find.text(tr('accountFollow').toUpperCase()), findsWidgets,
            reason: '$name: botón SEGUIR');
        expect(tester.takeException(), isNull);
      }
      TrialService.instance.stop();
    });
  });

  group('perfil público en los 4 temas', () {
    testWidgets('nombre, contadores, nota semanal y filas finales',
        (tester) async {
      for (final (dark, accent) in _combos) {
        final name = _comboName(dark, accent);
        await pumpThemed(
          tester,
          PublicProfileScreen(key: UniqueKey(), uid: 'dev-laura'),
          dark: dark,
          accent: accent,
        );
        expect(find.text('laura'), findsWidgets, reason: name);
        expect(find.text('@LAURA'), findsOneWidget, reason: name);
        expect(find.text('1420'), findsOneWidget, reason: name);
        expect(find.text(tr('profileWeeklyEmpty')), findsOneWidget,
            reason: name);
        expect(find.text(tr('profileReportUser')), findsOneWidget,
            reason: name);
        expect(find.text(tr('profileBlockUser')), findsOneWidget,
            reason: name);
        // El nombre se lee sobre el fondo de la pantalla.
        final nameText = tester.widget<Text>(find.text('laura').first);
        expect(_contrast(nameText.style!.color!, _screenBg(dark)),
            greaterThanOrEqualTo(4.5),
            reason: '$name: nombre del perfil');
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('tarjeta QR en los 4 temas', () {
    testWidgets('tarjeta blanca en todos los temas, con identidad y QR',
        (tester) async {
      for (final (dark, accent) in _combos) {
        final name = _comboName(dark, accent);
        await pumpThemed(
          tester,
          const QrScreen(username: 'laura', displayName: 'Laura'),
          dark: dark,
          accent: accent,
        );
        // La tarjeta es blanca en TODOS los temas (diseño de la
        // guía: tarjeta blanca sobre el perfil oscurecido).
        final qrView = find.byType(QrImageView);
        expect(qrView, findsOneWidget, reason: name);
        final cards = find
            .ancestor(of: qrView, matching: find.byType(Container))
            .evaluate()
            .map((e) => e.widget as Container)
            .where((c) =>
                c.decoration is BoxDecoration &&
                (c.decoration as BoxDecoration).borderRadius ==
                    BorderRadius.circular(24))
            .toList();
        expect(cards, isNotEmpty, reason: '$name: tarjeta QR encontrada');
        expect((cards.first.decoration as BoxDecoration).color, Colors.white,
            reason: '$name: la tarjeta QR es blanca');
        expect(find.text('Laura'), findsWidgets, reason: name);
        expect(find.text('@laura'), findsOneWidget, reason: name);
        expect(find.text('quemia'), findsOneWidget, reason: name);
        expect(tester.takeException(), isNull);
      }
    });
  });
}

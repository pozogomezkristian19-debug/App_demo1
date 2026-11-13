// Ronda #4, punto 11 (corrección final): Soporte NO va en el menú
// hamburguesa (salió de ahí por completo) y SÍ en Cuenta como
// última opción, pero como UNA OPCIÓN MÁS, igual que las demás
// filas: tarjeta gris, icono de mensaje (LucideIcons.messageCircle)
// en círculo tintado teal, título "Soporte", subtítulo "Escríbeme
// en la app", chevron. Nada de botón verde llamativo ni de logo
// de WhatsApp.
// 7.0 (Kristian 09:52): la fila YA NO abre WhatsApp directo —
// abre la ventanita de Soporte dentro de la app (ruta 'support').
// El botón flotante viejo (support_button.dart) no se toca: en
// lib/ ya nadie lo referencia (solo lo importan tests).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quimica_pura/widgets/lucide_icons.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/account_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'test_helpers.dart';

class _FakeUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final launched = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  late _FakeUrlLauncher fakeLauncher;
  late List<String> opened;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'melli_rules_seen_v6': true});
    await UserPrefs.load();
    await ProgressService.load();
    // Sin mock, el AudioPlayer estático de SoundService activa el
    // stream global de audioplayers y lanza MissingPluginException.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('xyz.luan/audioplayers.global/events'),
            (m) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('xyz.luan/audioplayers'), (m) async => null);
    fakeLauncher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = fakeLauncher;
    opened = <String>[];
  });

  Future<void> pumpAccount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 2, 800 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: AccountScreen(
            onOpenScreen: (key) => opened.add(key),
            onShowAbout: () {},
            onShowShareApp: () {},
            trackTopics: const [],
          ),
        ),
      ),
    );
    // Sin pumpAndSettle: el corazón de la tarjeta de estadísticas
    // late sin parar (PulseWidget repite cada 1200 ms).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('Soporte como una opción más en Cuenta (fix4, punto 11)', () {
    testWidgets('va después de Acerca de Quemia, antes de Ajustes',
        (tester) async {
      await pumpAccount(tester);
      await tester.scrollUntilVisible(
        find.text(tr('supportWord')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('supportWord')), findsOneWidget);
      // Debajo de "Acerca de Quemia"...
      final supportY = tester.getTopLeft(find.text(tr('supportWord'))).dy;
      final aboutY = tester.getTopLeft(find.text(tr('accountAbout'))).dy;
      expect(supportY, greaterThan(aboutY));
      // ...y por encima de "Ajustes" (7.1: Ajustes es la última
      // fila, antes del pie "Quemia · Creador: CraigKamer").
      final settingsY = tester.getTopLeft(find.text(tr('settingsTitle'))).dy;
      expect(supportY, lessThan(settingsY));
      final footerY = tester.getTopLeft(find.text('Quemia')).dy;
      expect(settingsY, lessThan(footerY));
    });

    testWidgets(
        'es una fila normal: icono de mensaje teal, sin verde '
        'llamativo ni logo de WhatsApp', (tester) async {
      await pumpAccount(tester);
      await tester.scrollUntilVisible(
        find.text(tr('supportWord')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Título y subtítulo pedidos (7.0: la fila abre la ventanita
      // en la app, ya no WhatsApp).
      expect(find.text(tr('supportWord')), findsOneWidget);
      expect(find.text(tr('supportSub')), findsOneWidget);
      // El icono es un mensaje (burbuja de chat), teal, no el logo.
      final icon = find.byWidgetPredicate((w) =>
          w is LucideIcon && w.icon == LucideIcons.messageCircle);
      expect(icon, findsOneWidget);
      final iconWidget = tester.widget<LucideIcon>(icon);
      expect(iconWidget.color, const Color(0xFF00C2A8));
      // Nada de verde WhatsApp en Cuenta ni logo de WhatsApp.
      expect(
        find.byWidgetPredicate((w) =>
            w is Material && w.color == const Color(0xFF25D366)),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate((w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == 'assets/whatsapp.png'),
        findsNothing,
      );
      // La fila es una TARJETA redondeada (_Row), como las
      // demás (organización 6.3): con tarjeta, pero sin sombra
      // (estilo Duolingo aprobado). Ningún contenedor con sombra
      // encima de "Soporte".
      final card = find.ancestor(
        of: find.text(tr('supportWord')),
        matching: find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).boxShadow != null),
      );
      expect(card, findsNothing);
      // ...y sigue con su chevron a la derecha.
      final row = find.ancestor(
        of: find.text(tr('supportWord')),
        matching: find.byType(InkWell),
      );
      expect(
        find.descendant(
          of: row,
          matching: find.byWidgetPredicate((w) =>
              w is LucideIcon && w.icon == LucideIcons.chevronRight),
        ),
        findsOneWidget,
      );
    });

    testWidgets('abre la ventanita de Soporte, sin abrir WhatsApp',
        (tester) async {
      await pumpAccount(tester);
      await tester.scrollUntilVisible(
        find.text(tr('supportWord')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(tr('supportWord')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // La fila abre la ruta 'support' (la ventanita en la app) y
      // NO lanza wa.me ni ningún enlace.
      expect(opened, ['support']);
      expect(fakeLauncher.launched, isEmpty);
    });
  });

  group('el menú ya no trae Soporte (fix4, punto 11)', () {
    testWidgets('el drawer no muestra Soporte ni el logo de WhatsApp',
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('supportWord')), findsNothing);
      expect(
        find.byWidgetPredicate((w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == 'assets/whatsapp.png'),
        findsNothing,
      );
    });
  });
}

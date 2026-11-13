// Pruebas del avatar editable (Quemia 7.1, alcance 9) y del
// encabezado del menú (alcance 10):
// - La galería: 4 libres + 3 premium (bloqueados sin comprar,
//   a la Tienda al tocarlos; equipables si ya se compraron).
// - El avatar por defecto va según el género del onboarding.
// - El círculo grande de Cuenta es el avatar del usuario (no la
//   compañera) y al tocarlo abre la galería; la línea "Hoy te
//   acompaña…" sigue intacta con su miniatura.
// - El género no se muestra escrito en Cuenta.
// - El menú trae el logo del anillo, no el de las gemelas.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/account_screen.dart';
import 'package:quimica_pura/screens/avatar_editor_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/social_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/lucide_icons.dart';
import 'package:quimica_pura/widgets/social_avatar.dart';
import 'package:quimica_pura/widgets/twin_avatars.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRobotoFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({'melli_rules_seen_v6': true});
    await UserPrefs.load();
    await ProgressService.load();
    SocialService.resetForTests();
    // Sin mock, el AudioPlayer estático de SoundService activa el
    // stream global de audioplayers y lanza MissingPluginException.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('xyz.luan/audioplayers.global/events'),
            (m) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('xyz.luan/audioplayers'), (m) async => null);
    UserPrefs.userName = '';
    UserPrefs.userGender = '';
  });

  tearDown(() {
    UserPrefs.userName = '';
    UserPrefs.userGender = '';
  });

  Finder imageAsset(String asset) => find.byWidgetPredicate((w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName == asset);

  Finder lucide(LucideIconData icon) => find.byWidgetPredicate(
      (w) => w is LucideIcon && w.icon == icon);

  /// La foto marcada con el check dentro de la galería.
  Finder selectedPhoto(String asset) {
    final check = lucide(LucideIcons.check);
    final tile = find.ancestor(
      of: check,
      matching: find.byType(Stack),
    );
    return find.descendant(
      of: tile,
      matching: imageAsset(asset),
    );
  }

  Future<void> pumpEditor(WidgetTester tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: AvatarEditorScreen(
            onOpenScreen: opened.add,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('avatar por defecto y resolución de ids', () {
    test('por defecto según el género del onboarding', () {
      expect(SocialService.defaultAvatarIdForGender('Femenino'),
          'avatar_brenda');
      expect(SocialService.defaultAvatarIdForGender('Masculino'),
          'avatar_kristian');
      expect(SocialService.defaultAvatarIdForGender(''), 'avatar_default');
      expect(SocialService.defaultAvatarIdForGender('Otro'),
          'avatar_default');
    });

    test('displayAvatarAssetForGender usa el de por defecto', () {
      expect(SocialService.displayAvatarAssetForGender('Femenino'),
          'assets/brenda.png');
      expect(SocialService.displayAvatarAssetForGender('Masculino'),
          'assets/kristian.png');
      expect(SocialService.displayAvatarAssetForGender(''),
          'assets/avatar_default.png');
    });

    test('avatarAssetForId resuelve libres, premium y desconocidos',
        () {
      expect(SocialService.avatarAssetForId('avatar_default'),
          'assets/avatar_default.png');
      expect(SocialService.avatarAssetForId('avatar_brenda'),
          'assets/brenda.png');
      expect(SocialService.avatarAssetForId('avatar_britany'),
          'assets/britany.png');
      expect(SocialService.avatarAssetForId('avatar_kristian'),
          'assets/kristian.png');
      expect(SocialService.avatarAssetForId('avatar_dorado'),
          'assets/avatar_dorado.png');
      expect(SocialService.avatarAssetForId('avatar_violeta'),
          'assets/avatar_violeta.png');
      expect(SocialService.avatarAssetForId('avatar_teal'),
          'assets/avatar_teal.png');
      expect(SocialService.avatarAssetForId('no_existe'), isNull);
      expect(SocialService.avatarAssetForId(null), isNull);
    });
  });

  group('galería del editor', () {
    testWidgets('sin nada equipado, la elegida es la de por defecto '
        'según el género', (tester) async {
      UserPrefs.userGender = 'Femenino';
      await pumpEditor(tester);
      // La galería trae las 7 caras.
      expect(imageAsset('assets/avatar_default.png'), findsOneWidget);
      expect(imageAsset('assets/brenda.png'), findsOneWidget);
      expect(imageAsset('assets/britany.png'), findsOneWidget);
      expect(imageAsset('assets/kristian.png'), findsOneWidget);
      expect(imageAsset('assets/avatar_dorado.png'), findsOneWidget);
      expect(imageAsset('assets/avatar_violeta.png'), findsOneWidget);
      expect(imageAsset('assets/avatar_teal.png'), findsOneWidget);
      // Un solo check, en la cara de por defecto (Brenda).
      expect(lucide(LucideIcons.check), findsOneWidget);
      expect(selectedPhoto('assets/brenda.png'), findsOneWidget);
    });

    testWidgets('tocar una libre la equipa y mueve el check',
        (tester) async {
      UserPrefs.userGender = 'Masculino';
      await pumpEditor(tester);
      expect(selectedPhoto('assets/kristian.png'), findsOneWidget);
      await tester.tap(find.text('Britany'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(SocialService.equippedAvatarId, 'avatar_britany');
      expect(selectedPhoto('assets/britany.png'), findsOneWidget);
      // Se guarda en local con el mismo campo de los premium.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('social_shop_equipped_avatar'),
          'avatar_britany');
    });

    testWidgets('los 3 premium salen bloqueados y al tocarlos van '
        'a la Tienda', (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: AvatarEditorScreen(
              onOpenScreen: opened.add,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Tres candados, uno por premium.
      expect(lucide(LucideIcons.lock), findsNWidgets(3));
      expect(SocialService.equippedAvatarId, isNull);
      await tester.tap(find.text('Avatar dorado'));
      await tester.pump();
      expect(opened, ['shop']);
      expect(SocialService.equippedAvatarId, isNull);
    });

    testWidgets('un premium ya comprado se puede equipar',
        (tester) async {
      ProgressService.instance.addPoints(1000);
      final dorado = kShopCatalog
          .firstWhere((i) => i.id == 'avatar_dorado');
      expect(await SocialService.buyItem(dorado), isTrue);
      await pumpEditor(tester);
      // Comprado: solo quedan 2 candados.
      expect(lucide(LucideIcons.lock), findsNWidgets(2));
      await tester.tap(find.text('Avatar dorado'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(SocialService.equippedAvatarId, 'avatar_dorado');
      expect(selectedPhoto('assets/avatar_dorado.png'), findsOneWidget);
    });
  });

  group('círculo de Cuenta (alcance 9) y género (alcance 10)', () {
    Future<List<String>> pumpAccount(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
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
              trackTopics: const [],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      return opened;
    }

    testWidgets('el círculo grande muestra el avatar equipado, '
        'no a la compañera', (tester) async {
      ProgressService.instance.addPoints(1000);
      final dorado =
          kShopCatalog.firstWhere((i) => i.id == 'avatar_dorado');
      await SocialService.buyItem(dorado);
      await SocialService.equipItem(dorado);
      UserPrefs.userName = 'Kristian';
      UserPrefs.userGender = 'Masculino';
      final opened = await pumpAccount(tester);
      // El círculo es SocialAvatar con la foto dorada equipada.
      expect(find.byType(SocialAvatar), findsOneWidget);
      final avatarImage = tester.widget<Image>(
        find.byKey(const ValueKey('social-avatar-Kristian')),
      );
      expect((avatarImage.image as AssetImage).assetName,
          'assets/avatar_dorado.png');
      // La compañera sigue solo en miniatura junto a la línea.
      expect(find.byType(CompanionAvatar), findsOneWidget);
      expect(tester.getSize(find.byType(CompanionAvatar)),
          const Size(22, 22));
      expect(
          find.text(tr(companionOfDayKey(companionOfTheDay()))),
          findsOneWidget);
      // Tocar el círculo abre la galería.
      await tester.tap(find.byType(SocialAvatar));
      await tester.pump();
      expect(opened, ['avatar']);
    });

    testWidgets('sin nada equipado, el círculo es el de por defecto '
        'según el género', (tester) async {
      UserPrefs.userName = 'Ana';
      UserPrefs.userGender = 'Femenino';
      await pumpAccount(tester);
      final avatarImage = tester.widget<Image>(
        find.byKey(const ValueKey('social-avatar-Ana')),
      );
      expect((avatarImage.image as AssetImage).assetName,
          'assets/brenda.png');
    });

    testWidgets('el género no se muestra escrito en Cuenta',
        (tester) async {
      UserPrefs.userName = 'Kristian';
      UserPrefs.userGender = 'Masculino';
      await pumpAccount(tester);
      expect(find.text('Bienvenido Kristian'), findsOneWidget);
      expect(find.text('Masculino'), findsNothing);
      expect(find.text('Femenino'), findsNothing);
      // Tampoco en Estadísticas: no hay ninguna píldora ni fila
      // con el género en toda la pantalla de Cuenta.
      expect(find.textContaining('Masculino'), findsNothing);
      expect(find.textContaining('Femenino'), findsNothing);
    });
  });

  group('menú hamburguesa (alcance 10)', () {
    testWidgets('el encabezado trae el logo del anillo, no el de '
        'las gemelas', (tester) async {
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
      final drawer = find.byType(Drawer);
      expect(drawer, findsOneWidget);
      // El anillo está en el encabezado del menú…
      expect(
        find.descendant(
          of: drawer,
          matching: imageAsset('assets/app_icon.png'),
        ),
        findsOneWidget,
      );
      // …y el logo de las gemelas ya no está en el menú.
      expect(
        find.descendant(
          of: drawer,
          matching: imageAsset('assets/logo.png'),
        ),
        findsNothing,
      );
      // El texto sigue: "Quemia" + el subtítulo.
      expect(
        find.descendant(
          of: drawer,
          matching: find.text('Quemia'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: drawer,
          matching: find.text(tr('appSubtitle')),
        ),
        findsOneWidget,
      );
    });
  });
}

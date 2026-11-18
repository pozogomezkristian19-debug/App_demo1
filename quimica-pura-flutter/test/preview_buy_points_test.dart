// Fotos de la compra de puntos para Kristian (2026-11-17):
// cómo quedaría en varios lugares — la tarjeta en la Tienda,
// la pantalla de paquetes y la pantalla de pago con
// Transfermóvil. Solo genera las fotos en
// ../../melli-qui-v6-previews/; no son goldens de regresión
// (no se comparan en verde salvo que existan).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/buy_points_screen.dart';
import 'package:quimica_pura/screens/shop_screen.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/remote_shop_catalog.dart';
import 'package:quimica_pura/services/remote_tuning.dart';
import 'package:quimica_pura/services/social_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/duo_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadNunitoFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    UserPrefs.userName = 'kristian';
    SocialService.setRepositoryForTests(
      InMemorySocialRepository(seedDemo: true),
    );
    RemoteTuning.resetForTests();
    RemoteShopCatalog.instance.resetForTests();
    // Catálogo fijo sin esperar a la red: el fetcher devuelve
    // vacío y el catálogo cae al respaldo (los 9 de siempre).
    RemoteShopCatalog.instance
        .setFetcherForTests(() async => <Map<String, dynamic>>[]);
  });

  tearDown(() {
    SocialService.resetForTests();
    RemoteShopCatalog.instance.resetForTests();
    RemoteTuning.resetForTests();
    UserPrefs.userName = '';
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Nunito'),
        home: screen,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../melli-qui-v6-previews/$name'),
    );
  }

  testWidgets('tienda_comprar_puntos: tarjeta arriba de la Tienda',
      (tester) async {
    await pump(tester, const ShopScreen(isGoogleLinked: true));
    expect(find.text('¿Te faltan puntos?'), findsOneWidget);
    expect(find.text('COMPRAR PUNTOS'), findsOneWidget);
    await shot(tester, 'tienda_comprar_puntos.png');
  });

  testWidgets('comprar_puntos_paquetes: los 3 paquetes',
      (tester) async {
    await pump(tester, const BuyPointsScreen());
    expect(find.text('Compra puntos'), findsOneWidget);
    expect(find.text('EL MÁS POPULAR'), findsOneWidget);
    expect(find.text('1.200 PUNTOS'), findsOneWidget);
    await shot(tester, 'comprar_puntos_paquetes.png');
  });

  testWidgets('comprar_puntos_pago: pago con Transfermóvil',
      (tester) async {
    await pump(tester, const BuyPointsScreen());
    await tester.tap(find.widgetWithText(DuoButton, 'COMPRAR').at(1));
    await tester.pumpAndSettle();
    expect(find.text('Paga con Transfermóvil'), findsOneWidget);
    expect(find.text('Tarjeta destino (EJEMPLO)'), findsOneWidget);
    expect(find.text('ELEGIR CAPTURA'), findsOneWidget);
    await shot(tester, 'comprar_puntos_pago.png');
  });
}

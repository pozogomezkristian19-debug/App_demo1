// Tienda 7.3: catálogo remoto (Firestore 'shop_items'), caché
// offline y compra/equipar de artículos remotos (incluido el
// marco). Sin backend real: el lector de Firestore se inyecta
// con un falso que devuelve documentos, falla o no responde.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/shop_screen.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/remote_shop_catalog.dart';
import 'package:quimica_pura/services/social_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Catálogo remoto simulado: los 9 de siempre + los 15 nuevos del
/// diseño 7.3 (3 temas, 7 avatares con imageUrl, 3 insignias, 2
/// marcos). Las imageUrl son ficticias: en tests no se descargan
/// (la tarjeta muestra la cara por defecto).
List<Map<String, dynamic>> kRemoteCatalogDocs = [
  for (final item in kShopCatalog) item.toMap(),
  {
    'id': 'theme_menta',
    'name': 'Verde menta',
    'kind': 'theme',
    'price': 300,
    'color': 0xFF34D399,
    'description': 'Fresco como un mojito sin alcohol.',
    'active': true,
    'sortOrder': 10,
  },
  {
    'id': 'theme_galaxia',
    'name': 'Morado galaxia',
    'kind': 'theme',
    'price': 350,
    'color': 0xFF8B5CF6,
    'description': 'El universo entero en tu pantalla.',
    'active': true,
    'sortOrder': 11,
  },
  {
    'id': 'theme_medianoche',
    'name': 'Medianoche',
    'kind': 'theme',
    'price': 400,
    'color': 0xFF1E3A5F,
    'description': 'Para estudiar hasta tarde sin que duelan los ojos.',
    'active': true,
    'sortOrder': 12,
  },
  {
    'id': 'avatar_gato',
    'name': 'Gato científico',
    'kind': 'avatar',
    'price': 150,
    'color': 0xFFFFA500,
    'imageUrl': 'https://example.com/tienda/avatar_gato.png',
    'description': 'Maúlla en fórmulas: H2O, miau.',
    'active': true,
    'sortOrder': 13,
  },
  {
    'id': 'avatar_exploradora',
    'name': 'Exploradora',
    'kind': 'avatar',
    'price': 200,
    'color': 0xFF65A30D,
    'imageUrl': 'https://example.com/tienda/avatar_exploradora.png',
    'description': 'Descubrió un elemento nuevo: el "químio".',
    'active': true,
    'sortOrder': 14,
  },
  {
    'id': 'avatar_cientifico',
    'name': 'Científico loco',
    'kind': 'avatar',
    'price': 250,
    'color': 0xFF00C2A8,
    'imageUrl': 'https://example.com/tienda/avatar_cientifico.png',
    'description': 'El pelo despeinado es por la ciencia, no por la ducha.',
    'active': true,
    'sortOrder': 15,
  },
  {
    'id': 'avatar_robot',
    'name': 'Robot Químico',
    'kind': 'avatar',
    'price': 300,
    'color': 0xFF3B82F6,
    'imageUrl': 'https://example.com/tienda/avatar_robot.png',
    'description': 'No duerme, no come, solo resuelve ecuaciones.',
    'active': true,
    'sortOrder': 16,
  },
  {
    'id': 'avatar_astronauta',
    'name': 'Astronauta',
    'kind': 'avatar',
    'price': 400,
    'color': 0xFF8B5CF6,
    'imageUrl': 'https://example.com/tienda/avatar_astronauta.png',
    'description': 'Su elemento favorito es el helio: siempre está en las nubes.',
    'active': true,
    'sortOrder': 17,
  },
  {
    'id': 'avatar_superquimica',
    'name': 'Superquímica',
    'kind': 'avatar',
    'price': 1500,
    'color': 0xFF00C2A8,
    'imageUrl': 'https://example.com/tienda/avatar_superquimica.png',
    'description': 'Su capa es violeta. Su tabla periódica, impecable.',
    'active': true,
    'sortOrder': 18,
  },
  {
    'id': 'avatar_supercientifico',
    'name': 'Súper científico',
    'kind': 'avatar',
    'price': 1500,
    'color': 0xFF00C2A8,
    'imageUrl': 'https://example.com/tienda/avatar_supercientifico.png',
    'description':
        'El héroe de la tabla periódica: traje teal, capa violeta, cero miedo a los exámenes.',
    'active': true,
    'sortOrder': 19,
  },
  {
    'id': 'badge_adn',
    'name': 'ADN',
    'kind': 'badge',
    'price': 200,
    'color': 0xFFFFC800,
    'badgeIcon': 'dna',
    'description': 'La doble hélice, siempre contigo.',
    'active': true,
    'sortOrder': 20,
  },
  {
    'id': 'badge_atomo',
    'name': 'Átomo',
    'kind': 'badge',
    'price': 250,
    'color': 0xFFFFC800,
    'badgeIcon': 'atom',
    'description': 'Todo está hecho de átomos. Tú también.',
    'active': true,
    'sortOrder': 21,
  },
  {
    'id': 'badge_cohete',
    'name': 'Cohete',
    'kind': 'badge',
    'price': 300,
    'color': 0xFFFFC800,
    'badgeIcon': 'rocket',
    'description': 'Despega hacia el 10.',
    'active': true,
    'sortOrder': 22,
  },
  {
    'id': 'frame_dorado',
    'name': 'Marco dorado',
    'kind': 'frame',
    'price': 400,
    'color': 0xFFFFD700,
    'description': 'Oro alrededor de tu foto. Como te mereces.',
    'active': true,
    'sortOrder': 23,
  },
  {
    'id': 'frame_arcoiris',
    'name': 'Marco arcoíris',
    'kind': 'frame',
    'price': 500,
    'badgeIcon': 'rainbow',
    'description': 'Todos los colores, todos los días.',
    'active': true,
    'sortOrder': 24,
  },
];

void main() {
  late InMemorySocialRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    repo = InMemorySocialRepository(seedDemo: true);
    SocialService.setRepositoryForTests(repo);
  });

  tearDown(() {
    SocialService.resetForTests();
    RemoteShopCatalog.instance.resetForTests();
  });

  group('ShopItem.fromMap', () {
    test('documento completo: todos los campos', () {
      final item = ShopItem.fromMap({
        'name': 'Gato científico',
        'kind': 'avatar',
        'price': 150,
        'color': 0xFFFFA500,
        'imageUrl': 'https://example.com/gato.png',
        'description': 'Miau.',
        'active': true,
        'sortOrder': 13,
      }, 'avatar_gato');
      expect(item, isNotNull);
      expect(item!.id, 'avatar_gato');
      expect(item.name, 'Gato científico');
      expect(item.kind, 'avatar');
      expect(item.price, 150);
      expect(item.color, 0xFFFFA500);
      expect(item.imageUrl, 'https://example.com/gato.png');
      expect(item.description, 'Miau.');
      expect(item.active, isTrue);
      expect(item.sortOrder, 13);
    });

    test('campos ausentes: valores por defecto, no rompe', () {
      final item = ShopItem.fromMap({
        'name': 'Misterio',
        'kind': 'theme',
      }, 'theme_x');
      expect(item, isNotNull);
      expect(item!.price, 0);
      expect(item.color, isNull);
      expect(item.badgeIcon, isNull);
      expect(item.asset, isNull);
      expect(item.imageUrl, isNull);
      expect(item.description, '');
      expect(item.active, isTrue);
      expect(item.sortOrder, 0);
    });

    test('tipos malos: precio con texto, color con texto, active no bool',
        () {
      final item = ShopItem.fromMap({
        'name': 'Raro',
        'kind': 'badge',
        'price': '150',
        'color': 'rojo',
        'active': 'sí',
        'sortOrder': '3',
      }, 'badge_raro');
      expect(item, isNotNull);
      expect(item!.price, 150);
      expect(item.color, isNull);
      expect(item.active, isTrue);
      expect(item.sortOrder, 3);

      final badPrice = ShopItem.fromMap({
        'name': 'Raro 2',
        'kind': 'badge',
        'price': 'abc',
        'sortOrder': 2.7,
      }, 'badge_raro2');
      expect(badPrice, isNotNull);
      expect(badPrice!.price, 0);
      expect(badPrice.sortOrder, 2);
    });

    test('sin id, sin nombre o sin tipo: null (documento roto)', () {
      expect(ShopItem.fromMap({'name': 'X', 'kind': 'theme'}), isNull);
      expect(
          ShopItem.fromMap({'kind': 'theme'}, 'id'), isNull);
      expect(
          ShopItem.fromMap({'name': 'X'}, 'id'), isNull);
      expect(
          ShopItem.fromMap(
              {'name': '  ', 'kind': 'theme'}, 'id'),
          isNull);
    });

    test('el id del documento manda sobre el campo id', () {
      final item = ShopItem.fromMap({
        'id': 'dentro',
        'name': 'X',
        'kind': 'theme',
        'price': 10,
      }, 'doc_id');
      expect(item!.id, 'doc_id');
    });

    test('toMap/fromMap: ida y vuelta sin perder nada', () {
      const original = ShopItem(
        id: 'avatar_gato',
        name: 'Gato científico',
        kind: 'avatar',
        price: 150,
        color: 0xFFFFA500,
        imageUrl: 'https://example.com/gato.png',
        description: 'Miau.',
        active: true,
        sortOrder: 13,
      );
      final back = ShopItem.fromMap(original.toMap(), 'avatar_gato');
      expect(back, original);
    });
  });

  group('RemoteShopCatalog', () {
    test('remoto: devuelve activos ordenados por sortOrder', () async {
      RemoteShopCatalog.instance.setFetcherForTests(() async => [
            {
              'id': 'b',
              'name': 'B',
              'kind': 'theme',
              'price': 100,
              'sortOrder': 2,
              'active': true,
            },
            {
              'id': 'a',
              'name': 'A',
              'kind': 'theme',
              'price': 100,
              'sortOrder': 1,
              'active': true,
            },
            {
              'id': 'off',
              'name': 'Oculto',
              'kind': 'theme',
              'price': 100,
              'sortOrder': 0,
              'active': false,
            },
            {'name': 'Roto', 'kind': 'theme', 'price': 100},
          ]);
      final items = await RemoteShopCatalog.instance.loadCatalog();
      expect(items.map((i) => i.id).toList(), ['a', 'b']);
    });

    test('sin internet y sin caché: respaldo kShopCatalog', () async {
      RemoteShopCatalog.instance
          .setFetcherForTests(() async => throw StateError('sin red'));
      final items = await RemoteShopCatalog.instance.loadCatalog();
      expect(items.map((i) => i.id).toList(),
          kShopCatalog.map((i) => i.id).toList());
    });

    test('sin internet con caché: devuelve la caché (no el respaldo)',
        () async {
      RemoteShopCatalog.instance.setFetcherForTests(
          () async => kRemoteCatalogDocs);
      final first = await RemoteShopCatalog.instance.loadCatalog();
      expect(first.length, 24);
      // Sin memoria (como al reabrir la app) y sin red: la caché
      // local responde.
      RemoteShopCatalog.instance.resetForTests();
      RemoteShopCatalog.instance
          .setFetcherForTests(() async => throw StateError('sin red'));
      final second = await RemoteShopCatalog.instance.loadCatalog();
      expect(second.map((i) => i.id).toList(),
          first.map((i) => i.id).toList());
      expect(second.any((i) => i.id == 'avatar_gato'), isTrue);
    });

    test('remoto vacío: cae al respaldo (no deja la tienda vacía)',
        () async {
      RemoteShopCatalog.instance.setFetcherForTests(() async => []);
      final items = await RemoteShopCatalog.instance.loadCatalog();
      expect(items.length, kShopCatalog.length);
    });

    test('refreshCatalog fuerza la relectura', () async {
      var calls = 0;
      RemoteShopCatalog.instance.setFetcherForTests(() async {
        calls++;
        return kRemoteCatalogDocs;
      });
      await RemoteShopCatalog.instance.loadCatalog();
      await RemoteShopCatalog.instance.loadCatalog();
      expect(calls, 1); // La segunda usa la memoria (TTL 5 min).
      await RemoteShopCatalog.instance.refreshCatalog();
      expect(calls, 2);
    });

    test('lectura colgada: timeout de 5 s y respaldo', () async {
      RemoteShopCatalog.instance
          .setFetcherForTests(() => Completer<List<Map<String, dynamic>>>().future);
      final stopwatch = Stopwatch()..start();
      final items = await RemoteShopCatalog.instance.loadCatalog();
      stopwatch.stop();
      expect(items.length, kShopCatalog.length);
      expect(stopwatch.elapsed.inSeconds, lessThan(10));
    });
  });

  group('SocialService.shopItems con catálogo remoto', () {
    test('devuelve el catálogo remoto (no el fijo)', () async {
      RemoteShopCatalog.instance.setFetcherForTests(
          () async => kRemoteCatalogDocs);
      final items = await SocialService.shopItems();
      expect(items.length, 24);
      expect(items.any((i) => i.id == 'frame_dorado'), isTrue);
      expect(items.any((i) => i.id == 'avatar_gato'), isTrue);
      expect(items.any((i) => i.id == 'avatar_supercientifico'), isTrue);
      expect(
          items
              .firstWhere((i) => i.id == 'avatar_superquimica')
              .price,
          1500);
      expect(
          items
              .firstWhere((i) => i.id == 'avatar_supercientifico')
              .price,
          1500);
    });

    test('comprar y equipar un avatar remoto (con imageUrl)', () async {
      RemoteShopCatalog.instance.setFetcherForTests(
          () async => kRemoteCatalogDocs);
      final items = await SocialService.shopItems();
      final gato = items.firstWhere((i) => i.id == 'avatar_gato');
      ProgressService.instance.addPoints(200);
      expect(await SocialService.buyItem(gato), isTrue);
      expect(ProgressService.instance.points, 50);
      await SocialService.equipItem(gato);
      expect(SocialService.equippedAvatarId, 'avatar_gato');
      expect(SocialService.equippedAvatarImageUrl,
          'https://example.com/tienda/avatar_gato.png');
      expect(SocialService.equippedAvatarAsset, isNull);
    });

    test('comprar y equipar un marco: se sincroniza como frame', () async {
      RemoteShopCatalog.instance.setFetcherForTests(
          () async => kRemoteCatalogDocs);
      final items = await SocialService.shopItems();
      final marco = items.firstWhere((i) => i.id == 'frame_dorado');
      ProgressService.instance.addPoints(500);
      expect(await SocialService.buyItem(marco), isTrue);
      await SocialService.equipItem(marco);
      expect(await SocialService.equippedItemId('frame'), 'frame_dorado');
      expect(SocialService.equippedFrameId, 'frame_dorado');
      expect(SocialService.equippedFrameItem?.name, 'Marco dorado');
      expect(repo.syncedEquipped['frame'], 'frame_dorado');
    });

    test('tema remoto equipado: su color se resuelve (acento)', () async {
      RemoteShopCatalog.instance.setFetcherForTests(
          () async => kRemoteCatalogDocs);
      final items = await SocialService.shopItems();
      final menta = items.firstWhere((i) => i.id == 'theme_menta');
      ProgressService.instance.addPoints(500);
      await SocialService.buyItem(menta);
      await SocialService.equipItem(menta);
      expect(SocialService.equippedThemeColor, const Color(0xFF34D399));
      expect(SocialService.equippedThemeName, 'Verde menta');
    });
  });

  group('ShopImageCache', () {
    test('nombre de archivo estable por URL y distinto por URL', () {
      const a = 'https://example.com/tienda/avatar_gato.png';
      const b = 'https://example.com/tienda/avatar_superquimica.png';
      expect(ShopImageCache.fileNameFor(a), ShopImageCache.fileNameFor(a));
      expect(ShopImageCache.fileNameFor(a),
          isNot(ShopImageCache.fileNameFor(b)));
      expect(ShopImageCache.fileNameFor(a).endsWith('.png'), isTrue);
      expect(
          ShopImageCache.fileNameFor('https://example.com/foto')
              .endsWith('.jpg'),
          isTrue);
    });
  });

  group('pantalla Tienda con catálogo remoto', () {
    Future<void> pumpShop(WidgetTester tester) async {
      // Viewport alto (6000 pt): el catálogo remoto tiene 24
      // tarjetas y la lista las construye solo si caben.
      tester.view.physicalSize = const Size(786, 12000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const ShopScreen(isGoogleLinked: true),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('secciones Temas/Avatares/Insignias/Marcos y 4 estados',
        (tester) async {
      RemoteShopCatalog.instance.setFetcherForTests(
          () async => kRemoteCatalogDocs);
      // 320 puntos como el mockup: dorado comprado y equipado,
      // violeta comprado, el resto según su precio.
      ProgressService.instance.addPoints(2000);
      final dorado = kShopCatalog.firstWhere((i) => i.id == 'avatar_dorado');
      final violeta =
          kShopCatalog.firstWhere((i) => i.id == 'avatar_violeta');
      await SocialService.buyItem(dorado);
      await SocialService.buyItem(violeta);
      await SocialService.equipItem(dorado);
      ProgressService.instance.addPoints(-1330);
      expect(ProgressService.instance.points, 320);

      await pumpShop(tester);

      expect(find.text('320'), findsOneWidget);
      expect(find.text('Temas'), findsOneWidget);
      expect(find.text('Avatares'), findsOneWidget);
      expect(find.text('Insignias'), findsOneWidget);
      expect(find.text('Marcos'), findsOneWidget);
      expect(find.text('Verde menta'), findsOneWidget);
      expect(find.text('Gato científico'), findsOneWidget);
      expect(find.text('Exploradora'), findsOneWidget);
      expect(find.text('Científico loco'), findsOneWidget);
      expect(find.text('Robot Químico'), findsOneWidget);
      expect(find.text('Astronauta'), findsOneWidget);
      expect(find.text('Superquímica'), findsOneWidget);
      expect(find.text('Súper científico'), findsOneWidget);
      expect(find.text('ADN'), findsOneWidget);
      expect(find.text('Marco dorado'), findsOneWidget);
      expect(find.text('Marco arcoíris'), findsOneWidget);
      // Los 4 estados visibles a la vez.
      expect(find.text('Equipado'), findsOneWidget);
      expect(find.text('EQUIPAR'), findsOneWidget);
      expect(find.textContaining('COMPRAR'), findsWidgets);
      expect(find.textContaining('Te faltan'), findsWidgets);
      // Precios del mockup: menta 300 comprable, galaxia 350.
      expect(find.textContaining('COMPRAR · 300'), findsWidgets);
      expect(find.text('Te faltan 30 puntos'), findsOneWidget);
      expect(find.text('Te faltan 180 puntos'), findsWidgets);
    });
  });
}

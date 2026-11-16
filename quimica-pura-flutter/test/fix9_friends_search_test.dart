// Búsqueda de amigos (Kristian 2026-11-15): barra en Amigos;
// SOLO por nombre de usuario (el correo NO se busca: lo quitó él
// 2026-11-15). Nombre de usuario exacto → solo ese usuario;
// nombre normal/parcial ('bre') → todos los nombres
// relacionados. Cada resultado muestra el nombre de usuario real
// (para verificar la cuenta antes de invitar), con la imagen de
// agregar amigo a la derecha (Kristian 2026-11-15: en vez de
// botón, el logo real de Flaticon; al tocarla se envía la
// solicitud, reutilizando el flujo de solicitud) y perfil del
// amigo al tocarlo una vez siendo amigos.
//
// Todo contra InMemorySocialRepository (sin Firestore real): lo
// online de verdad (red, Firestore, latencias, reglas) NO queda
// probado aquí — ver el informe final.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/friends_screen.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/notification_inbox.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/social_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late InMemorySocialRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    NotificationInbox.resetForTests();
    await ProgressService.load();
    UserPrefs.userName = 'kristian';
    repo = InMemorySocialRepository(seedDemo: true);
    SocialService.setRepositoryForTests(repo);
    AnalyticsSync.resetForTests();
  });

  tearDown(() {
    SocialService.resetForTests();
    AnalyticsSync.resetForTests();
    UserPrefs.userName = '';
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(360, 1000),
  }) async {
    tester.view.physicalSize = Size(size.width * 2, size.height * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: screen,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> _settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Escribe en la barra de búsqueda y espera el debounce
  /// (300 ms) + la búsqueda.
  Future<void> _search(WidgetTester tester, String text) async {
    await tester.enterText(
      find.widgetWithText(TextField, tr('friendsSearchHint')),
      text,
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  List<String> _names(List<FriendEntry> users) =>
      users.map((u) => u.username).toList();

  group('búsqueda de amigos (repositorio)', () {
    test('prefijo: la → solo laura', () async {
      expect(_names(await SocialService.searchUsers('la')), ['laura']);
    });

    test('prefijo sin mayúsculas: LA → laura, LU → lucia', () async {
      expect(_names(await SocialService.searchUsers('LA')), ['laura']);
      expect(_names(await SocialService.searchUsers('LU')), ['lucia']);
    });

    test('nombre normal: l → laura y lucia (varios perfiles)', () async {
      expect(
        _names(await SocialService.searchUsers('l')),
        ['laura', 'lucia'],
      );
    });

    test('nombre exacto: laura → solo laura, aunque la es prefijo', () async {
      expect(
        _names(await SocialService.searchUsers('laura')),
        ['laura'],
      );
      expect(
        _names(await SocialService.searchUsers('LaUrA')),
        ['laura'],
      );
    });

    test('nombre exacto que no existe → vacío', () async {
      expect(await SocialService.searchUsers('zzz'), isEmpty);
      expect(await SocialService.searchUsers('bren'), isEmpty);
    });

    test('vacío → vacío', () async {
      expect(await SocialService.searchUsers(''), isEmpty);
      expect(await SocialService.searchUsers('   '), isEmpty);
    });

    test('yo mismo no salgo: kri y kristian → vacío', () async {
      expect(await SocialService.searchUsers('kri'), isEmpty);
      expect(await SocialService.searchUsers('kristian'), isEmpty);
    });

    test('un correo ya no busca nada (Kristian lo quitó)', () async {
      expect(
        await SocialService.searchUsers('laura@quemia.demo'),
        isEmpty,
      );
      expect(
        await SocialService.searchUsers('nadie@quemia.demo'),
        isEmpty,
      );
    });

    test('sin internet → vacío', () async {
      repo.onlineFlag = false;
      expect(await SocialService.searchUsers('la'), isEmpty);
      repo.onlineFlag = true;
    });
  });

  group('búsqueda de amigos (pantalla)', () {
    testWidgets(
        'buscar por prefijo muestra el resultado con la imagen de '
        'agregar amigo', (tester) async {
      await pumpScreen(tester, const FriendsScreen(isGoogleLinked: true));
      await _search(tester, 'lu');
      expect(find.text('lucia'), findsOneWidget);
      expect(find.byKey(const ValueKey('addFriendImage-lucia')),
          findsOneWidget);
      // Sin botón Invitar: la imagen es el botón.
      expect(find.text('INVITAR'), findsNothing);
    });

    testWidgets('nombre normal: l muestra varios perfiles', (tester) async {
      await pumpScreen(tester, const FriendsScreen(isGoogleLinked: true));
      await _search(tester, 'l');
      expect(find.text('AMIGO'), findsOneWidget);
      expect(find.byKey(const ValueKey('addFriendImage-lucia')),
          findsOneWidget);
      // laura (amiga) y lucia (no amiga) en los resultados.
      final inResults = find.descendant(
        of: find.byKey(const ValueKey('friends-search-results')),
        matching: find.text('laura'),
      );
      expect(inResults, findsOneWidget);
      final luciaInResults = find.descendant(
        of: find.byKey(const ValueKey('friends-search-results')),
        matching: find.text('lucia'),
      );
      expect(luciaInResults, findsOneWidget);
    });

    testWidgets('nombre exacto muestra solo ese usuario', (tester) async {
      await pumpScreen(tester, const FriendsScreen(isGoogleLinked: true));
      await _search(tester, 'laura');
      expect(find.text('AMIGO'), findsOneWidget);
      // lucia comparte la 'l' pero no es laura: no sale.
      expect(find.text('lucia'), findsNothing);
    });

    testWidgets('buscar por correo ya no muestra nada', (tester) async {
      await pumpScreen(tester, const FriendsScreen(isGoogleLinked: true));
      await _search(tester, 'valeria@quemia.demo');
      expect(find.text('valeria'), findsNothing);
      expect(find.byKey(const ValueKey('addFriendImage-valeria')),
          findsNothing);
      expect(find.text(tr('friendsSearchNoResults')), findsOneWidget);
    });

    testWidgets(
        'invitar manda solicitud y la imagen cambia, sin duplicado',
        (tester) async {
      await pumpScreen(tester, const FriendsScreen(isGoogleLinked: true));
      await _search(tester, 'lu');
      await tester.tap(find.byKey(const ValueKey('addFriendImage-lucia')));
      await _settle(tester);
      expect(find.text('ENVIADA'), findsOneWidget);
      expect(find.byKey(const ValueKey('addFriendImage-lucia')),
          findsNothing);
      final sent = await SocialService.sentFriendRequests();
      expect(sent.length, 1);
      expect(sent.first.receiverUsername, 'lucia');
      // El botón ya está deshabilitado: tocarlo no manda otra.
      await tester.tap(find.text('ENVIADA'));
      await _settle(tester);
      expect(
        (await SocialService.sentFriendRequests()).length,
        1,
      );
    });

    testWidgets('un amigo sale como Amigo y al tocarlo abre su perfil',
        (tester) async {
      await pumpScreen(tester, const FriendsScreen(isGoogleLinked: true));
      await _search(tester, 'la');
      expect(find.text('AMIGO'), findsOneWidget);
      final lauraInResults = find.descendant(
        of: find.byKey(const ValueKey('friends-search-results')),
        matching: find.text('laura'),
      );
      await tester.tap(lauraInResults);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Perfil de laura: título + sus puntos y niveles.
      expect(find.text(tr('friendsProfileTitle')), findsOneWidget);
      expect(find.text('1420'), findsOneWidget);
      expect(find.text('28'), findsOneWidget);
    });

    testWidgets('sin resultados: mensaje tranquilo', (tester) async {
      await pumpScreen(tester, const FriendsScreen(isGoogleLinked: true));
      await _search(tester, 'zz');
      expect(find.text(tr('friendsSearchNoResults')), findsOneWidget);
    });

    testWidgets('sin internet: mensaje sin internet', (tester) async {
      repo.onlineFlag = false;
      await pumpScreen(tester, const FriendsScreen(isGoogleLinked: true));
      await _search(tester, 'lu');
      expect(find.text(tr('friendsSearchOffline')), findsOneWidget);
      repo.onlineFlag = true;
    });
  });
}

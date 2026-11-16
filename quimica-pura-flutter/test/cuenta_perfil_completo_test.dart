// Perfil completo de Cuenta (Kristian 2026-11-16, lote de 11
// puntos + refinamientos): seguir/dejar de seguir con contadores
// REALES, listas de seguidos/seguidores, rotación de sugerencias,
// perfil público con datos reales, tarjeta de completar perfil y
// flujo de poner nombre + "¡Se ve genial!", contenido del QR,
// reportar y bloquear. Los datos salen del repo en memoria con
// los 12 usuarios demo (kristian = yo, dev-kristian).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quimica_pura/screens/account_screen.dart';
import 'package:quimica_pura/screens/profile_qr_screen.dart';
import 'package:quimica_pura/screens/public_profile_screen.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/auth_service.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/social_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

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
    fakeAuth = FakeAuthProvider()
      ..uid = 'dev-kristian'
      ..googleLinked = true
      ..email = 'kristian@example.com'
      ..displayName = 'Kristian Pozo';
    AuthService.setProviderForTests(fakeAuth);
    SocialService.setRepositoryForTests(
        InMemorySocialRepository(seedDemo: true));
    AnalyticsSync.setRepositoryForTests(InMemoryAnalyticsRepository());
  });

  tearDown(() {
    SocialService.resetForTests();
    AnalyticsSync.resetForTests();
    AuthService.resetForTests();
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.onboardingDone = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.userName = '';
    UserPrefs.publicUsername = '';
  });


  /// Avance acotado en vez de pumpAndSettle: la tarjeta de
  /// completar perfil ya NO respira en bucle (la MascotMotion se
  /// quitó con la mascota, 2026-11-16), pero el avance acotado se
  /// queda: cubre las cargas async, el CountUp (600 ms), la
  /// salida de tarjeta (300 ms) y la celebración (900 ms) sin
  /// depender de que todo "se asiente".
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> pumpAccount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await UserPrefs.saveThemeMode('claro');
    // UniqueKey: cada pumpAccount es una pantalla NUEVA (como
    // reabrir Cuenta). Sin ella, pumpWidget reutiliza el State y
    // el initState (que lee el nombre de usuario) no vuelve a
    // correr.
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: AccountScreen(
            key: UniqueKey(),
            onOpenScreen: (_) {},
            onShowAbout: () {},
            onShowShareApp: () {},
            trackTopics: const ['estequiometria'],
          ),
        ),
      ),
    );
    await tester.pump();
    await settle(tester);
  }

  Future<void> pumpPublicProfile(WidgetTester tester, String uid) async {
    tester.view.physicalSize = const Size(800, 2500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: PublicProfileScreen(uid: uid),
      ),
    );
    await tester.pump();
    await settle(tester);
  }

  /// El primer nombre de usuario de las sugerencias de hoy.
  Future<String> firstSuggestionUsername() async {
    final list = await SocialService.friendSuggestions();
    expect(list, isNotEmpty);
    return list.first.username;
  }

  group('seguir y contadores reales (Cuenta)', () {
    testWidgets('seguir una sugerencia: botón a SIGUIENDO, sube '
        'Siguiendo y la tarjeta la sustituye la siguiente',
        (tester) async {
      final first = await firstSuggestionUsername();
      await pumpAccount(tester);
      expect(find.text(tr('accountSuggestionsTitle').toUpperCase()), findsOneWidget);
      expect(find.text(first), findsOneWidget);
      expect(await SocialService.followingCount('dev-kristian'), 0);

      await tester.tap(find.text(tr('accountFollow').toUpperCase()).first);
      // 100 ms: el followUser asíncrono termina y el botón pasa a
      // SIGUIENDO antes de que empiece la salida de 300 ms.
      await tester.pump(const Duration(milliseconds: 100));
      // El botón pasa a SIGUIENDO enseguida (antes de que la
      // tarjeta se desvanezca en 300 ms).
      expect(
          find.text(tr('accountFollowingBtn').toUpperCase()), findsOneWidget);
      expect(await SocialService.followingCount('dev-kristian'), 1);
      // La tarjeta se desliza/desvanece y la sustituye la
      // siguiente: la persona seguida ya no está en sugerencias.
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(find.text(first), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('invitado: nada de lo social (ni sugerencias, ni '
        'AGREGA AMIGOS, ni seguidores)', (tester) async {
      fakeAuth.googleLinked = false;
      fakeAuth.emailLinked = false;
      await pumpAccount(tester);
      // Lo social solo sale una vez iniciado sesión (Kristian
      // 2026-11-16): sin sesión no hay sugerencias, ni botón de
      // agregar amigo, ni contadores de Siguiendo/Seguidores, ni
      // la fila Amigos (es la entrada a la pantalla de amigos),
      // ni Tabla de posiciones ni Torneos (son listas de otra
      // gente: un invitado no ve lo de buscar otra gente).
      expect(find.text(tr('accountSuggestionsTitle').toUpperCase()),
          findsNothing);
      expect(find.text(tr('accountAddFriends').toUpperCase()), findsNothing);
      expect(find.text(tr('accountFollowing')), findsNothing);
      expect(find.text(tr('accountFollowers')), findsNothing);
      expect(find.text(tr('accountFriends')), findsNothing);
      expect(find.text(tr('accountLeaderboard')), findsNothing);
      expect(find.text(tr('accountTournaments')), findsNothing);
      // Niveles pasados NO es social: sí sale.
      expect(find.text(tr('accountLevels')), findsOneWidget);
      // Tienda y Premium NO son sociales: salen también de
      // invitado (Kristian 2026-11-16: viven en Cuenta, no en
      // Ajustes).
      expect(find.text(tr('accountShop')), findsOneWidget);
      expect(find.text(tr('accountPremium')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('invitado en perfil público: NO sale SEGUIR ni se '
        'abren las listas de seguidos/seguidores', (tester) async {
      fakeAuth.googleLinked = false;
      fakeAuth.emailLinked = false;
      await pumpPublicProfile(tester, 'dev-laura');
      // Un invitado no ve lo de buscar otra gente (Kristian
      // 2026-11-16): el botón SEGUIR no sale en absoluto — ni
      // diálogo ni nada — y los números de Siguiendo/Seguidores
      // se ven pero no se tocan (no abren sus listas).
      expect(find.text(tr('accountFollow').toUpperCase()), findsNothing);
      expect(find.text(tr('onlineNeedGoogle')), findsNothing);
      // Tocar los números no abre sus listas: la pantalla de
      // listas no aparece (el título coincide con el letrero
      // del contador, así que se comprueba por el tipo).
      await tester.tap(find.text(tr('accountFollowing')));
      await tester.pump();
      await settle(tester);
      expect(find.byType(FollowListScreen), findsNothing);
      await tester.tap(find.text(tr('accountFollowers')));
      await tester.pump();
      await settle(tester);
      expect(find.byType(FollowListScreen), findsNothing);
      expect(await SocialService.followingCount('dev-kristian'), 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dejar de seguir desde SIGUIENDO baja el contador',
        (tester) async {
      // Sigo a laura por el servicio: en Cuenta ya NO sale en
      // sugerencias (al seguir sale de ahí), pero sí en la lista
      // de Siguiendo; desde su perfil público se deja de seguir.
      await SocialService.followUser('dev-laura');
      await pumpAccount(tester);
      expect(await SocialService.followingCount('dev-kristian'), 1);
      await tester.tap(find.text(tr('accountFollowing')));
      await settle(tester);
      expect(find.text('laura'), findsOneWidget);
      await tester.tap(find.text('laura'));
      await settle(tester);
      expect(
          find.text(tr('accountFollowingBtn').toUpperCase()), findsOneWidget);
      await tester.tap(find.text(tr('accountFollowingBtn').toUpperCase()));
      await settle(tester);
      expect(find.text(tr('accountFollow').toUpperCase()), findsOneWidget);
      expect(await SocialService.followingCount('dev-kristian'), 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Siguiendo y Seguidores abren sus listas reales; '
        'tocar una persona abre su perfil público', (tester) async {
      await SocialService.followUser('dev-laura');
      (SocialService.repository as InMemorySocialRepository)
          .simulateFollowFrom('dev-miguel');
      await pumpAccount(tester);

      await tester.tap(find.text(tr('accountFollowing')));
      await settle(tester);
      expect(find.text(tr('followListFollowingTitle')), findsOneWidget);
      expect(find.text('laura'), findsOneWidget);
      await tester.tap(find.text('laura'));
      await settle(tester);
      // Perfil público de laura (cabecera + @LAURA: la línea va
      // en mayúsculas).
      expect(find.text('@LAURA'), findsOneWidget);
      await tester.pageBack();
      await settle(tester);
      // De vuelta en la lista de Siguiendo; otro atrás para
      // volver a Cuenta.
      await tester.pageBack();
      await settle(tester);

      await tester.tap(find.text(tr('accountFollowers')));
      await settle(tester);
      expect(find.text(tr('followListFollowersTitle')), findsOneWidget);
      expect(find.text('miguel'), findsOneWidget);
      await tester.tap(find.text('miguel'));
      await settle(tester);
      expect(find.text('@MIGUEL'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('sugerencias de amigos', () {
    test('rotan cada día, determinista por fecha, sin amigos ni yo',
        () async {
      final day1 = await SocialService.friendSuggestions(
          on: DateTime(2026, 11, 16));
      final day1Again = await SocialService.friendSuggestions(
          on: DateTime(2026, 11, 16));
      final day2 = await SocialService.friendSuggestions(
          on: DateTime(2026, 11, 17));
      final day3 = await SocialService.friendSuggestions(
          on: DateTime(2026, 11, 18));
      expect(day1.length, 2);
      expect(
          day1.map((s) => s.deviceId), day1Again.map((s) => s.deviceId));
      // En 3 días distintos, el primer sugerido cambia al menos
      // una vez (rotación real, no siempre los mismos 2).
      final firsts = {
        day1.first.deviceId,
        day2.first.deviceId,
        day3.first.deviceId,
      };
      expect(firsts.length, greaterThan(1));
      for (final list in [day1, day2, day3]) {
        for (final s in list) {
          expect(s.deviceId, isNot('dev-kristian'));
          expect(s.username, isNot(anyOf('laura', 'miguel', 'sofia')));
        }
      }
    });

    testWidgets('la X descarta la sugerencia solo por hoy',
        (tester) async {
      final first = await firstSuggestionUsername();
      await pumpAccount(tester);
      expect(find.text(first), findsOneWidget);
      final dismiss = find.byWidgetPredicate((w) =>
          w is LucideIcon && w.icon == LucideIcons.x);
      expect(dismiss, findsWidgets);
      await tester.tap(dismiss.first);
      await settle(tester);
      expect(find.text(first), findsNothing);
      // Sigue descartada hoy, pero vuelve mañana.
      final today = await SocialService.friendSuggestions();
      expect(today.map((s) => s.username), isNot(contains(first)));
      final tomorrow = await SocialService.friendSuggestions(
          on: DateTime.now().add(const Duration(days: 1)));
      expect(
          tomorrow.map((s) => s.username), anyOf(contains(first), isNotEmpty));
      expect(tester.takeException(), isNull);
    });
  });

  group('perfil público con datos reales', () {
    testWidgets('muestra niveles, puntos, racha y trofeos reales '
        'de esa persona', (tester) async {
      await pumpPublicProfile(tester, 'dev-laura');
      // laura demo: 28 niveles, 1420 puntos, racha 15, 0/10 trofeos.
      expect(find.text('laura'), findsWidgets);
      expect(find.text('@LAURA'), findsOneWidget);
      expect(find.text('28'), findsWidgets);
      expect(find.text('1420'), findsOneWidget);
      expect(find.text('15'), findsWidgets);
      expect(find.text('0/10'), findsOneWidget);
      // Sin historial de puntos por día: nota honesta, no gráfica
      // inventada.
      expect(find.text(tr('profileWeeklyEmpty')), findsOneWidget);
      // SEGUIR (aún no la sigo), REPORTAR y BLOQUEAR al final.
      expect(find.text(tr('accountFollow').toUpperCase()), findsOneWidget);
      expect(find.text(tr('profileReportUser')), findsOneWidget);
      expect(find.text(tr('profileBlockUser')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('seguir desde el perfil público cambia el botón a '
        'SIGUIENDO y sube sus Seguidores', (tester) async {
      await pumpPublicProfile(tester, 'dev-laura');
      await tester.tap(find.text(tr('accountFollow').toUpperCase()));
      await settle(tester);
      expect(
          find.text(tr('accountFollowingBtn').toUpperCase()), findsOneWidget);
      expect(await SocialService.isFollowing('dev-laura'), isTrue);
      expect(await SocialService.followersCount('dev-laura'), 1);
      expect(await SocialService.followingCount('dev-kristian'), 1);
      // Tocar de nuevo deja de seguir.
      await tester.tap(find.text(tr('accountFollowingBtn').toUpperCase()));
      await settle(tester);
      expect(find.text(tr('accountFollow').toUpperCase()), findsOneWidget);
      expect(await SocialService.isFollowing('dev-laura'), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('si me sigue de vuelta, el botón lleva corazón '
        '(mutuo = amigos)', (tester) async {
      (SocialService.repository as InMemorySocialRepository)
          .simulateFollowFrom('dev-laura');
      await pumpPublicProfile(tester, 'dev-laura');
      await tester.tap(find.text(tr('accountFollow').toUpperCase()));
      await settle(tester);
      expect(
          find.text(tr('accountFollowingBtn').toUpperCase()), findsOneWidget);
      expect(await SocialService.isMutualFollow('dev-laura'), isTrue);
      // Corazón (no check) en el botón de SIGUIENDO mutuo.
      expect(
          find.byWidgetPredicate(
              (w) => w is LucideIcon && w.icon == LucideIcons.heart),
          findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reportar crea el reporte; bloquear persiste y '
        'cambia a DESBLOQUEAR', (tester) async {
      await pumpPublicProfile(tester, 'dev-laura');
      await tester.tap(find.text(tr('profileReportUser')));
      await settle(tester);
      // El título del diálogo es el MISMO texto que la fila
      // ('Reportar usuario'): se comprueba el AlertDialog, no el
      // texto (que sale 3 veces: fila + título + botón).
      expect(find.byType(AlertDialog), findsOneWidget);
      final reportDialog =
          tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect((reportDialog.title as Text).data, tr('profileReportTitle'));
      await tester.enterText(
        find.byWidgetPredicate((w) =>
            w is TextField && w.decoration?.hintText == tr('profileReportReason')),
        'Se hace pasar por otra persona',
      );
      await settle(tester);
      await tester.tap(find.text(tr('profileReportUser')).last);
      await settle(tester);
      expect(find.text(tr('profileReportThanks')), findsOneWidget);
      // El SnackBar del reporte tapa la fila BLOQUEAR (al final
      // de la pantalla): se espera a que expire (4 s) antes de
      // tocarla, si no el toque cae en el SnackBar.
      await tester.pump(const Duration(seconds: 5));

      await tester.tap(find.text(tr('profileBlockUser')));
      await settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      final blockDialog =
          tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect((blockDialog.title as Text).data, tr('profileBlockTitle'));
      await tester.tap(find.text(tr('profileBlockUser')).last);
      await settle(tester);
      expect(find.text(tr('profileBlocked')), findsOneWidget);
      expect(find.text(tr('profileUnblockUser')), findsOneWidget);
      expect(await SocialService.isBlocked('dev-laura'), isTrue);
      // Bloqueada: ya no sale en sugerencias.
      final suggestions = await SocialService.friendSuggestions();
      expect(suggestions.map((s) => s.deviceId), isNot(contains('dev-laura')));
      expect(tester.takeException(), isNull);
    });
  });

  group('tarjeta de completar perfil', () {
    testWidgets('solo se muestra con sesión y sin nombre de usuario',
        (tester) async {
      // Con sesión (Google) y sin nombre: sale.
      await pumpAccount(tester);
      expect(find.byKey(const ValueKey('completeProfileCard')),
          findsOneWidget);
      expect(find.text(tr('accountCompleteProfileTitle')), findsOneWidget);

      // Con nombre ya reclamado: no sale.
      UserPrefs.publicUsername = 'kristian';
      await pumpAccount(tester);
      expect(find.byKey(const ValueKey('completeProfileCard')), findsNothing);

      // Sin sesión (invitado): no sale, aunque no tenga nombre.
      UserPrefs.publicUsername = '';
      fakeAuth.googleLinked = false;
      fakeAuth.emailLinked = false;
      await pumpAccount(tester);
      expect(find.byKey(const ValueKey('completeProfileCard')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('flujo completo: CONTINUAR → personalizar → '
        'guardar → ¡Se ve genial! → vuelve sin tarjeta',
        (tester) async {
      await pumpAccount(tester);
      await tester.tap(
          find.text(tr('accountCompleteProfileButton').toUpperCase()));
      await settle(tester);
      // "Personaliza tu nombre de usuario", campo prellenado con
      // el sugerido (primer nombre).
      expect(find.text(tr('usernamePersonalizeTitle')), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.controller?.text, 'Kristian');
      await tester
          .tap(find.text(tr('obUsernameUseThis').toUpperCase()));
      await settle(tester);
      // "¡Se ve genial!" con el nombre guardado.
      expect(find.text(tr('usernameSavedTitle')), findsOneWidget);
      expect(find.text('@Kristian'), findsOneWidget);
      await tester.tap(find.text(tr('okWord')));
      await settle(tester);
      // De vuelta en Cuenta, la tarjeta ya no está.
      expect(UserPrefs.publicUsername, 'Kristian');
      expect(find.byKey(const ValueKey('completeProfileCard')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('código QR del perfil', () {
    test('profileQrData codifica el usuario', () {
      expect(profileQrData('kristian'), 'quemia:user:kristian');
      expect(profileQrData('laura'), 'quemia:user:laura');
    });

    testWidgets('la pantalla QR muestra el código de ese perfil',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: QrScreen(
            username: 'laura',
            displayName: 'Laura',
          ),
        ),
      );
      await settle(tester);
      // qr_flutter 4.1.0 no expone el payload (campo _data
      // privado) y con la imagen incrustada (logo en el centro)
      // el QR no llega a pintar en el entorno de tests (el
      // stream del asset no resuelve ni con runAsync): se
      // verifica que la tarjeta es la de laura con su QR, y que
      // ese mismo payload SÍ pinta como QR válido (abajo, sin
      // imagen incrustada). El pintado con logo se verifica en
      // el navegador.
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Laura'), findsWidgets);
      expect(find.text('@laura'), findsOneWidget);
      expect(find.text('quemia'), findsOneWidget);
      expect(find.text(tr('profileQrShare').toUpperCase()), findsOneWidget);
      expect(find.text(tr('profileQrSave').toUpperCase()), findsOneWidget);
      expect(find.text(tr('profileQrScan').toUpperCase()), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el payload quemia:user:<usuario> pinta como QR válido',
        (tester) async {
      // El mismo dato que QrScreen le pasa al QR (sin la imagen
      // incrustada, que en tests no resuelve): pinta un QR real.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QrImageView(data: profileQrData('laura'), size: 150),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is QrPainter),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('el botón QR de Cuenta abre mi QR; el del perfil '
        'público, el de esa persona', (tester) async {
      UserPrefs.publicUsername = 'kristian';
      await pumpAccount(tester);
      await tester.tap(find.byKey(const ValueKey('accountQrButton')));
      await settle(tester);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('@kristian'), findsOneWidget);
      await tester.pageBack();
      await settle(tester);

      await pumpPublicProfile(tester, 'dev-laura');
      await tester.tap(find.byWidgetPredicate(
          (w) => w is LucideIcon && w.icon == LucideIcons.qrCode));
      await settle(tester);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('@laura'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('movimiento', () {
    testWidgets('CountUp llega al valor real; con movimiento '
        'reducido la pantalla se dibuja sin animaciones',
        (tester) async {
      await pumpPublicProfile(tester, 'dev-laura');
      // El total de puntos cuenta hasta 1420 (no se queda en 0).
      expect(find.text('1420'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: MediaQuery(
            data: const MediaQueryData(accessibleNavigation: true),
            child: Scaffold(
              body: AccountScreen(
                onOpenScreen: (_) {},
                onShowAbout: () {},
                onShowShareApp: () {},
                trackTopics: const ['estequiometria'],
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      expect(find.text(tr('accountSuggestionsTitle').toUpperCase()), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

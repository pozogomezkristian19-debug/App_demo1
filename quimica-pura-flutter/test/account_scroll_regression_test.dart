// Regresión del rectángulo gris de Cuenta (verificado en vivo
// 2026-11-16, tema claro): al subir 3 páginas de golpe desde el
// final, la zona del perfil (avatar, nombre, contadores) quedaba
// como un rectángulo gris sólido y no se repintaba.
//
// CAUSA RAÍZ (no un parche): la fila de contadores era un
// StreamBuilder<List<FriendEntry>>(stream:
// SocialService.friendsStream()) dentro del ListView. El
// SliverChildListDelegate reutiliza LA MISMA instancia del widget
// al recrear el hijo tras un scroll rápido, así que el remontaje
// se suscribía una segunda vez al MISMO stream de una sola
// suscripción → "Bad state: Stream has already been listened to"
// en _StreamBuilderBaseState.initState → el layout abortaba y en
// release la zona fallida se pintaba gris. Se arregló en la capa
// de datos (streams broadcast con replay) Y en la UI (la fila ya
// no usa friendsStream(): los contadores vienen del estado, de
// los conteos de seguir).
//
// Este test flinguea la Cuenta real 3× abajo/arriba y exige que
// no salte ninguna excepción y que la cabecera siga en el árbol
// con su tamaño real. Expectativas del lote 2026-11-16: el nombre
// sale UNA sola vez (debajo del avatar, no en la cabecera) y los
// contadores son los de seguir (no de amigos).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/account_screen.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/auth_service.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/social_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/social_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    UserPrefs.rulesSeenV6 = true;
    UserPrefs.onboardingDone = true;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.userName = 'Kristian Pozo';
    UserPrefs.publicUsername = 'kristian';
    AppLang.code = 'es';
    final fakeAuth = FakeAuthProvider()
      ..uid = 'dev-kristian'
      ..googleLinked = true
      ..email = 'kristian@example.com'
      ..displayName = 'Kristian Pozo';
    AuthService.setProviderForTests(fakeAuth);
    SocialService.setRepositoryForTests(
        InMemorySocialRepository(seedDemo: true));
    AnalyticsSync.setRepositoryForTests(InMemoryAnalyticsRepository());
    addTearDown(() {
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

  testWidgets('la cabecera sobrevive a flings rápidos sin gris',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
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
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    final listFinder = find.byType(ListView).first;
    // Baja de golpe hasta el final y sube de golpe hasta arriba,
    // varias veces (como la verificación en vivo). Pumps acotados
    // (no pumpAndSettle): la pantalla tiene animaciones en bucle.
    for (var i = 0; i < 3; i++) {
      await tester.fling(listFinder, const Offset(0, -3000), 8000);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.fling(listFinder, const Offset(0, 3000), 8000);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }
    // El defecto original: "Bad state: Stream has already been
    // listened to" al remontar el StreamBuilder tras el scroll.
    expect(tester.takeException(), isNull);
    // La cabecera sigue en el árbol y con tamaño real (no gris).
    final bigAvatar = find.byWidgetPredicate(
      (w) => w is SocialAvatar && w.size == 160,
    );
    expect(bigAvatar, findsOneWidget);
    final avatarSize = tester.getSize(bigAvatar);
    expect(avatarSize.width, 160);
    expect(avatarSize.height, 160);
    // El nombre vive en la cabecera (AccountProfilePage), no en
    // el cuerpo: aquí sobrevive la línea @usuario · año.
    expect(find.text('@KRISTIAN'), findsOneWidget);
    // Los contadores son los de seguir (no el stream de amigos).
    expect(find.text(tr('accountFollowing')), findsOneWidget);
    expect(find.text(tr('accountFollowers')), findsOneWidget);
  });
}

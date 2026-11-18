// Acerca de (Quemia 7.7): la hoja muestra el número de soporte REMOTO,
// el que el creador cambia desde la app de Administrador (ajustes
// remotos, 'supportNumber'); sin remoto, el número por defecto
// +5356519431. El Soporte (mensajería) se eliminó en la 7.7, pero el
// número en Acerca de sigue. Extraído de fix8_support_test.dart
// (el resto de ese archivo probaba la ventanita de Soporte, borrada).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/account_screen.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

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
    AnalyticsSync.resetForTests();
  });

  tearDown(() {
    AnalyticsSync.resetForTests();
  });

  Future<void> pumpHome(WidgetTester tester) async {
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
        home: HomeScreen(
          isDark: false,
          onToggleTheme: () {},
          onTrackChanged: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Abre la hoja "Acerca de" desde Ajustes (sección SOPORTE).
  /// 2026-11-16 (perfil estilo Duolingo): "Acerca de" vive en
  /// Ajustes; la puerta es el engranaje de arriba del perfil.
  Future<void> openAboutSheet(WidgetTester tester) async {
    // 2026-11-17: Cuenta ya NO es pestaña — se abre con el botón
    // de perfil de la barra de arriba.
    await tester.tap(find.byKey(const ValueKey('topBarProfileButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AccountProfilePage), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('accountSettingsButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.text(tr('accountAbout')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(tr('accountAbout')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('Acerca de: la hoja muestra el número remoto', () {
    testWidgets('con número remoto, muestra ese número', (tester) async {
      final repo = InMemoryAnalyticsRepository()
        ..settings = {
          'supportNumber': '+53 5 9999999',
        };
      AnalyticsSync.setRepositoryForTests(repo);
      AnalyticsSync.markFirebaseReady();
      await pumpHome(tester);
      await openAboutSheet(tester);
      expect(find.text('${tr('phoneWord')}: +53 59999999'), findsOneWidget);
    });

    testWidgets('sin remoto (sin internet), muestra el número por defecto',
        (tester) async {
      await pumpHome(tester);
      await openAboutSheet(tester);
      expect(find.text('${tr('phoneWord')}: +53 56519431'), findsOneWidget);
    });
  });
}

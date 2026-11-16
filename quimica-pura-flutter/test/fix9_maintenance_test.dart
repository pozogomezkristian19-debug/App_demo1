// Modo mantenimiento (2026-11-15): el panel de Admin escribe
// 'maintenanceMode' + 'maintenanceMessage' en 'settings/app'; la app
// principal los lee al abrir (RemoteTuning) y, si el modo está
// activo, muestra la pantalla de mantenimiento en vez de la app
// normal. REINTENTAR vuelve a leer los ajustes y entra si el modo
// ya está apagado. Sin internet la app abre normal (el modo queda
// como estaba, apagado si nunca se leyó).

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/practicar_screen.dart';
import 'package:quimica_pura/services/analytics_sync.dart';
import 'package:quimica_pura/services/auth_service.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/remote_tuning.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/maintenance_screen.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadRobotoFonts();
    await loadNunitoFonts();
  });

  late FakeAuthProvider fakeAuth;
  late InMemoryAnalyticsRepository fakeRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global/events'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (call) async => null,
    );
    UserPrefs.rulesSeenV6 = true;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    await UserPrefs.saveThemeMode('claro');
    UserPrefs.isDark = false;
    UserPrefs.onboardingDone = true;
    UserPrefs.userName = 'kristian';
    RemoteTuning.resetForTests();
    fakeAuth = FakeAuthProvider();
    AuthService.setProviderForTests(fakeAuth);
    fakeRepo = InMemoryAnalyticsRepository();
    AnalyticsSync.setRepositoryForTests(fakeRepo);
  });

  tearDown(() {
    AnalyticsSync.resetForTests();
    AuthService.resetForTests();
    RemoteTuning.resetForTests();
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = false;
    UserPrefs.isDark = false;
    UserPrefs.userName = '';
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 2, 800 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MelliQuiApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
  }

  group('RemoteTuning: modo mantenimiento', () {
    test('apply lee maintenanceMode y maintenanceMessage', () {
      RemoteTuning.apply(<String, dynamic>{
        'maintenanceMode': true,
        'maintenanceMessage': 'Volvemos en una hora.',
      });
      expect(RemoteTuning.maintenanceMode, isTrue);
      expect(RemoteTuning.maintenanceMessage, 'Volvemos en una hora.');
    });

    test('por defecto el modo está apagado con el mensaje local', () {
      expect(RemoteTuning.maintenanceMode, isFalse);
      expect(RemoteTuning.maintenanceMessage,
          'Quemia está en mantenimiento. Vuelve pronto.');
    });

    test('valores rotos no cambian nada', () {
      RemoteTuning.apply(<String, dynamic>{
        'maintenanceMode': 'sí',
        'maintenanceMessage': '   ',
      });
      expect(RemoteTuning.maintenanceMode, isFalse);
      expect(RemoteTuning.maintenanceMessage,
          'Quemia está en mantenimiento. Vuelve pronto.');
    });

    test('resetForTests apaga el modo', () {
      RemoteTuning.apply(<String, dynamic>{
        'maintenanceMode': true,
        'maintenanceMessage': 'Volvemos en una hora.',
      });
      RemoteTuning.resetForTests();
      expect(RemoteTuning.maintenanceMode, isFalse);
      expect(RemoteTuning.maintenanceMessage,
          'Quemia está en mantenimiento. Vuelve pronto.');
    });
  });

  group('pantalla de mantenimiento en la app', () {
    testWidgets('con el modo activo muestra el mensaje del servidor',
        (tester) async {
      fakeRepo.settings = <String, dynamic>{
        'maintenanceMode': true,
        'maintenanceMessage': 'Volvemos en una hora.',
      };
      await pumpApp(tester);
      expect(find.byType(MaintenanceScreen), findsOneWidget);
      expect(find.text('Volvemos en una hora.'), findsOneWidget);
      expect(find.text(tr('maintenanceTitle')), findsOneWidget);
      expect(find.text(tr('maintenanceRetry')), findsOneWidget);
      expect(find.byType(PracticarScreen), findsNothing);
    });

    testWidgets('sin el modo activo abre la principal normal', (tester) async {
      fakeRepo.settings = <String, dynamic>{'maintenanceMode': false};
      await pumpApp(tester);
      expect(find.byType(MaintenanceScreen), findsNothing);
      expect(find.byType(PracticarScreen), findsOneWidget);
    });

    testWidgets('REINTENTAR entra cuando el modo ya está apagado',
        (tester) async {
      fakeRepo.settings = <String, dynamic>{
        'maintenanceMode': true,
        'maintenanceMessage': 'Volvemos en una hora.',
      };
      await pumpApp(tester);
      expect(find.byType(MaintenanceScreen), findsOneWidget);
      fakeRepo.settings = <String, dynamic>{'maintenanceMode': false};
      await tester.tap(find.text(tr('maintenanceRetry')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(MaintenanceScreen), findsNothing);
      expect(find.byType(PracticarScreen), findsOneWidget);
    });

    testWidgets('si los ajustes fallan la app abre normal', (tester) async {
      fakeRepo.failSettings = true;
      await pumpApp(tester);
      expect(find.byType(MaintenanceScreen), findsNothing);
      expect(find.byType(PracticarScreen), findsOneWidget);
    });
  });
}

// Vistas previas de la ronda #5, punto 3 (Quemia 6.2): la Tabla
// periódica en modo normal como PÁGINA CON SCROLL.
// Se ejecuta con --update-goldens para ESCRIBIR los PNG en
// ~/workspace/melli-qui-v6-previews/ (nombres fix5_tabla_*).
// Viewport de ALTURA REAL DE TELÉFONO: 400 dp de ancho x 852 dp de
// alto (el Redmi de Kristian, ~393x852), dpr 2, Roboto real. Las
// dos capturas de 400 usan la app REAL (MelliQuiApp) con su barra
// de arriba y su barra de navegación de verdad — que es lo que
// come altura en el teléfono — para que un recorte como el de la
// 6.1 no se vuelva a esconder: arriba se ve la parte superior y
// desplazada muestra las filas de abajo + la leyenda.
// Los PNG se leen y se verifican a mano antes de informar.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/screens/tabla_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/widgets/main_bottom_nav.dart';
import 'package:quimica_pura/services/notification_inbox.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadRobotoFonts();
    await loadMaterialIcons();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressService.load();
    await NotificationInbox.load();
    // Sin mock, el AudioPlayer estático de SoundService activa el
    // stream global de audioplayers y lanza MissingPluginException
    // (error asíncrono que el test reporta como fallo).
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
  });

  tearDown(() {
    UserPrefs.rulesSeenV6 = false;
    UserPrefs.themeAccent = 'verde';
    UserPrefs.themeAccentNotifier.value = 'verde';
    UserPrefs.onboardingDone = false;
    UserPrefs.isDark = false;
    NotificationInbox.resetForTests();
  });

  Future<void> setPhone(
    WidgetTester tester, {
    double width = 400,
    double height = 852,
  }) async {
    tester.view.physicalSize = Size(width * 2, height * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../melli-qui-v6-previews/$name'),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
  }

  /// El Scrollable VERTICAL de la página de Tabla (el primero con
  /// eje hacia abajo: el de la rejilla queda dentro de él y el de
  /// los chips va en horizontal).
  Finder pageScrollable(WidgetTester tester) => find
      .byWidgetPredicate((w) =>
          w is Scrollable && w.axisDirection == AxisDirection.down)
      .first;

  /// App real a 400x852 y pestaña Tabla: la captura reproduce lo
  /// que ve Kristian (barra de arriba + barra de navegación).
  Future<void> pumpAppTabla(WidgetTester tester) async {
    await setPhone(tester, width: 400, height: 852);
    await tester.pumpWidget(const MelliQuiApp());
    await settle(tester);
    await tester.tap(find.descendant(
      of: find.byType(MainBottomNav),
      matching: find.text(tr('tabTable')),
    ));
    await tester.pump();
    // Cambio de pestaña con fundido (AnimatedSwitcher, 250 ms).
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('fix5_tabla_400_arriba: Tabla a 400x852, parte superior',
      (tester) async {
    await pumpAppTabla(tester);
    await shot(tester, 'fix5_tabla_400_arriba.png');
  });

  testWidgets(
      'fix5_tabla_400_desplazada: misma pantalla desplazada, filas '
      'de abajo + leyenda', (tester) async {
    await pumpAppTabla(tester);
    await tester.scrollUntilVisible(
      find.text('118 ${tr('elementsWord')}.'),
      300,
      scrollable: pageScrollable(tester),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, 'fix5_tabla_400_desplazada.png');
  });

  testWidgets('fix5_tabla_320: teléfono angosto, todas las filas',
      (tester) async {
    await setPhone(tester, width: 320, height: 2000);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(body: TablaScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, 'fix5_tabla_320.png');
  });
}

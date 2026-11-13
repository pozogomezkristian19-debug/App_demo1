// Vistas previas de la ronda #5, punto extra (Quemia 6.2) +
// rediseño Tabla 2026-11-12 (mockup flotante aprobado): los
// botones flotantes Comparar + Quiz SOLO con filtro "Todos".
// Se ejecuta con --update-goldens para ESCRIBIR los PNG en
// ~/workspace/melli-qui-v6-previews/ (nombres fix5_tabla_todos.png
// y fix5_tabla_filtro.png). Viewport de teléfono real: 400 dp de
// ancho x 852 dp de alto (el Redmi de Kristian, ~393x852), dpr 2,
// Roboto real. Las dos capturas usan la app REAL (MelliQuiApp)
// con su barra de arriba y su barra de navegación de verdad.
// Los PNG se leen y se verifican a mano antes de informar.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/main.dart';
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

  testWidgets('fix5_tabla_todos: filtro Todos, los dos flotantes '
      'visibles abajo a la derecha', (tester) async {
    await pumpAppTabla(tester);
    expect(find.text(tr('quizShort')), findsOneWidget);
    expect(find.text(tr('compareShort')), findsOneWidget);
    await shot(tester, 'fix5_tabla_todos.png');
  });

  testWidgets('fix5_tabla_filtro: filtro Metal alcalino, flotantes '
      'ocultos y lista filtrada arriba', (tester) async {
    await pumpAppTabla(tester);
    await tester.tap(
      find.widgetWithText(ChoiceChip, 'Metal alcalino'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(tr('quizShort')), findsNothing);
    expect(find.text(tr('compareShort')), findsNothing);
    expect(find.text('6 ${tr('elementsWord')}'), findsOneWidget);
    await shot(tester, 'fix5_tabla_filtro.png');
  });
}

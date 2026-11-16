// Inicio sin deslizar + atrás del teléfono (Kristian 2026-11-15):
// las pantallas de bienvenida solo cambian con los botones, nunca
// deslizando, y el atrás del teléfono vuelve un paso dentro del
// inicio en vez de salirse de la app. En "Ya tengo mi cuenta" el
// atrás vuelve a la elección. El aviso también tiene flecha atrás
// (antes solo se volvía deslizando).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/onboarding_screen.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/brand_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

ThemeData _lightTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.light(
        primary: BrandColors.teal,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: BrandColors.ink,
        surfaceContainerHighest: BrandColors.cardGray,
        error: const Color(0xFFFF4B4B),
      ),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserPrefs.load();
    AppLang.code = 'es';
  });

  Future<void> pumpInicio(WidgetTester tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _lightTheme(),
        home: OnboardingScreen(key: UniqueKey(), onFinished: () {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Atrás del teléfono (PopScope).
  Future<void> atras(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  /// Camino con botones hasta el aviso (igual que en
  /// zone_e_onboarding_test.dart).
  Future<void> goToNudge(WidgetTester tester) async {
    await tester.tap(find.text(tr('obContinue').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obCreateProfile').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obVamos').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obSourceInstagram')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obContinue').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obLevel1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obContinue').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obGoal10')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obGoalSave').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obNotifEnable').toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text('Ir a Ajustes'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obStreakStart').toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text(tr('obNudgeTitle')), findsOneWidget);
  }

  testWidgets('deslizar no cambia de pantalla en el inicio',
      (tester) async {
    await pumpInicio(tester);
    expect(find.text(tr('obContinue').toUpperCase()), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    // Sigue en la Bienvenida: el botón CONTINUAR sigue ahí y la
    // Elección no apareció.
    expect(find.text(tr('obContinue').toUpperCase()), findsOneWidget);
    expect(find.text(tr('obChoiceTitle')), findsNothing);
    // En la Elección tampoco se desliza.
    await tester.tap(find.text(tr('obContinue').toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text(tr('obChoiceTitle')), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text(tr('obChoiceTitle')), findsOneWidget);
    expect(find.text(tr('obBrendaHello')), findsNothing);
  });

  testWidgets('el atrás del teléfono vuelve un paso en el inicio',
      (tester) async {
    await pumpInicio(tester);
    await tester.tap(find.text(tr('obContinue').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obCreateProfile').toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text(tr('obBrendaHello')), findsOneWidget);
    await atras(tester);
    expect(find.text(tr('obChoiceTitle')), findsOneWidget);
    await atras(tester);
    expect(find.text(tr('obContinue').toUpperCase()), findsOneWidget);
  });

  testWidgets("el atrás en 'Ya tengo mi cuenta' vuelve a la elección",
      (tester) async {
    await pumpInicio(tester);
    await tester.tap(find.text(tr('obContinue').toUpperCase()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('obEnterAccount')));
    await tester.pumpAndSettle();
    expect(find.text(tr('obSignInTitle')), findsOneWidget);
    await atras(tester);
    expect(find.text(tr('obChoiceTitle')), findsOneWidget);
    expect(find.text(tr('obSignInTitle')), findsNothing);
  });

  testWidgets('el aviso tiene flecha atrás y vuelve a la racha',
      (tester) async {
    await pumpInicio(tester);
    await goToNudge(tester);
    // La flecha atrás está (antes no había: solo se volvía
    // deslizando) y es el único IconButton de la página.
    expect(find.byType(IconButton), findsOneWidget);
    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();
    expect(find.text(tr('obStreakStart').toUpperCase()), findsOneWidget);
    expect(find.text(tr('obNudgeTitle')), findsNothing);
  });
}

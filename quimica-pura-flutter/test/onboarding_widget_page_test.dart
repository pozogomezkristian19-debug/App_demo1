// Pantalla que pide el widget en el registro (2026-11-18, diseño
// v3 aprobado por Kristian: tarjeta con la miniatura del
// widget, título, cuerpo, AGREGAR WIDGET + MÁS TARDE).
// La pantalla NO es obligatoria: con MÁS TARDE se avanza igual.
// AGREGAR WIDGET abre el diálogo del sistema para fijar el widget;
// si el sistema no lo muestra (o no hay canal nativo, como en
// tests), se avanza igual.
//
// OJO: los canales 'home_widget' y 'com.melliqui/app_widget' van
// con mock, como en fix4_widget_tip_test: sin mock, la llamada al
// canal se queda colgada en un widget test montado y el botón
// AGREGAR nunca avanza (el tap sí dispara _add, pero update() no
// vuelve). Con mock, saveWidgetData/updateWidget devuelven true y
// requestPin devuelve false (sin soporte en tests).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/onboarding_widget_page.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadNunitoFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserPrefs.load();
    await ProgressService.load();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (call) async => true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.melliqui/app_widget'),
      (call) async => false,
    );
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required VoidCallback onNext,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Nunito', brightness: brightness),
        home: Scaffold(
          body: SafeArea(
            child: OnboardingWidgetPage(onNext: onNext),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('OnboardingWidgetPage', () {
    testWidgets('enseña la miniatura, el título y los dos botones',
        (tester) async {
      await pumpPage(tester, onNext: () {});
      expect(find.text('Quemia'), findsOneWidget);
      expect(find.text(tr('obWidgetTitle')), findsOneWidget);
      expect(find.text(tr('obWidgetBody')), findsOneWidget);
      expect(find.text(tr('obWidgetGoal')), findsOneWidget);
      // Perfil vacío: vidas llenas 10/10 y meta sin hacer (0/1).
      expect(find.text('10/10'), findsOneWidget);
      expect(find.text('0/1'), findsOneWidget);
      expect(find.text('AGREGAR WIDGET'), findsOneWidget);
      expect(find.text('MÁS TARDE'), findsOneWidget);
    });

    testWidgets('en tema oscuro la miniatura es oscura y se lee bien',
        (tester) async {
      await pumpPage(
        tester,
        onNext: () {},
        brightness: Brightness.dark,
      );
      // Tarjeta oscura (superficie de la app) con borde oscuro.
      final mini = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color ==
                const Color(0xFF1F2E35),
      );
      expect(mini, findsOneWidget);
      // Textos claros sobre la tarjeta oscura: título del widget y
      // la meta en casi blanco, el tip en gris claro.
      final title = tester.widget<Text>(find.text('Quemia'));
      expect(title.style?.color, const Color(0xFFF5F7FA));
      final goal = tester.widget<Text>(find.text(tr('obWidgetGoal')));
      expect(goal.style?.color, const Color(0xFFF5F7FA));
      // La barra teal, la llama, el corazón y el rayo quedan
      // iguales que en claro; los botones siguen legibles.
      expect(find.text('AGREGAR WIDGET'), findsOneWidget);
      expect(find.text('MÁS TARDE'), findsOneWidget);
      expect(find.text('10/10'), findsOneWidget);
    });

    testWidgets('MÁS TARDE avanza sin pedir nada', (tester) async {
      var advanced = false;
      await pumpPage(tester, onNext: () => advanced = true);
      await tester.tap(find.text('MÁS TARDE'));
      await tester.pumpAndSettle();
      expect(advanced, isTrue);
    });

    testWidgets('AGREGAR WIDGET avanza aunque el sistema no muestre '
        'el diálogo (sin canal nativo)', (tester) async {
      var advanced = false;
      await pumpPage(tester, onNext: () => advanced = true);
      await tester.tap(find.text('AGREGAR WIDGET'));
      // El botón es asíncrono (guardar datos + pedir el pin):
      // pumpAndSettle solo puede volver antes de que se resuelvan
      // los canales; hacen falta bombas acotadas, como al cerrar
      // un diálogo con un botón.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(advanced, isTrue);
    });
  });

  group('claves del widget en los 6 idiomas', () {
    test('obWidget* existe y no está vacío en es/en/fr/it/pt/ru', () {
      const keys = [
        'obWidgetTitle',
        'obWidgetBody',
        'obWidgetAdd',
        'obWidgetLater',
        'obWidgetGoal',
        'obWidgetGoalDone',
      ];
      final maps = AppLang.allStrings;
      expect(maps.keys.toSet(), {'es', 'en', 'fr', 'it', 'pt', 'ru'});
      for (final entry in maps.entries) {
        for (final key in keys) {
          expect(entry.value[key], isNotEmpty, reason: '${entry.key}/$key');
        }
      }
    });
  });
}

// Simulador de laboratorio, ronda fix3 punto 10 (vaso más real).
//
// Solo verifica a nivel de widget que el simulador monta en sus dos
// pestañas, que cambiar de indicador y de reacción de precipitación
// no rompe nada y que el vaso (CustomPaint) sigue presente. El
// aspecto real del vaso y los colores se verifican con las previews
// fix3 del agente de render.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/lab_sim_screen.dart';

void main() {
  group('Simulador de laboratorio (fix3 punto 10)', () {
    Future<void> pumpSim(WidgetTester tester) async {
      // Pantalla alta (800x1400): la tarjeta de resultado queda por
      // debajo del pliegue a 800x600 (el vaso mide 228 px y hay 3
      // desplegables encima), y el finder la salta como offstage
      // aunque el widget exista en el árbol. Con 1400 px todo entra
      // en la vista y los textos se ven sin hacer scroll.
      tester.view.physicalSize = const Size(800 * 2, 1400 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        const MaterialApp(home: LabSimScreen()),
      );
      await tester.pump();
    }

    testWidgets('ácido-base por defecto: pH 7 y vaso presente',
        (tester) async {
      await pumpSim(tester);
      expect(find.textContaining('pH ≈ 7.00'), findsOneWidget);
      expect(find.text('≈ 100 mL en el vaso'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('cambiar de indicador no rompe la pantalla',
        (tester) async {
      await pumpSim(tester);
      await tester.tap(find.text('Fenolftaleína'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Universal').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('pH ≈ 7.00'), findsOneWidget);
      // Azul de bromotimol: a pH 7 el líquido es verde.
      await tester.tap(find.text('Universal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Azul de bromotimol').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('pH ≈ 7.00'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('precipitación: AgCl por defecto y cambio a PbI2',
        (tester) async {
      await pumpSim(tester);
      await tester.tap(find.text('Precipitación'));
      await tester.pumpAndSettle();
      expect(find.text('Precipitado: AgCl'), findsOneWidget);
      expect(find.text('≈ 100 mL en el vaso'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      await tester.tap(find.text('AgNO₃ + NaCl'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pb(NO₃)₂ + KI').last);
      await tester.pumpAndSettle();
      expect(find.text('Precipitado: PbI₂'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}

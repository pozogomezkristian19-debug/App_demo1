// Prueba básica de Melli-Qui: la app arranca y muestra su nombre y logo.
import 'package:flutter_test/flutter_test.dart';

import 'package:quimica_pura/main.dart';

void main() {
  testWidgets('Melli-Qui arranca y muestra el logo y el nombre',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MelliQuiApp());
    await tester.pump();
    expect(find.text('Melli-Qui'), findsOneWidget);
    expect(find.text('Resolver'), findsWidgets);
  });
}

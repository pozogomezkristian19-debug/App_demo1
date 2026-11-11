import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/lab_sim_screen.dart';

void main() {
  testWidgets('probe textos del simulador', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LabSimScreen()),
    );
    await tester.pump();
    final texts = find.byType(Text).evaluate().map((e) {
      final w = e.widget as Text;
      return w.data ?? w.textSpan?.toPlainText() ?? '?';
    }).toList();
    // ignore: avoid_print
    print('TEXTOS: $texts');
  });
}

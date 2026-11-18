// Reportar pregunta: «Otro» con mensaje corto (Kristian 2026-11-17).
// La hoja tiene las 3 opciones y abajo un «Otro»; al tocarlo sale
// una caja de texto (máx. 140 caracteres, con contador) y el botón
// ENVIAR REPORTE. El mensaje viaja con el reporte (nota).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/social_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:quimica_pura/widgets/report_question.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  late InMemorySocialRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserPrefs.load();
    repo = InMemorySocialRepository();
    SocialService.setRepositoryForTests(repo);
    addTearDown(SocialService.resetForTests);
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () =>
                    showReportQuestionSheet(context, 'q-test-1'),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('la hoja enseña las 3 opciones y Otro, sin caja',
      (tester) async {
    await pumpSheet(tester);
    expect(find.text(tr('reportReasonWrong')), findsOneWidget);
    expect(find.text(tr('reportReasonUnclear')), findsOneWidget);
    expect(find.text(tr('reportReasonData')), findsOneWidget);
    expect(find.text(tr('reportReasonOther')), findsOneWidget);
    expect(find.byKey(const ValueKey('report-other-field')), findsNothing);
  });

  testWidgets('tocar Otro abre la caja con contador y Enviar apagado',
      (tester) async {
    await pumpSheet(tester);
    await tester.tap(find.text(tr('reportReasonOther')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('report-other-field')), findsOneWidget);
    expect(find.text('0/140'), findsOneWidget);
    expect(find.text(tr('reportSend').toUpperCase()), findsOneWidget);
    // Con la caja vacía, Enviar no hace nada: la hoja sigue abierta.
    await tester.tap(find.text(tr('reportSend').toUpperCase()));
    await tester.pump();
    expect(find.byKey(const ValueKey('report-other-field')), findsOneWidget);
    expect(repo.reports, isEmpty);
  });

  testWidgets('escribir y enviar manda el mensaje como nota',
      (tester) async {
    await pumpSheet(tester);
    await tester.tap(find.text(tr('reportReasonOther')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('report-other-field')));
    await tester.enterText(
        find.byKey(const ValueKey('report-other-field')),
        'La respuesta es 42, no 24');
    await tester.pump();
    expect(find.text('25/140'), findsOneWidget);
    await tester.tap(find.text(tr('reportSend').toUpperCase()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(tr('reportThanks')), findsOneWidget);
    expect(repo.reports.length, 1);
    expect(repo.reports.first.questionId, 'q-test-1');
    expect(repo.reports.first.reason, 'La respuesta es 42, no 24');
  });

  testWidgets('tocar un motivo envía directo con ese motivo',
      (tester) async {
    await pumpSheet(tester);
    await tester.tap(find.text(tr('reportReasonWrong')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(tr('reportThanks')), findsOneWidget);
    expect(repo.reports.length, 1);
    expect(repo.reports.first.reason, tr('reportReasonWrong'));
  });
}

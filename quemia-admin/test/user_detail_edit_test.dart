// Detalle de usuario: editar progreso y banear con motivo (pantalla).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quemia_admin/design.dart';
import 'package:quemia_admin/repositories.dart';
import 'package:quemia_admin/screens.dart';

import 'test_data.dart';

AdminService _service() => AdminService(
  me: ownerRecord(),
  users: FakeUsersRepository(seedUsers()),
  admins: FakeAdminsRepository(),
  settings: FakeSettingsRepository(),
);

Future<void> _pumpDetail(WidgetTester tester) async {
  // Superficie alta: el detalle es un ListView y las tarjetas de abajo
  // (edición, baneo) solo se construyen si entran en la pantalla.
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final service = _service();
  final laura = (await service.users.listUsers()).firstWhere(
    (u) => u.username == 'laura',
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: quemiaAdminTheme(),
      home: Scaffold(
        body: UserDetailScreen(user: laura, service: service),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('detalle de usuario (edición y baneo)', () {
    testWidgets('la edición viene con los valores actuales', (tester) async {
      await _pumpDetail(tester);
      expect(find.text('EDITAR PROGRESO'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).at(0)).controller?.text,
        '88',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller?.text,
        '5',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(2)).controller?.text,
        '',
      );
    });

    testWidgets('editar puntos guarda y se refleja sin recargar', (
      tester,
    ) async {
      await _pumpDetail(tester);
      await tester.enterText(find.byType(TextField).at(0), '500');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      // El diálogo de confirmación muestra el cambio.
      expect(find.textContaining('Puntos: 88 → 500'), findsOneWidget);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Progreso actualizado.'), findsOneWidget);
      // La fila de detalle (el campo de edición también lleva '500', así
      // que se busca dentro de la fila, no en toda la pantalla).
      expect(find.widgetWithText(AdminDetailRow, '500'), findsOneWidget);
      expect(find.widgetWithText(AdminDetailRow, '88'), findsNothing);
    });

    testWidgets('un valor inválido muestra el error en la misma tarjeta', (
      tester,
    ) async {
      await _pumpDetail(tester);
      await tester.enterText(find.byType(TextField).at(0), '-3');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pump();
      expect(
        find.textContaining('Los puntos tienen que ser un número entero'),
        findsOneWidget,
      );
      expect(find.text('Guardar'), findsNothing);
    });

    testWidgets('banear pide el motivo y no deja banear vacío', (
      tester,
    ) async {
      await _pumpDetail(tester);
      await tester.tap(find.widgetWithText(AdminButton, 'Banear usuario'));
      await tester.pumpAndSettle();
      expect(find.text('Banear usuario'), findsWidgets);
      final banButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Banear'),
      );
      expect(banButton.onPressed, isNull);
      await tester.enterText(find.byType(TextField).last, 'Spam en el chat');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Banear'))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Banear'));
      await tester.pumpAndSettle();
      // La etiqueta 'Baneado' aparece en el encabezado y en la ficha.
      expect(find.text('Baneado'), findsWidgets);
      expect(find.text('HISTORIAL DE BANEOS'), findsOneWidget);
      // El motivo aparece en la ficha (Motivo del baneo) y en el historial.
      expect(find.text('Spam en el chat'), findsWidgets);
    });
  });
}

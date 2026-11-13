// Saludo del Admin (2026-11-13, Kristian): al iniciar se muestra solo el
// primer nombre ("Hola Kristian"), sin apellidos y sin correo. Ni el Panel
// ni el pie del drawer muestran el correo del admin logueado.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quemia_admin/design.dart';
import 'package:quemia_admin/models.dart';
import 'package:quemia_admin/repositories.dart';
import 'package:quemia_admin/screens.dart';

import 'test_data.dart';

const _record = AdminRecord(
  uid: 'owner-uid',
  email: 'pozogomezkristian19@gmail.com',
  displayName: 'Kristian Pozo Gómez',
  role: 'owner',
  permissions: AdminPermissions.all,
);

void main() {
  setUpAll(() async {
    // Sin Nunito y sin vista de teléfono, las filas del drawer desbordan
    // (artefacto del test, en el teléfono cabe).
    final loader = FontLoader('Nunito');
    for (final asset in [
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-SemiBold.ttf',
      'assets/fonts/Nunito-Bold.ttf',
      'assets/fonts/Nunito-ExtraBold.ttf',
    ]) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  });

  group('AdminRecord.firstName', () {
    test('nombre completo devuelve solo el primer nombre', () {
      expect(_record.firstName, 'Kristian');
    });

    test('un solo nombre se queda igual', () {
      expect(
        const AdminRecord(
          uid: 'u',
          email: 'a@b.c',
          displayName: 'Kristian',
        ).firstName,
        'Kristian',
      );
    });

    test('sin nombre devuelve vacío (nunca el correo)', () {
      expect(
        const AdminRecord(
          uid: 'u',
          email: 'a@b.c',
          displayName: '',
        ).firstName,
        '',
      );
    });

    test('espacios de más no se cuelan', () {
      expect(
        const AdminRecord(
          uid: 'u',
          email: 'a@b.c',
          displayName: '  Ana   María  ',
        ).firstName,
        'Ana',
      );
    });
  });

  group('saludo al iniciar', () {
    testWidgets('el Panel dice "Hola Kristian", sin apellidos ni correo', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: quemiaAdminTheme(),
          home: Scaffold(
            body: DashboardScreen(
              users: FakeUsersRepository(seedUsers()),
              reports: FakeReportsRepository(seedReports()),
              me: _record,
              onNavigate: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Hola Kristian'), findsOneWidget);
      expect(find.textContaining('Pozo'), findsNothing);
      expect(find.textContaining('Gómez'), findsNothing);
      expect(
        find.textContaining('pozogomezkristian19@gmail.com'),
        findsNothing,
      );
    });

    testWidgets('el pie del drawer dice "Hola Kristian", sin correo', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: quemiaAdminTheme(),
          home: Scaffold(
            appBar: AppBar(),
            drawer: AdminDrawer(
              me: _record,
              current: AdminSection.panel,
              onSelect: (_) {},
              onSignOut: () {},
              canSeeUsers: true,
              canManage: true,
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('Hola Kristian'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.textContaining('pozogomezkristian19@gmail.com'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.textContaining('Pozo'),
        ),
        findsNothing,
      );
    });
  });
}

// Soporte: bandeja (abiertos/respondidos), responder, y ajustes remotos
// de soporte (número de WhatsApp + interruptor).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quemia_admin/models.dart';
import 'package:quemia_admin/repositories.dart';
import 'package:quemia_admin/screens.dart';

import 'test_data.dart';

AdminService serviceFor(AdminRecord me, {SupportRepository? support}) =>
    AdminService(
      me: me,
      users: FakeUsersRepository(),
      admins: FakeAdminsRepository(),
      settings: FakeSettingsRepository(),
      support: support ?? FakeSupportRepository(seedSupportMessages()),
    );

void main() {
  group('bandeja de soporte', () {
    test('lista: abiertos primero, más recientes primero', () async {
      final service = serviceFor(ownerRecord());
      final list = await service.support.listMessages();
      expect(list.length, 3);
      expect(list.where((m) => !m.isAnswered).length, 2);
      expect(list.take(2).every((m) => !m.isAnswered), isTrue);
      expect(list.last.isAnswered, isTrue);
      expect(list.first.id, 'sup-1'); // el abierto más reciente (2 h)
      expect(list.first.username, 'sofia');
    });

    test('responder guarda la respuesta y cambia el estado', () async {
      final service = serviceFor(ownerRecord());
      final message = (await service.support.listMessages()).first;
      expect(message.isAnswered, isFalse);
      await service.replyToSupport(message, 'Gracias, ya lo revisamos. ');
      final after = (await service.support.listMessages()).firstWhere(
        (m) => m.id == message.id,
      );
      expect(after.isAnswered, isTrue);
      expect(after.status, 'respondido');
      expect(after.reply, 'Gracias, ya lo revisamos.');
      expect(after.replyAt, isNotNull);
      expect(after.replyAt!.isAfter(message.createdAt), isTrue);
      // Ya no está entre los abiertos.
      final list = await service.support.listMessages();
      expect(list.where((m) => !m.isAnswered).length, 1);
    });

    test('respuesta vacía NO se guarda', () async {
      final service = serviceFor(ownerRecord());
      final message = (await service.support.listMessages()).first;
      await expectLater(
        service.replyToSupport(message, '   '),
        throwsArgumentError,
      );
      final after = (await service.support.listMessages()).firstWhere(
        (m) => m.id == message.id,
      );
      expect(after.isAnswered, isFalse);
      expect(after.reply, '');
    });

    test('admin sin manageAdmins NO puede responder', () async {
      final service = serviceFor(readOnlyAdminRecord());
      final message = (await service.support.listMessages()).first;
      await expectLater(
        service.replyToSupport(message, 'Hola'),
        throwsA(isA<PermissionDenied>()),
      );
      final after = (await service.support.listMessages()).firstWhere(
        (m) => m.id == message.id,
      );
      expect(after.isAnswered, isFalse);
    });
  });

  group('ajustes remotos de soporte', () {
    test('valores por defecto: número de Kristian, WhatsApp apagado', () {
      const s = RemoteSettings();
      expect(s.supportNumber, '+5356519431');
      expect(s.showWhatsApp, isFalse);
    });

    test('número e interruptor se guardan y se leen', () async {
      final settings = FakeSettingsRepository();
      final service = AdminService(
        me: ownerRecord(),
        users: FakeUsersRepository(),
        admins: FakeAdminsRepository(),
        settings: settings,
      );
      await service.saveSettings(
        const RemoteSettings(
          supportNumber: '+5355001122',
          showWhatsApp: true,
        ),
      );
      final loaded = await settings.load();
      expect(loaded.supportNumber, '+5355001122');
      expect(loaded.showWhatsApp, isTrue);
      // El resto sigue en sus valores por defecto.
      expect(loaded.passThreshold, 4);
      expect(loaded.maxLives, 5);
    });

    test('fromMap tolera un documento sin los campos de soporte', () {
      final s = RemoteSettings.fromMap({'passThreshold': 3});
      expect(s.supportNumber, '+5356519431');
      expect(s.showWhatsApp, isFalse);
    });

    test('número con formato inválido NO se guarda', () async {
      final service = AdminService(
        me: ownerRecord(),
        users: FakeUsersRepository(),
        admins: FakeAdminsRepository(),
        settings: FakeSettingsRepository(),
      );
      await expectLater(
        service.saveSettings(
          const RemoteSettings(supportNumber: 'no-es-un-numero'),
        ),
        throwsArgumentError,
      );
    });
  });

  group('pantallas de soporte (widgets)', () {
    testWidgets('la lista muestra abiertos y respondidos', (tester) async {
      final service = serviceFor(ownerRecord());
      await tester.pumpWidget(
        MaterialApp(
          theme: quemiaAdminTheme(),
          home: SupportScreen(
            support: service.support,
            service: service,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('sofia'), findsOneWidget);
      expect(find.text('miguel'), findsOneWidget);
      expect(find.text('laura'), findsOneWidget);
      expect(find.text('2 sin responder · 1 respondido(s)'), findsOneWidget);
      expect(find.text('Abierto'), findsNWidgets(2));
      expect(find.text('Respondido'), findsOneWidget);
    });

    testWidgets('responder desde el detalle cambia el estado', (tester) async {
      final support = FakeSupportRepository(seedSupportMessages());
      final service = serviceFor(ownerRecord(), support: support);
      await tester.pumpWidget(
        MaterialApp(
          theme: quemiaAdminTheme(),
          home: SupportScreen(support: support, service: service),
        ),
      );
      await tester.pump();
      await tester.pump();
      // Abre el mensaje de sofia.
      await tester.tap(find.text('sofia'));
      await tester.pumpAndSettle();
      expect(
        find.text('No me cargan las preguntas del nivel 3 de Estequiometría, se queda en blanco.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('Respuesta de soporte')),
        'Ya lo arreglamos, prueba de nuevo.',
      );
      await tester.tap(find.text('Enviar respuesta'));
      await tester.pumpAndSettle();
      expect(find.text('Respondido'), findsOneWidget);
      expect(find.text('Ya lo arreglamos, prueba de nuevo.'), findsOneWidget);
      final after = (await support.listMessages()).firstWhere(
        (m) => m.id == 'sup-1',
      );
      expect(after.status, 'respondido');
      expect(after.reply, 'Ya lo arreglamos, prueba de nuevo.');
    });

    testWidgets('ajustes: número e interruptor se guardan desde la UI', (tester) async {
      final settings = FakeSettingsRepository();
      final service = AdminService(
        me: ownerRecord(),
        users: FakeUsersRepository(),
        admins: FakeAdminsRepository(),
        settings: settings,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: quemiaAdminTheme(),
          home: SettingsScreen(
            settings: settings,
            service: service,
            me: ownerRecord(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      // Cambia el número y enciende el interruptor (la sección de Soporte
      // está abajo del todo: hay que hacer scroll hasta verla).
      await tester.ensureVisible(
        find.text('Número de soporte (WhatsApp)'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('Número de soporte (WhatsApp)')),
        '+5355001122',
      );
      await tester.ensureVisible(find.text('Mostrar WhatsApp en Soporte'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.ensureVisible(find.text('Guardar ajustes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar ajustes'));
      await tester.pumpAndSettle();
      expect(settings.current.supportNumber, '+5355001122');
      expect(settings.current.showWhatsApp, isTrue);
    });
  });
}

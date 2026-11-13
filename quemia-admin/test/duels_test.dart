// Duelos: modelo, repositorio fake y pantalla (solo lectura).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quemia_admin/models.dart';
import 'package:quemia_admin/repositories.dart';
import 'package:quemia_admin/screens.dart';

import 'test_data.dart';

Map<String, dynamic> _duelMap({
  String playerA = 'u-ana',
  String playerB = 'u-luis',
  String playerAName = 'Ana',
  String playerBName = 'Luis',
  String status = 'waiting',
  int createdAtMs = 1000,
  Map<String, dynamic> results = const {},
  String? winnerUid,
  bool forfeit = false,
}) => <String, dynamic>{
  'playerA': playerA,
  'playerB': playerB,
  'playerAName': playerAName,
  'playerBName': playerBName,
  'questionIds': ['q1', 'q2', 'q3', 'q4', 'q5'],
  'seed': 7,
  'status': status,
  'createdAtMs': createdAtMs,
  'results': results,
  'winnerUid': winnerUid,
  'forfeit': forfeit,
};

Duel _duel(
  String id, {
  String status = 'waiting',
  int createdAtMs = 1000,
  Map<String, dynamic> results = const {},
  String? winnerUid,
  bool forfeit = false,
  String playerAName = 'Ana',
  String playerBName = 'Luis',
}) => Duel.fromDoc(
  id,
  _duelMap(
    status: status,
    createdAtMs: createdAtMs,
    results: results,
    winnerUid: winnerUid,
    forfeit: forfeit,
    playerAName: playerAName,
    playerBName: playerBName,
  ),
);

AdminService _service(AdminRecord me, DuelsRepository duels) => AdminService(
  me: me,
  users: FakeUsersRepository(),
  admins: FakeAdminsRepository(),
  settings: FakeSettingsRepository(),
  duels: duels,
);

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
) async {
  await tester.pumpWidget(
    MaterialApp(theme: quemiaAdminTheme(), home: Scaffold(body: screen)),
  );
  await tester.pumpAndSettle();
}

/// Repositorio que simula la regla sin publicar: Firestore deniega la
/// lectura de duelos con permiso denegado.
class _DeniedDuelsRepository implements DuelsRepository {
  @override
  Future<List<Duel>> listDuels({int limit = 100}) async {
    throw Exception(
      '[cloud_firestore/permission-denied] The caller does not have '
      'permission to execute the specified operation.',
    );
  }
}

void main() {
  group('duelos (modelo)', () {
    test('fromDoc lee jugadores, estado, ganador y abandono', () {
      final d = _duel(
        'd1',
        status: 'finished',
        winnerUid: 'u-ana',
        forfeit: true,
        results: {
          'u-ana': {
            'correct': 4,
            'timeMs': 12000,
            'finishedAtMs': 2000,
            'lastActivityMs': 2000,
          },
          'u-luis': {
            'correct': 3,
            'timeMs': 15000,
            'finishedAtMs': 2100,
            'lastActivityMs': 2100,
          },
        },
      );
      expect(d.playerAName, 'Ana');
      expect(d.playerBName, 'Luis');
      expect(d.isFinished, isTrue);
      expect(d.isActive, isFalse);
      expect(d.winnerName, 'Ana');
      expect(d.forfeit, isTrue);
      expect(d.scoreOf('u-ana'), 4);
      expect(d.scoreOf('u-luis'), 3);
      expect(d.statusLabel, 'Terminado');
    });

    test('etiquetas de estado en español', () {
      expect(_duel('d', status: 'waiting').statusLabel, 'En espera');
      expect(_duel('d', status: 'playing').statusLabel, 'En curso');
      expect(_duel('d', status: 'finished').statusLabel, 'Terminado');
      expect(_duel('d', status: 'cancelled').statusLabel, 'Cancelado');
      expect(_duel('d', status: 'playing').isActive, isTrue);
      expect(_duel('d', status: 'cancelled').isCancelled, isTrue);
    });

    test('un latido (sin terminar) no cuenta como aciertos', () {
      final d = _duel(
        'd1',
        status: 'playing',
        results: {
          'u-ana': {
            'correct': 0,
            'timeMs': 0,
            'finishedAtMs': 0,
            'lastActivityMs': 1500,
          },
        },
      );
      expect(d.scoreOf('u-ana'), isNull);
      expect(d.scoreOf('u-luis'), isNull);
      expect(d.winnerName, '');
    });

    test('sin ganador no hay nombre de ganador', () {
      final d = _duel('d1', status: 'finished');
      expect(d.winnerName, '');
    });
  });

  group('duelos (repositorio fake)', () {
    test('lista del más reciente al más viejo y respeta el límite', () async {
      final repo = FakeDuelsRepository([
        _duel('viejo', createdAtMs: 100),
        _duel('nuevo', createdAtMs: 300),
        _duel('medio', createdAtMs: 200),
      ]);
      final list = await repo.listDuels();
      expect(list.map((d) => d.id), ['nuevo', 'medio', 'viejo']);
      expect((await repo.listDuels(limit: 2)).length, 2);
    });
  });

  group('duelos (servicio)', () {
    test('el dueño lista los duelos', () async {
      final service = _service(
        ownerRecord(),
        FakeDuelsRepository([_duel('d1')]),
      );
      expect((await service.listDuels()).length, 1);
    });

    test('admin sin ver usuarios NO puede listar duelos', () async {
      final noAccess = AdminRecord(
        uid: 'x',
        email: 'nadie@gmail.com',
        displayName: 'Nadie',
        role: 'admin',
        permissions: const AdminPermissions(),
        createdBy: ownerEmail,
      );
      final service = _service(
        noAccess,
        FakeDuelsRepository([_duel('d1')]),
      );
      await expectLater(
        service.listDuels(),
        throwsA(isA<PermissionDenied>()),
      );
    });
  });

  group('duelos (pantalla)', () {
    testWidgets('muestra jugadores, aciertos, estado y ganador', (
      tester,
    ) async {
      final service = _service(
        ownerRecord(),
        FakeDuelsRepository([
          _duel(
            'd1',
            status: 'playing',
            playerAName: 'Ana',
            playerBName: 'Luis',
            createdAtMs: 2000,
          ),
          _duel(
            'd2',
            status: 'finished',
            playerAName: 'Marta',
            playerBName: 'Pedro',
            winnerUid: 'u-ana',
            createdAtMs: 1000,
            results: {
              'u-ana': {
                'correct': 5,
                'timeMs': 9000,
                'finishedAtMs': 2000,
                'lastActivityMs': 2000,
              },
              'u-luis': {
                'correct': 2,
                'timeMs': 14000,
                'finishedAtMs': 2100,
                'lastActivityMs': 2100,
              },
            },
          ),
        ]),
      );
      await _pump(tester, DuelsScreen(service: service));
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Luis'), findsOneWidget);
      expect(find.text('Marta'), findsOneWidget);
      expect(find.text('5 aciertos'), findsOneWidget);
      expect(find.text('Ganador: Marta'), findsOneWidget);
      expect(find.text('En curso'), findsWidgets);
      expect(find.text('Terminado'), findsWidgets);
    });

    testWidgets('los filtros dejan solo los duelos de ese estado', (
      tester,
    ) async {
      final service = _service(
        ownerRecord(),
        FakeDuelsRepository([
          _duel('d1', status: 'playing', playerAName: 'Ana'),
          _duel('d2', status: 'finished', playerAName: 'Marta'),
        ]),
      );
      await _pump(tester, DuelsScreen(service: service));
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Marta'), findsOneWidget);

      // La píldora es el primer 'En curso' (la tarjeta va después).
      await tester.tap(find.text('En curso').first);
      await tester.pumpAndSettle();
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Marta'), findsNothing);

      await tester.tap(find.text('Terminados').first);
      await tester.pumpAndSettle();
      expect(find.text('Ana'), findsNothing);
      expect(find.text('Marta'), findsOneWidget);
    });

    testWidgets('sin permiso muestra el aviso calmado de la regla', (
      tester,
    ) async {
      final noAccess = AdminRecord(
        uid: 'x',
        email: 'nadie@gmail.com',
        displayName: 'Nadie',
        role: 'admin',
        permissions: const AdminPermissions(),
        createdBy: ownerEmail,
      );
      await _pump(
        tester,
        DuelsScreen(service: _service(noAccess, FakeDuelsRepository())),
      );
      expect(find.text('Duelos sin acceso todavía'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.textContaining('Error'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Firestore denegado muestra el mismo aviso calmado', (
      tester,
    ) async {
      await _pump(
        tester,
        DuelsScreen(
          service: _service(ownerRecord(), _DeniedDuelsRepository()),
        ),
      );
      expect(find.text('Duelos sin acceso todavía'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('sin duelos muestra el estado vacío', (tester) async {
      await _pump(
        tester,
        DuelsScreen(
          service: _service(ownerRecord(), FakeDuelsRepository()),
        ),
      );
      expect(find.text('Sin duelos todavía'), findsOneWidget);
    });
  });
}

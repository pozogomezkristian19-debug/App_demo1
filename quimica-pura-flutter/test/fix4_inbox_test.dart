// Pruebas de la ronda #4, punto 8: centro de notificaciones.
// La campana abre una bandeja persistida en el teléfono (máx. 30
// entradas, leído/no leído, numerito rojo en la campana). Entradas:
// (a) actualización pospuesta con "Más tarde" (desaparece al
// actualizar); (b) cada recordatorio de estudio que se dispara;
// (c) logro desbloqueado; (d) aviso de racha en peligro.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quimica_pura/main.dart';
import 'package:quimica_pura/services/achievements.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/notification_inbox.dart';
import 'package:quimica_pura/services/notification_service.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/update_check.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'test_helpers.dart';

/// Fake mínimo del plugin (mismo patrón que fix3_notifications_test):
/// sin plataforma real, las llamadas al canal nativo se quedan
/// colgadas. Solo hace falta para la tanda que programa "Más tarde".
class _InboxFakeNotifications extends AndroidFlutterLocalNotificationsPlugin
    with MockPlatformInterfaceMixin {
  @override
  Future<bool> initialize({
    required AndroidInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
  }) async =>
      true;

  @override
  Future<bool?> requestNotificationsPermission() async => true;

  @override
  Future<bool?> requestExactAlarmsPermission() async => true;

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
    AndroidNotificationDetails? notificationDetails,
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.exact,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRobotoFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({'melli_rules_seen_v6': true});
    await UserPrefs.load();
    await ProgressService.load();
    NotificationInbox.resetForTests();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (call) async => 'America/Havana',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (call.method == 'getTemporaryDirectory') return '/tmp';
        return null;
      },
    );
    FlutterLocalNotificationsPlatform.instance = _InboxFakeNotifications();
    await NotificationInbox.load();
  });

  group('Bandeja: crear, leer, persistir', () {
    test('añadir marca sin leer; markRead y markAllRead actualizan el '
        'contador', () async {
      await NotificationInbox.add(
        id: 'a',
        kind: InboxKind.reminder,
        title: 'Recordatorio',
        body: 'Toca repasar.',
      );
      await NotificationInbox.add(
        id: 'b',
        kind: InboxKind.update,
        title: 'Actualización',
        body: 'Versión 6.2',
      );
      expect(NotificationInbox.entries.length, 2);
      expect(NotificationInbox.unreadCount, 2);
      // La más reciente va primera.
      expect(NotificationInbox.entries.first.id, 'b');

      await NotificationInbox.markRead('b');
      expect(NotificationInbox.unreadCount, 1);
      expect(
          NotificationInbox.entries
              .firstWhere((e) => e.id == 'b')
              .read,
          isTrue);

      await NotificationInbox.markAllRead();
      expect(NotificationInbox.unreadCount, 0);
    });

    test('las entradas persisten en SharedPreferences entre cargas',
        () async {
      await NotificationInbox.add(
        id: 'persist-1',
        kind: InboxKind.reminder,
        title: 'Recordatorio',
        body: 'Toca repasar.',
      );
      // Simula un reinicio: se vacía la memoria y se vuelve a cargar.
      NotificationInbox.resetForTests();
      await NotificationInbox.load();
      expect(NotificationInbox.entries.length, 1);
      expect(NotificationInbox.entries.first.id, 'persist-1');
      expect(NotificationInbox.unreadCount, 1);
    });

    test('máximo 30 entradas: las más viejas se descartan', () async {
      for (var i = 0; i < 35; i++) {
        await NotificationInbox.add(
          id: 'e-$i',
          kind: InboxKind.reminder,
          title: 'Entrada $i',
          body: 'Cuerpo $i',
        );
      }
      expect(NotificationInbox.entries.length, 30);
      // Quedan las 30 más recientes (e-34..e-5).
      expect(NotificationInbox.entries.map((e) => e.id),
          isNot(contains('e-0')));
      expect(NotificationInbox.entries.map((e) => e.id),
          isNot(contains('e-4')));
      expect(
          NotificationInbox.entries.map((e) => e.id), contains('e-5'));
      expect(
          NotificationInbox.entries.map((e) => e.id), contains('e-34'));
    });

    test('añadir el mismo id sustituye y vuelve a marcar sin leer',
        () async {
      await NotificationInbox.add(
        id: 'dup',
        kind: InboxKind.reminder,
        title: 'Primera',
        body: 'Cuerpo',
      );
      await NotificationInbox.markAllRead();
      expect(NotificationInbox.unreadCount, 0);
      await NotificationInbox.add(
        id: 'dup',
        kind: InboxKind.reminder,
        title: 'Segunda',
        body: 'Cuerpo nuevo',
      );
      expect(NotificationInbox.entries.length, 1);
      expect(NotificationInbox.entries.first.title, 'Segunda');
      expect(NotificationInbox.unreadCount, 1);
    });

    test('removeByKind quita solo ese tipo', () async {
      await NotificationInbox.add(
        id: 'u1',
        kind: InboxKind.update,
        title: 'Actualización',
        body: 'Versión 6.2',
      );
      await NotificationInbox.add(
        id: 'r1',
        kind: InboxKind.reminder,
        title: 'Recordatorio',
        body: 'Toca repasar.',
      );
      await NotificationInbox.removeByKind(InboxKind.update);
      expect(
          NotificationInbox.entries.map((e) => e.id), ['r1']);
    });
  });

  group('Entrada de actualización (punto 8a)', () {
    /// Pantalla con dos botones: abrir el diálogo de actualización
    /// (versión 6.2) y comprobar de nuevo con el mismo version.json
    /// (6.1, la instalada) para simular que ya se actualizó.
    Future<void> pumpUpdateButtons(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () => UpdateCheckService.showUpdateDialog(
                      context,
                      const UpdateInfo(
                        latest: '6.2',
                        apkUrl: 'https://example.invalid/melli-qui.apk',
                        notes: 'Notas de la 6.2',
                        force: false,
                      ),
                    ),
                    child: const Text('Mostrar diálogo'),
                  ),
                  ElevatedButton(
                    onPressed: () => UpdateCheckService.checkForUpdate(
                      context,
                      fetcher: (_) async =>
                          '{"latest": "6.1", "apk_url": "", "notes": "", "force": false}',
                    ),
                    child: const Text('Comprobar otra vez'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('"Más tarde" crea la entrada; al actualizar, desaparece',
        (tester) async {
      await pumpUpdateButtons(tester);
      await tester.tap(find.text('Mostrar diálogo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Hay una nueva actualización'), findsOneWidget);
      await tester.tap(find.text('Más tarde'));
      // La copia del icono del recordatorio tiene un límite de 3 s
      // (ver fix3_update_check_test): hay que avanzar el tiempo
      // falso para que la cadena termine y no quede ningún
      // temporizador colgando. El pump() sencillo procesa el toque
      // y empieza el cierre del diálogo; sin él, la animación de
      // salida no arranca y el diálogo seguiría en el árbol. El
      // SEGUNDO salto de 4 s es necesario porque el temporizador de
      // 3 s se crea DESPUÉS de cerrar el diálogo (la cadena solo
      // llega a la copia cuando la animación de salida termina), así
      // que el primer salto no lo dispara.
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(find.text('Hay una nueva actualización'), findsNothing);
      final updateEntries = NotificationInbox.entries
          .where((e) => e.kind == InboxKind.update)
          .toList();
      expect(updateEntries.length, 1);
      expect(updateEntries.first.title, tr('inboxUpdateTitle'));
      expect(updateEntries.first.body, contains('6.2'));
      expect(NotificationInbox.unreadCount, 1);

      // Ya estamos al día (la instalada es la 6.1): la comprobación
      // limpia la entrada de actualización.
      await tester.tap(find.text('Comprobar otra vez'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pump();
      expect(
          NotificationInbox.entries
              .where((e) => e.kind == InboxKind.update),
          isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('Recordatorios disparados (punto 8b)', () {
    test('las horas pasadas se registran una vez (y no se duplican)',
        () async {
      // Tres avisos ya pasados y uno futuro, en la lista que guarda
      // scheduleNext ('melli_notif_next', ISO separados por comas).
      const raw =
          '2026-11-10T08:00:00.000,2026-11-10T09:00:00.000,'
          '2026-11-10T10:00:00.000,2026-11-10T15:00:00.000';
      SharedPreferences.setMockInitialValues({
        'melli_rules_seen_v6': true,
        'melli_notif_next': raw,
      });
      await ProgressService.load();
      NotificationInbox.resetForTests();
      await NotificationInbox.load();

      final now = DateTime(2026, 11, 10, 12, 0);
      await NotificationService.reconcileFiredReminders(nowOverride: now);
      expect(NotificationInbox.entries.length, 3);
      expect(
          NotificationInbox.entries
              .every((e) => e.kind == InboxKind.reminder),
          isTrue);
      // Segunda reconciliación: sigue habiendo 3 (dedup por id).
      await NotificationService.reconcileFiredReminders(nowOverride: now);
      expect(NotificationInbox.entries.length, 3);
      // Con "ahora" antes de todos: no se añade ninguno nuevo.
      // (Vaciar con la API: recargar desde prefs traería de vuelta
      // las 3 entradas guardadas.)
      await NotificationInbox.removeByKind(InboxKind.reminder);
      expect(NotificationInbox.entries, isEmpty);
      await NotificationService.reconcileFiredReminders(
        nowOverride: DateTime(2026, 11, 10, 7, 0),
      );
      expect(NotificationInbox.entries, isEmpty);
    });
  });

  group('syncDaily: logros y racha (punto 8c/8d)', () {
    List<String> daysAgo(List<int> days) {
      final today = DateTime.now();
      return days
          .map((d) => ProgressService.dateKey(
              DateTime(today.year, today.month, today.day - d)))
          .toList();
    }

    test('un logro nuevo genera una entrada; la primera vez solo se '
        'anota (sin avisar de los viejos)', () async {
      // 3 días seguidos hace 4-6 días: mejor racha 3 (logro
      // 'streak3' desbloqueado) pero racha actual 0 (sin aviso de
      // racha): el test queda aislado al logro.
      SharedPreferences.setMockInitialValues({
        'melli_rules_seen_v6': true,
        'melli_progress_days': daysAgo([6, 5, 4]),
        'melli_inbox_seen_achievements': <String>[],
      });
      await ProgressService.load();
      NotificationInbox.resetForTests();
      await NotificationInbox.load();
      expect(ProgressService.instance.streakBest, 3);

      await NotificationInbox.syncDaily([]);
      final achievements = NotificationInbox.entries
          .where((e) => e.kind == InboxKind.achievement)
          .toList();
      expect(achievements.length, 1);
      expect(
          achievements.first.title,
          allAchievements
              .firstWhere((a) => a.id == 'streak3')
              .title);

      // Primera vez (sin clave de vistos): se anota el conjunto sin
      // crear entradas.
      SharedPreferences.setMockInitialValues({
        'melli_rules_seen_v6': true,
        'melli_progress_days': daysAgo([6, 5, 4]),
      });
      await ProgressService.load();
      NotificationInbox.resetForTests();
      await NotificationInbox.load();
      await NotificationInbox.syncDaily([]);
      expect(NotificationInbox.entries, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      final seen =
          prefs.getStringList('melli_inbox_seen_achievements') ?? [];
      expect(seen, contains('streak3'));
    });

    test('racha en peligro: una entrada al día (y no se duplica)',
        () async {
      SharedPreferences.setMockInitialValues({
        'melli_rules_seen_v6': true,
        'melli_progress_days': daysAgo([1]),
        'melli_inbox_seen_achievements': <String>[],
      });
      await ProgressService.load();
      NotificationInbox.resetForTests();
      await NotificationInbox.load();
      expect(ProgressService.instance.streakNow, 1);

      await NotificationInbox.syncDaily([]);
      final streakEntries = NotificationInbox.entries
          .where((e) => e.kind == InboxKind.streak)
          .toList();
      expect(streakEntries.length, 1);
      expect(streakEntries.first.title, tr('inboxStreakTitle'));
      // Repetir el mismo día no duplica (el id lleva la fecha).
      await NotificationInbox.syncDaily([]);
      expect(
          NotificationInbox.entries
              .where((e) => e.kind == InboxKind.streak)
              .length,
          1);
    });
  });

  group('Campana con numerito', () {
    testWidgets('con 2 sin leer, la campana muestra el numerito',
        (tester) async {
      await NotificationInbox.add(
        id: 'u-1',
        kind: InboxKind.update,
        title: 'Actualización',
        body: 'Versión 6.2',
      );
      await NotificationInbox.add(
        id: 'r-1',
        kind: InboxKind.reminder,
        title: 'Recordatorio',
        body: 'Toca repasar.',
      );
      tester.view.physicalSize = const Size(800, 1700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: HomeScreen(
            isDark: false,
            onToggleTheme: () {},
            onTrackChanged: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // El numerito rojo con el 2, sobre la campana.
      expect(find.byKey(const Key('inboxBadge')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('inboxBadge')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

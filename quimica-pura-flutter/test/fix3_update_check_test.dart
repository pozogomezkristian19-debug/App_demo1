// Pruebas de la ronda de arreglos #3, punto 20 (aviso de
// actualización vía GitHub, con descarga en la propia app):
// comparación de versiones, máquina de estados de la descarga
// (idle → downloading → downloaded → installing), instalador del
// sistema (MethodChannel), diálogo (fondo blanco, teal, "Actualizar
// ahora" / "Más tarde") y recordatorio por notificación ("Más tarde"
// programa el aviso de mañana; una vez al día como máximo).
// Punto 20b (cadencia reescrita en la fix4, punto 7): la comprobación
// es en CADA apertura y al volver a primer plano (nada de esperar
// 4 horas); "Más tarde" sigue sin repetirse.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/screens/settings_screen.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/update_check.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _newerJson =
    '{"latest":"7.7","apk_url":"https://example.com/app.apk","notes":"Novedades de la versión","force":false}';
const _forcedJson =
    '{"latest":"7.7","apk_url":"https://example.com/app.apk","notes":"Actualización obligatoria","force":true}';

final _now = DateTime(2026, 11, 10, 18, 30);

const _updateInfo = UpdateInfo(
  latest: '7.7',
  apkUrl: 'https://example.com/app.apk',
  notes: 'Novedades de la versión',
  force: false,
);

/// Pantalla mínima que dispara la comprobación tras el primer frame,
/// como hace HomeScreen al abrirse la app.
class _Harness extends StatelessWidget {
  const _Harness({
    required this.fetcher,
    required this.now,
    this.fromReminder = false,
  });
  final UpdateJsonFetcher fetcher;
  final DateTime now;
  final bool fromReminder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            UpdateCheckService.checkForUpdate(
              context,
              fetcher: fetcher,
              nowOverride: now,
              fromReminder: fromReminder,
            );
          });
          return const Scaffold(body: Text('Inicio'));
        },
      ),
    );
  }
}

/// Fuente falsa de APK: los bytes en trozos de 10, con tamaño total.
ApkStreamFetcher fakeApkSource(List<int> bytes, {int? total}) {
  return (_) async {
    final chunks = <List<int>>[];
    for (var i = 0; i < bytes.length; i += 10) {
      final end = i + 10 > bytes.length ? bytes.length : i + 10;
      chunks.add(bytes.sublist(i, end));
    }
    return ApkDownloadSource(
      totalBytes: total ?? bytes.length,
      stream: Stream.fromIterable(chunks),
    );
  };
}

void main() {
  // Sin mock, getTemporaryDirectory() se queda colgada en pruebas y la
  // programación del recordatorio (que copia el PNG del compañero a un
  // archivo temporal) no termina nunca: la comprobación inicial queda
  // en curso y la vuelta a primer plano se la salta. Mismo patrón que
  // en fix3_notifications_test.dart.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (call.method == 'getTemporaryDirectory') return '/tmp';
        return null;
      },
    );
  });

  group('compareVersions', () {
    test('mayor, menor e igual', () {
      expect(compareVersions('6.2', '6.0'), greaterThan(0));
      expect(compareVersions('6.0', '6.2'), lessThan(0));
      expect(compareVersions('6.0', '6.0'), 0);
      expect(compareVersions('5.9', '6.0'), lessThan(0));
      expect(compareVersions('7.1', '6.9'), greaterThan(0));
    });

    test('"6.0" < "6.0.1" (un componente más)', () {
      expect(compareVersions('6.0', '6.0.1'), lessThan(0));
      expect(compareVersions('6.0.1', '6.0'), greaterThan(0));
      expect(compareVersions('6.0.0', '6.0'), 0);
    });

    test('"6.10" > "6.9" (comparación numérica, no de texto)', () {
      expect(compareVersions('6.10', '6.9'), greaterThan(0));
      expect(compareVersions('6.9', '6.10'), lessThan(0));
    });
  });

  group('UpdateInfo', () {
    test('fromJson válido y toJson redondo', () {
      final info = UpdateInfo.fromJson({
        'latest': '6.2',
        'apk_url': 'https://example.com/app.apk',
        'notes': 'Novedades',
        'force': false,
      });
      expect(info, isNotNull);
      expect(info!.latest, '6.2');
      expect(info.force, isFalse);
      // La info pendiente guardada para el recordatorio se lee igual.
      final roundTrip = UpdateInfo.fromJson(info.toJson());
      expect(roundTrip, isNotNull);
      expect(roundTrip!.latest, '6.2');
      expect(roundTrip.apkUrl, 'https://example.com/app.apk');
      expect(roundTrip.notes, 'Novedades');
    });

    test('sin versión no hay nada que avisar', () {
      expect(UpdateInfo.fromJson({'notes': 'x'}), isNull);
      expect(UpdateInfo.fromJson({}), isNull);
    });
  });

  group('shouldShowUpdate', () {
    test('misma versión o menor: nunca avisa', () {
      expect(
        shouldShowUpdate(
          latest: kAppVersion,
          force: false,
          dismissedVersion: null,
        ),
        isFalse,
      );
      expect(
        shouldShowUpdate(
          latest: '5.9',
          force: true,
          dismissedVersion: null,
        ),
        isFalse,
      );
    });

    test('versión nueva sin descartar y sin comprobar hoy: avisa', () {
      expect(
        shouldShowUpdate(
          latest: '7.7',
          force: false,
          dismissedVersion: null,
        ),
        isTrue,
      );
    });

    test('versión descartada con "Más tarde" no vuelve a preguntar', () {
      expect(
        shouldShowUpdate(
          latest: '7.7',
          force: false,
          dismissedVersion: '7.7',
        ),
        isFalse,
      );
      // Otra versión más nueva sí vuelve a avisar.
      expect(
        shouldShowUpdate(
          latest: '7.7',
          force: false,
          dismissedVersion: '7.1',
        ),
        isTrue,
      );
    });

    test('con force no se puede posponer: avisa aunque se descartó', () {
      expect(
        shouldShowUpdate(
          latest: '7.7',
          force: true,
          dismissedVersion: '7.7',
        ),
        isTrue,
      );
    });

    test(
        'sin cadencia: la comprobación es en cada apertura (fix4, '
        'punto 7)', () {
      // shouldShowUpdate ya no mira cuándo se comprobó por última
      // vez: una versión nueva avisa siempre (salvo "Más tarde"),
      // se acabara de mirar hace un minuto o hace un mes.
      expect(
        shouldShowUpdate(
          latest: '7.7',
          force: false,
          dismissedVersion: null,
        ),
        isTrue,
      );
      expect(
        shouldShowUpdate(
          latest: '7.7',
          force: true,
          dismissedVersion: null,
        ),
        isTrue,
      );
      // La versión descartada sigue sin avisar, con o sin force.
      expect(
        shouldShowUpdate(
          latest: '7.7',
          force: false,
          dismissedVersion: '7.7',
        ),
        isFalse,
      );
    });
  });

  group('kAppVersion (fix4, punto 6)', () {
    test('la versión instalada es la 7.6', () {
      expect(kAppVersion, '7.6');
      expect(compareVersions('7.6', '6.0'), greaterThan(0));
      // Nada más instalar la 7.6, la 7.6 remota no avisa (sin falso
      // aviso); la 7.7 sí.
      expect(
        shouldShowUpdate(
          latest: '7.6',
          force: false,
          dismissedVersion: null,
        ),
        isFalse,
      );
      expect(
        shouldShowUpdate(
          latest: '7.7',
          force: false,
          dismissedVersion: null,
        ),
        isTrue,
      );
    });
  });

  group('shouldScheduleReminder', () {
    test('sin recordatorio previo: se programa', () {
      expect(
        shouldScheduleReminder(
          latest: '7.7',
          scheduledVersion: null,
          scheduledAt: null,
          now: _now,
        ),
        isTrue,
      );
    });

    test('ya hay uno para ESTA versión y aún no llegó: no se duplica', () {
      expect(
        shouldScheduleReminder(
          latest: '7.7',
          scheduledVersion: '7.7',
          scheduledAt: _now.add(const Duration(hours: 2)),
          now: _now,
        ),
        isFalse,
      );
    });

    test('salió una versión más nueva: se actualiza a esa', () {
      expect(
        shouldScheduleReminder(
          latest: '6.6',
          scheduledVersion: '7.7',
          scheduledAt: _now.add(const Duration(hours: 2)),
          now: _now,
        ),
        isTrue,
      );
    });

    test('el recordatorio ya pasó: se programa el siguiente', () {
      expect(
        shouldScheduleReminder(
          latest: '7.7',
          scheduledVersion: '7.7',
          scheduledAt: _now.subtract(const Duration(hours: 1)),
          now: _now,
        ),
        isTrue,
      );
    });
  });

  group('updateTexts', () {
    test('los seis idiomas dicen "Hay una actualización pendiente"', () {
      const langs = ['es', 'en', 'fr', 'it', 'pt', 'ru'];
      for (final lang in langs) {
        final t = updateTexts(lang);
        expect(t['reminderBody'], isNotEmpty, reason: lang);
        expect(t['dialogTitle'], isNotEmpty, reason: lang);
        expect(t['updateNow'], isNotEmpty, reason: lang);
        expect(t['later'], isNotEmpty, reason: lang);
        expect(t['install'], isNotEmpty, reason: lang);
        // Sin slugs ni ids internos en los textos que ve el usuario.
        for (final value in t.values) {
          expect(value.contains('bach-'), isFalse, reason: '$lang: $value');
          expect(value.contains('uni-'), isFalse, reason: '$lang: $value');
        }
      }
      expect(
          updateTexts('es')['reminderBody'], 'Hay una actualización pendiente');
    });
  });

  group('UpdateDownloader (máquina de estados)', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('melli_update_test_');
    });

    tearDown(() async {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });

    test('idle → downloading → downloaded, con progreso y bytes exactos',
        () async {
      final dl = UpdateDownloader();
      expect(dl.state.value, UpdateDownloadState.idle);
      final bytes = List<int>.generate(100, (i) => i % 256);
      final seen = <double>[];
      dl.progress.addListener(() => seen.add(dl.progress.value));

      final file = await dl.download(
        info: _updateInfo,
        dir: dir,
        fetcher: fakeApkSource(bytes),
      );

      expect(file, isNotNull);
      expect(dl.state.value, UpdateDownloadState.downloaded);
      expect(dl.progress.value, 1);
      expect(seen, contains(1.0));
      expect(await file!.readAsBytes(), bytes);
      expect(file.path.endsWith('quemia-7.7.apk'), isTrue);
      expect(dl.downloadedPath, file.path);
      expect(dl.downloadedVersion, '7.7');
    });

    test('si el APK ya está descargado, no descarga de nuevo', () async {
      final bytes = List<int>.generate(50, (i) => i);
      await File('${dir.path}/quemia-7.7.apk').writeAsBytes(bytes);
      var calls = 0;
      final dl = UpdateDownloader();
      final file = await dl.download(
        info: _updateInfo,
        dir: dir,
        fetcher: (_) async {
          calls++;
          return ApkDownloadSource(
            totalBytes: bytes.length,
            stream: Stream.value(bytes),
          );
        },
      );
      expect(calls, 0);
      expect(file, isNotNull);
      expect(dl.state.value, UpdateDownloadState.downloaded);
      expect(await file!.readAsBytes(), bytes);
    });

    test('si la descarga falla, vuelve a idle y no deja archivo', () async {
      final dl = UpdateDownloader();
      final file = await dl.download(
        info: _updateInfo,
        dir: dir,
        fetcher: (_) async => ApkDownloadSource(
          totalBytes: 100,
          stream: Stream<List<int>>.error(Exception('sin red')),
        ),
      );
      expect(file, isNull);
      expect(dl.state.value, UpdateDownloadState.idle);
      expect(dl.progress.value, 0);
      expect(
        await File('${dir.path}/quemia-7.7.apk').exists(),
        isFalse,
      );
      expect(
        await File('${dir.path}/quemia-7.7.apk.part').exists(),
        isFalse,
      );
    });

    test('descarga incompleta (menos bytes que el total) se descarta',
        () async {
      final dl = UpdateDownloader();
      final file = await dl.download(
        info: _updateInfo,
        dir: dir,
        fetcher: fakeApkSource(List<int>.filled(10, 7), total: 100),
      );
      expect(file, isNull);
      expect(dl.state.value, UpdateDownloadState.idle);
    });
  });

  group('checkForUpdate (widget)', () {
    // El servicio arma un observador de ciclo de vida global al
    // comprobar: se desarma tras cada test para que no se pisen.
    tearDown(() => UpdateCheckService.resetForTests());

    testWidgets('versión nueva: diálogo blanco con teal y botones',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        _Harness(fetcher: (_) async => _newerJson, now: _now),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hay una nueva actualización'), findsOneWidget);
      // La versión que se enseña es la PÚBLICA (1.0): la interna
      // (7.7, latest del version.json) es solo para nosotros.
      expect(find.text('Versión 1.0 disponible'), findsOneWidget);
      expect(find.text('Novedades de la versión'), findsOneWidget);
      expect(find.text('Actualizar ahora'), findsOneWidget);
      expect(find.text('Más tarde'), findsOneWidget);
      // Fondo blanco (no del tema) y botón principal teal.
      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      expect(dialog.backgroundColor, Colors.white);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final bg = button.style?.backgroundColor?.resolve({});
      expect(bg, const Color(0xFF00C2A8));
    });

    testWidgets('"Más tarde" guarda la versión y programa el recordatorio',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        _Harness(fetcher: (_) async => _newerJson, now: _now),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hay una nueva actualización'), findsOneWidget);

      await tester.tap(find.text('Más tarde'));
      // El botón cierra el diálogo DESPUÉS de reprogramar el
      // recordatorio (cadena asíncrona al servicio de
      // notificaciones): se espera a que termine de verdad antes de
      // afirmar que el diálogo se cerró, porque pumpAndSettle no
      // espera a sus Futures y en una máquina cargada la cadena no
      // termina en los primeros pumps. El avance de 4 s dispara el
      // límite de 3 s de la copia del icono, o el temporizador
      // quedaría pendiente al cerrar el test.
      await tester.pump(const Duration(seconds: 4));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hay una nueva actualización'), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kUpdateDismissedKey), '7.7');
      // La info pendiente queda guardada: al tocar el recordatorio
      // el diálogo sale con estos datos aunque no haya internet.
      final pending = prefs.getString(kUpdatePendingKey);
      expect(pending, isNotNull);
      final pendingJson = jsonDecode(pending!) as Map<String, dynamic>;
      expect(UpdateInfo.fromJson(pendingJson)?.latest, '7.7');
      expect(prefs.getString(kUpdateReminderVersionKey), '7.7');
      final atMs = prefs.getInt(kUpdateReminderAtKey);
      expect(atMs, isNotNull);
      // Mañana, no hoy: al día siguiente.
      final at = DateTime.fromMillisecondsSinceEpoch(atMs!);
      expect(at.difference(_now).inHours, greaterThanOrEqualTo(23));
    });

    testWidgets(
        'versión descartada: al abrir no hay diálogo, solo el '
        'recordatorio (una vez al día)', (tester) async {
      SharedPreferences.setMockInitialValues({
        kUpdateDismissedKey: '7.7',
      });
      var calls = 0;
      await tester.pumpWidget(
        _Harness(
          fetcher: (_) async {
            calls++;
            return _newerJson;
          },
          now: _now,
        ),
      );
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(find.text('Hay una nueva actualización'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kUpdateReminderVersionKey), '7.7');

      // La comprobación inicial reprograma el recordatorio (con
      // E/S real de archivos, que en testWidgets solo avanza en
      // runAsync): se espera a que termine antes de la segunda
      // comprobación, o el servicio la saltaría por estar en curso.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pumpAndSettle();

      // Segunda comprobación (fix4, punto 7): ahora SÍ se descarga
      // en cada apertura — pero la versión pospuesta sigue sin
      // avisar: el aviso queda en el recordatorio.
      await UpdateCheckService.checkForUpdate(
        tester.element(find.text('Inicio')),
        fetcher: (_) async {
          calls++;
          return _newerJson;
        },
        nowOverride: _now,
      );
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Hay una nueva actualización'), findsNothing);
    });

    testWidgets(
        'desde el recordatorio, la versión descartada SÍ muestra '
        'el diálogo', (tester) async {
      SharedPreferences.setMockInitialValues({
        kUpdateDismissedKey: '7.7',
      });
      await tester.pumpWidget(
        _Harness(
          fetcher: (_) async => _newerJson,
          now: _now,
          fromReminder: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hay una nueva actualización'), findsOneWidget);
    });

    testWidgets('force: sin botón "Más tarde", solo "Actualizar ahora"',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        _Harness(fetcher: (_) async => _forcedJson, now: _now),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hay una nueva actualización'), findsOneWidget);
      expect(find.text('Actualizar ahora'), findsOneWidget);
      expect(find.text('Más tarde'), findsNothing);
      expect(
        find.text(
            'Esta actualización es obligatoria para seguir usando la app.'),
        findsOneWidget,
      );
    });

    testWidgets('sin internet: silencio, sin diálogo ni error', (tester) async {
      SharedPreferences.setMockInitialValues({});
      var calls = 0;
      await tester.pumpWidget(
        _Harness(
          fetcher: (_) async {
            calls++;
            return null;
          },
          now: _now,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hay una nueva actualización'), findsNothing);
      expect(find.text('Inicio'), findsOneWidget);
      // Sin cadencia ya no se anota la última mirada: la
      // comprobación se intenta en cada apertura (y falla en
      // silencio, sin diálogo ni error visible).
      expect(calls, 1);
    });

    testWidgets(
        'al abrir se comprueba siempre aunque se mirara hace '
        'un minuto (fix4, punto 7)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      var calls = 0;
      await tester.pumpWidget(
        _Harness(
          fetcher: (_) async {
            calls++;
            return _newerJson;
          },
          now: _now,
        ),
      );
      await tester.pumpAndSettle();

      // La primera mirada descarga y avisa.
      expect(calls, 1);
      expect(find.text('Hay una nueva actualización'), findsOneWidget);

      // Un minuto después, al volver a abrir, se vuelve a descargar
      // (nada de esperar 4 horas): el aviso sale en cuanto se abre
      // la app tras publicar.
      await tester.tap(find.text('Más tarde'));
      await tester.pump(const Duration(seconds: 4));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pumpAndSettle();
      await UpdateCheckService.checkForUpdate(
        tester.element(find.text('Inicio')),
        fetcher: (_) async {
          calls++;
          return _newerJson;
        },
        nowOverride: _now.add(const Duration(minutes: 1)),
      );
      await tester.pumpAndSettle();
      expect(calls, 2);
    });

    testWidgets('misma versión que la instalada: no hay aviso falso',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        _Harness(
          fetcher: (_) async =>
              '{"latest":"$kAppVersion","apk_url":"https://example.com/app.apk","notes":"La de siempre","force":false}',
          now: _now,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hay una nueva actualización'), findsNothing);
    });

    testWidgets('con el APK ya descargado, el botón es "Instalar"',
        (tester) async {
      // La E/S real de archivos (crear el APK falso) va en runAsync:
      // en un testWidgets sin runAsync la E/S de dart:io no se
      // entrega en la zona FakeAsync y el test se cuelga.
      final dir = await tester.runAsync(
        () => Directory.systemTemp.createTemp('melli_apk_'),
      );
      addTearDown(() => dir!.deleteSync(recursive: true));
      final apk = File('${dir!.path}/quemia-7.7.apk');
      await tester.runAsync(
        () => apk.writeAsBytes(List<int>.generate(20, (i) => i)),
      );
      SharedPreferences.setMockInitialValues({
        kUpdateApkPathKey: apk.path,
        kUpdateApkVersionKey: '7.7',
      });
      await tester.pumpWidget(
        _Harness(fetcher: (_) async => _newerJson, now: _now),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hay una nueva actualización'), findsOneWidget);
      expect(find.text('Instalar'), findsOneWidget);
      expect(find.text('Actualizar ahora'), findsNothing);
    });
  });

  group('comprobación en cada apertura y vuelta a primer plano (fix4, punto 7)',
      () {
    tearDown(() => UpdateCheckService.resetForTests());

    // La versión instalada: la primera mirada no avisa nada.
    const sameVersionJson =
        '{"latest":"7.2","apk_url":"https://example.com/app.apk","notes":"","force":false}';

    /// Espera a que la comprobación inicial (disparada por el primer
    /// frame) termine de verdad: pumpAndSettle no espera a sus
    /// Futures, y una vuelta a primer plano sobre una comprobación en
    /// curso se salta por diseño (el servicio no solapa dos
    /// comprobaciones). Sin esta espera, el test sería una carrera
    /// (en "Más tarde" la inicial reprograma el recordatorio y tarda
    /// más que en los otros casos).
    Future<void> waitForInitialCheck(WidgetTester tester) => tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)),
        );

    testWidgets(
        'al volver a primer plano se comprueba y sale el '
        'diálogo', (tester) async {
      SharedPreferences.setMockInitialValues({});
      var json = sameVersionJson;
      var calls = 0;
      await tester.pumpWidget(
        _Harness(
          fetcher: (_) async {
            calls++;
            return json;
          },
          now: _now,
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Hay una nueva actualización'), findsNothing);
      await waitForInitialCheck(tester);

      // Sin cadencia: volver a primer plano dispara la comprobación
      // aunque la última mirada fuera hace un minuto, y sale el
      // diálogo si hay versión nueva.
      json = _newerJson;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(find.text('Hay una nueva actualización'), findsOneWidget);
      expect(find.text('Actualizar ahora'), findsOneWidget);
    });

    testWidgets(
        '"Más tarde" sigue sin repetirse al volver a primer plano '
        '(solo comprueba, el recordatorio es el que avisa)', (tester) async {
      // El recordatorio ya está programado para mañana: la hora es
      // la REAL (no _now, que es 2026-11-10), para que el test no
      // dependa de la fecha en que se ejecuta. Con _now + 24 h el
      // recordatorio caducaba al correr el test después del
      // 2026-11-11 y la comprobación al volver a primer plano (que
      // usa DateTime.now()) lo reprogramaba, dejando el
      // temporizador de 3 s de la copia del icono pendiente al
      // terminar el test.
      SharedPreferences.setMockInitialValues({
        kUpdateDismissedKey: '7.7',
        kUpdateReminderVersionKey: '7.7',
        kUpdateReminderAtKey: DateTime.now()
            .add(const Duration(hours: 24))
            .millisecondsSinceEpoch,
      });
      var calls = 0;
      await tester.pumpWidget(
        _Harness(
          fetcher: (_) async {
            calls++;
            return _newerJson;
          },
          now: _now,
        ),
      );
      await tester.pumpAndSettle();
      // La primera mirada ve la 7.7 descartada: no hay diálogo y el
      // recordatorio por notificación sigue programado.
      expect(calls, 1);
      expect(find.text('Hay una nueva actualización'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kUpdateReminderVersionKey), '7.7');

      // La comprobación inicial reprograma el recordatorio: se
      // espera a que termine antes de la vuelta a primer plano.
      await waitForInitialCheck(tester);
      // Al volver a primer plano sí se comprueba...
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(calls, 2);
      // ...pero la versión pospuesta NO vuelve a avisar: el aviso
      // queda en el recordatorio (no se duplica).
      expect(find.text('Hay una nueva actualización'), findsNothing);
      expect(prefs.getString(kUpdateReminderVersionKey), '7.7');
    });

    testWidgets(
        'force: al volver a primer plano vuelve a avisar '
        'aunque esa versión se descartó', (tester) async {
      // La primera mirada ve la 7.7 normal y descartada (no la
      // misma versión: esa limpiaría el descartado al actualizar).
      // El recordatorio ya está programado (ver el test anterior).
      SharedPreferences.setMockInitialValues({
        kUpdateDismissedKey: '7.7',
        kUpdateReminderVersionKey: '7.7',
        kUpdateReminderAtKey:
            _now.add(const Duration(hours: 24)).millisecondsSinceEpoch,
      });
      var json = _newerJson;
      var calls = 0;
      await tester.pumpWidget(
        _Harness(
          fetcher: (_) async {
            calls++;
            return json;
          },
          now: _now,
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Hay una nueva actualización'), findsNothing);
      await waitForInitialCheck(tester);

      json = _forcedJson;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(find.text('Hay una nueva actualización'), findsOneWidget);
      expect(find.text('Más tarde'), findsNothing);
    });

    testWidgets(
        'la comprobación al volver no se solapa: dos '
        'reanudaciones seguidas son una sola descarga', (tester) async {
      SharedPreferences.setMockInitialValues({});
      var json = sameVersionJson;
      var calls = 0;
      await tester.pumpWidget(
        _Harness(
          fetcher: (_) async {
            calls++;
            return json;
          },
          now: _now,
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      await waitForInitialCheck(tester);

      json = _newerJson;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // La segunda reanudación cae sobre la comprobación en curso
      // y no descarga de nuevo.
      expect(calls, 2);
      expect(find.text('Hay una nueva actualización'), findsOneWidget);
    });
  });

  group('UpdateInstaller (MethodChannel)', () {
    const channel = MethodChannel('com.melliqui/update_installer');
    final calls = <String>[];
    final installedPaths = <String>[];
    var canInstall = true;
    var settingsOpened = false;

    setUp(() {
      calls.clear();
      installedPaths.clear();
      settingsOpened = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        switch (call.method) {
          case 'canInstallUnknownSources':
            return canInstall;
          case 'installApk':
            installedPaths.add(call.arguments['path'] as String);
            return true;
          case 'openUnknownSourcesSettings':
            settingsOpened = true;
            return true;
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    testWidgets('con permiso, instalar abre el instalador del sistema',
        (tester) async {
      canInstall = true;
      // E/S real en runAsync (ver test 28): en testWidgets la E/S de
      // dart:io sin runAsync se cuelga en la zona FakeAsync.
      final dir = await tester.runAsync(
        () => Directory.systemTemp.createTemp('melli_inst_'),
      );
      addTearDown(() => dir!.deleteSync(recursive: true));
      final apk = File('${dir!.path}/quemia-7.7.apk');
      await tester.runAsync(
        () => apk.writeAsBytes(List<int>.generate(10, (i) => i)),
      );
      SharedPreferences.setMockInitialValues({
        kUpdateApkPathKey: apk.path,
        kUpdateApkVersionKey: '7.7',
      });
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Inicio'))),
      );

      await UpdateCheckService.installDownloadedApk(
        tester.element(find.text('Inicio')),
      );
      await tester.pumpAndSettle();

      expect(calls, contains('canInstallUnknownSources'));
      expect(calls, contains('installApk'));
      expect(installedPaths, [apk.path]);
      // La máquina de estados llega a installing.
      expect(UpdateCheckService.downloader.state.value,
          UpdateDownloadState.installing);
      expect(find.text('Permite instalar apps'), findsNothing);
    });

    testWidgets('sin permiso, avisa y ofrece ir a Ajustes', (tester) async {
      canInstall = false;
      // E/S real en runAsync (ver test 28).
      final dir = await tester.runAsync(
        () => Directory.systemTemp.createTemp('melli_inst2_'),
      );
      addTearDown(() => dir!.deleteSync(recursive: true));
      final apk = File('${dir!.path}/quemia-7.7.apk');
      await tester.runAsync(
        () => apk.writeAsBytes(List<int>.generate(10, (i) => i)),
      );
      SharedPreferences.setMockInitialValues({
        kUpdateApkPathKey: apk.path,
        kUpdateApkVersionKey: '7.7',
      });
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Inicio'))),
      );

      // NO se hace await de installDownloadedApk: sin permiso muestra
      // el diálogo y no vuelve hasta que se cierra; esperar aquí
      // bloquearía el test sin poder tocar el botón. Se lanza y se
      // bombea el diálogo.
      unawaited(
        UpdateCheckService.installDownloadedApk(
          tester.element(find.text('Inicio')),
        ),
      );
      await tester.pumpAndSettle();

      expect(installedPaths, isEmpty);
      expect(find.text('Permite instalar apps'), findsOneWidget);
      expect(find.text('Ir a Ajustes'), findsOneWidget);

      await tester.tap(find.text('Ir a Ajustes'));
      await tester.pumpAndSettle();
      expect(settingsOpened, isTrue);
      expect(calls, contains('openUnknownSourcesSettings'));
    });
  });

  group('startDownload (orquestación)', () {
    testWidgets(
        'descarga completa → instalador (idle → downloading → '
        'downloaded → installing)', (tester) async {
      const channel = MethodChannel('com.melliqui/update_installer');
      final installedPaths = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'canInstallUnknownSources') return true;
        if (call.method == 'installApk') {
          installedPaths.add(call.arguments['path'] as String);
          return true;
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      // E/S real en runAsync (ver test 28): la descarga escribe el
      // APK con E/S asíncrona y en testWidgets se cuelga sin runAsync.
      final dir = await tester.runAsync(
        () => Directory.systemTemp.createTemp('melli_dl_'),
      );
      addTearDown(() => dir!.deleteSync(recursive: true));
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Inicio'))),
      );
      final context = tester.element(find.text('Inicio'));

      UpdateCheckService.downloader.state.value = UpdateDownloadState.idle;
      final bytes = List<int>.generate(200, (i) => i % 256);
      await tester.runAsync(
        () => UpdateCheckService.startDownload(
          context,
          _updateInfo,
          fetcher: fakeApkSource(bytes),
          directory: dir,
        ),
      );
      await tester.pumpAndSettle();

      final apk = File('${dir!.path}/quemia-7.7.apk');
      expect(await tester.runAsync(() => apk.exists()), isTrue);
      expect(await tester.runAsync(() => apk.readAsBytes()), bytes);
      expect(installedPaths, [apk.path]);
      expect(UpdateCheckService.downloader.state.value,
          UpdateDownloadState.installing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kUpdateApkPathKey), apk.path);
      expect(prefs.getString(kUpdateApkVersionKey), '7.7');
    });
  });

  group('checkForUpdateManual (fix4, punto 7)', () {
    tearDown(() => UpdateCheckService.resetForTests());

    /// Pantalla mínima con contexto para llamar al servicio.
    Future<BuildContext> pumpHome(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Inicio'))),
      );
      return tester.element(find.text('Inicio'));
    }

    testWidgets(
        'versión nueva: muestra el diálogo y devuelve '
        'updateAvailable', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final context = await pumpHome(tester);

      ManualUpdateResult? result;
      unawaited(
        UpdateCheckService.checkForUpdateManual(
          context,
          fetcher: (_) async => _newerJson,
        ).then((r) => result = r),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hay una nueva actualización'), findsOneWidget);
      expect(find.text('Versión 1.0 disponible'), findsOneWidget);

      // Cerrar con "Más tarde" para que el método termine.
      await tester.tap(find.text('Más tarde'));
      // El avance de 4 s dispara el límite de 3 s de la copia
      // del icono (ver el test de "Más tarde").
      await tester.pump(const Duration(seconds: 4));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pumpAndSettle();
      expect(result, ManualUpdateResult.updateAvailable);
    });

    testWidgets('ya estamos al día: upToDate, sin diálogo', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final context = await pumpHome(tester);

      final result = await UpdateCheckService.checkForUpdateManual(
        context,
        fetcher: (_) async =>
            '{"latest":"$kAppVersion","apk_url":"https://example.com/app.apk","notes":"","force":false}',
      );
      await tester.pumpAndSettle();
      expect(result, ManualUpdateResult.upToDate);
      expect(find.text('Hay una nueva actualización'), findsNothing);
    });

    testWidgets('sin internet: checkFailed, sin diálogo', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final context = await pumpHome(tester);

      final result = await UpdateCheckService.checkForUpdateManual(
        context,
        fetcher: (_) async => null,
      );
      await tester.pumpAndSettle();
      expect(result, ManualUpdateResult.checkFailed);
      expect(find.text('Hay una nueva actualización'), findsNothing);
    });

    testWidgets(
        'pasa por encima de "Más tarde": versión descartada '
        'SÍ muestra el diálogo', (tester) async {
      SharedPreferences.setMockInitialValues({
        kUpdateDismissedKey: '7.7',
      });
      final context = await pumpHome(tester);

      ManualUpdateResult? result;
      unawaited(
        UpdateCheckService.checkForUpdateManual(
          context,
          fetcher: (_) async => _newerJson,
        ).then((r) => result = r),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hay una nueva actualización'), findsOneWidget);

      await tester.tap(find.text('Más tarde'));
      // El avance de 4 s dispara el límite de 3 s de la copia
      // del icono (ver el test de "Más tarde").
      await tester.pump(const Duration(seconds: 4));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pumpAndSettle();
      expect(result, ManualUpdateResult.updateAvailable);
    });
  });

  group(
      'botón "Buscar actualización" en Ajustes (fix4, punto 7; '
      '7.1: mudado de Cuenta)', () {
    tearDown(() => UpdateCheckService.resetForTests());

    const sameJson =
        '{"latest":"7.2","apk_url":"https://example.com/app.apk","notes":"","force":false}';

    Future<void> pumpAccount(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await UserPrefs.load();
      await ProgressService.load();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsScreen(
              onOpenScreen: (_) {},
            ),
          ),
        ),
      );
      // Unos pumps bastan (sin pumpAndSettle: en la app real el
      // corazón de la tarjeta de estadísticas late sin parar y
      // pumpAndSettle no terminaría nunca).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // La fila está en Ajustes, no en Cuenta: se baja hasta ella
      // para que se construya (el ListView solo pinta lo visible).
      await tester.scrollUntilVisible(
        find.text('Buscar actualización'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('con versión nueva, abre el diálogo de actualización',
        (tester) async {
      await pumpAccount(tester);
      // La comprobación al abrir arma el servicio con el falso (que
      // primero dice 7.2, la instalada); el botón usa ese mismo
      // falso y en su segunda llamada dice 7.7.
      var calls = 0;
      Future<String?> statefulFetcher(Uri url) async {
        calls++;
        return calls == 1 ? sameJson : _newerJson;
      }

      await UpdateCheckService.checkForUpdate(
        tester.element(find.text('Buscar actualización')),
        fetcher: statefulFetcher,
        nowOverride: _now,
      );
      await tester.pump();
      expect(calls, 1);
      expect(find.text('Hay una nueva actualización'), findsNothing);

      await tester.tap(find.text('Buscar actualización'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(calls, 2);
      expect(find.text('Hay una nueva actualización'), findsOneWidget);
      expect(find.text('Versión 1.0 disponible'), findsOneWidget);
    });

    testWidgets('sin versión nueva, avisa "Ya tienes la última versión"',
        (tester) async {
      await pumpAccount(tester);
      await UpdateCheckService.checkForUpdate(
        tester.element(find.text('Buscar actualización')),
        fetcher: (_) async => sameJson,
        nowOverride: _now,
      );
      await tester.pump();

      await tester.tap(find.text('Buscar actualización'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Ya tienes la última versión'), findsOneWidget);
      expect(find.text('Hay una nueva actualización'), findsNothing);
    });
  });
}

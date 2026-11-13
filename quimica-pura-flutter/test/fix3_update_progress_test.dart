// Pruebas de la zona C (2026-11-12): la notificación de progreso de
// la descarga de la actualización debe VERSE desde el primer instante
// en el teléfono de Kristian (Redmi, MIUI).
//
// Lo que se rompió en la 7.0: la notificación solo se publicaba cuando
// llegaba el primer trozo Y el servidor daba el total (Content-Length).
// Si la conexión tardaba (la URL del APK de GitHub redirige) o el total
// era desconocido, no había ninguna barra aunque la descarga estuviera
// en marcha. Ahora:
//   (a) la notificación se pide al 0 % nada más arrancar la descarga,
//       antes de que llegue ningún trozo (barra indeterminada, porque
//       el total aún no se conoce);
//   (b) el porcentaje es correcto (50 % a la mitad de los bytes);
//   (c) un total desconocido no rompe nada y sigue mostrando la
//       notificación (indeterminada, y determinada en cuanto el total
//       se conoce);
//   (d) si la descarga falla, se cancela la de progreso y sale la de
//       fallo, sin intentar instalar nada.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/services/update_check.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _updateInfo = UpdateInfo(
  latest: '7.1',
  apkUrl: 'https://example.com/app.apk',
  notes: 'Novedades de la versión',
  force: false,
);

void main() {
  group('UpdateProgressThrottle (porcentaje y ritmo)', () {
    test('percentFor: 50 % a la mitad, 0 % al inicio, 100 % al final',
        () {
      expect(UpdateProgressThrottle.percentFor(0, 100), 0);
      expect(UpdateProgressThrottle.percentFor(50, 100), 50);
      expect(UpdateProgressThrottle.percentFor(100, 100), 100);
      expect(UpdateProgressThrottle.percentFor(1, 3), 33);
    });

    test('percentFor: nunca pasa de 100 y nunca es negativo', () {
      expect(UpdateProgressThrottle.percentFor(150, 100), 100);
      expect(UpdateProgressThrottle.percentFor(-5, 100), 0);
    });

    test('percentFor: total desconocido (<= 0) es -1 (indeterminada)',
        () {
      expect(UpdateProgressThrottle.percentFor(0, -1), -1);
      expect(UpdateProgressThrottle.percentFor(50, -1), -1);
      expect(UpdateProgressThrottle.percentFor(50, 0), -1);
    });

    test('la primera vez siempre se muestra, aunque sea 0 %', () {
      final throttle = UpdateProgressThrottle();
      final now = DateTime(2026, 11, 12, 15, 0, 0);
      expect(
        throttle.shouldShow(received: 0, total: 100, now: now),
        isTrue,
      );
      expect(throttle.lastPercent, 0);
      expect(throttle.showingIndeterminate, isFalse);
    });

    test('sin cambio de porcentaje no se muestra de nuevo', () {
      final throttle = UpdateProgressThrottle();
      final now = DateTime(2026, 11, 12, 15, 0, 0);
      expect(
        throttle.shouldShow(received: 10, total: 100, now: now),
        isTrue,
      );
      expect(
        throttle.shouldShow(
          received: 10,
          total: 100,
          now: now.add(const Duration(seconds: 5)),
        ),
        isFalse,
      );
    });

    test('un cambio de porcentaje antes de 500 ms no se muestra', () {
      final throttle = UpdateProgressThrottle();
      final now = DateTime(2026, 11, 12, 15, 0, 0);
      expect(
        throttle.shouldShow(received: 10, total: 100, now: now),
        isTrue,
      );
      expect(
        throttle.shouldShow(
          received: 11,
          total: 100,
          now: now.add(const Duration(milliseconds: 100)),
        ),
        isFalse,
      );
      expect(
        throttle.shouldShow(
          received: 11,
          total: 100,
          now: now.add(const Duration(milliseconds: 500)),
        ),
        isTrue,
      );
      expect(throttle.lastPercent, 11);
    });

    test('el porcentaje nunca va hacia atrás', () {
      final throttle = UpdateProgressThrottle();
      final now = DateTime(2026, 11, 12, 15, 0, 0);
      expect(
        throttle.shouldShow(received: 50, total: 100, now: now),
        isTrue,
      );
      expect(
        throttle.shouldShow(
          received: 40,
          total: 100,
          now: now.add(const Duration(seconds: 2)),
        ),
        isFalse,
      );
      expect(throttle.lastPercent, 50);
    });

    test('total desconocido: primero indeterminada, luego nada hasta '
        'que se conoce el total, y ese cambio es inmediato', () {
      final throttle = UpdateProgressThrottle();
      final now = DateTime(2026, 11, 12, 15, 0, 0);
      // Primera vez, sin total: se muestra (indeterminada).
      expect(
        throttle.shouldShow(received: 0, total: -1, now: now),
        isTrue,
      );
      expect(throttle.showingIndeterminate, isTrue);
      // Sigue sin total: nada nuevo que mostrar.
      expect(
        throttle.shouldShow(
          received: 500,
          total: -1,
          now: now.add(const Duration(seconds: 5)),
        ),
        isFalse,
      );
      // El total se conoce (aunque hayan pasado solo 100 ms): el paso
      // de indeterminada a determinada se muestra de inmediato.
      expect(
        throttle.shouldShow(
          received: 0,
          total: 100,
          now: now.add(const Duration(milliseconds: 100)),
        ),
        isTrue,
      );
      expect(throttle.showingIndeterminate, isFalse);
      expect(throttle.lastPercent, 0);
    });
  });

  group('UpdateDownloader (onProgress desde el primer byte)', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('melli_prog_test_');
    });

    tearDown(() async {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });

    test('(a) onProgress avisa (0, total) ANTES del primer trozo',
        () async {
      final controller = StreamController<List<int>>();
      final events = <(int, int)>[];
      final dl = UpdateDownloader();
      final future = dl.download(
        info: _updateInfo,
        dir: dir,
        fetcher: (_) async => ApkDownloadSource(
          totalBytes: 100,
          stream: controller.stream,
        ),
        onProgress: (received, total) => events.add((received, total)),
      );
      // La descarga ya pidió la fuente y está esperando el primer
      // trozo: el aviso del 0 % ya tiene que estar.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(events, [(0, 100)]);

      controller.add(List<int>.filled(50, 7));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(events, [(0, 100), (50, 100)]);

      controller.add(List<int>.filled(50, 8));
      await controller.close();
      final file = await future;
      expect(file, isNotNull);
      expect(events, [(0, 100), (50, 100), (100, 100)]);
      expect(await file!.readAsBytes(), hasLength(100));
    });

    test('(b/c) total desconocido: avisa (0, -1) y sigue sin romperse',
        () async {
      final events = <(int, int)>[];
      final dl = UpdateDownloader();
      final file = await dl.download(
        info: _updateInfo,
        dir: dir,
        fetcher: (_) async => ApkDownloadSource(
          totalBytes: -1,
          stream: Stream.fromIterable([
            List<int>.filled(10, 1),
            List<int>.filled(10, 2),
          ]),
        ),
        onProgress: (received, total) => events.add((received, total)),
      );
      expect(file, isNotNull);
      expect(dl.state.value, UpdateDownloadState.downloaded);
      expect(events, [(0, -1), (10, -1), (20, -1)]);
      expect(await file!.readAsBytes(), hasLength(20));
    });

    test('si la descarga falla, onProgress ya avisó del 0 % y no deja '
        'archivo', () async {
      final events = <(int, int)>[];
      final dl = UpdateDownloader();
      final file = await dl.download(
        info: _updateInfo,
        dir: dir,
        fetcher: (_) async => ApkDownloadSource(
          totalBytes: 100,
          stream: Stream<List<int>>.error(Exception('sin red')),
        ),
        onProgress: (received, total) => events.add((received, total)),
      );
      expect(file, isNull);
      expect(dl.state.value, UpdateDownloadState.idle);
      expect(events, [(0, 100)]);
      expect(
        await File('${dir.path}/quemia-7.1.apk').exists(),
        isFalse,
      );
    });
  });

  group('startDownload (la notificación en el canal del plugin)',
      () {
    const notifChannel =
        MethodChannel('dexterous.com/flutter/local_notifications');
    const installerChannel = MethodChannel('com.melliqui/update_installer');

    /// Llamadas al plugin de notificaciones, en orden.
    final notifCalls = <MethodCall>[];

    /// Rutas que se pidieron instalar.
    final installedPaths = <String>[];

    setUp(() {
      // En `flutter test` el target es Linux y el plugin no enruta
      // show()/cancel() a la implementación de Android: sin esto, las
      // llamadas al canal 'dexterous.com/flutter/local_notifications'
      // nunca salen y no hay nada que observar.
      // (debugDefaultTargetPlatformOverride NO va aquí: el framework
      // comprueba las variables debug al terminar el cuerpo del test,
      // antes de los tearDown, así que se pone y se quita dentro de
      // cada test.)
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      notifCalls.clear();
      installedPaths.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notifChannel, (call) async {
        notifCalls.add(call);
        return null;
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(installerChannel, (call) async {
        if (call.method == 'canInstallUnknownSources') return true;
        if (call.method == 'installApk') {
          installedPaths.add(call.arguments['path'] as String);
          return true;
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notifChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(installerChannel, null);
    });

    /// Los `show` de progreso (id 9001) con sus detalles de Android.
    /// (El codec del canal entrega Map<Object?, Object?>, no
    /// Map<String, Object?>: por eso no se castea a String.)
    List<Map<Object?, Object?>> progressShows() => notifCalls
        .where((c) => c.method == 'show')
        .map((c) => c.arguments as Map<Object?, Object?>)
        .where((args) => args['id'] == 9001)
        .map((args) => args['platformSpecifics'] as Map<Object?, Object?>)
        .toList();

    List<Map<Object?, Object?>> allShows() => notifCalls
        .where((c) => c.method == 'show')
        .map((c) => c.arguments as Map<Object?, Object?>)
        .toList();

    testWidgets('(a) la notificación de progreso se pide al 0 % nada '
        'más arrancar, antes de que llegue ningún trozo', (tester) async {
      // Se quita al final del cuerpo (ver setUp): si quedara puesta,
      // el framework protesta por la variable debug cambiada.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final dir = await tester.runAsync(
        () => Directory.systemTemp.createTemp('melli_prog_dl_'),
      );
      addTearDown(() => dir!.deleteSync(recursive: true));
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Inicio'))),
      );
      final context = tester.element(find.text('Inicio'));

      final controller = StreamController<List<int>>();
      Future<void>? downloadFuture;
      await tester.runAsync(() async {
        downloadFuture = UpdateCheckService.startDownload(
          context,
          _updateInfo,
          fetcher: (_) async => ApkDownloadSource(
            totalBytes: 200,
            stream: controller.stream,
          ),
          directory: dir,
          downloader: UpdateDownloader(),
        );
        // La descarga está atascada esperando el primer trozo: la
        // notificación del 0 % ya tiene que haberse pedido.
        await Future<void>.delayed(const Duration(milliseconds: 300));
        final early = progressShows();
        expect(early, isNotEmpty,
            reason: 'ningún show de progreso antes del primer trozo');
        final first = early.first;
        expect(first['channelId'], 'melli_app_updates');
        expect(first['showProgress'], isTrue);
        expect(first['maxProgress'], 100);
        expect(first['progress'], 0);
        expect(first['indeterminate'], isTrue);

        // Llega la mitad, MÁS de 500 ms después del 0 %: el regulador
        // deja pasar la actualización y se muestra el 50 % determinado
        // (el cambio de indeterminada a determinada ya ocurrió con el
        // 0 % al conocerse el total). Sin esa espera, el propio
        // regulador la suprimiría: es el comportamiento que se quiere.
        await Future<void>.delayed(const Duration(milliseconds: 600));
        controller.add(List<int>.filled(100, 7));
        await Future<void>.delayed(const Duration(milliseconds: 300));
        final half = progressShows();
        expect(
          half.any((d) =>
              d['progress'] == 50 && d['indeterminate'] == false),
          isTrue,
          reason: 'no llegó el 50 % determinado: $half',
        );

        controller.add(List<int>.filled(100, 8));
        await controller.close();
        await downloadFuture;
      });
      await tester.pumpAndSettle();

      // Al terminar, la notificación de "Descarga completa" reemplaza
      // a la de progreso y se pide instalar el APK.
      final shows = allShows();
      expect(
        shows.any((args) => args['title'] == 'Descarga completa'),
        isTrue,
      );
      expect(installedPaths, [File('${dir!.path}/quemia-7.1.apk').path]);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('(d) si la descarga falla, se cancela el progreso y '
        'sale el aviso de fallo, sin instalar nada', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final dir = await tester.runAsync(
        () => Directory.systemTemp.createTemp('melli_prog_fail_'),
      );
      addTearDown(() => dir!.deleteSync(recursive: true));
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Inicio'))),
      );
      final context = tester.element(find.text('Inicio'));

      await tester.runAsync(
        () => UpdateCheckService.startDownload(
          context,
          _updateInfo,
          fetcher: (_) async => ApkDownloadSource(
            totalBytes: 100,
            stream: Stream<List<int>>.error(Exception('sin red')),
          ),
          directory: dir,
          downloader: UpdateDownloader(),
        ),
      );
      await tester.pumpAndSettle();

      // La de progreso sí se pidió al arrancar (0 % indeterminada).
      expect(progressShows(), isNotEmpty);
      expect(progressShows().first['indeterminate'], isTrue);
      // … y luego se canceló (id 9001) y salió el aviso de fallo.
      final cancelIndex =
          notifCalls.indexWhere((c) => c.method == 'cancel');
      expect(cancelIndex, greaterThanOrEqualTo(0));
      expect(
        (notifCalls[cancelIndex].arguments as Map)['id'],
        9001,
      );
      final shows = allShows();
      final failIndex =
          shows.indexWhere((args) => args['title'] == 'No se pudo descargar');
      expect(failIndex, greaterThanOrEqualTo(0));
      expect(installedPaths, isEmpty);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}

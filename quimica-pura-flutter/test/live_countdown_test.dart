// Cuenta atrás EN VIVO de la racha (Kristian 2026-11-16): el aviso
// del recordatorio ya NO dice un tiempo fijo ("te quedan 2 h 6
// min"), sino que muestra la cuenta atrás TICKING hasta medianoche,
// como Duolingo, y se queda hasta que se hace la lección o llega
// medianoche. En Android 16+ es un Live Update (Hyper Island); en
// Android <16 es el mismo aviso en curso con cronómetro.
//
// Estos tests cubren el puente Dart (canal com.melliqui/
// live_countdown), la decisión pura de cuándo sale y la medianoche
// de fin. El aviso nativo en sí solo se puede probar en el teléfono
// tras compilar.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/services/live_countdown.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.melliqui/live_countdown');
  final calls = <MethodCall>[];
  var throwOnCall = false;

  setUp(() {
    calls.clear();
    throwOnCall = false;
    LiveCountdown.forceAndroidForTests = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      if (throwOnCall) throw PlatformException(code: 'ERROR');
      return true;
    });
  });

  tearDown(() {
    LiveCountdown.forceAndroidForTests = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('show() llama al canal con título, cuerpo, fin e inicio', () async {
    final endsAt = DateTime(2026, 11, 17);
    final startAt = DateTime(2026, 11, 16, 19);
    final ok = await LiveCountdown.show(
      endsAt: endsAt,
      title: '¡Kristian, ven por una lección!',
      body: 'Toca para practicar y no perder tu racha',
      largeIconPath: '/tmp/melli_notif_britany.png',
      startAt: startAt,
    );
    expect(ok, isTrue);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'show');
    final args = calls.single.arguments as Map<dynamic, dynamic>;
    expect(args['title'], '¡Kristian, ven por una lección!');
    expect(args['body'], 'Toca para practicar y no perder tu racha');
    expect(args['endAtMs'], endsAt.millisecondsSinceEpoch);
    expect(args['startAtMs'], startAt.millisecondsSinceEpoch);
    expect(args['largeIconPath'], '/tmp/melli_notif_britany.png');
  });

  test('schedule() programa la alarma para la hora del recordatorio',
      () async {
    final at = DateTime(2026, 11, 16, 19);
    final endsAt = DateTime(2026, 11, 17);
    final ok = await LiveCountdown.schedule(
      at: at,
      endsAt: endsAt,
      title: '¡Kristian, ven por una lección!',
      body: 'Toca para practicar y no perder tu racha',
    );
    expect(ok, isTrue);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'schedule');
    final args = calls.single.arguments as Map<dynamic, dynamic>;
    expect(args['atMs'], at.millisecondsSinceEpoch);
    expect(args['endAtMs'], endsAt.millisecondsSinceEpoch);
    expect(args['largeIconPath'], isNull);
  });

  test('cancel() llama al canal y devuelve true', () async {
    final ok = await LiveCountdown.cancel();
    expect(ok, isTrue);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'cancel');
  });

  test('si el canal falla, devuelve false sin lanzar', () async {
    throwOnCall = true;
    expect(
      await LiveCountdown.show(
        endsAt: DateTime(2026, 11, 17),
        title: 't',
        body: 'b',
      ),
      isFalse,
    );
    expect(await LiveCountdown.cancel(), isFalse);
  });

  test('fuera de Android no toca el canal', () async {
    LiveCountdown.forceAndroidForTests = false;
    expect(
      await LiveCountdown.show(
        endsAt: DateTime(2026, 11, 17),
        title: 't',
        body: 'b',
      ),
      isFalse,
    );
    expect(await LiveCountdown.cancel(), isFalse);
    expect(calls, isEmpty);
  });

  group('shouldShowLiveCountdown', () {
    test('antes de la hora del recordatorio, todavía no sale', () {
      expect(
        NotificationService.shouldShowLiveCountdown(
          now: DateTime(2026, 11, 16, 18, 30),
          reminderHour: 19,
          reminderMinute: 0,
        ),
        isFalse,
      );
    });

    test('a la hora exacta del recordatorio, ya sale', () {
      expect(
        NotificationService.shouldShowLiveCountdown(
          now: DateTime(2026, 11, 16, 19, 0),
          reminderHour: 19,
          reminderMinute: 0,
        ),
        isTrue,
      );
    });

    test('después de la hora, sale', () {
      expect(
        NotificationService.shouldShowLiveCountdown(
          now: DateTime(2026, 11, 16, 22, 15),
          reminderHour: 19,
          reminderMinute: 0,
        ),
        isTrue,
      );
    });
  });

  test('liveCountdownEndsAt es la medianoche que cierra el día', () {
    expect(
      NotificationService.liveCountdownEndsAt(DateTime(2026, 11, 16, 19, 30)),
      DateTime(2026, 11, 17),
    );
    expect(
      NotificationService.liveCountdownEndsAt(DateTime(2026, 11, 16, 0, 5)),
      DateTime(2026, 11, 17),
    );
  });

  test('liveCountdownBody existe en los 6 idiomas', () {
    for (final entry in AppLang.allStrings.entries) {
      final body = entry.value['liveCountdownBody'];
      expect(body, isNotNull, reason: 'falta en ${entry.key}');
      expect(body, isNotEmpty, reason: 'vacío en ${entry.key}');
    }
    expect(AppLang.allStrings.length, 6);
  });
}

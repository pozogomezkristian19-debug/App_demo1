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
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/services/live_countdown.dart';
import 'package:quimica_pura/services/localization.dart';
import 'package:quimica_pura/services/notification_service.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.melliqui/live_countdown');
  final calls = <MethodCall>[];
  var throwOnCall = false;

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    calls.clear();
    throwOnCall = false;
    UserPrefs.countdownFireMs = 0;
    SharedPreferences.setMockInitialValues({});
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

  test('schedule() programa la alarma para la hora elegida', () async {
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
    test('antes de la hora aleatoria, todavía no sale', () {
      expect(
        NotificationService.shouldShowLiveCountdown(
          now: DateTime(2026, 11, 16, 18, 30),
          fireTime: DateTime(2026, 11, 16, 21, 30),
        ),
        isFalse,
      );
    });

    test('a la hora aleatoria exacta, ya sale', () {
      expect(
        NotificationService.shouldShowLiveCountdown(
          now: DateTime(2026, 11, 16, 21, 30),
          fireTime: DateTime(2026, 11, 16, 21, 30),
        ),
        isTrue,
      );
    });

    test('después de la hora, sale', () {
      expect(
        NotificationService.shouldShowLiveCountdown(
          now: DateTime(2026, 11, 16, 22, 15),
          fireTime: DateTime(2026, 11, 16, 21, 30),
        ),
        isTrue,
      );
    });
  });

  group('randomCountdownFireTime', () {
    test('siempre cae entre las 21:30 y las 23:00', () {
      for (var seed = 0; seed < 20; seed++) {
        final fire = NotificationService.randomCountdownFireTime(
          DateTime(2026, 11, 18),
          Random(seed),
        );
        expect(fire.isBefore(DateTime(2026, 11, 18, 23, 0)), isTrue);
        expect(
          fire.isBefore(DateTime(2026, 11, 18, 21, 30)),
          isFalse,
        );
      }
    });

    test('con la misma semilla da la misma hora', () {
      final a = NotificationService.randomCountdownFireTime(
        DateTime(2026, 11, 18),
        Random(7),
      );
      final b = NotificationService.randomCountdownFireTime(
        DateTime(2026, 11, 18),
        Random(7),
      );
      expect(a, b);
    });
  });

  group('countdownFireTimeForToday', () {
    test('la primera vez genera una hora y la guarda', () async {
      final fire =
          await NotificationService.countdownFireTimeForToday(
        now: DateTime(2026, 11, 18, 10, 0),
        random: Random(7),
      );
      expect(fire.isBefore(DateTime(2026, 11, 18, 23, 0)), isTrue);
      expect(
        fire.isBefore(DateTime(2026, 11, 18, 21, 30)),
        isFalse,
      );
      expect(UserPrefs.countdownFireMs, fire.millisecondsSinceEpoch);
    });

    test('la segunda vez el mismo día devuelve la misma hora', () async {
      final first =
          await NotificationService.countdownFireTimeForToday(
        now: DateTime(2026, 11, 18, 10, 0),
        random: Random(7),
      );
      final second =
          await NotificationService.countdownFireTimeForToday(
        now: DateTime(2026, 11, 18, 20, 0),
        random: Random(99),
      );
      expect(second, first);
    });

    test('al día siguiente genera una hora nueva', () async {
      final first =
          await NotificationService.countdownFireTimeForToday(
        now: DateTime(2026, 11, 18, 10, 0),
        random: Random(7),
      );
      final next =
          await NotificationService.countdownFireTimeForToday(
        now: DateTime(2026, 11, 19, 10, 0),
        random: Random(7),
      );
      expect(next.day, 19);
      expect(next.millisecondsSinceEpoch, isNot(first.millisecondsSinceEpoch));
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

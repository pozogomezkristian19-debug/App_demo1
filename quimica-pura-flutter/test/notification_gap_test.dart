// Pruebas del aviso diario de repaso (Kristian 2026-11-17): UN
// aviso al día a la hora elegida (por defecto 19:00), nunca una
// tanda de varios cada 1-3 horas. La próxima ocurrencia es hoy si
// la hora aún no pasó, si no mañana.
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);
  test('nextDailyReminder: hoy si la hora no pasó, mañana si pasó', () {
    final loc = tz.getLocation('America/Havana');
    final morning = tz.TZDateTime(loc, 2026, 11, 17, 10, 0);
    final next = NotificationService.nextDailyReminder(
      hour: 19,
      minute: 0,
      now: morning,
    );
    expect(next.hour, 19);
    expect(next.minute, 0);
    expect(next.day, 17);
    expect(next.isAfter(morning), isTrue);

    final night = tz.TZDateTime(loc, 2026, 11, 17, 20, 30);
    final nextDay = NotificationService.nextDailyReminder(
      hour: 19,
      minute: 0,
      now: night,
    );
    expect(nextDay.day, 18);
    expect(nextDay.hour, 19);
    expect(nextDay.isAfter(night), isTrue);

    // Justo a la hora: ya pasó (no es "después"), toca mañana.
    final exact = tz.TZDateTime(loc, 2026, 11, 17, 19, 0);
    final rolled = NotificationService.nextDailyReminder(
      hour: 19,
      minute: 0,
      now: exact,
    );
    expect(rolled.day, 18);
  });

  test('nextDailyReminder: respeta la hora elegida, no solo las 19:00',
      () {
    final loc = tz.getLocation('America/Havana');
    final now = tz.TZDateTime(loc, 2026, 11, 17, 8, 0);
    final next = NotificationService.nextDailyReminder(
      hour: 7,
      minute: 30,
      now: now,
    );
    // Las 7:30 de hoy ya pasaron: toca mañana.
    expect(next.day, 18);
    expect(next.hour, 7);
    expect(next.minute, 30);
    expect(next.difference(now).inHours, lessThan(24));
  });
}

// Pruebas del intervalo real de notificaciones (v6, item 13): los
// avisos llegan a intervalos aleatorios siempre de más de 1 hora
// (61-180 minutos), nunca en avalancha.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/services/notification_service.dart';

void main() {
  test('los huecos entre avisos siempre son de más de 1 hora (61-180 min)',
      () {
    for (var seed = 0; seed < 100; seed++) {
      final gap = NotificationService.nextGapMinutes(Random(seed));
      expect(gap, greaterThanOrEqualTo(61));
      expect(gap, lessThanOrEqualTo(180));
      expect(NotificationService.gapIsValid(gap), isTrue);
    }
  });

  test('gapIsValid: 60 no vale, 61 y 180 sí, 181 no', () {
    expect(NotificationService.gapIsValid(60), isFalse);
    expect(NotificationService.gapIsValid(61), isTrue);
    expect(NotificationService.gapIsValid(180), isTrue);
    expect(NotificationService.gapIsValid(181), isFalse);
  });
}

// Pruebas de la ronda #4, punto 10: el widget muestra un tip.
// El tip rota cada día (estable dentro del día, cambia al día
// siguiente, como la pregunta del día): es un consejo de estudio de
// la app, localizado en el idioma activo, con etiqueta "Tip:", sin
// emojis, guardado con HomeWidget.saveWidgetData('tip', ...) y con su
// propio TextView (widget_tip) en el layout nativo. La pregunta del
// día y la fila Racha/Vidas/Puntos se mantienen como estaban.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/data/i18n/content_i18n.dart';
import 'package:quimica_pura/services/home_widget_service.dart';
import 'package:quimica_pura/services/progress.dart';
import 'package:quimica_pura/services/user_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('tipOfTheDay es determinista por día', () {
    test('la misma fecha da siempre el mismo tip', () {
      final day = DateTime(2026, 11, 10);
      final a = tipOfTheDay(day);
      final b = tipOfTheDay(DateTime(2026, 11, 10, 23, 59));
      expect(a.title, b.title);
      expect(a.body, b.body);
    });

    test('el tip cambia de un día a otro (rota)', () {
      final titles = <String>{
        for (var d = 1; d <= 30; d++) tipOfTheDay(DateTime(2026, 11, d)).title,
      };
      // Con 10 tips en el banco, en 30 días tienen que salir varios.
      expect(titles.length, greaterThan(1));
    });

    test('el tip sale del banco localizado de consejos', () {
      final bank = localizedGeneralTips();
      expect(bank.length, 10);
      for (var d = 1; d <= 30; d++) {
        final tip = tipOfTheDay(DateTime(2026, 11, d));
        expect(
          bank.any((t) => t.title == tip.title && t.body == tip.body),
          isTrue,
          reason: 'tip del día $d no está en el banco',
        );
      }
    });

    test('ningún tip del banco tiene emojis', () {
      for (final tip in localizedGeneralTips()) {
        for (final text in [tip.title, tip.body]) {
          expect(
            text.runes.any((r) => r >= 0x1F000 || r == 0xFE0F),
            isFalse,
            reason: 'emoji en "$text"',
          );
        }
      }
    });
  });

  group('HomeWidgetService.update guarda el tip', () {
    test('el tip de hoy se guarda con la etiqueta "Tip:" y la pregunta '
        'del día sigue guardándose', () async {
      SharedPreferences.setMockInitialValues({'melli_rules_seen_v6': true});
      await UserPrefs.load();
      await ProgressService.load();

      // Se capturan las llamadas al canal del plugin home_widget
      // (home_widget-0.10.0: canal 'home_widget', método
      // 'saveWidgetData' con {'id': ..., 'data': ...}).
      final saved = <String, Object?>{};
      var updateWidgetCalled = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('home_widget'),
        (call) async {
          if (call.method == 'saveWidgetData') {
            final args = call.arguments as Map;
            saved[args['id'] as String] = args['data'];
            return true;
          }
          if (call.method == 'updateWidget') {
            updateWidgetCalled = true;
            expect(call.arguments['name'], 'MelliQuiWidgetProvider');
            return true;
          }
          return null;
        },
      );

      await HomeWidgetService.update();

      final tip = tipOfTheDay(DateTime.now());
      // Lo guardado es el tip con las flechas "→" sustituidas por
      // "a" (el widget nativo no puede arriesgarse a un glifo que
      // falte en la fuente del sistema); el texto original del banco
      // (con flechas) sigue intacto en Tips de examen.
      final expected = (tip.body.isEmpty
              ? 'Tip: ${tip.title}'
              : 'Tip: ${tip.title} — ${tip.body}')
          .replaceAll('→', 'a');
      expect(saved['tip'], expected);
      expect((saved['tip'] as String).startsWith('Tip: '), isTrue);
      expect((saved['tip'] as String).contains('→'), isFalse);
      // La pregunta del día y las estadísticas siguen guardándose.
      expect(saved['qotd'], isNotNull);
      expect((saved['qotd'] as String).isNotEmpty, isTrue);
      expect(saved['streak'], isNotNull);
      expect(saved['lives'], isNotNull);
      expect(saved['points'], isNotNull);
      expect(updateWidgetCalled, isTrue);
    });
  });
}

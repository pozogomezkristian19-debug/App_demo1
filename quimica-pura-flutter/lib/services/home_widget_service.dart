// Widget de la pantalla de inicio (v6): tarjeta con un tip de
// estudio que rota cada día (fix4, punto 10), la racha, las vidas
// y los puntos. Al tocarla se abre la app.
// La parte nativa vive en MelliQuiWidgetProvider (Kotlin, RemoteViews);
// aquí solo se le mandan los datos con home_widget y se pide que se
// actualice. Si no hay widget instalado (o el plugin falla), la app
// sigue igual: update() nunca lanza una excepción.
//
// Widget mejorado (2026-11-18, diseño v3 aprobado por Kristian:
// tarjeta estilo Duolingo): además del tip, la meta del día
// (1 nivel al día) con su progreso y su estado, y las vidas sobre
// 10 — el widget viejo decía /5 y estaba mal. Los números van
// sueltos (streakNum, livesNum, pointsNum) porque en el layout
// nativo cada uno lleva su icono (llama, corazón, rayo) delante.
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../data/i18n/content_i18n.dart';
import 'localization.dart';
import 'points.dart';
import 'progress.dart';

class HomeWidgetService {
  HomeWidgetService._();

  /// Nombre de la clase Kotlin del proveedor (sin el paquete).
  static const providerName = 'MelliQuiWidgetProvider';

  static Future<void> update() async {
    try {
      final p = ProgressService.instance;
      // Tip del día (fix4, punto 10): mismo día, mismo tip;
      // cambia al día siguiente. Texto localizado
      // en el idioma de la app, con la etiqueta "Tip:". Sin emojis.
      // Las flechas "→" se sustituyen por "a" SOLO en lo que se
      // guarda para el widget: el widget corre en el lado nativo con
      // la fuente del sistema y una flecha que no esté en la fuente
      // se vería como un cuadradito; el texto original (con flechas)
      // de Tips de examen NO se toca.
      final tip = tipOfTheDay(DateTime.now());
      if (tip.title.isNotEmpty) {
        final tipText = (tip.body.isEmpty
                ? 'Tip: ${tip.title}'
                : 'Tip: ${tip.title} — ${tip.body}')
            .replaceAll('→', 'a');
        await HomeWidget.saveWidgetData<String>('tip', tipText);
      }
      await HomeWidget.saveWidgetData<String>(
          'streakNum', '${p.streakNow}');
      await HomeWidget.saveWidgetData<String>(
          'livesNum', '${p.livesLeft}/$maxLives');
      await HomeWidget.saveWidgetData<String>('pointsNum', '${p.points}');
      // Meta del día (widget mejorado, 2026-11-18): 1 nivel al día.
      // Etiqueta localizada, si está hecha o no, progreso 0/100 y
      // texto de estado ("¡Meta cumplida!" o "0/1").
      await HomeWidget.saveWidgetData<String>(
          'goalLabel', tr('obWidgetGoal'));
      final goalDone = p.dailyGoalDone;
      await HomeWidget.saveWidgetData<bool>('goalDone', goalDone);
      await HomeWidget.saveWidgetData<int>(
          'goalProgress', goalDone ? 100 : 0);
      await HomeWidget.saveWidgetData<String>(
        'goalStatus',
        goalDone ? tr('obWidgetGoalDone') : '${p.levelsPassedToday()}/1',
      );
      await HomeWidget.updateWidget(name: providerName);
    } catch (_) {
      // Sin widget instalado o sin el plugin: no pasa nada.
    }
  }

  /// Canal nativo para pedir el widget (2026-11-18, pantalla
  /// "Pon Quemia en tu pantalla principal"): abre el diálogo del
  /// sistema para fijar el widget en la pantalla principal
  /// (AppWidgetManager.requestPinAppWidget, Android 8+). Devuelve
  /// true si el sistema mostró el diálogo; false si no se puede
  /// (Android viejo, sin soporte o error) — en ese caso la
  /// pantalla avanza igual: poner el widget no es obligatorio.
  static const _pinChannel = MethodChannel('com.melliqui/app_widget');

  static Future<bool> requestPin() async {
    try {
      final pinned = await _pinChannel.invokeMethod<bool>('requestPin');
      return pinned ?? false;
    } catch (_) {
      return false;
    }
  }
}

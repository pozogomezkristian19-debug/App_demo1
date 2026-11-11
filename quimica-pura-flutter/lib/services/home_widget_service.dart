// Widget de la pantalla de inicio (v6): tarjeta con un tip de
// estudio que rota cada día (fix4, punto 10), la racha, las vidas
// y los puntos. Al tocarla se abre la app.
// La parte nativa vive en MelliQuiWidgetProvider (Kotlin, RemoteViews);
// aquí solo se le mandan los datos con home_widget y se pide que se
// actualice. Si no hay widget instalado (o el plugin falla), la app
// sigue igual: update() nunca lanza una excepción.
import 'package:home_widget/home_widget.dart';

import '../data/i18n/content_i18n.dart';
import 'localization.dart';
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
          'streak', '${tr('streakWord')}: ${p.streakNow}');
      await HomeWidget.saveWidgetData<String>(
          'lives', '${tr('livesTitle')}: ${p.livesLeft}/5');
      await HomeWidget.saveWidgetData<String>(
          'points', '${tr('pointsTitle')}: ${p.points}');
      await HomeWidget.updateWidget(name: providerName);
    } catch (_) {
      // Sin widget instalado o sin el plugin: no pasa nada.
    }
  }
}

// Widget de la pantalla de inicio (v6): tarjeta con la pregunta del
// día, la racha, las vidas y los puntos. Al tocarla se abre la app.
// La parte nativa vive en MelliQuiWidgetProvider (Kotlin, RemoteViews);
// aquí solo se le mandan los datos con home_widget y se pide que se
// actualice. Si no hay widget instalado (o el plugin falla), la app
// sigue igual: update() nunca lanza una excepción.
import 'package:home_widget/home_widget.dart';

import '../data/extra_content.dart';
import '../data/i18n/content_i18n.dart';
import '../data/questions.dart';
import 'localization.dart';
import 'progress.dart';

class HomeWidgetService {
  HomeWidgetService._();

  /// Nombre de la clase Kotlin del proveedor (sin el paquete).
  static const providerName = 'MelliQuiWidgetProvider';

  static Future<void> update() async {
    try {
      final p = ProgressService.instance;
      final today = questionOfTheDay(DateTime.now());
      final index = allQuestions.indexOf(today);
      final q = index >= 0 ? localizedQuestionAt(index) : today;
      await HomeWidget.saveWidgetData<String>('qotd', q.question);
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

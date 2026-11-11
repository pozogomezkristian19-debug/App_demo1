// Widget de la pantalla de inicio (v6; fix4, punto 10: línea de tip):
// tarjeta con la pregunta del día, un tip de estudio que rota cada
// día, la racha, las vidas y los puntos. Al tocarla se abre la app.
// Plantilla del paquete home_widget 0.10.0 (su ejemplo): extiende
// HomeWidgetProvider y pinta un RemoteViews con los datos que Dart
// guarda con HomeWidget.saveWidgetData. Sin interactividad de fondo:
// el toque entero abre MainActivity.
package com.melliqui.quimica_pura

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class MelliQuiWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views =
          RemoteViews(context.packageName, R.layout.melli_qui_widget).apply {
            // Tocar la tarjeta abre la app.
            val pendingIntent =
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            setOnClickPendingIntent(R.id.widget_container, pendingIntent)

            setTextViewText(
                R.id.widget_qotd,
                widgetData.getString("qotd", null) ?: "Quemia",
            )
            // Tip de estudio del día (fix4, punto 10): si no hay
            // tip guardado, el TextView queda vacío y no ocupa sitio.
            setTextViewText(
                R.id.widget_tip,
                widgetData.getString("tip", null) ?: "",
            )
            setTextViewText(
                R.id.widget_streak,
                widgetData.getString("streak", null) ?: "",
            )
            setTextViewText(
                R.id.widget_lives,
                widgetData.getString("lives", null) ?: "",
            )
            setTextViewText(
                R.id.widget_points,
                widgetData.getString("points", null) ?: "",
            )
          }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}

// Widget de la pantalla de inicio (mejorado, 2026-11-18, diseño v3
// aprobado por Kristian: tarjeta estilo Duolingo (blanca en claro,
// oscura en oscuro), cara de
// Brenda, llama + racha, tip de estudio del día, meta del día con
// barra teal, corazón + vidas sobre 10 y rayo + puntos).
// Al tocarla se abre la app.
// Plantilla del paquete home_widget 0.10.0 (su ejemplo): extiende
// HomeWidgetProvider y pinta un RemoteViews con los datos que Dart
// guarda con HomeWidget.saveWidgetData. Sin interactividad de fondo:
// el toque entero abre MainActivity.
package com.melliqui.quimica_pura

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
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

            // Cara de Brenda en círculo (assets de Flutter): si no se
            // puede leer, el ImageView queda vacío y no rompe nada.
            setCircularFace(context, this)

            // Tip de estudio del día (fix4, punto 10): si no hay
            // tip guardado, el TextView queda vacío y no ocupa sitio.
            setTextViewText(
                R.id.widget_tip,
                widgetData.getString("tip", null) ?: "",
            )
            // Racha: solo el número; la llama va en el layout.
            setTextViewText(
                R.id.widget_streak_num,
                widgetData.getString("streakNum", null) ?: "",
            )
            // Meta del día (1 nivel al día): etiqueta, estado
            // ("¡Meta cumplida!" o "0/1") y barra 0/100.
            setTextViewText(
                R.id.widget_goal_label,
                widgetData.getString("goalLabel", null) ?: "",
            )
            setTextViewText(
                R.id.widget_goal_status,
                widgetData.getString("goalStatus", null) ?: "",
            )
            setProgressBar(
                R.id.widget_goal_progress,
                100,
                widgetData.getInt("goalProgress", 0).coerceIn(0, 100),
                false,
            )
            // Vidas sobre 10 (el widget viejo decía /5 y estaba mal)
            // y puntos: solo los números; corazón y rayo van en el
            // layout.
            setTextViewText(
                R.id.widget_lives_num,
                widgetData.getString("livesNum", null) ?: "",
            )
            setTextViewText(
                R.id.widget_points_num,
                widgetData.getString("pointsNum", null) ?: "",
            )
          }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }

  /// Cara de Brenda recortada en círculo desde los assets de
  /// Flutter (flutter_assets/assets/brenda.png); si no se puede
  /// leer, se prueba el avatar por defecto. Sin cara no se rompe
  /// nada: el ImageView queda vacío.
  private fun setCircularFace(context: Context, views: RemoteViews) {
    try {
      val bitmap = decodeFace(context, "flutter_assets/assets/brenda.png")
          ?: decodeFace(context, "flutter_assets/assets/avatar_default.png")
          ?: return
      val size = minOf(bitmap.width, bitmap.height)
      val square = Bitmap.createBitmap(
          bitmap,
          (bitmap.width - size) / 2,
          (bitmap.height - size) / 2,
          size,
          size,
      )
      val out = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
      val canvas = Canvas(out)
      val paint = Paint(Paint.ANTI_ALIAS_FLAG)
      canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)
      paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
      canvas.drawBitmap(square, 0f, 0f, paint)
      views.setImageViewBitmap(R.id.widget_face, out)
    } catch (_: Exception) {
      // Sin cara: el widget sigue igual.
    }
  }

  private fun decodeFace(context: Context, assetPath: String): Bitmap? {
    return try {
      context.assets.open(assetPath).use { stream ->
        BitmapFactory.decodeStream(stream)
      }
    } catch (_: Exception) {
      null
    }
  }
}

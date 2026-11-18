package com.melliqui.quimica_pura

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.os.SystemClock
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import java.io.File

/**
 * Cuenta atrás EN VIVO de la racha (Kristian 2026-11-16): el aviso
 * del recordatorio no dice un tiempo fijo ("te quedan 2 h 6 min"),
 * sino que muestra la cuenta atrás TICKING hasta medianoche, como
 * Duolingo, y se queda ahí hasta que se hace la lección o llega
 * medianoche.
 *
 * Cómo funciona:
 * - El aviso es una vista personalizada IGUAL que la de Duolingo
 *   (res/layout/live_countdown_notification.xml): la melliza a la
 *   izquierda, el título a la derecha y la cuenta atrás en ROJO
 *   debajo del título. El Chronometer va bajando solo, segundo a
 *   segundo, sin que la app tenga que re-publicar nada.
 * - ISLA (Kristian 2026-11-17, sus capturas de Duolingo 21:48):
 *   él quiere que salga TAMBIÉN en la isla, como Duolingo. La
 *   isla de HyperOS no lee el Chronometer de la vista
 *   personalizada: lee el cronómetro ESTÁNDAR del aviso (when +
 *   usesChronometer + countDown). Por eso el constructor pone
 *   esos tres campos ADEMÁS de la vista personalizada: la vista
 *   sigue mandando en la pantalla de bloqueo y la cortina, y la
 *   isla coge el cronómetro estándar y enseña la cuenta atrás
 *   bajando. El compromiso del 2026-11-16 («me quedo con la
 *   notificación») queda superado: ahora son las dos cosas.
 * - El aviso es EN CURSO (ongoing): no se puede barrer con el
 *   dedo; se quita al tocarlo (abre la app y la app lo cancela
 *   cuando se hace la lección) o a medianoche. Igual que Duolingo.
 * - Se publica de dos formas: AHORA (show, la app está abierta) o
 *   con una alarma exacta a la hora del recordatorio (schedule, la
 *   app cerrada): la alarma la dispara LiveCountdownReceiver, que
 *   publica el aviso sin necesidad de Dart. Al reiniciar el
 *   teléfono, BootReceiver vuelve a programar la alarma si la hora
 *   aún no pasó (los datos quedan en SharedPreferences).
 */
object LiveCountdown {
    const val NOTIFICATION_ID = 7001
    const val CHANNEL_ID = "melli_study_reminders"
    private const val PREFS = "quemia_live_countdown"
    private const val ALARM_REQUEST_CODE = 7001

    /** Publica la cuenta atrás AHORA (la app está abierta). */
    fun show(
        context: Context,
        title: String,
        body: String,
        endAtMs: Long,
        startAtMs: Long,
        largeIconPath: String?,
    ) {
        try {
            ensureChannel(context)
            val notification = buildNotification(
                context, title, body, endAtMs, startAtMs, largeIconPath,
            )
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE)
                as NotificationManager
            nm.notify(NOTIFICATION_ID, notification)
        } catch (_: Exception) {
            // Sin permiso de avisos (revocado en ajustes) el post
            // lanza SecurityException: la cuenta atrás simplemente
            // no sale; la app sigue.
        }
    }

    /**
     * Programa la cuenta atrás para las [atMs] con una alarma exacta
     * (la app puede estar cerrada). Guarda los datos para volver a
     * programarla tras un reinicio. Devuelve false si no se pudo
     * programar la alarma.
     */
    fun schedule(
        context: Context,
        atMs: Long,
        title: String,
        body: String,
        endAtMs: Long,
        largeIconPath: String?,
    ): Boolean {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit()
            .putLong("atMs", atMs)
            .putString("title", title)
            .putString("body", body)
            .putLong("endAtMs", endAtMs)
            .putLong("startAtMs", atMs)
            .putString("largeIconPath", largeIconPath)
            .apply()
        return setAlarm(context, atMs, title, body, endAtMs, atMs, largeIconPath)
    }

    /** Quita la cuenta atrás y cancela su alarma (si la había). */
    fun cancel(context: Context) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE)
                as NotificationManager
            nm.cancel(NOTIFICATION_ID)
        } catch (_: Exception) {
            // Quitar un aviso que no existe no es un error.
        }
        try {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.cancel(alarmPendingIntent(context, "", "", 0L, 0L, null))
        } catch (_: Exception) {
            // Sin alarma que cancelar, nada que hacer.
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().clear().apply()
    }

    /** Vuelve a programar la alarma guardada (tras un reinicio). */
    fun rescheduleFromPrefs(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val atMs = prefs.getLong("atMs", 0L)
        if (atMs <= System.currentTimeMillis()) return false
        return setAlarm(
            context,
            atMs,
            prefs.getString("title", "Quemia") ?: "Quemia",
            prefs.getString("body", "") ?: "",
            prefs.getLong("endAtMs", 0L),
            prefs.getLong("startAtMs", atMs),
            prefs.getString("largeIconPath", null),
        )
    }

    private fun setAlarm(
        context: Context,
        atMs: Long,
        title: String,
        body: String,
        endAtMs: Long,
        startAtMs: Long,
        largeIconPath: String?,
    ): Boolean {
        return try {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = alarmPendingIntent(context, title, body, endAtMs, startAtMs, largeIconPath)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, pi)
                } else {
                    @Suppress("DEPRECATION")
                    am.setExact(AlarmManager.RTC_WAKEUP, atMs, pi)
                }
            } catch (_: SecurityException) {
                // Sin permiso de alarmas exactas (Android 12+): la
                // alarma inexacta puede llegar tarde, pero llega.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, pi)
                } else {
                    @Suppress("DEPRECATION")
                    am.set(AlarmManager.RTC_WAKEUP, atMs, pi)
                }
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun alarmPendingIntent(
        context: Context,
        title: String,
        body: String,
        endAtMs: Long,
        startAtMs: Long,
        largeIconPath: String?,
    ): PendingIntent {
        val intent = Intent(context, LiveCountdownReceiver::class.java).apply {
            putExtra("title", title)
            putExtra("body", body)
            putExtra("endAtMs", endAtMs)
            putExtra("startAtMs", startAtMs)
            putExtra("largeIconPath", largeIconPath)
        }
        return PendingIntent.getBroadcast(
            context,
            ALARM_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun buildNotification(
        context: Context,
        title: String,
        body: String,
        endAtMs: Long,
        startAtMs: Long,
        largeIconPath: String?,
    ): Notification {
        val contentIntent = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val smallIconId = context.resources.getIdentifier(
            "ic_notif_bell", "drawable", context.packageName,
        ).takeIf { it != 0 } ?: context.applicationInfo.icon
        val largeIcon = largeIconPath?.let { path ->
            try {
                val file = File(path)
                if (!file.exists()) {
                    null
                } else {
                    // El PNG de la melliza es 1600x1600: sin
                    // achicarlo, el Bitmap por Binder es demasiado
                    // grande y el aviso no se publica.
                    val bounds = BitmapFactory.Options().apply {
                        inJustDecodeBounds = true
                    }
                    BitmapFactory.decodeFile(path, bounds)
                    val sample = (bounds.outWidth / 112).coerceAtLeast(1)
                    BitmapFactory.decodeFile(
                        path,
                        BitmapFactory.Options().apply {
                            inSampleSize = sample
                        },
                    )
                }
            } catch (_: Exception) {
                null
            }
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(smallIconId)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setAutoCancel(false)
            // Cronómetro ESTÁNDAR (2026-11-17): la isla de HyperOS
            // enseña la cuenta atrás desde aquí; la vista
            // personalizada de abajo sigue mandando en la cortina
            // y la pantalla de bloqueo.
            .setWhen(endAtMs)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
        if (largeIcon != null) builder.setLargeIcon(largeIcon)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            // Android 7+: vista personalizada IGUAL que Duolingo
            // (res/layout/live_countdown_notification.xml): icono +
            // título + cuenta atrás en ROJO debajo del título, con
            // un Chronometer que baja solo segundo a segundo.
            val views = RemoteViews(
                context.packageName,
                R.layout.live_countdown_notification,
            )
            views.setTextViewText(R.id.live_title, title)
            if (largeIcon != null) {
                views.setImageViewBitmap(R.id.live_icon, largeIcon)
            }
            // La base del Chronometer va en tiempo de
            // SystemClock.elapsedRealtime(), NO en hora de pared:
            // medianoche menos ahora, sumado al reloj transcurrido.
            val base = SystemClock.elapsedRealtime() +
                (endAtMs - System.currentTimeMillis())
            views.setBoolean(R.id.live_countdown, "setCountDown", true)
            views.setChronometer(R.id.live_countdown, base, null, true)
            builder.setCustomContentView(views)
            builder.setCustomBigContentView(views)
        } else {
            // Android <7: sin Chronometer en cuenta atrás; el aviso
            // estándar con cronómetro en la zona de la hora.
            val now = System.currentTimeMillis()
            val total = (endAtMs - startAtMs).coerceAtLeast(1L)
            val percent = ((now - startAtMs) * 100 / total).toInt()
                .coerceIn(0, 100)
            builder.setProgress(100, percent, false)
        }
        return builder.build()
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE)
            as NotificationManager
        // Si el canal ya existe (lo creó el plugin de avisos), esto
        // no hace nada: conserva su nombre e importancia.
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Recordatorios de estudio",
            NotificationManager.IMPORTANCE_DEFAULT,
        )
        nm.createNotificationChannel(channel)
    }
}

/** La alarma de la hora del recordatorio: publica la cuenta atrás. */
class LiveCountdownReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra("title") ?: "Quemia"
        val body = intent.getStringExtra("body") ?: ""
        val endAtMs = intent.getLongExtra("endAtMs", 0L)
        if (endAtMs <= System.currentTimeMillis()) return
        LiveCountdown.show(
            context,
            title,
            body,
            endAtMs,
            intent.getLongExtra("startAtMs", System.currentTimeMillis()),
            intent.getStringExtra("largeIconPath"),
        )
    }
}

/** Tras reiniciar el teléfono, la alarma se pierde: se reprograma. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        try {
            LiveCountdown.rescheduleFromPrefs(context)
        } catch (_: Exception) {
            // Sin alarma que reprogramar, nada que hacer.
        }
    }
}

package com.fitmakyp.fitmakyp

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetPlugin
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/** Lo que el widget necesita saber de hoy (la app guarda la semana entera). */
private class Today(p: SharedPreferences) {
    val date: String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    /** 1 = lunes … 7 = domingo. */
    val weekday: Int = (Calendar.getInstance().get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1
    val title: String = p.getString("fm_day_title_$weekday", null) ?: "Abre FitMakyp"
    val info: String = p.getString("fm_day_info_$weekday", null) ?: ""
    val isTraining = info.isNotEmpty()
    val trained = p.getString("fm_trained_date", "") == date
    val inProgress = p.getString("fm_active_date", "") == date
    val glasses = if (p.getString("fm_water_date", "") == date) p.getString("fm_water_glasses", "0")!!.toIntOrNull() ?: 0 else 0
    val goal = (p.getString("fm_water_goal", "8") ?: "8").toIntOrNull()?.coerceAtLeast(1) ?: 8
    val streak = (p.getString("fm_streak", "0") ?: "0").toIntOrNull() ?: 0
    val best = (p.getString("fm_best", "0") ?: "0").toIntOrNull() ?: 0
}

private const val ACTION_ADD_WATER = "com.fitmakyp.fitmakyp.ADD_WATER"
private const val PENDING_PREFIX = "fm_water_pending_"
private fun todayKey(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

/**
 * Vasos sumados desde el widget que la app aún no ha recogido, por fecha.
 * Los devuelve y los borra (la app los suma a su registro).
 */
fun takeWidgetWater(context: Context): Map<String, Int> {
    val p = HomeWidgetPlugin.getData(context)
    val out = mutableMapOf<String, Int>()
    val e = p.edit()
    for ((k, v) in p.all) {
        if (!k.startsWith(PENDING_PREFIX)) continue
        val n = v.toString().toIntOrNull() ?: 0
        if (n > 0) out[k.removePrefix(PENDING_PREFIX)] = n
        e.remove(k)
    }
    e.commit()
    return out
}

private val dayNames = arrayOf("LUNES", "MARTES", "MIÉRCOLES", "JUEVES", "VIERNES", "SÁBADO", "DOMINGO")

/** Widget "Mi día": entreno de hoy, agua y racha. */
class DayWidgetProvider : HomeWidgetProvider() {

    /** "+💧" en el widget: suma un vaso al momento, sin abrir la app. */
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_ADD_WATER) {
            super.onReceive(context, intent)
            return
        }
        val p = HomeWidgetPlugin.getData(context)
        val today = todayKey()
        val glasses = if (p.getString("fm_water_date", "") == today) p.getString("fm_water_glasses", "0")!!.toIntOrNull() ?: 0 else 0
        val pendingKey = PENDING_PREFIX + today
        val pending = p.getString(pendingKey, "0")!!.toIntOrNull() ?: 0
        p.edit()
            .putString("fm_water_date", today)
            .putString("fm_water_glasses", "${(glasses + 1).coerceAtMost(30)}")
            .putString(pendingKey, "${pending + 1}")
            .commit()
        val mgr = AppWidgetManager.getInstance(context)
        onUpdate(context, mgr, mgr.getAppWidgetIds(ComponentName(context, DayWidgetProvider::class.java)), p)
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val t = Today(widgetData)
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.widget_day)
            v.setTextViewText(R.id.day_label, "HOY · ${dayNames[t.weekday - 1]}")
            v.setTextViewText(R.id.day_title, t.title)
            v.setTextViewText(
                R.id.day_info,
                if (t.isTraining) t.info else "Día de recuperación: estira, camina o descansa",
            )
            v.setTextViewText(
                R.id.day_status,
                when {
                    t.trained -> "✓ ¡Hecho!"
                    t.inProgress -> "▶ En curso"
                    t.isTraining -> "Pendiente"
                    else -> "Descanso"
                },
            )
            v.setTextViewText(R.id.day_water, "💧 ${t.glasses}/${t.goal} vasos")
            v.setProgressBar(R.id.day_water_bar, t.goal, t.glasses.coerceAtMost(t.goal), false)
            v.setTextViewText(R.id.day_streak, "🔥 ${t.streak}")
            v.setTextViewText(
                R.id.day_action,
                when {
                    t.trained -> "Ver mi semana →"
                    t.inProgress -> "Continuar →"
                    t.isTraining -> "Entrenar →"
                    else -> "Abrir →"
                },
            )
            v.setOnClickPendingIntent(
                R.id.day_water_add,
                PendingIntent.getBroadcast(
                    context,
                    7,
                    Intent(context, DayWidgetProvider::class.java).setAction(ACTION_ADD_WATER),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            v.setOnClickPendingIntent(
                R.id.day_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("fitmakyp://entrenar")),
            )
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}

/** Imagen de la mascota según el día: feliz si entrenó, animando si toca, descansando si no. */
private fun petBitmap(widgetData: SharedPreferences, t: Today): android.graphics.Bitmap? {
    val mood = when {
        t.trained -> "happy"
        t.isTraining -> "motivating"
        else -> "resting"
    }
    val path = widgetData.getString("fm_pet_img_$mood", null)
    return path?.takeIf { File(it).exists() }?.let { BitmapFactory.decodeFile(it) }
}

/** Widget "Mi mascota": la mascota con su ropa y la racha. */
class PetWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val t = Today(widgetData)
        val bitmap = petBitmap(widgetData, t)
        val name = widgetData.getString("fm_pet_name", "Tu mascota") ?: "Tu mascota"
        val level = widgetData.getString("fm_level", "1") ?: "1"
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.widget_pet)
            if (bitmap != null) {
                v.setImageViewBitmap(R.id.pet_image, bitmap)
                v.setViewVisibility(R.id.pet_image, View.VISIBLE)
            } else {
                v.setViewVisibility(R.id.pet_image, View.GONE)
            }
            v.setTextViewText(
                R.id.pet_streak,
                when (t.streak) {
                    0 -> "¡Empieza tu racha!"
                    1 -> "🔥 1 día"
                    else -> "🔥 ${t.streak} días"
                },
            )
            v.setTextViewText(
                R.id.pet_message,
                when {
                    t.trained -> "$name está feliz 💜"
                    t.inProgress -> "$name te anima ✨"
                    t.isTraining -> "$name te espera 💪"
                    else -> "$name descansa contigo"
                },
            )
            v.setTextViewText(R.id.pet_level, "Mejor: ${t.best} · Nivel $level")
            v.setOnClickPendingIntent(
                R.id.pet_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("fitmakyp://mascota")),
            )
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}

/** Widget "Solo mi mascota": la mascota sin fondo ni texto, sobre el fondo de pantalla. */
class PetOnlyWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val bitmap = petBitmap(widgetData, Today(widgetData))
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.widget_pet_only)
            if (bitmap != null) v.setImageViewBitmap(R.id.pet_only_image, bitmap)
            v.setOnClickPendingIntent(
                R.id.pet_only_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("fitmakyp://mascota")),
            )
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}

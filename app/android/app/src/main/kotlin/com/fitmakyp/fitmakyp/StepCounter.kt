package com.fitmakyp.fitmakyp

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Pasos del día con el podómetro del teléfono (sensor TYPE_STEP_COUNTER).
 * El sensor cuenta pasos desde que se encendió el teléfono; aquí se guarda la diferencia
 * entre lecturas y se suma al día de la lectura. Se lee al abrir la app y con el widget.
 * Los pasos se cuentan desde la primera lectura (la instalación).
 */
object StepCounter {
    private const val PREFS = "fitmakyp_steps"

    private fun sensor(ctx: Context): Sensor? =
        (ctx.getSystemService(Context.SENSOR_SERVICE) as SensorManager).getDefaultSensor(Sensor.TYPE_STEP_COUNTER)

    fun hasSensor(ctx: Context) = sensor(ctx) != null

    fun hasPermission(ctx: Context) = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
        ctx.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED

    private fun today() = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    /** Lee el sensor una vez (máx. 4 s) y guarda. [done] recibe si se pudo leer. */
    fun read(ctx: Context, done: (Boolean) -> Unit) {
        val app = ctx.applicationContext
        val s = sensor(app)
        if (s == null || !hasPermission(app)) {
            done(false)
            return
        }
        val sm = app.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        var finished = false
        val handler = Handler(Looper.getMainLooper())
        val listener = object : SensorEventListener {
            override fun onSensorChanged(e: SensorEvent) {
                if (finished) return
                finished = true
                sm.unregisterListener(this)
                record(app, e.values[0].toLong())
                done(true)
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }
        sm.registerListener(listener, s, SensorManager.SENSOR_DELAY_NORMAL, 0, handler)
        handler.postDelayed({
            if (!finished) {
                finished = true
                sm.unregisterListener(listener)
                done(false)
            }
        }, 4000)
    }

    @Synchronized
    private fun record(ctx: Context, value: Long) {
        val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val last = p.getLong("lastValue", -1)
        // Si el teléfono se reinició, el contador vuelve a 0.
        val delta = when {
            last < 0 -> 0L
            value >= last -> value - last
            else -> value
        }
        val day = today()
        val hist = JSONObject(p.getString("history", "{}") ?: "{}")
        hist.put(day, hist.optLong(day, 0) + delta)
        // Solo los últimos 60 días.
        val keys = hist.keys().asSequence().toList().sorted()
        for (k in keys.dropLast(60)) hist.remove(k)
        p.edit().putLong("lastValue", value).putString("history", hist.toString()).apply()
    }

    fun history(ctx: Context): Map<String, Int> {
        val p = ctx.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val hist = JSONObject(p.getString("history", "{}") ?: "{}")
        return hist.keys().asSequence().associateWith { hist.optLong(it).toInt() }
    }

    fun todaySteps(ctx: Context): Int = history(ctx)[today()] ?: 0
}

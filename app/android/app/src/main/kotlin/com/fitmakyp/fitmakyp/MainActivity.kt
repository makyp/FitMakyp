package com.fitmakyp.fitmakyp

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    /** Enlace del widget que abrió la app (fitmakyp://…); la app lo lee una vez. */
    private var pendingUri: String? = null

    /** Respuesta pendiente de la petición de permiso de actividad física. */
    private var stepsPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        remember(intent)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fitmakyp/launch").setMethodCallHandler { call, result ->
            if (call.method == "takeUri") {
                result.success(pendingUri)
                pendingUri = null
            } else if (call.method == "takeWater") {
                result.success(takeWidgetWater(this))
            } else if (call.method == "stepsStatus") {
                result.success(mapOf("sensor" to StepCounter.hasSensor(this), "permission" to StepCounter.hasPermission(this)))
            } else if (call.method == "requestStepsPermission") {
                if (StepCounter.hasPermission(this)) {
                    result.success(true)
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    stepsPermissionResult = result
                    requestPermissions(arrayOf(android.Manifest.permission.ACTIVITY_RECOGNITION), 77)
                } else {
                    result.success(true)
                }
            } else if (call.method == "readSteps") {
                StepCounter.read(this) { result.success(StepCounter.history(this)) }
            } else if (call.method == "usageAccess") {
                result.success(hasUsageAccess())
            } else if (call.method == "openUsageAccess") {
                startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                result.success(null)
            } else if (call.method == "phoneUses") {
                val from = (call.argument<Number>("from") ?: 0).toLong()
                val to = (call.argument<Number>("to") ?: System.currentTimeMillis()).toLong()
                result.success(if (hasUsageAccess()) phoneUses(from, to) else null)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 77) {
            stepsPermissionResult?.success(grantResults.isNotEmpty() && grantResults[0] == android.content.pm.PackageManager.PERMISSION_GRANTED)
            stepsPermissionResult = null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        remember(intent)
    }

    /** ¿El usuario dio permiso de "acceso a datos de uso"? (se activa en Ajustes). */
    private fun hasUsageAccess(): Boolean {
        val ops = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        } else {
            @Suppress("DEPRECATION")
            ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /**
     * Momentos (en minutos redondeados, ms) en que se usó el teléfono: desbloqueos y apps abiertas.
     * Solo horas, nunca qué app ni contenido. Se procesa en el teléfono.
     */
    private fun phoneUses(from: Long, to: Long): List<Long> {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(from, to)
        val e = UsageEvents.Event()
        val out = sortedSetOf<Long>()
        while (events.hasNextEvent()) {
            events.getNextEvent(e)
            val use = e.eventType == UsageEvents.Event.ACTIVITY_RESUMED ||
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && e.eventType == UsageEvents.Event.KEYGUARD_HIDDEN)
            if (use) out.add(e.timeStamp / 60000 * 60000)
        }
        return out.toList()
    }

    private fun remember(intent: Intent?) {
        val uri = intent?.data ?: return
        if (uri.scheme == "fitmakyp") pendingUri = uri.toString()
    }
}

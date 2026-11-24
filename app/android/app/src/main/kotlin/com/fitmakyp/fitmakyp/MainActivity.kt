package com.fitmakyp.fitmakyp

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    /** Enlace del widget que abrió la app (fitmakyp://…); la app lo lee una vez. */
    private var pendingUri: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        remember(intent)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fitmakyp/launch").setMethodCallHandler { call, result ->
            when (call.method) {
                "takeUri" -> {
                    result.success(pendingUri)
                    pendingUri = null
                }
                "takeWater" -> result.success(takeWidgetWater(this))
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        remember(intent)
    }

    private fun remember(intent: Intent?) {
        val uri = intent?.data ?: return
        if (uri.scheme == "fitmakyp") pendingUri = uri.toString()
    }
}

package com.niramaya.app.niramaya_app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channel = "com.niramaya.app/sos_intent"
    private var pendingHardwareTrigger = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingHardwareTrigger =
            intent?.getBooleanExtra("is_hardware_trigger", false) == true
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.getBooleanExtra("is_hardware_trigger", false)) {
            // App was already running — push directly via channel
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, channel).invokeMethod("triggerSos", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getHardwareFlag" -> {
                        result.success(pendingHardwareTrigger)
                        pendingHardwareTrigger = false // consume — query-then-reset
                    }
                    else -> result.notImplemented()
                }
            }
    }
}

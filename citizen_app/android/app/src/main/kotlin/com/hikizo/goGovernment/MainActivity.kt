package com.hikizo.goGovernment

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.hikizo.goGovernment/dialer"

    override fun getRenderMode(): RenderMode {
        return RenderMode.texture
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "dialNumber") {
                val phone = call.argument<String>("phone")
                if (!phone.isNullOrBlank()) {
                    try {
                        val clean = phone.replace(Regex("[^0-9+]"), "").trim()
                        val dialIntent = Intent(Intent.ACTION_DIAL).apply {
                            data = Uri.parse("tel:$clean")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(dialIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("DIAL_ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_PHONE", "Phone number is empty", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}


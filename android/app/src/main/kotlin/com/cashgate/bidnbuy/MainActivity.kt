package com.app.ebozor

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.app.ebozor/email"
        ).setMethodCallHandler { call, result ->
            if (call.method != "openInbox") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            try {
                val gmailIntent = packageManager
                    .getLaunchIntentForPackage("com.google.android.gm")
                val emailIntent = gmailIntent?.apply {
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP
                    )
                } ?: Intent.makeMainSelectorActivity(
                    Intent.ACTION_MAIN,
                    Intent.CATEGORY_APP_EMAIL
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(emailIntent)
                result.success(true)
            } catch (error: Exception) {
                result.error("EMAIL_APP_UNAVAILABLE", error.message, null)
            }
        }
    }
}

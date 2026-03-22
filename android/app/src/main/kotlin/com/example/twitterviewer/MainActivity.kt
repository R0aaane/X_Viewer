package com.example.twitterviewer

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingCallbackUrl: String? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "xviewer/auth_callback",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "consumePendingCallbackUrl" -> {
                    result.success(pendingCallbackUrl)
                    pendingCallbackUrl = null
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "xviewer/auth_callback/events",
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    pendingCallbackUrl?.let { url ->
                        events?.success(url)
                        pendingCallbackUrl = null
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )

        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val callbackUrl = intent?.dataString ?: return
        if (!callbackUrl.startsWith("xviewer://auth/callback")) {
            return
        }

        val sink = eventSink
        if (sink != null) {
            sink.success(callbackUrl)
        } else {
            pendingCallbackUrl = callbackUrl
        }
    }
}

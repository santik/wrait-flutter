package com.wrait.app

import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_ID_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                GET_DEVICE_ID_METHOD -> {
                    val androidId = Settings.Secure.getString(
                        contentResolver,
                        Settings.Secure.ANDROID_ID
                    )
                    if (androidId.isNullOrBlank()) {
                        result.success(null)
                    } else {
                        result.success(androidId)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private companion object {
        const val DEVICE_ID_CHANNEL = "wrait/preferences"
        const val GET_DEVICE_ID_METHOD = "getDeviceId"
    }
}

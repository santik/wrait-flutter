package com.wrait.flutter

import android.content.pm.ApplicationInfo
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        if (shouldEnableAutomationLockscreenMode()) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            } else {
                @Suppress("DEPRECATION")
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                )
            }
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }

        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_ID_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                GET_DEVICE_ID_METHOD -> {
                    try {
                        val androidId = Settings.Secure.getString(
                            contentResolver,
                            Settings.Secure.ANDROID_ID
                        )
                        if (androidId.isNullOrBlank()) {
                            result.success(null)
                        } else {
                            result.success(androidId)
                        }
                    } catch (exception: Exception) {
                        result.error(
                            DEVICE_ID_ERROR_CODE,
                            "Failed to retrieve Android device ID.",
                            exception.message
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private companion object {
        const val AUTOMATION_LOCKSCREEN_MODE_SETTING =
            "com.wrait.flutter.debug.automation_lockscreen_mode"
        const val DEVICE_ID_CHANNEL = "wrait/preferences"
        const val DEVICE_ID_ERROR_CODE = "device-id-unavailable"
        const val GET_DEVICE_ID_METHOD = "getDeviceId"
    }

    private fun shouldEnableAutomationLockscreenMode(): Boolean {
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) {
            return false
        }

        return Settings.Global.getString(
            contentResolver,
            AUTOMATION_LOCKSCREEN_MODE_SETTING
        ) == "1"
    }
}

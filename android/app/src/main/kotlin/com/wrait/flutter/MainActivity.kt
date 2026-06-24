package com.wrait.flutter

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableCaptureProtection()

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
        // Flutter can retarget the live activity window during attach/startup,
        // so reassert secure capture protection once the Flutter activity is ready.
        enableCaptureProtection()
    }

    override fun onResume() {
        super.onResume()
        // Reassert protection when Android brings the activity back to foreground.
        enableCaptureProtection()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            // Some lifecycle/app-switch flows restore focus after the live window changes.
            enableCaptureProtection()
        }
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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_LOCK_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                OPEN_SECURITY_SETTINGS_METHOD -> {
                    result.success(openSecuritySettings())
                }

                else -> result.notImplemented()
            }
        }
    }

    private companion object {
        const val AUTOMATION_LOCKSCREEN_MODE_SETTING =
            "com.wrait.flutter.debug.automation_lockscreen_mode"
        const val APP_LOCK_CHANNEL = "wrait/app_lock"
        const val DEVICE_ID_CHANNEL = "wrait/preferences"
        const val DEVICE_ID_ERROR_CODE = "device-id-unavailable"
        const val GET_DEVICE_ID_METHOD = "getDeviceId"
        const val OPEN_SECURITY_SETTINGS_METHOD = "openSecuritySettings"
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

    private fun openSecuritySettings(): Boolean {
        val intent = Intent(Settings.ACTION_SECURITY_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val resolvedActivity = intent.resolveActivity(packageManager) ?: return false

        return try {
            intent.setClassName(
                resolvedActivity.packageName,
                resolvedActivity.className
            )
            startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }

    private fun enableCaptureProtection() {
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}

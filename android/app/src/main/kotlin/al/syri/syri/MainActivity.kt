package al.syri.syri

import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onResume() {
        super.onResume()
        setAppVisibleForNotifications(true)
    }

    override fun onPause() {
        setAppVisibleForNotifications(false)
        super.onPause()
    }

    private fun setAppVisibleForNotifications(visible: Boolean) {
        getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            .edit()
            .putBoolean("flutter.setting_app_foreground", visible)
            .apply()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "al.syri.syri/power")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isBatterySaverOn" -> {
                        val power = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(power.isPowerSaveMode)
                    }
                    "openAppBatterySettings" -> {
                        try {
                            startActivity(
                                Intent(
                                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    Uri.parse("package:$packageName")
                                )
                            )
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("settings_unavailable", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}

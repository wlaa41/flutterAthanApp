package wlaa41.github.io.flutter_pro

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "athan/alarms").setMethodCallHandler { call, result ->
            try {
                when(call.method) {
                    "replace" -> { PrayerAlarms.replace(this, call.arguments as String); result.success(null) }
                    "health" -> result.success(PrayerAlarms.health(this))
                    "test" -> { PrayerAlarms.deliver(this, JSONObject(call.arguments as String), true); result.success(null) }
                    "appSettings" -> { startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))); result.success(null) }
                    "batterySettings" -> {
                        try { startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) }
                        catch (_: Exception) { startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))) }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch(e: Exception) { result.error("alarm_error", e.message, null) }
        }
    }
}

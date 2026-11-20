package wlaa41.github.io.flutter_pro

import android.app.StatusBarManager
import android.content.ComponentName
import android.content.Intent
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
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
                    "getBeepMode" -> result.success(BeepMode.until(this))
                    "setBeepMode" -> { BeepMode.set(this, (call.arguments as Number).toLong()); result.success(null) }
                    "beepOptions" -> { BeepMode.setOptions(this, call.arguments as String); result.success(null) }
                    "previewTone" -> { Tones.preview(this, JSONObject(call.arguments as String)); result.success(null) }
                    "requestBeepTile" -> {
                        // Android 13+ can offer the tile in a system dialog; older phones add it by hand.
                        if (Build.VERSION.SDK_INT >= 33) {
                            getSystemService(StatusBarManager::class.java).requestAddTileService(
                                ComponentName(this, BeepTileService::class.java), "Athan beep",
                                Icon.createWithResource(this, R.drawable.ic_beep_tile), mainExecutor) { }
                            result.success(true)
                        } else result.success(false)
                    }
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

package wlaa41.github.io.flutter_pro

import android.Manifest
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
    /** The Dart call waiting for a location permission answer. */
    private var permissionReply: MethodChannel.Result? = null
    private var permissionAsked: String? = null

    private fun askPermissions(permissions: Array<String>, reply: MethodChannel.Result) {
        permissionReply?.success(false)
        permissionReply = reply
        permissionAsked = permissions.first()
        requestPermissions(permissions, LOCATION_REQUEST)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != LOCATION_REQUEST) return
        val reply = permissionReply ?: return
        permissionReply = null
        reply.success(if (permissionAsked == Manifest.permission.ACCESS_BACKGROUND_LOCATION) AwayFromHome.hasBackground(this) else AwayFromHome.hasLocation(this))
        // Permission just arrived: the geofence can be armed now.
        AwayFromHome.register(this)
    }

    private fun awayStatus(): Map<String, Any?> = AwayFromHome.status(this)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "athan/alarms").setMethodCallHandler { call, result ->
            try {
                when(call.method) {
                    "replace" -> { PrayerAlarms.replace(this, call.arguments as String); result.success(null) }
                    "health" -> result.success(PrayerAlarms.health(this))
                    "test" -> {
                        val event = JSONObject(call.arguments as String)
                        // The app is open, so Android would only show a pop-up:
                        // open the alarm screen itself to show what it looks like.
                        if (PrayerAlarms.deliver(this, event) == PrayerAlarms.Delivery.PLAY && event.optString("soundId") !in BeepMode.TONES)
                            startActivity(AlarmActivity.intent(this, event))
                        result.success(null)
                    }
                    "alarmScreen" -> { AlarmScreen.setOptions(this, call.arguments as String); result.success(null) }
                    "cancelSnooze" -> { PrayerAlarms.cancelSnooze(this); result.success(null) }
                    "fullScreenSettings" -> {
                        // Android 14+: Settings, Apps, Special app access, Full screen notifications.
                        val page = if (Build.VERSION.SDK_INT >= 34) Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:$packageName"))
                            else Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        try { startActivity(page) }
                        catch (_: Exception) { startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))) }
                        result.success(null)
                    }
                    "testSoon" -> { PrayerAlarms.addTest(this, JSONObject(call.arguments as String)); result.success(null) }
                    "requestBatteryExemption" -> {
                        // The system dialog "Let app always run in the background?".
                        val power = getSystemService(POWER_SERVICE) as android.os.PowerManager
                        if (Build.VERSION.SDK_INT >= 23 && !power.isIgnoringBatteryOptimizations(packageName)) {
                            try { startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName"))) }
                            catch (_: Exception) { startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) }
                        }
                        result.success(null)
                    }
                    "awayStatus" -> {
                        // Opening the app also repairs a geofence the phone dropped.
                        AwayFromHome.register(this)
                        result.success(awayStatus())
                    }
                    "awaySave" -> {
                        val args = JSONObject(call.arguments as String)
                        val home = if (args.has("lat") && args.has("lng") && !args.isNull("lat"))
                            AwayFromHome.Home(args.getDouble("lat"), args.getDouble("lng"), args.optInt("radius", AwayFromHome.DEFAULT_RADIUS))
                            else null
                        AwayFromHome.save(this, args.optBoolean("enabled"), home)
                        result.success(awayStatus())
                    }
                    "awayLocate" -> AwayFromHome.locate(this) { fix ->
                        result.success(fix?.let { mapOf("lat" to it.latitude, "lng" to it.longitude, "accuracy" to (if (it.hasAccuracy()) it.accuracy.toDouble() else null)) })
                    }
                    "awayRequestLocation" -> {
                        if (AwayFromHome.hasLocation(this)) result.success(true)
                        else askPermissions(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION), result)
                    }
                    "awayRequestBackground" -> {
                        // Android 11+ answers this by opening the app's location page,
                        // where "Allow all the time" is chosen.
                        if (AwayFromHome.hasBackground(this)) result.success(true)
                        else if (!AwayFromHome.hasLocation(this)) result.success(false)
                        else askPermissions(arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION), result)
                    }
                    "locationSettings" -> { startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)); result.success(null) }
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

    companion object { private const val LOCATION_REQUEST = 7824 }
}

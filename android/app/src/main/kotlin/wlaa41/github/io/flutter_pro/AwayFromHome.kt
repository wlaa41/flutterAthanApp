package wlaa41.github.io.flutter_pro

import android.Manifest
import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.location.CurrentLocationRequest
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofenceStatusCodes
import com.google.android.gms.location.GeofencingEvent
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import java.util.concurrent.atomic.AtomicBoolean

/**
 * "Beep away from home": outside a circle around home, an Athan or Iqama
 * recording becomes the chosen beep. At home nothing changes.
 *
 * Two sources say where the phone is, best first:
 * 1. a location fix from the last few minutes, or one asked for when the
 *    reminder fires (at most [LIVE_WAIT_MILLIS], so the athan stays on time);
 * 2. the last time Android's geofence saw the phone enter or leave home.
 * With neither, the reminder keeps its usual sound.
 *
 * Battery: nothing polls and nothing listens for location. The geofence is
 * Android's own low-power one (cell and Wi-Fi, no GPS), and the check at a
 * reminder runs only when no recent fix exists, at balanced power, for at
 * most 3 s, a few times a day. GPS is used once, when home is set.
 */
object AwayFromHome {
    private const val STORE = "away_from_home"
    private const val FENCE = "home"
    private const val REQUEST = 7823
    const val DEFAULT_RADIUS = 300
    /** A fix this recent decides without asking for a new one. */
    const val FRESH_MILLIS = 3 * 60 * 1000L
    /** How long a reminder may wait for a new fix. Starting the athan from the
     *  background is allowed for about 10 s after the alarm. */
    const val LIVE_WAIT_MILLIS = 3_000L

    enum class Place { HOME, AWAY, UNKNOWN }
    data class Home(val lat: Double, val lng: Double, val radius: Int)

    private fun prefs(c: Context) = c.getSharedPreferences(STORE, Context.MODE_PRIVATE)

    fun home(c: Context): Home? {
        val p = prefs(c)
        if (!p.contains("lat") || !p.contains("lng")) return null
        return Home(
            java.lang.Double.longBitsToDouble(p.getLong("lat", 0L)),
            java.lang.Double.longBitsToDouble(p.getLong("lng", 0L)),
            p.getInt("radius", DEFAULT_RADIUS),
        )
    }
    fun enabled(c: Context) = prefs(c).getBoolean("enabled", false) && home(c) != null

    /** Saves the rule and (re)arms or removes the geofence. */
    fun save(c: Context, enabled: Boolean, home: Home?) {
        val editor = prefs(c).edit().putBoolean("enabled", enabled)
        if (home == null) editor.remove("lat").remove("lng").remove("radius")
        else {
            val moved = home(c)?.let { it != home } ?: true
            editor.putLong("lat", java.lang.Double.doubleToRawLongBits(home.lat))
                .putLong("lng", java.lang.Double.doubleToRawLongBits(home.lng))
                .putInt("radius", home.radius)
            // A new home is where the phone is now: it is at home.
            if (moved) editor.putString("state", Place.HOME.name).putLong("state_time", System.currentTimeMillis())
        }
        editor.commit()
        if (enabled && home != null) register(c) else unregister(c)
    }

    fun hasLocation(c: Context) = granted(c, Manifest.permission.ACCESS_FINE_LOCATION) || granted(c, Manifest.permission.ACCESS_COARSE_LOCATION)
    fun hasBackground(c: Context) = Build.VERSION.SDK_INT < 29 || granted(c, Manifest.permission.ACCESS_BACKGROUND_LOCATION)
    private fun granted(c: Context, permission: String) = c.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
    fun playServices(c: Context) = try {
        GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(c) == ConnectionResult.SUCCESS
    } catch (_: Throwable) { false }
    fun locationOn(c: Context): Boolean {
        val manager = c.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return if (Build.VERSION.SDK_INT >= 28) manager.isLocationEnabled
            else manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) || manager.isProviderEnabled(LocationManager.GPS_PROVIDER)
    }

    /** What the geofence last reported. */
    fun fenceState(c: Context): Place = try { Place.valueOf(prefs(c).getString("state", null) ?: "UNKNOWN") } catch (_: Exception) { Place.UNKNOWN }
    fun onTransition(c: Context, place: Place) {
        prefs(c).edit().putString("state", place.name).putLong("state_time", System.currentTimeMillis()).remove("error").commit()
    }
    /** The geofence stopped, for example because location was turned off. The
     *  last place is kept: it is still the best guess. */
    fun onError(c: Context, message: String) { prefs(c).edit().putString("error", message).commit() }

    /** One fix against the circle. A fix vaguer than the circle says nothing. */
    fun judge(home: Home, lat: Double, lng: Double, accuracy: Float): Place {
        if (accuracy > home.radius * 2f) return Place.UNKNOWN
        val distance = FloatArray(1)
        Location.distanceBetween(home.lat, home.lng, lat, lng, distance)
        return if (distance[0] > home.radius) Place.AWAY else Place.HOME
    }
    private fun judge(home: Home, fix: Location) = judge(home, fix.latitude, fix.longitude, if (fix.hasAccuracy()) fix.accuracy else 0f)

    /** The newest location any app on the phone obtained. */
    @SuppressLint("MissingPermission")
    fun lastFix(c: Context): Location? {
        if (!hasLocation(c)) return null
        val manager = c.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val providers = buildList {
            if (Build.VERSION.SDK_INT >= 31) add(LocationManager.FUSED_PROVIDER)
            add(LocationManager.GPS_PROVIDER); add(LocationManager.NETWORK_PROVIDER)
        }
        return providers.mapNotNull { try { manager.getLastKnownLocation(it) } catch (_: Exception) { null } }.maxByOrNull { it.time }
    }

    /** Where the phone is, from what is known now. */
    fun place(c: Context, fix: Location? = lastFix(c), now: Long = System.currentTimeMillis()): Place {
        val home = home(c) ?: return Place.UNKNOWN
        if (fix != null && now - fix.time <= FRESH_MILLIS) {
            val judged = judge(home, fix)
            if (judged != Place.UNKNOWN) return judged
        }
        return fenceState(c)
    }

    /** Answers [done] with where the phone is, asking for a new fix when the
     *  known ones are old. Never later than [LIVE_WAIT_MILLIS]. */
    @SuppressLint("MissingPermission")
    fun decide(c: Context, done: (Place) -> Unit) {
        val home = home(c)
        if (!enabled(c) || home == null) { done(Place.UNKNOWN); return }
        val known = lastFix(c)
        if (known != null && System.currentTimeMillis() - known.time <= FRESH_MILLIS) { done(place(c, known)); return }
        if (!hasLocation(c) || !hasBackground(c) || !locationOn(c)) { done(place(c, known)); return }
        val answered = AtomicBoolean(false)
        val handler = Handler(Looper.getMainLooper())
        fun answer(fix: Location?) {
            if (!answered.compareAndSet(false, true)) return
            handler.removeCallbacksAndMessages(null)
            val judged = fix?.let { judge(home, it) } ?: Place.UNKNOWN
            done(if (judged != Place.UNKNOWN) judged else place(c, known))
        }
        handler.postDelayed({ answer(null) }, LIVE_WAIT_MILLIS)
        try {
            if (playServices(c)) {
                val request = CurrentLocationRequest.Builder()
                    .setPriority(Priority.PRIORITY_BALANCED_POWER_ACCURACY)
                    .setMaxUpdateAgeMillis(FRESH_MILLIS)
                    .setDurationMillis(LIVE_WAIT_MILLIS)
                    .build()
                LocationServices.getFusedLocationProviderClient(c).getCurrentLocation(request, null)
                    .addOnCompleteListener { task -> answer(if (task.isSuccessful) task.result else null) }
            } else if (Build.VERSION.SDK_INT >= 30) {
                val manager = c.getSystemService(Context.LOCATION_SERVICE) as LocationManager
                manager.getCurrentLocation(LocationManager.NETWORK_PROVIDER, null, c.mainExecutor) { answer(it) }
            } else answer(null)
        } catch (_: Exception) { answer(null) }
    }

    /** A fix for "Set home here", with the app open. */
    @SuppressLint("MissingPermission")
    fun locate(c: Context, done: (Location?) -> Unit) {
        if (!hasLocation(c)) { done(null); return }
        val answered = AtomicBoolean(false)
        val handler = Handler(Looper.getMainLooper())
        fun answer(fix: Location?) {
            if (!answered.compareAndSet(false, true)) return
            handler.removeCallbacksAndMessages(null)
            done(fix ?: lastFix(c)?.takeIf { System.currentTimeMillis() - it.time <= FRESH_MILLIS })
        }
        handler.postDelayed({ answer(null) }, 15_000L)
        try {
            if (playServices(c)) {
                val request = CurrentLocationRequest.Builder()
                    .setPriority(Priority.PRIORITY_HIGH_ACCURACY)
                    .setMaxUpdateAgeMillis(30_000L)
                    .setDurationMillis(15_000L)
                    .build()
                LocationServices.getFusedLocationProviderClient(c).getCurrentLocation(request, null)
                    .addOnCompleteListener { task -> answer(if (task.isSuccessful) task.result else null) }
            } else if (Build.VERSION.SDK_INT >= 30) {
                val manager = c.getSystemService(Context.LOCATION_SERVICE) as LocationManager
                val provider = if (manager.isProviderEnabled(LocationManager.GPS_PROVIDER)) LocationManager.GPS_PROVIDER else LocationManager.NETWORK_PROVIDER
                manager.getCurrentLocation(provider, null, c.mainExecutor) { answer(it) }
            } else answer(null)
        } catch (_: Exception) { answer(null) }
    }

    private fun pending(c: Context): PendingIntent =
        // Play Services writes the transition into this intent, so it must be mutable.
        PendingIntent.getBroadcast(c, REQUEST, Intent(c, GeofenceReceiver::class.java).setAction("AWAY_FENCE"),
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0))

    /** Arms the geofence. Safe to repeat: Android replaces the old one. */
    @SuppressLint("MissingPermission")
    fun register(c: Context) {
        val home = home(c) ?: return
        if (!enabled(c)) return
        if (!hasLocation(c) || !hasBackground(c)) { onError(c, "permission"); return }
        if (!playServices(c)) { onError(c, "play_services"); return }
        try {
            val fence = Geofence.Builder()
                .setRequestId(FENCE)
                .setCircularRegion(home.lat, home.lng, home.radius.toFloat())
                .setExpirationDuration(Geofence.NEVER_EXPIRE)
                .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT)
                // Battery: Android may report leaving home up to 5 minutes late
                // (Google's power-saving value). The check when a reminder fires
                // covers that gap.
                .setNotificationResponsiveness(5 * 60_000)
                .build()
            val request = GeofencingRequest.Builder()
                .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER or GeofencingRequest.INITIAL_TRIGGER_EXIT)
                .addGeofence(fence)
                .build()
            LocationServices.getGeofencingClient(c).addGeofences(request, pending(c))
                .addOnSuccessListener { prefs(c).edit().remove("error").commit() }
                .addOnFailureListener { onError(c, it.message ?: "fence") }
        } catch (e: Exception) { onError(c, e.message ?: "fence") }
    }

    fun unregister(c: Context) {
        try { if (playServices(c)) LocationServices.getGeofencingClient(c).removeGeofences(pending(c)) } catch (_: Exception) { }
        prefs(c).edit().remove("error").commit()
    }

    fun status(c: Context): Map<String, Any?> {
        val home = home(c)
        return mapOf(
            "enabled" to enabled(c),
            "lat" to home?.lat,
            "lng" to home?.lng,
            "radius" to (home?.radius ?: DEFAULT_RADIUS),
            "place" to place(c).name.lowercase(),
            "location" to hasLocation(c),
            "background" to hasBackground(c),
            "locationOn" to locationOn(c),
            "playServices" to playServices(c),
            "error" to prefs(c).getString("error", null),
        )
    }
}

class GeofenceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event = try { GeofencingEvent.fromIntent(intent) } catch (_: Exception) { null } ?: return
        if (event.hasError()) { AwayFromHome.onError(context, GeofenceStatusCodes.getStatusCodeString(event.errorCode)); return }
        when (event.geofenceTransition) {
            Geofence.GEOFENCE_TRANSITION_ENTER -> AwayFromHome.onTransition(context, AwayFromHome.Place.HOME)
            Geofence.GEOFENCE_TRANSITION_EXIT -> AwayFromHome.onTransition(context, AwayFromHome.Place.AWAY)
        }
    }
}

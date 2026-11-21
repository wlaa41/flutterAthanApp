package wlaa41.github.io.flutter_pro

import android.Manifest
import android.app.Application
import android.content.Context
import android.content.Intent
import android.location.Location
import android.location.LocationManager
import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import org.json.JSONArray
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowAlarmManager
import java.time.Duration

/** "Beep away from home": which sound a reminder ends up with. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 34, 36])
class AwayFromHomeTest {
    private lateinit var app: Application
    private val home = AwayFromHome.Home(51.5390, 0.1440, 300)

    @Before fun setUp() {
        app = ApplicationProvider.getApplicationContext()
        ShadowAlarmManager.setCanScheduleExactAlarms(true)
        BeepMode.setOptions(app, JSONObject().put("soundId", "beep").put("resource", "beep").toString())
    }

    @After fun tearDown() = ShadowAlarmManager.reset()

    private fun event(sound: String = "smooth") = JSONObject()
        .put("id", 1).put("time", System.currentTimeMillis() + 1_000)
        .put("title", "Asr").put("body", "Time for Asr")
        .put("soundId", sound).put("resource", sound).put("filePath", "")

    /** Arms [e], fires its alarm, and says which sound the athan service got. */
    private fun soundAtPrayerTime(e: JSONObject = event()): String {
        PrayerAlarms.replace(app, JSONArray(listOf(e)).toString())
        val alarm = shadowOf(app.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager).scheduledAlarms.single()
        PrayerAlarmReceiver().onReceive(app, shadowOf(alarm.operation).savedIntent)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(5))
        val started = shadowOf(app).nextStartedService ?: return "none"
        return JSONObject(started.getStringExtra("event")!!).getString("soundId")
    }

    private fun fix(lat: Double, lng: Double, accuracy: Float = 20f, ageMillis: Long = 0) = Location(LocationManager.GPS_PROVIDER).apply {
        latitude = lat; longitude = lng; this.accuracy = accuracy; time = System.currentTimeMillis() - ageMillis
    }

    private fun giveFix(location: Location) {
        shadowOf(app).grantPermissions(Manifest.permission.ACCESS_FINE_LOCATION)
        shadowOf(app.getSystemService(Context.LOCATION_SERVICE) as LocationManager).setLastKnownLocation(LocationManager.GPS_PROVIDER, location)
    }

    @Test fun judgesAFixAgainstTheCircle() {
        assertEquals(AwayFromHome.Place.HOME, AwayFromHome.judge(home, 51.5390, 0.1440, 20f))
        // About 1 km north.
        assertEquals(AwayFromHome.Place.AWAY, AwayFromHome.judge(home, 51.5480, 0.1440, 20f))
        // A cell-tower fix 2 km wide cannot tell.
        assertEquals(AwayFromHome.Place.UNKNOWN, AwayFromHome.judge(home, 51.5480, 0.1440, 2_000f))
    }

    @Test fun offLeavesTheAthan() {
        AwayFromHome.onTransition(app, AwayFromHome.Place.AWAY)
        assertEquals("smooth", soundAtPrayerTime())
    }

    @Test fun awayFromHomeTheAthanBeeps() {
        AwayFromHome.save(app, true, home)
        AwayFromHome.onTransition(app, AwayFromHome.Place.AWAY)
        assertEquals("beep", soundAtPrayerTime())
    }

    @Test fun atHomeTheAthanPlays() {
        AwayFromHome.save(app, true, home)
        AwayFromHome.onTransition(app, AwayFromHome.Place.HOME)
        assertEquals("smooth", soundAtPrayerTime())
    }

    @Test fun aNewHomeStartsAtHome() {
        AwayFromHome.onTransition(app, AwayFromHome.Place.AWAY)
        AwayFromHome.save(app, true, home)
        assertEquals(AwayFromHome.Place.HOME, AwayFromHome.fenceState(app))
    }

    @Test fun aFreshFixBeatsTheGeofence() {
        AwayFromHome.save(app, true, home)
        AwayFromHome.onTransition(app, AwayFromHome.Place.HOME)
        // The geofence has not caught up yet; a fix a minute old says away.
        giveFix(fix(51.5480, 0.1440, ageMillis = 60_000))
        assertEquals("beep", soundAtPrayerTime())
    }

    @Test fun anOldFixDoesNotOverruleTheGeofence() {
        AwayFromHome.save(app, true, home)
        AwayFromHome.onTransition(app, AwayFromHome.Place.HOME)
        giveFix(fix(51.5480, 0.1440, ageMillis = 30 * 60_000L))
        assertEquals("smooth", soundAtPrayerTime())
    }

    @Test fun noFixInTimeFallsBackToTheGeofence() {
        AwayFromHome.save(app, true, home)
        AwayFromHome.onTransition(app, AwayFromHome.Place.AWAY)
        shadowOf(app).grantPermissions(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        assertEquals("beep", soundAtPrayerTime())
    }

    @Test fun neverTurnsQuietIntoSound() {
        AwayFromHome.save(app, true, home)
        AwayFromHome.onTransition(app, AwayFromHome.Place.AWAY)
        val away = { sound: String -> BeepMode.apply(app, event(sound), away = true).getString("soundId") }
        assertEquals("beep", away("smooth"))
        assertEquals("silent", away("silent"))
        assertEquals("vibrate", away("vibrate"))
        assertEquals("chime", away("chime"))
    }

    @Test fun switchedOffItForgetsNothingButStops() {
        AwayFromHome.save(app, true, home)
        AwayFromHome.onTransition(app, AwayFromHome.Place.AWAY)
        AwayFromHome.save(app, false, home)
        assertEquals("smooth", soundAtPrayerTime())
        assertEquals(home, AwayFromHome.home(app))
    }

    @Test fun statusSaysWhatIsMissing() {
        AwayFromHome.save(app, true, home)
        val status = AwayFromHome.status(app)
        assertEquals(true, status["enabled"])
        assertEquals(300, status["radius"])
        assertEquals("home", status["place"])
        assertEquals(false, status["location"])
    }

    @Test fun bootRearmsWithoutCrashing() {
        AwayFromHome.save(app, true, home)
        PrayerAlarmReceiver().onReceive(app, Intent(Intent.ACTION_BOOT_COMPLETED))
        assertEquals(AwayFromHome.Place.HOME, AwayFromHome.fenceState(app))
    }
}

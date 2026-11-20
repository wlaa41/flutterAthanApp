package wlaa41.github.io.flutter_pro

import android.app.AlarmManager
import android.app.Application
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.os.Build
import android.os.Looper
import android.os.VibrationAttributes
import android.os.Vibrator
import android.os.VibratorManager
import androidx.test.core.app.ApplicationProvider
import org.json.JSONArray
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowAlarmManager
import org.robolectric.shadows.ShadowMediaPlayer

/**
 * The path from a scheduled prayer to a sound, run on the Android framework.
 * Android 14 is the phone where this broke: exact alarms are off by default
 * there unless the app is an alarm app.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 34, 36])
class PrayerAlarmsTest {
    private lateinit var app: Application
    private val alarms get() = app.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val audio get() = app.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val notifications get() = app.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val vibrator: Vibrator get() = if (Build.VERSION.SDK_INT >= 31)
        (app.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        else @Suppress("DEPRECATION") (app.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator)

    @Before fun setUp() {
        app = ApplicationProvider.getApplicationContext()
        ShadowAlarmManager.setCanScheduleExactAlarms(true)
        audio.ringerMode = AudioManager.RINGER_MODE_NORMAL
    }

    @After fun tearDown() = ShadowAlarmManager.reset()

    private fun event(id: Int, inMillis: Long, sound: String = "smooth") = JSONObject()
        .put("id", id).put("time", System.currentTimeMillis() + inMillis)
        .put("title", "Dhuhr").put("body", "Time for Dhuhr")
        .put("soundId", sound).put("resource", sound).put("filePath", "")

    private fun plan(vararg events: JSONObject) = PrayerAlarms.replace(app, JSONArray(events.toList()).toString())

    /** The broadcast the armed alarm will send. */
    private fun armedIntent(): Intent {
        val alarm = shadowOf(alarms).scheduledAlarms.single()
        return shadowOf(alarm.operation).savedIntent
    }

    private fun fire(intent: Intent) = PrayerAlarmReceiver().onReceive(app, intent)

    private fun startedServices(): List<Intent> = generateSequence { shadowOf(app).nextStartedService }.toList()

    @Test fun decideMatchesTheSoundMode() {
        val ring = AudioManager.RINGER_MODE_NORMAL
        assertEquals(PrayerAlarms.Delivery.PLAY, PrayerAlarms.decide("smooth", ring, false))
        assertEquals(PrayerAlarms.Delivery.VIBRATE, PrayerAlarms.decide("smooth", AudioManager.RINGER_MODE_SILENT, false))
        assertEquals(PrayerAlarms.Delivery.VIBRATE, PrayerAlarms.decide("smooth", AudioManager.RINGER_MODE_VIBRATE, false))
        assertEquals(PrayerAlarms.Delivery.NOTIFY, PrayerAlarms.decide("smooth", ring, true))
        assertEquals(PrayerAlarms.Delivery.NOTIFY, PrayerAlarms.decide("smooth", ring, false, playbackMuted = true))
        assertEquals(PrayerAlarms.Delivery.VIBRATE, PrayerAlarms.decide("vibrate", ring, false))
        assertEquals(PrayerAlarms.Delivery.QUIET, PrayerAlarms.decide("silent", ring, false))
        assertEquals(PrayerAlarms.Delivery.PLAY, PrayerAlarms.decide("beep", ring, false))
    }

    @Test fun armsAnAlarmClockForTheNextPrayer() {
        val first = event(1, 60_000)
        plan(event(2, 120_000), first)
        assertEquals(first.getLong("time"), alarms.nextAlarmClock?.triggerTime)
        assertEquals(1, JSONObject(armedIntent().getStringExtra("event")!!).getInt("id"))
    }

    @Test fun stillArmsWithoutExactAlarms() {
        // Before Android 12 every app may set exact alarms.
        assumeTrue(Build.VERSION.SDK_INT >= 31)
        ShadowAlarmManager.setCanScheduleExactAlarms(false)
        plan(event(1, 60_000))
        assertNull(alarms.nextAlarmClock)
        assertEquals(1, shadowOf(alarms).scheduledAlarms.size)
    }

    @Test fun armsAndPlaysWithoutNotificationPermission() {
        shadowOf(notifications).setNotificationsEnabled(false)
        plan(event(1, 1_000))
        assertNotNull(alarms.nextAlarmClock)
        fire(armedIntent())
        assertEquals(AthanPlaybackService::class.java.name, startedServices().single().component?.className)
    }

    @Test fun onTimeAlarmStartsTheAthan() {
        plan(event(1, 1_000))
        fire(armedIntent())
        val started = startedServices().single()
        assertEquals(AthanPlaybackService::class.java.name, started.component?.className)
        assertEquals(1, JSONObject(started.getStringExtra("event")!!).getInt("id"))
    }

    @Test fun silentPhoneVibratesAndShowsTheReminder() {
        audio.ringerMode = AudioManager.RINGER_MODE_SILENT
        plan(event(1, 1_000))
        fire(armedIntent())
        assertTrue(startedServices().isEmpty())
        assertTrue(shadowOf(vibrator).isVibrating)
        // Alarm vibration is the kind a phone on silent lets through.
        if (Build.VERSION.SDK_INT >= 33)
            assertEquals(VibrationAttributes.USAGE_ALARM, (shadowOf(vibrator).vibrationAttributesFromLastVibration as VibrationAttributes).usage)
        val shown = shadowOf(notifications).allNotifications.single()
        assertEquals(PrayerAlarms.CHANNEL_QUIET, shown.channelId)
        if (Build.VERSION.SDK_INT >= 26)
            assertEquals(NotificationManager.IMPORTANCE_HIGH, notifications.getNotificationChannel(PrayerAlarms.CHANNEL_QUIET).importance)
    }

    @Test fun vibrateModeVibratesToo() {
        audio.ringerMode = AudioManager.RINGER_MODE_VIBRATE
        plan(event(1, 1_000))
        fire(armedIntent())
        assertTrue(startedServices().isEmpty())
        assertTrue(shadowOf(vibrator).isVibrating)
    }

    @Test fun doNotDisturbLeavesAReminder() {
        shadowOf(notifications).setNotificationPolicyAccessGranted(true)
        notifications.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
        plan(event(1, 1_000))
        fire(armedIntent())
        assertTrue(startedServices().isEmpty())
        assertEquals(PrayerAlarms.CHANNEL_VIBRATE, shadowOf(notifications).allNotifications.single().channelId)
    }

    @Test fun refreshAtPrayerTimeDoesNotSwallowTheAthan() {
        plan(event(1, 1_000))
        val intent = armedIntent()
        // The app opened and replaced its plan just as the alarm went off.
        plan()
        fire(intent)
        assertEquals(1, startedServices().size)
        // The same alarm arriving twice plays once.
        fire(intent)
        assertTrue(startedServices().isEmpty())
    }

    @Test fun lateAlarmNoLongerQueuedIsDropped() {
        val stale = event(1, -20 * 60_000L)
        fire(Intent(app, PrayerAlarmReceiver::class.java).setAction("PRAYER_ALERT").putExtra("event", stale.toString()))
        assertTrue(startedServices().isEmpty())
        assertTrue(shadowOf(notifications).allNotifications.isEmpty())
    }

    @Test fun planRefreshKeepsATestOnItsWay() {
        val test = event(998, 60_000)
        PrayerAlarms.addTest(app, test)
        plan()
        assertEquals(test.getLong("time"), alarms.nextAlarmClock?.triggerTime)
        fire(armedIntent())
        assertEquals(1, startedServices().size)
    }

    @Test fun nextAlarmIsArmedAfterOneFires() {
        val second = event(2, 120_000)
        plan(event(1, 1_000), second)
        fire(armedIntent())
        assertEquals(second.getLong("time"), alarms.nextAlarmClock?.triggerTime)
    }

    @Test fun healthReportsWhatTheAppShows() {
        audio.ringerMode = AudioManager.RINGER_MODE_VIBRATE
        val next = event(1, 60_000)
        plan(next, event(2, 120_000))
        val health = PrayerAlarms.health(app)
        assertEquals(true, health["exact"])
        assertEquals(2, health["count"])
        assertEquals(next.getLong("time"), health["nextTime"])
        assertEquals("Dhuhr", health["nextTitle"])
        assertEquals("vibrate", health["ringer"])
        assertEquals(false, health["dnd"])
    }

    @Test fun athanPlaysAsAnAlarmInAForegroundService() {
        ShadowMediaPlayer.setMediaInfoProvider { ShadowMediaPlayer.MediaInfo(60_000, 0) }
        val intent = Intent(app, AthanPlaybackService::class.java).putExtra("event", event(1, 0).toString())
        val service = Robolectric.buildService(AthanPlaybackService::class.java, intent).create().startCommand(0, 1).get()
        shadowOf(Looper.getMainLooper()).idle()
        assertNotNull(shadowOf(service).lastForegroundNotification)
        assertFalse(shadowOf(service).isStoppedBySelf)
        val focus = shadowOf(audio).lastAudioFocusRequest.audioFocusRequest
        assertEquals(AudioAttributes.USAGE_ALARM, focus.audioAttributes.usage)
    }
}

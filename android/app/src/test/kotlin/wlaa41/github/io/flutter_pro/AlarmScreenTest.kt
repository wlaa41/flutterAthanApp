package wlaa41.github.io.flutter_pro

import android.app.AlarmManager
import android.app.Application
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.Looper
import android.widget.TextView
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
import java.time.Duration

/** The black alarm screen, its slider, Snooze and Stop, and "Easier screen". */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 34, 36])
class AlarmScreenTest {
    private lateinit var app: Application
    private val alarms get() = app.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val notifications get() = app.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    @Before fun setUp() {
        app = ApplicationProvider.getApplicationContext()
        ShadowAlarmManager.setCanScheduleExactAlarms(true)
        (app.getSystemService(Context.AUDIO_SERVICE) as AudioManager).ringerMode = AudioManager.RINGER_MODE_NORMAL
    }

    @After fun tearDown() {
        AthanPlaybackService.current = null
        ShadowAlarmManager.reset()
    }

    private fun event(id: Int = 1, inMillis: Long = 0, sound: String = "smooth") = JSONObject()
        .put("id", id).put("time", System.currentTimeMillis() + inMillis)
        .put("title", "Time for Fajr").put("body", "It is time for prayer.")
        .put("soundId", sound).put("resource", sound).put("filePath", "")

    private fun idle(millis: Long = 600) = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(millis))
    private fun stopped(): List<Intent> = generateSequence { shadowOf(app).nextStoppedService }.toList()
    private fun queued(): List<JSONObject> {
        val raw = app.getSharedPreferences("prayer_alarm_queue", Context.MODE_PRIVATE).getString("queue", "[]")
        val array = JSONArray(raw)
        return (0 until array.length()).map { array.getJSONObject(it) }
    }
    private fun titles(notice: Notification) = notice.actions.orEmpty().map { it.title.toString() }

    @Test fun athanNotificationOffersSnoozeAndStopAndTheAlarmScreen() {
        val notice = PrayerAlarms.notification(app, event(), true, PrayerAlarms.playingChannel(event()))
        assertEquals(listOf("Snooze", "Stop", "Beep today"), titles(notice))
        assertNotNull(notice.fullScreenIntent)
        assertEquals(AlarmActivity::class.java.name, shadowOf(notice.fullScreenIntent).savedIntent.component?.className)
        assertEquals(AlarmActivity::class.java.name, shadowOf(notice.contentIntent).savedIntent.component?.className)
        assertEquals(Notification.CATEGORY_ALARM, notice.category)
        if (Build.VERSION.SDK_INT >= 26) {
            assertEquals(PrayerAlarms.CHANNEL_ALARM, notice.channelId)
            // Below high importance Android never opens a full-screen intent.
            assertEquals(NotificationManager.IMPORTANCE_HIGH, notifications.getNotificationChannel(PrayerAlarms.CHANNEL_ALARM).importance)
        }
    }

    @Test fun aBeepStaysAQuietNotification() {
        val beep = event(sound = "beep")
        val notice = PrayerAlarms.notification(app, beep, true, PrayerAlarms.playingChannel(beep))
        assertEquals(listOf("Stop"), titles(notice))
        assertNull(notice.fullScreenIntent)
        if (Build.VERSION.SDK_INT >= 26) assertEquals(PrayerAlarms.CHANNEL_PLAYBACK, notice.channelId)
    }

    @Test fun anAthanTurnedDownBeforeStaysTurnedDown() {
        assumeTrue(Build.VERSION.SDK_INT >= 26)
        // The user had lowered "Athan playback", where the athan used to play.
        notifications.createNotificationChannel(NotificationChannel(PrayerAlarms.CHANNEL_PLAYBACK, "Athan playback", NotificationManager.IMPORTANCE_LOW))
        assertEquals(PrayerAlarms.Delivery.NOTIFY, PrayerAlarms.deliver(app, event()))
        assertEquals(true, PrayerAlarms.health(app)["playbackMuted"])
        assertEquals(NotificationManager.IMPORTANCE_LOW, notifications.getNotificationChannel(PrayerAlarms.CHANNEL_ALARM).importance)
        // The old channel now only carries a beep, and says so.
        val old = notifications.getNotificationChannel(PrayerAlarms.CHANNEL_PLAYBACK)
        assertEquals("Beep playback", old.name.toString())
        assertEquals(NotificationManager.IMPORTANCE_LOW, old.importance)
    }

    @Test fun snoozeBringsTheAthanBackThroughTheSameAlarm() {
        AlarmScreen.setOptions(app, JSONObject().put("snoozeMinutes", 5).toString())
        val before = System.currentTimeMillis()
        val at = PrayerAlarms.snooze(app, event())
        assertTrue(at - before in 5 * 60_000L..5 * 60_000L + 5_000L)
        assertEquals(at, alarms.nextAlarmClock?.triggerTime)
        val snoozed = queued().single()
        assertEquals(PrayerAlarms.SNOOZE_ID, snoozed.getInt("id"))
        assertEquals(1, snoozed.getInt("snoozedFrom"))
        assertEquals("smooth", snoozed.getString("soundId"))
        // A countdown line with "Cancel snooze" waits in the shade.
        val line = shadowOf(notifications).getNotification(PrayerAlarms.SNOOZED_NOTICE)
        assertEquals(listOf("Cancel snooze"), titles(line))

        // Opening the app refreshes the plan; the snooze survives it.
        PrayerAlarms.replace(app, "[]")
        assertEquals(at, alarms.nextAlarmClock?.triggerTime)
        assertEquals(PrayerAlarms.snoozedUntil(app), at)

        // When it rings the athan plays again and the countdown line goes.
        val armed = shadowOf(shadowOf(alarms).scheduledAlarms.single().operation).savedIntent
        PrayerAlarmReceiver().onReceive(app, armed)
        assertEquals(AthanPlaybackService::class.java.name, shadowOf(app).nextStartedService.component?.className)
        assertNull(shadowOf(notifications).getNotification(PrayerAlarms.SNOOZED_NOTICE))
    }

    @Test fun cancelSnoozeMeansItWillNotRing() {
        PrayerAlarms.snooze(app, event())
        PrayerAlarmReceiver().onReceive(app, Intent(app, PrayerAlarmReceiver::class.java).setAction("CANCEL_SNOOZE"))
        assertNull(alarms.nextAlarmClock)
        assertTrue(queued().isEmpty())
        assertNull(shadowOf(notifications).getNotification(PrayerAlarms.SNOOZED_NOTICE))
    }

    @Test fun snoozingASnoozeKeepsOneWaiting() {
        val first = PrayerAlarms.snooze(app, event(id = 42))
        val again = PrayerAlarms.snooze(app, JSONObject(queued().single().toString()))
        assertTrue(again >= first)
        assertEquals(42, queued().single().getInt("snoozedFrom"))
    }

    private fun screen(): AlarmActivity {
        val playing = event()
        AthanPlaybackService.current = playing
        return Robolectric.buildActivity(AlarmActivity::class.java, AlarmActivity.intent(app, playing)).setup().get()
    }

    @Test fun showsThePrayerTheTimeAndHowToSlide() {
        val activity = screen()
        assertEquals("Time for Fajr", activity.findViewById<TextView>(R.id.alarm_title).text.toString())
        assertNotNull(activity.findViewById<TextView>(R.id.alarm_clock))
        val hint = activity.findViewById<TextView>(R.id.alarm_hint).text.toString()
        assertTrue(hint, hint.startsWith("Slide right to stop"))
        assertTrue(hint, hint.contains("Slide left to snooze 10 min"))
    }

    @Test fun slideRightStopsTheAthan() {
        val activity = screen()
        activity.findViewById<AlarmSlider>(R.id.alarm_slider).performAccessibilityAction(R.id.alarm_action_stop, null)
        idle()
        assertEquals(AthanPlaybackService::class.java.name, stopped().single().component?.className)
        assertTrue(activity.isFinishing)
        assertTrue(queued().isEmpty())
    }

    @Test fun slideLeftSnoozes() {
        val activity = screen()
        activity.findViewById<AlarmSlider>(R.id.alarm_slider).performAccessibilityAction(R.id.alarm_action_snooze, null)
        idle()
        assertEquals(PrayerAlarms.SNOOZE_ID, queued().single().getInt("id"))
        assertNotNull(alarms.nextAlarmClock)
        assertEquals(AthanPlaybackService::class.java.name, stopped().single().component?.className)
        val hint = activity.findViewById<TextView>(R.id.alarm_hint).text.toString()
        assertTrue(hint, hint.startsWith("Snoozed until"))
        idle(1500)
        assertTrue(activity.isFinishing)
    }

    @Test fun withoutEasierScreenATapDoesNotStop() {
        val activity = screen()
        activity.findViewById<android.view.View>(R.id.alarm_root).performClick()
        idle()
        assertTrue(stopped().isEmpty())
        assertFalse(activity.isFinishing)
    }

    @Test fun easierScreenStopsOnAnyTap() {
        AlarmScreen.setOptions(app, JSONObject().put("easierScreen", true).toString())
        val activity = screen()
        val hint = activity.findViewById<TextView>(R.id.alarm_hint).text.toString()
        assertTrue(hint, hint.startsWith("Tap anywhere to stop"))
        activity.findViewById<android.view.View>(R.id.alarm_root).performClick()
        idle()
        assertEquals(AthanPlaybackService::class.java.name, stopped().single().component?.className)
        assertTrue(activity.isFinishing)
    }

    @Test fun closesWhenTheAthanEnds() {
        val activity = screen()
        AthanPlaybackService.current = null
        AlarmActivity.closeAll()
        idle()
        assertTrue(activity.isFinishing)
    }

    @Test fun healthTellsTheAppAboutTheAlarmScreen() {
        val health = PrayerAlarms.health(app)
        // Android 14+ asks the platform, which Robolectric answers with its own
        // app-op state; before 14 the permission is always granted.
        assertTrue(health["fullScreen"] is Boolean)
        if (Build.VERSION.SDK_INT < 34) assertEquals(true, health["fullScreen"])
        assertNull(health["snoozedUntil"])
        val at = PrayerAlarms.snooze(app, event())
        assertEquals(at, PrayerAlarms.health(app)["snoozedUntil"])
    }
}

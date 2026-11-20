package wlaa41.github.io.flutter_pro

import android.app.*
import android.content.*
import android.media.*
import android.net.Uri
import android.os.*
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject

/**
 * A persisted queue with only ONE OS alarm armed. No polling or always-on service.
 *
 * At the moment an alarm fires the phone decides what to do:
 * - ringer on, no Do Not Disturb: the athan plays in full, at the alarm volume;
 * - ringer on vibrate or silent: the phone vibrates and shows the reminder;
 * - Do Not Disturb: a reminder only, which the phone treats by its own rules.
 */
object PrayerAlarms {
    private const val STORE = "prayer_alarm_queue"
    private const val REQUEST = 7821
    /** A reminder that fires more than this late becomes a quiet note. */
    const val LATE_MILLIS = 10 * 60 * 1000L
    const val CHANNEL_PLAYBACK = "athan_playback_v1"
    const val CHANNEL_QUIET = "prayer_quiet_v3"
    const val CHANNEL_VIBRATE = "prayer_vibrate_v3"
    private val RETIRED = listOf("athan_silent_v1", "athan_vibrate_v1")
    /** Three long pulses, a pause, three more: hard to miss in a pocket. */
    val PATTERN = longArrayOf(0, 800, 400, 800, 400, 800, 1200, 800, 400, 800, 400, 800)

    enum class Delivery { PLAY, VIBRATE, NOTIFY, QUIET }

    private fun prefs(c: Context) = c.getSharedPreferences(STORE, Context.MODE_PRIVATE)
    private fun manager(c: Context) = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    fun exact(c: Context) = Build.VERSION.SDK_INT < 31 || manager(c).canScheduleExactAlarms()
    private fun queue(c: Context): JSONArray = try { JSONArray(prefs(c).getString("queue", "[]")) } catch (_: Exception) { JSONArray() }
    private fun list(array: JSONArray) = (0 until array.length()).map { array.getJSONObject(it) }
    private fun save(c: Context, events: List<JSONObject>) {
        prefs(c).edit().putString("queue", JSONArray(events.sortedBy { it.optLong("time") }).toString()).commit()
    }
    private fun pending(c: Context, event: JSONObject? = null): PendingIntent {
        val intent = Intent(c, PrayerAlarmReceiver::class.java).setAction("PRAYER_ALERT")
        event?.let { intent.putExtra("event", it.toString()) }
        return PendingIntent.getBroadcast(c, REQUEST, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    /** The app's new plan. A test alarm still on its way is kept: the app
     *  refreshes its plan every time it opens. */
    @Synchronized fun replace(c: Context, events: String) {
        val parsed = list(JSONArray(events)) // Validate before changing a working queue.
        val now = System.currentTimeMillis()
        val tests = list(queue(c)).filter { it.optBoolean("test") && it.optLong("time") > now }
        save(c, parsed + tests)
        if (parsed.isEmpty() && tests.isEmpty()) c.stopService(Intent(c, AthanPlaybackService::class.java))
        armNext(c)
    }

    /** A test that goes through the same alarm as a real prayer. */
    @Synchronized fun addTest(c: Context, event: JSONObject) {
        event.put("test", true)
        save(c, list(queue(c)).filter { it.optInt("id") != event.optInt("id") } + event)
        armNext(c)
    }

    @Synchronized fun armNext(c: Context) {
        manager(c).cancel(pending(c))
        // Armed whether or not notifications are allowed: without them the
        // athan still plays, there is only no reminder in the shade.
        val now = System.currentTimeMillis()
        val future = list(queue(c)).filter { it.optLong("time") > now }
        save(c, future)
        val event = future.minByOrNull { it.optLong("time") } ?: return
        val whenMillis = event.getLong("time")
        val operation = pending(c, event)
        if (exact(c)) {
            try {
                // An alarm clock alarm: exact, fires in Doze, and lets the
                // receiver start the playback service from the background.
                val show = PendingIntent.getActivity(c, 0, Intent(c, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                manager(c).setAlarmClock(AlarmManager.AlarmClockInfo(whenMillis, show), operation)
                return
            } catch (_: SecurityException) { /* Permission can be revoked between check and set. */ }
        }
        if (Build.VERSION.SDK_INT >= 23) manager(c).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMillis, operation)
        else manager(c).set(AlarmManager.RTC_WAKEUP, whenMillis, operation)
    }

    /**
     * Takes [event] off the queue. True when it is due and was not delivered
     * yet. An event the app's own refresh dropped a moment before its alarm
     * arrived still counts, so opening the app at prayer time cannot swallow
     * the athan.
     */
    @Synchronized fun consume(c: Context, event: JSONObject): Boolean {
        val id = event.optInt("id")
        val time = event.optLong("time")
        val now = System.currentTimeMillis()
        val delivered = try { JSONObject(prefs(c).getString("delivered", "{}") ?: "{}") } catch (_: Exception) { JSONObject() }
        if (delivered.optLong(id.toString(), -1L) == time) return false
        val old = list(queue(c))
        val queued = old.any { it.optInt("id") == id && it.optLong("time") == time }
        if (!queued && now - time > LATE_MILLIS) return false
        // Keep a day of delivered reminders, enough to refuse a repeat.
        val kept = JSONObject()
        for (key in delivered.keys()) if (now - delivered.optLong(key) < 24 * 60 * 60 * 1000L) kept.put(key, delivered.optLong(key))
        kept.put(id.toString(), time)
        prefs(c).edit().putString("delivered", kept.toString()).commit()
        save(c, old.filter { it.optInt("id") != id })
        armNext(c)
        return true
    }

    fun ringer(c: Context): Int = (c.getSystemService(Context.AUDIO_SERVICE) as AudioManager).ringerMode
    fun doNotDisturb(c: Context): Boolean = Build.VERSION.SDK_INT >= 23 &&
        (c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).currentInterruptionFilter.let {
            it != NotificationManager.INTERRUPTION_FILTER_ALL && it != NotificationManager.INTERRUPTION_FILTER_UNKNOWN
        }
    /** The athan's own notification channel, turned down by the user in the phone's settings. */
    private fun playbackMuted(c: Context): Boolean {
        if (Build.VERSION.SDK_INT < 26) return false
        val channel = (c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).getNotificationChannel(CHANNEL_PLAYBACK)
        return channel != null && channel.importance < NotificationManager.IMPORTANCE_DEFAULT
    }

    /** What the phone does for a reminder with [soundId], given its sound mode. */
    fun decide(soundId: String, ringerMode: Int, dnd: Boolean, playbackMuted: Boolean = false): Delivery = when {
        soundId == "silent" -> Delivery.QUIET
        dnd -> Delivery.NOTIFY
        soundId == "vibrate" -> Delivery.VIBRATE
        ringerMode != AudioManager.RINGER_MODE_NORMAL -> Delivery.VIBRATE
        playbackMuted -> Delivery.NOTIFY
        else -> Delivery.PLAY
    }

    fun health(c: Context): Map<String, Any?> {
        val now = System.currentTimeMillis()
        val future = list(queue(c)).filter { it.optLong("time") > now }.sortedBy { it.optLong("time") }
        val next = future.firstOrNull()
        val power = c.getSystemService(Context.POWER_SERVICE) as PowerManager
        return mapOf(
            "exact" to exact(c),
            "batteryOptimized" to (Build.VERSION.SDK_INT >= 23 && !power.isIgnoringBatteryOptimizations(c.packageName)),
            "count" to future.size,
            "until" to future.lastOrNull()?.optLong("time"),
            "nextTime" to next?.optLong("time"),
            "nextTitle" to next?.optString("title"),
            "ringer" to when (ringer(c)) {
                AudioManager.RINGER_MODE_SILENT -> "silent"
                AudioManager.RINGER_MODE_VIBRATE -> "vibrate"
                else -> "normal"
            },
            "dnd" to doNotDisturb(c),
            "playbackMuted" to playbackMuted(c),
            "notifications" to notificationsAllowed(c),
            "sdk" to Build.VERSION.SDK_INT,
            "maker" to Build.MANUFACTURER,
        )
    }

    fun notificationsAllowed(c: Context): Boolean = Build.VERSION.SDK_INT < 24 || (c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).areNotificationsEnabled()

    private fun channel(c: Context, id: String) {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // Older channels were created at normal importance and cannot be raised.
        for (old in nm.notificationChannels) if (old.id in RETIRED || (old.id.startsWith("athan_fallback_") && old.id.endsWith("_v2"))) nm.deleteNotificationChannel(old.id)
        if (nm.getNotificationChannel(id) != null) return
        val created = when (id) {
            CHANNEL_PLAYBACK -> NotificationChannel(id, "Athan playback", NotificationManager.IMPORTANCE_DEFAULT).apply {
                setSound(null, null); enableVibration(false)
            }
            CHANNEL_VIBRATE -> NotificationChannel(id, "Prayer reminders (vibrate)", NotificationManager.IMPORTANCE_HIGH).apply {
                setSound(null, null); enableVibration(true); vibrationPattern = PATTERN
            }
            CHANNEL_QUIET -> NotificationChannel(id, "Prayer reminders", NotificationManager.IMPORTANCE_HIGH).apply {
                setSound(null, null); enableVibration(false)
            }
            else -> {
                // "athan_fallback_<tone>_v3": a channel's sound cannot change later,
                // so each tone and loudness has its own.
                val tone = id.removePrefix("athan_fallback_").removeSuffix("_v3")
                NotificationChannel(id, "Prayer reminders", NotificationManager.IMPORTANCE_HIGH).apply {
                    setSound(Uri.parse("android.resource://${c.packageName}/raw/$tone"), Tones.attributes(true))
                    enableVibration(true); vibrationPattern = PATTERN
                }
            }
        }
        created.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        nm.createNotificationChannel(created)
    }

    /** The tone a phone-side fallback reminder rings with. */
    private fun fallbackTone(c: Context, event: JSONObject): String {
        val wanted = event.optString("resource")
        return if (event.optString("soundId") in BeepMode.TONES && c.resources.getIdentifier(wanted, "raw", c.packageName) != 0) wanted else "beep"
    }

    fun notification(c: Context, event: JSONObject, playing: Boolean, channelId: String = CHANNEL_QUIET, text: String? = null): Notification {
        val soundId = event.optString("soundId")
        channel(c, channelId)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, channelId) else Notification.Builder(c)
        builder.setSmallIcon(R.drawable.ic_prayer_notification).setContentTitle(event.optString("title", "Prayer reminder"))
            .setContentText(text ?: if (playing && soundId !in BeepMode.TONES) "Tap Stop to end the athan" else event.optString("body"))
            .setCategory(if (playing) Notification.CATEGORY_ALARM else Notification.CATEGORY_REMINDER)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setAutoCancel(!playing).setOngoing(playing).setShowWhen(true)
            .setContentIntent(PendingIntent.getActivity(c, 0, Intent(c, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        if (Build.VERSION.SDK_INT < 26) {
            @Suppress("DEPRECATION")
            builder.setPriority(Notification.PRIORITY_HIGH)
            if (channelId == CHANNEL_VIBRATE) @Suppress("DEPRECATION") builder.setVibrate(PATTERN)
            if (channelId.startsWith("athan_fallback_")) {
                @Suppress("DEPRECATION")
                builder.setSound(Uri.parse("android.resource://${c.packageName}/raw/${fallbackTone(c, event)}"))
            }
        }
        if (playing) {
            val stop = PendingIntent.getService(c, 1, Intent(c, AthanPlaybackService::class.java).setAction("STOP"), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            builder.addAction(android.R.drawable.ic_media_pause, "Stop", stop)
            if (soundId !in BeepMode.TONES) {
                val beep = PendingIntent.getService(c, 2, Intent(c, AthanPlaybackService::class.java).setAction("BEEP_TODAY"), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                builder.addAction(android.R.drawable.ic_lock_silent_mode, "Beep today", beep)
            }
        }
        return builder.build()
    }

    private fun show(c: Context, event: JSONObject, channelId: String, text: String? = null) {
        // Without notification permission Android drops this quietly; the
        // athan and the vibration do not depend on it.
        try {
            (c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .notify(event.optInt("id"), notification(c, event, false, channelId, text))
        } catch (_: RuntimeException) { }
    }

    /** A reminder that rings with a phone tone and vibrates, for when the athan cannot play. */
    fun showFallback(c: Context, event: JSONObject) = show(c, event, "athan_fallback_${fallbackTone(c, event)}_v3")

    /** Delivers [event] now. [onTime] is false for a reminder that arrived late. */
    fun deliver(c: Context, event: JSONObject, onTime: Boolean = true) {
        if (!onTime) { show(c, event, CHANNEL_QUIET); return }
        when (decide(event.optString("soundId"), ringer(c), doNotDisturb(c), playbackMuted(c))) {
            Delivery.QUIET -> show(c, event, CHANNEL_QUIET)
            Delivery.NOTIFY -> show(c, event, CHANNEL_VIBRATE)
            Delivery.VIBRATE -> {
                // Vibrates as an alarm does, so it is felt on silent as well.
                Tones.vibrate(c, PATTERN, alarm = true)
                show(c, event, CHANNEL_QUIET, "Your phone is on silent, so it vibrated instead of the athan.")
            }
            Delivery.PLAY -> try {
                val intent = Intent(c, AthanPlaybackService::class.java).putExtra("event", event.toString())
                if (Build.VERSION.SDK_INT >= 26) c.startForegroundService(intent) else c.startService(intent)
            } catch (_: RuntimeException) {
                // Android refused to start playback from the background: ring a tone instead.
                showFallback(c, event)
            }
        }
    }
}

class PrayerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "PRAYER_ALERT") { PrayerAlarms.armNext(context); return }
        val event = try { JSONObject(intent.getStringExtra("event") ?: return) } catch (_: Exception) { return }
        // Keeps the phone awake until the playback service holds its own lock.
        try {
            (context.getSystemService(Context.POWER_SERVICE) as PowerManager)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "athan:deliver").acquire(30_000L)
        } catch (_: RuntimeException) { }
        if (!PrayerAlarms.consume(context, event)) return
        // A delayed alarm should leave a useful reminder, never a late athan.
        if (System.currentTimeMillis() - event.optLong("time") > PrayerAlarms.LATE_MILLIS) {
            event.put("soundId", "silent").put("body", "This reminder arrived late. Open Athan and check Reminder readiness.")
            PrayerAlarms.deliver(context, event, onTime = false)
            return
        }
        // Beep mode is decided here, at the moment of the reminder, so the quick
        // settings tile and the shortcuts work while the app is closed.
        PrayerAlarms.deliver(context, BeepMode.apply(context, event))
    }
}

class AthanPlaybackService : Service(), AudioManager.OnAudioFocusChangeListener {
    private var player: MediaPlayer? = null
    private var focus: AudioFocusRequest? = null
    private val handler = Handler(Looper.getMainLooper())
    private val timeout = Runnable { stopSelf() }
    override fun onBind(intent: Intent?) = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "BEEP_TODAY") {
            BeepMode.set(this, BeepMode.endOfToday())
            try { android.widget.Toast.makeText(applicationContext, "Athan: beep only until midnight", android.widget.Toast.LENGTH_SHORT).show() } catch (_: RuntimeException) { }
            stopSelf(); return START_NOT_STICKY
        }
        if (intent?.action == "STOP" || intent == null) { stopSelf(); return START_NOT_STICKY }
        val event = try { JSONObject(intent.getStringExtra("event") ?: "{}") } catch (_: Exception) { stopSelf(); return START_NOT_STICKY }
        try {
            val notice = PrayerAlarms.notification(this, event, true, PrayerAlarms.CHANNEL_PLAYBACK)
            if (Build.VERSION.SDK_INT >= 29) startForeground(7822, notice, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            else startForeground(7822, notice)
        } catch (_: RuntimeException) {
            PrayerAlarms.showFallback(this, event)
            stopSelf(); return START_NOT_STICKY
        }
        releasePlayer()
        abandonFocus()
        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        // The athan plays as an alarm: at the alarm volume, and not cut off by a
        // low notification volume. A tone may use the notification volume.
        val tone = event.optString("soundId") in BeepMode.TONES
        val options = BeepMode.options(this)
        val alarmVolume = !tone || options.optBoolean("alarmVolume")
        val attributes = if (tone) Tones.attributes(alarmVolume)
            else AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()
        val gain = if (tone) AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK else AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
        val granted = if (Build.VERSION.SDK_INT >= 26) {
            focus = AudioFocusRequest.Builder(gain).setAudioAttributes(attributes).setOnAudioFocusChangeListener(this).build()
            audio.requestAudioFocus(focus!!)
        } else @Suppress("DEPRECATION") audio.requestAudioFocus(this, if (alarmVolume) AudioManager.STREAM_ALARM else AudioManager.STREAM_NOTIFICATION, gain)
        // Refused during a phone call: the reminder vibrates and stays in the shade.
        if (granted != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) { finishWithReminder(event, vibrate = true); return START_NOT_STICKY }
        try {
            // Store ownership before any configuration can throw so onDestroy
            // also releases a player whose source or preparation failed.
            val nextPlayer = MediaPlayer()
            player = nextPlayer
            nextPlayer.apply {
                setAudioAttributes(attributes)
                setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
                val path = event.optString("filePath")
                if (path.isNotEmpty() && java.io.File(path).canRead()) setDataSource(path)
                else {
                    // A removed file, or a sound name another app version does not
                    // know, falls back to the classic athan, then to a beep.
                    val wanted = if (path.isNotEmpty()) "smooth" else event.optString("resource", "beep")
                    var resource = resources.getIdentifier(wanted, "raw", packageName)
                    if (resource == 0) resource = resources.getIdentifier("beep", "raw", packageName)
                    resources.openRawResourceFd(resource).use { fd -> setDataSource(fd.fileDescriptor, fd.startOffset, fd.length) }
                }
                // A beep is over in a second: leave a quiet line saying which prayer it was for.
                setOnCompletionListener { if (tone) finishWithReminder(event) else stopSelf() }
                setOnErrorListener { _, _, _ -> PrayerAlarms.showFallback(this@AthanPlaybackService, event); stopSelf(); true }
                setOnPreparedListener { it.start() }
                prepareAsync()
            }
            if (tone && options.optBoolean("vibrate")) Tones.vibrate(this)
            handler.removeCallbacks(timeout)
            handler.postDelayed(timeout, 10 * 60 * 1000L)
        } catch (_: Exception) {
            PrayerAlarms.showFallback(this, event)
            stopSelf()
        }
        return START_NOT_STICKY
    }
    override fun onAudioFocusChange(change: Int) { if (change <= AudioManager.AUDIOFOCUS_LOSS) stopSelf() }
    private fun releasePlayer() { player?.release(); player = null }
    private fun finishWithReminder(event: JSONObject, vibrate: Boolean = false) {
        if (vibrate) Tones.vibrate(this, PrayerAlarms.PATTERN, alarm = true)
        try {
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .notify(event.optInt("id"), PrayerAlarms.notification(this, event, false))
        } catch (_: RuntimeException) { }
        stopSelf()
    }
    private fun abandonFocus() {
        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= 26) focus?.let { audio.abandonAudioFocusRequest(it) } else @Suppress("DEPRECATION") audio.abandonAudioFocus(this)
        focus = null
    }
    override fun onDestroy() {
        handler.removeCallbacks(timeout)
        releasePlayer()
        abandonFocus()
        if (Build.VERSION.SDK_INT >= 24) stopForeground(Service.STOP_FOREGROUND_REMOVE) else @Suppress("DEPRECATION") stopForeground(true)
        super.onDestroy()
    }
}

/** One switch: every Athan and Iqama becomes the chosen beep until a set time. */
object BeepMode {
    /** "Until I turn it off"; the same number the app uses. */
    const val FOREVER = 253402300799000L
    val TONES = setOf("beep", "double_beep", "chime", "strong_beep")
    private fun prefs(c: Context) = c.getSharedPreferences("prayer_alarm_queue", Context.MODE_PRIVATE)

    /** When the beep hands back to the Athan, or 0 while the mode is off. */
    fun until(c: Context): Long {
        val stored = prefs(c).getLong("beep_until", 0L)
        return if (stored > System.currentTimeMillis()) stored else 0L
    }
    fun isOn(c: Context) = until(c) > 0L
    fun set(c: Context, until: Long) {
        val editor = prefs(c).edit()
        if (until <= System.currentTimeMillis()) editor.remove("beep_until") else editor.putLong("beep_until", until)
        editor.commit()
        BeepTileService.refresh(c)
    }
    fun endOfToday(): Long = java.util.Calendar.getInstance().apply {
        add(java.util.Calendar.DAY_OF_YEAR, 1)
        set(java.util.Calendar.HOUR_OF_DAY, 0); set(java.util.Calendar.MINUTE, 0)
        set(java.util.Calendar.SECOND, 0); set(java.util.Calendar.MILLISECOND, 0)
    }.timeInMillis

    /** The beep the app chose (sound, loudness file, vibration, which volume). */
    fun options(c: Context): JSONObject = try { JSONObject(prefs(c).getString("beep_options", "{}") ?: "{}") } catch (_: Exception) { JSONObject() }
    fun setOptions(c: Context, json: String) {
        JSONObject(json) // Reject anything that is not an object before saving.
        prefs(c).edit().putString("beep_options", json).commit()
    }

    /** The reminder to deliver: unchanged, or with the beep in place of its sound. */
    fun apply(c: Context, event: JSONObject): JSONObject {
        // Judged by the reminder's own time, so one that fires a little late still
        // gets the choice that was in force when it was due.
        val until = prefs(c).getLong("beep_until", 0L)
        if (until <= 0L || event.optLong("time", System.currentTimeMillis()) >= until) return event
        val chosen = options(c)
        return JSONObject(event.toString())
            .put("soundId", chosen.optString("soundId", "beep"))
            .put("resource", chosen.optString("resource", "beep"))
            .put("filePath", chosen.optString("filePath", ""))
    }
}

/** Shared by the playback service and the in-app "Test" button. */
object Tones {
    private var preview: MediaPlayer? = null
    fun attributes(alarmVolume: Boolean): AudioAttributes = AudioAttributes.Builder()
        .setUsage(if (alarmVolume) AudioAttributes.USAGE_ALARM else AudioAttributes.USAGE_NOTIFICATION_EVENT)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()

    /** Vibrates once through [pattern]. With [alarm] it vibrates as an alarm
     *  does, which a phone on silent still lets through. */
    fun vibrate(c: Context, pattern: LongArray = longArrayOf(0, 260, 140, 260), alarm: Boolean = false) {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= 31) (c.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
                else @Suppress("DEPRECATION") (c.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator)
            if (Build.VERSION.SDK_INT >= 33 && alarm) {
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1), VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ALARM))
            } else if (Build.VERSION.SDK_INT >= 26 && alarm) {
                @Suppress("DEPRECATION")
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1), AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build())
            } else if (Build.VERSION.SDK_INT >= 26) vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
            else @Suppress("DEPRECATION") vibrator.vibrate(pattern, -1)
        } catch (_: RuntimeException) { /* No vibrator, or the phone refused: the sound still plays. */ }
    }

    /** Plays the chosen beep once, with the same file, volume and buzz as a reminder. */
    @Synchronized fun preview(c: Context, sound: JSONObject) {
        preview?.release(); preview = null
        if (sound.optBoolean("vibrate")) vibrate(c)
        val soundId = sound.optString("soundId")
        if (soundId == "silent" || soundId == "vibrate") return
        val player = MediaPlayer()
        preview = player
        try {
            player.setAudioAttributes(attributes(sound.optBoolean("alarmVolume")))
            val path = sound.optString("filePath")
            if (path.isNotEmpty()) player.setDataSource(path)
            else {
                var resource = c.resources.getIdentifier(sound.optString("resource", "beep"), "raw", c.packageName)
                if (resource == 0) resource = c.resources.getIdentifier("beep", "raw", c.packageName)
                c.resources.openRawResourceFd(resource).use { fd -> player.setDataSource(fd.fileDescriptor, fd.startOffset, fd.length) }
            }
            val done = { finished: MediaPlayer -> finished.release(); synchronized(this) { if (preview === finished) preview = null } }
            player.setOnCompletionListener { done(it) }
            player.setOnErrorListener { failed, _, _ -> done(failed); true }
            player.setOnPreparedListener { it.start() }
            player.prepareAsync()
        } catch (error: Exception) {
            player.release(); preview = null
            throw error
        }
    }
}

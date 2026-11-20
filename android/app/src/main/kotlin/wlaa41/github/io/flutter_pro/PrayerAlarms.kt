package wlaa41.github.io.flutter_pro

import android.app.*
import android.content.*
import android.media.*
import android.net.Uri
import android.os.*
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject

/** A persisted queue with only ONE OS alarm armed. No polling or always-on service. */
object PrayerAlarms {
    private const val STORE = "prayer_alarm_queue"
    private const val REQUEST = 7821
    private fun prefs(c: Context) = c.getSharedPreferences(STORE, Context.MODE_PRIVATE)
    private fun manager(c: Context) = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    fun exact(c: Context) = Build.VERSION.SDK_INT < 31 || manager(c).canScheduleExactAlarms()
    private fun queue(c: Context): JSONArray = try { JSONArray(prefs(c).getString("queue", "[]")) } catch (_: Exception) { JSONArray() }
    private fun pending(c: Context, event: JSONObject? = null): PendingIntent {
        val intent = Intent(c, PrayerAlarmReceiver::class.java).setAction("PRAYER_ALERT")
        event?.let { intent.putExtra("event", it.toString()) }
        return PendingIntent.getBroadcast(c, REQUEST, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
    @Synchronized fun replace(c: Context, events: String) {
        val parsed = JSONArray(events) // Validate before changing a working queue.
        prefs(c).edit().putString("queue", parsed.toString()).commit()
        if (parsed.length() == 0) c.stopService(Intent(c, AthanPlaybackService::class.java))
        armNext(c)
    }
    @Synchronized fun armNext(c: Context) {
        manager(c).cancel(pending(c))
        if (!notificationsAllowed(c)) return
        val old = queue(c)
        val future = JSONArray()
        val now = System.currentTimeMillis()
        for (i in 0 until old.length()) if (old.getJSONObject(i).getLong("time") > now) future.put(old.getJSONObject(i))
        prefs(c).edit().putString("queue", future.toString()).commit()
        if (future.length() == 0) return
        val event = future.getJSONObject(0)
        val whenMillis = event.getLong("time")
        val operation = pending(c, event)
        if (exact(c)) {
            try {
                val show = PendingIntent.getActivity(c, 0, Intent(c, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                manager(c).setAlarmClock(AlarmManager.AlarmClockInfo(whenMillis, show), operation)
                return
            } catch (_: SecurityException) { /* Permission can be revoked between check and set. */ }
        }
        if (Build.VERSION.SDK_INT >= 23) manager(c).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMillis, operation)
        else manager(c).set(AlarmManager.RTC_WAKEUP, whenMillis, operation)
    }
    @Synchronized fun consume(c: Context, event: JSONObject): Boolean {
        val old = queue(c)
        val found = (0 until old.length()).any { old.getJSONObject(it).toString() == event.toString() }
        if (!found) return false
        val future = JSONArray()
        for (i in 0 until old.length()) if (old.getJSONObject(i).optInt("id") != event.optInt("id")) future.put(old.getJSONObject(i))
        prefs(c).edit().putString("queue", future.toString()).commit()
        armNext(c)
        return found
    }
    fun health(c: Context): Map<String, Any?> {
        val q = queue(c)
        val future = (0 until q.length()).map { q.getJSONObject(it).optLong("time") }.filter { it > System.currentTimeMillis() }
        val power = c.getSystemService(Context.POWER_SERVICE) as PowerManager
        return mapOf("exact" to exact(c), "batteryOptimized" to (Build.VERSION.SDK_INT >= 23 && !power.isIgnoringBatteryOptimizations(c.packageName)),
            "count" to future.size, "until" to future.maxOrNull())
    }
    fun notificationsAllowed(c: Context): Boolean = Build.VERSION.SDK_INT < 24 || (c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).areNotificationsEnabled()
    fun maySound(c: Context): Boolean {
        val audio = c.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val playbackChannel = if (Build.VERSION.SDK_INT >= 26) nm.getNotificationChannel("athan_playback_v1") else null
        if (playbackChannel != null && playbackChannel.importance < NotificationManager.IMPORTANCE_DEFAULT) return false
        return audio.ringerMode == AudioManager.RINGER_MODE_NORMAL && (Build.VERSION.SDK_INT < 23 || nm.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_ALL)
    }
    fun notification(c: Context, event: JSONObject, playing: Boolean, fallback: Boolean = false): Notification {
        val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val soundId = event.optString("soundId")
        val silent = soundId == "silent"
        val vibrate = soundId == "vibrate"
        // Tones come in five loudness levels; "resource" names the chosen one.
        val wanted = event.optString("resource")
        val fallbackTone = if (soundId in BeepMode.TONES && c.resources.getIdentifier(wanted, "raw", c.packageName) != 0) wanted else "beep"
        val fallbackUri = Uri.parse("android.resource://${c.packageName}/raw/$fallbackTone")
        val channelId = if (playing) "athan_playback_v1" else if (fallback && !silent && !vibrate) "athan_fallback_${fallbackTone}_v2" else if (vibrate) "athan_vibrate_v1" else "athan_silent_v1"
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(channelId, if (playing) "Athan playback" else "Prayer reminders", NotificationManager.IMPORTANCE_DEFAULT)
            channel.setSound(if (fallback && !silent && !vibrate) fallbackUri else null, null)
            channel.enableVibration(vibrate)
            // A channel's sound cannot change later, so each tone and loudness has its own.
            // Old ones are left alone: deleting a channel also clears its notifications.
            nm.createNotificationChannel(channel)
        }
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, channelId) else Notification.Builder(c)
        builder.setSmallIcon(R.drawable.ic_prayer_notification).setContentTitle(event.optString("title", "Prayer reminder"))
            .setContentText(if (playing) "Tap Stop to end the recitation" else event.optString("body"))
            .setCategory(Notification.CATEGORY_REMINDER).setAutoCancel(!playing).setOngoing(playing)
            .setContentIntent(PendingIntent.getActivity(c, 0, Intent(c, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        if (Build.VERSION.SDK_INT < 26) {
            if (fallback && !silent && !vibrate) builder.setSound(fallbackUri)
            if (vibrate) builder.setVibrate(longArrayOf(0, 200, 100, 200))
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
    fun deliver(c: Context, event: JSONObject, fullAudio: Boolean) {
        if (!notificationsAllowed(c)) return
        val sound = event.optString("soundId")
        if (!fullAudio || sound == "silent" || sound == "vibrate" || !maySound(c)) {
            val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(event.optInt("id"), notification(c, event, false, fallback = !fullAudio))
            return
        }
        try {
            val intent = Intent(c, AthanPlaybackService::class.java).putExtra("event", event.toString())
            if (Build.VERSION.SDK_INT >= 26) c.startForegroundService(intent) else c.startService(intent)
        } catch (_: RuntimeException) {
            val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(event.optInt("id"), notification(c, event, false, fallback = true))
        }
    }
}

class PrayerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "PRAYER_ALERT") { PrayerAlarms.armNext(context); return }
        val event = try { JSONObject(intent.getStringExtra("event") ?: return) } catch (_: Exception) { return }
        if (!PrayerAlarms.consume(context, event)) return
        // A delayed inexact alarm should leave a useful reminder, never a late recitation.
        if (System.currentTimeMillis() - event.optLong("time") > 10 * 60 * 1000) {
            event.put("soundId", "silent").put("body", "This reminder arrived late. Open Athan to check reminder settings.")
            PrayerAlarms.deliver(context, event, false)
            return
        }
        // Beep mode is decided here, at the moment of the reminder, so the quick
        // settings tile and the shortcuts work while the app is closed.
        PrayerAlarms.deliver(context, BeepMode.apply(context, event), PrayerAlarms.exact(context))
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
        startForeground(7822, PrayerAlarms.notification(this, event, true))
        if (!PrayerAlarms.maySound(this) || !PrayerAlarms.notificationsAllowed(this)) { stopSelf(); return START_NOT_STICKY }
        releasePlayer()
        abandonFocus()
        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        // A tone may follow the alarm volume and buzz; other audio only dips for it.
        val tone = event.optString("soundId") in BeepMode.TONES
        val options = BeepMode.options(this)
        val alarmVolume = tone && options.optBoolean("alarmVolume")
        val attributes = if (tone) Tones.attributes(alarmVolume)
            else AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()
        val gain = if (tone) AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK else AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
        val granted = if (Build.VERSION.SDK_INT >= 26) {
            focus = AudioFocusRequest.Builder(gain).setAudioAttributes(attributes).setOnAudioFocusChangeListener(this).build()
            audio.requestAudioFocus(focus!!)
        } else audio.requestAudioFocus(this, if (alarmVolume) AudioManager.STREAM_ALARM else AudioManager.STREAM_NOTIFICATION, gain)
        if (granted != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) { finishWithReminder(event); return START_NOT_STICKY }
        try {
            // Store ownership before any configuration can throw so onDestroy
            // also releases a player whose source or preparation failed.
            val nextPlayer = MediaPlayer()
            player = nextPlayer
            nextPlayer.apply {
                setAudioAttributes(attributes)
                setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
                val path = event.optString("filePath")
                if (path.isNotEmpty()) setDataSource(path)
                else {
                    var resource = resources.getIdentifier(event.optString("resource", "beep"), "raw", packageName)
                    // A reminder planned by another app version may name a file this one lacks.
                    if (resource == 0) resource = resources.getIdentifier("beep", "raw", packageName)
                    resources.openRawResourceFd(resource).use { fd -> setDataSource(fd.fileDescriptor, fd.startOffset, fd.length) }
                }
                // A beep is over in a second: leave a quiet line saying which prayer it was for.
                setOnCompletionListener { if (tone) finishWithReminder(event) else stopSelf() }
                setOnErrorListener { _, _, _ -> finishWithReminder(event); true }
                setOnPreparedListener { it.start() }
                prepareAsync()
            }
            if (tone && options.optBoolean("vibrate")) Tones.vibrate(this)
            handler.removeCallbacks(timeout)
            handler.postDelayed(timeout, 10 * 60 * 1000L)
        } catch (_: Exception) { finishWithReminder(event) }
        return START_NOT_STICKY
    }
    override fun onAudioFocusChange(change: Int) { if (change <= AudioManager.AUDIOFOCUS_LOSS) stopSelf() }
    private fun releasePlayer() { player?.release(); player = null }
    private fun finishWithReminder(event: JSONObject) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (PrayerAlarms.notificationsAllowed(this)) nm.notify(event.optInt("id"), PrayerAlarms.notification(this, event, false))
        stopSelf()
    }
    private fun abandonFocus() {
        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= 26) focus?.let { audio.abandonAudioFocusRequest(it) } else audio.abandonAudioFocus(this)
        focus = null
    }
    override fun onDestroy() {
        handler.removeCallbacks(timeout)
        releasePlayer()
        abandonFocus()
        stopForeground(true)
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

    fun vibrate(c: Context) {
        try {
            val pattern = longArrayOf(0, 260, 140, 260)
            val vibrator = if (Build.VERSION.SDK_INT >= 31) (c.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
                else @Suppress("DEPRECATION") (c.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator)
            if (Build.VERSION.SDK_INT >= 26) vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
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

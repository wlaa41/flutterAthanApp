package wlaa41.github.io.flutter_pro

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.format.DateFormat
import android.util.TypedValue
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowInsets
import android.view.WindowManager
import android.view.accessibility.AccessibilityNodeInfo
import android.view.animation.DecelerateInterpolator
import android.view.animation.OvershootInterpolator
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextClock
import android.widget.TextView
import org.json.JSONObject
import java.lang.ref.WeakReference
import java.util.Date
import java.util.Locale
import kotlin.math.abs

/** The alarm screen's two choices, set in the app's Settings. */
object AlarmScreen {
    private const val KEY = "alarm_screen"
    const val DEFAULT_SNOOZE = 10
    private fun prefs(c: Context) = c.getSharedPreferences("prayer_alarm_queue", Context.MODE_PRIVATE)
    private fun options(c: Context): JSONObject = try { JSONObject(prefs(c).getString(KEY, "{}") ?: "{}") } catch (_: Exception) { JSONObject() }

    fun setOptions(c: Context, json: String) {
        JSONObject(json) // Reject anything that is not an object before saving.
        prefs(c).edit().putString(KEY, json).commit()
    }

    /** "Easier screen": any tap on the alarm screen stops the athan. */
    fun easierScreen(c: Context) = options(c).optBoolean("easierScreen", false)
    fun snoozeMinutes(c: Context) = options(c).optInt("snoozeMinutes", DEFAULT_SNOOZE).coerceIn(1, 60)

    /** The clock time [millis] in the phone's own 12 or 24 hour style. */
    fun clock(c: Context, millis: Long): String = DateFormat.getTimeFormat(c).format(Date(millis))
}

/**
 * The black screen an official alarm shows: the time, the prayer, and one slider.
 * Slide right to stop, slide left to snooze. It opens over the lock screen
 * through the athan notification's full-screen intent, and closes itself when
 * the athan ends.
 */
class AlarmActivity : Activity(), AlarmSlider.Listener {
    private val handler = Handler(Looper.getMainLooper())
    private var event = JSONObject()
    private var finished = false
    private lateinit var hint: TextView
    private lateinit var slider: AlarmSlider
    private lateinit var title: TextView
    private var easier = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showing = WeakReference(this)
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        @Suppress("DEPRECATION")
        if (Build.VERSION.SDK_INT < 35) { window.statusBarColor = Color.BLACK; window.navigationBarColor = Color.BLACK }
        // The volume keys turn the athan down, as they do on an alarm.
        volumeControlStream = AudioManager.STREAM_ALARM
        if (Build.VERSION.SDK_INT >= 33) {
            // Back does nothing: the athan is stopped or snoozed on purpose.
            onBackInvokedDispatcher.registerOnBackInvokedCallback(android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT) { slider.nudge() }
        }
        setContentView(build())
        read(intent)
        // Opened a moment before playback started, or after it ended.
        handler.postDelayed({ if (AthanPlaybackService.current == null) close() }, 4000)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        read(intent)
    }

    @Deprecated("Back is handled by OnBackInvokedCallback from Android 13")
    override fun onBackPressed() { slider.nudge() }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        if (showing?.get() === this) showing = null
        super.onDestroy()
    }

    private fun read(intent: Intent?) {
        event = try { JSONObject(intent?.getStringExtra("event") ?: "{}") } catch (_: Exception) { JSONObject() }
        AthanPlaybackService.current?.let { if (event.length() == 0) event = it }
        title.text = event.optString("title", "Prayer time").ifEmpty { "Prayer time" }
        easier = AlarmScreen.easierScreen(this)
        showHint()
    }

    private fun showHint() {
        val minutes = AlarmScreen.snoozeMinutes(this)
        hint.text = if (easier) "Tap anywhere to stop · Slide left to snooze $minutes min"
            else "Slide right to stop · Slide left to snooze $minutes min"
        slider.invalidate()
    }

    private fun sp(view: TextView, size: Float) = view.setTextSize(TypedValue.COMPLEX_UNIT_SP, size)
    private fun dp(value: Float) = (value * resources.displayMetrics.density).toInt()

    private fun build(): View {
        val root = FrameLayout(this).apply {
            id = R.id.alarm_root
            setBackgroundColor(Color.BLACK)
            // "Easier screen": any tap stops. A slide still snoozes.
            setOnClickListener { if (easier) stopAthan() else slider.nudge() }
            contentDescription = "Athan alarm"
        }
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
        }
        title = TextView(this).apply {
            id = R.id.alarm_title
            setTextColor(Color.argb(230, 255, 255, 255))
            sp(this, 22f)
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            gravity = Gravity.CENTER
            letterSpacing = 0.02f
        }
        val time = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.BOTTOM
            layoutDirection = View.LAYOUT_DIRECTION_LTR
        }
        val clock = TextClock(this).apply {
            id = R.id.alarm_clock
            format12Hour = "h:mm"
            format24Hour = "HH:mm"
            setTextColor(Color.WHITE)
            sp(this, 96f)
            typeface = Typeface.create("sans-serif-thin", Typeface.NORMAL)
            includeFontPadding = false
        }
        val meridiem = TextClock(this).apply {
            format12Hour = " a"
            format24Hour = ""
            setTextColor(Color.argb(200, 255, 255, 255))
            sp(this, 24f)
            typeface = Typeface.create("sans-serif-light", Typeface.NORMAL)
            setPadding(0, 0, 0, dp(16f))
        }
        time.addView(clock)
        time.addView(meridiem)
        val pattern = DateFormat.getBestDateTimePattern(Locale.getDefault(), "EEEEdMMMM")
        val date = TextClock(this).apply {
            format12Hour = pattern
            format24Hour = pattern
            setTextColor(Color.argb(170, 255, 255, 255))
            sp(this, 17f)
            gravity = Gravity.CENTER
        }
        column.addView(title, LinearLayout.LayoutParams(-2, -2).apply { bottomMargin = dp(8f) })
        column.addView(time, LinearLayout.LayoutParams(-2, -2))
        column.addView(date, LinearLayout.LayoutParams(-2, -2).apply { topMargin = dp(4f) })
        root.addView(column, FrameLayout.LayoutParams(-1, -2, Gravity.CENTER).apply { bottomMargin = dp(120f) })

        val bottom = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
        }
        hint = TextView(this).apply {
            id = R.id.alarm_hint
            setTextColor(Color.argb(150, 255, 255, 255))
            sp(this, 14f)
            gravity = Gravity.CENTER
        }
        slider = AlarmSlider(this).apply {
            id = R.id.alarm_slider
            listener = this@AlarmActivity
        }
        bottom.addView(hint, LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = dp(14f) })
        bottom.addView(slider, LinearLayout.LayoutParams(-1, dp(84f)))
        root.addView(bottom, FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM).apply {
            leftMargin = dp(20f); rightMargin = dp(20f); bottomMargin = dp(36f)
        })
        // Android 15 draws every app edge to edge: keep clear of the system bars.
        if (Build.VERSION.SDK_INT >= 35) root.setOnApplyWindowInsetsListener { view, insets ->
            val bars = insets.getInsets(WindowInsets.Type.systemBars())
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            insets
        }
        return root
    }

    override fun tapped() { if (easier) stopAthan() else slider.nudge() }

    override fun stopAthan() {
        if (finished) return
        finished = true
        stopService(Intent(this, AthanPlaybackService::class.java))
        close()
    }

    override fun snoozeAthan() {
        if (finished) return
        finished = true
        val playing = AthanPlaybackService.current ?: event
        val at = PrayerAlarms.snooze(this, playing)
        stopService(Intent(this, AthanPlaybackService::class.java))
        hint.text = "Snoozed until ${AlarmScreen.clock(this, at)}"
        hint.setTextColor(AlarmSlider.SNOOZE)
        handler.postDelayed({ close() }, 1100)
    }

    private fun close() {
        if (isFinishing) return
        finish()
        @Suppress("DEPRECATION") overridePendingTransition(0, android.R.anim.fade_out)
    }

    companion object {
        private var showing: WeakReference<AlarmActivity>? = null

        /** The athan ended: the alarm screen goes with it. */
        fun closeAll() { showing?.get()?.let { screen -> if (!screen.finished) screen.handler.post { screen.close() } } }

        fun intent(c: Context, event: JSONObject): Intent = Intent(c, AlarmActivity::class.java)
            .putExtra("event", event.toString())
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION)
    }
}

/**
 * A pill with a round thumb in the middle. Drag the thumb to the right end to
 * stop, to the left end to snooze. A tap is reported separately, for the
 * "Easier screen" setting. Drawn by hand so it works the same on every phone.
 */
class AlarmSlider(context: Context) : View(context) {
    interface Listener { fun stopAthan(); fun snoozeAthan(); fun tapped() }

    var listener: Listener? = null
    var snoozeLabel = "Snooze"
    var stopLabel = "Stop"

    private val density = resources.displayMetrics.density
    private fun dp(value: Float) = value * density
    private val slop = ViewConfiguration.get(context).scaledTouchSlop
    private val track = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(22, 22, 22) }
    private val edge = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = dp(1f); color = Color.rgb(52, 52, 52) }
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = dp(2f) }
    private val thumb = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
    private val label = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = dp(15f); typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
    }
    private val chevron = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE; strokeWidth = dp(2.2f); strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND
    }
    private val icon = context.getDrawable(R.drawable.ic_prayer_notification)?.mutate()?.apply { setTint(Color.rgb(15, 57, 49)) }
    private val box = RectF()

    /** How far the thumb sits from the middle: below 0 toward snooze, above 0 toward stop. */
    private var offset = 0f
    private var downX = 0f
    private var startOffset = 0f
    private var dragging = false
    private var done = false
    private var armed = 0
    private var pulse = 0f
    private var settle: ValueAnimator? = null
    private val pulsing = ValueAnimator.ofFloat(0f, 1f).apply {
        duration = 1700L
        repeatCount = ValueAnimator.INFINITE
        addUpdateListener { pulse = it.animatedValue as Float; invalidate() }
    }

    init {
        isFocusable = true
        isClickable = true
        layoutDirection = LAYOUT_DIRECTION_LTR
        contentDescription = "Alarm slider. Slide right to stop the athan, or left to snooze it."
    }

    private val thumbRadius get() = dp(32f)
    private val travel get() = (width / 2f - dp(6f) - thumbRadius).coerceAtLeast(1f)
    private val threshold get() = travel * 0.7f

    override fun onAttachedToWindow() { super.onAttachedToWindow(); pulsing.start() }
    override fun onDetachedFromWindow() { pulsing.cancel(); settle?.cancel(); super.onDetachedFromWindow() }

    override fun onDraw(canvas: Canvas) {
        val h = height.toFloat()
        val cy = h / 2f
        val radius = h / 2f - dp(2f)
        box.set(dp(2f), cy - radius, width - dp(2f), cy + radius)
        canvas.drawRoundRect(box, radius, radius, track)
        val centre = width / 2f + offset
        val progress = (abs(offset) / travel).coerceIn(0f, 1f)
        // The side being reached fills with its colour.
        if (offset != 0f) {
            fill.color = withAlpha(if (offset < 0) SNOOZE else STOP, (40 + 140 * progress).toInt())
            if (offset < 0) box.set(dp(2f), cy - radius, centre + thumbRadius, cy + radius)
            else box.set(centre - thumbRadius, cy - radius, width - dp(2f), cy + radius)
            canvas.drawRoundRect(box, radius, radius, fill)
        }
        box.set(dp(2f), cy - radius, width - dp(2f), cy + radius)
        canvas.drawRoundRect(box, radius, radius, edge)

        // Labels at both ends, brighter as the thumb comes near.
        val baseline = cy - (label.descent() + label.ascent()) / 2f
        label.textAlign = Paint.Align.LEFT
        label.color = withAlpha(SNOOZE, if (offset < 0) 255 else 200 - (120 * progress).toInt())
        canvas.drawText(snoozeLabel, dp(26f), baseline, label)
        label.textAlign = Paint.Align.RIGHT
        label.color = withAlpha(STOP, if (offset > 0) 255 else 200 - (120 * progress).toInt())
        canvas.drawText(stopLabel, width - dp(26f), baseline, label)

        // Chevrons point both ways while the thumb rests.
        if (!dragging && !done) {
            val fade = ((1f - pulse) * 170).toInt().coerceIn(0, 255)
            for (step in 0..1) {
                val gap = thumbRadius + dp(14f) + step * dp(11f) + pulse * dp(6f)
                chevron.color = withAlpha(Color.WHITE, fade / (step + 1))
                drawChevron(canvas, centre - gap, cy, -1f)
                drawChevron(canvas, centre + gap, cy, 1f)
            }
            // A soft ring breathes out of the thumb.
            ring.color = withAlpha(Color.WHITE, ((1f - pulse) * 110).toInt())
            canvas.drawCircle(centre, cy, thumbRadius + pulse * dp(12f), ring)
        }
        canvas.drawCircle(centre, cy, thumbRadius, thumb)
        icon?.let {
            val half = dp(15f).toInt()
            it.setBounds((centre - half).toInt(), (cy - half).toInt(), (centre + half).toInt(), (cy + half).toInt())
            it.draw(canvas)
        }
    }

    private fun drawChevron(canvas: Canvas, x: Float, y: Float, direction: Float) {
        val s = dp(5f)
        canvas.drawLine(x - s * direction, y - s, x, y, chevron)
        canvas.drawLine(x, y, x - s * direction, y + s, chevron)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (done) return true
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                settle?.cancel()
                downX = event.x
                startOffset = offset
                dragging = false
                parent?.requestDisallowInterceptTouchEvent(true)
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = event.x - downX
                if (!dragging && abs(dx) > slop) dragging = true
                if (dragging) {
                    offset = (startOffset + dx).coerceIn(-travel, travel)
                    val side = when { offset >= threshold -> 1; offset <= -threshold -> -1; else -> 0 }
                    if (side != 0 && side != armed) performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                    armed = side
                    invalidate()
                }
            }
            MotionEvent.ACTION_UP -> {
                if (!dragging) { performClick(); listener?.tapped() }
                else when {
                    offset >= threshold -> complete(1)
                    offset <= -threshold -> complete(-1)
                    else -> back()
                }
                dragging = false
            }
            MotionEvent.ACTION_CANCEL -> { dragging = false; back() }
        }
        return true
    }

    override fun performClick(): Boolean = super.performClick()

    /** Runs the thumb to one end, then reports: 1 is stop, -1 is snooze. */
    fun complete(side: Int) {
        if (done) return
        done = true
        settle?.cancel()
        performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
        settle = ValueAnimator.ofFloat(offset, side * travel).apply {
            duration = 160L
            interpolator = DecelerateInterpolator()
            addUpdateListener { offset = it.animatedValue as Float; invalidate() }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    if (side > 0) listener?.stopAthan() else listener?.snoozeAthan()
                }
            })
            start()
        }
        // Phones with animations turned off end at once.
        if (Build.VERSION.SDK_INT >= 26 && !ValueAnimator.areAnimatorsEnabled()) settle?.end()
    }

    private fun back() {
        armed = 0
        settle?.cancel()
        settle = ValueAnimator.ofFloat(offset, 0f).apply {
            duration = 260L
            interpolator = OvershootInterpolator(1.6f)
            addUpdateListener { offset = it.animatedValue as Float; invalidate() }
            start()
        }
    }

    /** A small shake that says "slide me". */
    fun nudge() {
        if (done || dragging) return
        settle?.cancel()
        settle = ValueAnimator.ofFloat(0f, dp(16f), -dp(16f), dp(8f), 0f).apply {
            duration = 520L
            addUpdateListener { offset = it.animatedValue as Float; invalidate() }
            start()
        }
    }

    override fun onInitializeAccessibilityNodeInfo(info: AccessibilityNodeInfo) {
        super.onInitializeAccessibilityNodeInfo(info)
        info.addAction(AccessibilityNodeInfo.AccessibilityAction(R.id.alarm_action_stop, "Stop the athan"))
        info.addAction(AccessibilityNodeInfo.AccessibilityAction(R.id.alarm_action_snooze, "Snooze the athan"))
    }

    override fun performAccessibilityAction(action: Int, arguments: Bundle?): Boolean = when (action) {
        R.id.alarm_action_stop -> { complete(1); true }
        R.id.alarm_action_snooze -> { complete(-1); true }
        else -> super.performAccessibilityAction(action, arguments)
    }

    companion object {
        /** Gold of the app's palette. */
        val SNOOZE = Color.rgb(222, 186, 110)
        val STOP = Color.rgb(255, 138, 128)
        fun withAlpha(color: Int, alpha: Int) = Color.argb(alpha.coerceIn(0, 255), Color.red(color), Color.green(color), Color.blue(color))
    }
}

package wlaa41.github.io.flutter_pro

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.widget.Toast

/** Quick settings tile: swipe down, tap, and the Athan is a beep until midnight. */
class BeepTileService : TileService() {
    override fun onStartListening() { render() }
    override fun onTileAdded() { render() }
    override fun onClick() {
        BeepMode.set(this, if (BeepMode.isOn(this)) 0L else BeepMode.endOfToday())
        render()
    }
    private fun render() {
        val tile = qsTile ?: return
        val until = BeepMode.until(this)
        tile.state = if (until > 0L) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = "Athan beep"
        val detail = when {
            until <= 0L -> "Off: Athan as usual"
            until >= BeepMode.FOREVER -> "On until you turn it off"
            else -> "On until " + android.text.format.DateFormat.getTimeFormat(this).format(java.util.Date(until))
        }
        if (Build.VERSION.SDK_INT >= 29) tile.subtitle = detail
        tile.contentDescription = "Athan beep. $detail"
        tile.updateTile()
    }
    companion object {
        /** Redraws the tile after the app, a shortcut or a notification changed the mode. */
        fun refresh(c: Context) {
            try { requestListeningState(c, ComponentName(c, BeepTileService::class.java)) } catch (_: RuntimeException) { }
        }
    }
}

/** Target of the app icon shortcuts. Shows nothing: flips the mode, says so, closes. */
class QuickActionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val beep = intent?.action == ACTION_BEEP_TODAY
        BeepMode.set(this, if (beep) BeepMode.endOfToday() else 0L)
        Toast.makeText(applicationContext, if (beep) "Athan: beep only until midnight" else "Athan: back to your usual sound", Toast.LENGTH_SHORT).show()
        finish()
    }
    companion object {
        const val ACTION_BEEP_TODAY = "wlaa41.github.io.flutter_pro.BEEP_TODAY"
        const val ACTION_ATHAN_AS_USUAL = "wlaa41.github.io.flutter_pro.ATHAN_AS_USUAL"
    }
}

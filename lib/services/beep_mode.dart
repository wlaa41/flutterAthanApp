import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/prayer_time_model.dart';

/// How long a quick switch from Athan to the beep lasts.
enum BeepSpan { nextPrayer, today, untilOff }

class BeepModeState {
  const BeepModeState(this.until);
  static const off = BeepModeState(null);

  /// Reminders before this instant use the beep. Null when the mode is off.
  final DateTime? until;

  bool activeAt(DateTime now) => until != null && now.isBefore(until!);
  bool get untilTurnedOff =>
      until != null && until!.millisecondsSinceEpoch >= BeepMode.forever;

  @override
  bool operator ==(Object other) =>
      other is BeepModeState &&
      other.until?.millisecondsSinceEpoch == until?.millisecondsSinceEpoch;
  @override
  int get hashCode => until?.millisecondsSinceEpoch.hashCode ?? 0;
}

/// One switch that turns every Athan and Iqama into the chosen beep for a
/// while. On Android the phone keeps the switch itself, so the quick settings
/// tile and the app icon shortcuts can flip it while the app is closed.
class BeepMode {
  BeepMode._();
  static final BeepMode instance = BeepMode._();
  static const _channel = MethodChannel('athan/alarms');
  static const _key = 'beep_mode_until';

  /// "Until I turn it off", as a timestamp both sides agree on.
  static const int forever = 253402300799000; // 9999-12-31T23:59:59Z

  final ValueNotifier<BeepModeState> state = ValueNotifier(BeepModeState.off);
  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<BeepModeState> load() async {
    final prefs = await SharedPreferences.getInstance();
    var millis = prefs.getInt(_key) ?? 0;
    if (_android) {
      try {
        // The phone's copy wins: the tile may have changed it since last time.
        final native = await _channel.invokeMethod<int>('getBeepMode');
        if (native != null) millis = native;
      } on MissingPluginException {
        // Older install or a test without the channel: keep the saved value.
      } on PlatformException {
        // Same fallback when the phone side cannot answer.
      }
    }
    if (millis <= DateTime.now().millisecondsSinceEpoch) millis = 0;
    if ((prefs.getInt(_key) ?? 0) != millis) {
      millis == 0 ? await prefs.remove(_key) : await prefs.setInt(_key, millis);
    }
    final next = millis == 0
        ? BeepModeState.off
        : BeepModeState(DateTime.fromMillisecondsSinceEpoch(millis));
    state.value = next;
    return next;
  }

  Future<void> turnOn(DateTime until) => _store(until.millisecondsSinceEpoch);
  Future<void> turnOff() => _store(0);

  Future<void> _store(int millis) async {
    if (_android) {
      try {
        // The phone first: if it cannot take the switch, nothing is saved and
        // the caller hears about it.
        await _channel.invokeMethod<void>('setBeepMode', millis);
      } on MissingPluginException {
        // No phone side (a test, or a platform without it): the saved value
        // below still drives reminders planned by the app.
      }
    }
    final prefs = await SharedPreferences.getInstance();
    millis == 0 ? await prefs.remove(_key) : await prefs.setInt(_key, millis);
    state.value = millis == 0
        ? BeepModeState.off
        : BeepModeState(DateTime.fromMillisecondsSinceEpoch(millis));
  }

  /// The moment the beep hands back to the Athan for [span].
  ///
  /// [days] are the loaded timetables; "next prayer" covers that prayer and its
  /// Iqama reminders and ends when the prayer after it begins.
  static DateTime untilFor(
    BeepSpan span, {
    required DateTime now,
    required List<PrayerTimeModel> days,
  }) {
    if (span == BeepSpan.untilOff) {
      return DateTime.fromMillisecondsSinceEpoch(forever);
    }
    final prayers = <DateTime>[
      for (final day in days)
        for (final index in const [1, 3, 4, 5, 6]) day.getPrayerDateTime(index),
    ].where((time) => time.isAfter(now)).toList()..sort();
    if (span == BeepSpan.nextPrayer) {
      if (prayers.length >= 2) return prayers[1];
      return (prayers.isEmpty ? now : prayers.first).add(
        const Duration(hours: 3),
      );
    }
    final local = now.toLocal();
    var midnight = DateTime(local.year, local.month, local.day + 1);
    // Late at night nothing is left today, so "today" means the coming day.
    if (prayers.isNotEmpty && !prayers.first.isBefore(midnight)) {
      midnight = DateTime(local.year, local.month, local.day + 2);
    }
    return midnight;
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/alert_preferences.dart';
import '../models/prayer_time_model.dart';
import '../services/audio_service.dart';
import '../services/beep_mode.dart';
import '../services/notification_service.dart';
import '../services/prayer_service.dart';
import '../services/sound_library.dart';
import 'away_from_home_tile.dart';
import 'weekly_beep.dart';

/// The quick switch on the home screen: one tap turns every Athan and Iqama
/// into the chosen beep for the next prayer, for today, or until switched back.
/// Below it, the days and hours that beep every week.
class BeepModeCard extends StatefulWidget {
  const BeepModeCard({
    super.key,
    this.margin,
    this.onChanged,
    this.upcomingDays,
    this.showWeekly = true,
    this.cityNow,
  });

  final EdgeInsetsGeometry? margin;

  /// Whether the card carries the weekly beep days. Settings shows the same
  /// schedule in a section of its own and leaves it off the card.
  final bool showWeekly;

  /// The clock in the prayer city; the prayer service's when omitted.
  final DateTime Function()? cityNow;

  /// Supplies the coming days' timetable; the prayer service when omitted.
  final Future<List<PrayerTimeModel>> Function()? upcomingDays;

  /// Called after the mode was switched and reminders were updated.
  final VoidCallback? onChanged;

  @override
  State<BeepModeCard> createState() => _BeepModeCardState();
}

class _BeepModeCardState extends State<BeepModeCard>
    with WidgetsBindingObserver {
  static const _green = Color(0xFF0F3931);
  static const _gold = Color(0xFFE3C78F);
  Timer? _expiry;
  bool _busy = false;
  AlertPreferences? _preferences;

  /// Weekly edits not confirmed yet; null when there are none.
  AlertPreferences? _draft;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BeepMode.instance.state.addListener(_stateChanged);
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    BeepMode.instance.state.removeListener(_stateChanged);
    _expiry?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The quick settings tile may have flipped the switch while we were away.
    if (state == AppLifecycleState.resumed) _reload();
  }

  Future<void> _reload() async {
    try {
      await BeepMode.instance.load();
    } catch (_) {
      // The card still shows the last known state.
    }
    if (!widget.showWeekly) return;
    try {
      final preferences = await AlertPreferences.load();
      if (mounted) setState(() => _preferences = preferences);
    } catch (_) {
      // Without saved choices the weekly days stay hidden.
    }
  }

  /// Taps change the draft only. Confirm saves it.
  void _editWeekly(AlertPreferences next) {
    final saved = _preferences;
    if (saved == null) return;
    setState(() => _draft = next.sameWeekly(saved) ? null : next);
  }

  /// Saves the weekly schedule in [draft]. A failure keeps the draft open.
  Future<void> _saveWeekly(AlertPreferences draft) async {
    final before = _preferences;
    if (before == null || _busy) return;
    final next = before.withWeeklyFrom(draft);
    setState(() => _busy = true);
    try {
      await next.save();
      if (mounted) {
        setState(() {
          _preferences = next;
          _draft = null;
        });
      }
    } catch (_) {
      if (mounted) _say('That did not save. Please try again.');
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    try {
      await NotificationService.instance.refreshSchedule();
    } catch (_) {
      // The days are saved; reminders pick them up on the next refresh.
    }
    widget.onChanged?.call();
  }

  Future<void> _editWeeklyHours() async {
    final preferences = _draft ?? _preferences;
    if (preferences == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => WeeklyBeepSheet(
        preferences: preferences,
        cityName: PrayerService.instance.cityName,
        onConfirm: _saveWeekly,
      ),
    );
  }

  Widget? _weekly() {
    final preferences = _preferences;
    if (!widget.showWeekly || preferences == null) return null;
    return WeeklyBeepSection(
      preferences: _draft ?? preferences,
      saved: preferences,
      now: widget.cityNow?.call() ?? PrayerService.instance.now,
      enabled: !_busy,
      onChanged: _editWeekly,
      onEditHours: _editWeeklyHours,
      onConfirm: () => _saveWeekly(_draft ?? preferences),
      onCancel: () => setState(() => _draft = null),
    );
  }

  void _stateChanged() {
    if (!mounted) return;
    _expiry?.cancel();
    final until = BeepMode.instance.state.value.until;
    if (until != null) {
      final remaining = until.difference(DateTime.now());
      // Hand the card back to its resting look when the time is up.
      if (!remaining.isNegative && remaining < const Duration(days: 2)) {
        _expiry = Timer(remaining + const Duration(seconds: 1), _reload);
      }
    }
    setState(() {});
  }

  /// The card changing its look is the confirmation; only failures speak up.
  Future<void> _apply(Future<void> Function() change) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await change();
      try {
        await NotificationService.instance.refreshSchedule();
      } catch (_) {
        // The switch itself is saved; reminders pick it up on the next refresh.
      }
      widget.onChanged?.call();
    } catch (_) {
      if (mounted) _say('That did not save. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _turnOn(BeepSpan span) => _apply(() async {
    // The timetable tells "next prayer" where to stop, and tells "today"
    // whether anything is left before midnight.
    var days = const <PrayerTimeModel>[];
    if (span != BeepSpan.untilOff) {
      try {
        days =
            await (widget.upcomingDays?.call() ??
                PrayerService.instance.getUpcomingPrayers(days: 3));
      } catch (_) {
        // Without a timetable the switch still works: it runs to midnight.
      }
    }
    final until = BeepMode.untilFor(span, now: DateTime.now(), days: days);
    await BeepMode.instance.turnOn(until);
  });

  Future<void> _turnOff() => _apply(BeepMode.instance.turnOff);

  Future<void> _test() async {
    try {
      final preferences = await AlertPreferences.load();
      if (await NotificationService.instance.previewBeep(preferences)) return;
      final sound = (await SoundLibrary.instance.resolve(
        preferences.quietSoundId,
      )).atPower(preferences.beepPower);
      if (sound.canPreview) {
        await AudioService.instance.playSound(sound);
      } else if (mounted) {
        _say('${sound.name} makes no sound to test.');
      }
    } catch (_) {
      if (mounted) _say('The beep could not play. Try again.');
    }
  }

  String _until(BuildContext context, DateTime until) {
    final now = DateTime.now();
    final local = until.toLocal();
    final days = DateTime(
      local.year,
      local.month,
      local.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (local.hour == 0 && local.minute == 0) {
      return days <= 1 ? 'until midnight' : 'until the end of tomorrow';
    }
    final time = TimeOfDay.fromDateTime(local).format(context);
    return days == 0
        ? 'until $time'
        : days == 1
        ? 'until $time tomorrow'
        : 'until $time on ${MaterialLocalizations.of(context).formatShortMonthDay(local)}';
  }

  @override
  Widget build(BuildContext context) {
    final state = BeepMode.instance.state.value;
    final on = state.activeAt(DateTime.now());
    final margin =
        widget.margin ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 6);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: on ? BorderSide.none : const BorderSide(color: Color(0xFFD9E2DC)),
    );
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
    if (on) {
      return Semantics(
        container: true,
        liveRegion: true,
        child: Card(
          margin: margin,
          color: _gold,
          shape: shape,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notifications_paused_rounded, color: _green),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Beep mode is on',
                        style: TextStyle(
                          color: _green,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  state.untilTurnedOff
                      ? 'Athan and Iqama are a beep until you turn this off.'
                      : 'Athan and Iqama are a beep ${_until(context, state.until!)}.',
                  style: const TextStyle(
                    color: Color(0xFF16302A),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : _turnOff,
                      style: style.copyWith(
                        backgroundColor: const WidgetStatePropertyAll(_green),
                        foregroundColor: const WidgetStatePropertyAll(
                          Colors.white,
                        ),
                      ),
                      child: const Text('Back to Athan'),
                    ),
                    TextButton.icon(
                      onPressed: _test,
                      style: style.copyWith(
                        foregroundColor: const WidgetStatePropertyAll(_green),
                      ),
                      icon: const Icon(Icons.volume_up_outlined, size: 20),
                      label: const Text('Test beep'),
                    ),
                  ],
                ),
                ?_weekly(),
                if (widget.showWeekly)
                  AwayFromHomeSection(onChanged: widget.onChanged),
              ],
            ),
          ),
        ),
      );
    }
    return Card(
      margin: margin,
      color: Colors.white,
      shape: shape,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notifications_paused_outlined, color: _green),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Beep instead of Athan',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'For when you are somewhere the Athan should stay quiet.',
              style: TextStyle(color: Color(0xFF475569)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final (label, span) in const [
                  ('Next prayer', BeepSpan.nextPrayer),
                  ('Today', BeepSpan.today),
                  ('Until I turn it off', BeepSpan.untilOff),
                ])
                  FilledButton.tonal(
                    onPressed: _busy ? null : () => _turnOn(span),
                    style: style.copyWith(
                      backgroundColor: const WidgetStatePropertyAll(
                        Color(0xFFE8F0EC),
                      ),
                      foregroundColor: const WidgetStatePropertyAll(_green),
                    ),
                    child: Text(label),
                  ),
              ],
            ),
            ?_weekly(),
            if (widget.showWeekly)
              AwayFromHomeSection(onChanged: widget.onChanged),
          ],
        ),
      ),
    );
  }
}

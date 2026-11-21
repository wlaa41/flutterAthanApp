import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/alert_preferences.dart';
import '../services/sound_library.dart';
import 'alert_settings_controls.dart';

/// Words for the weekly beep schedule, shared by the home card and Settings.
class WeeklyBeepText {
  static const short = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const full = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// "Mon to Fri", "Sat and Sun", "Mon, Wed, Fri" or "every day".
  static String days(Set<int> weekdays) {
    final chosen = [
      for (var day = 1; day <= 7; day++)
        if (weekdays.contains(day)) day,
    ];
    if (chosen.isEmpty) return 'no days';
    if (chosen.length == 7) return 'every day';
    final unbroken = chosen.last - chosen.first == chosen.length - 1;
    if (unbroken && chosen.length >= 3) {
      return '${short[chosen.first - 1]} to ${short[chosen.last - 1]}';
    }
    if (chosen.length == 2) {
      return '${short[chosen.first - 1]} and ${short[chosen.last - 1]}';
    }
    return chosen.map((day) => short[day - 1]).join(', ');
  }

  /// "9:00 AM to 5:00 PM", "all day", or a window that ends the next morning.
  static String hours(BuildContext context, AlertPreferences preferences) {
    final start = preferences.quietStartMinute;
    final end = preferences.quietEndMinute;
    if (start == end) return 'all day';
    String clock(int minute) =>
        TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context);
    return '${clock(start)} to ${clock(end)}${end < start ? ' the next morning' : ''}';
  }

  /// What is heard in place of the Athan: "One beep" for the default tone.
  static String sound(String soundId) =>
      soundId == 'beep' ? 'One beep' : SoundCatalog.byId(soundId).name;
}

/// Weekly beep changes are a draft until Confirm is pressed, so a stray tap
/// on a day cannot change which prayers beep.
extension WeeklyBeepDraft on AlertPreferences {
  bool sameWeekly(AlertPreferences other) =>
      quietEnabled == other.quietEnabled &&
      setEquals(quietWeekdays, other.quietWeekdays) &&
      quietStartMinute == other.quietStartMinute &&
      quietEndMinute == other.quietEndMinute;

  /// These choices with the weekly schedule taken from [draft].
  AlertPreferences withWeeklyFrom(AlertPreferences draft) => copyWith(
    quietEnabled: draft.quietEnabled,
    quietWeekdays: draft.quietWeekdays,
    quietStartMinute: draft.quietStartMinute,
    quietEndMinute: draft.quietEndMinute,
  );

  /// Confirm needs at least one day while the schedule is on.
  bool get weeklyCanSave => !quietEnabled || quietWeekdays.isNotEmpty;
}

/// "Not saved yet" with Cancel and Confirm, under an edited weekly schedule.
class WeeklyConfirmBar extends StatelessWidget {
  const WeeklyConfirmBar({
    super.key,
    required this.draft,
    required this.onConfirm,
    required this.onCancel,
    this.busy = false,
  });

  final AlertPreferences draft;
  final VoidCallback onConfirm, onCancel;
  final bool busy;

  static const _green = Color(0xFF0F3931);

  @override
  Widget build(BuildContext context) {
    final summary = draft.quietEnabled
        ? '${WeeklyBeepText.sound(draft.quietSoundId)} on ${WeeklyBeepText.days(draft.quietWeekdays)}, ${WeeklyBeepText.hours(context, draft)}.'
        : 'Weekly beep off.';
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4D6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3C78F)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Not saved yet',
              style: TextStyle(fontWeight: FontWeight.w700, color: _green),
            ),
            Text(
              draft.weeklyCanSave ? summary : 'Choose at least one day.',
              style: const TextStyle(color: Color(0xFF334155)),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: busy ? null : onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: _green,
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: busy || !draft.weeklyCanSave ? null : onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The weekly part of the home Beep card: one switch, the seven days, and
/// the hours. Days and hours start as Monday to Friday, 9 to 5. Edits stay a
/// draft, shown with Cancel and Confirm, until confirmed.
class WeeklyBeepSection extends StatelessWidget {
  const WeeklyBeepSection({
    super.key,
    required this.preferences,
    required this.now,
    required this.enabled,
    required this.onChanged,
    required this.onEditHours,
    this.saved,
    this.onConfirm,
    this.onCancel,
  });

  /// What the controls show: the draft while one is open.
  final AlertPreferences preferences;

  /// What is in force. A [preferences] that differs from it is unsaved.
  final AlertPreferences? saved;
  final VoidCallback? onConfirm, onCancel;

  /// The clock in the prayer city, to say whether the schedule applies now.
  final DateTime now;
  final bool enabled;
  final ValueChanged<AlertPreferences> onChanged;
  final VoidCallback onEditHours;

  static const _green = Color(0xFF0F3931);

  @override
  Widget build(BuildContext context) {
    final on = preferences.quietEnabled;
    final days = preferences.quietWeekdays;
    final active = saved ?? preferences;
    final beepingNow = active.isQuietAt(now);
    final unsaved = saved != null && !preferences.sameWeekly(saved!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 24, color: _green.withValues(alpha: .18)),
        MergeSemantics(
          child: Row(
            children: [
              const Icon(Icons.event_repeat, color: _green),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Weekly beep days',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      active.quietEnabled
                          ? '${WeeklyBeepText.sound(active.quietSoundId)} instead of Athan and Iqama${beepingNow ? ' · on now' : ''}'
                          : 'One beep on the same days every week, such as work days.',
                      style: const TextStyle(color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: on,
                activeTrackColor: _green,
                onChanged: enabled
                    ? (value) =>
                          onChanged(preferences.copyWith(quietEnabled: value))
                    : null,
              ),
            ],
          ),
        ),
        if (on) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              for (var day = 1; day <= 7; day++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _DayToggle(
                      day: day,
                      selected: days.contains(day),
                      onTap: enabled
                          ? () => onChanged(
                              preferences.copyWith(
                                quietWeekdays: days.contains(day)
                                    ? ({...days}..remove(day))
                                    : {...days, day},
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (days.isEmpty && !unsaved)
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 2),
              child: Text('Choose at least one day.'),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: enabled ? onEditHours : null,
              style: TextButton.styleFrom(
                foregroundColor: _green,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: const Icon(Icons.schedule, size: 20),
              label: Text(
                'Hours: ${WeeklyBeepText.hours(context, preferences)}',
              ),
            ),
          ),
        ],
        if (unsaved && onConfirm != null && onCancel != null)
          WeeklyConfirmBar(
            draft: preferences,
            busy: !enabled,
            onConfirm: onConfirm!,
            onCancel: onCancel!,
          ),
      ],
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final bool selected;
  final VoidCallback? onTap;

  static const _green = Color(0xFF0F3931);

  @override
  Widget build(BuildContext context) {
    final border = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: selected ? _green : _green.withValues(alpha: .4)),
    );
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: WeeklyBeepText.full[day - 1],
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? _green : Colors.transparent,
        shape: border,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    WeeklyBeepText.short[day - 1],
                    style: TextStyle(
                      color: selected ? Colors.white : _green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The full weekly setup: day presets, all day or set hours, start and end.
/// Nothing changes until Confirm; closing the sheet any other way drops the
/// edits.
class WeeklyBeepSheet extends StatefulWidget {
  const WeeklyBeepSheet({
    super.key,
    required this.preferences,
    required this.cityName,
    required this.onConfirm,
  });

  final AlertPreferences preferences;
  final String cityName;
  final ValueChanged<AlertPreferences> onConfirm;

  @override
  State<WeeklyBeepSheet> createState() => _WeeklyBeepSheetState();
}

class _WeeklyBeepSheetState extends State<WeeklyBeepSheet> {
  late AlertPreferences _preferences = widget.preferences;
  // The hours to return to after "All day".
  late int _start = widget.preferences.quietStartMinute;
  late int _end = widget.preferences.quietEndMinute;

  @override
  void initState() {
    super.initState();
    if (_start == _end) {
      _start = const AlertPreferences().quietStartMinute;
      _end = const AlertPreferences().quietEndMinute;
    }
  }

  void _change(AlertPreferences next) => setState(() => _preferences = next);

  @override
  Widget build(BuildContext context) {
    final preferences = _preferences;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Weekly beep days',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'On these days and hours every week, Athan and Iqama are your beep. Other times keep your usual sounds.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    QuietScheduleEditor(
                      weekdays: preferences.quietWeekdays,
                      startMinute: preferences.quietStartMinute,
                      endMinute: preferences.quietEndMinute,
                      enabled: true,
                      onAllDayChanged: (allDay) {
                        final isAllDay =
                            preferences.quietStartMinute ==
                            preferences.quietEndMinute;
                        if (allDay == isAllDay) return;
                        if (allDay) {
                          _start = preferences.quietStartMinute;
                          _end = preferences.quietEndMinute;
                        }
                        _change(
                          preferences.copyWith(
                            quietStartMinute: allDay ? 0 : _start,
                            quietEndMinute: allDay ? 0 : _end,
                          ),
                        );
                      },
                      onWeekdaysChanged: (value) =>
                          _change(preferences.copyWith(quietWeekdays: value)),
                      onStartChanged: (value) => _change(
                        preferences.copyWith(quietStartMinute: value),
                      ),
                      onEndChanged: (value) =>
                          _change(preferences.copyWith(quietEndMinute: value)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Plays ${WeeklyBeepText.sound(preferences.quietSoundId).toLowerCase()}. Change the sound and its power in Settings, under Reminders. Uses the time in ${widget.cityName}.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: preferences.weeklyCanSave
                          ? () {
                              widget.onConfirm(preferences);
                              Navigator.pop(context);
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

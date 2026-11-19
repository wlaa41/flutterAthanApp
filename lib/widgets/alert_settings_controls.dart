import 'package:flutter/material.dart';

/// Controls stay in normal document flow so large text and narrow phones scroll.
class QuietScheduleEditor extends StatelessWidget {
  const QuietScheduleEditor({
    super.key,
    required this.weekdays,
    required this.startMinute,
    required this.endMinute,
    required this.enabled,
    required this.onWeekdaysChanged,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  final Set<int> weekdays;
  final int startMinute;
  final int endMinute;
  final bool enabled;
  final ValueChanged<Set<int>> onWeekdaysChanged;
  final ValueChanged<int> onStartChanged;
  final ValueChanged<int> onEndChanged;
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _fullDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  Future<void> _pickTime(
    BuildContext context,
    int minute,
    ValueChanged<int> onChanged,
  ) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    );
    if (selected != null) onChanged(selected.hour * 60 + selected.minute);
  }

  @override
  Widget build(BuildContext context) {
    final start = TimeOfDay(hour: startMinute ~/ 60, minute: startMinute % 60);
    final end = TimeOfDay(hour: endMinute ~/ 60, minute: endMinute % 60);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quiet days', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (var i = 0; i < 7; i++)
              Semantics(
                label: _fullDays[i],
                child: FilterChip(
                  label: Text(_days[i]),
                  selected: weekdays.contains(i + 1),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: !enabled
                      ? null
                      : (selected) {
                          final next = Set<int>.from(weekdays);
                          selected ? next.add(i + 1) : next.remove(i + 1);
                          onWeekdaysChanged(next);
                        },
                ),
              ),
          ],
        ),
        if (weekdays.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Select at least one day to use quiet hours.'),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule),
              label: Text('From ${start.format(context)}'),
              onPressed: enabled
                  ? () => _pickTime(context, startMinute, onStartChanged)
                  : null,
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule),
              label: Text('Until ${end.format(context)}'),
              onPressed: enabled
                  ? () => _pickTime(context, endMinute, onEndChanged)
                  : null,
            ),
          ],
        ),
        if (endMinute < startMinute)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Finishes the next morning. Choose the days your quiet hours start.',
            ),
          ),
        if (endMinute == startMinute)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Matching times mean quiet all day on your selected days.',
            ),
          ),
      ],
    );
  }
}

class ReminderTimingEditor extends StatelessWidget {
  const ReminderTimingEditor({
    super.key,
    required this.delayMinutes,
    required this.repeatCount,
    required this.intervalMinutes,
    required this.enabled,
    required this.onDelayChanged,
    required this.onRepeatChanged,
    required this.onIntervalChanged,
  });
  final int delayMinutes;
  final int repeatCount;
  final int intervalMinutes;
  final bool enabled;
  final ValueChanged<int> onDelayChanged;
  final ValueChanged<int> onRepeatChanged;
  final ValueChanged<int> onIntervalChanged;

  Widget _number(
    BuildContext context,
    String label,
    int value,
    List<int> options,
    String Function(int) describe,
    ValueChanged<int> onChanged,
  ) {
    final values = {...options, value}.toList()..sort();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<int>(
        initialValue: value,
        isExpanded: true,
        itemHeight: null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final number in values)
            DropdownMenuItem(value: number, child: Text(describe(number))),
        ],
        onChanged: !enabled
            ? null
            : (next) {
                if (next != null) onChanged(next);
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _number(
        context,
        'After Athan',
        delayMinutes,
        [1, 5, 10, 15, 20, 25, 30, 45, 60, 90, 120],
        (value) => '$value minutes',
        onDelayChanged,
      ),
      _number(
        context,
        'Number of reminders',
        repeatCount,
        [1, 2, 3, 4, 5],
        (value) => value == 1 ? 'Once' : '$value times in total',
        onRepeatChanged,
      ),
      if (repeatCount > 1)
        _number(
          context,
          'Time between reminders',
          intervalMinutes,
          [1, 2, 3, 5, 10, 15, 20, 30],
          (value) => value == 1 ? '1 minute' : '$value minutes',
          onIntervalChanged,
        ),
      Text(
        repeatCount == 1
            ? 'One Iqama reminder, $delayMinutes minutes after Athan.'
            : '$repeatCount reminders: first at +$delayMinutes minutes, then every $intervalMinutes minutes.',
      ),
      const SizedBox(height: 8),
      const Text('Reminders stop at sunrise or the next prayer.'),
    ],
  );
}

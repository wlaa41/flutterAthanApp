import '../models/alert_preferences.dart';
import '../models/prayer_time_model.dart';

class PlannedAlert {
  final int id;
  final DateTime time;
  final String title, body, soundId;
  final bool iqama;
  const PlannedAlert({
    required this.id,
    required this.time,
    required this.title,
    required this.body,
    required this.soundId,
    required this.iqama,
  });
}

/// Pure planning: no polling, network, location tracking or foreground timers.
List<PlannedAlert> planAlerts({
  required List<PrayerTimeModel> days,
  required AlertPreferences preferences,
  required Set<int> enabledPrayers,
  required DateTime now,
  int limit = 450,
}) {
  final alerts = <PlannedAlert>[];
  for (final day in days) {
    for (final index in [1, 3, 4, 5, 6]) {
      if (!enabledPrayers.contains(index)) continue;
      final prayer = day.getPrayerDateTime(index);
      final name = day.getPrayerName(index);
      void add(DateTime time, int repeat, bool iqama) {
        if (!time.isAfter(now)) return;
        final dayCode = DateTime.utc(
              day.date.year,
              day.date.month,
              day.date.day,
            ).millisecondsSinceEpoch ~/
            Duration.millisecondsPerDay;
        alerts.add(
          PlannedAlert(
            id: dayCode * 100 + index * 10 + repeat,
            time: time,
            title: iqama ? '$name Iqama' : 'Time for $name',
            body: iqama
                ? 'Iqama reminder ${repeat} of ${preferences.iqamaRepeatCount}'
                : 'It is time for prayer.',
            soundId: preferences.isQuietAt(time)
                ? preferences.quietSoundId
                : (iqama ? preferences.iqamaSoundId : preferences.athanSoundId),
            iqama: iqama,
          ),
        );
      }

      add(prayer, 0, false);
      if (!preferences.iqamaEnabled) continue;
      // Fajr ends at sunrise; other Iqamas stop before the following prayer.
      final nextIndex = index == 1 ? 2 : index + 1;
      DateTime? nextPrayer;
      if (index < 6) nextPrayer = day.getPrayerDateTime(nextIndex);
      if (index == 6) {
        final following = days.where((d) => d.date.isAfter(day.date)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        if (following.isNotEmpty)
          nextPrayer = following.first.getPrayerDateTime(1);
      }
      for (var repeat = 0;
          repeat < preferences.iqamaRepeatCount.clamp(1, 5);
          repeat++) {
        final time = prayer.add(
          Duration(
            minutes: preferences.iqamaDelayMinutes +
                repeat * preferences.iqamaRepeatIntervalMinutes,
          ),
        );
        if (nextPrayer != null && !time.isBefore(nextPrayer)) break;
        add(time, repeat + 1, true);
      }
    }
  }
  alerts.sort((a, b) => a.time.compareTo(b.time));
  final unique = <int>{};
  return alerts.where((a) => unique.add(a.id)).take(limit).toList();
}

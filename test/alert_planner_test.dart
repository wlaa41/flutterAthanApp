import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/models/alert_preferences.dart';
import 'package:flutter_pro/models/prayer_time_model.dart';
import 'package:flutter_pro/services/alert_planner.dart';

PrayerTimeModel day(int date) => PrayerTimeModel(
      date: DateTime(2026, 11, date),
      fajr: '06:00',
      sunrise: '07:30',
      dhuhr: '12:00',
      asr: '14:00',
      maghrib: '16:10',
      isha: '18:00',
      timeZoneName: 'Europe/London',
    );

void main() {
  test('work schedule respects weekday and exact boundaries', () {
    const prefs = AlertPreferences(quietEnabled: true);
    expect(prefs.isQuietAt(DateTime(2026, 11, 19, 8, 59)), false);
    expect(prefs.isQuietAt(DateTime(2026, 11, 19, 9)), true);
    expect(prefs.isQuietAt(DateTime(2026, 11, 19, 16, 59)), true);
    expect(prefs.isQuietAt(DateTime(2026, 11, 19, 17)), false);
    expect(prefs.isQuietAt(DateTime(2026, 11, 21, 12)), false);
  });
  test('overnight quiet shift belongs to its starting day', () {
    const prefs = AlertPreferences(
      quietEnabled: true,
      quietWeekdays: {5},
      quietStartMinute: 22 * 60,
      quietEndMinute: 6 * 60,
    );
    expect(prefs.isQuietAt(DateTime(2026, 11, 20, 23)), true);
    expect(prefs.isQuietAt(DateTime(2026, 11, 21, 5)), true);
    expect(prefs.isQuietAt(DateTime(2026, 11, 21, 6)), false);
    expect(prefs.isQuietAt(DateTime(2026, 11, 21, 23)), false);
  });
  test(
    'Iqama count is total reminders; quiet applies separately to each event',
    () {
      const prefs = AlertPreferences(
        iqamaEnabled: true,
        iqamaRepeatCount: 3,
        iqamaDelayMinutes: 45,
        iqamaRepeatIntervalMinutes: 5,
        quietEnabled: true,
      );
      final plan = planAlerts(
        days: [day(19)],
        preferences: prefs,
        enabledPrayers: {5},
        now: DateTime.utc(2026, 11, 19),
      );
      expect(plan.length, 4);
      expect(plan.map((a) => a.time.minute).toList(), [10, 55, 0, 5]);
      expect(plan.map((a) => a.soundId).toList(), [
        'beep',
        'beep',
        'iqama',
        'iqama',
      ]);
      expect(plan.map((a) => a.id).toSet().length, 4);
    },
  );
  test('disable prayer removes its Iqamas and past events never catch up', () {
    final plan = planAlerts(
      days: [day(19)],
      preferences: const AlertPreferences(iqamaEnabled: true),
      enabledPrayers: {1, 3},
      now: DateTime.utc(2026, 11, 19, 12, 5),
    );
    expect(plan.length, 1);
    expect(plan.single.title, 'Dhuhr Iqama');
  });
  test('iOS limit keeps soonest chronological alerts across months', () {
    final plan = planAlerts(
      days: [day(20), day(19), day(21)],
      preferences: const AlertPreferences(
        iqamaEnabled: true,
        iqamaRepeatCount: 5,
      ),
      enabledPrayers: {1, 3, 4, 5, 6},
      now: DateTime.utc(2026, 11, 19),
      limit: 60,
    );
    expect(plan.length, 60);
    for (var i = 1; i < plan.length; i++) {
      expect(plan[i].time.isBefore(plan[i - 1].time), false);
    }
  });
  test(
    'Iqama stops before the next prayer and input days are deduplicated',
    () {
      final plan = planAlerts(
        days: [day(19), day(19)],
        preferences: const AlertPreferences(
          iqamaEnabled: true,
          iqamaDelayMinutes: 120,
          iqamaRepeatCount: 5,
        ),
        enabledPrayers: {3},
        now: DateTime.utc(2026, 11, 19),
      );
      expect(plan.length, 1);
    },
  );
  test('Fajr Iqama does not spill past sunrise', () {
    final plan = planAlerts(
        days: [day(19)],
        preferences:
            const AlertPreferences(iqamaEnabled: true, iqamaDelayMinutes: 120),
        enabledPrayers: {1},
        now: DateTime.utc(2026, 11, 19));
    expect(plan.length, 1);
    expect(plan.single.iqama, false);
  });
  test('persisted preferences round trip and invalid numbers are bounded', () {
    final prefs = AlertPreferences.fromJson({
      'iqamaRepeatCount': 99,
      'quietStartMinute': -5,
      'quietWeekdays': [0, 1, 8],
    });
    expect(prefs.iqamaRepeatCount, 5);
    expect(prefs.quietStartMinute, 0);
    expect(prefs.quietWeekdays, {1});
    expect(AlertPreferences.fromJson(prefs.toJson()).toJson(), prefs.toJson());
  });
}

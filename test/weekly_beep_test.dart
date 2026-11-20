import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/models/alert_preferences.dart';
import 'package:flutter_pro/models/prayer_time_model.dart';
import 'package:flutter_pro/services/alert_planner.dart';
import 'package:flutter_pro/services/beep_mode.dart';
import 'package:flutter_pro/widgets/beep_mode_card.dart';
import 'package:flutter_pro/widgets/weekly_beep.dart';
import 'package:shared_preferences/shared_preferences.dart';

PrayerTimeModel _day(int date) => PrayerTimeModel(
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
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('The schedule starts as one beep, Monday to Friday, 9 to 5, off', () {
    const fresh = AlertPreferences();
    expect(fresh.quietEnabled, isFalse);
    expect(fresh.quietSoundId, 'beep');
    expect(fresh.quietWeekdays, {1, 2, 3, 4, 5});
    expect(fresh.quietStartMinute, 9 * 60);
    expect(fresh.quietEndMinute, 17 * 60);
    expect(WeeklyBeepText.sound(fresh.quietSoundId), 'One beep');
    expect(WeeklyBeepText.days(fresh.quietWeekdays), 'Mon to Fri');
  });

  test('Switched on, it beeps for prayers inside those days and hours', () {
    // 20 November 2026 is a Friday.
    final plan = planAlerts(
      days: [_day(20), _day(21), _day(22), _day(23)],
      preferences: const AlertPreferences(quietEnabled: true),
      enabledPrayers: {1, 3, 4, 5, 6},
      now: DateTime.utc(2026, 11, 19, 23),
    );
    String sound(int day, int hour) => plan
        .singleWhere((a) => a.time.day == day && a.time.hour == hour)
        .soundId;
    // Friday: Dhuhr, Asr and Maghrib fall between 9 and 5.
    expect(sound(20, 6), 'smooth');
    expect(sound(20, 12), 'beep');
    expect(sound(20, 14), 'beep');
    expect(sound(20, 16), 'beep');
    expect(sound(20, 18), 'smooth');
    // The weekend keeps the Athan all day.
    for (final hour in [6, 12, 14, 16, 18]) {
      expect(sound(21, hour), 'smooth');
      expect(sound(22, hour), 'smooth');
    }
    // Monday beeps again.
    expect(sound(23, 12), 'beep');
    expect(sound(23, 18), 'smooth');
  });

  test('Chosen days read the way people say them', () {
    expect(WeeklyBeepText.days({1, 2, 3, 4, 5}), 'Mon to Fri');
    expect(WeeklyBeepText.days({6, 7}), 'Sat and Sun');
    expect(WeeklyBeepText.days({5, 6, 7}), 'Fri to Sun');
    expect(WeeklyBeepText.days({1, 3, 5}), 'Mon, Wed, Fri');
    expect(WeeklyBeepText.days({1, 2, 4}), 'Mon, Tue, Thu');
    expect(WeeklyBeepText.days({3}), 'Wed');
    expect(WeeklyBeepText.days({1, 7}), 'Mon and Sun');
    expect(WeeklyBeepText.days({1, 2, 3, 4, 5, 6, 7}), 'every day');
    expect(WeeklyBeepText.days({}), 'no days');
    expect(WeeklyBeepText.sound('double_beep'), 'Double beep');
    expect(WeeklyBeepText.sound('chime'), 'Gentle chime');
  });

  Future<void> showCard(
    WidgetTester tester, {
    DateTime? cityNow,
    Size size = const Size(412, 915),
    double textScale = 1,
  }) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await BeepMode.instance.turnOff();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: BeepModeCard(
              upcomingDays: () async => const [],
              // A Friday morning unless the test says otherwise.
              cityNow: () => cityNow ?? DateTime(2026, 11, 20, 10),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('One switch on the home card turns the weekly beep on', (
    tester,
  ) async {
    await showCard(tester);
    expect(find.text('Weekly beep days'), findsOneWidget);
    expect(
      find.text('One beep on the same days every week, such as work days.'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Monday'), findsNothing);

    await press(tester, find.byType(Switch));
    final saved = await AlertPreferences.load();
    expect(saved.quietEnabled, isTrue);
    expect(saved.quietWeekdays, {1, 2, 3, 4, 5});
    expect(saved.quietStartMinute, 540);
    expect(saved.quietEndMinute, 1020);
    expect(saved.quietSoundId, 'beep');
    // It is Friday 10:00, inside the schedule.
    expect(
      find.text('One beep instead of Athan and Iqama · on now'),
      findsOneWidget,
    );
    expect(find.text('Hours: 9:00 AM to 5:00 PM'), findsOneWidget);
    for (final day in WeeklyBeepText.full) {
      expect(find.bySemanticsLabel(day), findsOneWidget);
    }

    await press(tester, find.byType(Switch));
    expect((await AlertPreferences.load()).quietEnabled, isFalse);
    expect(find.bySemanticsLabel('Monday'), findsNothing);
    // The days and hours are kept for the next time.
    expect((await AlertPreferences.load()).quietWeekdays, {1, 2, 3, 4, 5});
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Days are chosen on the card, one tap each', (tester) async {
    await const AlertPreferences(quietEnabled: true).save();
    // A Saturday: outside Monday to Friday.
    await showCard(tester, cityNow: DateTime(2026, 11, 21, 10));
    expect(find.text('One beep instead of Athan and Iqama'), findsOneWidget);

    await press(tester, find.bySemanticsLabel('Saturday'));
    expect((await AlertPreferences.load()).quietWeekdays, {1, 2, 3, 4, 5, 6});
    expect(
      find.text('One beep instead of Athan and Iqama · on now'),
      findsOneWidget,
    );

    await press(tester, find.bySemanticsLabel('Monday'));
    await press(tester, find.bySemanticsLabel('Tuesday'));
    expect((await AlertPreferences.load()).quietWeekdays, {3, 4, 5, 6});

    for (final day in ['Wednesday', 'Thursday', 'Friday', 'Saturday']) {
      await press(tester, find.bySemanticsLabel(day));
    }
    expect((await AlertPreferences.load()).quietWeekdays, isEmpty);
    expect(find.text('Choose at least one day.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Hours open from the card and can be all day', (tester) async {
    await const AlertPreferences(quietEnabled: true).save();
    await showCard(tester);
    await press(tester, find.text('Hours: 9:00 AM to 5:00 PM'));
    expect(find.text('Weekly beep days'), findsNWidgets(2));
    expect(find.text('From 9:00 AM'), findsOneWidget);
    expect(find.text('Until 5:00 PM'), findsOneWidget);
    expect(find.textContaining('Plays one beep.'), findsOneWidget);

    await press(tester, find.text('All day'));
    var saved = await AlertPreferences.load();
    expect(saved.quietStartMinute, saved.quietEndMinute);
    expect(find.text('Beeps all day on the chosen days.'), findsOneWidget);

    await press(tester, find.text('Set hours'));
    saved = await AlertPreferences.load();
    expect(saved.quietStartMinute, 540);
    expect(saved.quietEndMinute, 1020);

    await press(tester, find.text('Weekend'));
    expect((await AlertPreferences.load()).quietWeekdays, {6, 7});
    await press(tester, find.text('All day'));
    await press(tester, find.text('Done'));
    expect(find.text('Hours: all day'), findsOneWidget);
    // Friday is no longer a beep day.
    expect(find.text('One beep instead of Athan and Iqama'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('The weekly days stay in view while Beep mode is on', (
    tester,
  ) async {
    await const AlertPreferences(quietEnabled: true).save();
    await showCard(tester);
    await press(tester, find.text('Until I turn it off'));
    expect(find.text('Beep mode is on'), findsOneWidget);
    expect(find.text('Weekly beep days'), findsOneWidget);
    await press(tester, find.bySemanticsLabel('Sunday'));
    expect((await AlertPreferences.load()).quietWeekdays, contains(7));
    await press(tester, find.text('Back to Athan'));
    expect(find.text('Beep instead of Athan'), findsOneWidget);
    expect(find.bySemanticsLabel('Sunday'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in const [Size(320, 568), Size(360, 740)]) {
    testWidgets('The weekly days fit $size with large text', (tester) async {
      await showCard(tester, size: size, textScale: 2);
      await press(tester, find.byType(Switch));
      expect(tester.takeException(), isNull);
      // Every day is still a full-height target, side by side.
      final monday = tester.getRect(find.bySemanticsLabel('Monday'));
      final sunday = tester.getRect(find.bySemanticsLabel('Sunday'));
      expect(monday.height, greaterThanOrEqualTo(44));
      expect(monday.top, sunday.top);
      expect(sunday.right, lessThanOrEqualTo(size.width));
      await press(tester, find.textContaining('Hours:'));
      await press(tester, find.text('All day'));
      await press(tester, find.text('Done'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

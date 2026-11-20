import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/models/alert_preferences.dart';
import 'package:flutter_pro/models/prayer_time_model.dart';
import 'package:flutter_pro/screens/settings_screen.dart';
import 'package:flutter_pro/services/alert_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Settings offers the athans that can be added, with credits', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Audio credits'), 150);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose or add a sound'));
    await tester.pumpAndSettle();
    expect(find.text('Trending athans'), findsOneWidget);
    expect(find.text('محمد بن مروان قصاص'), findsOneWidget);
    expect(find.byTooltip('Add Muhammad Jazi Abdullah'), findsOneWidget);
    await tester.tap(find.byTooltip('Close sound picker'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Audio credits'));
    await tester.pumpAndSettle();
    final credits = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .data!;
    expect(credits, contains('ATHAN AUDIO CREDITS'));
    expect(credits, contains('ATHANS YOU CAN ADD'));
    expect(credits, contains('Muhammad Marwan Qassas: tilawatalharamain.com'));
    expect(credits, contains('Muhammad Jazi Abdullah: archive.org'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('chosen beep days persist and only replace those days', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Reminders'));
    await tester.pumpAndSettle();
    // Beep mode and the beep sound now come first on this page.
    await tester.scrollUntilVisible(find.text('Use a quieter reminder'), 150);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use a quieter reminder'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Weekend'), 150);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekend'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('All day'), 150);
    await tester.pumpAndSettle();
    await tester.tap(find.text('All day'));
    await tester.pumpAndSettle();

    final saved = await AlertPreferences.load();
    expect(saved.quietEnabled, isTrue);
    expect(saved.quietSoundId, 'beep');
    expect(saved.quietWeekdays, {6, 7});
    expect(saved.quietStartMinute, saved.quietEndMinute);

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
    final plan = planAlerts(
      days: [day(20), day(21), day(22), day(23)],
      preferences: saved.copyWith(iqamaEnabled: true),
      enabledPrayers: {1, 3, 4, 5, 6},
      now: DateTime.utc(2026, 11, 20),
    );
    expect(plan.where((a) => a.time.weekday >= 6), isNotEmpty);
    for (final alert in plan) {
      expect(
        alert.soundId,
        alert.time.weekday >= 6
            ? 'beep'
            : alert.iqama
            ? saved.iqamaSoundId
            : saved.athanSoundId,
      );
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScreen(initialSection: SettingsSection.reminders),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Use a quieter reminder'), 150);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Use a quieter reminder'),
          )
          .value,
      isTrue,
    );
    expect((await AlertPreferences.load()).quietWeekdays, {6, 7});
    expect(tester.takeException(), isNull);
  });

  testWidgets('all-day choice restores the existing custom time window', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      'alert_preferences': jsonEncode(
        const AlertPreferences(
          quietEnabled: true,
          quietStartMinute: 600,
          quietEndMinute: 960,
        ).toJson(),
      ),
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScreen(initialSection: SettingsSection.reminders),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('All day'), 150);
    await tester.pumpAndSettle();
    await tester.tap(find.text('All day'));
    await tester.pumpAndSettle();
    expect((await AlertPreferences.load()).quietStartMinute, 0);
    expect((await AlertPreferences.load()).quietEndMinute, 0);
    await tester.tap(find.text('Set hours'));
    await tester.pumpAndSettle();
    expect((await AlertPreferences.load()).quietStartMinute, 600);
    expect((await AlertPreferences.load()).quietEndMinute, 960);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone setup opens directly without searching other settings', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScreen(initialSection: SettingsSection.phone),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reminder readiness'), findsOneWidget);
    expect(find.text('City'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Basics'));
    await tester.pumpAndSettle();
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Reminder readiness'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

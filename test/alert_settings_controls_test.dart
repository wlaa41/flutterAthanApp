import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/widgets/alert_settings_controls.dart';
import 'package:flutter_pro/screens/settings_screen.dart';
import 'package:flutter_pro/models/alert_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('expanded settings scroll on a small phone with large text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'alert_preferences': jsonEncode(
        const AlertPreferences(
          iqamaEnabled: true,
          iqamaRepeatCount: 5,
          quietEnabled: true,
        ).toJson(),
      ),
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Calculation method'),
      250,
      maxScrolls: 60,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Calculation method'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Reminders'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Time between reminders'),
      250,
      maxScrolls: 60,
    );
    await tester.pumpAndSettle();
    expect(find.text('Time between reminders'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Phone setup'));
    await tester.pumpAndSettle();
    expect(find.text('Reminder readiness'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quiet hours persist from the settings screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Reminders'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Beep on these days'), 300);
    await tester.tap(find.text('Beep on these days'));
    await tester.pumpAndSettle();
    final preferences = await AlertPreferences.load();
    expect(preferences.quietEnabled, isTrue);
    expect(preferences.quietWeekdays, {1, 2, 3, 4, 5});
    expect(preferences.quietStartMinute, 540);
    expect(preferences.quietEndMinute, 1020);
    await tester.scrollUntilVisible(find.text('Fri'), 150);
    await tester.pumpAndSettle();
    final friday = find.widgetWithText(FilterChip, 'Fri');
    expect(tester.widget<FilterChip>(friday).onSelected, isNotNull);
    await tester.tap(friday);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(friday).selected, isFalse);
    expect((await AlertPreferences.load()).quietWeekdays, {1, 2, 3, 4});
    expect(tester.takeException(), isNull);
  });

  testWidgets('quiet weekdays can be changed without mutating the input', (
    tester,
  ) async {
    final original = {1, 2, 3, 4, 5};
    Set<int>? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuietScheduleEditor(
            weekdays: original,
            startMinute: 540,
            endMinute: 1020,
            enabled: true,
            onWeekdaysChanged: (value) => changed = value,
            onStartChanged: (_) {},
            onEndChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mon'));
    expect(changed, {2, 3, 4, 5});
    expect(original, {1, 2, 3, 4, 5});
    await tester.tap(find.text('Sat'));
    expect(changed, {1, 2, 3, 4, 5, 6});
    await tester.tap(find.text('Weekend'));
    expect(changed, {6, 7});
    expect(original, {1, 2, 3, 4, 5});
    await tester.tap(find.text('Every day'));
    expect(changed, {1, 2, 3, 4, 5, 6, 7});
    await tester.tap(find.text('Weekdays'));
    expect(changed, {1, 2, 3, 4, 5});
  });

  testWidgets('quiet time picker allows cancel without changing the schedule', (
    tester,
  ) async {
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuietScheduleEditor(
            weekdays: const {1},
            startMinute: 540,
            endMinute: 1020,
            enabled: true,
            onWeekdaysChanged: (_) {},
            onStartChanged: (_) => changes++,
            onEndChanged: (_) => changes++,
          ),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'From 9:00 AM'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(changes, 0);
  });

  testWidgets('Iqama repeat count reveals spacing and uses a total count', (
    tester,
  ) async {
    var repeatCount = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ReminderTimingEditor(
              delayMinutes: 15,
              repeatCount: repeatCount,
              intervalMinutes: 5,
              enabled: true,
              onDelayChanged: (_) {},
              onIntervalChanged: (_) {},
              onRepeatChanged: (value) => setState(() => repeatCount = value),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Time between reminders'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<int>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 times in total').last);
    await tester.pumpAndSettle();
    expect(repeatCount, 5);
    expect(find.text('Time between reminders'), findsOneWidget);
    expect(
      find.text('5 reminders: first at +15 minutes, then every 5 minutes.'),
      findsOneWidget,
    );
  });

  testWidgets('overnight and full-day schedules explain their meaning', (
    tester,
  ) async {
    Widget build(int end) => MaterialApp(
      home: Scaffold(
        body: QuietScheduleEditor(
          weekdays: const {1},
          startMinute: 1320,
          endMinute: end,
          enabled: true,
          onWeekdaysChanged: (_) {},
          onStartChanged: (_) {},
          onEndChanged: (_) {},
        ),
      ),
    );
    await tester.pumpWidget(build(360));
    expect(
      find.text(
        'Finishes the next morning. Choose the days the hours start on.',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(build(1320));
    expect(find.text('Beeps all day on the chosen days.'), findsOneWidget);
  });

  for (final size in [
    const Size(375, 812),
    const Size(812, 375),
    const Size(1024, 768),
  ]) {
    testWidgets('alert settings fit $size with large text and dark theme', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  QuietScheduleEditor(
                    weekdays: const {1, 2, 3, 4, 5},
                    startMinute: 540,
                    endMinute: 1020,
                    enabled: true,
                    onWeekdaysChanged: (_) {},
                    onStartChanged: (_) {},
                    onEndChanged: (_) {},
                    onAllDayChanged: (_) {},
                  ),
                  const SizedBox(height: 24),
                  ReminderTimingEditor(
                    delayMinutes: 15,
                    repeatCount: 5,
                    intervalMinutes: 5,
                    enabled: true,
                    onDelayChanged: (_) {},
                    onRepeatChanged: (_) {},
                    onIntervalChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -700),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

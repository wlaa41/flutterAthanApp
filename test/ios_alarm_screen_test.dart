import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/models/alert_preferences.dart';
import 'package:flutter_pro/screens/main_navigation_screen.dart';
import 'package:flutter_pro/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support_iphone.dart';

void main() {
  // One walk through the screens, start to finish: the services keep their
  // work in futures, and a future finished in one widget test never answers
  // in the next.
  testWidgets('an iPhone is asked for alarms, tries one, and can stop a '
      'ringing athan in the app', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      'alert_preferences': jsonEncode(
        const AlertPreferences(athanSoundId: 'madinah').toJson(),
      ),
    });
    final phone = FakeIphone(tester.binding.defaultBinaryMessenger)..install();
    addTearDown(phone.remove);
    phone.alarmState = 'notDetermined';

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();
    final ask = find.text('Alarms are not allowed yet');
    await tester.scrollUntilVisible(ask, 150);
    await tester.ensureVisible(ask);
    await tester.pumpAndSettle();
    expect(find.text('Alarm screen'), findsOneWidget);
    // iOS draws the alarm, so the Android-only option is not offered.
    expect(find.text('Easier screen'), findsNothing);
    // Not allowed yet: nothing is armed, and the test button waits.
    expect(phone.armed, isEmpty);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Try the alarm'),
          )
          .onPressed,
      isNull,
    );

    // The iPhone's own question, then the athans are armed.
    await tester.tap(ask);
    await tester.pumpAndSettle();
    expect(
      phone.calls.where((c) => c.method == 'alarmKitRequest'),
      hasLength(1),
    );
    expect(find.text('Alarms are not allowed yet'), findsNothing);
    expect(phone.armed, isNotEmpty);
    expect(phone.armed.values.map((e) => e['sound']).toSet(), {
      'madinah_short.wav',
    });
    expect(
      phone.notified.keys.toSet().intersection(phone.armed.keys.toSet()),
      isEmpty,
    );

    final tryIt = find.text('Try the alarm');
    await tester.ensureVisible(tryIt);
    await tester.pumpAndSettle();
    await tester.tap(tryIt);
    await tester.pumpAndSettle();
    final test =
        phone.calls.lastWhere((c) => c.method == 'alarmKitTest').arguments
            as Map;
    expect(test['sound'], 'madinah_short.wav');
    // At a full minute, like a prayer, with time left to lock the phone.
    final at = DateTime.fromMillisecondsSinceEpoch(test['time'] as int);
    expect(at.second, 0);
    expect(at.millisecond, 0);
    final wait = at.difference(DateTime.now());
    expect(wait, greaterThan(const Duration(seconds: 15)));
    expect(wait, lessThan(const Duration(seconds: 81)));
    expect(test['snoozeMinutes'], 10);
    expect(find.textContaining('Lock the iPhone now'), findsOneWidget);
    expect(
      find.text('${phone.armed.length} athans are ready as alarms.'),
      findsOneWidget,
    );

    // A refusal is shown in the iPhone's own words, to report it.
    phone.testError = 'maximumLimitReached';
    await tester.tap(tryIt);
    await tester.pumpAndSettle();
    expect(
      find.text('The iPhone refused the alarm: maximumLimitReached'),
      findsWidgets,
    );
    phone.testError = '';

    // A longer snooze is armed with the alarms.
    final fifteen = find.widgetWithText(ChoiceChip, '15 min');
    await tester.ensureVisible(fifteen);
    await tester.pumpAndSettle();
    await tester.tap(fifteen);
    await tester.pumpAndSettle();
    expect((await AlertPreferences.load()).snoozeMinutes, 15);
    expect(
      (phone.calls.lastWhere((c) => c.method == 'alarmKitReplace').arguments
          as Map)['snoozeMinutes'],
      15,
    );

    // Off: the alarms come off and the athan is a notification again.
    final toggle = find.text('Ring as an alarm');
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect((await AlertPreferences.load()).ringAsAlarm, isFalse);
    expect(phone.armed, isEmpty);
    expect(phone.notified.values, contains('madinah_short.wav'));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect((await AlertPreferences.load()).ringAsAlarm, isTrue);
    expect(phone.armed, isNotEmpty);

    // A snoozed athan can be taken off from here.
    phone.snoozed = 1;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();
    final cancel = find.text('Cancel snooze');
    await tester.scrollUntilVisible(cancel, 150);
    await tester.ensureVisible(cancel);
    await tester.pumpAndSettle();
    expect(find.text('An athan is snoozed'), findsOneWidget);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(phone.snoozed, 0);
    expect(find.text('An athan is snoozed'), findsNothing);
    expect(tester.takeException(), isNull);

    // The athan is ringing when the app is opened: Stop is right there.
    phone.ringing = [
      {'id': 'A7A40000-0000-4000-8000-0000001FB5ED', 'title': 'Time for Asr'},
    ];
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const MaterialApp(home: MainNavigationScreen()));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Time for Asr'), findsOneWidget);
    expect(find.text('The athan is ringing.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Stop'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      (phone.calls.lastWhere((c) => c.method == 'alarmKitStop').arguments
          as Map)['id'],
      'A7A40000-0000-4000-8000-0000001FB5ED',
    );
    expect(find.text('The athan is ringing.'), findsNothing);

    // Ringing again when the app comes back to the front: Snooze this time.
    phone.ringing = [
      {'id': 'A7A40000-0000-4000-8000-0000001FB5EE', 'title': 'Asr Iqama'},
    ];
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Asr Iqama'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Snooze'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      phone.calls.where((c) => c.method == 'alarmKitSnooze'),
      hasLength(1),
    );
    expect(phone.snoozed, 1);
    expect(find.text('The athan is ringing.'), findsNothing);

    // Before iOS 26: Settings says why there is no alarm screen.
    phone.alarmsSupported = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();
    final note = find.textContaining('This iPhone runs an older iOS');
    await tester.scrollUntilVisible(note, 150);
    expect(note, findsOneWidget);
    expect(find.text('Ring as an alarm'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

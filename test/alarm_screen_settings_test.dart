import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/models/alert_preferences.dart';
import 'package:flutter_pro/screens/settings_screen.dart';
import 'package:flutter_pro/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Easier screen and snooze length are saved with the other choices', () {
    const defaults = AlertPreferences();
    expect(defaults.easierScreen, isFalse);
    expect(defaults.snoozeMinutes, 10);
    final chosen = defaults.copyWith(easierScreen: true, snoozeMinutes: 15);
    final back = AlertPreferences.fromJson(
      jsonDecode(jsonEncode(chosen.toJson())) as Map<String, dynamic>,
    );
    expect(back.easierScreen, isTrue);
    expect(back.snoozeMinutes, 15);
    expect(defaults.copyWith(snoozeMinutes: 0).snoozeMinutes, 1);
    expect(defaults.copyWith(snoozeMinutes: 500).snoozeMinutes, 60);
    // Saved before this setting existed: the defaults apply.
    expect(AlertPreferences.fromJson({'beepPower': 3}).snoozeMinutes, 10);
    expect(jsonDecode(NotificationService.alarmScreenJson(chosen)), {
      'easierScreen': true,
      'snoozeMinutes': 15,
    });
  });

  test('the phone reports the alarm screen and a waiting snooze', () {
    final at = DateTime(2026, 11, 25, 5, 40);
    final health = NotificationService.healthFromNative({
      'exact': true,
      'count': 3,
      'fullScreen': false,
      'snoozedUntil': at.millisecondsSinceEpoch,
    }, notificationsEnabled: true);
    expect(health.fullScreenAllowed, isFalse);
    expect(health.snoozedUntil, at);
    // An athan still plays without it, so it is not a problem to fix first.
    expect(health.problems, isEmpty);
    final older = NotificationService.healthFromNative({
      'exact': true,
      'count': 3,
    }, notificationsEnabled: true);
    expect(older.fullScreenAllowed, isTrue);
    expect(older.snoozedUntil, isNull);
  });

  testWidgets('Settings sends Easier screen and the snooze to the phone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const notifications = MethodChannel(
      'dexterous.com/flutter/local_notifications',
    );
    const alarms = MethodChannel('athan/alarms');
    messenger.setMockMethodCallHandler(notifications, (call) async {
      if (call.method == 'initialize' ||
          call.method == 'areNotificationsEnabled')
        return true;
      return null;
    });
    messenger.setMockMethodCallHandler(alarms, (call) async {
      calls.add(call);
      if (call.method == 'health')
        return {
          'exact': true,
          'batteryOptimized': false,
          'count': 10,
          'ringer': 'normal',
          'fullScreen': false,
        };
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(notifications, null);
      messenger.setMockMethodCallHandler(alarms, null);
    });
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    final easier = find.text('Easier screen');
    await tester.scrollUntilVisible(easier, 150);
    await tester.ensureVisible(easier);
    await tester.pumpAndSettle();
    expect(find.text('Alarm screen'), findsOneWidget);
    expect(find.text('Full-screen alarm is off'), findsOneWidget);
    await tester.tap(easier);
    await tester.pumpAndSettle();
    expect((await AlertPreferences.load()).easierScreen, isTrue);
    Map<String, dynamic> lastSent() =>
        jsonDecode(
              calls.lastWhere((c) => c.method == 'alarmScreen').arguments
                  as String,
            )
            as Map<String, dynamic>;
    expect(lastSent(), {'easierScreen': true, 'snoozeMinutes': 10});

    final fifteen = find.widgetWithText(ChoiceChip, '15 min');
    await tester.ensureVisible(fifteen);
    await tester.pumpAndSettle();
    await tester.tap(fifteen);
    await tester.pumpAndSettle();
    expect((await AlertPreferences.load()).snoozeMinutes, 15);
    expect(lastSent(), {'easierScreen': true, 'snoozeMinutes': 15});

    // Opens the phone's page where full-screen alerts are allowed.
    await tester.tap(find.text('Full-screen alarm is off'));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'fullScreenSettings'), hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

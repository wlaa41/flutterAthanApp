import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/screens/settings_screen.dart';
import 'package:flutter_pro/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('phone health is read field by field', () {
    final next = DateTime(2026, 11, 21, 12, 30);
    final health = NotificationService.healthFromNative({
      'exact': true,
      'batteryOptimized': true,
      'count': 4,
      'until': next.add(const Duration(days: 1)).millisecondsSinceEpoch,
      'nextTime': next.millisecondsSinceEpoch,
      'nextTitle': 'Dhuhr',
      'ringer': 'vibrate',
      'dnd': false,
    }, notificationsEnabled: false);
    expect(health.nextTime, next);
    expect(health.nextTitle, 'Dhuhr');
    expect(health.ringer, RingerMode.vibrate);
    expect(health.canPlayAloud, isFalse);
    expect(health.problems, [
      'Battery saving can delay or block the Athan.',
      'Notifications are off, so reminders cannot show on screen.',
    ]);
  });

  test('missing on-time alarms is reported first', () {
    final health = NotificationService.healthFromNative({
      'exact': false,
      'count': 0,
    }, notificationsEnabled: true);
    expect(health.ringer, RingerMode.normal);
    expect(health.problems.first, contains('On-time alarms are off'));
    expect(health.problems, contains('No Athan is scheduled.'));
  });

  test('a ready phone has nothing to fix', () {
    final health = NotificationService.healthFromNative({
      'exact': true,
      'batteryOptimized': false,
      'count': 300,
      'ringer': 'normal',
    }, notificationsEnabled: true);
    expect(health.problems, isEmpty);
    expect(health.canPlayAloud, isTrue);
  });

  testWidgets('Test in 1 minute goes through the real alarm', (tester) async {
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
          'ringer': 'silent',
        };
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(notifications, null);
      messenger.setMockMethodCallHandler(alarms, null);
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScreen(initialSection: SettingsSection.phone),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('It vibrates at prayer time', findRichText: true),
      findsOneWidget,
    );
    final button = find.text('Test in 1 minute');
    await tester.scrollUntilVisible(button, 150);
    final before = DateTime.now();
    await tester.tap(button);
    await tester.pumpAndSettle();
    final sent = calls.where((c) => c.method == 'testSoon').single;
    final event = jsonDecode(sent.arguments as String) as Map<String, dynamic>;
    expect(event['id'], 998);
    final at = DateTime.fromMillisecondsSinceEpoch(event['time'] as int);
    expect(
      at.difference(before).inSeconds,
      inInclusiveRange(55, 65),
      reason: 'Long enough to lock the phone',
    );
    expect(find.textContaining('Lock the phone now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/models/alert_preferences.dart';
import 'package:flutter_pro/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support_iphone.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Its own file, so the service starts as it does when the app is launched.
  test(
    'two launches that end while arming alarms pause the alarm screen',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({
        'alert_preferences': jsonEncode(
          const AlertPreferences(athanSoundId: 'madinah').toJson(),
        ),
        // The launch before last ended inside arming, and so did the last one.
        'ios_alarm_crashes': 1,
        'ios_alarm_arming': true,
      });
      final phone = FakeIphone(
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger,
      )..install();
      addTearDown(phone.remove);
      final service = NotificationService.instance;

      await service.refreshSchedule();
      // The app leaves the iPhone's alarms alone and still delivers every athan.
      expect(phone.calls.where((c) => c.method == 'alarmKitReplace'), isEmpty);
      expect(phone.armed, isEmpty);
      expect(phone.notified.values, contains('madinah_short.wav'));
      final paused = (await service.getHealth()).alarm;
      expect(paused.allowed, isTrue);
      expect(paused.paused, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('ios_alarm_crashes'), 2);
      expect(prefs.containsKey('ios_alarm_arming'), isFalse);

      // "Try again" in Settings: arming works, and the count starts over.
      await service.resumeIosAlarms();
      expect(phone.armed, isNotEmpty);
      expect(
        phone.notified.keys.toSet().intersection(phone.armed.keys.toSet()),
        isEmpty,
      );
      expect((await service.getHealth()).alarm.paused, isFalse);
      expect(prefs.containsKey('ios_alarm_crashes'), isFalse);
      expect(prefs.containsKey('ios_alarm_arming'), isFalse);

      // One launch that ended there is not enough to pause: it may have been
      // closed by hand. The mark is only read once per launch, so set the count.
      await prefs.setInt('ios_alarm_crashes', 1);
      expect((await service.getHealth()).alarm.paused, isFalse);
    },
  );
}

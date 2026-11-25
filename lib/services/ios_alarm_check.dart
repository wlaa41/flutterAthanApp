import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'notification_service.dart';

/// A check of the iPhone alarm that needs nobody at the screen. It is only
/// built in with `--dart-define=ATHAN_ALARM_CHECK=true`, which
/// `tools/ios_alarm_check.sh` does for a simulator run; every other build
/// drops it.
///
/// Once the first-run questions are answered it sets test alarms, as
/// "Try the alarm" does, and logs what the iPhone reports every two seconds:
/// waiting, ringing, snoozed, gone. The UI test that drives the run names the
/// times in `ATHAN_ALARM_CHECK_AT` (milliseconds, comma separated), so it
/// knows when to look. Without the times, one alarm rings at the usual test
/// time. The prayers stay armed, so one that falls inside a run rings too.
class IosAlarmCheck {
  static const enabled = bool.fromEnvironment('ATHAN_ALARM_CHECK');
  static const _phone = MethodChannel('athan/alarms');
  static bool _started = false;

  static Future<void> run() async {
    if (!enabled || _started) return;
    _started = true;
    final service = NotificationService.instance;
    try {
      _log('ready: ${_describe(await service.iosAlarmStatus())}');
      // Dart has no process environment on iOS; the app delegate reads it.
      final times = timesFrom(await _phone.invokeMethod<String>('checkTimes'));
      if (times.isEmpty) {
        final at = await service.testIosAlarm();
        _log('test alarm 1 set for ${at.toIso8601String()}');
      }
      for (var i = 0; i < times.length; i++) {
        final left = times[i].difference(DateTime.now()).inSeconds;
        if (left < 5) {
          _log('test alarm ${i + 1} is too late: ${left}s left');
          continue;
        }
        final at = await service.testIosAlarm(time: times[i]);
        _log('test alarm ${i + 1} set for ${at.toIso8601String()}');
      }
      for (var i = 0; i < 450; i++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        _log(_describe(await service.iosAlarmStatus()));
      }
    } catch (error) {
      _log('failed: $error');
    }
  }

  /// The times in a comma separated list of milliseconds. Public for tests.
  static List<DateTime> timesFrom(String? text) => [
        for (final part in (text ?? '').split(','))
          if (int.tryParse(part.trim()) case final ms?)
            DateTime.fromMillisecondsSinceEpoch(ms),
      ];

  static void _log(String line) => debugPrint('ALARM_CHECK $line');

  static String _describe(IosAlarmStatus status) =>
      'state=${status.state} waiting=${status.scheduled} '
      'snoozed=${status.snoozed} '
      'ringing=${status.ringing.map((alarm) => alarm.title).toList()} '
      'error=${status.error} paused=${status.paused}';
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The iPhone side of both channels, as the app sees it: Apple's alarms on
/// "athan/alarms" and the notification plugin beside it.
class FakeIphone {
  FakeIphone(this.tester);
  final TestDefaultBinaryMessenger tester;

  /// iOS 26 or later.
  bool alarmsSupported = true;
  String alarmState = 'authorized';
  bool notificationsAllowed = true;

  /// How many alarms this iPhone accepts before it refuses the next one.
  int alarmCap = 1000;

  /// What the iPhone answers to "Try the alarm"; empty when it arms it.
  String testError = '';
  List<Map<String, dynamic>> ringing = [];
  int snoozed = 0;

  final armed = <int, Map<Object?, Object?>>{};
  final notified = <int, String?>{};
  final calls = <MethodCall>[];

  static const _alarms = MethodChannel('athan/alarms');
  static const _notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  Map<String, dynamic> _status() => alarmsSupported
      ? {
          'supported': true,
          'state': alarmState,
          'scheduled': armed.length,
          'snoozed': snoozed,
          'ringing': ringing,
        }
      : {'supported': false, 'state': 'unsupported'};

  void install() {
    tester.setMockMethodCallHandler(_alarms, (call) async {
      calls.add(call);
      final arguments = call.arguments as Map? ?? const {};
      switch (call.method) {
        case 'appSettings':
          return null;
        case 'alarmKitRequest':
          if (alarmsSupported) alarmState = 'authorized';
        case 'alarmKitReplace':
          if (!alarmsSupported) return _status();
          final events = (arguments['events'] as List).cast<Map>();
          final keep = events.map((e) => e['id'] as int).toSet();
          armed.removeWhere((id, _) => !keep.contains(id));
          var error = '';
          for (final event in events) {
            if (armed.length >= alarmCap && !armed.containsKey(event['id'])) {
              error = 'maximumLimitReached';
              break;
            }
            armed[event['id'] as int] = event;
          }
          final accepted = <int>[];
          for (final event in events) {
            if (!armed.containsKey(event['id'])) break;
            accepted.add(event['id'] as int);
          }
          return {..._status(), 'armed': accepted, 'error': error};
        case 'alarmKitStop':
          ringing = [
            for (final alarm in ringing)
              if (alarm['id'] != arguments['id']) alarm,
          ];
        case 'alarmKitSnooze':
          ringing = [
            for (final alarm in ringing)
              if (alarm['id'] != arguments['id']) alarm,
          ];
          snoozed++;
        case 'alarmKitCancelSnooze':
          snoozed = 0;
        case 'alarmKitCancelAll':
          armed.clear();
          snoozed = 0;
        case 'alarmKitTest':
          return {..._status(), 'error': testError};
      }
      return _status();
    });
    tester.setMockMethodCallHandler(_notifications, (call) async {
      switch (call.method) {
        case 'initialize':
          return true;
        case 'checkPermissions':
          return {
            'isEnabled': notificationsAllowed,
            'isAlertEnabled': notificationsAllowed,
            'isSoundEnabled': notificationsAllowed,
          };
        case 'requestPermissions':
          return notificationsAllowed;
        case 'pendingNotificationRequests':
          return [
            for (final id in notified.keys)
              {'id': id, 'title': 'Prayer', 'body': '', 'payload': ''},
          ];
        case 'zonedSchedule':
          final arguments = call.arguments as Map;
          final specifics = arguments['platformSpecifics'] as Map?;
          notified[arguments['id'] as int] = specifics?['sound'] as String?;
        case 'cancel':
          notified.remove(call.arguments);
        case 'cancelAll':
          notified.clear();
      }
      return null;
    });
  }

  void remove() {
    tester.setMockMethodCallHandler(_alarms, null);
    tester.setMockMethodCallHandler(_notifications, null);
  }

  List<Map<Object?, Object?>> lastReplace() =>
      ((calls.lastWhere((call) => call.method == 'alarmKitReplace').arguments
                  as Map)['events']
              as List)
          .cast<Map<Object?, Object?>>();
}

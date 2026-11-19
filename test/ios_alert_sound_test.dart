import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_pro/services/notification_service.dart';
import 'package:flutter_pro/services/sound_library.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  final plugin = IOSFlutterLocalNotificationsPlugin();

  setUp(() {
    calls.clear();
    tzdata.initializeTimeZones();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final id in ['silent', 'vibrate']) {
    test(
      '$id sends no iOS background sound for scheduled and test alerts',
      () async {
        final details = NotificationService.iosDetailsFor(
          SoundCatalog.byId(id),
        );
        await plugin.show(
          1,
          'Prayer',
          'Reminder',
          notificationDetails: details,
        );
        await plugin.zonedSchedule(
          2,
          'Prayer',
          'Reminder',
          tz.TZDateTime.now(tz.UTC).add(const Duration(hours: 1)),
          details,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        expect(calls.map((call) => call.method), ['show', 'zonedSchedule']);
        for (final call in calls) {
          final specifics = (call.arguments as Map)['platformSpecifics'] as Map;
          // presentSound alone only suppresses foreground presentation. The
          // native notification content must not receive a sound filename.
          expect(specifics['presentSound'], isFalse);
          expect(specifics['sound'], isNull);
          expect(specifics['presentAlert'], isTrue);
        }
      },
    );
  }

  for (final entry in {
    'beep': 'beep.wav',
    'iqama': 'iqama_short.wav',
  }.entries) {
    test('${entry.key} retains its supported iOS sound', () async {
      await plugin.show(
        1,
        'Prayer',
        'Reminder',
        notificationDetails: NotificationService.iosDetailsFor(
          SoundCatalog.byId(entry.key),
        ),
      );
      final specifics =
          (calls.single.arguments as Map)['platformSpecifics'] as Map;
      expect(specifics['presentSound'], isTrue);
      expect(specifics['sound'], entry.value);
    });
  }

  test(
    'Unsupported full imported recording retains short audible fallback',
    () async {
      const custom = SoundOption(
        id: 'custom_1',
        name: 'My Athan',
        description: 'Imported',
        kind: SoundKind.custom,
        filePath: '/audio.mp3',
      );
      await plugin.show(
        1,
        'Prayer',
        'Reminder',
        notificationDetails: NotificationService.iosDetailsFor(custom),
      );
      final specifics =
          (calls.single.arguments as Map)['platformSpecifics'] as Map;
      expect(specifics['sound'], 'beep.wav');
      expect(specifics['presentSound'], isTrue);
    },
  );
}

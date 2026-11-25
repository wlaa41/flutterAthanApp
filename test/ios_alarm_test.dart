import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/models/alert_preferences.dart';
import 'package:flutter_pro/services/alert_planner.dart';
import 'package:flutter_pro/services/ios_alarm_check.dart';
import 'package:flutter_pro/services/notification_service.dart';
import 'package:flutter_pro/services/sound_library.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support_iphone.dart';

PlannedAlert _alert(int id, String soundId, {bool iqama = false}) =>
    PlannedAlert(
      id: id,
      time: DateTime(2026, 11, 26, 5).add(Duration(minutes: id)),
      title: iqama ? 'Fajr Iqama' : 'Time for Fajr',
      body: '',
      soundId: soundId,
      iqama: iqama,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Ring as an alarm is on by default and saved with the other choices',
    () {
      const defaults = AlertPreferences();
      expect(defaults.ringAsAlarm, isTrue);
      final off = AlertPreferences.fromJson(
        jsonDecode(jsonEncode(defaults.copyWith(ringAsAlarm: false).toJson()))
            as Map<String, dynamic>,
      );
      expect(off.ringAsAlarm, isFalse);
      // Saved before this setting existed: the athan rings as an alarm.
      expect(
        AlertPreferences.fromJson({'snoozeMinutes': 5}).ringAsAlarm,
        isTrue,
      );
    },
  );

  test('recordings ring as alarms; quiet reminders stay notifications', () {
    for (final id in ['smooth', 'madinah', 'qassas_clear', 'iqama']) {
      expect(
        NotificationService.ringsAsAlarm(SoundCatalog.byId(id)),
        isTrue,
        reason: id,
      );
    }
    for (final id in ['beep', 'chime', 'strong_beep', 'vibrate', 'silent']) {
      expect(
        NotificationService.ringsAsAlarm(SoundCatalog.byId(id)),
        isFalse,
        reason: id,
      );
    }
    const added = SoundOption(
      id: 'added_athan',
      name: 'Added athan',
      description: 'No iPhone excerpt',
      kind: SoundKind.athan,
      filePath: '/tmp/added.mp3',
    );
    SoundOption sound(String id) =>
        id == added.id ? added : SoundCatalog.byId(id);
    final events = NotificationService.iosAlarmEvents(
      [
        _alert(1, 'madinah'),
        _alert(2, 'beep'),
        _alert(3, 'iqama', iqama: true),
        _alert(4, 'silent'),
        _alert(5, 'added_athan'),
        _alert(6, 'smooth'),
      ],
      sound,
      limit: 3,
    );
    // The soonest three recordings, in order, each with its iPhone excerpt.
    expect(events.map((e) => e['id']), [1, 3, 5]);
    expect(events.map((e) => e['sound']), [
      'madinah_short.wav',
      'iqama_short.wav',
      // No excerpt: the iPhone's own alarm sound.
      '',
    ]);
    expect(events.first['title'], 'Time for Fajr');
    expect(
      events.first['time'],
      DateTime(2026, 11, 26, 5, 1).millisecondsSinceEpoch,
    );
  });

  test('a test alarm rings at a full minute, at least 20 seconds away', () {
    DateTime at(int minute, int second) => NotificationService.iosAlarmTestTime(
      DateTime(2026, 11, 25, 15, minute, second),
    );
    expect(at(41, 0), DateTime(2026, 11, 25, 15, 42));
    expect(at(41, 39), DateTime(2026, 11, 25, 15, 42));
    // Exactly 20 seconds before the minute is still time enough.
    expect(at(41, 40), DateTime(2026, 11, 25, 15, 42));
    expect(at(41, 41), DateTime(2026, 11, 25, 15, 43));
    expect(at(59, 59), DateTime(2026, 11, 25, 16, 1));
  });

  test('the simulator check is off in a normal build and reads its times', () {
    expect(IosAlarmCheck.enabled, isFalse);
    expect(IosAlarmCheck.timesFrom(null), isEmpty);
    expect(IosAlarmCheck.timesFrom(''), isEmpty);
    expect(IosAlarmCheck.timesFrom('1795712460000, 1795712700000,soon'), [
      DateTime.fromMillisecondsSinceEpoch(1795712460000),
      DateTime.fromMillisecondsSinceEpoch(1795712700000),
    ]);
  });

  test('the phone reports what is armed, snoozed and ringing', () {
    final status = IosAlarmStatus.fromNative({
      'supported': true,
      'state': 'authorized',
      'scheduled': 7,
      'snoozed': 1,
      'ringing': [
        {'id': 'A7A40000-0000-4000-8000-0000001FB5ED', 'title': 'Time for Asr'},
        {'id': 'A7A47E57-0000-4000-8000-000000000001', 'title': ''},
      ],
      'armed': [20781610, 20781630],
      'error': 'maximumLimitReached',
    });
    expect(status.allowed, isTrue);
    expect(status.scheduled, 7);
    expect(status.snoozed, 1);
    expect(status.ringing.map((r) => r.title), ['Time for Asr', 'Athan']);
    expect(status.armed, [20781610, 20781630]);
    expect(status.error, 'maximumLimitReached');
    // Before iOS 26, and anywhere that is not an iPhone.
    for (final none in [
      IosAlarmStatus.fromNative(null),
      IosAlarmStatus.fromNative({'supported': false}),
    ]) {
      expect(none.supported, isFalse);
      expect(none.allowed, isFalse);
      expect(none.undecided, isFalse);
    }
    final denied = IosAlarmStatus.fromNative({
      'supported': true,
      'state': 'denied',
    });
    expect(denied.denied, isTrue);
    expect(denied.allowed, isFalse);
  });

  test('every iPhone excerpt is in the app bundle, where alarms read it', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final excerpts = [
      for (final sound in SoundCatalog.builtIns)
        if (NotificationService.ringsAsAlarm(sound)) sound.iosSound,
    ];
    // Each recording has an excerpt, the Classic Athan included.
    expect(excerpts, everyElement(endsWith('_short.wav')));
    expect(SoundCatalog.byId('smooth').iosSound, 'smooth_short.wav');
    for (final name in excerpts) {
      expect(project, contains('$name in Resources'), reason: name!);
      expect(File('asset/$name').existsSync(), isTrue, reason: name);
    }
    // The extension that draws the alarm is built into the app.
    expect(
      project,
      contains('AthanAlarm.appex in Embed Foundation Extensions'),
    );
    final embed = project.indexOf('/* Embed Foundation Extensions */,');
    final thin = project.indexOf('/* Thin Binary */,');
    expect(embed, greaterThan(0));
    // Later than Flutter's Thin Binary script, Xcode reports a build cycle.
    expect(embed, lessThan(thin));
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('NSAlarmKitUsageDescription'));
  });

  group('On an iPhone', () {
    late FakeIphone phone;

    setUp(() async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      SharedPreferences.setMockInitialValues({
        // A recitation for the athan, and an Iqama after it.
        'alert_preferences': jsonEncode(
          const AlertPreferences(
            athanSoundId: 'madinah',
            iqamaEnabled: true,
          ).toJson(),
        ),
      });
      phone = FakeIphone(
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger,
      )..install();
      // Start every test from a phone with nothing scheduled.
      await NotificationService.instance.cancelAll();
      phone.calls.clear();
    });

    tearDown(() {
      phone.remove();
      debugDefaultTargetPlatformOverride = null;
    });

    test('athans are armed as alarms and are not notified twice', () async {
      await NotificationService.instance.refreshSchedule();
      final events = phone.lastReplace();
      expect(events, isNotEmpty);
      expect(
        events.length,
        lessThanOrEqualTo(NotificationService.iosAlarmLimit),
      );
      expect(events.map((e) => e['sound']).toSet(), {
        'madinah_short.wav',
        'iqama_short.wav',
      });
      expect(phone.armed.keys.toSet(), events.map((e) => e['id']).toSet());
      // Soonest first, so the next prayers are the ones that ring as alarms.
      final times = events.map((e) => e['time'] as int).toList();
      expect(times, [...times]..sort());
      // The reminders after them wait as notifications; none is in both.
      expect(phone.notified, isNotEmpty);
      expect(
        phone.notified.keys.toSet().intersection(phone.armed.keys.toSet()),
        isEmpty,
      );
      final health = await NotificationService.instance.getHealth();
      expect(health.alarm.allowed, isTrue);
      expect(health.scheduledCount, phone.armed.length + phone.notified.length);
      expect(health.problems, isEmpty);

      // Opening the app again changes nothing on the phone.
      phone.calls.clear();
      await NotificationService.instance.refreshSchedule();
      expect(phone.calls.where((c) => c.method == 'alarmKitReplace'), isEmpty);
    });

    test('what the iPhone will not arm arrives as a notification', () async {
      phone.alarmCap = 3;
      await NotificationService.instance.refreshSchedule();
      expect(phone.armed, hasLength(3));
      final wanted = phone.lastReplace().map((e) => e['id'] as int).toSet();
      expect(wanted.length, greaterThan(3));
      // Every reminder the phone refused is still delivered.
      expect(
        phone.notified.keys.toSet(),
        containsAll(wanted.difference(phone.armed.keys.toSet())),
      );
      expect(
        phone.notified.keys.toSet().intersection(phone.armed.keys.toSet()),
        isEmpty,
      );
    });

    test('before iOS 26 every reminder is a notification, as before', () async {
      phone.alarmsSupported = false;
      await NotificationService.instance.refreshSchedule();
      expect(phone.calls.where((c) => c.method == 'alarmKitReplace'), isEmpty);
      expect(phone.armed, isEmpty);
      expect(phone.notified, isNotEmpty);
      expect(phone.notified.values, contains('madinah_short.wav'));
    });

    test(
      'with the alarm screen off, armed alarms are taken off again',
      () async {
        await NotificationService.instance.refreshSchedule();
        expect(phone.armed, isNotEmpty);
        await (await AlertPreferences.load())
            .copyWith(ringAsAlarm: false)
            .save();
        await NotificationService.instance.refreshSchedule();
        expect(phone.lastReplace(), isEmpty);
        expect(phone.armed, isEmpty);
        expect(phone.notified.values, contains('madinah_short.wav'));
      },
    );

    test('alarms still ring when notifications are turned off', () async {
      phone.notificationsAllowed = false;
      await NotificationService.instance.refreshSchedule();
      expect(phone.armed, isNotEmpty);
      expect(phone.notified, isEmpty);
      final health = await NotificationService.instance.getHealth();
      expect(health.scheduledCount, phone.armed.length);

      // Neither allowed: nothing can reach the person, so nothing is left armed.
      phone.alarmState = 'denied';
      await NotificationService.instance.refreshSchedule();
      expect(phone.armed, isEmpty);
      expect(phone.notified, isEmpty);
    });

    test('a quiet beep is never an alarm', () async {
      await (await AlertPreferences.load())
          .copyWith(athanSoundId: 'beep', iqamaEnabled: false)
          .save();
      await NotificationService.instance.refreshSchedule();
      expect(phone.armed, isEmpty);
      expect(phone.notified.values.toSet(), {'beep.wav'});
    });

    test('a test alarm rings with the chosen athan, at the time asked', () async {
      final time = DateTime(2031, 3, 4, 5, 6, 30);
      expect(await NotificationService.instance.testIosAlarm(time: time), time);
      final sent = phone.calls.singleWhere((c) => c.method == 'alarmKitTest');
      expect(sent.arguments, {
        'time': time.millisecondsSinceEpoch,
        'title': 'Test athan',
        'sound': 'madinah_short.wav',
        'snoozeMinutes': const AlertPreferences().snoozeMinutes,
      });

      phone.testError = 'maximumLimitReached';
      await expectLater(
        NotificationService.instance.testIosAlarm(),
        throwsA(isA<IosAlarmRefused>()),
      );
    });

    test('the app asks for alarms once, also after an update', () async {
      phone.alarmState = 'notDetermined';
      // An install that finished its first-run questions in an older version.
      (await SharedPreferences.getInstance()).setBool(
        'reminder_setup_asked_v1',
        true,
      );
      await NotificationService.instance.firstRunSetup();
      expect(
        phone.calls.where((c) => c.method == 'alarmKitRequest'),
        hasLength(1),
      );
      phone.alarmState = 'denied';
      phone.calls.clear();
      await NotificationService.instance.firstRunSetup();
      expect(phone.calls.where((c) => c.method == 'alarmKitRequest'), isEmpty);
    });
  });
}

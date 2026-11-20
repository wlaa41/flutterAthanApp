import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/models/alert_preferences.dart';
import 'package:flutter_pro/models/prayer_time_model.dart';
import 'package:flutter_pro/services/alert_planner.dart';
import 'package:flutter_pro/services/beep_mode.dart';
import 'package:flutter_pro/services/sound_library.dart';
import 'package:flutter_pro/widgets/beep_mode_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

PrayerTimeModel _day(int date) => PrayerTimeModel(
  date: DateTime(2026, 11, date),
  fajr: '06:00',
  sunrise: '07:30',
  dhuhr: '12:00',
  asr: '14:00',
  maghrib: '16:10',
  isha: '18:00',
  timeZoneName: 'Europe/London',
);

/// Root-mean-square level of a 16-bit mono WAV, in dBFS.
double _loudness(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes, 44);
  var sum = 0.0;
  final samples = data.lengthInBytes ~/ 2;
  for (var i = 0; i < samples; i++) {
    final value = data.getInt16(i * 2, Endian.little) / 32768;
    sum += value * value;
  }
  return 10 * math.log(sum / samples) / math.ln10;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Beep mode window', () {
    final days = [_day(20), _day(21), _day(22)];

    test('next prayer covers that prayer and its Iqama, then hands back', () {
      final now = DateTime.utc(2026, 11, 20, 11, 30); // before Dhuhr
      final until = BeepMode.untilFor(
        BeepSpan.nextPrayer,
        now: now,
        days: days,
      );
      expect(until.toUtc(), DateTime.utc(2026, 11, 20, 14)); // Asr begins
      final plan = planAlerts(
        days: days,
        preferences: const AlertPreferences(iqamaEnabled: true),
        enabledPrayers: {1, 3, 4, 5, 6},
        now: now,
        quietUntil: until,
      );
      final today = plan
          .where((a) => a.time.isBefore(DateTime.utc(2026, 11, 21)))
          .toList();
      final dhuhr = today.where((a) => a.title.contains('Dhuhr')).toList();
      expect(dhuhr, hasLength(2)); // the Athan and its Iqama reminder
      expect(dhuhr.every((a) => a.soundId == 'beep'), isTrue);
      expect(
        today.where((a) => !a.title.contains('Dhuhr')).map((a) => a.soundId),
        everyElement(isNot('beep')),
      );
      expect(
        today.firstWhere((a) => a.title == 'Time for Asr').soundId,
        'smooth',
      );
    });

    test('after Isha the next prayer is tomorrow Fajr', () {
      final until = BeepMode.untilFor(
        BeepSpan.nextPrayer,
        now: DateTime.utc(2026, 11, 20, 19),
        days: days,
      );
      expect(until.toUtc(), DateTime.utc(2026, 11, 21, 12)); // Dhuhr tomorrow
    });

    test('today ends at midnight, or the next one when nothing is left', () {
      final midday = DateTime(2026, 11, 20, 11, 30);
      expect(
        BeepMode.untilFor(BeepSpan.today, now: midday, days: days),
        DateTime(2026, 11, 21),
      );
      final late = DateTime(2026, 11, 20, 23, 30);
      final first = days
          .expand((d) => [1, 3, 4, 5, 6].map(d.getPrayerDateTime))
          .where((t) => t.isAfter(late))
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final expected = first.isBefore(DateTime(2026, 11, 21))
          ? DateTime(2026, 11, 21)
          : DateTime(2026, 11, 22);
      expect(
        BeepMode.untilFor(BeepSpan.today, now: late, days: days),
        expected,
      );
    });

    test(
      'until I turn it off never expires and keeps every reminder quiet',
      () {
        final until = BeepMode.untilFor(
          BeepSpan.untilOff,
          now: DateTime.utc(2026, 11, 20),
          days: const [],
        );
        expect(BeepModeState(until).untilTurnedOff, isTrue);
        final plan = planAlerts(
          days: days,
          preferences: const AlertPreferences(quietSoundId: 'strong_beep'),
          enabledPrayers: {1, 3, 4, 5, 6},
          now: DateTime.utc(2026, 11, 20),
          quietUntil: until,
        );
        expect(plan, isNotEmpty);
        expect(plan.every((a) => a.soundId == 'strong_beep'), isTrue);
      },
    );

    test('without Beep mode the plan is unchanged', () {
      final plan = planAlerts(
        days: days,
        preferences: const AlertPreferences(),
        enabledPrayers: {1, 3, 4, 5, 6},
        now: DateTime.utc(2026, 11, 20),
      );
      expect(plan.every((a) => a.soundId == 'smooth'), isTrue);
    });
  });

  group('Saved switch', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.linux);
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('turning on, reloading and turning off', () async {
      final until = DateTime.now().add(const Duration(hours: 2));
      await BeepMode.instance.turnOn(until);
      expect((await BeepMode.instance.load()).activeAt(DateTime.now()), isTrue);
      await BeepMode.instance.turnOff();
      expect((await BeepMode.instance.load()).until, isNull);
    });

    test('an expired switch reads as off and is cleared', () async {
      SharedPreferences.setMockInitialValues({
        'beep_mode_until': DateTime.now()
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
      });
      expect((await BeepMode.instance.load()).until, isNull);
      expect(
        (await SharedPreferences.getInstance()).containsKey('beep_mode_until'),
        isFalse,
      );
    });
  });

  test('on Android the phone keeps the switch and its copy wins', () async {
    const channel = MethodChannel('athan/alarms');
    final calls = <MethodCall>[];
    var stored = DateTime.now()
        .add(const Duration(hours: 1))
        .millisecondsSinceEpoch;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'getBeepMode') return stored;
          if (call.method == 'setBeepMode') stored = call.arguments as int;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    // Nothing saved in the app, but the quick settings tile switched it on.
    expect((await BeepMode.instance.load()).activeAt(DateTime.now()), isTrue);
    await BeepMode.instance.turnOff();
    expect(calls.last.method, 'setBeepMode');
    expect(calls.last.arguments, 0);
    expect((await BeepMode.instance.load()).until, isNull);
  });

  group('Beep power', () {
    test('settings round-trip and stay within one to five', () {
      final saved = AlertPreferences.fromJson(
        jsonDecode(
              jsonEncode(
                const AlertPreferences().copyWith(
                  beepPower: 9,
                  beepVibrate: true,
                  beepAlarmVolume: true,
                ),
              ),
            )
            as Map<String, dynamic>,
      );
      expect(saved.beepPower, 5);
      expect(saved.beepVibrate, isTrue);
      expect(saved.beepAlarmVolume, isTrue);
      // Settings saved by an earlier version keep working.
      expect(AlertPreferences.fromJson(const {}).beepPower, 4);
    });

    test('each tone ships at five levels for the app, Android and iPhone', () {
      final tones = SoundCatalog.builtIns.where((s) => s.hasPowerLevels);
      expect(tones.map((s) => s.id), [
        'beep',
        'double_beep',
        'chime',
        'strong_beep',
      ]);
      for (final tone in tones) {
        double? previous;
        for (var power = 1; power <= 5; power++) {
          final sound = tone.atPower(power);
          final file = File(sound.assetPath!);
          expect(file.existsSync(), isTrue, reason: sound.assetPath);
          expect(SoundLibrary.isPcmWave(file.readAsBytesSync()), isTrue);
          expect(sound.iosSound, '${sound.androidResource}.wav');
          final raw = File(
            'android/app/src/main/res/raw/${sound.androidResource}.wav',
          );
          expect(raw.readAsBytesSync(), file.readAsBytesSync());
          final level = _loudness(file.path);
          if (previous != null) {
            expect(level, greaterThan(previous + 2), reason: sound.assetPath);
          }
          previous = level;
        }
        expect(tone.atPower(4).assetPath, tone.assetPath);
      }
      // The default beep is far louder than the old -21 dBFS one.
      expect(_loudness('asset/beep.wav'), greaterThan(-9));
    });

    test('recordings and silent choices ignore the power setting', () {
      expect(
        SoundCatalog.byId('smooth').atPower(1).assetPath,
        'asset/smooth.mp3',
      );
      expect(SoundCatalog.byId('silent').atPower(5).canPreview, isFalse);
      expect(SoundCatalog.byId('vibrate').hasPowerLevels, isFalse);
    });
  });

  for (final size in const [Size(320, 640), Size(412, 915)]) {
    testWidgets('home card switches on and back at $size with large text', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await BeepMode.instance.turnOff();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: BeepModeCard(upcomingDays: () async => const []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Beep instead of Athan'), findsOneWidget);
      expect(tester.takeException(), isNull);

      Future<void> press(String label) async {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      await press('Today');
      expect(find.text('Beep mode is on'), findsOneWidget);
      expect(find.textContaining('until midnight'), findsOneWidget);
      expect(BeepMode.instance.state.value.activeAt(DateTime.now()), isTrue);
      expect(tester.takeException(), isNull);

      await press('Back to Athan');
      expect(find.text('Beep instead of Athan'), findsOneWidget);
      expect(BeepMode.instance.state.value.until, isNull);

      await press('Until I turn it off');
      expect(find.textContaining('until you turn this off'), findsOneWidget);
      await BeepMode.instance.turnOff();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

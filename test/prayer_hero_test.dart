import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/models/prayer_time_model.dart';
import 'package:flutter_pro/services/prayer_service.dart';
import 'package:flutter_pro/widgets/next_prayer_hero.dart';

void main() {
  PrayerTimeModel today() {
    final now = PrayerService.instance.now;
    return PrayerTimeModel(
      date: DateTime.utc(now.year, now.month, now.day),
      fajr: '05:30',
      sunrise: '07:00',
      dhuhr: '12:00',
      asr: '14:00',
      maghrib: '17:00',
      isha: '19:00',
    );
  }

  for (final size in [const Size(320, 640), const Size(740, 360)]) {
    testWidgets('Prayer hero fits ${size.width} width with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(2),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: NextPrayerHero(today: today(), onRefresh: () {}),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Preview Athan'), findsOneWidget);
      // Let several ticks occur, then dispose: no leaked timer/subscription.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('City picker remains scrollable on a small landscape screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NextPrayerHero(today: today(), onRefresh: () {}),
          ),
        ),
      ),
    );
    await tester.tap(find.text(PrayerService.instance.cityName));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Choose your city'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

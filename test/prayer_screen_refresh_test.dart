import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/screens/athan_screen.dart';
import 'package:flutter_pro/services/astronomical_calculator.dart';
import 'package:flutter_pro/services/prayer_service.dart';
import 'package:flutter_pro/widgets/next_prayer_hero.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('city refresh requests coalesce while alarms are being saved', (
    tester,
  ) async {
    final now = DateTime.now();
    final saved = <String, Object>{
      'pref_timezone': 'Europe/London',
      'pref_calculation_method': 15,
    };
    for (final config in [
      const AstronomicalCalculator(),
      const AstronomicalCalculator(
        latitude: 25.2048,
        longitude: 55.2708,
        calculationMethod: 16,
        timeZoneName: 'Asia/Dubai',
      ),
    ]) {
      for (var offset = 0; offset <= 3; offset++) {
        final date = DateTime(now.year, now.month + offset, 1);
        final key =
            'prayers_v3_${date.year}_${date.month}_${config.latitude.toStringAsFixed(6)}_${config.longitude.toStringAsFixed(6)}_${config.calculationMethod}_${config.timeZoneName}';
        saved[key] = jsonEncode({
          'checkedAt': now.toUtc().toIso8601String(),
          'days': config
              .calculateMonth(date.year, date.month)
              .map((day) => day.toJson())
              .toList(),
        });
      }
    }
    SharedPreferences.setMockInitialValues(saved);
    final firstSchedule = Completer<void>();
    var replacements = 0;
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
      if (call.method == 'health')
        return {'exact': true, 'batteryOptimized': false, 'count': 0};
      if (call.method == 'replace') {
        replacements++;
        if (replacements == 1) await firstSchedule.future;
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(notifications, null);
      messenger.setMockMethodCallHandler(alarms, null);
    });
    await PrayerService.instance.loadSavedSettings();
    await tester.pumpWidget(const MaterialApp(home: AthanScreen()));
    await tester.pumpAndSettle();
    expect(replacements, 1);
    final hero = tester.widget<NextPrayerHero>(find.byType(NextPrayerHero));
    expect(hero.today.timeZoneName, 'Europe/London');
    await PrayerService.instance.updateLocation(
      lat: 25.2048,
      lng: 55.2708,
      city: 'Dubai, UAE',
      method: 16,
      timeZoneName: 'Asia/Dubai',
    );
    hero.onRefresh();
    hero.onRefresh();
    await tester.pump();
    expect(find.byType(NextPrayerHero), findsNothing);
    firstSchedule.complete();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<NextPrayerHero>(find.byType(NextPrayerHero))
          .today
          .timeZoneName,
      'Asia/Dubai',
    );
    expect(
      replacements,
      2,
      reason: 'Both requests should cause only one replacement load',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

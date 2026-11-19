import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/main.dart';
import 'package:flutter_pro/services/astronomical_calculator.dart';
import 'package:flutter_pro/services/prayer_service.dart';
import 'package:flutter_pro/widgets/next_prayer_hero.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Cached prayer home opens and main navigation works offline',
      (tester) async {
    final now = PrayerService.instance.now;
    const calculator =
        AstronomicalCalculator(latitude: 51.5074, longitude: -0.1278);
    final days = calculator.calculateMonth(now.year, now.month);
    SharedPreferences.setMockInitialValues({
      'pref_timezone': 'Europe/London',
      'pref_calculation_method': 15,
      'prayers_v3_${now.year}_${now.month}_51.507400_-0.127800_15_Europe/London':
          jsonEncode({
        'checkedAt': DateTime.now().toIso8601String(),
        'days': days.map((day) => day.toJson()).toList()
      }),
    });
    await PrayerService.instance.loadSavedSettings();
    await tester.pumpWidget(const AthanQuranApp());
    await tester.pumpAndSettle();
    expect(find.byType(NextPrayerHero), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Make Athan yours'), findsOneWidget);
    expect(find.byType(NextPrayerHero), findsNothing);

    await tester.tap(find.text('Holy Quran').last);
    await tester.pumpAndSettle();
    expect(find.text('Al-Faatiha'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

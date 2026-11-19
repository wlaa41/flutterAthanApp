import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/screens/qibla_screen.dart';
import 'package:flutter_pro/services/prayer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Qibla guide uses selected city and explains north-up orientation',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = PrayerService.instance;
    await service.updateLocation(
        lat: 51.5074, lng: -0.1278, city: 'London, United Kingdom', method: 15);
    await tester.pumpWidget(const MaterialApp(home: QiblaScreen()));
    // adhan_dart upstream UK reference is 118.99 degrees from north.
    expect(find.text('119.0° from north'), findsOneWidget);
    expect(find.textContaining('From London, United Kingdom'), findsOneWidget);
    expect(find.textContaining('North stays at the top'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await service.updateLocation(
        lat: 40.7128, lng: -74.0060, city: 'New York, USA', method: 2);
    await tester.pumpWidget(const MaterialApp(home: QiblaScreen()));
    expect(find.text('58.5° from north'), findsOneWidget);
    expect(find.textContaining('From New York, USA'), findsOneWidget);
    expect(find.textContaining('ESE'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

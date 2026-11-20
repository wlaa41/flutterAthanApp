// Run with: flutter test tools/capture_screens.dart
// Writes disposable review images into build/review; these are not goldens.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/main.dart';
import 'package:flutter_pro/models/alert_preferences.dart';
import 'package:flutter_pro/screens/settings_screen.dart';
import 'package:flutter_pro/services/astronomical_calculator.dart';
import 'package:flutter_pro/services/beep_mode.dart';
import 'package:flutter_pro/services/prayer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _boundary = ValueKey('screen-capture');

Future<void> loadReviewFonts(WidgetTester tester) => tester.runAsync(() async {
  // Widget tests draw text with a block font unless real fonts are loaded.
  final latin =
      Platform.environment['REVIEW_FONT'] ??
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';
  final roboto = FontLoader('Roboto')
    ..addFont(File(latin).readAsBytes().then(ByteData.sublistView));
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
});

Future<void> capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundary),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/review').create(recursive: true);
    await File(
      'build/review/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Map<String, Object> cachedMonth() {
  final now = PrayerService.instance.now;
  const calculator = AstronomicalCalculator(
    latitude: 51.5074,
    longitude: -0.1278,
  );
  return {
    'pref_timezone': 'Europe/London',
    'pref_calculation_method': 15,
    'prayers_v3_${now.year}_${now.month}_51.507400_-0.127800_15_Europe/London':
        jsonEncode({
          'checkedAt': DateTime.now().toIso8601String(),
          'days': calculator
              .calculateMonth(now.year, now.month)
              .map((day) => day.toJson())
              .toList(),
        }),
  };
}

void main() {
  // One test on purpose: PrayerService keeps its settings future, and a future
  // made under one test's fake clock never completes for the next test.
  testWidgets('review screens', (tester) async {
    await loadReviewFonts(tester);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    // Home screen, Beep mode off and on.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(cachedMonth());
    tester.view.physicalSize = const Size(392, 850);
    await PrayerService.instance.loadSavedSettings();
    await BeepMode.instance.turnOff();
    await tester.pumpWidget(
      const RepaintBoundary(key: _boundary, child: AthanQuranApp()),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'home-beep-off');
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    await capture(tester, 'home-beep-on');
    await BeepMode.instance.turnOff();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    // Beep settings as Android shows them, with the phone side answered here.
    debugDefaultTargetPlatformOverride = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const alarms = MethodChannel('athan/alarms');
    const notifications = MethodChannel(
      'dexterous.com/flutter/local_notifications',
    );
    messenger.setMockMethodCallHandler(alarms, (call) async {
      if (call.method == 'health') {
        return {'exact': true, 'batteryOptimized': false, 'count': 0};
      }
      if (call.method == 'getBeepMode') return 0;
      return null;
    });
    messenger.setMockMethodCallHandler(notifications, (call) async {
      if (call.method == 'initialize' ||
          call.method == 'areNotificationsEnabled') {
        return true;
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(alarms, null);
      messenger.setMockMethodCallHandler(notifications, null);
    });
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      ...cachedMonth(),
      'alert_preferences': jsonEncode(
        const AlertPreferences(beepVibrate: true).toJson(),
      ),
    });
    tester.view.physicalSize = const Size(392, 1500);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(),
          home: const SettingsScreen(initialSection: SettingsSection.reminders),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'settings-beep');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

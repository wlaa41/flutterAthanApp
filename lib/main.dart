import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'screens/main_navigation_screen.dart';
import 'services/notification_service.dart';
import 'services/prayer_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize time zones for local notifications
  tz.initializeTimeZones();

  // Initialize notification service with 'smooth' athan sound
  await NotificationService.instance.initialize();

  // Initialize background service with safe error handling
  try {
    FlutterBackgroundService.initialize(onBackgroundServiceStart);
  } catch (e) {
    debugPrint('Background service init warning: $e');
  }

  runApp(const AthanQuranApp());
}

/// Background service job to keep prayer alarms and timings updated
void onBackgroundServiceStart() {
  WidgetsFlutterBinding.ensureInitialized();
  final service = FlutterBackgroundService();

  service.onDataReceived.listen((event) {
    if (event == null) return;
    if (event['action'] == 'setAsForeground') {
      service.setForegroundMode(true);
    } else if (event['action'] == 'setAsBackground') {
      service.setForegroundMode(false);
    } else if (event['action'] == 'stopService') {
      service.stopBackgroundService();
    }
  });

  service.setForegroundMode(true);

  // Periodic background refresh every 24 hours to schedule ahead
  Timer.periodic(const Duration(hours: 24), (timer) async {
    if (!(await service.isServiceRunning())) {
      timer.cancel();
      return;
    }

    try {
      tz.initializeTimeZones();
      final now = DateTime.now();
      final monthly =
          await PrayerService.instance.getMonthlyPrayers(now.year, now.month);
      await NotificationService.instance.schedulePrayers(monthly);

      service.setNotificationInfo(
        title: "Athan London Service",
        content: "Prayer timings updated at ${DateTime.now().hour}:${DateTime.now().minute}",
      );
    } catch (e) {
      debugPrint('Background periodic job error: $e');
    }
  });
}

class AthanQuranApp extends StatelessWidget {
  const AthanQuranApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Athan & Quran London',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF0F3931),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0F3931),
          secondary: Color(0xFFC5A059),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F3931),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        fontFamily: 'Roboto',
      ),
      home: const MainNavigationScreen(),
    );
  }
}

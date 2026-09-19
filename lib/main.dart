import 'package:flutter/material.dart';
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

  // Schedule upcoming month's prayer notifications
  try {
    final now = DateTime.now();
    PrayerService.instance
        .getMonthlyPrayers(now.year, now.month)
        .then((prayers) {
      NotificationService.instance.schedulePrayers(prayers);
    }).catchError((e) {
      debugPrint('Initial prayer schedule error: $e');
    });
  } catch (e) {
    debugPrint('Prayer init error: $e');
  }

  runApp(const AthanQuranApp());
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
        cardTheme: CardThemeData(
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

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/prayer_time_model.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onSelectNotification: (String? payload) async {
        debugPrint('Notification clicked with payload: $payload');
      },
    );
    _isInitialized = true;
  }

  /// Check if a specific prayer alarm is enabled
  Future<bool> isPrayerEnabled(int prayerIndex) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('alarm_enabled_$prayerIndex') ?? true;
  }

  /// Toggle prayer alarm enabled/disabled
  Future<void> setPrayerEnabled(int prayerIndex, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alarm_enabled_$prayerIndex', enabled);
  }

  /// Schedule upcoming prayer notifications using the authentic 'smooth' sound
  Future<void> schedulePrayers(List<PrayerTimeModel> days) async {
    await initialize();
    await cancelAll();

    final now = DateTime.now();
    int notificationId = 100;

    for (final day in days) {
      for (int i = 1; i <= 6; i++) {
        if (i == 2) continue; // Skip sunrise for athan alarm

        final isEnabled = await isPrayerEnabled(i);
        if (!isEnabled) continue;

        final prayerDateTime = day.getPrayerDateTime(i);
        if (prayerDateTime.isAfter(now)) {
          final prayerName = day.getPrayerName(i);
          final scheduledTz = tz.TZDateTime.from(prayerDateTime, tz.local);

          const androidDetails = AndroidNotificationDetails(
            'athan_channel',
            'Athan Prayer Times',
            channelDescription: 'Prayer notifications with Athan sound',
            importance: Importance.max,
            priority: Priority.max,
            sound: RawResourceAndroidNotificationSound('smooth'),
            playSound: true,
            enableVibration: true,
            fullScreenIntent: true,
          );

          const details = NotificationDetails(android: androidDetails);

          try {
            await _notificationsPlugin.zonedSchedule(
              notificationId++,
              'Time for $prayerName Prayer',
              'Hayya \'ala-s-Salah - Athan for $prayerName in London',
              scheduledTz,
              details,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              androidAllowWhileIdle: true,
            );
          } catch (e) {
            debugPrint('NotificationService: schedule error: $e');
          }
        }
      }
    }
  }

  /// Test instant notification with sound
  Future<void> testNotification() async {
    await initialize();
    const androidDetails = AndroidNotificationDetails(
      'athan_channel_test',
      'Athan Test',
      channelDescription: 'Test notification for Athan sound',
      importance: Importance.max,
      priority: Priority.max,
      sound: RawResourceAndroidNotificationSound('smooth'),
      playSound: true,
      enableVibration: true,
    );
    const details = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      999,
      'Athan Sound Test',
      'Playing smooth Athan audio...',
      details,
    );
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}

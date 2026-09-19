import 'package:flutter/material.dart';
import 'services/notification_service.dart';

class MyGlobals {
  static Future<void> createNotification(
    DateTime date, [
    String title = 'Athan',
    String description = 'Notification',
    int id = 1,
    int timeSeconds = 500,
  ]) async {
    await NotificationService.instance.testNotification();
  }

  static Future<void> cancelAllNotifications() async {
    await NotificationService.instance.cancelAll();
  }
}

abstract class MyStyle {
  static TextStyle getProgressHeaderStyle() {
    return const TextStyle(
      color: Colors.white,
      fontFamily: 'Montserrat',
      fontWeight: FontWeight.w400,
      fontSize: 12.0,
    );
  }
}
import 'dart:async';
import 'dart:io';
// import 'dart:math';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';


FlutterLocalNotificationsPlugin notificationsPlugin =
FlutterLocalNotificationsPlugin();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();
class MyGlobals {
  static Future<void> createNotification(date , [ title='Athan',discription='Notification',int id= -1,int timeSeconds = 500]) async {

    // id = id==-1 ? new Random().nextInt(999999999):id;
    id = 1;
    notificationsPlugin.zonedSchedule(
        id,
        title,
        discription + '  $id',
        tz.TZDateTime.from(date, tz.local),

        NotificationDetails(
          android: AndroidNotificationDetails(
            'channel id $id',
            'channel name $id',
            'channel description $id',
            timeoutAfter: 500*1000,// SET IT TO 500000 ALMOST 7 MINS
            importance: Importance.max,
            priority: Priority.max,
            sound: RawResourceAndroidNotificationSound('smooth'),
              fullScreenIntent: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        androidAllowWhileIdle: true);
  }
  static var notificationIsOn = false;
  static Future<String> get _globalpath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }
  static Future<File> get _globalFile async {
    final path = await _globalpath;
    return File('$path/global.txt');
  }
  static Future<File> writeGLOBAL(counter) async {
    final file = await _globalFile;
    return file.writeAsString('$counter');
  }
  static Future readGLOBAL() async {
    try {
      final file = await _globalFile;
      // Read the file
      final contents = await file.readAsString();
      return contents;
    } catch (e) {
      return 0;
    }
  }
  static Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}

abstract class MyStyle {
  static TextStyle getProgressHeaderStyle() {
    return const TextStyle(
        color: Colors.white,
        fontFamily: 'Montserrat',
        fontWeight: FontWeight.w100,
        fontSize: 11.0);
  }
}
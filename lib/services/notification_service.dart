import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/alert_preferences.dart';
import '../models/prayer_time_model.dart';
import 'alert_planner.dart';
import 'beep_mode.dart';
import 'prayer_service.dart';
import 'sound_library.dart';

class NotificationHealth {
  final bool notificationsEnabled,
      exactAlarmsEnabled,
      batteryOptimized,
      supported;
  final int scheduledCount;
  final DateTime? scheduledUntil;
  const NotificationHealth({
    required this.notificationsEnabled,
    required this.exactAlarmsEnabled,
    required this.batteryOptimized,
    required this.supported,
    required this.scheduledCount,
    this.scheduledUntil,
  });
}

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();
  static const _native = MethodChannel('athan/alarms');
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _initializing;
  Future<void> _queue = Future.value();
  String? _lastPlan;
  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get _supported => _android || _ios;

  /// iOS content.sound controls background audio independently of the
  /// foreground presentSound flag. Quiet alerts must leave both disabled.
  static DarwinNotificationDetails iosDetailsFor(SoundOption sound) {
    final audible = !sound.isSilent && !sound.isVibrationOnly;
    return DarwinNotificationDetails(
      presentAlert: true,
      presentSound: audible,
      sound: audible ? sound.iosSound ?? 'beep.wav' : null,
      threadIdentifier: 'prayer',
    );
  }

  Future<void> initialize() async {
    if (!_supported) return;
    try {
      await (_initializing ??= _initialize());
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    if (!_supported) return;
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_prayer_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    await SoundLibrary.instance.prepareNotificationSounds();
  }

  Future<bool> isPrayerEnabled(int index) async =>
      (await SharedPreferences.getInstance()).getBool('alarm_enabled_$index') ??
      true;
  Future<void> setPrayerEnabled(int index, bool enabled) async {
    await (await SharedPreferences.getInstance()).setBool(
      'alarm_enabled_$index',
      enabled,
    );
    await refreshSchedule();
  }

  Future<void> refreshSchedule() {
    if (!_supported) return Future<void>.value();
    return _enqueue(() async {
      await initialize();
      if (!_supported) return;
      if (!(await getHealth()).notificationsEnabled) {
        await cancelAll();
        return;
      }
      final days = await PrayerService.instance.getUpcomingPrayers(
        days: _android ? 60 : 14,
      );
      await _schedule(days);
    });
  }

  // Retained for older callers; always extend beyond the current month.
  Future<void> schedulePrayers(List<PrayerTimeModel> days) => refreshSchedule();

  Future<void> _enqueue(Future<void> Function() work) {
    final next = _queue.then((_) => work());
    _queue = next.catchError((Object error) {
      debugPrint('Alert scheduling: $error');
    });
    return next;
  }

  Future<void> _schedule(List<PrayerTimeModel> days) async {
    final settings = await AlertPreferences.load();
    final prefs = await SharedPreferences.getInstance();
    final enabled = {
      for (final i in [1, 3, 4, 5, 6])
        if (prefs.getBool('alarm_enabled_$i') ?? true) i,
    };
    final health = await getHealth();
    if (!health.notificationsEnabled) {
      await cancelAll();
      return;
    }
    final beepMode = await BeepMode.instance.load();
    final plan = planAlerts(
      days: days,
      preferences: settings,
      enabledPrayers: enabled,
      now: DateTime.now(),
      limit: _android ? 2000 : 60,
      quietUntil: _android ? null : beepMode.until,
    );
    final sounds = await SoundLibrary.instance.loadSounds();
    SoundOption sound(String id) => sounds
        .firstWhere(
          (s) => s.id == id,
          orElse: () => SoundCatalog.byId('beep'),
        )
        .atPower(settings.beepPower);
    if (_android) await _sendBeepOptions(settings, sound(settings.quietSoundId));
    final events = plan.map((a) {
      final s = sound(a.soundId);
      return {
        'id': a.id,
        'time': a.time.millisecondsSinceEpoch,
        'title': a.title,
        'body': a.body,
        'soundId': s.id,
        'resource': s.androidResource ?? 'beep',
        'filePath': s.filePath ?? '',
      };
    }).toList();
    final encoded = jsonEncode(events);
    final fingerprint = '$encoded:${health.exactAlarmsEnabled}';
    // Frequent resumes/route changes need no OS writes when the queue is unchanged.
    if (_lastPlan == fingerprint && health.scheduledCount == plan.length)
      return;
    if (_android) {
      await _native.invokeMethod<void>('replace', encoded);
      // Retire schedules created by versions before the native playback queue.
      await _plugin.cancelAll();
    } else {
      final pending = await _plugin.pendingNotificationRequests();
      final keep = plan.map((a) => a.id).toSet();
      // Remove obsolete choices before enqueueing so iOS never exceeds its 64 limit.
      for (final request in pending) {
        if (!keep.contains(request.id)) await _plugin.cancel(request.id);
      }
      for (final a in plan) {
        final s = sound(a.soundId);
        await _plugin.zonedSchedule(
          a.id,
          a.title,
          a.body,
          tz.TZDateTime.from(a.time, tz.UTC),
          NotificationDetails(iOS: iosDetailsFor(s)),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
    _lastPlan = fingerprint;
    await prefs.setInt('scheduled_count', plan.length);
    if (plan.isNotEmpty)
      await prefs.setInt(
        'scheduled_until',
        plan.last.time.millisecondsSinceEpoch,
      );
    else
      await prefs.remove('scheduled_until');
  }

  /// Tells the phone which sound Beep mode uses, so it can swap the Athan for
  /// it at the moment a reminder fires.
  Future<void> _sendBeepOptions(AlertPreferences settings, SoundOption quiet) =>
      _native.invokeMethod<void>(
        'beepOptions',
        jsonEncode({
          'soundId': quiet.id,
          'resource': quiet.androidResource ?? 'beep',
          'filePath': quiet.filePath ?? '',
          'vibrate': settings.beepVibrate,
          'alarmVolume': settings.beepAlarmVolume,
        }),
      );

  /// Plays the chosen beep once, the way a reminder would sound.
  Future<bool> previewBeep(AlertPreferences settings) async {
    if (!_android) return false;
    final sounds = await SoundLibrary.instance.loadSounds();
    final quiet = sounds
        .firstWhere(
          (s) => s.id == settings.quietSoundId,
          orElse: () => SoundCatalog.byId('beep'),
        )
        .atPower(settings.beepPower);
    if (quiet.isSilent) return true;
    try {
      await _native.invokeMethod<void>(
        'previewTone',
        jsonEncode({
          'soundId': quiet.id,
          'resource': quiet.androidResource ?? 'beep',
          'filePath': quiet.filePath ?? '',
          'vibrate': settings.beepVibrate || quiet.isVibrationOnly,
          'alarmVolume': settings.beepAlarmVolume,
        }),
      );
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Asks Android 13+ to offer the "Athan beep" quick settings tile.
  /// Returns false when the phone needs it added by hand.
  Future<bool> requestBeepTile() async {
    if (!_android) return false;
    try {
      return await _native.invokeMethod<bool>('requestBeepTile') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<NotificationHealth> getHealth() async {
    await initialize();
    if (!_supported)
      return const NotificationHealth(
        notificationsEnabled: false,
        exactAlarmsEnabled: false,
        batteryOptimized: false,
        supported: false,
        scheduledCount: 0,
      );
    if (_android) {
      final plugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final native =
          await _native.invokeMapMethod<String, dynamic>('health') ?? {};
      return NotificationHealth(
        notificationsEnabled: await plugin?.areNotificationsEnabled() ?? false,
        exactAlarmsEnabled: native['exact'] == true,
        batteryOptimized: native['batteryOptimized'] == true,
        supported: true,
        scheduledCount: native['count'] as int? ?? 0,
        scheduledUntil: native['until'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(native['until'] as int),
      );
    }
    final permissions = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.checkPermissions();
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt('scheduled_until');
    return NotificationHealth(
      notificationsEnabled: permissions?.isEnabled ?? false,
      exactAlarmsEnabled: true,
      batteryOptimized: false,
      supported: true,
      scheduledCount: (await _plugin.pendingNotificationRequests()).length,
      scheduledUntil: until == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(until),
    );
  }

  Future<void> requestNotificationPermission() async {
    await initialize();
    if (_android)
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    if (_ios)
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: false, sound: true);
    await refreshSchedule();
  }

  Future<void> requestExactAlarmPermission() async {
    await initialize();
    if (_android)
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestExactAlarmsPermission();
    await refreshSchedule();
  }

  Future<void> openAppSettings() async {
    if (_supported) await _native.invokeMethod<void>('appSettings');
  }

  Future<void> openBatterySettings() async {
    if (_android) await _native.invokeMethod<void>('batterySettings');
  }

  Future<void> testNotification() async {
    await initialize();
    if (!_supported)
      throw UnsupportedError('Test alerts on an Android phone or iPhone.');
    final health = await getHealth();
    if (!health.notificationsEnabled)
      throw StateError('Allow notifications before testing an alert.');
    final settings = await AlertPreferences.load();
    final sounds = await SoundLibrary.instance.loadSounds();
    final beepMode = await BeepMode.instance.load();
    final id =
        settings.isQuietAt(PrayerService.instance.now) ||
            beepMode.activeAt(DateTime.now())
        ? settings.quietSoundId
        : settings.athanSoundId;
    final sound = sounds
        .firstWhere((s) => s.id == id, orElse: () => SoundCatalog.byId('beep'))
        .atPower(settings.beepPower);
    if (_android) {
      await _native.invokeMethod<void>(
        'test',
        jsonEncode({
          'id': 999,
          'title': 'Test prayer alert',
          'body': 'Uses your current work-hours and sound settings.',
          'soundId': sound.id,
          'resource': sound.androidResource ?? 'beep',
          'filePath': sound.filePath ?? '',
        }),
      );
    } else {
      await _plugin.show(
        999,
        'Test prayer alert',
        'Uses your current sound settings.',
        NotificationDetails(iOS: iosDetailsFor(sound)),
      );
    }
  }

  Future<void> cancelAll() async {
    if (!_supported) return;
    if (_android) await _native.invokeMethod<void>('replace', '[]');
    await _plugin.cancelAll();
    _lastPlan = null;
  }
}

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

/// The phone's sound mode, which decides how a reminder arrives.
enum RingerMode { normal, vibrate, silent }

/// The iPhone would not arm an alarm; [reason] is its own wording.
class IosAlarmRefused implements Exception {
  final String reason;
  const IosAlarmRefused(this.reason);

  @override
  String toString() => 'The iPhone refused the alarm: $reason';
}

/// An athan that is ringing as an iPhone alarm right now.
class RingingAlarm {
  final String id, title;
  const RingingAlarm(this.id, this.title);
}

/// The iPhone's alarms (iOS 26 and later): whether athans may ring as
/// alarms, and what is armed, snoozed and ringing.
class IosAlarmStatus {
  /// False before iOS 26: athans stay notifications.
  final bool supported;

  /// What the person answered: authorized, denied or notDetermined.
  final String state;

  /// Prayer reminders waiting as alarms.
  final int scheduled;

  /// Athans snoozed and counting down to ring again.
  final int snoozed;
  final List<RingingAlarm> ringing;

  /// The reminders armed by the last update, and why it stopped early.
  final List<int> armed;
  final String error;

  /// The app closed twice in a row while arming alarms, so it stopped trying
  /// and athans are notifications until the person asks again in Settings.
  final bool paused;

  const IosAlarmStatus({
    this.supported = false,
    this.state = 'unsupported',
    this.scheduled = 0,
    this.snoozed = 0,
    this.ringing = const [],
    this.armed = const [],
    this.error = '',
    this.paused = false,
  });

  IosAlarmStatus withNotes({required String error, required bool paused}) =>
      IosAlarmStatus(
        supported: supported,
        state: state,
        scheduled: scheduled,
        snoozed: snoozed,
        ringing: ringing,
        armed: armed,
        error: error,
        paused: paused,
      );

  static const none = IosAlarmStatus();

  bool get allowed => supported && state == 'authorized';
  bool get denied => supported && state == 'denied';
  bool get undecided => supported && state == 'notDetermined';

  /// Reads the phone's answer to any "alarmKit…" call. Public for tests.
  factory IosAlarmStatus.fromNative(Map<String, dynamic>? native) {
    if (native == null || native['supported'] != true) return none;
    final ringing = <RingingAlarm>[];
    for (final item in native['ringing'] as List? ?? const []) {
      if (item is Map && item['id'] is String) {
        final title = item['title'];
        ringing.add(
          RingingAlarm(
            item['id'] as String,
            title is String && title.isNotEmpty ? title : 'Athan',
          ),
        );
      }
    }
    return IosAlarmStatus(
      supported: true,
      state: native['state'] as String? ?? 'notDetermined',
      scheduled: (native['scheduled'] as num?)?.toInt() ?? 0,
      snoozed: (native['snoozed'] as num?)?.toInt() ?? 0,
      ringing: ringing,
      armed: [
        for (final id in native['armed'] as List? ?? const [])
          if (id is int) id,
      ],
      error: native['error'] as String? ?? '',
    );
  }
}

class NotificationHealth {
  final bool notificationsEnabled,
      exactAlarmsEnabled,
      batteryOptimized,
      supported;
  final int scheduledCount;
  final DateTime? scheduledUntil;

  /// The next reminder the phone will deliver.
  final DateTime? nextTime;
  final String? nextTitle;
  final RingerMode ringer;
  final bool doNotDisturb;

  /// The user turned the "Athan alarm" channel down in phone settings.
  final bool playbackMuted;

  /// Android may open the black alarm screen over the lock screen. Android
  /// 14+ lets the user turn this off under "Full screen notifications".
  final bool fullScreenAllowed;

  /// A snoozed athan waits to play again at this time.
  final DateTime? snoozedUntil;

  /// iPhone: athans that ring as alarms. Elsewhere [IosAlarmStatus.none].
  final IosAlarmStatus alarm;
  const NotificationHealth({
    required this.notificationsEnabled,
    required this.exactAlarmsEnabled,
    required this.batteryOptimized,
    required this.supported,
    required this.scheduledCount,
    this.scheduledUntil,
    this.nextTime,
    this.nextTitle,
    this.ringer = RingerMode.normal,
    this.doNotDisturb = false,
    this.playbackMuted = false,
    this.fullScreenAllowed = true,
    this.snoozedUntil,
    this.alarm = IosAlarmStatus.none,
  });

  /// An Athan can play out loud right now.
  bool get canPlayAloud =>
      ringer == RingerMode.normal && !doNotDisturb && !playbackMuted;

  /// What would block or weaken the next Athan, worst first. Empty when ready.
  List<String> get problems => [
    if (!exactAlarmsEnabled)
      'On-time alarms are off, so the Athan cannot play.',
    if (scheduledCount == 0) 'No Athan is scheduled.',
    if (batteryOptimized) 'Battery saving can delay or block the Athan.',
    if (!notificationsEnabled)
      'Notifications are off, so reminders cannot show on screen.',
  ];
}

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();
  static const _native = MethodChannel('athan/alarms');
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _initializing;
  Future<void> _queue = Future.value();
  String? _lastPlan;
  int _lastScheduled = -1;

  /// Why the iPhone last stopped arming athans as alarms; empty when it armed
  /// every one it was given.
  String _iosAlarmError = '';
  bool _iosAlarmCrashNoted = false;

  /// Set while the iPhone arms alarms, and how many launches ended inside it.
  static const _iosArmingKey = 'ios_alarm_arming';
  static const _iosCrashKey = 'ios_alarm_crashes';

  /// How many athans an iPhone keeps armed as alarms: about three days. The
  /// reminders after them wait as notifications until the app is opened.
  static const iosAlarmLimit = 24;

  /// "Try the alarm" rings at a full minute, like a prayer, and never sooner
  /// than this after the tap: time to lock the phone.
  static const iosAlarmTestDelay = Duration(seconds: 20);

  /// When a test alarm asked for at [now] rings. Public for tests.
  static DateTime iosAlarmTestTime(DateTime now) {
    final earliest = now.add(iosAlarmTestDelay);
    final minute = DateTime(
      earliest.year,
      earliest.month,
      earliest.day,
      earliest.hour,
      earliest.minute,
    );
    return minute == earliest ? minute : minute.add(const Duration(minutes: 1));
  }

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
      // Android plays the Athan through its own alarm and service, which do
      // not need notification permission. An iPhone notifies, or from iOS 26
      // rings an alarm, which has its own permission.
      if (_ios) {
        final health = await getHealth();
        if (!health.notificationsEnabled && !health.alarm.allowed) {
          await cancelAll();
          return;
        }
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
    final useAlarms =
        _ios &&
        settings.ringAsAlarm &&
        health.alarm.allowed &&
        !health.alarm.paused;
    if (_ios && !health.notificationsEnabled && !useAlarms) {
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
        .firstWhere((s) => s.id == id, orElse: () => SoundCatalog.byId('beep'))
        .atPower(settings.beepPower);
    if (_android) {
      await _sendBeepOptions(settings, sound(settings.quietSoundId));
      await _sendAlarmScreen(settings);
    }
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
    final fingerprint =
        '$encoded:${health.exactAlarmsEnabled}:${health.notificationsEnabled}'
        ':$useAlarms:${settings.snoozeMinutes}';
    // Frequent resumes/route changes need no OS writes when the queue is unchanged.
    if (_lastPlan == fingerprint && health.scheduledCount == _lastScheduled)
      return;
    var scheduled = plan;
    if (_android) {
      await _native.invokeMethod<void>('replace', encoded);
      // Retire schedules created by versions before the native playback queue.
      await _plugin.cancelAll();
    } else {
      // Athans ring as alarms where the iPhone allows it. The same call takes
      // alarms off again when the alarm screen is turned off.
      var armed = const <int>{};
      if (health.alarm.supported && !health.alarm.paused) {
        // If the app dies inside this call, the next launch finds the mark.
        await prefs.setBool(_iosArmingKey, true);
        final answer = await _iosAlarm('alarmKitReplace', {
          'snoozeMinutes': settings.snoozeMinutes,
          'events': useAlarms
              ? iosAlarmEvents(plan, sound)
              : const <Map<String, Object>>[],
        });
        await prefs.remove(_iosArmingKey);
        await prefs.remove(_iosCrashKey);
        armed = answer.armed.toSet();
        _iosAlarmError = answer.error;
        if (answer.error.isNotEmpty)
          debugPrint('iPhone alarms stopped early: ${answer.error}');
      }
      // Everything else, and what the iPhone would not arm, is a notification.
      final notify = health.notificationsEnabled
          ? plan.where((a) => !armed.contains(a.id)).toList()
          : const <PlannedAlert>[];
      final pending = await _plugin.pendingNotificationRequests();
      final keep = notify.map((a) => a.id).toSet();
      // Remove obsolete choices before enqueueing so iOS never exceeds its 64 limit.
      for (final request in pending) {
        if (!keep.contains(request.id)) await _plugin.cancel(request.id);
      }
      for (final a in notify) {
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
      scheduled = health.notificationsEnabled
          ? plan
          : plan.where((a) => armed.contains(a.id)).toList();
    }
    _lastPlan = fingerprint;
    _lastScheduled = scheduled.length;
    await prefs.setInt('scheduled_count', scheduled.length);
    if (scheduled.isNotEmpty)
      await prefs.setInt(
        'scheduled_until',
        scheduled.last.time.millisecondsSinceEpoch,
      );
    else
      await prefs.remove('scheduled_until');
  }

  /// A recording rings as an alarm. A beep, vibration or silent reminder is
  /// meant to be quiet, so it stays a notification. Android draws the same
  /// line for its alarm screen.
  static bool ringsAsAlarm(SoundOption sound) => sound.kind != SoundKind.tone;

  /// The reminders an iPhone arms as alarms: the soonest [limit] recordings.
  /// A recording with no iPhone excerpt rings with the phone's alarm sound.
  /// Public for tests.
  static List<Map<String, Object>> iosAlarmEvents(
    List<PlannedAlert> plan,
    SoundOption Function(String id) sound, {
    int limit = iosAlarmLimit,
  }) => [
    for (final a
        in plan.where((a) => ringsAsAlarm(sound(a.soundId))).take(limit))
      {
        'id': a.id,
        'time': a.time.millisecondsSinceEpoch,
        'title': a.title,
        'sound': sound(a.soundId).iosSound ?? '',
      },
  ];

  /// Asks the iPhone about its alarms, or to change them. Every call answers
  /// with what is armed, snoozed and ringing. Older iPhones answer "none".
  Future<IosAlarmStatus> _iosAlarm(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    if (!_ios) return IosAlarmStatus.none;
    try {
      return IosAlarmStatus.fromNative(
        await _native.invokeMapMethod<String, dynamic>(method, arguments),
      );
    } on MissingPluginException {
      return IosAlarmStatus.none;
    } on PlatformException {
      return IosAlarmStatus.none;
    }
  }

  /// What is armed, snoozed and ringing, with why arming last stopped and
  /// whether the guard below has turned alarms off.
  Future<IosAlarmStatus> iosAlarmStatus() async {
    final status = await _iosAlarm('alarmKit');
    if (!status.supported) return status;
    return status.withNotes(
      error: _iosAlarmError,
      paused: await _iosAlarmPaused(),
    );
  }

  /// A guard against a crash at every launch: arming runs when the app
  /// opens, so a launch that ends inside it would end the next one too. Two
  /// in a row and the app stops arming until the person asks again.
  Future<bool> _iosAlarmPaused() async {
    final prefs = await SharedPreferences.getInstance();
    if (!_iosAlarmCrashNoted) {
      _iosAlarmCrashNoted = true;
      if (prefs.getBool(_iosArmingKey) ?? false) {
        await prefs.remove(_iosArmingKey);
        await prefs.setInt(_iosCrashKey, (prefs.getInt(_iosCrashKey) ?? 0) + 1);
      }
    }
    return (prefs.getInt(_iosCrashKey) ?? 0) >= 2;
  }

  /// "Try again" in Settings after the guard turned alarms off.
  Future<void> resumeIosAlarms() async {
    await (await SharedPreferences.getInstance()).remove(_iosCrashKey);
    await refreshSchedule();
  }

  /// Shows the iPhone's "allow alarms" question, then arms the athans.
  Future<void> requestIosAlarms() async {
    await _iosAlarm('alarmKitRequest');
    await refreshSchedule();
  }

  /// Rings a test alarm with the chosen athan, at [iosAlarmTestTime]. Only
  /// the simulator check names its own [time].
  Future<DateTime> testIosAlarm({DateTime? time}) async {
    final settings = await AlertPreferences.load();
    final athan = await SoundLibrary.instance.resolve(settings.athanSoundId);
    final at = time ?? iosAlarmTestTime(DateTime.now());
    final answer = await _iosAlarm('alarmKitTest', {
      'time': at.millisecondsSinceEpoch,
      'title': 'Test athan',
      'sound': athan.iosSound ?? '',
      'snoozeMinutes': settings.snoozeMinutes,
    });
    if (!answer.allowed) throw const IosAlarmRefused('alarms are not allowed');
    if (answer.error.isNotEmpty) throw IosAlarmRefused(answer.error);
    return at;
  }

  /// Stops an athan that is ringing as an iPhone alarm.
  Future<IosAlarmStatus> stopRinging(String id) =>
      _iosAlarm('alarmKitStop', {'id': id});

  /// Snoozes it for the chosen minutes.
  Future<IosAlarmStatus> snoozeRinging(String id) =>
      _iosAlarm('alarmKitSnooze', {'id': id});

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

  /// Tells the phone how the alarm screen behaves: "Easier screen" and the
  /// snooze length. Read there when an athan plays, with the app closed.
  Future<void> _sendAlarmScreen(AlertPreferences settings) =>
      _native.invokeMethod<void>('alarmScreen', alarmScreenJson(settings));

  /// The alarm screen's options as the phone stores them. Public for tests.
  static String alarmScreenJson(AlertPreferences settings) => jsonEncode({
    'easierScreen': settings.easierScreen,
    'snoozeMinutes': settings.snoozeMinutes,
  });

  /// Android 14+: the page where "Full screen notifications" is allowed.
  Future<void> openFullScreenSettings() async {
    if (_android) await _native.invokeMethod<void>('fullScreenSettings');
  }

  /// Takes back a snoozed athan before it plays again.
  Future<void> cancelSnooze() async {
    if (_android) await _native.invokeMethod<void>('cancelSnooze');
    if (_ios) await _iosAlarm('alarmKitCancelSnooze');
  }

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
      return healthFromNative(
        native,
        notificationsEnabled: await plugin?.areNotificationsEnabled() ?? false,
      );
    }
    final permissions = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.checkPermissions();
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt('scheduled_until');
    final alarm = await iosAlarmStatus();
    return NotificationHealth(
      notificationsEnabled: permissions?.isEnabled ?? false,
      exactAlarmsEnabled: true,
      batteryOptimized: false,
      supported: true,
      scheduledCount:
          (await _plugin.pendingNotificationRequests()).length +
          alarm.scheduled,
      scheduledUntil: until == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(until),
      alarm: alarm,
    );
  }

  /// Reads the phone's answer to "health". Public for tests.
  static NotificationHealth healthFromNative(
    Map<String, dynamic> native, {
    required bool notificationsEnabled,
  }) {
    DateTime? at(Object? ms) =>
        ms is int ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
    final title = native['nextTitle'];
    return NotificationHealth(
      notificationsEnabled: notificationsEnabled,
      exactAlarmsEnabled: native['exact'] == true,
      batteryOptimized: native['batteryOptimized'] == true,
      supported: true,
      scheduledCount: native['count'] as int? ?? 0,
      scheduledUntil: at(native['until']),
      nextTime: at(native['nextTime']),
      nextTitle: title is String && title.isNotEmpty ? title : null,
      ringer: switch (native['ringer']) {
        'silent' => RingerMode.silent,
        'vibrate' => RingerMode.vibrate,
        _ => RingerMode.normal,
      },
      doNotDisturb: native['dnd'] == true,
      playbackMuted: native['playbackMuted'] == true,
      // An older phone side that does not report it can show the screen.
      fullScreenAllowed: native['fullScreen'] != false,
      snoozedUntil: at(native['snoozedUntil']),
    );
  }

  /// Asks, once per install, for what the Athan needs: notifications, then
  /// freedom from battery saving. Later fixes go through Reminder readiness.
  Future<void> firstRunSetup() async {
    if (!_supported) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_setupKey) ?? false)) {
      await prefs.setBool(_setupKey, true);
      try {
        final health = await getHealth();
        if (!health.notificationsEnabled) await requestNotificationPermission();
        if (_android && (await getHealth()).batteryOptimized)
          await requestBatteryExemption();
      } on PlatformException catch (e) {
        debugPrint('Reminder setup: $e');
      } on MissingPluginException catch (e) {
        debugPrint('Reminder setup: $e');
      }
    }
    await _iosAlarmSetup(prefs);
  }

  /// iPhone, once: ask to ring athans as alarms. It has its own key, so a
  /// phone that updates from a version without alarms is asked too, and one
  /// that later moves to iOS 26 is asked then.
  Future<void> _iosAlarmSetup(SharedPreferences prefs) async {
    if (!_ios || (prefs.getBool(_alarmSetupKey) ?? false)) return;
    if (!(await AlertPreferences.load()).ringAsAlarm) return;
    if (!(await iosAlarmStatus()).undecided) return;
    await prefs.setBool(_alarmSetupKey, true);
    await _iosAlarm('alarmKitRequest');
  }

  static const _setupKey = 'reminder_setup_asked_v1';
  static const _alarmSetupKey = 'alarm_screen_asked_v1';

  /// Shows Android's "Let app always run in the background?" dialog.
  Future<void> requestBatteryExemption() async {
    if (_android) await _native.invokeMethod<void>('requestBatteryExemption');
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
    if (_ios && !(await getHealth()).notificationsEnabled)
      throw StateError('Allow notifications before testing an alert.');
    final event = await _testEvent(
      999,
      'Test prayer alert',
      'Uses your current work-hours and sound settings.',
    );
    if (_android) {
      await _native.invokeMethod<void>('test', jsonEncode(event));
    } else {
      final sounds = await SoundLibrary.instance.loadSounds();
      final sound = sounds.firstWhere(
        (s) => s.id == event['soundId'],
        orElse: () => SoundCatalog.byId('beep'),
      );
      await _plugin.show(
        999,
        'Test prayer alert',
        'Uses your current sound settings.',
        NotificationDetails(iOS: iosDetailsFor(sound)),
      );
    }
  }

  /// How long "Test in 1 minute" waits: enough time to lock the phone.
  static const testDelay = Duration(seconds: 60);

  /// Puts a test through the same alarm a real prayer uses, [testDelay] from
  /// now. This is the honest test: lock the phone and wait for it.
  Future<DateTime> testSoon() async {
    await initialize();
    if (!_android) throw UnsupportedError('This test runs on Android.');
    final at = DateTime.now().add(testDelay);
    final event = await _testEvent(
      998,
      'Test Athan',
      'This came through the same alarm as a real prayer.',
    );
    event['time'] = at.millisecondsSinceEpoch;
    await _native.invokeMethod<void>('testSoon', jsonEncode(event));
    return at;
  }

  Future<Map<String, Object>> _testEvent(
    int id,
    String title,
    String body,
  ) async {
    final settings = await AlertPreferences.load();
    final sounds = await SoundLibrary.instance.loadSounds();
    final beepMode = await BeepMode.instance.load();
    final soundId =
        settings.isQuietAt(PrayerService.instance.now) ||
            beepMode.activeAt(DateTime.now())
        ? settings.quietSoundId
        : settings.athanSoundId;
    final sound = sounds
        .firstWhere(
          (s) => s.id == soundId,
          orElse: () => SoundCatalog.byId('beep'),
        )
        .atPower(settings.beepPower);
    return {
      'id': id,
      'time': DateTime.now().millisecondsSinceEpoch,
      'title': title,
      'body': body,
      'soundId': sound.id,
      'resource': sound.androidResource ?? 'beep',
      'filePath': sound.filePath ?? '',
    };
  }

  Future<void> cancelAll() async {
    if (!_supported) return;
    if (_android) await _native.invokeMethod<void>('replace', '[]');
    if (_ios) await _iosAlarm('alarmKitCancelAll');
    await _plugin.cancelAll();
    _lastPlan = null;
    _lastScheduled = -1;
  }
}

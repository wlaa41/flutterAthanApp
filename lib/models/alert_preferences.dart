import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// All alert choices are persisted together so a scheduled batch sees one snapshot.
class AlertPreferences {
  final String athanSoundId, iqamaSoundId, quietSoundId;
  final bool iqamaEnabled, quietEnabled;
  final int iqamaDelayMinutes, iqamaRepeatCount, iqamaRepeatIntervalMinutes;
  final int quietStartMinute, quietEndMinute;
  final Set<int> quietWeekdays;

  /// Loudness of the reminder tones, 1 (soft) to 5 (maximum).
  final int beepPower;
  final bool beepVibrate, beepAlarmVolume;

  /// "Easier screen": any tap on the alarm screen stops the athan.
  final bool easierScreen;

  /// How long Snooze waits before the athan plays again.
  final int snoozeMinutes;

  /// iPhone, iOS 26 and later: the athan rings as an alarm that takes over
  /// the lock screen. Off, it arrives as a notification.
  final bool ringAsAlarm;

  static const snoozeChoices = [5, 10, 15, 20, 30];

  const AlertPreferences({
    this.athanSoundId = 'smooth',
    this.iqamaSoundId = 'iqama',
    this.quietSoundId = 'beep',
    this.iqamaEnabled = false,
    this.iqamaDelayMinutes = 15,
    this.iqamaRepeatCount = 1,
    this.iqamaRepeatIntervalMinutes = 5,
    this.quietEnabled = false,
    this.quietStartMinute = 540,
    this.quietEndMinute = 1020,
    this.quietWeekdays = const {1, 2, 3, 4, 5},
    this.beepPower = 4,
    this.beepVibrate = false,
    this.beepAlarmVolume = false,
    this.easierScreen = false,
    this.snoozeMinutes = 10,
    this.ringAsAlarm = true,
  });

  /// Overnight shifts belong to their starting weekday; the end is exclusive.
  bool isQuietAt(DateTime time) {
    if (!quietEnabled || quietWeekdays.isEmpty) return false;
    final minute = time.hour * 60 + time.minute;
    if (quietStartMinute == quietEndMinute)
      return quietWeekdays.contains(time.weekday);
    if (quietStartMinute < quietEndMinute) {
      return quietWeekdays.contains(time.weekday) &&
          minute >= quietStartMinute &&
          minute < quietEndMinute;
    }
    final previousWeekday = time.weekday == 1 ? 7 : time.weekday - 1;
    return (quietWeekdays.contains(time.weekday) &&
            minute >= quietStartMinute) ||
        (quietWeekdays.contains(previousWeekday) && minute < quietEndMinute);
  }

  AlertPreferences copyWith({
    String? athanSoundId,
    String? iqamaSoundId,
    String? quietSoundId,
    bool? iqamaEnabled,
    bool? quietEnabled,
    int? iqamaDelayMinutes,
    int? iqamaRepeatCount,
    int? iqamaRepeatIntervalMinutes,
    int? quietStartMinute,
    int? quietEndMinute,
    Set<int>? quietWeekdays,
    int? beepPower,
    bool? beepVibrate,
    bool? beepAlarmVolume,
    bool? easierScreen,
    int? snoozeMinutes,
    bool? ringAsAlarm,
  }) => AlertPreferences(
    athanSoundId: athanSoundId ?? this.athanSoundId,
    iqamaSoundId: iqamaSoundId ?? this.iqamaSoundId,
    quietSoundId: quietSoundId ?? this.quietSoundId,
    iqamaEnabled: iqamaEnabled ?? this.iqamaEnabled,
    quietEnabled: quietEnabled ?? this.quietEnabled,
    iqamaDelayMinutes: (iqamaDelayMinutes ?? this.iqamaDelayMinutes).clamp(
      1,
      120,
    ),
    iqamaRepeatCount: (iqamaRepeatCount ?? this.iqamaRepeatCount).clamp(1, 5),
    iqamaRepeatIntervalMinutes:
        (iqamaRepeatIntervalMinutes ?? this.iqamaRepeatIntervalMinutes).clamp(
          1,
          30,
        ),
    quietStartMinute: (quietStartMinute ?? this.quietStartMinute).clamp(
      0,
      1439,
    ),
    quietEndMinute: (quietEndMinute ?? this.quietEndMinute).clamp(0, 1439),
    quietWeekdays: Set.unmodifiable(
      (quietWeekdays ?? this.quietWeekdays).where((d) => d >= 1 && d <= 7),
    ),
    beepPower: (beepPower ?? this.beepPower).clamp(1, 5),
    beepVibrate: beepVibrate ?? this.beepVibrate,
    beepAlarmVolume: beepAlarmVolume ?? this.beepAlarmVolume,
    easierScreen: easierScreen ?? this.easierScreen,
    snoozeMinutes: (snoozeMinutes ?? this.snoozeMinutes).clamp(1, 60),
    ringAsAlarm: ringAsAlarm ?? this.ringAsAlarm,
  );

  Map<String, dynamic> toJson() => {
    'athanSoundId': athanSoundId,
    'iqamaSoundId': iqamaSoundId,
    'quietSoundId': quietSoundId,
    'iqamaEnabled': iqamaEnabled,
    'quietEnabled': quietEnabled,
    'iqamaDelayMinutes': iqamaDelayMinutes,
    'iqamaRepeatCount': iqamaRepeatCount,
    'iqamaRepeatIntervalMinutes': iqamaRepeatIntervalMinutes,
    'quietStartMinute': quietStartMinute,
    'quietEndMinute': quietEndMinute,
    'quietWeekdays': quietWeekdays.toList()..sort(),
    'beepPower': beepPower,
    'beepVibrate': beepVibrate,
    'beepAlarmVolume': beepAlarmVolume,
    'easierScreen': easierScreen,
    'snoozeMinutes': snoozeMinutes,
    'ringAsAlarm': ringAsAlarm,
  };

  factory AlertPreferences.fromJson(Map<String, dynamic> json) {
    int? number(String key) => (json[key] as num?)?.toInt();
    return const AlertPreferences().copyWith(
      athanSoundId: json['athanSoundId'] as String?,
      iqamaSoundId: json['iqamaSoundId'] as String?,
      quietSoundId: json['quietSoundId'] as String?,
      iqamaEnabled: json['iqamaEnabled'] as bool?,
      quietEnabled: json['quietEnabled'] as bool?,
      iqamaDelayMinutes: number('iqamaDelayMinutes'),
      iqamaRepeatCount: number('iqamaRepeatCount'),
      iqamaRepeatIntervalMinutes: number('iqamaRepeatIntervalMinutes'),
      quietStartMinute: number('quietStartMinute'),
      quietEndMinute: number('quietEndMinute'),
      quietWeekdays: (json['quietWeekdays'] as List?)?.whereType<int>().toSet(),
      beepPower: number('beepPower'),
      beepVibrate: json['beepVibrate'] as bool?,
      beepAlarmVolume: json['beepAlarmVolume'] as bool?,
      easierScreen: json['easierScreen'] as bool?,
      snoozeMinutes: number('snoozeMinutes'),
      ringAsAlarm: json['ringAsAlarm'] as bool?,
    );
  }

  static Future<AlertPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString('alert_preferences');
      return raw == null
          ? const AlertPreferences()
          : AlertPreferences.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return const AlertPreferences();
    } on TypeError {
      return const AlertPreferences();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alert_preferences', jsonEncode(copyWith().toJson()));
  }
}

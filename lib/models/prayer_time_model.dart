import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Resolves a named zone without depending on the phone's current zone.
tz.Location prayerLocation(String name) {
  if (tz.timeZoneDatabase.locations.isEmpty) tzdata.initializeTimeZones();
  return tz.getLocation(name);
}

class PrayerTimeModel {
  final DateTime date;
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  final String timeZoneName;
  final bool isCalculated;

  PrayerTimeModel({
    required this.date,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    this.timeZoneName = 'Europe/London',
    this.isCalculated = false,
  }) {
    for (final value in [fajr, sunrise, dhuhr, asr, maghrib, isha]) {
      parseMinutes(value);
    }
    prayerLocation(timeZoneName);
  }

  static int parseMinutes(String value) {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
    if (match == null) throw FormatException('Invalid prayer time', value);
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) {
      throw FormatException('Invalid prayer time', value);
    }
    return hour * 60 + minute;
  }

  String get formattedDate =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  String get briefDate => '${date.day}/${date.month}';

  /// Returns the prayer's absolute instant in the selected city's timezone.
  /// Isha after midnight belongs to the following calendar day.
  DateTime getPrayerDateTime(int index) {
    if (index < 1 || index > 6) throw RangeError.range(index, 1, 6);
    final values = [fajr, sunrise, dhuhr, asr, maghrib, isha];
    final minutes = parseMinutes(values[index - 1]);
    var dayOffset = 0;
    if (index == 6 && minutes < parseMinutes(maghrib)) dayOffset = 1;
    if (index == 1 && minutes > parseMinutes(sunrise)) dayOffset = -1;
    return tz.TZDateTime(
      prayerLocation(timeZoneName),
      date.year,
      date.month,
      date.day + dayOffset,
      minutes ~/ 60,
      minutes % 60,
    );
  }

  String getPrayerName(int index) {
    if (index < 1 || index > 6) throw RangeError.range(index, 1, 6);
    return ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'][index - 1];
  }

  Map<String, dynamic> toJson() => {
    'date': DateTime.utc(date.year, date.month, date.day).toIso8601String(),
    'fajr': fajr,
    'sunrise': sunrise,
    'dhuhr': dhuhr,
    'asr': asr,
    'maghrib': maghrib,
    'isha': isha,
    'timezone': timeZoneName,
    'calculated': isCalculated,
  };

  factory PrayerTimeModel.fromJson(Map<String, dynamic> json) =>
      PrayerTimeModel(
        date: DateTime.parse(json['date'] as String),
        fajr: json['fajr'] as String,
        sunrise: json['sunrise'] as String,
        dhuhr: json['dhuhr'] as String,
        asr: json['asr'] as String,
        maghrib: json['maghrib'] as String,
        isha: json['isha'] as String,
        timeZoneName: json['timezone'] as String? ?? 'Europe/London',
        isCalculated: json['calculated'] as bool? ?? false,
      );
}

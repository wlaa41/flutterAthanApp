class PrayerTimeModel {
  final DateTime date;
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;

  PrayerTimeModel({
    required this.date,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  /// Formatted date in DD/MM/YYYY
  String get formattedDate {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  /// Brief date in D/M
  String get briefDate => '${date.day}/${date.month}';

  /// Returns DateTime object for a specific prayer index (1: Fajr, 2: Sunrise, 3: Dhuhr, 4: Asr, 5: Maghrib, 6: Isha)
  DateTime getPrayerDateTime(int index) {
    String timeStr;
    switch (index) {
      case 1:
        timeStr = fajr;
        break;
      case 2:
        timeStr = sunrise;
        break;
      case 3:
        timeStr = dhuhr;
        break;
      case 4:
        timeStr = asr;
        break;
      case 5:
        timeStr = maghrib;
        break;
      case 6:
        timeStr = isha;
        break;
      default:
        timeStr = fajr;
    }

    final cleanTime = timeStr.split(' ')[0];
    final parts = cleanTime.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  String getPrayerName(int index) {
    switch (index) {
      case 1:
        return 'Fajr';
      case 2:
        return 'Sunrise';
      case 3:
        return 'Dhuhr';
      case 4:
        return 'Asr';
      case 5:
        return 'Maghrib';
      case 6:
        return 'Isha';
      default:
        return 'Prayer';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'fajr': fajr,
      'sunrise': sunrise,
      'dhuhr': dhuhr,
      'asr': asr,
      'maghrib': maghrib,
      'isha': isha,
    };
  }

  factory PrayerTimeModel.fromJson(Map<String, dynamic> json) {
    return PrayerTimeModel(
      date: DateTime.parse(json['date'] as String),
      fajr: json['fajr'] as String? ?? '05:00',
      sunrise: json['sunrise'] as String? ?? '06:30',
      dhuhr: json['dhuhr'] as String? ?? '12:30',
      asr: json['asr'] as String? ?? '15:45',
      maghrib: json['maghrib'] as String? ?? '18:15',
      isha: json['isha'] as String? ?? '19:45',
    );
  }
}

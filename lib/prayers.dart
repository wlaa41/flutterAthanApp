// Legacy compatibility model for Prayers
import 'models/prayer_time_model.dart';

class Prayers {
  Prayers({
    required this.Fajr,
    required this.Dhuhr,
    required this.Asr,
    required this.Maghrib,
    required this.Isha,
    required this.date,
  });

  String Fajr;
  String Dhuhr;
  String Asr;
  String Maghrib;
  String Isha;
  DateTime date;

  String getPrayerName(int salahNo) {
    switch (salahNo) {
      case 1:
        return '$YMD Fajr';
      case 2:
        return '$YMD Dhuhr';
      case 3:
        return '$YMD Asr';
      case 4:
        return '$YMD Maghrib';
      case 5:
        return '$YMD Isha';
      default:
        return '$YMD Prayer';
    }
  }

  String getPrayer(int salahNo) {
    String time = '';
    switch (salahNo) {
      case 1:
        time = '$Fajr:00';
        break;
      case 2:
        time = '$Dhuhr:00';
        break;
      case 3:
        time = '$Asr:00';
        break;
      case 4:
        time = '$Maghrib:00';
        break;
      case 5:
        time = '$Isha:00';
        break;
    }
    return '$YMD $time';
  }

  String briefDate() => '${date.day}/${date.month}';

  String get YMD => date.toString().split(' ')[0];

  PrayerTimeModel toModernModel() {
    return PrayerTimeModel(
      date: date,
      fajr: Fajr,
      sunrise: '',
      dhuhr: Dhuhr,
      asr: Asr,
      maghrib: Maghrib,
      isha: Isha,
    );
  }
}

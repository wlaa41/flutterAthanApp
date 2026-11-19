import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:timezone/timezone.dart' as tz;

import '../models/prayer_time_model.dart';

/// Offline calculations using the maintained MIT-licensed adhan_dart library.
/// Calculated times can differ from a mosque's locally adjusted timetable.
class AstronomicalCalculator {
  static const double defaultLatitude = 51.5074;
  static const double defaultLongitude = -0.1278;

  final double latitude;
  final double longitude;
  final int calculationMethod;
  final String timeZoneName;

  const AstronomicalCalculator({
    this.latitude = defaultLatitude,
    this.longitude = defaultLongitude,
    this.calculationMethod = 15,
    this.timeZoneName = 'Europe/London',
  });

  adhan.CalculationParameters _parameters() {
    switch (calculationMethod) {
      case 1:
        return adhan.CalculationMethodParameters.karachi();
      case 2:
        return adhan.CalculationMethodParameters.northAmerica();
      case 3:
        return adhan.CalculationMethodParameters.muslimWorldLeague();
      case 4:
        return adhan.CalculationMethodParameters.ummAlQura();
      case 5:
        return adhan.CalculationMethodParameters.egyptian();
      case 8:
        return adhan.CalculationMethodParameters.gulfRegion();
      case 9:
        return adhan.CalculationMethodParameters.kuwait();
      case 10:
        return adhan.CalculationMethodParameters.qatar();
      case 11:
        return adhan.CalculationMethodParameters.singapore();
      case 13:
        return adhan.CalculationMethodParameters.turkiye();
      case 15:
        return adhan.CalculationMethodParameters.moonsightingCommittee();
      case 16:
        return adhan.CalculationMethodParameters.dubai();
      default:
        throw ArgumentError.value(calculationMethod, 'calculationMethod');
    }
  }

  PrayerTimeModel calculate(DateTime date) {
    final params = _parameters();
    // Match Aladhan's latitudeAdjustmentMethod=3.
    params.highLatitudeRule = adhan.HighLatitudeRule.twilightAngle;
    final times = adhan.PrayerTimes(
      date: DateTime.utc(date.year, date.month, date.day),
      coordinates: adhan.Coordinates(latitude, longitude),
      calculationParameters: params,
    );
    final zone = prayerLocation(timeZoneName);
    String format(DateTime instant) {
      final local = tz.TZDateTime.from(instant, zone);
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    return PrayerTimeModel(
      date: DateTime.utc(date.year, date.month, date.day),
      fajr: format(times.fajr),
      sunrise: format(times.sunrise),
      dhuhr: format(times.dhuhr),
      asr: format(times.asr),
      maghrib: format(times.maghrib),
      isha: format(times.isha),
      timeZoneName: timeZoneName,
      isCalculated: true,
    );
  }

  List<PrayerTimeModel> calculateMonth(int year, int month) => [
    for (var day = 1; day <= DateTime.utc(year, month + 1, 0).day; day++)
      calculate(DateTime.utc(year, month, day)),
  ];
}

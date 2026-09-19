import 'dart:math' as math;
import '../models/prayer_time_model.dart';

/// Astronomical Prayer Times Calculator
/// Provides 100% offline, fail-safe prayer time calculations using standard
/// solar position algorithms (Equation of Time, Solar Declination, Solar Noon).
class AstronomicalCalculator {
  // Default coordinates: London, UK (matches user's original app default)
  static const double defaultLatitude = 51.5074;
  static const double defaultLongitude = -0.1278;

  /// Calculation method parameters
  final double latitude;
  final double longitude;
  final double fajrAngle;
  final double ishaAngle;

  const AstronomicalCalculator({
    this.latitude = defaultLatitude,
    this.longitude = defaultLongitude,
    this.fajrAngle = 18.0, // Muslim World League / London Unified standard
    this.ishaAngle = 17.0,
  });

  /// Calculate prayer times for a specific DateTime
  PrayerTimeModel calculate(DateTime date) {
    final tzOffset = date.timeZoneOffset.inMinutes / 60.0;
    final dayOfYear = _getDayOfYear(date);

    // Solar calculation parameters
    // Fractional year in radians
    final gamma = 2 * math.pi / 365.0 * (dayOfYear - 1 + (12.0 - tzOffset) / 24.0);

    // Equation of time in minutes
    final eqtime = 229.18 *
        (0.000075 +
            0.001868 * math.cos(gamma) -
            0.032077 * math.sin(gamma) -
            0.014615 * math.cos(2 * gamma) -
            0.040849 * math.sin(2 * gamma));

    // Solar declination angle in radians
    final decl = 0.006918 -
        0.399912 * math.cos(gamma) +
        0.070257 * math.sin(gamma) -
        0.006758 * math.cos(2 * gamma) +
        0.000907 * math.sin(2 * gamma) -
        0.002697 * math.cos(3 * gamma) +
        0.00148 * math.sin(3 * gamma);

    final latRad = _degToRad(latitude);

    // Solar noon (Dhuhr) in hours
    final solarNoon = 12.0 + tzOffset - (longitude / 15.0) - (eqtime / 60.0);

    // Sunrise & Sunset angle (0.8333 degrees for atmospheric refraction)
    final sunriseHourAngle = _sunHourAngle(latRad, decl, 0.8333);
    final fajrHourAngle = _sunHourAngle(latRad, decl, fajrAngle);
    final ishaHourAngle = _sunHourAngle(latRad, decl, ishaAngle);

    // Asr calculation (Shafi'i: shadow length factor 1)
    final asrAngle = _asrHourAngle(latRad, decl, 1.0);

    // Time in decimal hours
    final sunriseHours = solarNoon - sunriseHourAngle;
    final sunsetHours = solarNoon + sunriseHourAngle;
    var fajrHours = solarNoon - fajrHourAngle;
    var ishaHours = solarNoon + ishaHourAngle;
    final asrHours = solarNoon + asrAngle;

    // High latitude adjustment (1/7th of night rule if sun doesn't reach angle)
    if (fajrHourAngle.isNaN || fajrHours < 1.0 || fajrHours > sunriseHours) {
      final nightDuration = 24.0 - sunsetHours + sunriseHours;
      fajrHours = sunriseHours - (nightDuration / 7.0);
    }
    if (ishaHourAngle.isNaN || ishaHours > 23.5 || ishaHours < sunsetHours) {
      final nightDuration = 24.0 - sunsetHours + sunriseHours;
      ishaHours = sunsetHours + (nightDuration / 7.0);
    }

    return PrayerTimeModel(
      date: date,
      fajr: _formatHours(fajrHours),
      sunrise: _formatHours(sunriseHours),
      dhuhr: _formatHours(solarNoon + (2.0 / 60.0)), // add 2 mins safety
      asr: _formatHours(asrHours),
      maghrib: _formatHours(sunsetHours + (2.0 / 60.0)), // add 2 mins safety
      isha: _formatHours(ishaHours),
    );
  }

  /// Calculates prayer times for an entire month
  List<PrayerTimeModel> calculateMonth(int year, int month) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final list = <PrayerTimeModel>[];
    for (int day = 1; day <= daysInMonth; day++) {
      list.add(calculate(DateTime(year, month, day)));
    }
    return list;
  }

  double _sunHourAngle(double latRad, double declRad, double angleDeg) {
    final angleRad = _degToRad(angleDeg);
    final cosH = (math.sin(-angleRad) - math.sin(latRad) * math.sin(declRad)) /
        (math.cos(latRad) * math.cos(declRad));

    if (cosH > 1.0 || cosH < -1.0) {
      return double.nan; // Sun doesn't reach this angle (extreme latitudes)
    }
    return _radToDeg(math.acos(cosH)) / 15.0;
  }

  double _asrHourAngle(double latRad, double declRad, double shadowFactor) {
    final delta = (latRad - declRad).abs();
    final cotAngle = shadowFactor + math.tan(delta);
    final asrAltRad = math.atan(1.0 / cotAngle);

    final cosH = (math.sin(asrAltRad) - math.sin(latRad) * math.sin(declRad)) /
        (math.cos(latRad) * math.cos(declRad));

    if (cosH > 1.0 || cosH < -1.0) {
      return 3.0; // fallback 3 hours after noon
    }
    return _radToDeg(math.acos(cosH)) / 15.0;
  }

  int _getDayOfYear(DateTime date) {
    return date.difference(DateTime(date.year, 1, 1)).inDays + 1;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);
  double _radToDeg(double rad) => rad * (180.0 / math.pi);

  String _formatHours(double decimalHours) {
    if (decimalHours.isNaN || decimalHours.isInfinite) return '00:00';
    var totalMinutes = (decimalHours * 60).round();
    while (totalMinutes < 0) {
      totalMinutes += 24 * 60;
    }
    totalMinutes = totalMinutes % (24 * 60);

    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}

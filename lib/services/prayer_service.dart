import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_time_model.dart';
import 'astronomical_calculator.dart';

class NextPrayerInfo {
  final String prayerName;
  final int prayerIndex;
  final DateTime prayerTime;
  final Duration timeRemaining;
  final double progressFraction; // 0.0 to 1.0 of the current prayer interval

  NextPrayerInfo({
    required this.prayerName,
    required this.prayerIndex,
    required this.prayerTime,
    required this.timeRemaining,
    required this.progressFraction,
  });
}

class PrayerService {
  static final PrayerService instance = PrayerService._internal();
  PrayerService._internal();

  double _latitude = 51.5074;
  double _longitude = -0.1278;
  String _cityName = 'London, United Kingdom';
  int _calculationMethod = 10; // 10 = London Unified / Islamic Relief

  double get latitude => _latitude;
  double get longitude => _longitude;
  String get cityName => _cityName;

  static const List<Map<String, dynamic>> presetCities = [
    {'name': 'London, United Kingdom', 'lat': 51.5074, 'lng': -0.1278, 'method': 10},
    {'name': 'Birmingham, United Kingdom', 'lat': 52.4862, 'lng': -1.8904, 'method': 10},
    {'name': 'Manchester, United Kingdom', 'lat': 53.4808, 'lng': -2.2426, 'method': 10},
    {'name': 'Leeds, United Kingdom', 'lat': 53.8008, 'lng': -1.5491, 'method': 10},
    {'name': 'Glasgow, United Kingdom', 'lat': 55.8642, 'lng': -4.2518, 'method': 10},
    {'name': 'Makkah, Saudi Arabia', 'lat': 21.3891, 'lng': 39.8579, 'method': 4},
    {'name': 'Madinah, Saudi Arabia', 'lat': 24.5247, 'lng': 39.5692, 'method': 4},
    {'name': 'Cairo, Egypt', 'lat': 30.0444, 'lng': 31.2357, 'method': 5},
    {'name': 'Dubai, UAE', 'lat': 25.2048, 'lng': 55.2708, 'method': 8},
    {'name': 'Istanbul, Turkey', 'lat': 41.0082, 'lng': 28.9784, 'method': 13},
    {'name': 'New York, USA', 'lat': 40.7128, 'lng': -74.0060, 'method': 2},
    {'name': 'Toronto, Canada', 'lat': 43.6532, 'lng': -79.3832, 'method': 2},
  ];

  Future<void> loadSavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _latitude = prefs.getDouble('pref_latitude') ?? 51.5074;
      _longitude = prefs.getDouble('pref_longitude') ?? -0.1278;
      _cityName = prefs.getString('pref_city_name') ?? 'London, United Kingdom';
      _calculationMethod = prefs.getInt('pref_calculation_method') ?? 10;
    } catch (_) {}
  }

  Future<void> updateLocation({
    required double lat,
    required double lng,
    required String city,
    int? method,
  }) async {
    _latitude = lat;
    _longitude = lng;
    _cityName = city;
    if (method != null) _calculationMethod = method;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('pref_latitude', lat);
      await prefs.setDouble('pref_longitude', lng);
      await prefs.setString('pref_city_name', city);
      if (method != null) {
        await prefs.setInt('pref_calculation_method', method);
      }
    } catch (_) {}
  }

  /// Get prayer times for a given month with automatic offline fallback
  Future<List<PrayerTimeModel>> getMonthlyPrayers(int year, int month) async {
    final cacheKey = 'prayers_${year}_${month}_${_latitude.toStringAsFixed(2)}_${_longitude.toStringAsFixed(2)}';

    // 1. Try reading from local SharedPreferences cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        final cachedList = decoded
            .map((item) => PrayerTimeModel.fromJson(item as Map<String, dynamic>))
            .toList();
        if (cachedList.isNotEmpty) {
          // Asynchronously refresh in background if connected
          _fetchAndCacheOnline(year, month, cacheKey).catchError((_) {});
          return cachedList;
        }
      }
    } catch (e) {
      debugPrint('PrayerService: Cache read error: $e');
    }

    // 2. Try fetching from network API
    try {
      final onlineList = await _fetchFromApi(year, month);
      if (onlineList.isNotEmpty) {
        _saveToCache(cacheKey, onlineList);
        return onlineList;
      }
    } catch (e) {
      debugPrint('PrayerService: Online fetch failed ($e). Using astronomical offline fallback.');
    }

    // 3. Robust Offline Fallback: Astronomical Solar Algorithm
    final fallbackCalculator = AstronomicalCalculator(
      latitude: _latitude,
      longitude: _longitude,
    );
    final fallbackList = fallbackCalculator.calculateMonth(year, month);
    _saveToCache(cacheKey, fallbackList);
    return fallbackList;
  }

  /// Get today's prayer times
  Future<PrayerTimeModel> getTodayPrayers() async {
    final now = DateTime.now();
    final monthly = await getMonthlyPrayers(now.year, now.month);
    return monthly.firstWhere(
      (p) => p.date.day == now.day && p.date.month == now.month,
      orElse: () => AstronomicalCalculator(
        latitude: _latitude,
        longitude: _longitude,
      ).calculate(now),
    );
  }

  /// Calculate the next prayer and countdown
  NextPrayerInfo calculateNextPrayer(PrayerTimeModel today, DateTime now) {
    final prayers = [
      {'name': 'Fajr', 'index': 1, 'time': today.getPrayerDateTime(1)},
      {'name': 'Sunrise', 'index': 2, 'time': today.getPrayerDateTime(2)},
      {'name': 'Dhuhr', 'index': 3, 'time': today.getPrayerDateTime(3)},
      {'name': 'Asr', 'index': 4, 'time': today.getPrayerDateTime(4)},
      {'name': 'Maghrib', 'index': 5, 'time': today.getPrayerDateTime(5)},
      {'name': 'Isha', 'index': 6, 'time': today.getPrayerDateTime(6)},
    ];

    for (int i = 0; i < prayers.length; i++) {
      final prayerTime = prayers[i]['time'] as DateTime;
      if (prayerTime.isAfter(now)) {
        final remaining = prayerTime.difference(now);
        final prevTime = i > 0
            ? (prayers[i - 1]['time'] as DateTime)
            : today.getPrayerDateTime(1).subtract(const Duration(hours: 6));
        final totalInterval = prayerTime.difference(prevTime).inSeconds;
        final elapsed = now.difference(prevTime).inSeconds;
        final fraction = totalInterval > 0
            ? (elapsed / totalInterval).clamp(0.0, 1.0)
            : 0.0;

        return NextPrayerInfo(
          prayerName: prayers[i]['name'] as String,
          prayerIndex: prayers[i]['index'] as int,
          prayerTime: prayerTime,
          timeRemaining: remaining,
          progressFraction: fraction,
        );
      }
    }

    // If all prayers today have passed, next is Fajr tomorrow
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowFajr = AstronomicalCalculator(
      latitude: _latitude,
      longitude: _longitude,
    ).calculate(tomorrow).getPrayerDateTime(1);

    final remaining = tomorrowFajr.difference(now);
    return NextPrayerInfo(
      prayerName: 'Fajr',
      prayerIndex: 1,
      prayerTime: tomorrowFajr,
      timeRemaining: remaining,
      progressFraction: 0.0,
    );
  }

  Future<List<PrayerTimeModel>> _fetchFromApi(int year, int month) async {
    final url = Uri.parse(
      'https://api.aladhan.com/v1/calendar?latitude=$_latitude&longitude=$_longitude&method=$_calculationMethod&month=$month&year=$year',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> days = data['data'] as List<dynamic>? ?? [];

      final list = <PrayerTimeModel>[];
      for (final dayData in days) {
        final timings = dayData['timings'] as Map<String, dynamic>;
        final dateInfo = dayData['date']['gregorian'];
        final dateStr = dateInfo['date'] as String; // "DD-MM-YYYY"
        final dateParts = dateStr.split('-');
        final date = DateTime(
          int.parse(dateParts[2]),
          int.parse(dateParts[1]),
          int.parse(dateParts[0]),
        );

        list.add(PrayerTimeModel(
          date: date,
          fajr: (timings['Fajr'] as String).split(' ')[0],
          sunrise: (timings['Sunrise'] as String).split(' ')[0],
          dhuhr: (timings['Dhuhr'] as String).split(' ')[0],
          asr: (timings['Asr'] as String).split(' ')[0],
          maghrib: (timings['Maghrib'] as String).split(' ')[0],
          isha: (timings['Isha'] as String).split(' ')[0],
        ));
      }
      return list;
    }
    throw Exception('API status: ${response.statusCode}');
  }

  Future<void> _fetchAndCacheOnline(int year, int month, String cacheKey) async {
    try {
      final list = await _fetchFromApi(year, month);
      if (list.isNotEmpty) {
        await _saveToCache(cacheKey, list);
      }
    } catch (_) {}
  }

  Future<void> _saveToCache(String key, List<PrayerTimeModel> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(list.map((e) => e.toJson()).toList());
      await prefs.setString(key, jsonStr);
    } catch (e) {
      debugPrint('PrayerService: Save cache error: $e');
    }
  }
}

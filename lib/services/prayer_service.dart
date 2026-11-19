import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/prayer_time_model.dart';
import 'astronomical_calculator.dart';

class NextPrayerInfo {
  final String prayerName;
  final int prayerIndex;
  final DateTime prayerTime;
  final Duration timeRemaining;
  final double progressFraction;

  NextPrayerInfo({
    required this.prayerName,
    required this.prayerIndex,
    required this.prayerTime,
    required this.timeRemaining,
    required this.progressFraction,
  });
}

class PrayerService {
  static final PrayerService instance = PrayerService();
  PrayerService({http.Client? client, DateTime Function()? clock})
    : _client = client ?? http.Client(),
      _clock = clock ?? DateTime.now;

  final http.Client _client;
  final DateTime Function() _clock;
  final Map<String, Future<List<PrayerTimeModel>>> _inflight = {};
  final Map<String, List<PrayerTimeModel>> _memory = {};
  Future<void>? _settingsLoading;
  double _latitude = 51.5074;
  double _longitude = -0.1278;
  String _cityName = 'London, United Kingdom';
  int _calculationMethod = 15;
  String _timeZoneName = 'Europe/London';

  double get latitude => _latitude;
  double get longitude => _longitude;
  String get cityName => _cityName;
  int get calculationMethod => _calculationMethod;
  String get timeZoneName => _timeZoneName;
  tz.TZDateTime get now =>
      tz.TZDateTime.from(_clock(), prayerLocation(_timeZoneName));

  static const Map<int, String> calculationMethods = {
    1: 'Karachi',
    2: 'ISNA (North America)',
    3: 'Muslim World League',
    4: 'Umm al-Qura, Makkah',
    5: 'Egyptian General Authority',
    8: 'Gulf Region',
    9: 'Kuwait',
    10: 'Qatar',
    11: 'Singapore',
    13: 'Turkey (Diyanet)',
    15: 'Moonsighting Committee',
    16: 'Dubai',
  };

  static const List<Map<String, dynamic>> presetCities = [
    {
      'name': 'London, United Kingdom',
      'lat': 51.5074,
      'lng': -0.1278,
      'method': 15,
      'timezone': 'Europe/London',
    },
    {
      'name': 'Birmingham, United Kingdom',
      'lat': 52.4862,
      'lng': -1.8904,
      'method': 15,
      'timezone': 'Europe/London',
    },
    {
      'name': 'Manchester, United Kingdom',
      'lat': 53.4808,
      'lng': -2.2426,
      'method': 15,
      'timezone': 'Europe/London',
    },
    {
      'name': 'Leeds, United Kingdom',
      'lat': 53.8008,
      'lng': -1.5491,
      'method': 15,
      'timezone': 'Europe/London',
    },
    {
      'name': 'Glasgow, United Kingdom',
      'lat': 55.8642,
      'lng': -4.2518,
      'method': 15,
      'timezone': 'Europe/London',
    },
    {
      'name': 'Makkah, Saudi Arabia',
      'lat': 21.3891,
      'lng': 39.8579,
      'method': 4,
      'timezone': 'Asia/Riyadh',
    },
    {
      'name': 'Madinah, Saudi Arabia',
      'lat': 24.5247,
      'lng': 39.5692,
      'method': 4,
      'timezone': 'Asia/Riyadh',
    },
    {
      'name': 'Cairo, Egypt',
      'lat': 30.0444,
      'lng': 31.2357,
      'method': 5,
      'timezone': 'Africa/Cairo',
    },
    {
      'name': 'Dubai, UAE',
      'lat': 25.2048,
      'lng': 55.2708,
      'method': 16,
      'timezone': 'Asia/Dubai',
    },
    {
      'name': 'Istanbul, Turkey',
      'lat': 41.0082,
      'lng': 28.9784,
      'method': 13,
      'timezone': 'Europe/Istanbul',
    },
    {
      'name': 'New York, USA',
      'lat': 40.7128,
      'lng': -74.0060,
      'method': 2,
      'timezone': 'America/New_York',
    },
    {
      'name': 'Toronto, Canada',
      'lat': 43.6532,
      'lng': -79.3832,
      'method': 2,
      'timezone': 'America/Toronto',
    },
  ];

  Future<void> loadSavedSettings() => _settingsLoading ??= _loadSettings();

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final city = prefs.getString('pref_city_name') ?? _cityName;
    final preset = _presetFor(city);
    final lat = prefs.getDouble('pref_latitude') ?? _latitude;
    final lng = prefs.getDouble('pref_longitude') ?? _longitude;
    if (!lat.isFinite ||
        lat < -66 ||
        lat > 66 ||
        !lng.isFinite ||
        lng.abs() > 180)
      return;
    var method = prefs.getInt('pref_calculation_method') ?? 15;
    // Previous releases incorrectly labelled method 10 as London Unified.
    if (!prefs.containsKey('pref_timezone') &&
        city.endsWith('United Kingdom') &&
        method == 10) {
      method = 15;
      await prefs.setInt('pref_calculation_method', method);
    }
    final zone =
        prefs.getString('pref_timezone') ??
        preset?['timezone'] as String? ??
        'Europe/London';
    try {
      prayerLocation(zone);
    } catch (_) {
      return;
    }
    _latitude = lat;
    _longitude = lng;
    _cityName = city;
    _calculationMethod = calculationMethods.containsKey(method) ? method : 15;
    _timeZoneName = zone;
    await prefs.setString('pref_timezone', zone);
  }

  static Map<String, dynamic>? _presetFor(String city) {
    for (final preset in presetCities) {
      if (preset['name'] == city) return preset;
    }
    return null;
  }

  Future<void> updateLocation({
    required double lat,
    required double lng,
    required String city,
    int? method,
    String? timeZoneName,
  }) async {
    await loadSavedSettings();
    if (!lat.isFinite || lat.abs() > 66 || !lng.isFinite || lng.abs() > 180) {
      throw ArgumentError(
        'Choose a location between 66 degrees north and south.',
      );
    }
    final nextMethod = method ?? _calculationMethod;
    if (!calculationMethods.containsKey(nextMethod))
      throw ArgumentError('Unknown calculation method');
    final zone = timeZoneName ?? _presetFor(city)?['timezone'] as String?;
    if (zone == null)
      throw ArgumentError('A timezone is required for this location.');
    prayerLocation(zone);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pref_latitude', lat);
    await prefs.setDouble('pref_longitude', lng);
    await prefs.setString('pref_city_name', city);
    await prefs.setInt('pref_calculation_method', nextMethod);
    await prefs.setString('pref_timezone', zone);
    _latitude = lat;
    _longitude = lng;
    _cityName = city;
    _calculationMethod = nextMethod;
    _timeZoneName = zone;
    _memory.clear();
  }

  _PrayerConfiguration get _configuration => _PrayerConfiguration(
    _latitude,
    _longitude,
    _calculationMethod,
    _timeZoneName,
  );

  /// Reuses validated monthly data; never starts a background polling loop.
  /// Force refresh is reserved for an explicit user refresh.
  Future<List<PrayerTimeModel>> getMonthlyPrayers(
    int year,
    int month, {
    bool forceRefresh = false,
  }) async {
    if (year < 1900 || year > 2200 || month < 1 || month > 12)
      throw ArgumentError('Invalid month');
    await loadSavedSettings();
    return _monthFor(_configuration, year, month, forceRefresh: forceRefresh);
  }

  Future<List<PrayerTimeModel>> _monthFor(
    _PrayerConfiguration config,
    int year,
    int month, {
    bool forceRefresh = false,
  }) async {
    final key = config.key(year, month);
    final existing = _inflight[key];
    if (existing != null) return existing;
    final request = _loadMonth(year, month, config, forceRefresh);
    _inflight[key] = request;
    try {
      final result = await request;
      if (_configuration.key(year, month) == key) _memory[key] = result;
      return result;
    } finally {
      _inflight.remove(key);
    }
  }

  Future<List<PrayerTimeModel>> _loadMonth(
    int year,
    int month,
    _PrayerConfiguration config,
    bool forceRefresh,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = config.key(year, month);
    List<PrayerTimeModel>? cached;
    try {
      final text = prefs.getString(key);
      if (text != null) {
        final envelope = jsonDecode(text) as Map<String, dynamic>;
        cached = (envelope['days'] as List)
            .map((e) => PrayerTimeModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _validateMonth(cached, year, month, config.zone);
        final checkedAt = DateTime.parse(envelope['checkedAt'] as String);
        final age = _clock().difference(checkedAt);
        final ttl = cached.first.isCalculated
            ? const Duration(minutes: 30)
            : const Duration(hours: 24);
        if (!forceRefresh && !age.isNegative && age < ttl) return cached;
      }
    } catch (_) {
      cached = null;
      await prefs.remove(key);
    }
    try {
      final online = await _fetchFromApi(year, month, config);
      await _save(prefs, key, online);
      return online;
    } catch (error) {
      debugPrint(
        'Prayer timetable unavailable; using saved or calculated times.',
      );
      final result = cached ?? config.calculator.calculateMonth(year, month);
      _validateMonth(result, year, month, config.zone);
      await _save(prefs, key, result);
      return result;
    }
  }

  Future<void> _save(
    SharedPreferences prefs,
    String key,
    List<PrayerTimeModel> days,
  ) async {
    await prefs.setString(
      key,
      jsonEncode({
        'checkedAt': _clock().toUtc().toIso8601String(),
        'days': days.map((day) => day.toJson()).toList(),
      }),
    );
    // Bound storage as location/method choices change.
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith('prayers_v3_'))
        .toList();
    if (keys.length > 12) {
      keys.remove(key);
      keys.sort();
      for (final old in keys.take(keys.length - 11)) {
        await prefs.remove(old);
      }
    }
  }

  Future<List<PrayerTimeModel>> _fetchFromApi(
    int year,
    int month,
    _PrayerConfiguration config,
  ) async {
    final url = Uri.https('api.aladhan.com', '/v1/calendar/$year/$month', {
      'latitude': config.lat.toString(),
      'longitude': config.lng.toString(),
      'method': config.method.toString(),
      'timezonestring': config.zone,
      'latitudeAdjustmentMethod': '3',
      'school': '0',
    });
    http.Response? response;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        response = await _client.get(url).timeout(const Duration(seconds: 6));
        if (response.statusCode >= 500 && attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          continue;
        }
        break;
      } on TimeoutException {
        if (attempt == 1) rethrow;
      } on http.ClientException {
        if (attempt == 1) rethrow;
      }
    }
    if (response == null || response.statusCode != 200)
      throw const FormatException('Prayer service unavailable');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['code'] != 200 || body['data'] is! List)
      throw const FormatException('Invalid calendar response');
    final days = (body['data'] as List).map((raw) {
      final data = raw as Map<String, dynamic>;
      final timings = data['timings'] as Map<String, dynamic>;
      final date = (data['date']['gregorian']['date'] as String).split('-');
      if (date.length != 3)
        throw const FormatException('Invalid calendar date');
      final dayNumber = int.parse(date[0]);
      final monthNumber = int.parse(date[1]);
      final yearNumber = int.parse(date[2]);
      final parsedDate = DateTime.utc(yearNumber, monthNumber, dayNumber);
      if (parsedDate.day != dayNumber ||
          parsedDate.month != monthNumber ||
          parsedDate.year != yearNumber)
        throw const FormatException('Invalid calendar date');
      final zone = data['meta']?['timezone'];
      if (zone != null && zone != config.zone)
        throw const FormatException('Unexpected calendar timezone');
      String time(String name) {
        final rawTime = timings[name];
        if (rawTime is! String)
          throw const FormatException('Missing prayer time');
        final match = RegExp(
          r'^(\d{2}:\d{2})(?:\s*\([^)]*\))?$',
        ).firstMatch(rawTime.trim());
        if (match == null) throw const FormatException('Invalid prayer time');
        return match.group(1)!;
      }

      return PrayerTimeModel(
        date: parsedDate,
        fajr: time('Fajr'),
        sunrise: time('Sunrise'),
        dhuhr: time('Dhuhr'),
        asr: time('Asr'),
        maghrib: time('Maghrib'),
        isha: time('Isha'),
        timeZoneName: config.zone,
      );
    }).toList();
    _validateMonth(days, year, month, config.zone);
    return days;
  }

  static void _validateMonth(
    List<PrayerTimeModel> days,
    int year,
    int month,
    String zone,
  ) {
    if (days.length != DateTime.utc(year, month + 1, 0).day)
      throw const FormatException('Incomplete calendar');
    days.sort((a, b) => a.date.compareTo(b.date));
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      if (day.date.year != year ||
          day.date.month != month ||
          day.date.day != i + 1 ||
          day.timeZoneName != zone)
        throw const FormatException('Calendar date mismatch');
      for (var prayer = 2; prayer <= 6; prayer++) {
        if (!day
            .getPrayerDateTime(prayer)
            .isAfter(day.getPrayerDateTime(prayer - 1)))
          throw const FormatException('Invalid prayer sequence');
      }
    }
  }

  Future<PrayerTimeModel> getTodayPrayers() async {
    await loadSavedSettings();
    final current = now;
    final monthly = await getMonthlyPrayers(current.year, current.month);
    return monthly[current.day - 1];
  }

  /// Calendar days spanning month/year boundaries for the notification planner.
  /// Include yesterday so an Isha or Iqama after midnight survives rescheduling.
  Future<List<PrayerTimeModel>> getUpcomingPrayers({int days = 30}) async {
    if (days < 1 || days > 62) throw RangeError.range(days, 1, 62);
    await loadSavedSettings();
    // Keep every month on one immutable location/method snapshot. A city change
    // can happen while HTTP is in flight; retry once, never return a mixed plan.
    for (var attempt = 0; attempt < 2; attempt++) {
      final config = _configuration;
      final current = tz.TZDateTime.from(_clock(), prayerLocation(config.zone));
      final first = DateTime.utc(current.year, current.month, current.day - 1);
      final last = DateTime.utc(
        current.year,
        current.month,
        current.day + days - 1,
      );
      final months = <List<PrayerTimeModel>>[];
      var cursor = DateTime.utc(first.year, first.month);
      bool isCurrent() => _configuration.key(0, 0) == config.key(0, 0);
      while (!cursor.isAfter(last)) {
        months.add(await _monthFor(config, cursor.year, cursor.month));
        if (!isCurrent()) break;
        cursor = DateTime.utc(cursor.year, cursor.month + 1);
      }
      if (isCurrent()) {
        return months
            .expand((month) => month)
            .where(
              (day) => !day.date.isBefore(first) && !day.date.isAfter(last),
            )
            .toList();
      }
    }
    throw StateError(
      'Location changed while loading reminders. Please try again.',
    );
  }

  NextPrayerInfo calculateNextPrayer(PrayerTimeModel today, DateTime instant) {
    final config = _configuration;
    final localNow = tz.TZDateTime.from(
      instant,
      prayerLocation(today.timeZoneName),
    );
    PrayerTimeModel dayFor(DateTime date) {
      if (today.date.year == date.year &&
          today.date.month == date.month &&
          today.date.day == date.day)
        return today;
      final cached = _memory[config.key(date.year, date.month)];
      return cached != null
          ? cached[date.day - 1]
          : config.calculator.calculate(date);
    }

    final schedule = <MapEntry<int, DateTime>>[];
    for (var offset = -1; offset <= 2; offset++) {
      final date = DateTime.utc(
        localNow.year,
        localNow.month,
        localNow.day + offset,
      );
      final day = dayFor(date);
      for (final index in [1, 3, 4, 5, 6]) {
        schedule.add(MapEntry(index, day.getPrayerDateTime(index)));
      }
    }
    schedule.sort((a, b) => a.value.compareTo(b.value));
    final nextIndex = schedule.indexWhere(
      (entry) => entry.value.isAfter(instant),
    );
    final next = schedule[nextIndex];
    final previous = nextIndex > 0 ? schedule[nextIndex - 1].value : instant;
    final interval = next.value.difference(previous).inSeconds;
    return NextPrayerInfo(
      prayerName: today.getPrayerName(next.key),
      prayerIndex: next.key,
      prayerTime: next.value,
      timeRemaining: next.value.difference(instant),
      progressFraction: interval <= 0
          ? 0
          : (instant.difference(previous).inSeconds / interval).clamp(0.0, 1.0),
    );
  }
}

class _PrayerConfiguration {
  final double lat;
  final double lng;
  final int method;
  final String zone;
  const _PrayerConfiguration(this.lat, this.lng, this.method, this.zone);
  String key(int year, int month) =>
      'prayers_v3_${year}_${month}_${lat.toStringAsFixed(6)}_${lng.toStringAsFixed(6)}_${method}_$zone';
  AstronomicalCalculator get calculator => AstronomicalCalculator(
    latitude: lat,
    longitude: lng,
    calculationMethod: method,
    timeZoneName: zone,
  );
}

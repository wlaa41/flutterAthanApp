import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_pro/models/prayer_time_model.dart';
import 'package:flutter_pro/services/astronomical_calculator.dart';
import 'package:flutter_pro/services/prayer_service.dart';

Map<String, dynamic> calendar(
  int year,
  int month, {
  String zone = 'Europe/London',
}) => {
  'code': 200,
  'data': List.generate(
    DateTime.utc(year, month + 1, 0).day,
    (i) => {
      'date': {
        'gregorian': {
          'date':
              '${(i + 1).toString().padLeft(2, '0')}-${month.toString().padLeft(2, '0')}-$year',
        },
      },
      'meta': {'timezone': zone},
      'timings': {
        'Fajr': '05:00 (GMT)',
        'Sunrise': '07:00 (GMT)',
        'Dhuhr': '12:00 (GMT)',
        'Asr': '14:30 (GMT)',
        'Maghrib': '16:30 (GMT)',
        'Isha': '18:00 (GMT)',
      },
    },
  ),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('city timezone observes DST independently of device timezone', () {
    PrayerTimeModel day(int month, int date) => PrayerTimeModel(
      date: DateTime.utc(2026, month, date),
      fajr: '05:00',
      sunrise: '07:00',
      dhuhr: '12:00',
      asr: '15:00',
      maghrib: '18:00',
      isha: '20:00',
    );
    expect(day(3, 28).getPrayerDateTime(3).toUtc().hour, 12);
    expect(day(3, 29).getPrayerDateTime(3).toUtc().hour, 11);
    expect(day(10, 24).getPrayerDateTime(3).toUtc().hour, 11);
    expect(day(10, 25).getPrayerDateTime(3).toUtc().hour, 12);
  });

  test('Isha after midnight keeps the following day across year boundary', () {
    final day = PrayerTimeModel(
      date: DateTime.utc(2026, 12, 31),
      fajr: '05:00',
      sunrise: '07:00',
      dhuhr: '12:00',
      asr: '15:00',
      maghrib: '20:00',
      isha: '00:20',
      timeZoneName: 'Asia/Dubai',
    );
    final isha = day.getPrayerDateTime(6);
    expect(isha.year, 2027);
    expect(isha.day, 1);
    expect(isha.toUtc(), DateTime.utc(2026, 12, 31, 20, 20));
  });

  test(
    'missing or out-of-range times are rejected instead of midnight alarms',
    () {
      final json = {
        'date': '2026-11-01',
        'fajr': '25:61',
        'sunrise': '07:00',
        'dhuhr': '12:00',
        'asr': '15:00',
        'maghrib': '18:00',
        'isha': '20:00',
      };
      expect(() => PrayerTimeModel.fromJson(json), throwsFormatException);
      json.remove('fajr');
      expect(() => PrayerTimeModel.fromJson(json), throwsA(isA<TypeError>()));
    },
  );

  test(
    'legacy UK method is corrected without overriding a modern explicit choice',
    () async {
      SharedPreferences.setMockInitialValues({
        'pref_city_name': 'London, United Kingdom',
        'pref_calculation_method': 10,
      });
      final legacy = PrayerService();
      await legacy.loadSavedSettings();
      expect(legacy.calculationMethod, 15);
      SharedPreferences.setMockInitialValues({
        'pref_city_name': 'London, United Kingdom',
        'pref_calculation_method': 10,
        'pref_timezone': 'Europe/London',
      });
      final explicit = PrayerService();
      await explicit.loadSavedSettings();
      expect(explicit.calculationMethod, 10);
    },
  );

  test('online data is cached without repeated refresh requests', () async {
    var calls = 0;
    final service = PrayerService(
      client: MockClient((request) async {
        calls++;
        expect(request.url.path, '/v1/calendar/2026/11');
        expect(request.url.queryParameters['method'], '15');
        expect(request.url.queryParameters['timezonestring'], 'Europe/London');
        return http.Response(jsonEncode(calendar(2026, 11)), 200);
      }),
      clock: () => DateTime.utc(2026, 11, 19),
    );
    final first = await service.getMonthlyPrayers(2026, 11);
    await service.getMonthlyPrayers(2026, 11);
    await service.getTodayPrayers();
    expect(first.length, 30);
    expect(first.first.isCalculated, isFalse);
    expect(calls, 1);
  });

  test('simultaneous loads share one request', () async {
    var calls = 0;
    final service = PrayerService(
      client: MockClient((request) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return http.Response(jsonEncode(calendar(2026, 11)), 200);
      }),
    );
    final results = await Future.wait([
      service.getMonthlyPrayers(2026, 11),
      service.getMonthlyPrayers(2026, 11),
    ]);
    expect(calls, 1);
    expect(results[0].length, 30);
    expect(results[1].length, 30);
  });

  test('calculation method forms part of cache identity', () async {
    final methods = <String>[];
    final service = PrayerService(
      client: MockClient((request) async {
        methods.add(request.url.queryParameters['method']!);
        return http.Response(jsonEncode(calendar(2026, 11)), 200);
      }),
    );
    await service.getMonthlyPrayers(2026, 11);
    await service.updateLocation(
      lat: 51.5074,
      lng: -0.1278,
      city: 'London, United Kingdom',
      method: 3,
    );
    await service.getMonthlyPrayers(2026, 11);
    expect(methods, ['15', '3']);
  });

  test(
    'incomplete calendar is rejected and replaced by calculated full month',
    () async {
      final response = calendar(2026, 11);
      (response['data'] as List).removeLast();
      final service = PrayerService(
        client: MockClient(
          (_) async => http.Response(jsonEncode(response), 200),
        ),
      );
      final days = await service.getMonthlyPrayers(2026, 11);
      expect(days.length, 30);
      expect(days.every((day) => day.isCalculated), isTrue);
    },
  );

  test(
    'duplicate dates and malformed clocks never enter notification data',
    () async {
      final response = calendar(2026, 11);
      final data = response['data'] as List;
      data[1] = data[0];
      final service = PrayerService(
        client: MockClient(
          (_) async => http.Response(jsonEncode(response), 200),
        ),
      );
      final days = await service.getMonthlyPrayers(2026, 11);
      expect(days[1].date.day, 2);
      expect(days.first.isCalculated, isTrue);
    },
  );

  test('offline retry is bounded and calculated cache is reused', () async {
    var calls = 0;
    final service = PrayerService(
      client: MockClient((_) async {
        calls++;
        throw http.ClientException('offline');
      }),
    );
    final days = await service.getMonthlyPrayers(2026, 11);
    await service.getMonthlyPrayers(2026, 11);
    expect(calls, 2);
    expect(days.first.isCalculated, isTrue);
    for (final day in days) {
      expect(
        day.getPrayerDateTime(6).isAfter(day.getPrayerDateTime(1)),
        isTrue,
      );
    }
  });

  test('rolling schedule includes the next month and next year', () async {
    final service = PrayerService(
      client: MockClient((request) async {
        final parts = request.url.pathSegments;
        return http.Response(
          jsonEncode(calendar(int.parse(parts[2]), int.parse(parts[3]))),
          200,
        );
      }),
      clock: () => DateTime.utc(2026, 12, 31, 12),
    );
    final days = await service.getUpcomingPrayers(days: 3);
    expect(days.map((day) => day.formattedDate), [
      '30/12/2026',
      '31/12/2026',
      '01/01/2027',
      '02/01/2027',
    ]);
  });

  test(
    'today follows selected city even when UTC calendar day differs',
    () async {
      final service = PrayerService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(calendar(2026, 12, zone: 'Asia/Dubai')),
            200,
          ),
        ),
        clock: () => DateTime.utc(2026, 11, 30, 22),
      );
      await service.updateLocation(
        lat: 25.2048,
        lng: 55.2708,
        city: 'Dubai, UAE',
        method: 16,
      );
      expect((await service.getTodayPrayers()).date, DateTime.utc(2026, 12, 1));
    },
  );

  test(
    'next prayer skips sunrise and uses loaded tomorrow timetable',
    () async {
      final service = PrayerService(
        client: MockClient(
          (_) async => http.Response(jsonEncode(calendar(2026, 11)), 200),
        ),
      );
      final days = await service.getMonthlyPrayers(2026, 11);
      expect(
        service
            .calculateNextPrayer(days.first, DateTime.utc(2026, 11, 1, 6))
            .prayerName,
        'Dhuhr',
      );
      final next = service.calculateNextPrayer(
        days.first,
        DateTime.utc(2026, 11, 1, 23),
      );
      expect(next.prayerTime.toUtc(), DateTime.utc(2026, 11, 2, 5));
    },
  );

  test('every preset yields ordered offline prayers in summer and winter', () {
    for (final city in PrayerService.presetCities) {
      final calculator = AstronomicalCalculator(
        latitude: city['lat'] as double,
        longitude: city['lng'] as double,
        calculationMethod: city['method'] as int,
        timeZoneName: city['timezone'] as String,
      );
      for (final month in [6, 12]) {
        final day = calculator.calculate(DateTime.utc(2026, month, 21));
        for (var index = 2; index <= 6; index++) {
          expect(
            day
                .getPrayerDateTime(index)
                .isAfter(day.getPrayerDateTime(index - 1)),
            isTrue,
            reason: '${city['name']} month $month prayer $index',
          );
        }
      }
    }
  });

  test('offline calculations honour city timezone and selected method', () {
    const london = AstronomicalCalculator();
    const dubai = AstronomicalCalculator(
      latitude: 25.2048,
      longitude: 55.2708,
      calculationMethod: 16,
      timeZoneName: 'Asia/Dubai',
    );
    final summer = london.calculate(DateTime.utc(2026, 6, 15));
    expect(
      summer.getPrayerDateTime(3).timeZoneOffset,
      const Duration(hours: 1),
    );
    expect(
      dubai
          .calculate(DateTime.utc(2026, 6, 15))
          .getPrayerDateTime(3)
          .timeZoneOffset,
      const Duration(hours: 4),
    );
    expect(summer.isCalculated, isTrue);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/models/drawing_stroke.dart';
import 'package:flutter_pro/models/prayer_time_model.dart';
import 'package:flutter_pro/models/quran_models.dart';
import 'package:flutter_pro/services/astronomical_calculator.dart';
import 'package:flutter_pro/services/quran_service.dart';

void main() {
  group('AstronomicalCalculator Tests (Offline Fallback)', () {
    test('Calculates valid 24h prayer times for London', () {
      const calculator = AstronomicalCalculator(
        latitude: 51.5074,
        longitude: -0.1278,
      );

      final date = DateTime(2026, 9, 19);
      final times = calculator.calculate(date);

      expect(times.fajr, isNotEmpty);
      expect(times.sunrise, isNotEmpty);
      expect(times.dhuhr, isNotEmpty);
      expect(times.asr, isNotEmpty);
      expect(times.maghrib, isNotEmpty);
      expect(times.isha, isNotEmpty);

      // Verify format HH:mm
      final timeRegex = RegExp(r'^\d{2}:\d{2}$');
      expect(timeRegex.hasMatch(times.fajr), isTrue);
      expect(timeRegex.hasMatch(times.sunrise), isTrue);
      expect(timeRegex.hasMatch(times.dhuhr), isTrue);
      expect(timeRegex.hasMatch(times.asr), isTrue);
      expect(timeRegex.hasMatch(times.maghrib), isTrue);
      expect(timeRegex.hasMatch(times.isha), isTrue);
    });

    test('Calculates full month without null or empty values', () {
      const calculator = AstronomicalCalculator(
        latitude: 51.5074,
        longitude: -0.1278,
      );

      final monthTimes = calculator.calculateMonth(2026, 9);
      expect(monthTimes.length, equals(30)); // September has 30 days
      for (final p in monthTimes) {
        expect(p.fajr, isNotEmpty);
        expect(p.maghrib, isNotEmpty);
      }
    });
  });

  group('Tajweed Parser & Quran Tests', () {
    test('stripTajweedTags correctly removes bracket markup', () {
      const sample = "بِسْمِ [h:1[ٱ]للَّهِ [h:2[ٱ]لرَّحْمَ[n[ـٰ]نِ [h:3[ٱ]لرَّحِ[p[ي]مِ";
      final clean = QuranService.stripTajweedTags(sample);
      expect(clean.contains('['), isFalse);
      expect(clean.contains(']'), isFalse);
      expect(clean.contains('بِسْمِ'), isTrue);
      expect(clean.contains('للَّهِ'), isTrue);
    });

    test('TajweedRuleInfo returns correct colors for rule codes', () {
      expect(TajweedRuleInfo.getColorForCode('q'), equals(const Color(0xFFDD1111))); // Qalqalah
      expect(TajweedRuleInfo.getColorForCode('f'), equals(const Color(0xFF9400D3))); // Ikhfa
      expect(TajweedRuleInfo.getColorForCode('a'), equals(const Color(0xFF169777))); // Idgham
      expect(TajweedRuleInfo.getColorForCode('h'), equals(const Color(0xFF78909C))); // Hamzat Wasl
    });

    test('Surah list contains 114 Surahs with valid names', () {
      expect(QuranService.surahList.length, equals(114));
      expect(QuranService.surahList.first.englishName, equals('Al-Faatiha'));
      expect(QuranService.surahList.last.englishName, equals('An-Naas'));
    });
  });

  group('Stylus & Drawing Persistence Tests', () {
    test('DrawingStroke serializes and deserializes correctly', () {
      final stroke = DrawingStroke(
        points: [
          DrawingPoint(x: 10.5, y: 20.5, pressure: 0.8),
          DrawingPoint(x: 15.0, y: 30.0, pressure: 0.9),
        ],
        colorValue: 0xFFC5A059,
        strokeWidth: 3.5,
        isHighlighter: false,
      );

      final json = stroke.toJson();
      final reconstructed = DrawingStroke.fromJson(json);

      expect(reconstructed.points.length, equals(2));
      expect(reconstructed.points[0].x, equals(10.5));
      expect(reconstructed.points[0].y, equals(20.5));
      expect(reconstructed.colorValue, equals(0xFFC5A059));
      expect(reconstructed.strokeWidth, equals(3.5));
      expect(reconstructed.isHighlighter, isFalse);
    });

    test('Highlighter DrawingStroke preserves isHighlighter flag', () {
      final stroke = DrawingStroke(
        points: [DrawingPoint(x: 50.0, y: 60.0)],
        colorValue: 0xFFFEF08A,
        strokeWidth: 22.0,
        isHighlighter: true,
      );

      final reconstructed = DrawingStroke.fromJson(stroke.toJson());
      expect(reconstructed.isHighlighter, isTrue);
      expect(reconstructed.strokeWidth, equals(22.0));
    });

    test('DrawingTool enum includes pan tool for scrolling in stylus mode', () {
      expect(DrawingTool.values.contains(DrawingTool.pan), isTrue);
    });
  });

  group('PrayerService Preset Cities Tests', () {
    test('Preset cities list contains London and other global cities', () {
      expect(PrayerService.presetCities.isNotEmpty, isTrue);
      final london = PrayerService.presetCities.firstWhere(
        (c) => (c['name'] as String).contains('London'),
      );
      expect(london['lat'], equals(51.5074));
      expect(london['lng'], equals(-0.1278));
    });
  });
}

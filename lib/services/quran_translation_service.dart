import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/quran_models.dart';
import 'disk_cache.dart';
import 'quran_service.dart';

/// The English meaning of each verse (Saheeh International), by Hafs verse
/// number. A surah is fetched the first time it is opened and then kept on the
/// phone.
class QuranTranslationService {
  QuranTranslationService({http.Client? client, DiskCache? cache})
    : _client = client ?? http.Client(),
      _cache = cache ?? DiskCache('quran_translation/en.sahih');

  static final QuranTranslationService instance = QuranTranslationService();
  static const String name = 'Saheeh International';

  final http.Client _client;
  final DiskCache _cache;
  final Map<int, List<String>> _memory = {};
  final Map<int, Future<List<String>>> _pending = {};

  /// The meanings of a surah's verses in Hafs order.
  Future<List<String>> surah(int number) {
    if (number < 1 || number > 114) {
      return Future.error(RangeError.range(number, 1, 114));
    }
    final ready = _memory[number];
    if (ready != null) return Future.value(ready);
    return _pending.putIfAbsent(number, () async {
      try {
        return _memory[number] = await _load(number);
      } finally {
        _pending.remove(number);
      }
    });
  }

  /// The meaning of a verse of any mushaf: the Hafs verses holding its words.
  static String forAyah(List<String> surah, MushafAyah ayah) => [
    for (var n = ayah.hafsFrom; n <= ayah.hafsTo && n <= surah.length; n++)
      surah[n - 1],
  ].join(' ');

  List<String>? _valid(int number, Object? decoded) {
    if (decoded is! List) return null;
    final verses = [
      for (final item in decoded)
        if (item is String && item.trim().isNotEmpty) item,
    ];
    final expected = QuranService.surahList[number - 1].numberOfAyahs;
    return verses.length == expected && decoded.length == expected
        ? List.unmodifiable(verses)
        : null;
  }

  Future<List<String>> _load(int number) async {
    final file = '$number.json';
    final saved = await _cache.read(file);
    if (saved != null) {
      try {
        final verses = _valid(number, jsonDecode(saved));
        if (verses != null) return verses;
      } catch (_) {}
      await _cache.remove(file);
    }

    // Earlier versions kept the whole surah, with its meaning, in preferences.
    final prefs = await SharedPreferences.getInstance();
    final legacyKey = 'surah_detail_$number';
    final legacy = prefs.getString(legacyKey);
    if (legacy != null) {
      List<String>? verses;
      try {
        verses = _valid(number, [
          for (final item in jsonDecode(legacy) as List<dynamic>)
            (item as Map<String, dynamic>)['translation'],
        ]);
      } catch (_) {}
      await prefs.remove(legacyKey);
      if (verses != null) {
        await _cache.write(file, jsonEncode(verses));
        return verses;
      }
    }

    try {
      final response = await _client
          .get(Uri.parse('https://api.alquran.cloud/v1/surah/$number/en.sahih'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw const FormatException('Translation service unavailable');
      }
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      final ayahs = data['ayahs'] as List<dynamic>;
      if (body['code'] != 200 ||
          data['number'] != number ||
          data['edition']?['identifier'] != 'en.sahih') {
        throw const FormatException('Wrong surah returned');
      }
      for (var index = 0; index < ayahs.length; index++) {
        if (ayahs[index]['numberInSurah'] != index + 1) {
          throw const FormatException('Verses are out of order');
        }
      }
      final verses = _valid(number, [for (final ayah in ayahs) ayah['text']]);
      if (verses == null) throw const FormatException('Incomplete surah');
      await _cache.write(file, jsonEncode(verses));
      return verses;
    } catch (error) {
      debugPrint('Translation of surah $number unavailable ($error).');
      throw const FormatException(
        'The translation of this surah is not on the phone yet.',
      );
    }
  }
}

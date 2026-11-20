import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'disk_cache.dart';
import 'quran_service.dart';

/// A tafsir the reader can open, served by quran.com.
class TafsirBook {
  const TafsirBook({
    required this.id,
    required this.title,
    required this.name,
    required this.about,
    required this.arabic,
    this.wholeSurah = false,
  });

  /// The resource number at quran.com.
  final int id;

  /// The short label, in the tafsir's own language.
  final String title;
  final String name;
  final String about;
  final bool arabic;

  /// Short enough to fetch a whole surah at once, which then reads offline.
  final bool wholeSurah;
}

/// A piece of tafsir and the Hafs verses it explains together.
class TafsirPassage {
  const TafsirPassage({
    required this.from,
    required this.to,
    required this.html,
  });

  final int from;
  final int to;
  final String html;

  Map<String, dynamic> toJson() => {'f': from, 't': to, 'h': html};

  static TafsirPassage? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final from = json['f'], to = json['t'], html = json['h'];
    if (from is! int || to is! int || html is! String) return null;
    if (from < 1 || to < from || html.trim().isEmpty) return null;
    return TafsirPassage(from: from, to: to, html: html);
  }
}

class TafsirUnavailable implements Exception {
  const TafsirUnavailable();

  @override
  String toString() =>
      'This tafsir could not be loaded. Check the connection and try again. '
      'Passages opened before stay on the phone.';
}

/// Fetches tafsir by Hafs verse and keeps what was read on the phone.
class TafsirService {
  TafsirService({http.Client? client, DiskCache? cache})
    : _client = client ?? http.Client(),
      _cache = cache ?? DiskCache('tafsir');

  static final TafsirService instance = TafsirService();

  static const List<TafsirBook> books = [
    TafsirBook(
      id: 16,
      title: 'الميسّر',
      name: 'Al-Tafsir al-Muyassar',
      about: 'King Fahd Complex. Short, in plain Arabic.',
      arabic: true,
      wholeSurah: true,
    ),
    TafsirBook(
      id: 91,
      title: 'السعدي',
      name: "Tafsir al-Sa'di",
      about: "Abd al-Rahman al-Sa'di. Clear and concise.",
      arabic: true,
    ),
    TafsirBook(
      id: 14,
      title: 'ابن كثير',
      name: 'Tafsir Ibn Kathir',
      about: 'Explains the Quran by the Quran and the hadith.',
      arabic: true,
    ),
    TafsirBook(
      id: 15,
      title: 'الطبري',
      name: 'Tafsir al-Tabari',
      about: 'The earliest large tafsir, with its chains of narration.',
      arabic: true,
    ),
    TafsirBook(
      id: 90,
      title: 'القرطبي',
      name: 'Tafsir al-Qurtubi',
      about: 'Known for the rulings drawn from each verse.',
      arabic: true,
    ),
    TafsirBook(
      id: 94,
      title: 'البغوي',
      name: 'Tafsir al-Baghawi',
      about: 'A medium-length tafsir built on narrations.',
      arabic: true,
    ),
    TafsirBook(
      id: 169,
      title: 'Ibn Kathir',
      name: 'Tafsir Ibn Kathir, abridged',
      about: 'The English abridgement.',
      arabic: false,
    ),
    TafsirBook(
      id: 168,
      title: "Ma'arif al-Qur'an",
      name: "Ma'arif al-Qur'an",
      about: "Mufti Muhammad Shafi'. Detailed, in English.",
      arabic: false,
    ),
    TafsirBook(
      id: 817,
      title: 'Tazkirul Quran',
      name: 'Tazkirul Quran',
      about: 'Wahiduddin Khan. Short reflections in English.',
      arabic: false,
    ),
  ];

  static TafsirBook book(int? id) =>
      books.firstWhere((book) => book.id == id, orElse: () => books.first);

  final http.Client _client;
  final DiskCache _cache;
  final Map<String, List<TafsirPassage>> _memory = {};
  final Map<String, Future<TafsirPassage>> _pending = {};

  /// The passage of [book] that explains a Hafs verse.
  Future<TafsirPassage> passage(TafsirBook book, int surah, int ayah) {
    final count = surah >= 1 && surah <= 114
        ? QuranService.surahList[surah - 1].numberOfAyahs
        : 0;
    if (ayah < 1 || ayah > count) {
      return Future.error(RangeError('No verse $surah:$ayah'));
    }
    return _pending.putIfAbsent('${book.id}/$surah/$ayah', () async {
      try {
        return await _find(book, surah, ayah, count);
      } finally {
        _pending.remove('${book.id}/$surah/$ayah');
      }
    });
  }

  static TafsirPassage? _covering(List<TafsirPassage> passages, int ayah) {
    for (final passage in passages) {
      if (passage.from <= ayah && ayah <= passage.to) return passage;
    }
    return null;
  }

  Future<TafsirPassage> _find(
    TafsirBook book,
    int surah,
    int ayah,
    int count,
  ) async {
    final key = '${book.id}/$surah';
    final file = '$key.json';
    var passages = _memory[key];
    if (passages == null) {
      passages = <TafsirPassage>[];
      final saved = await _cache.read(file);
      if (saved != null) {
        try {
          for (final item in jsonDecode(saved) as List<dynamic>) {
            final passage = TafsirPassage.fromJson(item);
            if (passage != null && passage.to <= count) passages.add(passage);
          }
        } catch (_) {
          passages.clear();
        }
      }
      _memory[key] = passages;
    }
    final known = _covering(passages, ayah);
    if (known != null) return known;

    try {
      var fetched = const <TafsirPassage>[];
      if (book.wholeSurah) {
        try {
          fetched = await _fetchSurah(book, surah, count);
        } on FormatException {
          // Fall through to the single verse.
        }
      }
      if (_covering(fetched, ayah) == null) {
        fetched = [await _fetchAyah(book, surah, ayah, count)];
      }
      for (final passage in fetched) {
        passages.removeWhere(
          (old) => old.from <= passage.to && passage.from <= old.to,
        );
        passages.add(passage);
      }
      passages.sort((a, b) => a.from.compareTo(b.from));
      await _cache.write(file, jsonEncode(passages));
      return _covering(passages, ayah)!;
    } catch (error) {
      debugPrint('Tafsir ${book.id} for $surah:$ayah unavailable ($error).');
      throw const TafsirUnavailable();
    }
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await _client
        .get(
          Uri.parse('https://api.quran.com/api/v4/tafsirs/$path'),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw FormatException('Tafsir source answered ${response.statusCode}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  static int? _ayahOf(Object? verseKey, int surah) {
    if (verseKey is! String) return null;
    final parts = verseKey.split(':');
    if (parts.length != 2 || int.tryParse(parts[0]) != surah) return null;
    return int.tryParse(parts[1]);
  }

  Future<TafsirPassage> _fetchAyah(
    TafsirBook book,
    int surah,
    int ayah,
    int count,
  ) async {
    final body = await _get('${book.id}/by_ayah/$surah:$ayah');
    final tafsir = body['tafsir'] as Map<String, dynamic>;
    final html = tafsir['text'];
    if (tafsir['resource_id'] != book.id ||
        html is! String ||
        html.trim().isEmpty) {
      throw const FormatException('No tafsir text for this verse');
    }
    // A tafsir may explain several verses in one piece and says which.
    final covered = [
      for (final key in (tafsir['verses'] as Map<String, dynamic>? ?? {}).keys)
        ?_ayahOf(key, surah),
    ]..sort();
    var from = ayah, to = ayah;
    if (covered.isNotEmpty && covered.first <= ayah && ayah <= covered.last) {
      from = covered.first;
      to = covered.last > count ? count : covered.last;
    }
    return TafsirPassage(from: from, to: to, html: html);
  }

  /// A whole surah in one request. Each piece explains the verses from its
  /// own up to the next piece (checked against single-verse answers).
  Future<List<TafsirPassage>> _fetchSurah(
    TafsirBook book,
    int surah,
    int count,
  ) async {
    final body = await _get('${book.id}/by_chapter/$surah?per_page=300');
    if ((body['pagination'] as Map<String, dynamic>?)?['next_page'] != null) {
      throw const FormatException('The surah came in more than one page');
    }
    final starts = <int, String>{};
    for (final item in body['tafsirs'] as List<dynamic>) {
      final ayah = _ayahOf(item['verse_key'], surah);
      final html = item['text'];
      if (item['resource_id'] != book.id ||
          ayah == null ||
          ayah < 1 ||
          ayah > count ||
          html is! String ||
          html.trim().isEmpty) {
        throw const FormatException('Unexpected tafsir entry');
      }
      starts[ayah] = html;
    }
    final order = starts.keys.toList()..sort();
    return [
      for (var index = 0; index < order.length; index++)
        TafsirPassage(
          from: order[index],
          to: index + 1 < order.length ? order[index + 1] - 1 : count,
          html: starts[order[index]]!,
        ),
    ];
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/quran_models.dart';

/// The loaded text of one mushaf.
class MushafText {
  MushafText({
    required this.edition,
    required this.basmalah,
    required this.surahs,
  });

  final MushafEdition edition;

  /// The basmalah as this mushaf writes it.
  final String basmalah;
  final List<List<MushafAyah>> surahs;

  List<MushafAyah> surah(int number) => surahs[number - 1];

  /// Whether the basmalah stands above [surah] instead of being its first
  /// numbered verse. At-Tawbah has none.
  bool basmalahAbove(int surah) =>
      surah != 9 && !(surah == 1 && surahs.first.first.text == basmalah);

  /// The verse of this mushaf that holds a Hafs verse.
  MushafAyah ayahForHafs(int surah, int hafsAyah) {
    final ayat = this.surah(surah);
    for (final ayah in ayat) {
      if (hafsAyah <= ayah.hafsTo) return ayah;
    }
    return ayat.last;
  }
}

/// The mushafs bundled with the app, published by the King Fahd Glorious
/// Quran Printing Complex. They are read from assets, so they work offline.
class MushafLibrary {
  MushafLibrary({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static final MushafLibrary instance = MushafLibrary();

  static const List<MushafEdition> editions = [
    MushafEdition(
      id: 'hafs_tajweed',
      textId: 'hafs',
      name: 'Hafs, tajweed colours',
      arabicName: 'مصحف التجويد',
      note: 'The Madinah Mushaf in Uthmani script, each rule in its colour.',
      ayahCount: 6236,
      tajweedColours: true,
    ),
    MushafEdition(
      id: 'hafs',
      textId: 'hafs',
      name: "Hafs from 'Asim",
      arabicName: 'حفص عن عاصم',
      note: 'The Madinah Mushaf in Uthmani script.',
      ayahCount: 6236,
    ),
    MushafEdition(
      id: 'warsh',
      textId: 'warsh',
      name: "Warsh from Nafi'",
      arabicName: 'ورش عن نافع',
      note: 'Read across North and West Africa.',
      ayahCount: 6214,
    ),
    MushafEdition(
      id: 'qaloon',
      textId: 'qaloon',
      name: "Qalun from Nafi'",
      arabicName: 'قالون عن نافع',
      note: 'Read in Libya and Tunisia.',
      ayahCount: 6214,
    ),
    MushafEdition(
      id: 'shouba',
      textId: 'shouba',
      name: "Shu'bah from 'Asim",
      arabicName: 'شعبة عن عاصم',
      note: "The other narrator from 'Asim.",
      ayahCount: 6236,
    ),
    MushafEdition(
      id: 'doori',
      textId: 'doori',
      name: "Al-Duri from Abu 'Amr",
      arabicName: 'الدوري عن أبي عمرو',
      note: 'Read in Sudan and parts of East Africa.',
      ayahCount: 6217,
    ),
    MushafEdition(
      id: 'soosi',
      textId: 'soosi',
      name: "Al-Susi from Abu 'Amr",
      arabicName: 'السوسي عن أبي عمرو',
      note: "The other narrator from Abu 'Amr.",
      ayahCount: 6217,
    ),
    MushafEdition(
      id: 'bazzi',
      textId: 'bazzi',
      name: 'Al-Bazzi from Ibn Kathir',
      arabicName: 'البزي عن ابن كثير',
      note: 'The reading of Makkah.',
      ayahCount: 6220,
    ),
    MushafEdition(
      id: 'qumbul',
      textId: 'qumbul',
      name: 'Qunbul from Ibn Kathir',
      arabicName: 'قنبل عن ابن كثير',
      note: 'The other narrator from Ibn Kathir.',
      ayahCount: 6220,
    ),
  ];

  static MushafEdition edition(String? id) => editions.firstWhere(
    (edition) => edition.id == id,
    orElse: () => editions.first,
  );

  static const _choiceKey = 'quran_edition';

  final AssetBundle _bundle;
  final Map<String, Future<MushafText>> _loaded = {};
  Future<List<List<int>>>? _colours;

  /// The mushaf the reader shows.
  final ValueNotifier<MushafEdition> current = ValueNotifier(editions.first);

  bool _restored = false;

  /// The mushaf chosen last time. It is read from storage once.
  Future<MushafEdition> restoreChoice() async {
    if (_restored) return current.value;
    final prefs = await SharedPreferences.getInstance();
    if (!_restored) {
      _restored = true;
      current.value = edition(prefs.getString(_choiceKey));
    }
    return current.value;
  }

  Future<void> choose(MushafEdition edition) async {
    _restored = true;
    current.value = edition;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_choiceKey, edition.id);
  }

  /// Reads a mushaf once and keeps it for the session.
  Future<MushafText> load(MushafEdition edition) {
    final pending = _loaded[edition.id];
    if (pending != null) return pending;
    final reading = _read(edition);
    _loaded[edition.id] = reading;
    // A failed read is not remembered, so opening the reader again retries.
    reading.then<void>(
      (_) {},
      onError: (Object _) {
        _loaded.remove(edition.id);
        _colours = null;
      },
    );
    return reading;
  }

  /// The files are plain JSON. They are not gzipped on purpose: the Android
  /// build unpacks any `.gz` asset and renames it, so the app could not find it.
  Future<Map<String, dynamic>> _json(String asset) async {
    final data = await _bundle.load(asset);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  Future<MushafText> _read(MushafEdition edition) async {
    final json = await _json(edition.asset);
    final surahRows = json['surahs'] as List<dynamic>;
    if (json['format'] != 1 ||
        json['id'] != edition.textId ||
        json['count'] != edition.ayahCount ||
        surahRows.length != 114) {
      throw const FormatException('This mushaf file is not the expected one');
    }
    final colours = edition.tajweedColours
        ? await (_colours ??= _readColours())
        : null;
    final surahs = <List<MushafAyah>>[];
    var running = 0;
    for (var s = 0; s < surahRows.length; s++) {
      final rows = surahRows[s] as List<dynamic>;
      final ayat = <MushafAyah>[];
      for (var a = 0; a < rows.length; a++) {
        final row = rows[a] as List<dynamic>;
        // Rows of a surah numbered as in Hafs carry no mapping.
        final mapped = row.length >= 5;
        ayat.add(
          MushafAyah(
            surah: s + 1,
            number: a + 1,
            text: row[0] as String,
            page: row[1] as int,
            juz: row[2] as int,
            hafsFrom: mapped ? row[3] as int : a + 1,
            hafsTo: mapped ? row[4] as int : a + 1,
            tajweed: colours == null ? const [] : colours[running],
          ),
        );
        running++;
      }
      if (ayat.isEmpty) throw const FormatException('A surah is empty');
      surahs.add(List.unmodifiable(ayat));
    }
    if (running != edition.ayahCount) {
      throw const FormatException('This mushaf file is incomplete');
    }
    return MushafText(
      edition: edition,
      basmalah: json['basmalah'] as String,
      surahs: List.unmodifiable(surahs),
    );
  }

  Future<List<List<int>>> _readColours() async {
    final json = await _json('asset/quran/hafs_tajweed.json');
    // The file numbers its rules; they are matched to ours by name.
    final ruleIndex = [
      for (final name in json['rules'] as List<dynamic>)
        TajweedRule.values.indexWhere((rule) => rule.dataName == name),
    ];
    // Stored surah by surah, used as one run of ayat in mushaf order.
    final ayat = [
      for (final surah in json['surahs'] as List<dynamic>)
        ...(surah as List<dynamic>).cast<List<dynamic>>(),
    ];
    if (json['format'] != 1 || ruleIndex.contains(-1) || ayat.length != 6236) {
      throw const FormatException('The tajweed colour file is not valid');
    }
    return [
      for (final flat in ayat)
        [
          for (var i = 0; i + 2 < flat.length; i += 3) ...[
            flat[i] as int,
            flat[i + 1] as int,
            ruleIndex[flat[i + 2] as int],
          ],
        ],
    ];
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../services/mushaf_library.dart';
import 'quran_models.dart';

/// How the player meets the ayahs. Every level asks about whole ayahs.
enum JourneyLevel {
  /// English: a question about the ayah, the ayah shown and heard.
  english,

  /// Arabic: the ayah is shown and the player picks its tafsir.
  arabic,

  /// Arabic, strong: the tafsir is shown and the player picks the ayah.
  strong;

  bool get isArabic => this != english;
}

/// A question of the English level, written for one ayah of a stop.
class JourneyQuestion {
  const JourneyQuestion({
    required this.ayah,
    required this.question,
    required this.answer,
    required this.wrong,
  });

  final int ayah;
  final String question;
  final String answer;
  final List<String> wrong;
}

/// A few ayahs of the surah: they are read with their meaning, then asked
/// about.
class JourneyStop {
  const JourneyStop({
    required this.id,
    required this.en,
    required this.ar,
    required this.first,
    required this.last,
    required this.questions,
  });

  final String id;
  final String en;
  final String ar;
  final int first;
  final int last;
  final List<JourneyQuestion> questions;

  String title(bool arabic) => arabic ? ar : en;
  Iterable<int> get ayahs =>
      Iterable.generate(last - first + 1, (i) => first + i);
}

/// What the player finds at the end of a story: a thing named in its ayahs.
class JourneyKeepsake {
  const JourneyKeepsake({
    required this.id,
    required this.en,
    required this.ar,
    required this.ayah,
  });

  /// coin, vine, ship or iron.
  final String id;
  final String en;
  final String ar;

  /// The ayah that names it.
  final int ayah;

  String name(bool arabic) => arabic ? ar : en;
}

/// One of the four stories, or the ayahs between two of them.
class JourneySection {
  const JourneySection({
    required this.id,
    required this.isStory,
    required this.en,
    required this.ar,
    required this.art,
    required this.stops,
    this.number,
    this.keepsake,
    this.blessingEn,
    this.blessingAr,
  });

  final String id;
  final bool isStory;
  final String en;
  final String ar;

  /// The blessing said after the names in the title, where it names
  /// prophets: "peace be upon them".
  final String? blessingEn;
  final String? blessingAr;

  /// The picture drawn for it: book, cave, gardens, rain, sea or wall.
  final String art;
  final List<JourneyStop> stops;

  /// 1 to 4 for a story.
  final int? number;
  final JourneyKeepsake? keepsake;

  String title(bool arabic) => arabic ? ar : en;
  String? blessing(bool arabic) => arabic ? blessingAr : blessingEn;

  /// The title with its blessing, for a line of text.
  String full(bool arabic) {
    final said = blessing(arabic);
    if (said == null) return title(arabic);
    return arabic ? '$ar $said' : '$en ($said)';
  }

  int get first => stops.first.first;
  int get last => stops.last.last;
}

/// What one ayah means, copied from its sources letter for letter.
class JourneyAyah {
  const JourneyAyah({
    required this.en,
    required this.ar,
    this.notes = const [],
    this.skip = false,
  });

  /// The Saheeh International translation, with its footnote marks.
  final String en;

  /// The translation's footnotes for this ayah, each opening with its mark.
  final List<String> notes;

  /// Al-Tafsir al-Muyassar. Ayahs it explains together carry the same text.
  final String ar;

  /// Whether the Arabic levels leave the ayah out.
  final bool skip;
}

/// A word of an ayah, or a few, with the meaning As-Siraj gives.
class JourneyWord {
  const JourneyWord({
    required this.word,
    required this.span,
    required this.meaning,
  });

  /// Where the words stand in the ayah, and how many they are.
  final int word;
  final int span;
  final String meaning;
}

/// Ayahs the Arabic levels show and ask about as one: a single ayah, or the
/// few that al-Tafsir al-Muyassar explains in one text.
class JourneyPassage {
  const JourneyPassage(this.first, this.last);

  final int first;
  final int last;

  bool get isOne => first == last;
  Iterable<int> get ayahs =>
      Iterable.generate(last - first + 1, (i) => first + i);

  @override
  bool operator ==(Object other) =>
      other is JourneyPassage && other.first == first && other.last == last;

  @override
  int get hashCode => Object.hash(first, last);

  @override
  String toString() => isOne ? '$first' : '$first-$last';
}

/// A work the meanings are copied from, as QuranEnc.com names it.
class JourneySource {
  const JourneySource({
    required this.key,
    required this.en,
    required this.ar,
    required this.byEn,
    required this.byAr,
    required this.version,
    required this.date,
    required this.url,
  });

  factory JourneySource.fromJson(Map<String, dynamic> json) => JourneySource(
    key: json['key'] as String,
    en: json['en'] as String,
    ar: json['ar'] as String,
    byEn: json['byEn'] as String,
    byAr: json['byAr'] as String,
    version: json['version'] as String,
    date: json['date'] as String,
    url: json['url'] as String,
  );

  final String key;
  final String en;
  final String ar;
  final String byEn;
  final String byAr;
  final String version;

  /// When QuranEnc last changed it, as year-month-day.
  final String date;
  final String url;

  String title(bool arabic) => arabic ? ar : en;
  String by(bool arabic) => arabic ? byAr : byEn;
}

/// The whole journey through Surah Al-Kahf, with the surah's own text.
class Journey {
  Journey({
    required this.sections,
    required this.ayahs,
    required this.words,
    required this.verses,
    required this.basmalah,
    required this.translation,
    required this.tafsir,
    required this.wordSource,
  }) : stops = [for (final section in sections) ...section.stops],
       passages = _passages(ayahs);

  static const surah = 18;

  final List<JourneySection> sections;
  final List<JourneyAyah> ayahs;
  final Map<int, List<JourneyWord>> words;

  /// The bundled Hafs text, ayah 1 first. Never retyped anywhere.
  final List<String> verses;
  final String basmalah;

  /// Where the English meanings, the Arabic ones and the word meanings are
  /// copied from.
  final JourneySource translation;
  final JourneySource tafsir;
  final JourneySource wordSource;

  /// Every stop in walking order.
  final List<JourneyStop> stops;

  /// The surah as the Arabic levels divide it, in order.
  final List<JourneyPassage> passages;

  static List<JourneyPassage> _passages(List<JourneyAyah> ayahs) {
    final out = <JourneyPassage>[];
    for (var ayah = 1; ayah <= ayahs.length; ayah++) {
      if (out.isNotEmpty && ayahs[out.last.last - 1].ar == ayahs[ayah - 1].ar) {
        out[out.length - 1] = JourneyPassage(out.last.first, ayah);
      } else {
        out.add(JourneyPassage(ayah, ayah));
      }
    }
    return out;
  }

  static Journey? _read;

  /// Lets a test hand over a journey it read from disk.
  @visibleForTesting
  static set cached(Journey? journey) => _read = journey;

  /// Kept as the object, not its future: a future made in one widget test's
  /// zone never completes in the next test.
  static Future<Journey> load({AssetBundle? bundle}) async {
    final kept = _read;
    if (kept != null) return kept;
    final text = await (bundle ?? rootBundle).loadString(
      'asset/journey/kahf.json',
    );
    final mushaf = await MushafLibrary.instance.load(
      MushafLibrary.edition('hafs'),
    );
    return _read = Journey.fromJson(jsonDecode(text) as Map<String, dynamic>, [
      for (final ayah in mushaf.surah(surah)) ayah.text,
    ], basmalah: mushaf.basmalah);
  }

  factory Journey.fromJson(
    Map<String, dynamic> json,
    List<String> verses, {
    String basmalah = '',
  }) {
    List<String> strings(Object? value) => [
      for (final item in value as List) item as String,
    ];
    final sources = json['sources'] as Map<String, dynamic>;
    JourneySource source(String use) =>
        JourneySource.fromJson(sources[use] as Map<String, dynamic>);
    return Journey(
      verses: verses,
      basmalah: basmalah,
      translation: source('translation'),
      tafsir: source('tafsir'),
      wordSource: source('words'),
      sections: [
        for (final section in json['sections'] as List)
          JourneySection(
            id: section['id'] as String,
            isStory: section['kind'] == 'story',
            en: section['en'] as String,
            ar: section['ar'] as String,
            art: section['art'] as String,
            number: section['number'] as int?,
            blessingEn: section['blessingEn'] as String?,
            blessingAr: section['blessingAr'] as String?,
            keepsake: section['keepsake'] == null
                ? null
                : JourneyKeepsake(
                    id: section['keepsake']['id'] as String,
                    en: section['keepsake']['en'] as String,
                    ar: section['keepsake']['ar'] as String,
                    ayah: section['keepsake']['ayah'] as int,
                  ),
            stops: [
              for (final stop in section['stops'] as List)
                JourneyStop(
                  id: stop['id'] as String,
                  en: stop['en'] as String,
                  ar: stop['ar'] as String,
                  first: stop['first'] as int,
                  last: stop['last'] as int,
                  questions: [
                    for (final question in stop['questions'] as List)
                      JourneyQuestion(
                        ayah: question['ayah'] as int,
                        question: question['q'] as String,
                        answer: question['a'] as String,
                        wrong: strings(question['w']),
                      ),
                  ],
                ),
            ],
          ),
      ],
      ayahs: [
        for (final ayah in json['ayahs'] as List)
          JourneyAyah(
            en: ayah['en'] as String,
            ar: ayah['ar'] as String,
            notes: ayah['notes'] == null ? const [] : strings(ayah['notes']),
            skip: ayah['skip'] == true,
          ),
      ],
      words: {
        for (final entry in (json['words'] as Map<String, dynamic>).entries)
          int.parse(entry.key): [
            for (final word in entry.value as List)
              JourneyWord(
                word: word['word'] as int,
                span: word['span'] as int? ?? 1,
                meaning: word['meaning'] as String,
              ),
          ],
      },
    );
  }

  JourneySection sectionOf(JourneyStop stop) =>
      sections.firstWhere((section) => section.stops.contains(stop));

  JourneyAyah meaning(int ayah) => ayahs[ayah - 1];

  /// The ayah as the mushaf writes it, whole.
  String verse(int ayah) => verses[ayah - 1];

  /// The ayah followed by its end mark, as the reader shows it: a no-break
  /// space and the number, which the mushaf's font draws as the ornament.
  String verseWithMark(int ayah) => '${verse(ayah)}\u00A0${arabicDigits(ayah)}';

  /// The passage [ayah] belongs to in the Arabic levels.
  JourneyPassage passageOf(int ayah) =>
      passages.firstWhere((p) => p.first <= ayah && ayah <= p.last);

  /// The passages of a stop, in order. A passage never crosses a stop.
  List<JourneyPassage> passagesOf(JourneyStop stop) => [
    for (final passage in passages)
      if (passage.first >= stop.first && passage.last <= stop.last) passage,
  ];

  /// The ayahs of a passage, whole, each with its end mark.
  String passageText(JourneyPassage passage) =>
      [for (final ayah in passage.ayahs) verseWithMark(ayah)].join(' ');

  /// Whether the Arabic levels leave a passage out.
  bool skips(JourneyPassage passage) =>
      passage.ayahs.any((ayah) => meaning(ayah).skip);

  /// The words of the mushaf a word meaning explains.
  String wordText(int ayah, JourneyWord word) {
    final all = verse(ayah).split(' ');
    final end = (word.word + word.span).clamp(0, all.length);
    return all.sublist(word.word.clamp(0, end), end).join(' ');
  }

  /// The stops whose lantern must be lit before [stop] opens: all before it.
  JourneyStop? next(Set<String> done) {
    for (final stop in stops) {
      if (!done.contains(stop.id)) return stop;
    }
    return null;
  }

  bool isOpen(JourneyStop stop, Set<String> done) {
    final upcoming = next(done);
    return done.contains(stop.id) || upcoming == stop;
  }

  bool sectionDone(JourneySection section, Set<String> done) =>
      section.stops.every((stop) => done.contains(stop.id));

  /// The keepsakes of the stories walked to their end, in story order.
  List<JourneyKeepsake> found(Set<String> done) => [
    for (final section in sections)
      if (section.keepsake != null && sectionDone(section, done))
        section.keepsake!,
  ];

  List<JourneyKeepsake> get keepsakes => [
    for (final section in sections)
      if (section.keepsake != null) section.keepsake!,
  ];
}

/// Bare letters of Quran text: no marks, one alif. The same rule as
/// `letters` in tools/make_kahf_journey.py.
String journeyLetters(String text) {
  final out = StringBuffer();
  for (final rune in text.runes) {
    if ((rune >= 0x064B && rune <= 0x065F) ||
        rune == 0x0670 ||
        (rune >= 0x06D6 && rune <= 0x06ED) ||
        (rune >= 0x08D3 && rune <= 0x08FF)) {
      continue;
    }
    if (rune == 0x0640 || rune == 0x00A0) continue;
    if (rune == 0x0671 || rune == 0x0623 || rune == 0x0625 || rune == 0x0622) {
      out.write('ا');
      continue;
    }
    out.writeCharCode(rune);
  }
  return out.toString();
}

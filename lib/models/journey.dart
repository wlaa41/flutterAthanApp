import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../services/mushaf_library.dart';
import 'quran_models.dart';

/// How the player meets the ayahs. Every level asks about whole ayahs.
enum JourneyLevel {
  /// English: a question about the ayah, the ayah shown and heard.
  english,

  /// Arabic: the ayah is shown and the player picks its meaning.
  arabic,

  /// Arabic, strong: the meaning is shown and the player picks the ayah.
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

/// A few ayahs of the surah: a part of the story, then questions about it.
class JourneyStop {
  const JourneyStop({
    required this.id,
    required this.en,
    required this.ar,
    required this.first,
    required this.last,
    required this.storyEn,
    required this.storyAr,
    required this.questions,
  });

  final String id;
  final String en;
  final String ar;
  final int first;
  final int last;
  final List<String> storyEn;
  final List<String> storyAr;
  final List<JourneyQuestion> questions;

  String title(bool arabic) => arabic ? ar : en;
  List<String> story(bool arabic) => arabic ? storyAr : storyEn;
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
    required this.first,
    required this.last,
    required this.line,
  });

  /// coin, vine, ship or iron.
  final String id;
  final String en;
  final String ar;

  /// Where the surah names it: the ayah and its words, first to last.
  final int ayah;
  final int first;
  final int last;

  /// Those words in English.
  final String line;

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
  });

  final String id;
  final bool isStory;
  final String en;
  final String ar;

  /// The picture drawn for it: book, cave, gardens, rain, sea or wall.
  final String art;
  final List<JourneyStop> stops;

  /// 1 to 4 for a story.
  final int? number;
  final JourneyKeepsake? keepsake;

  String title(bool arabic) => arabic ? ar : en;
  int get first => stops.first.first;
  int get last => stops.last.last;
}

/// A short meaning of one ayah, and whether the Arabic levels leave it out.
class JourneyAyah {
  const JourneyAyah({required this.en, required this.ar, this.skip = false});

  final String en;
  final String ar;
  final bool skip;
}

/// A harder word of an ayah with its meaning, for the optional help.
class JourneyWord {
  const JourneyWord({
    required this.word,
    required this.span,
    required this.meaning,
  });

  final int word;
  final int span;
  final String meaning;
}

/// The whole journey through Surah Al-Kahf, with the surah's own text.
class Journey {
  Journey({
    required this.sections,
    required this.ayahs,
    required this.words,
    required this.verses,
    required this.basmalah,
  }) : stops = [for (final section in sections) ...section.stops];

  static const surah = 18;

  final List<JourneySection> sections;
  final List<JourneyAyah> ayahs;
  final Map<int, List<JourneyWord>> words;

  /// The bundled Hafs text, ayah 1 first. Never retyped anywhere.
  final List<String> verses;
  final String basmalah;

  /// Every stop in walking order.
  final List<JourneyStop> stops;

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
    return Journey(
      verses: verses,
      basmalah: basmalah,
      sections: [
        for (final section in json['sections'] as List)
          JourneySection(
            id: section['id'] as String,
            isStory: section['kind'] == 'story',
            en: section['en'] as String,
            ar: section['ar'] as String,
            art: section['art'] as String,
            number: section['number'] as int?,
            keepsake: section['keepsake'] == null
                ? null
                : JourneyKeepsake(
                    id: section['keepsake']['id'] as String,
                    en: section['keepsake']['en'] as String,
                    ar: section['keepsake']['ar'] as String,
                    ayah: section['keepsake']['ayah'] as int,
                    first: section['keepsake']['first'] as int,
                    last: section['keepsake']['last'] as int,
                    line: section['keepsake']['line'] as String,
                  ),
            stops: [
              for (final stop in section['stops'] as List)
                JourneyStop(
                  id: stop['id'] as String,
                  en: stop['en'] as String,
                  ar: stop['ar'] as String,
                  first: stop['first'] as int,
                  last: stop['last'] as int,
                  storyEn: strings(stop['storyEn']),
                  storyAr: strings(stop['storyAr']),
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

  /// The ayah as the mushaf writes it.
  String verse(int ayah) => verses[ayah - 1];

  /// The ayah followed by its end mark, as the reader shows it.
  String verseWithMark(int ayah) => '${verse(ayah)} ${arabicDigits(ayah)}';

  /// The opening words of a long ayah, for a choice that has to stay short.
  String verseOpening(int ayah, {int words = 16}) {
    final all = verse(ayah).split(' ');
    if (all.length <= words + 2) return verseWithMark(ayah);
    return '${all.take(words).join(' ')} …';
  }

  /// The closing words of a long ayah, for the cue before a recitation.
  String verseEnding(int ayah, {int words = 14}) {
    final all = verse(ayah).split(' ');
    if (all.length <= words + 2) return verseWithMark(ayah);
    return '… ${all.skip(all.length - words).join(' ')} ${arabicDigits(ayah)}';
  }

  /// Some words of an ayah, first to last.
  String verseWords(int ayah, int first, int last) {
    final all = verse(ayah).split(' ');
    final end = (last + 1).clamp(0, all.length);
    return all.sublist(first.clamp(0, end), end).join(' ');
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

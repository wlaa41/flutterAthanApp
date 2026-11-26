import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_pro/models/journey.dart';
import 'package:flutter_pro/services/journey_progress.dart';
import 'package:flutter_pro/services/journey_round.dart';
import 'package:flutter_test/flutter_test.dart';

import 'journey_support.dart';

/// The words of an English text, as tools/make_kahf_journey.py reads them to
/// match a choice against the translation: no footnote marks, no punctuation,
/// the letters as written, accents and square brackets included.
List<String> _words(String text) => [
  for (final match in RegExp(
    r"[\[\]\w’']+",
    unicode: true,
  ).allMatches(text.replaceAll(RegExp(r'\[\d+\]'), '').toLowerCase()))
    match[0]!.replaceAll(RegExp(r"^['’]+|['’]+$"), ''),
].where((word) => word.isNotEmpty).toList();

bool _holds(List<String> text, List<String> phrase) {
  for (var i = 0; i + phrase.length <= text.length; i++) {
    var same = true;
    for (var j = 0; j < phrase.length && same; j++) {
      same = text[i + j] == phrase[j];
    }
    if (same) return true;
  }
  return false;
}

const _determiners = {
  'a',
  'an',
  'the',
  'their',
  'his',
  'its',
  'this',
  'that',
  'to',
};

void main() {
  final journey = readJourney();
  final translation = readSource('english_saheeh');
  final tafsir = readSource('arabic_moyassar');
  final wordBook = readSource('arabic_seraj');
  final english = [for (final row in translation) _words(row['translation'])];

  /// The ayahs whose translation holds [choice] word for word. A choice may
  /// open with a small word of ours ("their fish" for "our fish").
  Set<int> whereSaid(String choice) {
    final want = _words(choice);
    Set<int> search(List<String> phrase) => {
      for (var i = 0; i < english.length; i++)
        if (_holds(english[i], phrase)) i + 1,
    };
    final found = search(want);
    if (found.isEmpty && want.length > 1 && _determiners.contains(want.first)) {
      return search(want.sublist(1));
    }
    return found;
  }

  test('the journey walks every ayah of the surah once, in order', () {
    expect(journey.verses, hasLength(110));
    expect(journey.ayahs, hasLength(110));
    expect(journey.stops, hasLength(28));
    var expected = 1;
    for (final stop in journey.stops) {
      expect(stop.first, expected, reason: stop.id);
      expect(stop.last, greaterThanOrEqualTo(stop.first));
      expected = stop.last + 1;
    }
    expect(expected, 111);
    expect({for (final stop in journey.stops) stop.id}, hasLength(28));
  });

  group('what explains the Quran is copied from its sources', () {
    test('the files are the ones the manifest records', () {
      final manifest =
          jsonDecode(
                File('tools/sources/quranenc/manifest.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final sources = manifest['sources'] as List;
      expect(
        [for (final source in sources) source['key']],
        ['english_saheeh', 'arabic_moyassar', 'arabic_seraj'],
      );
      for (final source in sources) {
        final file = File('tools/sources/quranenc/${source['key']}_18.json');
        expect(
          sha256.convert(file.readAsBytesSync()).toString(),
          source['sha256'],
          reason: source['key'] as String,
        );
      }
      expect(journey.translation.key, 'english_saheeh');
      expect(journey.tafsir.key, 'arabic_moyassar');
      expect(journey.wordSource.key, 'arabic_seraj');
      for (final source in [
        journey.translation,
        journey.tafsir,
        journey.wordSource,
      ]) {
        final recorded = sources.firstWhere((s) => s['key'] == source.key);
        expect(source.version, recorded['version']);
        expect(source.date, recorded['date']);
        expect(source.en, recorded['en']);
        expect(source.ar, recorded['ar']);
        expect(source.url, startsWith('https://quranenc.com/'));
      }
    });

    test("the sources' ayahs are the ayahs of the bundled mushaf", () {
      for (final source in [translation, tafsir, wordBook]) {
        expect(source, hasLength(110));
        for (var ayah = 1; ayah <= 110; ayah++) {
          final row = source[ayah - 1];
          expect(row['sura'], '18');
          expect(row['aya'], '$ayah');
          expect(
            journeyLetters(row['arabic_text'] as String).replaceAll(' ', ''),
            journeyLetters(journey.verse(ayah)).replaceAll(' ', ''),
            reason: 'ayah $ayah',
          );
        }
      }
    });

    test('every English meaning is the translation, letter for letter', () {
      var footnotes = 0;
      for (var ayah = 1; ayah <= 110; ayah++) {
        final meaning = journey.meaning(ayah);
        final row = translation[ayah - 1];
        expect(meaning.en, row['translation'], reason: 'ayah $ayah');
        expect(
          meaning.notes.join('\n'),
          row['footnotes'] ?? '',
          reason: 'ayah $ayah',
        );
        footnotes += meaning.notes.length;
        // Each footnote mark in the text has its footnote, in order.
        expect(
          [
            for (final mark in RegExp(r'\[\d+\]').allMatches(meaning.en))
              mark[0],
          ],
          [for (final note in meaning.notes) note.split(' ').first],
          reason: 'ayah $ayah',
        );
      }
      expect(footnotes, 26);
    });

    test(
      'every Arabic meaning is al-Tafsir al-Muyassar, letter for letter',
      () {
        for (var ayah = 1; ayah <= 110; ayah++) {
          expect(
            journey.meaning(ayah).ar,
            tafsir[ayah - 1]['translation'],
            reason: 'ayah $ayah',
          );
          expect(tafsir[ayah - 1]['footnotes'] ?? '', isEmpty);
        }
      },
    );

    test(
      'every word meaning is a line of As-Siraj, on a word of the mushaf',
      () {
        // "the word: its meaning." for each ayah, as the source writes them.
        final lines = <int, Map<String, String>>{};
        var total = 0;
        for (var ayah = 1; ayah <= 110; ayah++) {
          for (final line
              in (wordBook[ayah - 1]['translation'] as String)
                  .split('\n')
                  .where((line) => line.isNotEmpty)) {
            final cut = line.indexOf(': ');
            expect(cut, greaterThan(0), reason: line);
            (lines[ayah] ??= {})[line.substring(0, cut)] = line.substring(
              cut + 2,
            );
            total++;
          }
        }
        expect(total, 148);
        // The mushaf spells with its own old letters (an alif left out, a waw
        // or a ya where the plain spelling has an alif, the hamza seated
        // differently): compare the consonants, which never differ.
        String frame(String text) =>
            journeyLetters(text).replaceAll(RegExp('[اويىءؤئ]'), '');
        var shown = 0;
        for (final entry in journey.words.entries) {
          final ayah = entry.key;
          final words = journey.verse(ayah).split(' ');
          var before = -1;
          for (final word in entry.value) {
            shown++;
            expect(word.word, greaterThan(before), reason: 'ayah $ayah');
            before = word.word;
            expect(word.span, greaterThan(0));
            expect(word.word + word.span, lessThanOrEqualTo(words.length));
            final text = journey.wordText(ayah, word);
            expect(journey.verse(ayah), contains(text));
            // The line is the source's: under this ayah, or (for one line
            // the source files an ayah early) under the ayah before it.
            final from = [
              ...?lines[ayah]?.entries,
              ...?lines[ayah - 1]?.entries,
            ].where((line) => line.value == word.meaning).toList();
            expect(from, isNotEmpty, reason: '$ayah: ${word.meaning}');
            expect(
              from.any((line) => frame(line.key) == frame(text)),
              isTrue,
              reason: '$ayah: $text',
            );
          }
        }
        // One line is left out: its word and its meaning do not belong
        // together (see WORD_LEFT_OUT in tools/make_kahf_journey.py).
        expect(shown, 147);
        // The source files the word of ayah 109 under ayah 108. The game
        // shows it where the word is. (No vowelled Arabic is typed here: the
        // lines are looked up by their bare letters.)
        String line(int ayah, String bare) => lines[ayah]!.entries
            .singleWhere((entry) => journeyLetters(entry.key) == bare)
            .value;
        expect(journey.words[108]!.single.meaning, line(108, 'حولا'));
        expect(journey.words[109]!.single.meaning, line(108, 'لنفد'));
        expect(
          journeyLetters(journey.wordText(109, journey.words[109]!.single)),
          'لنفد',
        );
        expect(journeyLetters(journey.verse(108)), isNot(contains('لنفد')));
        expect(journeyLetters(journey.verse(109)), contains('لنفد'));
      },
    );

    test('ayahs the tafsir explains in one text are one passage', () {
      expect(
        [
          for (final passage in journey.passages)
            if (!passage.isOne) '$passage',
        ],
        ['2-3', '23-24', '35-36', '39-41'],
      );
      expect(
        journey.passages.fold<int>(0, (sum, p) => sum + p.ayahs.length),
        110,
      );
      for (final passage in journey.passages) {
        expect({
          for (final ayah in passage.ayahs) journey.meaning(ayah).ar,
        }, hasLength(1));
        expect(journey.passageOf(passage.last), passage);
      }
      // A passage never crosses from one stop into the next.
      expect([
        for (final stop in journey.stops) ...journey.passagesOf(stop),
      ], journey.passages);
      // No tafsir text is the meaning of two passages.
      expect({
        for (final p in journey.passages) journey.meaning(p.first).ar,
      }, hasLength(journey.passages.length));
    });
  });

  group('the Quran is shown whole and exact', () {
    test('an ayah is the bundled text with its end mark, never a part', () {
      for (var ayah = 1; ayah <= 110; ayah++) {
        final shown = journey.verseWithMark(ayah);
        expect(shown, startsWith(journey.verse(ayah)));
        expect(
          shown.substring(journey.verse(ayah).length),
          matches(RegExp('^ [٠-٩]+\$')),
        );
      }
      expect(
        journey.passageText(const JourneyPassage(39, 41)),
        [39, 40, 41].map(journey.verseWithMark).join(' '),
      );
      expect(journey.verse(19).split(' '), hasLength(38));
      expect(
        journey.passageText(const JourneyPassage(19, 19)),
        journey.verseWithMark(19),
      );
    });

    test('nothing the game holds or asks carries a cut mark', () {
      final content = File('asset/journey/kahf.json').readAsStringSync();
      expect(content.contains('…'), isFalse);
      expect(content.contains('...'), isFalse);
      // The game's own file holds no Quran text at all: the ayahs come from
      // the bundled mushaf, by number.
      expect(RegExp('[ٱۡۖ-ۭ]').hasMatch(content), isFalse);
      for (final level in [JourneyLevel.arabic, JourneyLevel.strong]) {
        for (final stop in journey.stops) {
          final round = JourneyRounds.build(
            journey,
            stop,
            level,
            random: Random(4),
          );
          for (final item in round) {
            for (final text in [item.prompt, ...item.choices]) {
              expect(text.contains('…'), isFalse);
            }
          }
        }
      }
    });
  });

  group('the English questions add nothing to the surah', () {
    test('the right choice is in the translation of the ayah asked about', () {
      var questions = 0;
      for (final stop in journey.stops) {
        expect(stop.questions.length, inInclusiveRange(3, 4), reason: stop.id);
        expect(
          {for (final q in stop.questions) q.question},
          hasLength(stop.questions.length),
          reason: stop.id,
        );
        for (final question in stop.questions) {
          questions++;
          expect(question.ayah, inInclusiveRange(stop.first, stop.last));
          expect(question.question, endsWith('?'));
          expect(
            whereSaid(question.answer),
            contains(question.ayah),
            reason: '${stop.id}: ${question.answer}',
          );
        }
      }
      expect(questions, 108);
    });

    test('every other choice is in the translation of another ayah', () {
      // Three questions set a word of the ayah against another word of the
      // same ayah (awake and asleep): there the first wrong choice is inside.
      final inside = <String>[];
      for (final stop in journey.stops) {
        for (final question in stop.questions) {
          expect(question.wrong, hasLength(2));
          expect({question.answer, ...question.wrong}, hasLength(3));
          for (final wrong in question.wrong) {
            final found = whereSaid(wrong);
            expect(found, isNotEmpty, reason: '${stop.id}: $wrong');
            if (found.contains(question.ayah)) {
              expect(wrong, question.wrong.first);
              inside.add('${question.ayah}: $wrong');
            }
          }
        }
      }
      expect(inside, [
        '18: Asleep',
        '46: The enduring good deeds',
        '50: The angels',
        '96: Molten copper',
      ]);
    });

    test('the prophets are named with a blessing', () {
      final stems = [
        for (final stop in journey.stops)
          for (final question in stop.questions) question.question,
      ];
      for (final stem in stems) {
        for (final name in ['Musa', 'al-Khidr', 'Adam']) {
          if (stem.contains(name)) {
            expect(stem, contains('$name (peace be upon him)'), reason: stem);
          }
        }
        if (stem.contains('Prophet')) {
          expect(
            stem,
            contains('the Prophet (peace and blessings be upon him)'),
          );
        }
      }
      expect(stems.where((s) => s.contains('Musa')), isNotEmpty);
      expect(stems.where((s) => s.contains('Prophet')), isNotEmpty);
      final khidr = journey.sections.firstWhere((s) => s.id == 'khidr');
      expect(khidr.full(false), 'Musa and Al-Khidr (peace be upon them)');
      expect(khidr.full(true), 'موسى والخضر عليهما السلام');
      expect(journey.sections.first.full(false), 'The Opening');
    });
  });

  test('four stories, each with a keepsake its own ayahs mention', () {
    final stories = journey.sections.where((s) => s.isStory).toList();
    expect([for (final s in stories) s.number], [1, 2, 3, 4]);
    expect(
      [for (final s in stories) s.keepsake!.id],
      ['coin', 'vine', 'ship', 'iron'],
    );
    expect([for (final s in stories) s.keepsake!.ayah], [19, 32, 79, 96]);
    for (final story in stories) {
      final keepsake = story.keepsake!;
      expect(keepsake.ayah, inInclusiveRange(story.first, story.last));
      // The translation of that ayah names the thing.
      expect(whereSaid(keepsake.en), contains(keepsake.ayah));
    }
    for (final bridge in journey.sections.where((s) => !s.isStory)) {
      expect(bridge.keepsake, isNull);
      expect(bridge.number, isNull);
    }
  });

  test('every text is filled in and free of long dashes', () {
    final texts = <String>[
      for (final ayah in journey.ayahs) ...[ayah.en, ayah.ar, ...ayah.notes],
      for (final words in journey.words.values)
        for (final word in words) word.meaning,
      for (final section in journey.sections) ...[
        section.en,
        section.ar,
        if (section.keepsake != null) ...[
          section.keepsake!.en,
          section.keepsake!.ar,
        ],
        for (final stop in section.stops) ...[
          stop.en,
          stop.ar,
          for (final q in stop.questions) ...[q.question, q.answer, ...q.wrong],
        ],
      ],
    ];
    for (final text in texts) {
      expect(text.trim(), text);
      expect(text, isNotEmpty);
      expect(text.contains('—') || text.contains('–'), isFalse);
    }
  });

  test('the English level asks the questions written for the stop', () {
    for (final stop in journey.stops) {
      final round = JourneyRounds.build(
        journey,
        stop,
        JourneyLevel.english,
        random: Random(7),
      );
      expect(round, hasLength(stop.questions.length), reason: stop.id);
      for (var i = 0; i < round.length; i++) {
        final item = round[i];
        final question = stop.questions[i];
        expect(item.prompt, question.question);
        expect(item.choices, hasLength(3));
        expect(item.choices.toSet(), hasLength(3));
        expect(item.choices[item.correct], question.answer);
        expect(item.passage, JourneyPassage(question.ayah, question.ayah));
        expect(item.ayah, question.ayah);
      }
    }
  });

  test('the Arabic levels ask about whole ayahs, with the tafsir as it is', () {
    for (final level in [JourneyLevel.arabic, JourneyLevel.strong]) {
      for (final stop in journey.stops) {
        final section = journey.sectionOf(stop);
        for (final seed in [1, 2, 3]) {
          final round = JourneyRounds.build(
            journey,
            stop,
            level,
            random: Random(seed),
          );
          expect(round.length, inInclusiveRange(2, 4), reason: stop.id);
          expect({
            for (final item in round) item.passage,
          }, hasLength(round.length));
          for (final item in round) {
            final passage = item.passage;
            expect(journey.passages, contains(passage));
            expect(journey.skips(passage), isFalse);
            expect(item.choices, hasLength(3));
            expect(item.choices.toSet(), hasLength(3), reason: '$passage');
            expect(item.correct, inInclusiveRange(0, 2));
            if (item.review) {
              expect(passage.last, lessThan(stop.first));
              expect(passage.first, greaterThanOrEqualTo(section.first));
            } else {
              expect(passage.first, greaterThanOrEqualTo(stop.first));
              expect(passage.last, lessThanOrEqualTo(stop.last));
            }
            final meaning = tafsir[passage.first - 1]['translation'] as String;
            if (level == JourneyLevel.arabic) {
              // The ayah is shown; the three choices are tafsir texts, each
              // exactly as the source has it.
              expect(item.prompt, isEmpty);
              expect(item.choices[item.correct], meaning);
              for (final choice in item.choices) {
                expect(
                  tafsir.where((row) => row['translation'] == choice),
                  isNotEmpty,
                );
              }
            } else {
              // The tafsir is shown; the three choices are whole ayahs.
              expect(item.prompt, meaning);
              expect(item.choicePassages[item.correct], passage);
              expect(item.choicePassages, hasLength(3));
              for (var i = 0; i < 3; i++) {
                final other = item.choicePassages[i];
                expect(journey.passages, contains(other));
                expect(journey.skips(other), isFalse);
                expect(other.first, greaterThanOrEqualTo(section.first));
                expect(other.last, lessThanOrEqualTo(section.last));
                expect(item.choices[i], journey.passageText(other));
              }
            }
          }
        }
      }
    }
  });

  test(
    'a short stop brings back ayahs of earlier stops, missed ones first',
    () {
      final stop = journey.stops.firstWhere((s) => s.first == 17);
      final round = JourneyRounds.build(
        journey,
        stop,
        JourneyLevel.arabic,
        random: Random(3),
        missed: {10: 2, 14: 1},
      );
      expect([for (final item in round) item.ayah], [17, 18, 10, 14]);
      expect(
        [for (final item in round) item.review],
        [false, false, true, true],
      );
    },
  );

  test('a long stop asks four ayahs, the missed ones among them', () {
    final stop = journey.stops.firstWhere((s) => s.first == 54);
    final round = JourneyRounds.build(
      journey,
      stop,
      JourneyLevel.strong,
      random: Random(5),
      missed: {59: 1, 55: 3},
    );
    final asked = [for (final item in round) item.ayah];
    expect(asked, hasLength(4));
    expect(asked, containsAll([55, 59]));
    expect(asked, [...asked]..sort());
  });

  test('a stop with a passage asks the passage once, by its first ayah', () {
    final stop = journey.stops.firstWhere((s) => s.first == 37);
    final round = JourneyRounds.build(
      journey,
      stop,
      JourneyLevel.arabic,
      random: Random(2),
      missed: {39: 1},
    );
    // Ayahs 37, 38 and the passage 39 to 41; one more from an earlier stop.
    expect(
      [
        for (final item in round.where((item) => !item.review))
          '${item.passage}',
      ],
      ['37', '38', '39-41'],
    );
    expect(round.where((item) => item.review), hasLength(1));
    final asked = round.firstWhere((item) => item.ayah == 39);
    expect(asked.choices[asked.correct], journey.meaning(40).ar);
  });

  test('stops open one after another and keepsakes follow the stories', () {
    final done = <String>{};
    expect(journey.next(done), journey.stops.first);
    expect(journey.isOpen(journey.stops.first, done), isTrue);
    expect(journey.isOpen(journey.stops[1], done), isFalse);
    expect(journey.found(done), isEmpty);
    for (final stop in journey.stops.take(8)) {
      done.add(stop.id);
    }
    // The opening and the six stops of the Cave.
    expect([for (final k in journey.found(done)) k.id], ['coin']);
    expect(journey.next(done)!.first, 27);
    expect(journey.isOpen(journey.stops[3], done), isTrue);
    done.addAll([for (final stop in journey.stops) stop.id]);
    expect(journey.next(done), isNull);
    expect(journey.found(done), hasLength(4));
  });

  test('progress survives being written and read', () {
    final progress = JourneyProgress(level: JourneyLevel.arabic)
      ..done.addAll(['opening-1', 'cave-1'])
      ..answered(10, right: false)
      ..answered(10, right: false)
      ..answered(11, right: false)
      ..answered(11, right: true);
    expect(progress.recitedAyah(9, 5, 9), isTrue);
    expect(progress.recitedAyah(9, 4, 9), isFalse);
    expect(progress.recitedAyah(9, 9, 9), isTrue);
    final back = JourneyProgress.decode(progress.encode());
    expect(back.level, JourneyLevel.arabic);
    expect(back.done, {'opening-1', 'cave-1'});
    expect(back.missed, {10: 2});
    expect(back.recited, {9: 100});
    expect(JourneyProgress.decode(null).level, isNull);
    expect(JourneyProgress.decode('{broken').done, isEmpty);
  });
}

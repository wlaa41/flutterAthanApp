import 'dart:math';

import 'package:flutter_pro/models/journey.dart';
import 'package:flutter_pro/services/journey_progress.dart';
import 'package:flutter_pro/services/journey_round.dart';
import 'package:flutter_test/flutter_test.dart';

import 'journey_support.dart';

void main() {
  final journey = readJourney();

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

  test('four stories, each with a keepsake named in its own ayahs', () {
    final stories = journey.sections.where((s) => s.isStory).toList();
    expect([for (final s in stories) s.number], [1, 2, 3, 4]);
    expect(
      [for (final s in stories) s.keepsake!.id],
      ['coin', 'vine', 'ship', 'iron'],
    );
    for (final story in stories) {
      final keepsake = story.keepsake!;
      expect(keepsake.ayah, inInclusiveRange(story.first, story.last));
      final words = journey.verseWords(
        keepsake.ayah,
        keepsake.first,
        keepsake.last,
      );
      expect(words.split(' '), hasLength(keepsake.last - keepsake.first + 1));
      expect(journey.verse(keepsake.ayah), contains(words));
    }
    expect(
      journeyLetters(journey.verseWords(19, 20, 25)),
      'فابعثوا احدكم بورقكم هذه الى المدينة',
    );
    for (final bridge in journey.sections.where((s) => !s.isStory)) {
      expect(bridge.keepsake, isNull);
      expect(bridge.number, isNull);
    }
  });

  test('every text is filled in and free of long dashes', () {
    final texts = <String>[
      for (final ayah in journey.ayahs) ...[ayah.en, ayah.ar],
      for (final section in journey.sections) ...[
        section.en,
        section.ar,
        if (section.keepsake != null) ...[
          section.keepsake!.en,
          section.keepsake!.ar,
          section.keepsake!.line,
        ],
        for (final stop in section.stops) ...[
          stop.en,
          stop.ar,
          ...stop.storyEn,
          ...stop.storyAr,
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
      expect(round.length, inInclusiveRange(3, 4));
      for (var i = 0; i < round.length; i++) {
        final item = round[i];
        final question = stop.questions[i];
        expect(item.prompt, question.question);
        expect(item.choices, hasLength(3));
        expect(item.choices.toSet(), hasLength(3));
        expect(item.choices[item.correct], question.answer);
        expect(item.ayah, inInclusiveRange(stop.first, stop.last));
        expect(item.explain, journey.meaning(item.ayah).en);
      }
    }
  });

  test('the Arabic levels ask about whole ayahs of the stop', () {
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
            for (final item in round) item.ayah,
          }, hasLength(round.length));
          for (final item in round) {
            expect(journey.meaning(item.ayah).skip, isFalse);
            expect(item.choices, hasLength(3));
            expect(item.choices.toSet(), hasLength(3), reason: '${item.ayah}');
            expect(item.correct, inInclusiveRange(0, 2));
            expect(item.explain, journey.meaning(item.ayah).ar);
            if (item.review) {
              expect(item.ayah, lessThan(stop.first));
              expect(item.ayah, greaterThanOrEqualTo(section.first));
            } else {
              expect(item.ayah, inInclusiveRange(stop.first, stop.last));
            }
            if (level == JourneyLevel.arabic) {
              expect(item.prompt, isEmpty);
              expect(item.choices[item.correct], journey.meaning(item.ayah).ar);
            } else {
              expect(item.prompt, journey.meaning(item.ayah).ar);
              expect(item.choiceAyahs[item.correct], item.ayah);
              for (final other in item.choiceAyahs) {
                expect(journey.meaning(other).skip, isFalse);
                expect(other, inInclusiveRange(section.first, section.last));
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

  test('a long ayah is offered by its opening words', () {
    expect(journey.verseOpening(10), journey.verseWithMark(10));
    final opening = journey.verseOpening(19);
    expect(opening.endsWith('…'), isTrue);
    expect(opening.split(' '), hasLength(17));
    expect(journey.verse(19).startsWith(opening.replaceAll(' …', '')), isTrue);
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

  test('a long ayah can be shown by its opening or its ending', () {
    // Ayah 10 has 16 words: short enough to stand whole.
    expect(journey.verseOpening(10), journey.verseWithMark(10));
    expect(journey.verseEnding(10), journey.verseWithMark(10));
    // Ayah 19 has 38.
    final words = journey.verse(19).split(' ');
    expect(words, hasLength(38));
    expect(journey.verseOpening(19), '${words.take(16).join(' ')} …');
    expect(
      journey.verseEnding(19),
      '… ${words.skip(24).join(' ')} ${journey.verseWithMark(19).split(' ').last}',
    );
    for (var ayah = 1; ayah <= 110; ayah++) {
      for (final text in [
        journey.verseOpening(ayah),
        journey.verseEnding(ayah),
      ]) {
        expect(
          journey.verse(ayah),
          contains(
            text.replaceAll('… ', '').replaceAll(' …', '').split(' ').first,
          ),
        );
        // At most 18 words and the ayah's mark.
        expect(text.split(' ').length, lessThanOrEqualTo(19));
      }
    }
  });

  test('the optional word meanings point at real words', () {
    expect(journey.words.values.expand((w) => w), hasLength(146));
    for (final entry in journey.words.entries) {
      final words = journey.verse(entry.key).split(' ');
      for (final word in entry.value) {
        expect(word.word + word.span, lessThanOrEqualTo(words.length));
        expect(word.meaning, isNotEmpty);
      }
    }
  });
}

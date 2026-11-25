import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/data/kahf_challenge.dart';
import 'package:flutter_pro/models/quiz_models.dart';
import 'package:flutter_pro/services/mushaf_library.dart';
import 'package:flutter_pro/services/quiz_engine.dart';
import 'package:flutter_pro/services/quiz_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const challenge = kahfChallenge;

  test('every question points at its own words in the bundled text', () async {
    final text = await MushafLibrary().load(MushafLibrary.edition('hafs'));
    final verses = text.surah(18);
    expect(verses, hasLength(110));
    for (final question in challenge.questions) {
      final words = verses[question.ayah - 1].text.split(' ');
      expect(
        question.word + question.span,
        lessThanOrEqualTo(words.length),
        reason: question.id,
      );
      final asked = words
          .sublist(question.word, question.word + question.span)
          .map(quizLetters)
          .join(' ');
      expect(asked, question.letters, reason: question.id);
    }
  });

  test('at least 60 questions, and each round asks fewer than its stage', () {
    final questions = challenge.questions;
    expect(questions.length, greaterThanOrEqualTo(60));
    expect(questions.map((q) => q.id).toSet(), hasLength(questions.length));
    for (final stage in challenge.stages) {
      expect(
        stage.questions.length,
        greaterThan(QuizRules.roundSize),
        reason: '${stage.title} should hold more words than one round asks',
      );
    }
    expect(QuizRules.finalRoundSize, lessThan(questions.length));
  });

  test('stages follow the surah from verse 1 to 110 without a gap', () {
    var next = 1;
    for (final stage in challenge.stages) {
      expect(stage.from, next, reason: stage.title);
      expect(stage.to, greaterThanOrEqualTo(stage.from));
      for (final question in stage.questions) {
        expect(question.ayah, inInclusiveRange(stage.from, stage.to));
      }
      next = stage.to + 1;
    }
    expect(next, 111);
  });

  test(
    'each question has one right meaning and three different wrong ones',
    () {
      for (final question in challenge.questions) {
        expect(question.wrong, hasLength(3), reason: question.id);
        final choices = {question.meaning, ...question.wrong};
        expect(choices, hasLength(4), reason: question.id);
        for (final choice in choices) {
          expect(choice.trim(), isNotEmpty);
          // Arabic meanings, as asked: no Latin letters.
          expect(RegExp('[A-Za-z]').hasMatch(choice), isFalse, reason: choice);
        }
      }
    },
  );

  test('letters drop marks and write every alef plainly', () {
    expect(quizLetters('ٱلۡكَهۡفِ'), 'الكهف');
    expect(quizLetters('عِوَجَاۜ'), 'عوجا');
    expect(quizLetters('أَوَى'), 'اوى');
    expect(quizLetters('لَهُۥ'), 'له');
  });

  group('rounds', () {
    test('a round asks distinct questions with the right answer marked', () {
      final stage = challenge.stages.first;
      final round = buildRound(
        stage.questions,
        size: QuizRules.roundSize,
        random: Random(3),
      );
      expect(round, hasLength(QuizRules.roundSize));
      expect(round.map((a) => a.question.id).toSet(), hasLength(round.length));
      for (final asked in round) {
        expect(asked.options, hasLength(4));
        expect(asked.options[asked.answer], asked.question.meaning);
      }
      // Read through in the surah's order.
      final order = [
        for (final a in round) a.question.ayah * 100 + a.question.word,
      ];
      expect(order, [...order]..sort());
    });

    test('a word missed before is asked again first', () {
      final stage = challenge.stages[1];
      final missed = stage.questions.last;
      final records = {
        for (final q in stage.questions)
          q.id: const WordRecord(right: 3, lastRight: true),
        missed.id: const WordRecord(right: 1, wrong: 2),
      };
      var asked = 0;
      for (var seed = 0; seed < 40; seed++) {
        final round = buildRound(
          stage.questions,
          size: 4,
          random: Random(seed),
          records: records,
        );
        if (round.any((a) => a.question.id == missed.id)) asked++;
      }
      expect(asked, greaterThan(34));
    });

    test('points reward speed and a streak', () {
      const limit = Duration(seconds: 25);
      expect(QuizRules.points(left: limit, limit: limit, streak: 1), 200);
      expect(
        QuizRules.points(left: Duration.zero, limit: limit, streak: 1),
        100,
      );
      expect(
        QuizRules.points(
          left: const Duration(milliseconds: 12500),
          limit: limit,
          streak: 3,
        ),
        225,
      );
      expect(QuizRules.points(left: limit, limit: limit, streak: 5), 400);
    });

    test('three stars only for a perfect round, none when hearts run out', () {
      expect(QuizRules.stars(right: 6, asked: 6, survived: true), 3);
      expect(QuizRules.stars(right: 5, asked: 6, survived: true), 2);
      expect(QuizRules.stars(right: 4, asked: 6, survived: true), 1);
      expect(QuizRules.stars(right: 3, asked: 6, survived: false), 0);
      expect(quizRank(0, 146), 'بداية الطريق');
      expect(quizRank(146, 146), 'متقن المعاني');
    });
  });

  group('progress', () {
    RoundOutcome outcome(
      QuizStage stage, {
      required int right,
      bool survived = true,
    }) {
      final round = buildRound(stage.questions, size: 6, random: Random(1));
      return RoundOutcome(
        answers: [
          for (var i = 0; i < round.length; i++)
            AnswerLog(
              asked: round[i],
              chosen: i < right ? round[i].answer : (round[i].answer + 1) % 4,
              points: i < right ? 150 : 0,
              timedOut: false,
            ),
        ],
        score: right * 150,
        bestStreak: right,
        survived: survived,
        time: const Duration(seconds: 70),
      );
    }

    test('a star opens the next stage, and progress is kept', () async {
      final progress = await QuizProgress.load(challenge.id);
      expect(progress.unlocked(challenge, 0), isTrue);
      expect(progress.unlocked(challenge, 1), isFalse);
      final first = challenge.stages.first;

      final lost = await progress.record(
        challenge,
        first.id,
        outcome(first, right: 3, survived: false),
        6,
      );
      expect(lost.stars, 0);
      expect(progress.unlocked(challenge, 1), isFalse);

      final won = await progress.record(
        challenge,
        first.id,
        outcome(first, right: 6),
        6,
      );
      expect(won.stars, 3);
      expect(won.unlockedNext, isTrue);
      expect(won.newBest, isTrue);
      expect(progress.unlocked(challenge, 1), isTrue);
      expect(progress.nextStage(challenge), 1);

      final again = await QuizProgress.load(challenge.id);
      expect(again.stage(first.id).stars, 3);
      expect(again.stage(first.id).best, 900);
      expect(again.stage(first.id).plays, 2);
      expect(again.points, 450 + 900);
      expect(again.starsEarned(challenge), 3);
      expect(
        QuizProgress.starsAvailable(challenge),
        (challenge.stages.length + 1) * 3,
      );
    });

    test('a word is mastered after two right answers in a row', () async {
      final progress = await QuizProgress.load(challenge.id);
      final first = challenge.stages.first;
      await progress.record(challenge, first.id, outcome(first, right: 6), 6);
      expect(progress.mastered(challenge), 0);
      await progress.record(challenge, first.id, outcome(first, right: 6), 6);
      expect(progress.mastered(challenge), 6);
    });

    test('the final challenge opens when every stage has a star', () async {
      final progress = await QuizProgress.load(challenge.id);
      SavedRound? last;
      for (final stage in challenge.stages) {
        expect(progress.finalUnlocked(challenge), isFalse);
        last = await progress.record(
          challenge,
          stage.id,
          outcome(stage, right: 4),
          6,
        );
      }
      expect(last!.unlockedFinal, isTrue);
      expect(progress.finalUnlocked(challenge), isTrue);
    });

    test('a damaged save starts afresh', () async {
      SharedPreferences.setMockInitialValues({
        'quiz_progress_kahf': '{not json',
      });
      final progress = await QuizProgress.load(challenge.id);
      expect(progress.points, 0);
      expect(progress.stages, isEmpty);
    });
  });
}

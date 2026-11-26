import 'dart:math';

import '../models/journey.dart';

/// One thing asked in a stop, with its three choices.
class RoundItem {
  const RoundItem({
    required this.passage,
    required this.prompt,
    required this.choices,
    required this.correct,
    this.choicePassages = const [],
    this.review = false,
  });

  /// What is asked about: one ayah at the English level, at the Arabic
  /// levels an ayah or the few that share one tafsir text.
  final JourneyPassage passage;

  /// The first ayah of [passage]: what a wrong answer is remembered under.
  int get ayah => passage.first;

  /// English level: the question. Strong level: the tafsir. Arabic level:
  /// empty, the player is always asked for the tafsir of what is shown.
  final String prompt;

  /// English level: the answers written for the question. Arabic level:
  /// tafsir texts, word for word. Strong level: whole ayahs.
  final List<String> choices;
  final int correct;

  /// Strong level: the ayahs behind each choice.
  final List<JourneyPassage> choicePassages;

  /// A passage of an earlier stop, brought back to fill the round.
  final bool review;
}

/// Builds what a stop asks at each level.
class JourneyRounds {
  /// The Arabic levels ask about this many passages in a stop.
  static const size = 4;

  static List<RoundItem> build(
    Journey journey,
    JourneyStop stop,
    JourneyLevel level, {
    Random? random,
    Map<int, int> missed = const {},
  }) {
    final rng = random ?? Random();
    if (level == JourneyLevel.english) {
      return [for (final question in stop.questions) _english(question, rng)];
    }
    final section = journey.sectionOf(stop);
    final pool = [
      for (final other in section.stops)
        for (final passage in journey.passagesOf(other))
          if (!journey.skips(passage)) passage,
    ];
    final own = [
      for (final passage in journey.passagesOf(stop))
        if (!journey.skips(passage)) passage,
    ];
    final earlier = [
      for (final passage in pool)
        if (passage.last < stop.first) passage,
    ];
    final asked = own.length > size
        ? (_pick(own, size, missed, rng)
            ..sort((a, b) => a.first.compareTo(b.first)))
        : own;
    final review = _pick(earlier, size - asked.length, missed, rng)
      ..sort((a, b) => a.first.compareTo(b.first));
    return [
      for (final passage in asked) _arabic(journey, passage, level, pool, rng),
      for (final passage in review)
        _arabic(journey, passage, level, pool, rng, review: true),
    ];
  }

  /// [count] of [from]: the ones missed most first, the rest by chance.
  static List<JourneyPassage> _pick(
    List<JourneyPassage> from,
    int count,
    Map<int, int> missed,
    Random rng,
  ) {
    if (count <= 0 || from.isEmpty) return [];
    final shuffled = [...from]..shuffle(rng);
    final order = [for (var i = 0; i < shuffled.length; i++) (shuffled[i], i)];
    order.sort((a, b) {
      final byMissed = (missed[b.$1.first] ?? 0).compareTo(
        missed[a.$1.first] ?? 0,
      );
      return byMissed != 0 ? byMissed : a.$2.compareTo(b.$2);
    });
    return [for (final entry in order.take(count)) entry.$1];
  }

  static RoundItem _english(JourneyQuestion question, Random rng) {
    final choices = [question.answer, ...question.wrong]..shuffle(rng);
    return RoundItem(
      passage: JourneyPassage(question.ayah, question.ayah),
      prompt: question.question,
      choices: choices,
      correct: choices.indexOf(question.answer),
    );
  }

  static RoundItem _arabic(
    Journey journey,
    JourneyPassage passage,
    JourneyLevel level,
    List<JourneyPassage> pool,
    Random rng, {
    bool review = false,
  }) {
    // The two other choices come from nearby passages of the same story.
    final near =
        [
          for (final other in pool)
            if (other != passage) other,
        ]..sort(
          (a, b) => (a.first - passage.first).abs().compareTo(
            (b.first - passage.first).abs(),
          ),
        );
    final others = (near.take(5).toList()..shuffle(rng)).take(2);
    final order = [passage, ...others]..shuffle(rng);
    final strong = level == JourneyLevel.strong;
    return RoundItem(
      passage: passage,
      prompt: strong ? journey.meaning(passage.first).ar : '',
      choices: [
        for (final other in order)
          strong ? journey.passageText(other) : journey.meaning(other.first).ar,
      ],
      correct: order.indexOf(passage),
      choicePassages: strong ? order : const [],
      review: review,
    );
  }
}

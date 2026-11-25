import 'dart:math';

import '../models/journey.dart';

/// One thing asked in a stop, with its three choices.
class RoundItem {
  const RoundItem({
    required this.ayah,
    required this.prompt,
    required this.choices,
    required this.correct,
    required this.explain,
    this.choiceAyahs = const [],
    this.review = false,
  });

  /// The ayah asked about.
  final int ayah;

  /// English level: the question. Strong level: the meaning. Arabic level:
  /// empty, the question is always "what does this ayah mean?".
  final String prompt;
  final List<String> choices;
  final int correct;

  /// Shown after the answer: the meaning of the ayah.
  final String explain;

  /// Strong level: the ayah behind each choice.
  final List<int> choiceAyahs;

  /// An ayah of an earlier stop, brought back to fill the round.
  final bool review;
}

/// Builds what a stop asks at each level.
class JourneyRounds {
  /// The Arabic levels ask about this many ayahs in a stop.
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
      return [
        for (final question in stop.questions) _english(journey, question, rng),
      ];
    }
    final section = journey.sectionOf(stop);
    final pool = [
      for (final other in section.stops)
        for (final ayah in other.ayahs)
          if (!journey.meaning(ayah).skip) ayah,
    ];
    final own = [
      for (final ayah in stop.ayahs)
        if (!journey.meaning(ayah).skip) ayah,
    ];
    final earlier = [
      for (final ayah in pool)
        if (ayah < stop.first) ayah,
    ];
    final asked = own.length > size
        ? (_pick(own, size, missed, rng)..sort())
        : own;
    final review = _pick(earlier, size - asked.length, missed, rng)..sort();
    return [
      for (final ayah in asked) _arabic(journey, ayah, level, pool, rng),
      for (final ayah in review)
        _arabic(journey, ayah, level, pool, rng, review: true),
    ];
  }

  /// [count] of [from]: the ones missed most first, the rest by chance.
  static List<int> _pick(
    List<int> from,
    int count,
    Map<int, int> missed,
    Random rng,
  ) {
    if (count <= 0 || from.isEmpty) return [];
    final shuffled = [...from]..shuffle(rng);
    final order = [for (var i = 0; i < shuffled.length; i++) (shuffled[i], i)];
    order.sort((a, b) {
      final byMissed = (missed[b.$1] ?? 0).compareTo(missed[a.$1] ?? 0);
      return byMissed != 0 ? byMissed : a.$2.compareTo(b.$2);
    });
    return [for (final entry in order.take(count)) entry.$1];
  }

  static RoundItem _english(
    Journey journey,
    JourneyQuestion question,
    Random rng,
  ) {
    final choices = [question.answer, ...question.wrong]..shuffle(rng);
    return RoundItem(
      ayah: question.ayah,
      prompt: question.question,
      choices: choices,
      correct: choices.indexOf(question.answer),
      explain: journey.meaning(question.ayah).en,
    );
  }

  static RoundItem _arabic(
    Journey journey,
    int ayah,
    JourneyLevel level,
    List<int> pool,
    Random rng, {
    bool review = false,
  }) {
    // The two other choices come from nearby ayahs of the same story.
    final near = [
      for (final other in pool)
        if (other != ayah) other,
    ]..sort((a, b) => (a - ayah).abs().compareTo((b - ayah).abs()));
    final others = (near.take(5).toList()..shuffle(rng)).take(2);
    final order = [ayah, ...others]..shuffle(rng);
    final meaning = journey.meaning(ayah).ar;
    return RoundItem(
      ayah: ayah,
      prompt: level == JourneyLevel.strong ? meaning : '',
      choices: [
        for (final other in order)
          level == JourneyLevel.strong
              ? journey.verseOpening(other)
              : journey.meaning(other).ar,
      ],
      correct: order.indexOf(ayah),
      explain: meaning,
      choiceAyahs: level == JourneyLevel.strong ? order : const [],
      review: review,
    );
  }
}

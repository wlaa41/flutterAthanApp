import 'dart:math';

import '../models/quiz_models.dart';

/// The rules of a round. A stage holds more questions than one round asks, so
/// rounds stay short and a replay brings other words.
class QuizRules {
  static const roundSize = 6;
  static const finalRoundSize = 12;
  static const seconds = 25;
  static const finalSeconds = 15;
  static const hearts = 3;
  static const extraSeconds = 10;

  /// Right answers in a row before the points grow.
  static double multiplier(int streak) => streak >= 5
      ? 2
      : streak >= 3
      ? 1.5
      : 1;

  /// 100 for the right meaning, up to 100 more for answering fast, then the
  /// streak bonus. [streak] counts this answer.
  static int points({
    required Duration left,
    required Duration limit,
    required int streak,
  }) {
    final share = limit.inMilliseconds <= 0
        ? 0.0
        : (left.inMilliseconds / limit.inMilliseconds).clamp(0.0, 1.0);
    return ((100 + (100 * share).round()) * multiplier(streak)).round();
  }

  /// Three stars for a perfect round. A round lost on hearts earns none.
  static int stars({
    required int right,
    required int asked,
    required bool survived,
  }) {
    if (!survived || asked == 0) return 0;
    if (right == asked) return 3;
    final share = right / asked;
    if (share >= 0.8) return 2;
    if (share >= 0.6) return 1;
    return 0;
  }
}

/// One question as asked: its four meanings in a shuffled order.
class AskedQuestion {
  AskedQuestion(this.question, this.options, this.answer);

  /// Shuffles the right meaning in among the wrong ones.
  factory AskedQuestion.shuffle(QuizQuestion question, Random random) {
    final options = [question.meaning, ...question.wrong]..shuffle(random);
    return AskedQuestion(question, options, options.indexOf(question.meaning));
  }

  final QuizQuestion question;
  final List<String> options;

  /// Where the right meaning sits in [options].
  final int answer;
}

/// How a word has gone so far.
class WordRecord {
  const WordRecord({this.right = 0, this.wrong = 0, this.lastRight = false});

  final int right, wrong;
  final bool lastRight;

  /// Answered right twice, and right the last time.
  bool get mastered => right >= 2 && lastRight;
  bool get seen => right + wrong > 0;

  WordRecord answered(bool correct) => WordRecord(
    right: right + (correct ? 1 : 0),
    wrong: wrong + (correct ? 0 : 1),
    lastRight: correct,
  );

  Map<String, dynamic> toJson() => {'r': right, 'w': wrong, 'l': lastRight};

  static WordRecord fromJson(Object? json) {
    if (json is! Map) return const WordRecord();
    int count(Object? value) => value is int && value > 0 ? value : 0;
    return WordRecord(
      right: count(json['r']),
      wrong: count(json['w']),
      lastRight: json['l'] == true,
    );
  }
}

/// Picks [size] questions from [pool]. Words missed before come first, then
/// words not met yet, then the rest, so every meaning gets its turn.
List<AskedQuestion> buildRound(
  List<QuizQuestion> pool, {
  required int size,
  required Random random,
  Map<String, WordRecord> records = const {},
  bool inVerseOrder = true,
}) {
  double weight(QuizQuestion question) {
    final record = records[question.id] ?? const WordRecord();
    if (!record.seen) return 3;
    if (!record.lastRight) return 5;
    return record.mastered ? 1 : 2;
  }

  final remaining = [...pool];
  final chosen = <QuizQuestion>[];
  while (chosen.length < size && remaining.isNotEmpty) {
    final total = remaining.fold<double>(0, (sum, q) => sum + weight(q));
    var ticket = random.nextDouble() * total;
    var index = 0;
    for (; index < remaining.length - 1; index++) {
      ticket -= weight(remaining[index]);
      if (ticket < 0) break;
    }
    chosen.add(remaining.removeAt(index));
  }
  if (inVerseOrder) {
    // Read through the passage in order, as it is recited.
    chosen.sort((a, b) => a.ayah != b.ayah ? a.ayah - b.ayah : a.word - b.word);
  }
  return [for (final q in chosen) AskedQuestion.shuffle(q, random)];
}

/// What happened to one question in a round.
class AnswerLog {
  const AnswerLog({
    required this.asked,
    required this.chosen,
    required this.points,
    required this.timedOut,
  });

  final AskedQuestion asked;

  /// The option picked, or -1 when the time ran out.
  final int chosen;
  final int points;
  final bool timedOut;

  bool get right => chosen == asked.answer;
}

/// A finished round, ready to be saved and shown.
class RoundOutcome {
  const RoundOutcome({
    required this.answers,
    required this.score,
    required this.bestStreak,
    required this.survived,
    required this.time,
  });

  final List<AnswerLog> answers;
  final int score;
  final int bestStreak;

  /// False when the hearts ran out before the last question.
  final bool survived;
  final Duration time;

  int get right => answers.where((a) => a.right).length;

  /// Every question of the round counts, answered or not.
  int asked(int roundSize) => survived ? answers.length : roundSize;

  int stars(int roundSize) => QuizRules.stars(
    right: right,
    asked: asked(roundSize),
    survived: survived,
  );
}

/// A title for how much of the surah's meaning is known.
String quizRank(int mastered, int total) {
  final share = total == 0 ? 0.0 : mastered / total;
  if (share >= 0.9) return 'متقن المعاني';
  if (share >= 0.65) return 'فارس المعاني';
  if (share >= 0.35) return 'متدبّر';
  if (share >= 0.1) return 'طالب معنى';
  return 'بداية الطريق';
}

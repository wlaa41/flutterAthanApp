import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/quiz_models.dart';
import 'quiz_engine.dart';

/// The best a stage has gone.
class StageRecord {
  const StageRecord({this.stars = 0, this.best = 0, this.plays = 0});

  final int stars, best, plays;

  Map<String, dynamic> toJson() => {'s': stars, 'b': best, 'p': plays};

  static StageRecord fromJson(Object? json) {
    if (json is! Map) return const StageRecord();
    int count(Object? value, [int max = 1 << 30]) =>
        value is int && value > 0 ? (value > max ? max : value) : 0;
    return StageRecord(
      stars: count(json['s'], 3),
      best: count(json['b']),
      plays: count(json['p']),
    );
  }
}

/// What a saved round changed, for the results screen.
class SavedRound {
  const SavedRound({
    required this.stars,
    required this.newBest,
    required this.unlockedNext,
    required this.unlockedFinal,
  });

  final int stars;
  final bool newBest;
  final bool unlockedNext;
  final bool unlockedFinal;
}

/// One player's progress in one challenge, kept on the phone.
class QuizProgress {
  QuizProgress._(this.challengeId, this.points, this.stages, this.words);

  /// The stage id the final challenge is saved under.
  static const finalId = 'final';

  final String challengeId;

  /// Every point ever won here: the player's "power".
  int points;
  final Map<String, StageRecord> stages;
  final Map<String, WordRecord> words;

  static String _key(String id) => 'quiz_progress_$id';

  static Future<QuizProgress> load(String challengeId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(challengeId));
    try {
      final json = raw == null ? const {} : jsonDecode(raw) as Map;
      final stages = json['stages'] is Map ? json['stages'] as Map : const {};
      final words = json['words'] is Map ? json['words'] as Map : const {};
      final points = json['points'];
      return QuizProgress._(
        challengeId,
        points is int && points > 0 ? points : 0,
        {
          for (final entry in stages.entries)
            '${entry.key}': StageRecord.fromJson(entry.value),
        },
        {
          for (final entry in words.entries)
            '${entry.key}': WordRecord.fromJson(entry.value),
        },
      );
    } on FormatException {
      return QuizProgress._(challengeId, 0, {}, {});
    } on TypeError {
      return QuizProgress._(challengeId, 0, {}, {});
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(challengeId),
      jsonEncode({
        'points': points,
        'stages': {
          for (final entry in stages.entries) entry.key: entry.value.toJson(),
        },
        'words': {
          for (final entry in words.entries) entry.key: entry.value.toJson(),
        },
      }),
    );
  }

  StageRecord stage(String id) => stages[id] ?? const StageRecord();

  /// The first stage is open; each next one opens with a star in the one
  /// before it.
  bool unlocked(QuizChallenge challenge, int index) =>
      index <= 0 || stage(challenge.stages[index - 1].id).stars > 0;

  /// The final challenge opens when every stage has a star.
  bool finalUnlocked(QuizChallenge challenge) =>
      challenge.stages.every((s) => stage(s.id).stars > 0);

  int starsEarned(QuizChallenge challenge) =>
      challenge.stages.fold(0, (sum, s) => sum + stage(s.id).stars) +
      stage(finalId).stars;

  /// Stars there are to win, the final challenge's included.
  static int starsAvailable(QuizChallenge challenge) =>
      (challenge.stages.length + 1) * 3;

  int mastered(QuizChallenge challenge) =>
      challenge.questions.where((q) => words[q.id]?.mastered ?? false).length;

  /// The stage to play next: the first without a star, else the first not
  /// perfect yet, else null when every stage has three stars.
  int? nextStage(QuizChallenge challenge) {
    for (var i = 0; i < challenge.stages.length; i++) {
      if (stage(challenge.stages[i].id).stars == 0) return i;
    }
    for (var i = 0; i < challenge.stages.length; i++) {
      if (stage(challenge.stages[i].id).stars < 3) return i;
    }
    return null;
  }

  /// Adds a finished round: its words, its points, and the stage's best.
  /// [stageId] is a stage's id or [finalId].
  Future<SavedRound> record(
    QuizChallenge challenge,
    String stageId,
    RoundOutcome outcome,
    int roundSize,
  ) async {
    final wasFinalOpen = finalUnlocked(challenge);
    final index = challenge.stages.indexWhere((s) => s.id == stageId);
    final wasNextOpen = index >= 0 && unlocked(challenge, index + 1);
    for (final answer in outcome.answers) {
      final id = answer.asked.question.id;
      words[id] = (words[id] ?? const WordRecord()).answered(answer.right);
    }
    points += outcome.score;
    final before = stage(stageId);
    final stars = outcome.stars(roundSize);
    stages[stageId] = StageRecord(
      stars: stars > before.stars ? stars : before.stars,
      best: outcome.score > before.best ? outcome.score : before.best,
      plays: before.plays + 1,
    );
    await save();
    return SavedRound(
      stars: stars,
      newBest: outcome.score > before.best && before.plays > 0,
      unlockedNext:
          !wasNextOpen &&
          index >= 0 &&
          index + 1 < challenge.stages.length &&
          unlocked(challenge, index + 1),
      unlockedFinal: !wasFinalOpen && finalUnlocked(challenge),
    );
  }
}

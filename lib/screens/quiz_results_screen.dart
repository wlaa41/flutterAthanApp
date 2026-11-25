import 'package:flutter/material.dart';

import '../models/quiz_models.dart';
import '../models/quran_models.dart';
import '../services/quiz_engine.dart';
import '../services/quiz_progress.dart';
import '../widgets/quiz_widgets.dart';
import 'quiz_round_screen.dart';

/// The end of a round: stars, points, records, and every word of the round
/// with its meaning, so the meaning stays.
class QuizResultsScreen extends StatelessWidget {
  const QuizResultsScreen({
    super.key,
    required this.challenge,
    required this.stage,
    required this.outcome,
    required this.saved,
    required this.roundSize,
    required this.verses,
    required this.progress,
  });

  final QuizChallenge challenge;
  final QuizStage? stage;
  final RoundOutcome outcome;
  final SavedRound saved;
  final int roundSize;
  final List<MushafAyah> verses;
  final QuizProgress progress;

  int get _stageIndex => stage == null
      ? -1
      : challenge.stages.indexWhere((s) => s.id == stage!.id);

  QuizStage? get _nextStage {
    final index = _stageIndex;
    if (index < 0 || index + 1 >= challenge.stages.length) return null;
    return progress.unlocked(challenge, index + 1)
        ? challenge.stages[index + 1]
        : null;
  }

  bool get _finalNext =>
      stage != null &&
      _stageIndex == challenge.stages.length - 1 &&
      progress.finalUnlocked(challenge);

  String get _headline {
    if (!outcome.survived) return 'نفدت القلوب';
    switch (saved.stars) {
      case 3:
        return 'إتقان كامل!';
      case 2:
        return 'أحسنت!';
      case 1:
        return 'جيد، واصل';
      default:
        return 'حاول مرة أخرى';
    }
  }

  void _play(BuildContext context, QuizStage? next) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => QuizRoundScreen(challenge: challenge, stage: next),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final next = _nextStage;
    final minutes = outcome.time.inMinutes;
    final seconds = outcome.time.inSeconds % 60;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: QuizColors.night,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: QuizColors.background),
          child: Stack(
            children: [
              SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
                  children: [
                    Text(
                      stage?.title ?? 'التحدي الكبير',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: QuizColors.soft,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _headline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Stars(stars: saved.stars),
                    const SizedBox(height: 10),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: outcome.score.toDouble()),
                      duration: const Duration(milliseconds: 1400),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Text(
                        quizNumber(value.round()),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: QuizColors.gold,
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const Text(
                      'نقطة',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: QuizColors.soft),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (saved.newBest)
                          const QuizPill(
                            icon: Icons.emoji_events_rounded,
                            text: 'رقم قياسي جديد!',
                          ),
                        if (saved.unlockedNext)
                          const QuizPill(
                            icon: Icons.lock_open_rounded,
                            text: 'فُتحت المرحلة التالية',
                            color: QuizColors.mint,
                          ),
                        if (saved.unlockedFinal)
                          const QuizPill(
                            icon: Icons.workspace_premium_rounded,
                            text: 'فُتح التحدي الكبير!',
                            color: QuizColors.amber,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _stat(
                          'الصحيحة',
                          '${arabicDigits(outcome.right)} / ${arabicDigits(outcome.asked(roundSize))}',
                        ),
                        _stat('أطول سلسلة', arabicDigits(outcome.bestStreak)),
                        _stat(
                          'الوقت',
                          '${arabicDigits(minutes)}:${arabicDigits(seconds).padLeft(2, '٠')}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    if (next != null)
                      _button(
                        context,
                        icon: Icons.arrow_forward_rounded,
                        label: 'المرحلة التالية: ${next.title}',
                        filled: true,
                        onPressed: () => _play(context, next),
                      )
                    else if (_finalNext)
                      _button(
                        context,
                        icon: Icons.workspace_premium_rounded,
                        label: 'إلى التحدي الكبير',
                        filled: true,
                        onPressed: () => _play(context, null),
                      ),
                    const SizedBox(height: 10),
                    _button(
                      context,
                      icon: Icons.replay_rounded,
                      label: 'أعد المحاولة',
                      filled: next == null && !_finalNext,
                      onPressed: () => _play(context, stage),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'خريطة المراحل',
                        style: TextStyle(color: QuizColors.soft, fontSize: 15),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'راجع المعاني',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final answer in outcome.answers) _review(answer),
                  ],
                ),
              ),
              if (saved.stars == 3)
                const Positioned.fill(child: ConfettiBurst()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: QuizColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: QuizColors.line),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: QuizColors.faint, fontSize: 12.5),
          ),
        ],
      ),
    ),
  );

  Widget _button(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback onPressed,
  }) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
    return filled
        ? FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: QuizColors.gold,
              foregroundColor: QuizColors.night,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: onPressed,
            child: child,
          )
        : OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: QuizColors.line),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: onPressed,
            child: child,
          );
  }

  Widget _review(AnswerLog answer) {
    final question = answer.asked.question;
    final color = answer.right ? QuizColors.mint : QuizColors.rose;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: QuizColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                answer.right
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  askedWords(verses, question),
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontFamily: quranFont,
                    color: QuizColors.gold,
                    fontSize: 24,
                    height: 1.7,
                  ),
                ),
              ),
              Text(
                '${challenge.surahName}: ${arabicDigits(question.ayah)}',
                style: const TextStyle(color: QuizColors.faint, fontSize: 12),
              ),
            ],
          ),
          Text(
            question.meaning,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!answer.right)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                answer.timedOut
                    ? 'انتهى الوقت قبل الإجابة'
                    : 'اخترت: ${answer.asked.options[answer.chosen]}',
                style: const TextStyle(color: QuizColors.faint, fontSize: 13.5),
              ),
            ),
        ],
      ),
    );
  }
}

/// Three big stars that pop in one after another.
class _Stars extends StatelessWidget {
  const _Stars({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$stars من ٣ نجوم',
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == 1 ? 14 : 0),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 500 + i * 280),
              curve: Interval(i * 0.3, 1, curve: Curves.elasticOut),
              builder: (context, t, _) => Transform.scale(
                scale: i < stars ? t : 1,
                child: Icon(
                  i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: i == 1 ? 76 : 60,
                  color: i < stars ? QuizColors.gold : QuizColors.faint,
                  shadows: i < stars
                      ? [
                          Shadow(
                            color: QuizColors.gold.withValues(alpha: 0.6),
                            blurRadius: 24,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

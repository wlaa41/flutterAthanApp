import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../models/quiz_models.dart';
import '../models/quran_models.dart';
import '../services/quiz_engine.dart';
import '../services/quiz_progress.dart';
import '../widgets/quiz_widgets.dart';
import 'quiz_results_screen.dart';

/// One timed round: a few questions from a stage, or twelve from the whole
/// surah in the final challenge. Three hearts, points for speed, a bonus for
/// a streak, and two helps: remove two answers, ten more seconds.
class QuizRoundScreen extends StatefulWidget {
  const QuizRoundScreen({
    super.key,
    required this.challenge,
    this.stage,
    this.random,
  });

  final QuizChallenge challenge;

  /// The stage played, or null for the final challenge.
  final QuizStage? stage;

  /// Tests pass a seeded one so a round is the same every time.
  final Random? random;

  @override
  State<QuizRoundScreen> createState() => _QuizRoundScreenState();
}

class _QuizRoundScreenState extends State<QuizRoundScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _letters = ['أ', 'ب', 'ج', 'د'];

  List<MushafAyah>? _verses;
  QuizProgress? _progress;
  List<AskedQuestion> _round = const [];
  int _index = 0;
  int _hearts = QuizRules.hearts;
  int _score = 0;
  int _streak = 0;
  int _bestStreak = 0;
  final _log = <AnswerLog>[];

  /// The option picked, -1 when the time ran out, null while asking.
  int? _chosen;
  final Set<int> _removed = {};
  bool _usedHalf = false;
  bool _usedTime = false;
  bool _finishing = false;

  late final Ticker _ticker = createTicker(_tick);

  /// The time left, redrawn every frame by the ring alone.
  final _leftNow = ValueNotifier<Duration>(Duration.zero);
  Duration _limit = const Duration(seconds: QuizRules.seconds);
  Duration _spent = Duration.zero;
  Duration _running = Duration.zero;
  int _lastSecond = -1;
  final _clock = Stopwatch();
  Timer? _advance;

  /// Points of the last right answer, flying up from the card.
  int _gained = 0;
  int _flight = 0;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  bool get _final => widget.stage == null;
  Duration get _perQuestion =>
      Duration(seconds: _final ? QuizRules.finalSeconds : QuizRules.seconds);
  Duration get _left {
    final left = _limit - _spent - _running;
    return left.isNegative ? Duration.zero : left;
  }

  String get _title => widget.stage?.title ?? 'التحدي الكبير';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prepare();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _advance?.cancel();
    _ticker.dispose();
    _leftNow.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else {
      _pause();
    }
  }

  Future<void> _prepare() async {
    final verses = await QuizVerses.surah(widget.challenge.surah);
    final progress = await QuizProgress.load(widget.challenge.id);
    final pool = widget.stage?.questions ?? widget.challenge.questions;
    final round = buildRound(
      pool,
      size: _final ? QuizRules.finalRoundSize : QuizRules.roundSize,
      random: widget.random ?? Random(),
      records: progress.words,
      inVerseOrder: !_final,
    );
    if (!mounted) return;
    setState(() {
      _verses = verses;
      _progress = progress;
      _round = round;
    });
    _clock.start();
    _ask();
  }

  void _ask() {
    _ticker.stop();
    _limit = _perQuestion;
    _spent = Duration.zero;
    _running = Duration.zero;
    _lastSecond = -1;
    _removed.clear();
    _chosen = null;
    _leftNow.value = _left;
    _ticker.start();
    setState(() {});
  }

  void _tick(Duration elapsed) {
    _running = elapsed;
    if (_left == Duration.zero) {
      _leftNow.value = Duration.zero;
      _answer(-1);
      return;
    }
    final second = (_left.inMilliseconds / 1000).ceil();
    if (second != _lastSecond) {
      if (second <= 5 && _lastSecond != -1) HapticFeedback.selectionClick();
      _lastSecond = second;
    }
    _leftNow.value = _left;
  }

  void _pause() {
    if (!_ticker.isActive) return;
    _spent += _running;
    _running = Duration.zero;
    _ticker.stop();
    _clock.stop();
  }

  void _resume() {
    if (_ticker.isActive || _chosen != null || _verses == null || _finishing)
      return;
    _ticker.start();
    _clock.start();
  }

  void _answer(int choice) {
    if (_chosen != null || _round.isEmpty) return;
    final left = _left;
    _pause();
    _clock.start();
    final asked = _round[_index];
    final right = choice == asked.answer;
    var points = 0;
    if (right) {
      _streak++;
      _bestStreak = max(_bestStreak, _streak);
      points = QuizRules.points(left: left, limit: _limit, streak: _streak);
      _score += points;
      _gained = points;
      _flight++;
      HapticFeedback.mediumImpact();
      // A right answer moves on by itself; a wrong one waits to be read.
      _advance = Timer(const Duration(milliseconds: 2200), _next);
    } else {
      _streak = 0;
      _hearts--;
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
    }
    _log.add(
      AnswerLog(
        asked: asked,
        chosen: choice,
        points: points,
        timedOut: choice < 0,
      ),
    );
    setState(() => _chosen = choice);
  }

  void _next() {
    _advance?.cancel();
    if (!mounted || _chosen == null || _finishing) return;
    if (_hearts <= 0 || _index + 1 >= _round.length) {
      _finish();
      return;
    }
    setState(() => _index++);
    _ask();
  }

  Future<void> _finish() async {
    _finishing = true;
    _ticker.stop();
    _clock.stop();
    final outcome = RoundOutcome(
      answers: List.unmodifiable(_log),
      score: _score,
      bestStreak: _bestStreak,
      survived: _hearts > 0,
      time: _clock.elapsed,
    );
    final saved = await _progress!.record(
      widget.challenge,
      widget.stage?.id ?? QuizProgress.finalId,
      outcome,
      _round.length,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => QuizResultsScreen(
          challenge: widget.challenge,
          stage: widget.stage,
          outcome: outcome,
          saved: saved,
          roundSize: _round.length,
          verses: _verses!,
          progress: _progress!,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _halve() {
    if (_usedHalf || _chosen != null) return;
    final asked = _round[_index];
    final wrong = [
      for (var i = 0; i < asked.options.length; i++)
        if (i != asked.answer) i,
    ]..shuffle(widget.random ?? Random());
    HapticFeedback.lightImpact();
    setState(() {
      _usedHalf = true;
      _removed.addAll(wrong.take(2));
    });
  }

  void _moreTime() {
    if (_usedTime || _chosen != null) return;
    HapticFeedback.lightImpact();
    setState(() {
      _usedTime = true;
      _limit += const Duration(seconds: QuizRules.extraSeconds);
    });
    _leftNow.value = _left;
  }

  Future<void> _tafsir() async {
    _advance?.cancel();
    final asked = _round[_index];
    await showQuizTafsir(
      context,
      surah: widget.challenge.surah,
      ayah: _verses![asked.question.ayah - 1],
      surahName: widget.challenge.surahName,
    );
  }

  Future<void> _leave() async {
    _pause();
    _advance?.cancel();
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialog) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: QuizColors.deep,
          title: const Text(
            'إنهاء الجولة؟',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'لن تُحسب هذه الجولة، ويمكنك البدء من جديد متى شئت.',
            style: TextStyle(color: QuizColors.soft),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('متابعة'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text(
                'إنهاء',
                style: TextStyle(color: QuizColors.rose),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (leave == true) {
      Navigator.of(context).pop();
    } else if (_chosen == null) {
      _resume();
    } else if (_chosen == _round[_index].answer) {
      _advance = Timer(const Duration(milliseconds: 900), _next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _verses != null && _round.isNotEmpty;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: Scaffold(
          backgroundColor: QuizColors.night,
          body: DecoratedBox(
            decoration: const BoxDecoration(gradient: QuizColors.background),
            child: SafeArea(
              child: !ready
                  ? const Center(
                      child: CircularProgressIndicator(color: QuizColors.gold),
                    )
                  : Column(
                      children: [
                        _topBar(),
                        _statusRow(),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 30, 16, 16),
                            child: Column(
                              children: [
                                _questionCard(),
                                const SizedBox(height: 18),
                                _options(),
                              ],
                            ),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          transitionBuilder: (child, animation) =>
                              SizeTransition(
                                sizeFactor: animation,
                                alignment: Alignment.topCenter,
                                child: child,
                              ),
                          child: _chosen == null ? _helps() : _feedback(),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(6, 6, 14, 0),
    child: Row(
      children: [
        IconButton(
          tooltip: 'إنهاء الجولة',
          onPressed: _leave,
          icon: const Icon(Icons.close_rounded, color: QuizColors.soft),
        ),
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < _round.length; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i < _log.length
                          ? (_log[i].right ? QuizColors.mint : QuizColors.rose)
                          : i == _index
                          ? QuizColors.gold
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          label: 'القلوب الباقية $_hearts',
          child: Row(
            children: [
              for (var i = 0; i < QuizRules.hearts; i++)
                AnimatedScale(
                  scale: i < _hearts ? 1 : 0.7,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.elasticOut,
                  child: Icon(
                    i < _hearts
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 22,
                    color: i < _hearts ? QuizColors.rose : QuizColors.faint,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _statusRow() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
    child: Row(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(end: _score.toDouble()),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => QuizPill(
            icon: Icons.bolt_rounded,
            text: quizNumber(value.round()),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: _streak >= 2
              ? QuizPill(
                  key: ValueKey(_streak),
                  icon: Icons.local_fire_department_rounded,
                  color: QuizColors.amber,
                  text: QuizRules.multiplier(_streak) > 1
                      ? 'سلسلة ${arabicDigits(_streak)}  ×${_multiplierText(_streak)}'
                      : 'سلسلة ${arabicDigits(_streak)}',
                )
              : const SizedBox.shrink(),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            _title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: QuizColors.faint, fontSize: 13),
          ),
        ),
      ],
    ),
  );

  static String _multiplierText(int streak) {
    final m = QuizRules.multiplier(streak);
    return m == m.roundToDouble() ? arabicDigits(m.round()) : '١٫٥';
  }

  Widget _questionCard() {
    final asked = _round[_index];
    final question = asked.question;
    final ayah = _verses![question.ayah - 1];
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 44, 18, 18),
          decoration: BoxDecoration(
            color: QuizColors.card,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: QuizColors.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(-0.06, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Column(
              key: ValueKey(_index),
              children: [
                Text(
                  'السؤال ${arabicDigits(_index + 1)} من ${arabicDigits(_round.length)}',
                  style: const TextStyle(
                    color: QuizColors.faint,
                    fontSize: 12.5,
                  ),
                ),
                const Text(
                  'ما معنى',
                  style: TextStyle(
                    color: QuizColors.soft,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  askedWords(_verses!, question),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: quranFont,
                    fontSize: question.span > 2 ? 32 : 40,
                    height: 1.8,
                    color: QuizColors.gold,
                    shadows: [
                      Shadow(
                        color: QuizColors.gold.withValues(alpha: 0.45),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Container(height: 1, width: 120, color: QuizColors.line),
                const SizedBox(height: 8),
                VerseSnippet(ayah: ayah, question: question, fontSize: 22),
                const SizedBox(height: 4),
                Text(
                  '${widget.challenge.surahName}: ${arabicDigits(question.ayah)}',
                  style: const TextStyle(color: QuizColors.faint, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: -30,
          child: ValueListenableBuilder<Duration>(
            valueListenable: _leftNow,
            builder: (context, left, _) =>
                TimerRing(left: left, limit: _limit, size: 62),
          ),
        ),
        // The points of a right answer rise and fade.
        if (_flight > 0)
          Positioned(
            top: 6,
            left: 20,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(_flight),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => Opacity(
                opacity: (1 - t).clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, -38 * t),
                  child: Text(
                    '+${quizNumber(_gained)}',
                    style: const TextStyle(
                      color: QuizColors.mint,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _options() {
    final asked = _round[_index];
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) => Transform.translate(
        offset: Offset(sin(_shake.value * pi * 6) * 10 * (1 - _shake.value), 0),
        child: child,
      ),
      child: Column(
        children: [
          for (var i = 0; i < asked.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _option(asked, i),
            ),
        ],
      ),
    );
  }

  Widget _option(AskedQuestion asked, int i) {
    final answered = _chosen != null;
    final isRight = i == asked.answer;
    final isChosen = i == _chosen;
    final removed = _removed.contains(i);
    Color edge = QuizColors.line;
    Color fill = QuizColors.raised;
    Color badge = Colors.white.withValues(alpha: 0.10);
    Color ink = Colors.white;
    IconData? mark;
    if (answered && isRight) {
      edge = QuizColors.mint;
      fill = QuizColors.mint.withValues(alpha: 0.18);
      badge = QuizColors.mint;
      mark = Icons.check_circle_rounded;
    } else if (answered && isChosen) {
      edge = QuizColors.rose;
      fill = QuizColors.rose.withValues(alpha: 0.16);
      badge = QuizColors.rose;
      mark = Icons.cancel_rounded;
    } else if (answered || removed) {
      ink = Colors.white.withValues(alpha: 0.38);
    }
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: removed ? 0.25 : 1,
      child: Semantics(
        button: true,
        label: 'الخيار ${_letters[i]}: ${asked.options[i]}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: answered || removed ? null : () => _answer(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: edge,
                  width: answered && (isRight || isChosen) ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: badge,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _letters[i],
                      style: TextStyle(
                        color: answered && (isRight || isChosen)
                            ? QuizColors.night
                            : QuizColors.gold,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      asked.options[i],
                      style: TextStyle(
                        color: ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        decoration: removed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  if (mark != null) Icon(mark, color: edge, size: 26),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _helps() => Padding(
    key: const ValueKey('helps'),
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
    child: Row(
      children: [
        Expanded(
          child: _help(
            icon: Icons.filter_2_rounded,
            label: 'احذف إجابتين',
            used: _usedHalf,
            onTap: _halve,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _help(
            icon: Icons.more_time_rounded,
            label: '+${arabicDigits(QuizRules.extraSeconds)} ثوانٍ',
            used: _usedTime,
            onTap: _moreTime,
          ),
        ),
      ],
    ),
  );

  Widget _help({
    required IconData icon,
    required String label,
    required bool used,
    required VoidCallback onTap,
  }) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      foregroundColor: QuizColors.gold,
      disabledForegroundColor: QuizColors.faint,
      side: BorderSide(color: used ? Colors.white12 : QuizColors.line),
      minimumSize: const Size.fromHeight(46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    onPressed: used ? null : onTap,
    icon: Icon(icon, size: 20),
    label: Text(used ? 'استُعملت' : label),
  );

  Widget _feedback() {
    final asked = _round[_index];
    final right = _chosen == asked.answer;
    final timedOut = (_chosen ?? 0) < 0;
    final color = right
        ? QuizColors.mint
        : timedOut
        ? QuizColors.amber
        : QuizColors.rose;
    final verdict = right
        ? 'أحسنت! +${quizNumber(_gained)}'
        : timedOut
        ? 'انتهى الوقت'
        : 'ليس هذا المعنى';
    final last = _hearts <= 0 || _index + 1 >= _round.length;
    return Container(
      key: ValueKey('feedback$_index'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: QuizColors.deep,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                right
                    ? Icons.verified_rounded
                    : timedOut
                    ? Icons.timer_off_rounded
                    : Icons.lightbulb_rounded,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  verdict,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!right && _hearts <= 0)
                const Flexible(
                  child: Text(
                    'نفدت القلوب',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: QuizColors.rose, fontSize: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: askedWords(_verses!, asked.question),
                  style: const TextStyle(
                    fontFamily: quranFont,
                    color: QuizColors.gold,
                    fontSize: 22,
                  ),
                ),
                const TextSpan(text: '  :  '),
                TextSpan(text: asked.question.meaning),
              ],
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: QuizColors.soft),
                onPressed: _tafsir,
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: const Text('التفسير'),
              ),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: QuizColors.night,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _next,
                icon: Icon(
                  last
                      ? Icons.emoji_events_rounded
                      : Icons.arrow_forward_rounded,
                ),
                label: Text(
                  last ? 'النتيجة' : 'التالي',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

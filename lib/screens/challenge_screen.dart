import 'dart:math';

import 'package:flutter/material.dart';

import '../data/kahf_challenge.dart';
import '../models/quiz_models.dart';
import '../models/quran_models.dart';
import '../services/quiz_engine.dart';
import '../services/quiz_progress.dart';
import '../widgets/quiz_widgets.dart';
import 'quiz_round_screen.dart';
import 'quiz_study_screen.dart';

/// The meaning challenges, starting with Surah Al-Kahf: a path of stages,
/// each a short timed round of questions on the words of a few verses.
class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key, this.challenge = kahfChallenge});

  final QuizChallenge challenge;

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  QuizProgress? _progress;

  QuizChallenge get _challenge => widget.challenge;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final progress = await QuizProgress.load(_challenge.id);
    if (mounted) setState(() => _progress = progress);
  }

  Future<void> _play(QuizStage? stage) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizRoundScreen(challenge: _challenge, stage: stage),
      ),
    );
    await _load();
  }

  Future<void> _study(QuizStage stage) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizStudyScreen(challenge: _challenge, stage: stage),
      ),
    );
    await _load();
  }

  void _locked() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'افتح هذه المرحلة بنجمة واحدة على الأقل في المرحلة التي قبلها.',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: QuizColors.night,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: QuizColors.background),
          child: SafeArea(
            bottom: false,
            child: progress == null
                ? const Center(
                    child: CircularProgressIndicator(color: QuizColors.gold),
                  )
                : CustomScrollView(
                    slivers: [
                      const SliverToBoxAdapter(child: _Header()),
                      SliverToBoxAdapter(
                        child: _HeroCard(
                          challenge: _challenge,
                          progress: progress,
                          onPlay: (index) =>
                              _openStage(index ?? _challenge.stages.length),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 26, 20, 4),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 2,
                            children: [
                              const Text(
                                'مراحل التحدي',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${arabicDigits(_challenge.stages.length)} مرحلة، ${arabicDigits(_challenge.questions.length)} كلمة',
                                style: const TextStyle(
                                  color: QuizColors.faint,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _StagePath(
                          challenge: _challenge,
                          progress: progress,
                          onTap: (index) {
                            final open = index == _challenge.stages.length
                                ? progress.finalUnlocked(_challenge)
                                : progress.unlocked(_challenge, index);
                            if (!open) return _locked();
                            _openStage(index);
                          },
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(28, 4, 28, 40),
                          child: Text(
                            'المعاني من التفسير الميسر (مجمع الملك فهد) ومن كتب غريب القرآن. كل جولة أسئلة أقل من كلمات المرحلة، فالإعادة تأتي بكلمات أخرى.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: QuizColors.faint,
                              fontSize: 12.5,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// The stage's card: its verses, stars and best score, Start and Learn.
  /// [index] equal to the number of stages is the final challenge.
  void _openStage(int index) {
    final progress = _progress!;
    final isFinal = index >= _challenge.stages.length;
    final stage = isFinal ? null : _challenge.stages[index];
    final record = progress.stage(stage?.id ?? QuizProgress.finalId);
    final pool = stage?.questions.length ?? _challenge.questions.length;
    final asked = isFinal
        ? QuizRules.finalRoundSize
        : min(QuizRules.roundSize, pool);
    final seconds = isFinal ? QuizRules.finalSeconds : QuizRules.seconds;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: QuizColors.deep,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) => Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: QuizColors.faint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isFinal
                    ? 'السورة كلها'
                    : 'المرحلة ${arabicDigits(index + 1)}، ${stage!.verses}',
                style: const TextStyle(
                  color: QuizColors.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isFinal ? 'التحدي الكبير' : stage!.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StarRow(stars: record.stars, size: 26),
                  if (record.plays > 0)
                    Text(
                      'أفضل نتيجة ${quizNumber(record.best)}',
                      style: const TextStyle(color: QuizColors.soft),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  QuizPill(
                    icon: Icons.quiz_outlined,
                    text:
                        '${arabicDigits(asked)} أسئلة من ${arabicDigits(pool)}',
                  ),
                  QuizPill(
                    icon: Icons.timer_outlined,
                    text: '${arabicDigits(seconds)} ثانية للسؤال',
                    color: QuizColors.mint,
                  ),
                  QuizPill(
                    icon: Icons.favorite_rounded,
                    text: '${arabicDigits(QuizRules.hearts)} قلوب',
                    color: QuizColors.rose,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'إجابة أسرع تعني نقاطًا أكثر، والسلسلة الصحيحة تضاعفها. الجولة الكاملة بلا خطأ تمنح ثلاث نجوم.',
                style: TextStyle(color: QuizColors.faint, height: 1.6),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: QuizColors.gold,
                  foregroundColor: QuizColors.night,
                  minimumSize: const Size.fromHeight(54),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  record.plays == 0 ? 'ابدأ' : 'العب مرة أخرى',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: () {
                  Navigator.pop(sheet);
                  _play(stage);
                },
              ),
              if (stage != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: QuizColors.line),
                    minimumSize: const Size.fromHeight(50),
                  ),
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('تعلّم كلمات المرحلة أولًا'),
                  onPressed: () {
                    Navigator.pop(sheet);
                    _study(stage);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تحدّي المعاني',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'افهم كلمات القرآن كلمةً كلمة، والعب لتثبت.',
          style: TextStyle(color: QuizColors.soft, fontSize: 14.5),
        ),
      ],
    ),
  );
}

/// The surah's card: rank, mastery, stars, power and the next stage.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.challenge,
    required this.progress,
    required this.onPlay,
  });

  final QuizChallenge challenge;
  final QuizProgress progress;

  /// The stage to open, or null for the final challenge.
  final ValueChanged<int?> onPlay;

  @override
  Widget build(BuildContext context) {
    final total = challenge.questions.length;
    final mastered = progress.mastered(challenge);
    final next = progress.nextStage(challenge);
    final allDone = next == null;
    final label = allDone
        ? 'التحدي الكبير'
        : 'المرحلة ${arabicDigits(next + 1)}: ${challenge.stages[next].title}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF1B5E52), Color(0xFF0E3A33), Color(0xFF0A2621)],
          ),
          border: Border.all(color: QuizColors.line),
          boxShadow: [
            BoxShadow(
              color: QuizColors.gold.withValues(alpha: 0.10),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _CaveMark(size: 54),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'لقبك: ${quizRank(mastered, total)}',
                        style: const TextStyle(
                          color: QuizColors.gold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  'أتقنت ${arabicDigits(mastered)} من ${arabicDigits(total)} كلمة',
                  style: const TextStyle(color: QuizColors.soft),
                ),
                const Spacer(),
                Text(
                  '${arabicDigits(total == 0 ? 0 : (mastered * 100 / total).round())}٪',
                  style: const TextStyle(
                    color: QuizColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: total == 0 ? 0 : mastered / total),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 9,
                  color: QuizColors.gold,
                  backgroundColor: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                QuizPill(
                  icon: Icons.star_rounded,
                  text:
                      '${arabicDigits(progress.starsEarned(challenge))} / ${arabicDigits(QuizProgress.starsAvailable(challenge))}',
                ),
                QuizPill(
                  icon: Icons.bolt_rounded,
                  text: '${quizNumber(progress.points)} نقطة قوة',
                  color: QuizColors.mint,
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: QuizColors.gold,
                foregroundColor: QuizColors.night,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => onPlay(allDone ? null : next),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_arrow_rounded),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      progress.points == 0 ? 'ابدأ: $label' : 'تابع: $label',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A cave mouth under a crescent, drawn in gold.
class _CaveMark extends StatelessWidget {
  const _CaveMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: QuizColors.night.withValues(alpha: 0.55),
      border: Border.all(color: QuizColors.line),
    ),
    child: CustomPaint(painter: _CavePainter()),
  );
}

class _CavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final gold = Paint()
      ..color = QuizColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round;
    // The hill and the cave's arch.
    final hill = Path()
      ..moveTo(w * 0.16, h * 0.74)
      ..quadraticBezierTo(w * 0.5, h * 0.18, w * 0.84, h * 0.74);
    canvas.drawPath(hill, gold);
    final arch = Path()
      ..moveTo(w * 0.38, h * 0.74)
      ..lineTo(w * 0.38, h * 0.6)
      ..arcToPoint(Offset(w * 0.62, h * 0.6), radius: Radius.circular(w * 0.12))
      ..lineTo(w * 0.62, h * 0.74);
    canvas.drawPath(arch, gold);
    canvas.drawLine(
      Offset(w * 0.12, h * 0.74),
      Offset(w * 0.88, h * 0.74),
      gold,
    );
    // A crescent above.
    final moon = Paint()..color = QuizColors.gold;
    final c = Offset(w * 0.7, h * 0.27);
    canvas.drawCircle(c, w * 0.08, moon);
    canvas.drawCircle(
      c + Offset(w * 0.035, -h * 0.02),
      w * 0.07,
      Paint()..color = const Color(0xFF0E3A33),
    );
  }

  @override
  bool shouldRepaint(_CavePainter oldDelegate) => false;
}

/// The stages as stepping stones along a winding path, the final at the end.
class _StagePath extends StatefulWidget {
  const _StagePath({
    required this.challenge,
    required this.progress,
    required this.onTap,
  });

  final QuizChallenge challenge;
  final QuizProgress progress;
  final ValueChanged<int> onTap;

  @override
  State<_StagePath> createState() => _StagePathState();
}

class _StagePathState extends State<_StagePath>
    with SingleTickerProviderStateMixin {
  static const _step = 126.0;
  static const _top = 58.0;

  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final progress = widget.progress;
    final count = challenge.stages.length + 1;
    final next = progress.nextStage(challenge);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        Offset at(int i) => Offset(
          width / 2 + sin(i * pi / 2.3) * width * 0.24,
          _top + i * _step,
        );
        final points = [for (var i = 0; i < count; i++) at(i)];
        var reached = 0;
        for (var i = 0; i < challenge.stages.length; i++) {
          if (progress.stage(challenge.stages[i].id).stars > 0) reached = i + 1;
        }
        return SizedBox(
          height: _top + (count - 1) * _step + 110,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _PathPainter(points, reached)),
              ),
              for (var i = 0; i < count; i++)
                Positioned(
                  left: points[i].dx - 70,
                  top: points[i].dy - 38,
                  width: 140,
                  child: _node(i, next),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _node(int index, int? next) {
    final challenge = widget.challenge;
    final progress = widget.progress;
    final isFinal = index == challenge.stages.length;
    final stage = isFinal ? null : challenge.stages[index];
    final record = progress.stage(stage?.id ?? QuizProgress.finalId);
    final open = isFinal
        ? progress.finalUnlocked(challenge)
        : progress.unlocked(challenge, index);
    final current = open && (isFinal ? next == null : next == index);
    final done = record.stars > 0;
    final size = isFinal ? 84.0 : 72.0;
    final colors = !open
        ? const [Color(0xFF2A3F3B), Color(0xFF1C2E2A)]
        : done
        ? const [Color(0xFFF1D594), Color(0xFFB98A3E)]
        : const [Color(0xFF3FD69A), Color(0xFF168A5B)];
    final ink = !open
        ? QuizColors.faint
        : done
        ? QuizColors.night
        : Colors.white;
    final title = isFinal ? 'التحدي الكبير' : stage!.title;
    return Semantics(
      button: true,
      label: '$title، ${open ? '${record.stars} من ٣ نجوم' : 'مغلقة'}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onTap(index),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _glow,
              builder: (context, child) => Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: colors,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: open ? 0.35 : 0.08),
                    width: 2,
                  ),
                  boxShadow: [
                    if (current)
                      BoxShadow(
                        color: (done ? QuizColors.gold : QuizColors.mint)
                            .withValues(alpha: 0.25 + 0.35 * _glow.value),
                        blurRadius: 18 + 14 * _glow.value,
                        spreadRadius: 2 + 4 * _glow.value,
                      ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: child,
              ),
              child: Center(
                child: !open
                    ? Icon(Icons.lock_rounded, color: ink, size: 26)
                    : isFinal
                    ? Icon(
                        Icons.workspace_premium_rounded,
                        color: ink,
                        size: 40,
                      )
                    : Text(
                        arabicDigits(index + 1),
                        style: TextStyle(
                          color: ink,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: open ? Colors.white : QuizColors.faint,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            if (open) StarRow(stars: record.stars, size: 15),
          ],
        ),
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter(this.points, this.reached);

  final List<Offset> points;

  /// The path is gold up to this node.
  final int reached;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i + 1 < points.length; i++) {
      final a = points[i], b = points[i + 1];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      final bend = Offset(
        mid.dx + (b.dy - a.dy) * 0.18 * (i.isEven ? 1 : -1),
        mid.dy,
      );
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(bend.dx, bend.dy, b.dx, b.dy);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = i < reached
            ? QuizColors.gold.withValues(alpha: 0.75)
            : Colors.white.withValues(alpha: 0.12);
      // Dashes along the curve.
      for (final metric in path.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += 16) {
          canvas.drawPath(
            metric.extractPath(d, min(d + 8, metric.length)),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.reached != reached || old.points.length != points.length;
}

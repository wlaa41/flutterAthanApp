import 'dart:math';

import 'package:flutter/material.dart';

import '../models/quiz_models.dart';
import '../models/quran_models.dart';
import '../services/mushaf_library.dart';
import '../services/tafsir_service.dart';
import 'mushaf_block.dart';
import 'reader_palette.dart';
import 'tafsir_html.dart';

/// The challenge's colours: night green with the app's gold.
class QuizColors {
  static const night = Color(0xFF061A16);
  static const deep = Color(0xFF0B2B25);
  static const card = Color(0xFF0F3A32);
  static const raised = Color(0xFF15463D);
  static const gold = Color(0xFFE5C27A);
  static const brandGold = Color(0xFFC5A059);
  static const mint = Color(0xFF5FD8A3);
  static const rose = Color(0xFFFF8A80);
  static const amber = Color(0xFFFFC857);
  static const soft = Color(0xB3FFFFFF);
  static const faint = Color(0x61FFFFFF);
  static const line = Color(0x40E5C27A);

  static const background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0D332C), night],
  );
}

/// Arabic digits grouped in thousands: ١٬٢٤٠.
String quizNumber(int value) {
  final digits = value.abs().toString();
  final grouped = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write('٬');
    grouped.writeCharCode(digits.codeUnitAt(i) - 0x30 + 0x0660);
  }
  return grouped.toString();
}

/// The Quran font of the bundled Hafs text.
const quranFont = 'kfgqpc_hafs';

/// The verses of a surah from the bundled Hafs text, read once.
class QuizVerses {
  static final Map<int, List<MushafAyah>> _read = {};

  static Future<List<MushafAyah>> surah(int number) async {
    // Kept as a plain list, so a later caller gets its own future.
    final kept = _read[number];
    if (kept != null) return kept;
    final text = await MushafLibrary.instance.load(
      MushafLibrary.edition('hafs'),
    );
    return _read[number] = text.surah(number);
  }
}

/// The asked words exactly as the mushaf writes them.
String askedWords(List<MushafAyah> verses, QuizQuestion question) {
  final words = verses[question.ayah - 1].text.split(' ');
  final end = min(question.word + question.span, words.length);
  return words.sublist(min(question.word, end), end).join(' ');
}

/// Part of a verse around the asked words, the words in gold. Colour is the
/// only change inside the passage, so every letter joins as the font draws it.
class VerseSnippet extends StatelessWidget {
  const VerseSnippet({
    super.key,
    required this.ayah,
    required this.question,
    this.around = 5,
    this.fontSize = 24,
    this.color = QuizColors.soft,
    this.highlight = QuizColors.gold,
  });

  final MushafAyah ayah;
  final QuizQuestion question;

  /// Words shown on each side; null shows the whole verse.
  final int? around;
  final double fontSize;
  final Color color;
  final Color highlight;

  @override
  Widget build(BuildContext context) {
    final words = ayah.text.split(' ');
    final first = question.word.clamp(0, words.length);
    final last = (question.word + question.span).clamp(first, words.length);
    final from = around == null ? 0 : max(0, first - around!);
    final to = around == null
        ? words.length
        : min(words.length, last + around!);
    final before = words.sublist(from, first).join(' ');
    final asked = words.sublist(first, last).join(' ');
    final after = words.sublist(last, to).join(' ');
    final style = TextStyle(
      fontFamily: quranFont,
      fontSize: fontSize,
      height: 1.9,
      color: color,
    );
    // The mushaf's font has no ellipsis: it is set in the app's own font.
    final cut = TextStyle(
      fontFamily: DefaultTextStyle.of(context).style.fontFamily,
    );
    return Text.rich(
      TextSpan(
        children: [
          if (from > 0) TextSpan(text: '… ', style: cut),
          if (before.isNotEmpty) TextSpan(text: '$before '),
          TextSpan(
            text: asked,
            style: TextStyle(color: highlight),
          ),
          if (after.isNotEmpty) TextSpan(text: ' $after'),
          // The verse's own end: the font draws the number as its ornament.
          if (to == words.length)
            TextSpan(text: MushafBlock.endMark(ayah))
          else
            TextSpan(text: ' …', style: cut),
        ],
      ),
      style: style,
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
    );
  }
}

/// A ring that empties as the time runs out, green to amber to red.
class TimerRing extends StatelessWidget {
  const TimerRing({
    super.key,
    required this.left,
    required this.limit,
    this.size = 64,
  });

  final Duration left;
  final Duration limit;
  final double size;

  @override
  Widget build(BuildContext context) {
    final share = limit.inMilliseconds <= 0
        ? 0.0
        : (left.inMilliseconds / limit.inMilliseconds).clamp(0.0, 1.0);
    final color = share > 0.5
        ? QuizColors.mint
        : share > 0.25
        ? QuizColors.amber
        : QuizColors.rose;
    final seconds = (left.inMilliseconds / 1000).ceil().clamp(0, 999);
    return Semantics(
      label: 'الوقت الباقي $seconds ثانية',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(share, color),
          child: Center(
            child: Text(
              arabicDigits(seconds),
              style: TextStyle(
                color: color,
                fontSize: size * 0.34,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.share, this.color);

  final double share;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.09;
    final rect = Offset.zero & size;
    final ring = rect.deflate(stroke / 2);
    canvas.drawCircle(
      rect.center,
      size.width / 2 - stroke / 2,
      Paint()
        ..color = QuizColors.night.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill,
    );
    canvas.drawArc(
      ring,
      0,
      2 * pi,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    canvas.drawArc(
      ring,
      -pi / 2,
      -2 * pi * share,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.share != share || old.color != color;
}

/// Three stars, the earned ones in gold.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 16});

  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$stars من ٣ نجوم',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Icon(
            i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i < stars ? QuizColors.gold : QuizColors.faint,
          ),
      ],
    ),
  );
}

/// A small rounded label with an icon, for scores and counts.
class QuizPill extends StatelessWidget {
  const QuizPill({
    super.key,
    required this.icon,
    required this.text,
    this.color = QuizColors.gold,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}

/// Confetti in the app's colours, falling once.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.pieces = 90});

  final int pieces;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();
  late final List<_Piece> _pieces;

  @override
  void initState() {
    super.initState();
    final random = Random(7);
    const colours = [
      QuizColors.gold,
      QuizColors.mint,
      Colors.white,
      QuizColors.amber,
      Color(0xFF7FD1FF),
    ];
    _pieces = [
      for (var i = 0; i < widget.pieces; i++)
        _Piece(
          x: random.nextDouble(),
          drift: (random.nextDouble() - 0.5) * 0.4,
          delay: random.nextDouble() * 0.35,
          speed: 0.7 + random.nextDouble() * 0.6,
          spin: (random.nextDouble() - 0.5) * 14,
          size: 5 + random.nextDouble() * 6,
          color: colours[i % colours.length],
        ),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(_pieces, _controller.value),
      ),
    ),
  );
}

class _Piece {
  const _Piece({
    required this.x,
    required this.drift,
    required this.delay,
    required this.speed,
    required this.spin,
    required this.size,
    required this.color,
  });

  final double x, drift, delay, speed, spin, size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      final local = ((t - piece.delay) / (1 - piece.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + local * piece.speed * (size.height + 40);
      final x = (piece.x + piece.drift * local) * size.width;
      final fade = local > 0.8 ? (1 - local) / 0.2 : 1.0;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(piece.spin * local);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: piece.size,
            height: piece.size * 0.55,
          ),
          const Radius.circular(1.5),
        ),
        Paint()..color = piece.color.withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// Al-Tafsir al-Muyassar on a verse of the challenge's surah, fetched once
/// and kept on the phone like the reader's tafsir.
Future<void> showQuizTafsir(
  BuildContext context, {
  required int surah,
  required MushafAyah ayah,
  required String surahName,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: QuizColors.deep,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (sheet) => Directionality(
    textDirection: TextDirection.rtl,
    child: DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
          const SizedBox(height: 14),
          Text(
            'التفسير الميسر، $surahName: ${arabicDigits(ayah.number)}',
            style: const TextStyle(
              color: QuizColors.gold,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${ayah.text}${MushafBlock.endMark(ayah)}',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: quranFont,
              fontSize: 24,
              height: 1.9,
              color: Colors.white,
            ),
          ),
          const Divider(color: QuizColors.line, height: 28),
          FutureBuilder<TafsirPassage>(
            future: TafsirService.instance.passage(
              TafsirService.book(16),
              surah,
              ayah.number,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'يحتاج التفسير إلى الإنترنت أول مرة، ثم يبقى على الهاتف.',
                  style: TextStyle(color: QuizColors.soft, fontSize: 15),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(color: QuizColors.gold),
                  ),
                );
              }
              return TafsirHtmlView(
                html: snapshot.data!.html,
                palette: ReaderPalette.dark,
                fontSize: 15,
              );
            },
          ),
        ],
      ),
    ),
  ),
);

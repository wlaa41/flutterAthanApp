import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The look of the Al-Kahf Journey: a light sky, ink outlines, flat colour
/// and buttons that sit on a hard shadow.
abstract final class J {
  static const bg = Color(0xFFEAF4FA);
  static const ink = Color(0xFF10243E);
  static const white = Color(0xFFFFFFFF);
  static const sun = Color(0xFFFFC533);
  static const sunSoft = Color(0xFFFFD45C);
  static const sunPale = Color(0xFFFFE08A);
  static const sunCream = Color(0xFFFFE9A8);
  static const teal = Color(0xFF25B8A8);
  static const tealSoft = Color(0xFFBFEDE5);
  static const tealPale = Color(0xFFCDEBE6);
  static const navy = Color(0xFF3A4A9F);
  static const deep = Color(0xFF2B3780);
  static const lilac = Color(0xFF7A8AD8);
  static const lilacPale = Color(0xFFC9D4FF);
  static const lilacText = Color(0xFFE6EAFF);
  static const leaf = Color(0xFF8FD3A0);
  static const muted = Color(0xFF33485F);
  static const label = Color(0xFF2B4C7E);
  static const wrong = Color(0xFFB8420F);
  static const wrongPale = Color(0xFFFFE1D2);
  static const right = Color(0xFF0B6B60);
  static const grey = Color(0xFF7B8CA3);
  static const panel = Color(0xFFDCE6F1);
  static const silver = Color(0xFFE7EEF3);
  static const steel = Color(0xFFB9C7D4);

  static const font = 'baloo';
  static const quranFont = 'kfgqpc_hafs';

  /// Text in the journey's own face. [weight] is 400, 600, 700 or 800.
  static TextStyle text(
    double size, {
    int weight = 400,
    Color color = ink,
    double? height,
    double? spacing,
  }) => TextStyle(
    fontFamily: font,
    fontSize: size,
    fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
    color: color,
    height: height,
    letterSpacing: spacing,
    decoration: TextDecoration.none,
  );

  /// Quran text, always in the mushaf's own font.
  static TextStyle quran(
    double size, {
    Color color = ink,
    double height = 1.95,
  }) => TextStyle(
    fontFamily: quranFont,
    fontSize: size,
    height: height,
    color: color,
    decoration: TextDecoration.none,
  );

  static BoxDecoration box({
    Color color = white,
    double radius = 22,
    double depth = 5,
    Color border = ink,
    double width = 2.5,
  }) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border, width: width),
    boxShadow: depth <= 0
        ? null
        : [BoxShadow(color: ink, offset: Offset(0, depth))],
  );
}

/// A journey screen: its background, text direction and safe area.
class JScreen extends StatelessWidget {
  const JScreen({
    super.key,
    required this.child,
    this.arabic = false,
    this.color = J.bg,
    this.bottom = true,
  });

  final Widget child;
  final bool arabic;
  final Color color;
  final bool bottom;

  @override
  Widget build(BuildContext context) {
    // The clock and battery stay readable over a light or a dark screen.
    final dark = ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Directionality(
        textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: color,
          body: DefaultTextStyle(
            style: J.text(16),
            child: SafeArea(bottom: bottom, child: child),
          ),
        ),
      ),
    );
  }
}

/// A screen's column: it fills the screen, and scrolls when the text is set
/// large or the phone is small. A [Spacer] among [children] pushes what
/// follows it to the bottom.
class JPage extends StatelessWidget {
  const JPage({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 16),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: box.maxHeight),
        child: IntrinsicHeight(
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Quran text in the mushaf's own font. Where an ayah was cut short, the
/// dots that say so are drawn in the journey's face: the mushaf's font has
/// no such sign.
class JQuran extends StatelessWidget {
  const JQuran(
    this.text, {
    super.key,
    required this.size,
    this.height = 1.95,
    this.color = J.ink,
  });

  /// May open with "… " or close with " …".
  final String text;
  final double size;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    var body = text;
    final before = body.startsWith('… ');
    if (before) body = body.substring(2);
    final after = body.endsWith(' …');
    if (after) body = body.substring(0, body.length - 2);
    final dots = J.text(size * 0.85, weight: 700, color: color);
    return Text.rich(
      TextSpan(
        children: [
          if (before) TextSpan(text: '… ', style: dots),
          TextSpan(text: body),
          if (after) TextSpan(text: ' …', style: dots),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      style: J.quran(size, height: height, color: color),
    );
  }
}

/// A card with the ink outline and the hard shadow.
class JCard extends StatelessWidget {
  const JCard({
    super.key,
    required this.child,
    this.color = J.white,
    this.radius = 22,
    this.depth = 5,
    this.padding = const EdgeInsets.fromLTRB(14, 10, 14, 12),
    this.border = J.ink,
    this.width = 2.5,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double depth;
  final EdgeInsetsGeometry padding;
  final Color border;
  final double width;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: depth),
    child: Container(
      padding: padding,
      decoration: J.box(
        color: color,
        radius: radius,
        depth: depth,
        border: border,
        width: width,
      ),
      child: child,
    ),
  );
}

/// A button that sinks onto its shadow when pressed.
class JButton extends StatefulWidget {
  const JButton({
    super.key,
    required this.child,
    required this.onTap,
    this.color = J.sun,
    this.radius = 18,
    this.depth = 5,
    this.minHeight = 54,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    this.border = J.ink,
    this.alignment = Alignment.center,
    this.label,
    this.fadeWhenOff = true,
  });

  /// A button that is just a line of text.
  JButton.text(
    String text, {
    super.key,
    required this.onTap,
    this.color = J.sun,
    this.radius = 18,
    this.depth = 5,
    this.minHeight = 58,
    double size = 20,
    int weight = 800,
    Color textColor = J.ink,
    Widget? icon,
    this.border = J.ink,
  }) : padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
       alignment = Alignment.center,
       label = null,
       fadeWhenOff = true,
       child = Row(
         mainAxisSize: MainAxisSize.min,
         children: [
           if (icon != null) ...[icon, const SizedBox(width: 8)],
           Flexible(
             child: Text(
               text,
               textAlign: TextAlign.center,
               style: J.text(
                 size,
                 weight: weight,
                 color: textColor,
                 height: 1.2,
               ),
             ),
           ),
         ],
       );

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final double radius;
  final double depth;
  final double minHeight;
  final EdgeInsetsGeometry padding;
  final Color border;
  final AlignmentGeometry alignment;

  /// What a screen reader says, when the child has no text of its own.
  final String? label;

  /// Whether a button that cannot be pressed looks faded. An answer that has
  /// been given keeps its colour.
  final bool fadeWhenOff;

  @override
  State<JButton> createState() => _JButtonState();
}

class _JButtonState extends State<JButton> {
  bool _down = false;

  void _set(bool down) {
    if (widget.onTap != null && down != _down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final sink = _down ? widget.depth - 1 : 0.0;
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: widget.onTap,
        child: Opacity(
          opacity: widget.onTap == null && widget.fadeWhenOff ? 0.55 : 1,
          child: Padding(
            padding: EdgeInsets.only(top: sink, bottom: widget.depth - sink),
            child: Container(
              constraints: BoxConstraints(minHeight: widget.minHeight),
              padding: widget.padding,
              alignment: widget.alignment,
              decoration: J.box(
                color: widget.color,
                radius: widget.radius,
                depth: widget.depth - sink,
                border: widget.border,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// The round button in a screen's corner: back, leave, listen.
class JRound extends StatelessWidget {
  const JRound({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = J.white,
    this.size = 44,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: J.ink, width: 2.5),
        ),
        child: Icon(icon, size: size * 0.5, color: J.ink),
      ),
    ),
  );
}

/// A small fact about a stop: its ayahs, how many questions.
class JChip extends StatelessWidget {
  const JChip(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: J.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: J.ink, width: 2),
    ),
    child: Text(text, style: J.text(14, weight: 700, height: 1.3)),
  );
}

/// How far a round has come: one bar for each question.
class JSegments extends StatelessWidget {
  const JSegments({super.key, required this.count, required this.done});

  final int count;

  /// Bars before this one are answered; this one is being asked.
  final int done;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < count; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 12,
            decoration: BoxDecoration(
              color: i < done
                  ? J.teal
                  : i == done
                  ? J.sun
                  : J.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: J.ink, width: 2),
            ),
          ),
        ),
      ],
    ],
  );
}

/// The words of the journey in the player's language.
class JText {
  const JText(this.arabic);

  final bool arabic;

  String pick(String en, String ar) => arabic ? ar : en;

  /// A number in the digits the level reads.
  String number(int value) => arabic
      ? String.fromCharCodes(
          '$value'.codeUnits.map((unit) => unit - 0x30 + 0x0660),
        )
      : '$value';

  String get title => pick('Al-Kahf Journey', 'رحلة الكهف');
  String get surah => pick('Al-Kahf', 'الكهف');

  String ayahs(int first, int last) => first == last
      ? pick('Ayah $first', 'الآية ${number(first)}')
      : pick(
          'Ayahs $first to $last',
          'الآيات ${number(first)} إلى ${number(last)}',
        );

  String ayah(int ayah) =>
      pick('Al-Kahf, ayah $ayah', 'الكهف، الآية ${number(ayah)}');

  String fromAyah(int ayah) =>
      pick('Al-Kahf, from ayah $ayah', 'الكهف، من الآية ${number(ayah)}');

  String ofCount(int index, int count) =>
      pick('$index of $count', '${number(index)} من ${number(count)}');

  /// "14 of 16 words", for a recitation.
  String words(int count, int total) => arabic
      ? switch (total) {
          1 => '${number(count)} من كلمة واحدة',
          2 => '${number(count)} من كلمتين',
          <= 10 => '${number(count)} من ${number(total)} كلمات',
          _ => '${number(count)} من ${number(total)} كلمة',
        }
      : total == 1
      ? '$count of 1 word'
      : '$count of $total words';

  /// "16 words", for an ayah not yet recited.
  String wordCount(int total) => arabic
      ? switch (total) {
          1 => 'كلمة واحدة',
          2 => 'كلمتان',
          <= 10 => '${number(total)} كلمات',
          _ => '${number(total)} كلمة',
        }
      : total == 1
      ? '1 word'
      : '$total words';

  /// What a screen reader says for a keepsake's badge.
  String keepsake(String en, String ar, {required bool found}) => found
      ? pick('$en, found', '$ar، وُجد')
      : pick('$en, not found yet', '$ar، لم يوجد بعد');

  String questions(int count) => arabic
      ? switch (count) {
          1 => 'سؤال واحد',
          2 => 'سؤالان',
          <= 10 => '${number(count)} أسئلة',
          _ => '${number(count)} سؤالًا',
        }
      : count == 1
      ? '1 question'
      : '$count questions';

  /// "six lanterns", for a sentence.
  String lanterns(int count) => arabic
      ? switch (count) {
          1 => 'فانوسًا واحدًا',
          2 => 'فانوسين',
          <= 10 => '${_arabicCount(count)} فوانيس',
          _ => '${number(count)} فانوسًا',
        }
      : count == 1
      ? 'one lantern'
      : '${_englishCount(count)} lanterns';

  String lanternsLit(int count) => arabic
      ? switch (count) {
          1 => 'أُضيء الفانوس.',
          2 => 'أُضيء الفانوسان.',
          _ => 'أُضيئت الفوانيس كلها.',
        }
      : switch (count) {
          1 => 'The lantern is lit.',
          2 => 'Both lanterns lit.',
          _ => 'All ${_englishCount(count)} lanterns lit.',
        };

  static String _englishCount(int count) =>
      const [
        'no',
        'one',
        'two',
        'three',
        'four',
        'five',
        'six',
        'seven',
        'eight',
        'nine',
        'ten',
      ].elementAtOrNull(count) ??
      '$count';

  static String _arabicCount(int count) => const [
    '',
    '',
    '',
    'ثلاثة',
    'أربعة',
    'خمسة',
    'ستة',
    'سبعة',
    'ثمانية',
    'تسعة',
    'عشرة',
  ][count];
}

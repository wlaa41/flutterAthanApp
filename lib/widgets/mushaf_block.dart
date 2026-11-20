import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/quran_models.dart';
import 'reader_palette.dart';

/// The verses of one mushaf page as a single flowing paragraph.
///
/// The passage is one paragraph in one font, so every letter joins the way the
/// mushaf's font draws it. Colour is the only thing that changes inside a
/// word: a change of weight or font there would split the word into separate
/// shaping runs and leave its letters standing apart.
class MushafBlock extends StatefulWidget {
  const MushafBlock({
    super.key,
    required this.ayat,
    required this.edition,
    required this.palette,
    required this.fontSize,
    required this.onTap,
    this.selected,
    this.highlights = const {},
  });

  final List<MushafAyah> ayat;
  final MushafEdition edition;
  final ReaderPalette palette;
  final double fontSize;
  final ValueChanged<MushafAyah> onTap;

  /// The number of the verse that is open or being recited.
  final int? selected;

  /// Highlight colours by verse number.
  final Map<int, Color> highlights;

  /// What follows a verse: a no-break space and its number, which the
  /// mushaf's font draws as the end-of-ayah ornament. This is how the
  /// Complex's own text ends each verse.
  static String endMark(MushafAyah ayah) => ' ${arabicDigits(ayah.number)}';

  /// The verse as spans: its text, tajweed runs in their colours, then the
  /// end mark.
  static List<InlineSpan> spansFor(MushafAyah ayah, ReaderPalette palette) {
    final text = ayah.text;
    final runs = ayah.tajweed;
    final spans = <InlineSpan>[];
    var at = 0;
    for (var i = 0; i + 2 < runs.length; i += 3) {
      final start = runs[i];
      final end = start + runs[i + 1];
      // A run that does not fit the text is left uncoloured, never guessed.
      if (start < at || end <= start || end > text.length) continue;
      if (start > at) spans.add(TextSpan(text: text.substring(at, start)));
      spans.add(
        TextSpan(
          text: text.substring(start, end),
          style: TextStyle(
            color: palette.tajweed[TajweedRule.values[runs[i + 2]]],
          ),
        ),
      );
      at = end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    spans.add(
      TextSpan(
        text: endMark(ayah),
        style: TextStyle(color: palette.marker),
      ),
    );
    return spans;
  }

  static TextStyle textStyle(
    MushafEdition edition,
    ReaderPalette palette,
    double fontSize,
  ) => TextStyle(
    fontFamily: edition.fontFamily,
    fontSize: fontSize,
    height: 1.95,
    color: palette.ink,
  );

  @override
  State<MushafBlock> createState() => _MushafBlockState();
}

class _MushafBlockState extends State<MushafBlock> {
  final GlobalKey _paragraph = GlobalKey();

  /// Where each verse starts in the paragraph's text.
  List<int> _starts = const [];

  MushafAyah? _ayahAt(Offset local) {
    final render = _paragraph.currentContext?.findRenderObject();
    if (render is! RenderParagraph || _starts.isEmpty) return null;
    final offset = render.getPositionForOffset(local).offset;
    var index = _starts.length - 1;
    while (index > 0 && _starts[index] > offset) {
      index--;
    }
    return widget.ayat[index];
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final ayat = widget.ayat;
    final starts = <int>[];
    final children = <InlineSpan>[];
    var offset = 0;
    for (var index = 0; index < ayat.length; index++) {
      final ayah = ayat[index];
      starts.add(offset);
      final spans = MushafBlock.spansFor(ayah, palette);
      final background = ayah.number == widget.selected
          ? palette.selection
          : widget.highlights[ayah.number]?.withValues(
              alpha: palette.night ? 0.28 : 0.55,
            );
      children.add(
        background == null
            ? TextSpan(children: spans)
            : TextSpan(
                style: TextStyle(backgroundColor: background),
                children: spans,
              ),
      );
      offset += ayah.text.length + MushafBlock.endMark(ayah).length;
      if (index + 1 < ayat.length) {
        children.add(const TextSpan(text: ' '));
        offset++;
      }
    }
    _starts = starts;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final ayah = _ayahAt(details.localPosition);
        if (ayah != null) widget.onTap(ayah);
      },
      child: RichText(
        key: _paragraph,
        textDirection: TextDirection.rtl,
        // A few short verses sit centred, as a mushaf sets a short surah.
        textAlign: offset < 220 ? TextAlign.center : TextAlign.justify,
        text: TextSpan(
          style: MushafBlock.textStyle(
            widget.edition,
            palette,
            widget.fontSize,
          ),
          children: children,
        ),
      ),
    );
  }
}

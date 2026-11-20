import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/quran_models.dart';
import '../services/mushaf_pages.dart';
import '../services/quran_service.dart';
import 'reader_palette.dart';

/// How one line is drawn so that it runs from margin to margin: its type
/// size, how far it is drawn wider or narrower than that type, and the space
/// added between its words.
class LineFit {
  const LineFit(this.fontSize, this.wordSpacing, [this.stretch = 1]);
  final double fontSize;
  final double wordSpacing;

  /// The line's width as drawn, over its width as typeset. The calligrapher
  /// fills a line by drawing its letters longer or closer; a typeface cannot,
  /// so the whole line is drawn a few per cent wider or narrower instead.
  final double stretch;
}

/// How a page is drawn in a given space.
class PageFit {
  const PageFit({
    required this.fontSize,
    required this.pitch,
    required this.width,
    required this.lines,
  });

  /// The type size of the page. A line may be drawn slightly larger or
  /// smaller, as a hand-written line is.
  final double fontSize;

  /// The height of one line.
  final double pitch;

  /// The width every full line is set to.
  final double width;

  /// A fit per line of the page; null where the line is not text.
  final List<LineFit?> lines;

  /// How far a line's type may leave the page's size to fill its measure.
  static const double give = 0.03;

  /// How much narrower than its type a crowded line may be drawn, and how
  /// much wider a loose one, before the rest is made up between its words.
  static const double squeeze = 0.04;
  static const double pull = 0.06;

  /// The line pitch in type sizes: the tightest that keeps the marks of one
  /// line clear of the next, and the loosest that still reads as a page.
  static const double tightest = 1.72;
  static const double loosest = 2.3;

  /// The pitch of a page that scrolls, where no height has to be met.
  static const double comfortable = 1.95;

  /// A centred page (the first two) is set narrower than its frame.
  static const double centredShare = 0.8;

  /// A page that would lose more than this share of its width to fit the
  /// height is not shrunk: it keeps its width and scrolls instead.
  static const double smallestShare = 0.8;

  /// Sizes a page so its widest line fills the width and all its lines fit
  /// the height; with an unbounded height the width alone decides. [natural]
  /// is each line's width at a type size of 1, or null where the line is not
  /// text; [gaps] is its number of word spaces.
  static PageFit of({
    required Size space,
    required List<double?> natural,
    required List<bool> centred,
    required List<int> gaps,
  }) {
    var full = 0.0;
    var short = 0.0;
    for (var line = 0; line < natural.length; line++) {
      final width = natural[line];
      if (width == null) continue;
      if (centred[line]) {
        short = math.max(short, width);
      } else {
        full = math.max(full, width);
      }
    }
    // The widest full line sets the size, drawn at its smallest and closest.
    final widest = full > 0
        ? full * (1 - give) * (1 - squeeze)
        : short / centredShare;
    final slot = space.height / math.max(natural.length, 1);
    var fontSize = widest > 0 ? space.width / widest : slot / loosest;
    if (fontSize * tightest > slot) fontSize = slot / tightest;
    final width = widest > 0
        ? math.min(space.width, fontSize * widest)
        : space.width;
    return PageFit(
      fontSize: fontSize,
      pitch: slot.isFinite
          ? math.min(slot, fontSize * loosest)
          : fontSize * comfortable,
      width: width,
      lines: [
        for (var line = 0; line < natural.length; line++)
          if (natural[line] case final em?)
            _line(em * fontSize, fontSize, width, centred[line], gaps[line])
          else
            null,
      ],
    );
  }

  static LineFit _line(
    double natural,
    double fontSize,
    double width,
    bool centred,
    int gaps,
  ) {
    if (natural <= 0) return LineFit(fontSize, 0);
    if (centred) {
      return LineFit(
        natural > width ? fontSize * width / natural : fontSize,
        0,
      );
    }
    final scale = (width / natural).clamp(1 - give, 1 + give);
    final set = natural * scale;
    // A line of one word has nothing to spread: it stays as typeset.
    if (gaps == 0 && set < width) return LineFit(fontSize * scale, 0);
    final stretch = (width / set).clamp(1 - squeeze, 1 + pull);
    final left = width / stretch - set;
    return LineFit(fontSize * scale, left > 0 ? left / gaps : 0, stretch);
  }
}

/// One page of the mushaf as it is printed: the same lines, each beginning
/// with the same word, the surah banners and the basmalah in their places.
class MushafPage extends StatefulWidget {
  const MushafPage({
    super.key,
    required this.pages,
    required this.page,
    required this.palette,
    required this.onTap,
    this.selected,
    this.highlightOf,
  });

  final MushafPages pages;
  final int page;
  final ReaderPalette palette;
  final ValueChanged<MushafAyah> onTap;

  /// The verse that is open or being recited.
  final MushafAyah? selected;

  /// The highlight colour of a verse, if it has one.
  final Color? Function(MushafAyah ayah)? highlightOf;

  /// The words of a line as one string, with a plain space between tokens so
  /// the line can be spread evenly, and where each verse's part begins.
  static ({String text, List<int> starts}) lineText(List<LinePiece> pieces) {
    final buffer = StringBuffer();
    final starts = <int>[];
    for (final piece in pieces) {
      if (buffer.isNotEmpty) buffer.write(' ');
      starts.add(buffer.length);
      final words = piece.ayah.text.substring(piece.start, piece.end);
      buffer.write(words);
      if (piece.endMark) {
        if (words.isNotEmpty) buffer.write(' ');
        buffer.write(arabicDigits(piece.ayah.number));
      }
    }
    return (text: buffer.toString(), starts: starts);
  }

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage> {
  /// Line widths at a type size of 1. They depend on the text and the font
  /// only, so they are measured once per page.
  List<double?>? _natural;
  List<bool> _centred = const [];
  List<int> _gaps = const [];
  List<List<LinePiece>?> _pieces = const [];
  List<({String text, List<int> starts})?> _texts = const [];
  List<GlobalKey> _keys = const [];
  List<PageLine> _lines = const [];

  static const double _measureSize = 100;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(MushafPage old) {
    super.didUpdateWidget(old);
    if (old.page != widget.page || old.pages != widget.pages) _prepare();
  }

  void _prepare() {
    final pages = widget.pages;
    _lines = [
      for (final line in pages.lines(widget.page))
        if (line != null) line,
    ];
    _keys = [for (final _ in _lines) GlobalKey()];
    _pieces = [
      for (final line in _lines) line is TextLine ? pages.pieces(line) : null,
    ];
    _texts = [
      for (final pieces in _pieces)
        pieces == null ? null : MushafPage.lineText(pieces),
    ];
    _centred = [for (final line in _lines) line is TextLine && line.centred];
    _gaps = [
      for (final text in _texts)
        text == null ? 0 : ' '.allMatches(text.text).length,
    ];
    final family = pages.text.edition.fontFamily;
    _natural = [
      for (final text in _texts)
        if (text == null) null else _measure(text.text, family),
    ];
  }

  static double _measure(String text, String family) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: family, fontSize: _measureSize),
      ),
      textDirection: TextDirection.rtl,
      maxLines: 1,
    )..layout();
    final width = painter.width / _measureSize;
    painter.dispose();
    return width;
  }

  MushafAyah? _ayahAt(Offset global) {
    for (var line = 0; line < _lines.length; line++) {
      final pieces = _pieces[line];
      final text = _texts[line];
      if (pieces == null || text == null) continue;
      final render = _keys[line].currentContext?.findRenderObject();
      if (render is! RenderParagraph || !render.attached) continue;
      final local = render.globalToLocal(global);
      if (local.dy < 0 || local.dy > render.size.height) continue;
      final offset = render.getPositionForOffset(local).offset;
      var index = pieces.length - 1;
      while (index > 0 && text.starts[index] > offset) {
        index--;
      }
      return pieces[index].ayah;
    }
    return null;
  }

  List<InlineSpan> _spans(LinePiece piece) {
    final palette = widget.palette;
    final ayah = piece.ayah;
    final text = ayah.text;
    final runs = ayah.tajweed;
    final spans = <InlineSpan>[];
    var at = piece.start;
    for (var i = 0; i + 2 < runs.length && at < piece.end; i += 3) {
      final start = math.max(runs[i], piece.start);
      final end = math.min(runs[i] + runs[i + 1], piece.end);
      // A run that does not fit the text is left uncoloured, never guessed.
      if (runs[i] + runs[i + 1] > text.length || end <= start || start < at) {
        continue;
      }
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
    if (at < piece.end)
      spans.add(TextSpan(text: text.substring(at, piece.end)));
    if (piece.endMark) {
      spans.add(
        TextSpan(
          text:
              '${piece.end > piece.start ? ' ' : ''}${arabicDigits(ayah.number)}',
          style: TextStyle(color: palette.marker),
        ),
      );
    }
    return spans;
  }

  Widget _textLine(int line, PageFit fit) {
    final palette = widget.palette;
    final pieces = _pieces[line]!;
    final lineFit = fit.lines[line]!;
    final selected = widget.selected;
    final children = <InlineSpan>[];
    for (var index = 0; index < pieces.length; index++) {
      final piece = pieces[index];
      if (index > 0) children.add(const TextSpan(text: ' '));
      final ayah = piece.ayah;
      final open =
          selected != null &&
          selected.surah == ayah.surah &&
          selected.number == ayah.number;
      final background = open
          ? palette.selection
          : widget.highlightOf
                ?.call(ayah)
                ?.withValues(alpha: palette.night ? 0.28 : 0.55);
      final spans = _spans(piece);
      children.add(
        background == null
            ? TextSpan(children: spans)
            : TextSpan(
                style: TextStyle(backgroundColor: background),
                children: spans,
              ),
      );
    }
    final full = !(_lines[line] as TextLine).centred && _gaps[line] > 0;
    return SizedBox(
      width: fit.width,
      height: fit.pitch,
      // A full line is laid out to the width its fit worked out and drawn
      // from margin to margin; its height is the line's already. A centred
      // line is only kept from passing the margin.
      child: FittedBox(
        fit: full ? BoxFit.fill : BoxFit.scaleDown,
        child: RichText(
          key: _keys[line],
          textDirection: TextDirection.rtl,
          maxLines: 1,
          softWrap: false,
          text: TextSpan(
            style: TextStyle(
              fontFamily: widget.pages.text.edition.fontFamily,
              fontSize: lineFit.fontSize,
              height: fit.pitch / lineFit.fontSize,
              wordSpacing: lineFit.wordSpacing,
              color: palette.ink,
            ),
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _banner(int surah, PageFit fit) {
    final palette = widget.palette;
    return SizedBox(
      width: fit.width,
      height: fit.pitch,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: fit.pitch * 0.09),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.frame,
            borderRadius: BorderRadius.circular(fit.pitch * 0.22),
            border: Border.all(color: palette.marker, width: 1.2),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'سورة ${QuranService.surahList[surah - 1].name}',
                textDirection: TextDirection.rtl,
                textScaler: TextScaler.noScaling,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'kfgqpc_hafs',
                  fontSize: fit.pitch * 0.46,
                  height: 1.3,
                  color: palette.frameInk,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _basmalah(PageFit fit) => SizedBox(
    width: fit.width,
    height: fit.pitch,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: RichText(
        textDirection: TextDirection.rtl,
        maxLines: 1,
        softWrap: false,
        text: TextSpan(
          text: widget.pages.text.basmalah,
          style: TextStyle(
            fontFamily: widget.pages.text.edition.fontFamily,
            fontSize: fit.fontSize,
            height: fit.pitch / fit.fontSize,
            color: widget.palette.ink,
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final pages = widget.pages;
    final small = TextStyle(fontSize: 12, height: 1.2, color: palette.soft);
    final surahs = pages
        .surahsOn(widget.page)
        .map((surah) => QuranService.surahList[surah - 1].name)
        .join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: Column(
        children: [
          // The running head of the print: the surah, and the juz.
          Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'سورة $surahs',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: TextScaler.noScaling,
                    style: small,
                  ),
                ),
                Text(
                  'الجزء ${arabicDigits(pages.firstAyah(widget.page).juz)}',
                  textScaler: TextScaler.noScaling,
                  style: small,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                PageFit fitted(Size space) => PageFit.of(
                  space: space,
                  natural: _natural!,
                  centred: _centred,
                  gaps: _gaps,
                );
                var fit = fitted(constraints.biggest);
                // A phone held sideways has no room for fifteen lines: the
                // page keeps its width there and scrolls.
                final scrolls =
                    fit.width < constraints.maxWidth * PageFit.smallestShare;
                if (scrolls) {
                  fit = fitted(Size(constraints.maxWidth, double.infinity));
                }
                final lines = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var line = 0; line < _lines.length; line++)
                      switch (_lines[line]) {
                        TextLine() => _textLine(line, fit),
                        SurahBanner(:final surah) => _banner(surah, fit),
                        BasmalahLine() => _basmalah(fit),
                      },
                  ],
                );
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final ayah = _ayahAt(details.globalPosition);
                    if (ayah != null) widget.onTap(ayah);
                  },
                  child: scrolls
                      ? SingleChildScrollView(
                          child: SizedBox(
                            width: constraints.maxWidth,
                            child: Center(child: lines),
                          ),
                        )
                      : Center(child: lines),
                );
              },
            ),
          ),
          const SizedBox(height: 2),
          Text(
            arabicDigits(widget.page),
            textScaler: TextScaler.noScaling,
            style: small.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

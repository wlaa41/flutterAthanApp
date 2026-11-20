import 'package:flutter/material.dart';

import 'reader_palette.dart';

/// How a tafsir marks a stretch of text.
enum TafsirTone { quran, blue, green, red, brown, reference }

/// A stretch of tafsir text with one look.
class TafsirRun {
  const TafsirRun(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.tone,
  });

  final String text;
  final bool bold;
  final bool italic;
  final TafsirTone? tone;

  TafsirRun withText(String value) =>
      TafsirRun(value, bold: bold, italic: italic, tone: tone);
}

/// A paragraph or heading of a tafsir.
class TafsirBlock {
  const TafsirBlock(this.runs, {this.heading = 0});

  final List<TafsirRun> runs;

  /// 0 for a paragraph, otherwise the heading level.
  final int heading;

  String get text => runs.map((run) => run.text).join();

  /// Whether the block reads right to left, judged by its first letter.
  bool get rtl {
    for (final rune in text.runes) {
      if ((rune >= 0x0590 && rune <= 0x08FF) ||
          (rune >= 0xFB1D && rune <= 0xFDFF) ||
          (rune >= 0xFE70 && rune <= 0xFEFF)) {
        return true;
      }
      if ((rune >= 0x41 && rune <= 0x5A) ||
          (rune >= 0x61 && rune <= 0x7A) ||
          (rune >= 0xC0 && rune <= 0x24F)) {
        return false;
      }
    }
    return false;
  }

  /// A paragraph that is nothing but a quotation from the Quran.
  bool get quotation =>
      runs.isNotEmpty && runs.every((run) => run.tone == TafsirTone.quran);
}

class _Look {
  const _Look({
    this.tag = '',
    this.bold = false,
    this.italic = false,
    this.tone,
    this.hidden = false,
  });

  final String tag;
  final bool bold;
  final bool italic;
  final TafsirTone? tone;
  final bool hidden;

  static final _classes = RegExp(
    r'''class\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))''',
    caseSensitive: false,
  );

  _Look enter(String name, String attributes) {
    final match = _classes.firstMatch(attributes);
    final names = (match?.group(1) ?? match?.group(2) ?? match?.group(3) ?? '')
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .toSet();
    TafsirTone? marked;
    if (names.contains('reference') || name == 'sup' || name == 'sub') {
      marked = TafsirTone.reference;
    } else if (names.contains('qpc-hafs') ||
        names.contains('uthmani') ||
        names.contains('arabic')) {
      marked = TafsirTone.quran;
    } else if (names.contains('blue')) {
      marked = TafsirTone.blue;
    } else if (names.contains('green')) {
      marked = TafsirTone.green;
    } else if (names.contains('red')) {
      marked = TafsirTone.red;
    } else if (names.contains('brown')) {
      marked = TafsirTone.brown;
    }
    return _Look(
      tag: name,
      bold: bold || name == 'b' || name == 'strong',
      italic: italic || name == 'i' || name == 'em',
      tone: marked ?? tone,
      hidden: hidden || name == 'script' || name == 'style',
    );
  }
}

const _blockTags = {
  'p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li', 'ul', 'ol', //
  'blockquote', 'table', 'tr', 'section', 'article',
};

const _namedEntities = {
  'nbsp': ' ', 'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', //
  'apos': "'", 'lsquo': '‘', 'rsquo': '’', 'ldquo': '“',
  'rdquo': '”', 'ndash': '–', 'mdash': '—', 'hellip': '…',
};

String _decodeEntities(String text) {
  if (!text.contains('&')) return text;
  return text.replaceAllMapped(RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z]+);'), (
    match,
  ) {
    final body = match.group(1)!;
    if (body.startsWith('#')) {
      final hex = body.length > 1 && (body[1] == 'x' || body[1] == 'X');
      final code = int.tryParse(
        body.substring(hex ? 2 : 1),
        radix: hex ? 16 : 10,
      );
      return code == null || code <= 0 || code > 0x10FFFF
          ? match.group(0)!
          : String.fromCharCode(code);
    }
    return _namedEntities[body.toLowerCase()] ?? match.group(0)!;
  });
}

final _tag = RegExp(
  r'''<(/?)([a-zA-Z][a-zA-Z0-9]*)((?:[^>"']|"[^"]*"|'[^']*')*)>''',
);

/// Reads the small subset of HTML that tafsir texts use into paragraphs.
/// Unknown tags are dropped and their text kept, so nothing is lost.
List<TafsirBlock> parseTafsirHtml(String html) {
  final marksBlocks = RegExp(
    r'<(p|div|h[1-6]|li|br)\b',
    caseSensitive: false,
  ).hasMatch(html);
  final blocks = <TafsirBlock>[];
  var runs = <TafsirRun>[];
  var heading = 0;
  final looks = <_Look>[const _Look()];

  void flush() {
    while (runs.isNotEmpty && runs.first.text.trim().isEmpty) {
      runs.removeAt(0);
    }
    while (runs.isNotEmpty && runs.last.text.trim().isEmpty) {
      runs.removeLast();
    }
    if (runs.isNotEmpty) {
      runs[0] = runs[0].withText(runs[0].text.trimLeft());
      runs[runs.length - 1] = runs.last.withText(runs.last.text.trimRight());
      blocks.add(TafsirBlock(List.unmodifiable(runs), heading: heading));
    }
    runs = <TafsirRun>[];
  }

  void addText(String raw) {
    final look = looks.last;
    if (raw.isEmpty || look.hidden) return;
    // Texts without paragraph tags separate their paragraphs by line breaks.
    final pieces = marksBlocks ? [raw] : raw.split(RegExp(r'\s*\n\s*'));
    for (var index = 0; index < pieces.length; index++) {
      if (index > 0) flush();
      final clean = _decodeEntities(
        pieces[index],
      ).replaceAll(RegExp(r'[ \t\r\n\f]+'), ' ');
      if (clean.isEmpty) continue;
      if (clean == ' ' && (runs.isEmpty || runs.last.text.endsWith(' '))) {
        continue;
      }
      runs.add(
        TafsirRun(clean, bold: look.bold, italic: look.italic, tone: look.tone),
      );
    }
  }

  var at = 0;
  for (final match in _tag.allMatches(html)) {
    addText(html.substring(at, match.start));
    at = match.end;
    final closing = match.group(1) == '/';
    final name = match.group(2)!.toLowerCase();
    final attributes = match.group(3) ?? '';
    if (name == 'br' || name == 'hr') {
      flush();
      continue;
    }
    final block = _blockTags.contains(name);
    if (closing) {
      if (block) {
        flush();
        heading = 0;
      }
      for (var index = looks.length - 1; index > 0; index--) {
        if (looks[index].tag == name) {
          looks.removeRange(index, looks.length);
          break;
        }
      }
    } else {
      if (block) {
        flush();
        heading = name.length == 2 && name[0] == 'h'
            ? int.tryParse(name[1]) ?? 0
            : 0;
      }
      if (attributes.trimRight().endsWith('/')) continue;
      looks.add(looks.last.enter(name, attributes));
    }
  }
  addText(html.substring(at));
  flush();
  return blocks;
}

/// Tafsir text laid out as paragraphs, each in its own reading direction.
class TafsirHtmlView extends StatelessWidget {
  const TafsirHtmlView({
    super.key,
    required this.html,
    required this.palette,
    required this.fontSize,
    this.arabicWork = true,
  });

  final String html;
  final ReaderPalette palette;

  /// Whether the tafsir is written in Arabic. In a translated one, a
  /// paragraph of Arabic is a quotation and is set apart.
  final bool arabicWork;

  /// The size of Latin body text. Arabic is set a little larger.
  final double fontSize;

  Color _tone(TafsirTone tone) {
    final night = palette.night;
    switch (tone) {
      case TafsirTone.quran:
        return night ? const Color(0xFF8FD3B4) : const Color(0xFF0F5A45);
      case TafsirTone.blue:
        return night ? const Color(0xFF8FB8F2) : const Color(0xFF1D4E89);
      case TafsirTone.green:
        return night ? const Color(0xFF8BD68F) : const Color(0xFF2E7D32);
      case TafsirTone.red:
        return night ? const Color(0xFFFF8A80) : const Color(0xFFB3261E);
      case TafsirTone.brown:
        return night ? const Color(0xFFD9B38C) : const Color(0xFF8D5A2B);
      case TafsirTone.reference:
        return palette.soft;
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocks = parseTafsirHtml(html);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final block in blocks)
          Padding(
            padding: EdgeInsets.only(
              top: block.heading > 0 ? 10 : 0,
              bottom: block.heading > 0 ? 6 : 12,
            ),
            child: _block(block),
          ),
      ],
    );
  }

  Widget _block(TafsirBlock block) {
    final rtl = block.rtl;
    final heading = block.heading > 0;
    final quoted = !heading && (block.quotation || (rtl && !arabicWork));
    final size = rtl ? fontSize * (quoted ? 1.35 : 1.2) : fontSize;
    final base = TextStyle(
      fontSize: heading ? size * 1.1 : size,
      height: rtl ? 1.85 : 1.55,
      fontWeight: heading ? FontWeight.w700 : FontWeight.w400,
      color: heading
          ? (palette.night ? palette.frameInk : ReaderPalette.green)
          : quoted
          ? _tone(TafsirTone.quran)
          : palette.ink,
    );
    return Text.rich(
      TextSpan(
        children: [
          for (final run in block.runs)
            TextSpan(
              text: run.text,
              style: TextStyle(
                fontWeight: run.bold ? FontWeight.w700 : null,
                fontStyle: run.italic ? FontStyle.italic : null,
                color: run.tone == null ? null : _tone(run.tone!),
                fontSize: run.tone == TafsirTone.reference ? size * 0.85 : null,
              ),
            ),
        ],
      ),
      style: base,
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      textAlign: quoted ? TextAlign.center : TextAlign.start,
    );
  }
}

import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/quran_models.dart';
import 'mushaf_library.dart';

/// One line of a printed page.
sealed class PageLine {
  const PageLine();
}

/// A line of text: the tokens from [from] up to [to], counted through the
/// whole mushaf. The tokens of a verse are its words and then its end mark.
class TextLine extends PageLine {
  const TextLine(this.from, this.to, {this.centred = false});

  final int from;
  final int to;

  /// The print sets most lines from margin to margin and a few, such as the
  /// last words of a short surah, in the middle.
  final bool centred;
}

/// The banner that carries a surah's name.
class SurahBanner extends PageLine {
  const SurahBanner(this.surah);
  final int surah;
}

/// The basmalah on a line of its own, above a surah.
class BasmalahLine extends PageLine {
  const BasmalahLine(this.surah);
  final int surah;
}

/// The part of a line that belongs to one verse: the characters from [start]
/// to [end] of its text, and whether the verse's end mark follows them.
class LinePiece {
  const LinePiece(this.ayah, this.start, this.end, {required this.endMark});

  final MushafAyah ayah;
  final int start;
  final int end;
  final bool endMark;
}

/// A mushaf laid out as its printed pages: which words stand on each line.
class MushafPages {
  MushafPages._(this.text, this._pages, this._ayat, this._firstToken);

  final MushafText text;
  final List<List<PageLine?>> _pages;

  /// Every verse in mushaf order, and the number of each one's first token.
  final List<MushafAyah> _ayat;
  final List<int> _firstToken;

  /// The layout read for a text, kept as long as the text itself is.
  static final Expando<Future<MushafPages>> _loaded = Expando();

  /// Whether a page layout ships for this mushaf.
  static bool has(MushafEdition edition) => edition.textId == 'hafs';

  static String asset(MushafEdition edition) =>
      'asset/quran/${edition.textId}_pages.json';

  /// Reads the layout of [text] once and keeps it with that text.
  static Future<MushafPages> load(MushafText text, {AssetBundle? bundle}) {
    final pending = _loaded[text];
    if (pending != null) return pending;
    final reading = _read(text, bundle ?? rootBundle);
    _loaded[text] = reading;
    // A failed read is not remembered, so opening the pages again retries.
    reading.then<void>((_) {}, onError: (Object _) => _loaded[text] = null);
    return reading;
  }

  static Future<MushafPages> _read(MushafText text, AssetBundle bundle) async {
    final data = await bundle.load(asset(text.edition));
    final json =
        jsonDecode(
              utf8.decode(
                data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
              ),
            )
            as Map<String, dynamic>;
    final ayat = [for (final surah in text.surahs) ...surah];
    final firstToken = <int>[];
    var tokens = 0;
    for (final ayah in ayat) {
      firstToken.add(tokens);
      tokens += wordStarts(ayah.text).length + 1;
    }
    firstToken.add(tokens);
    if (json['format'] != 1 ||
        json['edition'] != text.edition.textId ||
        json['tokens'] != tokens) {
      throw const FormatException('The page layout does not match the text');
    }
    final centred = {
      for (final entry in (json['centred'] as Map<String, dynamic>).entries)
        int.parse(entry.key): (entry.value as List<dynamic>).cast<int>(),
    };
    final rows = (json['pages'] as List<dynamic>).cast<List<dynamic>>();
    // A text line runs to the start of the next text line.
    final starts = [
      for (final row in rows)
        for (final value in row)
          if (value is int && value >= 0) value,
      tokens,
    ];
    var next = 0;
    final pages = <List<PageLine?>>[];
    for (var page = 0; page < rows.length; page++) {
      final lines = <PageLine?>[];
      for (var line = 0; line < rows[page].length; line++) {
        final value = rows[page][line];
        if (value is! int) {
          lines.add(null);
        } else if (value >= 0) {
          if (starts[next] != value || starts[next + 1] <= value) {
            throw const FormatException('The page layout is out of order');
          }
          lines.add(
            TextLine(
              value,
              starts[++next],
              centred: centred[page + 1]?.contains(line + 1) ?? false,
            ),
          );
        } else if (value < -200) {
          lines.add(BasmalahLine(-value - 200));
        } else {
          lines.add(SurahBanner(-value));
        }
      }
      pages.add(List.unmodifiable(lines));
    }
    return MushafPages._(text, List.unmodifiable(pages), ayat, firstToken);
  }

  /// Where each word of [text] starts. Words are separated by plain spaces; a
  /// no-break space keeps a sign with its word.
  static List<int> wordStarts(String text) {
    final starts = [0];
    for (var at = text.indexOf(' '); at >= 0; at = text.indexOf(' ', at + 1)) {
      starts.add(at + 1);
    }
    return starts;
  }

  int get pageCount => _pages.length;

  /// The lines of [page], numbered from 1. A null is a line the page lacks.
  List<PageLine?> lines(int page) => _pages[page - 1];

  /// The index of the verse that holds [token].
  int _ayahAt(int token) {
    var low = 0;
    var high = _ayat.length - 1;
    while (low < high) {
      final middle = (low + high + 1) >> 1;
      if (_firstToken[middle] <= token) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return low;
  }

  /// The verses on [line], each with the part of its text that stands there.
  List<LinePiece> pieces(TextLine line) {
    final pieces = <LinePiece>[];
    for (
      var index = _ayahAt(line.from);
      index < _ayat.length && _firstToken[index] < line.to;
      index++
    ) {
      final ayah = _ayat[index];
      final starts = wordStarts(ayah.text);
      final first = _firstToken[index];
      final from = line.from > first ? line.from - first : 0;
      final to = line.to - first;
      final words = starts.length;
      final start = from < words ? starts[from] : ayah.text.length;
      final end = to < words ? starts[to] - 1 : ayah.text.length;
      pieces.add(
        LinePiece(ayah, start, end < start ? start : end, endMark: to > words),
      );
    }
    return pieces;
  }

  /// The first verse that starts or continues on [page].
  MushafAyah firstAyah(int page) {
    for (final line in lines(page)) {
      if (line is TextLine) return _ayat[_ayahAt(line.from)];
    }
    // A page always carries text; the last verse is only a safe answer.
    return _ayat.last;
  }

  /// The surahs with text or a banner on [page], in order.
  List<int> surahsOn(int page) {
    final surahs = <int>[];
    void add(int surah) {
      if (!surahs.contains(surah)) surahs.add(surah);
    }

    for (final line in lines(page)) {
      switch (line) {
        case SurahBanner(:final surah):
          add(surah);
        case TextLine(:final from, :final to):
          add(_ayat[_ayahAt(from)].surah);
          add(_ayat[_ayahAt(to - 1)].surah);
        case BasmalahLine() || null:
          break;
      }
    }
    return surahs;
  }

  /// The page on which [ayah] begins.
  int pageOf(MushafAyah ayah) {
    final token = _firstToken[_indexOf(ayah)];
    var low = 1;
    var high = pageCount;
    // The last page whose first text line starts at or before the token.
    while (low < high) {
      final middle = (low + high + 1) >> 1;
      if (_firstTextToken(middle) <= token) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return low;
  }

  int _firstTextToken(int page) {
    for (final line in lines(page)) {
      if (line is TextLine) return line.from;
    }
    return _firstToken.last;
  }

  int _indexOf(MushafAyah ayah) {
    var index = 0;
    for (var surah = 1; surah < ayah.surah; surah++) {
      index += text.surah(surah).length;
    }
    return index + ayah.number - 1;
  }

  /// The page where [surah] begins: the page of its first verse, which is the
  /// page the mushaf's own index gives. (A banner can sit alone at the foot of
  /// the page before it.)
  int pageOfSurah(int surah) => pageOf(text.surah(surah).first);
}

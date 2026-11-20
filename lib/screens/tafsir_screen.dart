import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/quran_models.dart';
import '../services/mushaf_library.dart';
import '../services/tafsir_service.dart';
import '../widgets/mushaf_block.dart';
import '../widgets/reader_palette.dart';
import '../widgets/tafsir_html.dart';

/// The tafsir of one verse, with a choice of well-known works.
class TafsirScreen extends StatefulWidget {
  const TafsirScreen({
    super.key,
    required this.surah,
    required this.text,
    required this.ayah,
    this.night = false,
    this.service,
  });

  final Surah surah;
  final MushafText text;
  final MushafAyah ayah;
  final bool night;
  final TafsirService? service;

  static const bookKey = 'quran_tafsir_book';
  static const fontKey = 'quran_tafsir_font';

  @override
  State<TafsirScreen> createState() => _TafsirScreenState();
}

class _TafsirScreenState extends State<TafsirScreen> {
  late final TafsirService _service = widget.service ?? TafsirService.instance;
  late MushafAyah _ayah = widget.ayah;
  TafsirBook _book = TafsirService.books.first;
  double _fontSize = 16;
  Future<List<TafsirPassage>>? _passages;
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _chipKeys = {
    for (final book in TafsirService.books) book.id: GlobalKey(),
  };

  /// Whether a long verse is shown in full above its tafsir.
  bool _verseOpen = false;

  ReaderPalette get _palette =>
      widget.night ? ReaderPalette.dark : ReaderPalette.paper;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _book = TafsirService.book(prefs.getInt(TafsirScreen.bookKey));
      _fontSize = (prefs.getDouble(TafsirScreen.fontKey) ?? 16)
          .clamp(13, 24)
          .toDouble();
      _passages = _load();
    });
    // The remembered tafsir may sit beyond the edge of the row.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chip = _chipKeys[_book.id]?.currentContext;
      if (chip != null) Scrollable.ensureVisible(chip, alignment: 0.5);
    });
  }

  /// A verse of another riwayah can hold the words of two Hafs verses, and a
  /// tafsir can explain several verses in one piece. Each piece is shown once.
  Future<List<TafsirPassage>> _load() {
    // The builder below reports a failure; it must not also count as an
    // unhandled error when it arrives before the builder is listening.
    return _fetch()..ignore();
  }

  Future<List<TafsirPassage>> _fetch() async {
    final book = _book;
    final ayah = _ayah;
    final passages = <TafsirPassage>[];
    var next = ayah.hafsFrom;
    while (next <= ayah.hafsTo) {
      final passage = await _service.passage(book, ayah.surah, next);
      passages.add(passage);
      next = passage.to >= next ? passage.to + 1 : next + 1;
    }
    return passages;
  }

  void _reload() => setState(() {
    _passages = _load();
  });

  Future<void> _choose(TafsirBook book) async {
    if (book.id == _book.id) return;
    setState(() {
      _book = book;
      _passages = _load();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(TafsirScreen.bookKey, book.id);
  }

  Future<void> _resize(double size) async {
    setState(() => _fontSize = size);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(TafsirScreen.fontKey, size);
  }

  void _step(int by) {
    final ayat = widget.text.surah(widget.surah.number);
    final index = _ayah.number - 1 + by;
    if (index < 0 || index >= ayat.length) return;
    setState(() {
      _ayah = ayat[index];
      _verseOpen = false;
      _passages = _load();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// The verse being explained. A long one shows its first lines until asked
  /// for, so the tafsir starts on the first screen.
  Widget _verse(ReaderPalette palette) {
    final span = TextSpan(
      style: MushafBlock.textStyle(widget.text.edition, palette, 24),
      children: MushafBlock.spansFor(_ayah, palette),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final measure = TextPainter(
          text: span,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          maxLines: 3,
        )..layout(maxWidth: constraints.maxWidth);
        final long = measure.didExceedMaxLines;
        measure.dispose();
        return Column(
          children: [
            RichText(
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              maxLines: long && !_verseOpen ? 3 : null,
              overflow: TextOverflow.clip,
              text: span,
            ),
            if (long)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: palette.night
                      ? palette.frameInk
                      : ReaderPalette.green,
                ),
                onPressed: () => setState(() => _verseOpen = !_verseOpen),
                child: Text(_verseOpen ? 'Show less' : 'Show the whole verse'),
              ),
          ],
        );
      },
    );
  }

  String _verses(TafsirPassage passage) {
    final surah = widget.surah.number;
    return passage.from == passage.to
        ? 'Verse $surah:${passage.from}'
        : 'Verses $surah:${passage.from} to $surah:${passage.to}, '
              'explained together';
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    final surah = widget.surah;
    final count = widget.text.surah(surah.number).length;
    return Scaffold(
      backgroundColor: palette.page,
      appBar: AppBar(
        backgroundColor: ReaderPalette.green,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tafsir', style: TextStyle(fontSize: 18)),
            Text(
              '${surah.englishName} ${surah.number}:${_ayah.number}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<double>(
            tooltip: 'Text size',
            icon: const Icon(Icons.format_size),
            initialValue: _fontSize,
            onSelected: _resize,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 14, child: Text('Small')),
              PopupMenuItem(value: 16, child: Text('Medium')),
              PopupMenuItem(value: 19, child: Text('Large')),
              PopupMenuItem(value: 22, child: Text('Extra large')),
            ],
          ),
        ],
      ),
      body: SelectionArea(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.rule),
              ),
              child: Column(
                children: [
                  _verse(palette),
                  if (!_ayah.numberedAsHafs) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Tafsir follows the Hafs count, where this is '
                      '${_ayah.hafsReference}.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: palette.soft),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final book in TafsirService.books)
                    Padding(
                      key: _chipKeys[book.id],
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(book.title),
                        selected: book.id == _book.id,
                        showCheckmark: false,
                        onSelected: (_) => _choose(book),
                        selectedColor: ReaderPalette.green,
                        backgroundColor: palette.card,
                        side: BorderSide(
                          color: book.id == _book.id
                              ? ReaderPalette.green
                              : palette.rule,
                        ),
                        labelStyle: TextStyle(
                          fontSize: book.arabic ? 15 : 13.5,
                          fontWeight: FontWeight.w600,
                          color: book.id == _book.id
                              ? Colors.white
                              : palette.ink,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${_book.name}. ${_book.about}',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: palette.soft,
              ),
            ),
            const SizedBox(height: 14),
            FutureBuilder<List<TafsirPassage>>(
              future: _passages,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: palette.night
                            ? palette.frameInk
                            : ReaderPalette.green,
                      ),
                    ),
                  );
                }
                final passages = snapshot.data;
                if (snapshot.hasError || passages == null) {
                  return Column(
                    children: [
                      const SizedBox(height: 24),
                      Text(
                        const TafsirUnavailable().toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(height: 1.45, color: palette.ink),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final passage in passages) ...[
                      if (passages.length > 1 || passage.from != passage.to)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _verses(passage),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: palette.soft,
                            ),
                          ),
                        ),
                      TafsirHtmlView(
                        html: passage.html,
                        palette: palette,
                        fontSize: _fontSize,
                        arabicWork: _book.arabic,
                      ),
                    ],
                    Divider(color: palette.rule, height: 28),
                    Text(
                      'From quran.com. A passage stays on the phone once it '
                      'has been opened.',
                      style: TextStyle(fontSize: 12, color: palette.soft),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: palette.card,
            border: Border(top: BorderSide(color: palette.rule)),
          ),
          child: TextButtonTheme(
            data: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: palette.night
                    ? palette.frameInk
                    : ReaderPalette.green,
                disabledForegroundColor: palette.soft.withValues(alpha: 0.5),
                minimumSize: const Size(48, 48),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: _ayah.number > 1 ? () => _step(-1) : null,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Previous verse'),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _ayah.number < count ? () => _step(1) : null,
                    icon: const Icon(Icons.chevron_right),
                    iconAlignment: IconAlignment.end,
                    label: const Text('Next verse'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

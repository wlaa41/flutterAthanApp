import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/drawing_stroke.dart';
import '../models/quran_models.dart';
import '../services/annotation_storage_service.dart';
import '../services/audio_service.dart';
import '../services/mushaf_library.dart';
import '../services/quran_service.dart';
import '../services/quran_translation_service.dart';
import '../widgets/mushaf_block.dart';
import '../widgets/mushaf_sheets.dart';
import '../widgets/reader_palette.dart';
import '../widgets/stylus_canvas.dart';
import '../widgets/verse_action_sheet.dart';
import 'tafsir_screen.dart';

/// Reads one surah in the chosen mushaf. The text comes from the app's own
/// files, so it opens without a connection.
class QuranReaderScreen extends StatefulWidget {
  const QuranReaderScreen({
    super.key,
    required this.surah,
    this.openAtHafsAyah,
    this.openAtPage,
    this.library,
    this.translations,
  });

  final Surah surah;

  /// A verse (in the Hafs count) to open at, as a bookmark stores it.
  final int? openAtHafsAyah;

  /// A mushaf page to open at, where reading stopped.
  final int? openAtPage;
  final MushafLibrary? library;
  final QuranTranslationService? translations;

  static const fontSizeKey = 'quran_font_size';
  static const nightKey = 'quran_night';
  static const tapHintKey = 'quran_tap_hint_done';

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  late final MushafLibrary _library = widget.library ?? MushafLibrary.instance;
  late final QuranTranslationService _translations =
      widget.translations ?? QuranTranslationService.instance;
  final GlobalKey<StylusCanvasState> _canvasKey =
      GlobalKey<StylusCanvasState>();
  final GlobalKey _viewportKey = GlobalKey();
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _pageKeys = {};

  /// Page blocks as last built, so a tap or a highlight rebuilds one block
  /// and not the whole surah.
  final Map<int, ({String signature, Widget block})> _blocks = {};

  /// A long surah is laid out a few pages per frame, so its first page shows
  /// at once. This is how many pages are laid out so far.
  int _laidOut = 0;
  static const int _pagesPerFrame = 4;

  MushafText? _text;
  List<List<MushafAyah>> _pages = const [];
  List<DrawingStroke> _strokes = [];
  Map<String, int> _highlights = {};
  String? _loadError;
  int _loadId = 0;
  double _fontSize = 26;
  bool _night = false;
  int? _selected;

  /// Shown until a verse has been opened once.
  bool _tapHint = false;

  bool _isStylusMode = false;
  DrawingTool _activeTool = DrawingTool.pen;
  Color _penColor = const Color(0xFFD97706);
  Color _highlighterColor = const Color(0xFFFEF08A);

  ReaderPalette get _palette =>
      _night ? ReaderPalette.dark : ReaderPalette.paper;

  int get _surahNumber => widget.surah.number;

  @override
  void initState() {
    super.initState();
    AudioService.instance.lastError.addListener(_showAudioError);
    _load().then((_) => _openStartingPlace());
  }

  @override
  void dispose() {
    AudioService.instance.lastError.removeListener(_showAudioError);
    unawaited(AudioService.instance.stop().catchError((Object _) {}));
    _scroll.dispose();
    super.dispose();
  }

  void _showAudioError() {
    final error = AudioService.instance.lastError.value;
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  /// Drawings sit on the laid-out text, so each mushaf keeps its own. The key
  /// is new with the bundled mushafs: notes from earlier versions were drawn
  /// over a different text and would land on the wrong words.
  String _strokeKey(MushafEdition edition) =>
      'mushaf_${edition.textId}_surah_$_surahNumber';

  Future<void> _load({MushafEdition? edition}) async {
    final id = ++_loadId;
    if (_loadError != null) setState(() => _loadError = null);
    try {
      final prefs = await SharedPreferences.getInstance();
      final chosen = edition ?? await _library.restoreChoice();
      final text = await _library.load(chosen);
      final strokes = await AnnotationStorageService.instance.loadStrokes(
        _strokeKey(chosen),
      );
      final highlights = await QuranService.instance.highlights();
      if (!mounted || id != _loadId) return;
      final pages = <List<MushafAyah>>[];
      for (final ayah in text.surah(_surahNumber)) {
        if (pages.isEmpty || pages.last.last.page != ayah.page) pages.add([]);
        pages.last.add(ayah);
      }
      _blocks.clear();
      setState(() {
        _text = text;
        _pages = pages;
        _laidOut = math.min(pages.length, _pagesPerFrame);
        _strokes = strokes;
        _highlights = highlights;
        _fontSize =
            (prefs.getDouble(QuranReaderScreen.fontSizeKey) ?? _fontSize)
                .clamp(
                  MushafSettingsSheet.minFontSize,
                  MushafSettingsSheet.maxFontSize,
                )
                .toDouble();
        _night = prefs.getBool(QuranReaderScreen.nightKey) ?? _night;
        _tapHint = !(prefs.getBool(QuranReaderScreen.tapHintKey) ?? false);
      });
      _layOutMore();
      // Opening a surah online keeps its translation for later, offline.
      unawaited(
        _translations
            .surah(_surahNumber)
            .then<void>((_) {}, onError: (Object _) {}),
      );
    } catch (_) {
      if (!mounted || id != _loadId) return;
      setState(
        () => _loadError = 'This mushaf could not be opened. Try again.',
      );
    }
  }

  /// Adds the next pages after each frame until the surah is complete.
  void _layOutMore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _laidOut >= _pages.length) return;
      setState(
        () => _laidOut = math.min(_pages.length, _laidOut + _pagesPerFrame),
      );
      _layOutMore();
    });
  }

  void _openStartingPlace() {
    final text = _text;
    if (!mounted || text == null) return;
    var page = widget.openAtPage;
    final hafsAyah = widget.openAtHafsAyah;
    if (hafsAyah != null) {
      final ayah = text.ayahForHafs(_surahNumber, hafsAyah);
      page = ayah.page;
      setState(() => _selected = ayah.number);
    }
    _rememberPlace(page ?? _pages.first.first.page);
    if (page != null) _showPage(page);
  }

  void _showPage(int page) {
    if (_pages.isEmpty || page == _pages.first.first.page) return;
    // The page must be laid out before it can be scrolled to.
    final index = _pages.indexWhere((ayat) => ayat.first.page == page);
    if (index + 1 > _laidOut) {
      setState(() => _laidOut = math.min(_pages.length, index + 2));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _pageKeys[page]?.currentContext;
      if (target != null) Scrollable.ensureVisible(target, alignment: 0.02);
    });
  }

  /// The mushaf page at the top of the screen.
  List<MushafAyah>? _topPage() {
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.attached) return null;
    final top = viewport.localToGlobal(Offset.zero).dy;
    for (final page in _pages) {
      final box = _pageKeys[page.first.page]?.currentContext
          ?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      if (box.localToGlobal(Offset(0, box.size.height)).dy > top + 60) {
        return page;
      }
    }
    return null;
  }

  void _rememberPlace(int page) {
    final text = _text;
    if (text == null) return;
    unawaited(
      QuranService.instance.saveLastRead(
        LastRead(surah: _surahNumber, page: page, textId: text.edition.textId),
      ),
    );
  }

  Future<void> _changeEdition(MushafEdition edition) async {
    if (edition.id == _text?.edition.id) return;
    // Stay at the same passage: riwayat number and page it differently.
    final anchor = _topPage()?.first;
    await _library.choose(edition);
    await _load(edition: edition);
    final text = _text;
    if (!mounted || text == null || anchor == null) return;
    final page = text.ayahForHafs(_surahNumber, anchor.hafsFrom).page;
    if (page == _pages.first.first.page) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } else {
      _showPage(page);
    }
    _rememberPlace(page);
  }

  Future<void> _setFontSize(double size) async {
    setState(() => _fontSize = size);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(QuranReaderScreen.fontSizeKey, size);
  }

  Future<void> _setNight(bool night) async {
    setState(() => _night = night);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(QuranReaderScreen.nightKey, night);
  }

  void _openSettings() {
    final text = _text;
    if (text == null) return;
    MushafSettingsSheet.show(
      context,
      edition: text.edition,
      onEdition: _changeEdition,
      fontSize: _fontSize,
      night: _night,
      onFontSize: _setFontSize,
      onNight: _setNight,
    );
  }

  void _onStrokesChanged(List<DrawingStroke> strokes) {
    final text = _text;
    if (text == null) return;
    _strokes = strokes;
    AnnotationStorageService.instance.saveStrokes(
      _strokeKey(text.edition),
      strokes,
    );
  }

  Color? _highlightOf(MushafEdition edition, MushafAyah ayah) {
    final argb = _highlights[QuranService.markKey(edition, ayah)];
    return argb == null ? null : Color(argb);
  }

  void _openVerse(MushafAyah ayah) {
    final text = _text;
    if (text == null) return;
    if (_isStylusMode && _activeTool != DrawingTool.pan) return;
    final edition = text.edition;
    if (_tapHint) {
      unawaited(
        SharedPreferences.getInstance().then(
          (prefs) => prefs.setBool(QuranReaderScreen.tapHintKey, true),
        ),
      );
    }
    setState(() {
      _selected = ayah.number;
      _tapHint = false;
    });
    VerseActionSheet.show(
      context,
      surah: widget.surah,
      ayah: ayah,
      edition: edition,
      highlight: _highlightOf(edition, ayah),
      translations: _translations,
      onHighlight: (colour) {
        final key = QuranService.markKey(edition, ayah);
        setState(() {
          if (colour == null) {
            _highlights.remove(key);
          } else {
            _highlights[key] = colour.toARGB32();
          }
        });
        unawaited(QuranService.instance.setHighlight(key, colour?.toARGB32()));
      },
      onAnnotate: () {
        if (!mounted) return;
        setState(() {
          _isStylusMode = true;
          _activeTool = DrawingTool.pen;
        });
        _canvasKey.currentState
          ?..currentTool = DrawingTool.pen
          ..selectedColor = _penColor;
      },
      onTafsir: () {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => TafsirScreen(
              surah: widget.surah,
              text: text,
              ayah: ayah,
              night: _night,
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) setState(() => _selected = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    final text = _text;
    return Scaffold(
      backgroundColor: palette.page,
      appBar: AppBar(
        backgroundColor: ReaderPalette.green,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          tooltip: 'Return to Surah List',
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Column(
          children: [
            Text(
              widget.surah.englishName,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              text?.edition.name ?? 'Opening the mushaf',
              style: const TextStyle(fontSize: 11.5, color: Colors.white70),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (text != null && text.edition.tajweedColours)
            IconButton(
              icon: const Icon(Icons.palette_outlined, color: Colors.white),
              tooltip: 'Tajweed colours',
              onPressed: () => TajweedGuideSheet.show(context, palette),
            ),
          IconButton(
            icon: const Icon(Icons.tune, color: ReaderPalette.gold),
            tooltip: 'Mushaf and text size',
            onPressed: text == null ? null : _openSettings,
          ),
        ],
      ),
      body: text == null
          ? Center(
              child: _loadError == null
                  ? const CircularProgressIndicator(color: ReaderPalette.green)
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_loadError!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () =>
                                _load().then((_) => _openStartingPlace()),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
            )
          : Stack(
              key: _viewportKey,
              fit: StackFit.expand,
              children: [
                NotificationListener<ScrollEndNotification>(
                  onNotification: (_) {
                    final page = _topPage();
                    if (page != null) _rememberPlace(page.first.page);
                    return false;
                  },
                  child: SingleChildScrollView(
                    controller: _scroll,
                    physics: (_isStylusMode && _activeTool != DrawingTool.pan)
                        ? const NeverScrollableScrollPhysics()
                        : const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      _isStylusMode ? 240 : 96,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        // The drawing layer is part of the page, so notes
                        // scroll with the verses they were written on.
                        child: StylusCanvas(
                          key: _canvasKey,
                          storageKey: _strokeKey(text.edition),
                          initialStrokes: _strokes,
                          onStrokesChanged: _onStrokesChanged,
                          isDrawingActive: _isStylusMode,
                          child: _page(text, palette),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 16,
                  right: 16,
                  child: ValueListenableBuilder<RecitationNow?>(
                    valueListenable: AudioService.instance.recitation,
                    builder: (context, now, _) => now == null
                        ? const SizedBox.shrink()
                        : _buildFloatingAudioPlayer(now),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: SafeArea(
                    top: false,
                    child: _isStylusMode
                        ? _buildStylusToolbar()
                        : Align(
                            alignment: Alignment.centerRight,
                            child: _buildNotesButton(),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _page(MushafText text, ReaderPalette palette) {
    final edition = text.edition;
    final surah = widget.surah;
    final count = text.surah(surah.number).length;
    final style = MushafBlock.textStyle(edition, palette, _fontSize);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: palette.frame,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.marker, width: 1.2),
          ),
          child: Text(
            'سورة ${surah.name}',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'kfgqpc_hafs',
              fontSize: 26,
              height: 1.5,
              color: palette.frameInk,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            '${surah.revelationType}, $count ayat, juz ${_pages.first.first.juz}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: palette.soft),
          ),
        ),
        if (_tapHint)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Tap a verse for its meaning, tafsir and audio.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: palette.soft),
            ),
          ),
        if (text.basmalahAbove(surah.number))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: RichText(
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              text: TextSpan(text: text.basmalah, style: style),
            ),
          ),
        const SizedBox(height: 6),
        for (var index = 0; index < _laidOut; index++) ...[
          if (index > 0) _pageRule(_pages[index], _pages[index - 1], palette),
          _block(index, edition, palette),
        ],
      ],
    );
  }

  Widget _block(int index, MushafEdition edition, ReaderPalette palette) {
    final ayat = _pages[index];
    final page = ayat.first.page;
    final highlights = <int, Color>{
      for (final ayah in ayat)
        if (_highlightOf(edition, ayah) case final colour?) ayah.number: colour,
    };
    final selected = _selected;
    final open =
        selected != null &&
            selected >= ayat.first.number &&
            selected <= ayat.last.number
        ? selected
        : null;
    final signature = [
      edition.id,
      palette.night,
      _fontSize,
      open,
      for (final entry in highlights.entries)
        '${entry.key}=${entry.value.toARGB32()}',
    ].join('|');
    final built = _blocks[page];
    if (built != null && built.signature == signature) return built.block;
    final block = MushafBlock(
      key: _pageKeys.putIfAbsent(page, () => GlobalKey()),
      ayat: ayat,
      edition: edition,
      palette: palette,
      fontSize: _fontSize,
      selected: open,
      highlights: highlights,
      onTap: _openVerse,
    );
    _blocks[page] = (signature: signature, block: block);
    return block;
  }

  /// Marks where a page of the printed mushaf ends and the next begins.
  Widget _pageRule(
    List<MushafAyah> page,
    List<MushafAyah> before,
    ReaderPalette palette,
  ) {
    final first = page.first;
    final label = first.juz == before.last.juz
        ? 'Page ${first.page}'
        : 'Page ${first.page}, juz ${first.juz}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: palette.rule, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, color: palette.soft),
            ),
          ),
          Expanded(child: Divider(color: palette.rule, thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildFloatingAudioPlayer(RecitationNow now) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: ReaderPalette.green,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: ReaderPalette.gold, width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(Icons.graphic_eq, color: ReaderPalette.gold, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Reciting ${now.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  now.reciter,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.stop_circle_rounded,
              color: Colors.white,
              size: 26,
            ),
            tooltip: 'Stop Recitation',
            onPressed: () => AudioService.instance.stop(),
          ),
        ],
      ),
    );
  }

  /// Opens the drawing tools. While reading, this is all that floats over
  /// the page.
  Widget _buildNotesButton() {
    return Tooltip(
      message: 'Write or highlight on the page',
      child: Material(
        color: const Color(0xFF0F172A).withValues(alpha: 0.94),
        elevation: 4,
        shape: StadiumBorder(
          side: BorderSide(color: ReaderPalette.gold.withValues(alpha: 0.4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _isStylusMode = true),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit, size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Notes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStylusToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: ReaderPalette.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Wrap tools instead of squeezing touch targets on narrow phones.
          Wrap(
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              Semantics(
                button: true,
                label: 'Finish drawing',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => setState(() => _isStylusMode = false),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ReaderPalette.gold,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, size: 16, color: Colors.black87),
                        SizedBox(width: 4),
                        Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.create,
                  color: _activeTool == DrawingTool.pen
                      ? ReaderPalette.gold
                      : Colors.white60,
                  size: 20,
                ),
                tooltip: 'Stylus Pen',
                onPressed: () {
                  setState(() => _activeTool = DrawingTool.pen);
                  _canvasKey.currentState?.currentTool = DrawingTool.pen;
                  _canvasKey.currentState?.selectedColor = _penColor;
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.highlight,
                  color: _activeTool == DrawingTool.highlighter
                      ? const Color(0xFFFEF08A)
                      : Colors.white60,
                  size: 20,
                ),
                tooltip: 'Highlighter (Translucent)',
                onPressed: () {
                  setState(() => _activeTool = DrawingTool.highlighter);
                  _canvasKey.currentState?.currentTool =
                      DrawingTool.highlighter;
                  _canvasKey.currentState?.selectedColor = _highlighterColor;
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.cleaning_services,
                  color: _activeTool == DrawingTool.eraser
                      ? Colors.redAccent
                      : Colors.white60,
                  size: 20,
                ),
                tooltip: 'Eraser',
                onPressed: () {
                  setState(() => _activeTool = DrawingTool.eraser);
                  _canvasKey.currentState?.currentTool = DrawingTool.eraser;
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.pan_tool_outlined,
                  color: _activeTool == DrawingTool.pan
                      ? ReaderPalette.gold
                      : Colors.white60,
                  size: 20,
                ),
                tooltip: 'Pan / Scroll Page',
                onPressed: () {
                  setState(() => _activeTool = DrawingTool.pan);
                  _canvasKey.currentState?.currentTool = DrawingTool.pan;
                },
              ),
              IconButton(
                icon: const Icon(Icons.undo, color: Colors.white70, size: 20),
                tooltip: 'Undo',
                onPressed: () => _canvasKey.currentState?.undo(),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_sweep,
                  color: Colors.white70,
                  size: 20,
                ),
                tooltip: 'Clear Page Drawing',
                onPressed: () => _canvasKey.currentState?.clearAll(),
              ),
            ],
          ),
          if (_activeTool != DrawingTool.eraser) ...[
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                const Text(
                  'Ink: ',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
                if (_activeTool == DrawingTool.pen) ...[
                  _buildColorDot(const Color(0xFFD97706)),
                  _buildColorDot(const Color(0xFFEF4444)),
                  _buildColorDot(const Color(0xFF3B82F6)),
                  _buildColorDot(const Color(0xFF10B981)),
                  _buildColorDot(const Color(0xFFFFFFFF)),
                ] else ...[
                  _buildColorDot(const Color(0xFFFEF08A)),
                  _buildColorDot(const Color(0xFFA7F3D0)),
                  _buildColorDot(const Color(0xFFBAE6FD)),
                  _buildColorDot(const Color(0xFFFBCFE8)),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildColorDot(Color color) {
    final isSelected = _activeTool == DrawingTool.pen
        ? _penColor.toARGB32() == color.toARGB32()
        : _highlighterColor.toARGB32() == color.toARGB32();
    final colorName =
        {
          0xFFD97706: 'Gold',
          0xFFEF4444: 'Coral',
          0xFF3B82F6: 'Blue',
          0xFF10B981: 'Green',
          0xFFFFFFFF: 'White',
          0xFFFEF08A: 'Yellow',
          0xFFA7F3D0: 'Mint',
          0xFFBAE6FD: 'Cyan',
          0xFFFBCFE8: 'Pink',
        }[color.toARGB32()] ??
        'Ink';
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$colorName ink',
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.all(12),
        ),
        onPressed: () {
          setState(() {
            if (_activeTool == DrawingTool.pen) {
              _penColor = color;
            } else {
              _highlighterColor = color;
            }
            _canvasKey.currentState?.selectedColor = color;
          });
        },
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.white : Colors.white24,
              width: isSelected ? 2.5 : 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

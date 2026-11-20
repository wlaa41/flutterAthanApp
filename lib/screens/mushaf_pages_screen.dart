import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/quran_models.dart';
import '../services/audio_service.dart';
import '../services/mushaf_library.dart';
import '../services/mushaf_pages.dart';
import '../services/quran_service.dart';
import '../services/quran_translation_service.dart';
import '../widgets/mushaf_page.dart';
import '../widgets/mushaf_sheets.dart';
import '../widgets/reader_palette.dart';
import '../widgets/recitation_bar.dart';
import '../widgets/tajweed_legend.dart';
import '../widgets/verse_action_sheet.dart';
import 'quran_reader_screen.dart';
import 'tafsir_screen.dart';

/// Reads the mushaf page by page, as it is printed: the same pages, the same
/// fifteen lines, each line beginning with the same word.
class MushafPagesScreen extends StatefulWidget {
  const MushafPagesScreen({
    super.key,
    this.surah,
    this.hafsAyah,
    this.page,
    this.library,
    this.translations,
    this.bundle,
  });

  /// The surah to open at, when no [page] is given.
  final int? surah;

  /// With [surah]: a verse (in the Hafs count) to open at and mark.
  final int? hafsAyah;

  /// The page to open at, where reading stopped.
  final int? page;
  final MushafLibrary? library;
  final QuranTranslationService? translations;
  final AssetBundle? bundle;

  static const viewKey = 'quran_view';

  /// Whether the reader opens as printed pages. It does unless flowing text
  /// was chosen.
  static Future<bool> preferred() async =>
      (await SharedPreferences.getInstance()).getString(viewKey) != 'flow';

  static Future<void> prefer({required bool printedPages}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(viewKey, printedPages ? 'pages' : 'flow');
  }

  @override
  State<MushafPagesScreen> createState() => _MushafPagesScreenState();
}

class _MushafPagesScreenState extends State<MushafPagesScreen> {
  late final MushafLibrary _library = widget.library ?? MushafLibrary.instance;
  late final QuranTranslationService _translations =
      widget.translations ?? QuranTranslationService.instance;
  PageController? _controller;
  MushafPages? _pages;
  Map<String, int> _highlights = {};
  String? _loadError;
  int _loadId = 0;
  int _page = 1;
  bool _night = false;
  bool _tapHint = false;
  MushafAyah? _selected;

  ReaderPalette get _palette =>
      _night ? ReaderPalette.dark : ReaderPalette.paper;

  @override
  void initState() {
    super.initState();
    AudioService.instance.lastError.addListener(_showAudioError);
    _load();
  }

  @override
  void dispose() {
    AudioService.instance.lastError.removeListener(_showAudioError);
    unawaited(AudioService.instance.stop().catchError((Object _) {}));
    _controller?.dispose();
    super.dispose();
  }

  void _showAudioError() {
    final error = AudioService.instance.lastError.value;
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _load({MushafEdition? edition, int? page}) async {
    final id = ++_loadId;
    if (_loadError != null) setState(() => _loadError = null);
    try {
      final prefs = await SharedPreferences.getInstance();
      final chosen = edition ?? await _library.restoreChoice();
      final text = await _library.load(chosen);
      final pages = await MushafPages.load(text, bundle: widget.bundle);
      final highlights = await QuranService.instance.highlights();
      if (!mounted || id != _loadId) return;
      MushafAyah? marked;
      var start = page ?? widget.page;
      final surah = widget.surah;
      if (start == null && surah != null) {
        final hafsAyah = widget.hafsAyah;
        if (hafsAyah != null) {
          marked = text.ayahForHafs(surah, hafsAyah);
          start = pages.pageOf(marked);
        } else {
          start = pages.pageOfSurah(surah);
        }
      }
      start = (start ?? 1).clamp(1, pages.pageCount);
      final controller = PageController(initialPage: start - 1);
      final old = _controller;
      setState(() {
        _pages = pages;
        _controller = controller;
        _page = start!;
        _highlights = highlights;
        _selected = page == null ? marked : _selected;
        _night = prefs.getBool(QuranReaderScreen.nightKey) ?? _night;
        _tapHint = !(prefs.getBool(QuranReaderScreen.tapHintKey) ?? false);
      });
      old?.dispose();
      _rememberPlace();
    } catch (_) {
      if (!mounted || id != _loadId) return;
      setState(
        () => _loadError = 'This mushaf could not be opened. Try again.',
      );
    }
  }

  void _rememberPlace() {
    final pages = _pages;
    if (pages == null) return;
    unawaited(
      QuranService.instance.saveLastRead(
        LastRead(
          surah: pages.firstAyah(_page).surah,
          page: _page,
          textId: pages.text.edition.textId,
        ),
      ),
    );
  }

  /// The surah a reader on this page would say they are in.
  Surah _surahOf(int page) =>
      QuranService.surahList[_pages!.surahsOn(page).first - 1];

  /// Leaves for the flowing reader at the same place.
  void _openFlowing() {
    final pages = _pages;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => QuranReaderScreen(
          surah: pages == null
              ? QuranService.surahList[(widget.surah ?? 1) - 1]
              : _surahOf(_page),
          openAtPage: pages == null ? null : _page,
          library: widget.library,
          translations: widget.translations,
        ),
      ),
    );
  }

  Future<void> _changeEdition(MushafEdition edition) async {
    final pages = _pages;
    if (pages == null || edition.id == pages.text.edition.id) return;
    await _library.choose(edition);
    if (!mounted) return;
    if (MushafPages.has(edition)) {
      await _load(edition: edition, page: _page);
      return;
    }
    // The other riwayat have no line-by-line layout: they open as text.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${edition.name} opens as flowing text. Printed pages are ready '
            'for the two Hafs copies.',
          ),
        ),
      );
    Navigator.of(context).popUntil((route) => route is! PopupRoute);
    _openFlowing();
  }

  Future<void> _setNight(bool night) async {
    setState(() => _night = night);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(QuranReaderScreen.nightKey, night);
  }

  void _openSettings() {
    final pages = _pages;
    if (pages == null) return;
    MushafSettingsSheet.show(
      context,
      edition: pages.text.edition,
      onEdition: _changeEdition,
      night: _night,
      onNight: _setNight,
      printedPages: true,
      onPrintedPages: (printed) async {
        if (printed) return;
        await MushafPagesScreen.prefer(printedPages: false);
        if (mounted) _openFlowing();
      },
    );
  }

  Future<void> _goToPage() async {
    final pages = _pages;
    if (pages == null) return;
    final chosen = await showDialog<int>(
      context: context,
      builder: (_) => _GoToPageDialog(current: _page, last: pages.pageCount),
    );
    if (chosen == null || !mounted) return;
    _controller?.jumpToPage(chosen - 1);
  }

  Color? _highlightOf(MushafAyah ayah) {
    final argb = _highlights[QuranService.markKey(_pages!.text.edition, ayah)];
    return argb == null ? null : Color(argb);
  }

  void _openVerse(MushafAyah ayah) {
    final pages = _pages;
    if (pages == null) return;
    final edition = pages.text.edition;
    final surah = QuranService.surahList[ayah.surah - 1];
    if (_tapHint) {
      unawaited(
        SharedPreferences.getInstance().then(
          (prefs) => prefs.setBool(QuranReaderScreen.tapHintKey, true),
        ),
      );
    }
    setState(() {
      _selected = ayah;
      _tapHint = false;
    });
    VerseActionSheet.show(
      context,
      surah: surah,
      ayah: ayah,
      edition: edition,
      highlight: _highlightOf(ayah),
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
      onTafsir: () {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => TafsirScreen(
              surah: surah,
              text: pages.text,
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
    final pages = _pages;
    final controller = _controller;
    final ready = pages != null && controller != null;
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
              ready
                  ? pages
                        .surahsOn(_page)
                        .map((s) => QuranService.surahList[s - 1].englishName)
                        .join(', ')
                  : 'Quran',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              ready
                  ? 'Page $_page of ${pages.pageCount}, juz ${pages.firstAyah(_page).juz}'
                  : 'Opening the mushaf',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: Colors.white70),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.find_in_page_outlined, color: Colors.white),
            tooltip: 'Go to page',
            onPressed: ready ? _goToPage : null,
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: ReaderPalette.gold),
            tooltip: 'Mushaf and page',
            onPressed: ready ? _openSettings : null,
          ),
        ],
      ),
      body: !ready
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
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
            )
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  if (_tapHint)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        'Tap a verse for its meaning, tafsir and audio. '
                        'Swipe to turn the page.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: palette.soft),
                      ),
                    ),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // The mushaf opens from the right: the next page
                        // comes in from the left.
                        PageView.builder(
                          controller: controller,
                          reverse: true,
                          // The pages on either side are laid out ahead of
                          // the swipe that brings them in.
                          allowImplicitScrolling: true,
                          itemCount: pages.pageCount,
                          onPageChanged: (index) {
                            setState(() => _page = index + 1);
                            _rememberPlace();
                          },
                          itemBuilder: (context, index) => Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 620),
                              child: MushafPage(
                                key: ValueKey(
                                  '${pages.text.edition.id}-${index + 1}',
                                ),
                                pages: pages,
                                page: index + 1,
                                palette: palette,
                                selected: _selected,
                                highlightOf: _highlightOf,
                                onTap: _openVerse,
                              ),
                            ),
                          ),
                        ),
                        const Positioned(
                          top: 10,
                          left: 16,
                          right: 16,
                          child: RecitationBar(),
                        ),
                      ],
                    ),
                  ),
                  if (pages.text.edition.tajweedColours)
                    TajweedLegend(palette: palette),
                ],
              ),
            ),
    );
  }
}

class _GoToPageDialog extends StatefulWidget {
  const _GoToPageDialog({required this.current, required this.last});

  final int current;
  final int last;

  @override
  State<_GoToPageDialog> createState() => _GoToPageDialogState();
}

class _GoToPageDialogState extends State<_GoToPageDialog> {
  late final TextEditingController _field =
      TextEditingController(text: '${widget.current}')
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: '${widget.current}'.length,
        );

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  int? get _page {
    final page = int.tryParse(_field.text.trim());
    return page != null && page >= 1 && page <= widget.last ? page : null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Go to page'),
      content: TextField(
        controller: _field,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: 'Page, 1 to ${widget.last}',
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) {
          final page = _page;
          if (page != null) Navigator.pop(context, page);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _page == null ? null : () => Navigator.pop(context, _page),
          child: const Text('Go'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../models/quran_models.dart';
import '../services/mushaf_library.dart';
import '../services/quran_service.dart';
import '../widgets/mushaf_sheets.dart';
import '../widgets/reader_palette.dart';
import 'quran_reader_screen.dart';

class QuranIndexScreen extends StatefulWidget {
  const QuranIndexScreen({super.key, this.library});

  final MushafLibrary? library;

  @override
  State<QuranIndexScreen> createState() => _QuranIndexScreenState();
}

class _QuranIndexScreenState extends State<QuranIndexScreen> {
  late final MushafLibrary _library = widget.library ?? MushafLibrary.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filter = 'all'; // 'all', 'meccan', 'medinan'

  /// The chosen mushaf, loaded only when it counts verses differently.
  MushafText? _text;
  LastRead? _lastRead;

  @override
  void initState() {
    super.initState();
    _library.current.addListener(_editionChanged);
    _restore();
  }

  @override
  void dispose() {
    _library.current.removeListener(_editionChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    await _library.restoreChoice();
    await _refreshLastRead();
    _editionChanged();
  }

  Future<void> _refreshLastRead() async {
    final place = await QuranService.instance.lastRead();
    if (mounted) setState(() => _lastRead = place);
  }

  Future<void> _editionChanged() async {
    final edition = _library.current.value;
    if (mounted) setState(() => _text = null);
    if (edition.hafsNumbering) return;
    try {
      final text = await _library.load(edition);
      if (mounted && _library.current.value.id == edition.id) {
        setState(() => _text = text);
      }
    } catch (_) {
      // The list still works with the Hafs counts.
    }
  }

  int _ayahCount(Surah surah) =>
      _text?.surah(surah.number).length ?? surah.numberOfAyahs;

  List<Surah> get _filteredSurahs {
    final query = _searchQuery.trim().toLowerCase();
    return QuranService.surahList.where((s) {
      final matchesQuery =
          query.isEmpty ||
          s.englishName.toLowerCase().contains(query) ||
          s.englishNameTranslation.toLowerCase().contains(query) ||
          s.name.contains(_searchQuery.trim()) ||
          s.number.toString() == query;
      if (!matchesQuery) return false;
      if (_filter == 'meccan') return s.revelationType == 'Meccan';
      if (_filter == 'medinan') return s.revelationType == 'Medinan';
      return true;
    }).toList();
  }

  Future<void> _open(Surah surah, {int? page, int? hafsAyah}) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => QuranReaderScreen(
          surah: surah,
          openAtPage: page,
          openAtHafsAyah: hafsAyah,
          library: widget.library,
        ),
      ),
    );
    await _refreshLastRead();
  }

  void _chooseMushaf() {
    MushafSettingsSheet.show(
      context,
      edition: _library.current.value,
      onEdition: (edition) {
        _library.choose(edition);
        Navigator.pop(context);
      },
    );
  }

  Future<void> _showBookmarks() async {
    final marks = [
      for (final key in (await QuranService.instance.bookmarks()).reversed)
        ?QuranService.parseMark(key),
    ];
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _BookmarksSheet(
        marks: marks,
        onOpen: (mark) async {
          Navigator.pop(sheetContext);
          var hafsAyah = mark.ayah;
          final textId = mark.textId;
          if (textId != null) {
            // A bookmark made in another riwayah keeps that mushaf's number.
            try {
              final text = await _library.load(MushafLibrary.edition(textId));
              final ayat = text.surah(mark.surah);
              if (mark.ayah <= ayat.length) {
                hafsAyah = ayat[mark.ayah - 1].hafsFrom;
              }
            } catch (_) {}
          }
          if (!mounted) return;
          await _open(
            QuranService.surahList[mark.surah - 1],
            hafsAyah: hafsAyah,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surahs = _filteredSurahs;
    final place = _lastRead;
    final showContinue = place != null && _searchQuery.trim().isEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: ReaderPalette.green,
        elevation: 0,
        title: const Text(
          'القرآن الكريم',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: ReaderPalette.gold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Bookmarks',
            icon: const Icon(Icons.bookmarks_outlined, color: Colors.white),
            onPressed: _showBookmarks,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            color: ReaderPalette.green,
            child: Column(
              children: [
                ValueListenableBuilder<MushafEdition>(
                  valueListenable: _library.current,
                  builder: (context, edition, _) => Semantics(
                    button: true,
                    label: 'Mushaf: ${edition.name}. Change',
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _chooseMushaf,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: ReaderPalette.gold.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_stories_outlined,
                              color: ReaderPalette.gold,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Mushaf',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white60,
                                    ),
                                  ),
                                  Text(
                                    edition.name,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Text(
                              'Change',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ReaderPalette.gold,
                              ),
                            ),
                            const Icon(
                              Icons.expand_more,
                              color: ReaderPalette.gold,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search Surah by name or number...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: ReaderPalette.gold,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white70,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.12),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildFilterChip('All (114)', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Meccan (86)', 'meccan'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Medinan (28)', 'medinan'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: surahs.length + (showContinue ? 1 : 0),
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                if (showContinue && index == 0) return _continueTile(place);
                return _surahTile(surahs[index - (showContinue ? 1 : 0)]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _continueTile(LastRead place) {
    final surah = QuranService.surahList[place.surah - 1];
    // A page number belongs to the mushaf it was read in.
    final samePages = place.textId == _library.current.value.textId;
    return ListTile(
      tileColor: const Color(0xFFFBF6E9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: ReaderPalette.gold.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.bookmark_added_outlined,
          color: Color(0xFF7A5A16),
        ),
      ),
      title: const Text(
        'Continue reading',
        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
      ),
      subtitle: Text(
        samePages
            ? '${surah.englishName}, page ${place.page}'
            : surah.englishName,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _open(surah, page: samePages ? place.page : null),
    );
  }

  Widget _surahTile(Surah surah) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      leading: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ReaderPalette.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ReaderPalette.gold.withValues(alpha: 0.4)),
        ),
        child: Text(
          '${surah.number}',
          style: const TextStyle(
            color: ReaderPalette.green,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              surah.englishName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          Text(
            surah.name,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'kfgqpc_hafs',
              fontSize: 21,
              height: 1.3,
              color: Color(0xFF0F766E),
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                '${surah.englishNameTranslation} • ${_ayahCount(surah)} Ayahs',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: surah.revelationType == 'Meccan'
                    ? Colors.amber.shade50
                    : Colors.teal.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                surah.revelationType,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: surah.revelationType == 'Meccan'
                      ? Colors.amber.shade800
                      : Colors.teal.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
      onTap: () => _open(surah),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _filter = value),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? ReaderPalette.gold : Colors.white12,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black87 : Colors.white70,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _BookmarksSheet extends StatefulWidget {
  const _BookmarksSheet({required this.marks, required this.onOpen});

  final List<VerseMark> marks;
  final ValueChanged<VerseMark> onOpen;

  @override
  State<_BookmarksSheet> createState() => _BookmarksSheetState();
}

class _BookmarksSheetState extends State<_BookmarksSheet> {
  late final List<VerseMark> _marks = List.of(widget.marks);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Bookmarks',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (_marks.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Text(
                  'No bookmarks yet. Tap a verse while reading, then Bookmark.',
                  style: TextStyle(height: 1.45, color: Color(0xFF64748B)),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _marks.length,
                  itemBuilder: (context, index) {
                    final mark = _marks[index];
                    final surah = QuranService.surahList[mark.surah - 1];
                    final riwayah = mark.textId == null
                        ? null
                        : MushafLibrary.edition(mark.textId).name;
                    return ListTile(
                      leading: const Icon(
                        Icons.bookmark,
                        color: ReaderPalette.gold,
                      ),
                      title: Text(
                        '${surah.englishName} ${mark.surah}:${mark.ayah}',
                      ),
                      subtitle: riwayah == null ? null : Text(riwayah),
                      trailing: IconButton(
                        tooltip: 'Remove bookmark',
                        icon: const Icon(Icons.close),
                        onPressed: () async {
                          await QuranService.instance.toggleBookmark(mark.key);
                          if (mounted) setState(() => _marks.remove(mark));
                        },
                      ),
                      onTap: () => widget.onOpen(mark),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

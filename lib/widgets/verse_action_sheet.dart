import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/quran_models.dart';
import '../services/audio_service.dart';
import '../services/quran_service.dart';
import '../services/quran_translation_service.dart';

/// What can be done with a verse: read its meaning, open its tafsir, hear it,
/// bookmark, highlight, annotate or copy it.
class VerseActionSheet extends StatefulWidget {
  const VerseActionSheet({
    super.key,
    required this.surah,
    required this.ayah,
    required this.edition,
    required this.highlight,
    required this.onHighlight,
    required this.onTafsir,
    this.onAnnotate,
    this.translations,
  });

  final Surah surah;
  final MushafAyah ayah;
  final MushafEdition edition;

  /// The verse's current highlight colour, if any.
  final Color? highlight;
  final ValueChanged<Color?> onHighlight;

  /// Opens the pen on the page. Left out where the page takes no handwriting.
  final VoidCallback? onAnnotate;
  final VoidCallback onTafsir;
  final QuranTranslationService? translations;

  static const List<Color> highlightColours = [
    Color(0xFFFEF08A),
    Color(0xFFA7F3D0),
    Color(0xFFBAE6FD),
    Color(0xFFFBCFE8),
    Color(0xFFFED7AA),
  ];

  static Future<void> show(
    BuildContext context, {
    required Surah surah,
    required MushafAyah ayah,
    required MushafEdition edition,
    required Color? highlight,
    required ValueChanged<Color?> onHighlight,
    required VoidCallback onTafsir,
    VoidCallback? onAnnotate,
    QuranTranslationService? translations,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => VerseActionSheet(
        surah: surah,
        ayah: ayah,
        edition: edition,
        highlight: highlight,
        onHighlight: onHighlight,
        onAnnotate: onAnnotate,
        onTafsir: onTafsir,
        translations: translations,
      ),
    );
  }

  @override
  State<VerseActionSheet> createState() => _VerseActionSheetState();
}

class _VerseActionSheetState extends State<VerseActionSheet> {
  late final QuranTranslationService _translations =
      widget.translations ?? QuranTranslationService.instance;
  late final String _markKey = QuranService.markKey(
    widget.edition,
    widget.ayah,
  );
  late final Reciter _reciter = Reciter.forEdition(widget.edition);
  late Future<List<String>> _meaning = _loadMeaning();
  late Color? _highlight = widget.highlight;
  bool _playing = false;
  bool _bookmarked = false;

  String get _reference => '${widget.surah.number}:${widget.ayah.number}';

  /// The box below shows a failure itself, so it is not also reported as an
  /// unhandled error when it arrives before the box is listening.
  Future<List<String>> _loadMeaning() =>
      _translations.surah(widget.surah.number)..ignore();

  @override
  void initState() {
    super.initState();
    QuranService.instance.isBookmarked(_markKey).then((marked) {
      if (mounted) setState(() => _bookmarked = marked);
    });
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await AudioService.instance.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    await AudioService.instance.playVerses(
      _reciter.urlsFor(widget.ayah),
      RecitationNow(
        title: '${widget.surah.englishName} $_reference',
        reciter: '${_reciter.name}, ${_reciter.riwayah}',
      ),
    );
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _toggleBookmark() async {
    final marked = await QuranService.instance.toggleBookmark(_markKey);
    if (!mounted) return;
    setState(() => _bookmarked = marked);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(marked ? 'Bookmarked' : 'Bookmark removed'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _copy() async {
    // Copy at once: the meaning is added only if it is already here.
    String? meaning;
    try {
      meaning = QuranTranslationService.forAyah(
        await _meaning.timeout(const Duration(milliseconds: 300)),
        widget.ayah,
      );
    } catch (_) {}
    final lines = [
      widget.ayah.text,
      if (meaning != null && meaning.isNotEmpty) '\n"$meaning"',
      '(${widget.surah.englishName} $_reference, ${widget.edition.name})',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verse copied'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _setHighlight(Color? colour) {
    setState(() => _highlight = colour);
    widget.onHighlight(colour);
  }

  @override
  Widget build(BuildContext context) {
    final ayah = widget.ayah;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.surah.englishName} $_reference',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ayah.numberedAsHafs
                              ? 'Juz ${ayah.juz}, page ${ayah.page}'
                              : 'Juz ${ayah.juz}, page ${ayah.page}. '
                                    '${ayah.hafsReference} in the Hafs count.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _meaningBox(),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _action(
                    icon: _playing
                        ? Icons.stop_circle_rounded
                        : Icons.play_circle_fill,
                    label: _playing ? 'Stop' : 'Play',
                    color: const Color(0xFF0F766E),
                    onTap: _togglePlay,
                  ),
                  _action(
                    icon: Icons.menu_book_rounded,
                    label: 'Tafsir',
                    color: const Color(0xFF0F3931),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onTafsir();
                    },
                  ),
                  _action(
                    icon: _bookmarked ? Icons.bookmark : Icons.bookmark_border,
                    label: _bookmarked ? 'Saved' : 'Bookmark',
                    color: const Color(0xFFA47C2C),
                    onTap: _toggleBookmark,
                  ),
                  if (widget.onAnnotate case final annotate?)
                    _action(
                      icon: Icons.edit,
                      label: 'Note',
                      color: const Color(0xFF2563EB),
                      onTap: () {
                        Navigator.pop(context);
                        annotate();
                      },
                    ),
                  _action(
                    icon: Icons.copy,
                    label: 'Copy',
                    color: const Color(0xFF475569),
                    onTap: _copy,
                  ),
                ],
              ),
              if (!_reciter.matches(widget.edition)) ...[
                const SizedBox(height: 8),
                Text(
                  'Play uses the Hafs recitation. This riwayah has no '
                  'verse-by-verse recording yet.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
              const Divider(height: 24),
              // A Wrap, so large system text moves the colours to a second
              // line instead of off the sheet.
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Text(
                      'Highlight',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  for (final colour in VerseActionSheet.highlightColours)
                    _highlightDot(colour),
                  TextButton(
                    onPressed: _highlight == null
                        ? null
                        : () => _setHighlight(null),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meaningBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: FutureBuilder<List<String>>(
        future: _meaning,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Text(
              'Loading the translation…',
              style: TextStyle(color: Color(0xFF64748B)),
            );
          }
          final verses = snapshot.data;
          if (snapshot.hasError || verses == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The translation of this surah is not on the phone yet. '
                  'It is saved the first time the surah opens online.',
                  style: TextStyle(height: 1.45, color: Color(0xFF334155)),
                ),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _meaning = _loadMeaning();
                  }),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Try again'),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                QuranTranslationService.forAyah(verses, widget.ayah),
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                QuranTranslationService.name,
                style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _highlightDot(Color colour) {
    final chosen = _highlight?.toARGB32() == colour.toARGB32();
    return Semantics(
      button: true,
      selected: chosen,
      label: 'Highlight colour',
      child: InkResponse(
        radius: 22,
        onTap: () => _setHighlight(colour),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colour,
              shape: BoxShape.circle,
              border: Border.all(
                color: chosen ? Colors.black87 : Colors.black12,
                width: chosen ? 2.5 : 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 6),
              // Five labels share the row; a long one shrinks before it is cut.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/quran_models.dart';
import '../services/audio_service.dart';
import '../services/quran_service.dart';

class VerseActionSheet extends StatefulWidget {
  final Surah surah;
  final Ayah ayah;
  final VoidCallback onHighlightChanged;
  final VoidCallback onAnnotatePressed;

  const VerseActionSheet({
    Key? key,
    required this.surah,
    required this.ayah,
    required this.onHighlightChanged,
    required this.onAnnotatePressed,
  }) : super(key: key);

  static void show(
    BuildContext context, {
    required Surah surah,
    required Ayah ayah,
    required VoidCallback onHighlightChanged,
    required VoidCallback onAnnotatePressed,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => VerseActionSheet(
        surah: surah,
        ayah: ayah,
        onHighlightChanged: onHighlightChanged,
        onAnnotatePressed: onAnnotatePressed,
      ),
    );
  }

  @override
  _VerseActionSheetState createState() => _VerseActionSheetState();
}

class _VerseActionSheetState extends State<VerseActionSheet> {
  bool _isPlaying = false;
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    _checkBookmark();
  }

  Future<void> _checkBookmark() async {
    final bookmarked =
        await QuranService.instance.isAyahBookmarked(widget.ayah.number);
    if (mounted) {
      setState(() {
        _isBookmarked = bookmarked;
      });
    }
  }

  void _togglePlay() async {
    if (_isPlaying) {
      await AudioService.instance.stop();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      setState(() => _isPlaying = true);
      await AudioService.instance.playAyah(widget.ayah.number);
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  void _toggleBookmark() async {
    await QuranService.instance.toggleBookmark(widget.ayah.number);
    if (mounted) {
      setState(() {
        _isBookmarked = !_isBookmarked;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isBookmarked
              ? 'Ayah bookmarked successfully'
              : 'Bookmark removed'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _copyToClipboard() {
    final text =
        '${widget.ayah.cleanText}\n\n"${widget.ayah.translation}"\n(Surah ${widget.surah.englishName} ${widget.surah.number}:${widget.ayah.numberInSurah})';
    Clipboard.setData(ClipboardData(text: text));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ayah & translation copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _setHighlight(Color? color) {
    setState(() {
      widget.ayah.highlightColorValue = color?.value;
    });
    widget.onHighlightChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Surah ${widget.surah.englishName} • Ayah ${widget.ayah.numberInSurah}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Juz ${widget.ayah.juz} • Page ${widget.ayah.page}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 14),

          // Translation Preview Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.ayah.translation.isNotEmpty
                      ? widget.ayah.translation
                      : 'Translation loading or unavailable offline.',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '— Saheeh International',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: _isPlaying ? Icons.pause_circle : Icons.play_circle_fill,
                label: _isPlaying ? 'Stop Audio' : 'Play Ayah',
                color: const Color(0xFF0F766E),
                onTap: _togglePlay,
              ),
              _buildActionButton(
                icon: _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                label: 'Bookmark',
                color: const Color(0xFFC5A059),
                onTap: _toggleBookmark,
              ),
              _buildActionButton(
                icon: Icons.edit,
                label: 'Stylus Note',
                color: const Color(0xFF2563EB),
                onTap: () {
                  Navigator.pop(context);
                  widget.onAnnotatePressed();
                },
              ),
              _buildActionButton(
                icon: Icons.copy,
                label: 'Copy',
                color: const Color(0xFF475569),
                onTap: _copyToClipboard,
              ),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(),

          // Quick Highlighter Palette
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Text(
                  'Highlight:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(width: 12),
                _buildHighlightCircle(const Color(0xFFFEF08A)), // Yellow
                _buildHighlightCircle(const Color(0xFFA7F3D0)), // Mint Green
                _buildHighlightCircle(const Color(0xFFBAE6FD)), // Cyan
                _buildHighlightCircle(const Color(0xFFFBCFE8)), // Rose
                _buildHighlightCircle(const Color(0xFFFED7AA)), // Orange
                const Spacer(),
                TextButton(
                  onPressed: () => _setHighlight(null),
                  child: const Text('Clear', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildHighlightCircle(Color color) {
    final isSelected = widget.ayah.highlightColorValue == color.value;
    return GestureDetector(
      onTap: () => _setHighlight(color),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.black87 : Colors.black12,
            width: isSelected ? 2.5 : 1,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

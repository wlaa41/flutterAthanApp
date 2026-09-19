import 'package:flutter/material.dart';
import '../models/drawing_stroke.dart';
import '../models/quran_models.dart';
import '../services/annotation_storage_service.dart';
import '../services/audio_service.dart';
import '../services/quran_service.dart';
import '../widgets/stylus_canvas.dart';
import '../widgets/tajweed_text.dart';
import '../widgets/verse_action_sheet.dart';

class QuranReaderScreen extends StatefulWidget {
  final Surah surah;

  const QuranReaderScreen({
    Key? key,
    required this.surah,
  }) : super(key: key);

  @override
  _QuranReaderScreenState createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  final GlobalKey<StylusCanvasState> _canvasKey = GlobalKey<StylusCanvasState>();

  List<Ayah> _ayahs = [];
  List<DrawingStroke> _strokes = [];
  bool _isLoading = true;
  double _fontSize = 24.0;
  bool _isStylusMode = false;
  int? _selectedAyahNumber;

  // Drawing tool state
  DrawingTool _activeTool = DrawingTool.pen;
  Color _penColor = const Color(0xFFD97706); // Amber Gold
  Color _highlighterColor = const Color(0xFFFEF08A); // Translucent Yellow

  int? _currentPlayingAyah;

  @override
  void initState() {
    super.initState();
    _loadSurahAndAnnotations();

    AudioService.instance.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _currentPlayingAyah = AudioService.instance.currentPlayingAyah;
        });
      }
    });
  }

  Future<void> _loadSurahAndAnnotations() async {
    setState(() => _isLoading = true);

    final ayahs = await QuranService.instance.getSurahAyahs(widget.surah.number);
    final strokes = await AnnotationStorageService.instance
        .loadStrokes('surah_${widget.surah.number}');

    if (mounted) {
      setState(() {
        _ayahs = ayahs;
        _strokes = strokes;
        _isLoading = false;
      });
    }
  }

  void _onStrokesChanged(List<DrawingStroke> updatedStrokes) {
    _strokes = updatedStrokes;
    AnnotationStorageService.instance
        .saveStrokes('surah_${widget.surah.number}', updatedStrokes);
  }

  void _onAyahTapped(Ayah ayah) {
    if (_isStylusMode && _activeTool != DrawingTool.pan) return;

    setState(() {
      _selectedAyahNumber = ayah.number;
    });

    VerseActionSheet.show(
      context,
      surah: widget.surah,
      ayah: ayah,
      onHighlightChanged: () {
        setState(() {});
      },
      onAnnotatePressed: () {
        setState(() {
          _isStylusMode = true;
          _activeTool = DrawingTool.pen;
        });
      },
    );
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await AudioService.instance.stop();
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF8F5), // Traditional cream mushaf paper tone
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F3931),
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            tooltip: 'Return to Surah List',
            onPressed: () async {
              await AudioService.instance.stop();
              Navigator.pop(context);
            },
          ),
          title: Column(
            children: [
              Text(
                'سورة ${widget.surah.name}',
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC5A059),
                ),
              ),
              Text(
                '${widget.surah.englishName} • ${widget.surah.numberOfAyahs} Ayahs',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            // Tajweed Legend Sheet Button
            IconButton(
              icon: const Icon(Icons.palette_outlined, color: Color(0xFFC5A059)),
              tooltip: 'Tajweed Rules Guide',
              onPressed: () => TajweedText.showTajweedLegendModal(context),
            ),
            // Font Size Adjustment
            PopupMenuButton<double>(
              icon: const Icon(Icons.format_size, color: Colors.white),
              tooltip: 'Font Size',
              onSelected: (size) => setState(() => _fontSize = size),
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 20.0, child: Text('Small (20px)')),
                const PopupMenuItem(value: 24.0, child: Text('Medium (24px)')),
                const PopupMenuItem(value: 28.0, child: Text('Large (28px)')),
                const PopupMenuItem(value: 34.0, child: Text('Extra Large (34px)')),
              ],
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F3931)),
                ),
              )
            : Stack(
                children: [
                  // Stylus Canvas Wrapping Quran Content
                  StylusCanvas(
                    key: _canvasKey,
                    storageKey: 'surah_${widget.surah.number}',
                    initialStrokes: _strokes,
                    onStrokesChanged: _onStrokesChanged,
                    isDrawingActive: _isStylusMode,
                    child: SingleChildScrollView(
                      physics: (_isStylusMode && _activeTool != DrawingTool.pan)
                          ? const NeverScrollableScrollPhysics()
                          : const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                          16, _currentPlayingAyah != null ? 70 : 16, 16, 120),
                    child: Column(
                      children: [
                        // Surah Header Banner
                        _buildSurahHeaderBanner(),

                        // Bismillah (except Surah At-Tawba #9 and Al-Fatiha #1 where it is Ayah 1)
                        if (widget.surah.number != 9 && widget.surah.number != 1)
                          _buildBismillah(),

                        const SizedBox(height: 12),

                        // Ayahs with Tajweed & Clickable behavior
                        Wrap(
                          alignment: WrapAlignment.center,
                          textDirection: TextDirection.rtl,
                          spacing: 4,
                          runSpacing: 8,
                          children: _ayahs.map((ayah) {
                            return TajweedText(
                              ayah: ayah,
                              fontSize: _fontSize,
                              isSelected: _selectedAyahNumber == ayah.number,
                              onTap: () => _onAyahTapped(ayah),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),

                // Floating Active Audio Reciter Bar
                if (_currentPlayingAyah != null)
                  Positioned(
                    top: 10,
                    left: 16,
                    right: 16,
                    child: _buildFloatingAudioPlayer(),
                  ),

                // Floating Stylus / Highlighter Control Panel
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: _buildStylusToolbar(),
                ),
              ],
            ),
    );
  }

  Widget _buildFloatingAudioPlayer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F3931),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFC5A059), width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(Icons.graphic_eq, color: Color(0xFFC5A059), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Reciting Ayah $_currentPlayingAyah',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Text(
                  'Sheikh Mishary Rashid Alafasy',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.stop_circle_rounded,
                color: Colors.white, size: 26),
            tooltip: 'Stop Recitation',
            onPressed: () async {
              await AudioService.instance.stop();
              setState(() => _currentPlayingAyah = null);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSurahHeaderBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F3931),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC5A059), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${widget.surah.revelationType} • ${widget.surah.numberOfAyahs} Verses',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            'سورة ${widget.surah.name}',
            style: const TextStyle(
              fontFamily: 'serif',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFC5A059),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBismillah() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: const Text(
        'بِسْمِ اللَّهِ الرَّحْمَـٰنِ الرَّحِيمِ',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'serif',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0F766E),
        ),
      ),
    );
  }

  Widget _buildStylusToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.94),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFFC5A059).withOpacity(0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Mode switcher & tools
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Toggle Read vs Draw Mode
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isStylusMode = !_isStylusMode;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _isStylusMode
                            ? 'Stylus Mode ON: Write & Highlight on Quran'
                            : 'Read Mode ON: Scroll & Tap Verses',
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isStylusMode
                        ? const Color(0xFFC5A059)
                        : Colors.white12,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isStylusMode ? Icons.edit : Icons.menu_book,
                        size: 16,
                        color: _isStylusMode ? Colors.black87 : Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isStylusMode ? 'Stylus' : 'Read',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _isStylusMode ? Colors.black87 : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_isStylusMode) ...[
                // Pen Tool
                IconButton(
                  icon: Icon(
                    Icons.create,
                    color: _activeTool == DrawingTool.pen
                        ? const Color(0xFFC5A059)
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

                // Highlighter Tool
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

                // Eraser Tool
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

                // Pan / Hand Scroll Tool
                IconButton(
                  icon: Icon(
                    Icons.pan_tool_outlined,
                    color: _activeTool == DrawingTool.pan
                        ? const Color(0xFFC5A059)
                        : Colors.white60,
                    size: 20,
                  ),
                  tooltip: 'Pan / Scroll Page',
                  onPressed: () {
                    setState(() => _activeTool = DrawingTool.pan);
                    _canvasKey.currentState?.currentTool = DrawingTool.pan;
                  },
                ),

                // Undo
                IconButton(
                  icon: const Icon(Icons.undo, color: Colors.white70, size: 20),
                  tooltip: 'Undo',
                  onPressed: () => _canvasKey.currentState?.undo(),
                ),

                // Clear All
                IconButton(
                  icon: const Icon(Icons.delete_sweep,
                      color: Colors.white70, size: 20),
                  tooltip: 'Clear Page Drawing',
                  onPressed: () {
                    _canvasKey.currentState?.clearAll();
                  },
                ),
              ] else ...[
                const Text(
                  'Tap any verse for audio & translation',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ],
          ),

          // Row 2 (When in Stylus mode): Quick Color Palette
          if (_isStylusMode && _activeTool != DrawingTool.eraser) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Ink: ',
                    style: TextStyle(color: Colors.white60, fontSize: 11)),
                if (_activeTool == DrawingTool.pen) ...[
                  _buildColorDot(const Color(0xFFD97706)), // Gold
                  _buildColorDot(const Color(0xFFEF4444)), // Coral
                  _buildColorDot(const Color(0xFF3B82F6)), // Sky Blue
                  _buildColorDot(const Color(0xFF10B981)), // Emerald
                  _buildColorDot(const Color(0xFFFFFFFF)), // White
                ] else ...[
                  _buildColorDot(const Color(0xFFFEF08A)), // Yellow
                  _buildColorDot(const Color(0xFFA7F3D0)), // Mint
                  _buildColorDot(const Color(0xFFBAE6FD)), // Cyan
                  _buildColorDot(const Color(0xFFFBCFE8)), // Pink
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
        ? _penColor.value == color.value
        : _highlighterColor.value == color.value;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_activeTool == DrawingTool.pen) {
            _penColor = color;
            _canvasKey.currentState?.selectedColor = color;
          } else {
            _highlighterColor = color;
            _canvasKey.currentState?.selectedColor = color;
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
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
    );
  }
}

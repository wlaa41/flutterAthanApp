import 'package:flutter/material.dart';
import '../models/drawing_stroke.dart';

class StylusCanvas extends StatefulWidget {
  final Widget child;
  final String storageKey; // e.g. "surah_1"
  final List<DrawingStroke> initialStrokes;
  final Function(List<DrawingStroke>) onStrokesChanged;
  final bool isDrawingActive;

  const StylusCanvas({
    Key? key,
    required this.child,
    required this.storageKey,
    required this.initialStrokes,
    required this.onStrokesChanged,
    required this.isDrawingActive,
  }) : super(key: key);

  @override
  StylusCanvasState createState() => StylusCanvasState();
}

class StylusCanvasState extends State<StylusCanvas> {
  late List<DrawingStroke> _strokes;
  final List<DrawingStroke> _redoHistory = [];
  DrawingStroke? _currentStroke;

  DrawingTool currentTool = DrawingTool.pen;
  Color selectedColor = const Color(0xFFD97706); // Amber Gold default
  double penWidth = 2.5;
  double highlighterWidth = 20.0;

  @override
  void initState() {
    super.initState();
    _strokes = List.from(widget.initialStrokes);
  }

  @override
  void didUpdateWidget(covariant StylusCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storageKey != widget.storageKey) {
      _strokes = List.from(widget.initialStrokes);
      _redoHistory.clear();
      _currentStroke = null;
    }
  }

  void undo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _redoHistory.add(_strokes.removeLast());
      });
      widget.onStrokesChanged(_strokes);
    }
  }

  void redo() {
    if (_redoHistory.isNotEmpty) {
      setState(() {
        _strokes.add(_redoHistory.removeLast());
      });
      widget.onStrokesChanged(_strokes);
    }
  }

  void clearAll() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _strokes.clear();
        _redoHistory.clear();
      });
      widget.onStrokesChanged(_strokes);
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (!_canDraw) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);

    if (currentTool == DrawingTool.eraser) {
      _eraseAt(localPosition);
      return;
    }

    setState(() {
      final isHighlighter = currentTool == DrawingTool.highlighter;
      final strokeWidth = isHighlighter ? highlighterWidth : penWidth;

      _currentStroke = DrawingStroke(
        points: [
          DrawingPoint(
            x: localPosition.dx,
            y: localPosition.dy,
          ),
        ],
        colorValue: selectedColor.value,
        strokeWidth: strokeWidth,
        isHighlighter: isHighlighter,
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_canDraw) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);

    if (currentTool == DrawingTool.eraser) {
      _eraseAt(localPosition);
      return;
    }

    if (_currentStroke != null) {
      setState(() {
        _currentStroke!.points.add(
          DrawingPoint(
            x: localPosition.dx,
            y: localPosition.dy,
          ),
        );
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_canDraw) return;

    if (_currentStroke != null) {
      setState(() {
        _strokes.add(_currentStroke!);
        _currentStroke = null;
        _redoHistory.clear();
      });
      widget.onStrokesChanged(_strokes);
    }
  }

  void _eraseAt(Offset position) {
    const eraseRadius = 24.0;
    bool modified = false;

    setState(() {
      _strokes.removeWhere((stroke) {
        for (final p in stroke.points) {
          if ((Offset(p.x, p.y) - position).distance < eraseRadius) {
            modified = true;
            return true;
          }
        }
        return false;
      });
    });

    if (modified) {
      widget.onStrokesChanged(_strokes);
    }
  }

  bool get _canDraw => widget.isDrawingActive && currentTool != DrawingTool.pan;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Underlying Quran Text / Reader content
        widget.child,

        // Drawing layer overlay
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_canDraw,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: CustomPaint(
                painter: _CanvasPainter(
                  strokes: _strokes,
                  activeStroke: _currentStroke,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CanvasPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final DrawingStroke? activeStroke;

  _CanvasPainter({
    required this.strokes,
    required this.activeStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw finalized strokes
    for (final stroke in strokes) {
      _drawSingleStroke(canvas, stroke);
    }

    // Draw ongoing stroke
    if (activeStroke != null) {
      _drawSingleStroke(canvas, activeStroke!);
    }
  }

  void _drawSingleStroke(Canvas canvas, DrawingStroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke.strokeWidth;

    if (stroke.isHighlighter) {
      // Semi-transparent overlay with soft blend mode
      paint.color = stroke.color.withOpacity(0.38);
      paint.blendMode = BlendMode.srcOver;
    } else {
      paint.color = stroke.color;
    }

    if (stroke.points.length == 1) {
      final p = stroke.points.first.offset;
      canvas.drawCircle(
        p,
        stroke.strokeWidth / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    final path = Path();
    path.moveTo(stroke.points[0].x, stroke.points[0].y);

    for (int i = 1; i < stroke.points.length; i++) {
      final prev = stroke.points[i - 1].offset;
      final cur = stroke.points[i].offset;
      final mid = Offset((prev.dx + cur.dx) / 2, (prev.dy + cur.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }

    final last = stroke.points.last.offset;
    path.lineTo(last.dx, last.dy);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter oldDelegate) => true;
}

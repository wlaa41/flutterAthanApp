import 'dart:ui';
import 'package:flutter/material.dart';

enum DrawingTool {
  pen,
  highlighter,
  eraser,
  pan, // Allows scrolling/panning while in stylus mode
}

class DrawingPoint {
  final double x;
  final double y;
  final double pressure;

  DrawingPoint({
    required this.x,
    required this.y,
    this.pressure = 1.0,
  });

  Offset get offset => Offset(x, y);

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'pressure': pressure,
    };
  }

  factory DrawingPoint.fromJson(Map<String, dynamic> json) {
    return DrawingPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      pressure: (json['pressure'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class DrawingStroke {
  final List<DrawingPoint> points;
  final int colorValue;
  final double strokeWidth;
  final bool isHighlighter;

  DrawingStroke({
    required this.points,
    required this.colorValue,
    required this.strokeWidth,
    this.isHighlighter = false,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() {
    return {
      'points': points.map((p) => p.toJson()).toList(),
      'colorValue': colorValue,
      'strokeWidth': strokeWidth,
      'isHighlighter': isHighlighter,
    };
  }

  factory DrawingStroke.fromJson(Map<String, dynamic> json) {
    final pointsList = (json['points'] as List<dynamic>?)
            ?.map((p) => DrawingPoint.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [];

    return DrawingStroke(
      points: pointsList,
      colorValue: json['colorValue'] as int? ?? Colors.black.value,
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 3.0,
      isHighlighter: json['isHighlighter'] as bool? ?? false,
    );
  }
}

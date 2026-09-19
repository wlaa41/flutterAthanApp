import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/drawing_stroke.dart';

class AnnotationStorageService {
  static final AnnotationStorageService instance =
      AnnotationStorageService._internal();
  AnnotationStorageService._internal();

  /// Save strokes for a given Surah or Page key (e.g. "surah_1" or "page_50")
  Future<void> saveStrokes(String key, List<DrawingStroke> strokes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = strokes.map((s) => s.toJson()).toList();
      final encoded = jsonEncode(jsonList);
      await prefs.setString('annotations_$key', encoded);
    } catch (e) {
      debugPrint('AnnotationStorageService: Error saving strokes: $e');
    }
  }

  /// Load strokes for a given key
  Future<List<DrawingStroke>> loadStrokes(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString('annotations_$key');
      if (encoded != null && encoded.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(encoded);
        return decoded
            .map((item) => DrawingStroke.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('AnnotationStorageService: Error loading strokes: $e');
    }
    return [];
  }

  /// Clear all strokes for a given key
  Future<void> clearStrokes(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('annotations_$key');
    } catch (e) {
      debugPrint('AnnotationStorageService: Error clearing strokes: $e');
    }
  }
}

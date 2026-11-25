import 'package:flutter/foundation.dart';

import '../models/journey.dart';
import 'audio_service.dart';

/// Plays ayahs of the surah for the journey, one thing at a time.
class JourneyAudio {
  /// What is playing now: the key its button gave, or null.
  static final ValueNotifier<String?> playing = ValueNotifier(null);

  /// Stands in for the phone's player in tests.
  @visibleForTesting
  static Future<bool> Function(List<int> ayahs)? player;

  /// Plays [ayahs] in order, or stops them if [key] is what is playing.
  /// Answers false when they could not be loaded.
  static Future<bool> toggle(String key, List<int> ayahs) async {
    if (playing.value == key) {
      await stop();
      return true;
    }
    playing.value = key;
    try {
      final stand = player;
      if (stand != null) return await stand(ayahs);
      final service = AudioService.instance;
      await service.playVerses([
        for (final ayah in ayahs) Reciter.alafasy.url(Journey.surah, ayah),
      ], RecitationNow(title: 'Al-Kahf', reciter: Reciter.alafasy.name));
      return service.lastError.value == null;
    } finally {
      if (playing.value == key) playing.value = null;
    }
  }

  static Future<void> stop() async {
    final was = playing.value;
    playing.value = null;
    if (was != null && player == null) {
      try {
        await AudioService.instance.stop();
      } catch (_) {}
    }
  }
}

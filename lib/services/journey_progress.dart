import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/journey.dart';

/// What the player has done on the journey, kept on the phone.
class JourneyProgress {
  JourneyProgress({
    this.level,
    Set<String>? done,
    Map<int, int>? missed,
    Map<int, int>? recited,
  }) : done = done ?? {},
       missed = missed ?? {},
       recited = recited ?? {};

  static const key = 'journey_kahf_v1';

  /// Null until the player has chosen how to play.
  JourneyLevel? level;

  /// The stops whose lantern is lit. One set for all three levels.
  final Set<String> done;

  /// Ayahs answered wrong and not yet answered right again, with the count.
  final Map<int, int> missed;

  /// The best share of an ayah's words heard in a recitation, in percent.
  final Map<int, int> recited;

  /// Where the Meaning challenge, which this game replaced, kept its scores.
  static const _oldKey = 'quiz_progress_kahf';

  static Future<JourneyProgress> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_oldKey)) await prefs.remove(_oldKey);
    return decode(prefs.getString(key));
  }

  static JourneyProgress decode(String? text) {
    if (text == null || text.isEmpty) return JourneyProgress();
    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
      Map<int, int> numbers(Object? value) => {
        for (final entry in (value as Map<String, dynamic>? ?? {}).entries)
          if (int.tryParse(entry.key) != null && entry.value is int)
            int.parse(entry.key): entry.value as int,
      };
      final level = json['level'];
      return JourneyProgress(
        level: level is int && level >= 0 && level < JourneyLevel.values.length
            ? JourneyLevel.values[level]
            : null,
        done: {for (final id in json['done'] as List? ?? []) id as String},
        missed: numbers(json['missed']),
        recited: numbers(json['recited']),
      );
    } catch (_) {
      return JourneyProgress();
    }
  }

  String encode() => jsonEncode({
    'level': level?.index,
    'done': done.toList()..sort(),
    'missed': {for (final e in missed.entries) '${e.key}': e.value},
    'recited': {for (final e in recited.entries) '${e.key}': e.value},
  });

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, encode());
  }

  /// A wrong answer is remembered until the ayah is answered right again,
  /// so a later stop can bring it back.
  void answered(int ayah, {required bool right}) {
    if (right) {
      missed.remove(ayah);
    } else {
      missed[ayah] = (missed[ayah] ?? 0) + 1;
    }
  }

  /// Keeps the best recitation of an ayah. Returns whether this one is.
  bool recitedAyah(int ayah, int heard, int total) {
    if (total <= 0) return false;
    final percent = (heard * 100 / total).round().clamp(0, 100);
    if (percent <= (recited[ayah] ?? -1)) return false;
    recited[ayah] = percent;
    return true;
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_pro/models/journey.dart';

/// The journey as the app loads it, read straight from the repository.
Journey readJourney() {
  final content =
      jsonDecode(File('asset/journey/kahf.json').readAsStringSync())
          as Map<String, dynamic>;
  final hafs =
      jsonDecode(File('asset/quran/hafs.json').readAsStringSync())
          as Map<String, dynamic>;
  final kahf = (hafs['surahs'] as List)[Journey.surah - 1] as List;
  return Journey.fromJson(content, [
    for (final ayah in kahf) (ayah as List).first as String,
  ], basmalah: hafs['basmalah'] as String);
}

/// Loads the journey's own fonts, so a test lays text out as a phone does
/// and not in the test font's wide boxes. Call it from setUpAll.
Future<void> loadJourneyFonts() async {
  Future<ByteData> read(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());
  final baloo = FontLoader('baloo');
  for (final weight in const [400, 600, 700, 800]) {
    baloo.addFont(read('asset/fonts/baloo_$weight.ttf'));
  }
  await baloo.load();
  await (FontLoader(
    'kfgqpc_hafs',
  )..addFont(read('asset/fonts/kfgqpc_hafs.ttf'))).load();
  await (FontLoader(
    'journey_signs',
  )..addFont(read('asset/fonts/journey_signs.ttf'))).load();
}

/// Surah 18 of one of the works the journey quotes, as QuranEnc.com served
/// it: the file kept in tools/sources/quranenc, ayah 1 first.
List<Map<String, dynamic>> readSource(String key) => [
  for (final row
      in (jsonDecode(
                File(
                  'tools/sources/quranenc/${key}_18.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>)['result']
          as List)
    row as Map<String, dynamic>,
];

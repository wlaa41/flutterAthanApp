import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/services/sound_library.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Every preview and iOS alert sound is bundled locally', () async {
    for (final sound in SoundCatalog.builtIns) {
      if (sound.assetPath != null) {
        expect(await File(sound.assetPath!).length(), greaterThan(44));
      }
      if (sound.iosSound != null) {
        final bytes = await File('asset/${sound.iosSound}').readAsBytes();
        expect(SoundLibrary.isPcmWave(bytes), isTrue, reason: sound.id);
        // The longest shipped excerpt is 28 seconds at 22050Hz mono PCM16.
        expect(bytes.length, lessThan(30 * 22050 * 2 + 200));
      }
    }
  });

  test('Quiet choices never accidentally preview a loud recording', () {
    expect(SoundCatalog.byId('silent').canPreview, isFalse);
    expect(SoundCatalog.byId('vibrate').canPreview, isFalse);
    expect(SoundCatalog.byId('beep').kind, SoundKind.tone);
  });

  test(
    'Damaged or missing custom audio retains built-ins and safe fallback',
    () async {
      SharedPreferences.setMockInitialValues({
        'custom_alert_sounds_v1': [
          'not-json',
          '{"id":"custom_missing","filePath":"missing.mp3"}',
        ],
      });
      expect(
        await SoundLibrary.instance.loadSounds(),
        hasLength(SoundCatalog.builtIns.length),
      );
      expect(
        (await SoundLibrary.instance.resolve('custom_missing')).id,
        'beep',
      );
    },
  );

  test('Rejects corrupt or compressed WAV headers for iOS alerts', () async {
    expect(SoundLibrary.isPcmWave(Uint8List(0)), isFalse);
    final bytes = await File('asset/beep.wav').readAsBytes();
    final compressed = Uint8List.fromList(bytes);
    ByteData.sublistView(compressed).setUint16(20, 3, Endian.little);
    expect(SoundLibrary.isPcmWave(compressed), isFalse);
    expect(SoundLibrary.isPcmWave(bytes.sublist(0, 25)), isFalse);
  });
}

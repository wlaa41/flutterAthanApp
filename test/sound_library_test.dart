import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/services/sound_library.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Every platform maps to the correct bundled sound', () async {
    expect(
      SoundCatalog.builtIns.map((sound) => sound.id).toSet(),
      hasLength(SoundCatalog.builtIns.length),
    );
    for (final sound in SoundCatalog.builtIns) {
      if (sound.assetPath != null) {
        final preview = await File(sound.assetPath!).readAsBytes();
        expect(preview.length, greaterThan(44));
        expect(sound.androidResource, isNotNull, reason: sound.id);
        final extension = sound.assetPath!.split('.').last;
        final android = await File(
          'android/app/src/main/res/raw/${sound.androidResource}.$extension',
        ).readAsBytes();
        expect(listEquals(preview, android), isTrue, reason: sound.id);
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

  group('Bounded picker stream copy', () {
    late Directory directory;
    late File target;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('athan-import-test-');
      target = File('${directory.path}/audio.wav');
    });
    tearDown(() async {
      if (await target.exists()) await target.delete();
      await directory.delete();
    });

    test('Accepts an unknown-length stream exactly at the cap', () async {
      await SoundLibrary.copyBoundedAudio(
        Stream.fromIterable([
          [1, 2],
          [3, 4],
        ]),
        target,
        byteLimit: 4,
      );
      expect(await target.readAsBytes(), [1, 2, 3, 4]);
    });

    test('Rejects excess bytes and removes the partial file', () async {
      await expectLater(
        SoundLibrary.copyBoundedAudio(
          Stream.fromIterable([
            [1, 2],
            [3, 4],
          ]),
          target,
          byteLimit: 3,
        ),
        throwsFormatException,
      );
      expect(await target.exists(), isFalse);
    });

    test('Rejects an empty stream without keeping a file', () async {
      await expectLater(
        SoundLibrary.copyBoundedAudio(const Stream<List<int>>.empty(), target),
        throwsFormatException,
      );
      expect(await target.exists(), isFalse);
    });

    test('Removes partial data when a remote file read fails', () async {
      Stream<List<int>> brokenSource() async* {
        yield [1, 2];
        throw StateError('Remote file became unavailable');
      }

      await expectLater(
        SoundLibrary.copyBoundedAudio(brokenSource(), target),
        throwsStateError,
      );
      expect(await target.exists(), isFalse);
    });
  });
}

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_pro/services/recitation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'journey_support.dart';

void main() {
  final journey = readJourney();
  List<String> words(int ayah) => journey.verse(ayah).split(' ');
  String spoken(int ayah) => words(ayah).map(recitationLetters).join(' ');

  test('letters are written the way the model writes them', () {
    expect(spoken(9), 'ام حسبت ان اصحب الكهف والرقيم كانوا من ءايتنا عجبا');
    expect(recitationLetters('ٱلۡمَدِينَةِ'), 'المدينه');
    expect(recitationLetters('يَٰمُوسَىٰٓ'), 'يموسي');
    // The hizb sign in front of ayah 32 is not a word.
    expect(spoken(32).split(' ').first, 'واضرب');
    expect(spoken(32).split(' '), hasLength(words(32).length));
  });

  test('every ayah of the surah, recited whole, is heard whole', () {
    for (var ayah = 1; ayah <= 110; ayah++) {
      final match = matchRecitation(words(ayah), spoken(ayah));
      // One mark for each word on the screen, so none may be dropped.
      expect(match.total, words(ayah).length, reason: 'ayah $ayah');
      expect(match.complete, isTrue, reason: 'ayah $ayah');
    }
  });

  test('the ayah before or after is not heard as this one', () {
    for (var ayah = 2; ayah <= 109; ayah++) {
      for (final other in [ayah - 1, ayah + 1]) {
        // Three ayahs of Dhul-Qarnayn's story are the same words.
        if (spoken(other) == spoken(ayah)) continue;
        final match = matchRecitation(words(ayah), spoken(other));
        expect(match.complete, isFalse, reason: 'ayah $ayah heard in $other');
      }
    }
  });

  test('missed words are marked, the others stay heard', () {
    final all = spoken(10).split(' ');
    final said = [...all]
      ..removeAt(11)
      ..removeAt(9);
    final match = matchRecitation(words(10), said.join(' '));
    expect(match.count, 14);
    expect(match.total, 16);
    expect(
      [
        for (var i = 0; i < 16; i++)
          if (!match.heard[i]) i,
      ],
      [9, 11],
    );
  });

  test('a slip in a long word is forgiven, a different word is not', () {
    final all = spoken(10).split(' ');
    // One letter off in a five-letter word.
    final slip = [...all]..[2] = 'الفتيت';
    expect(matchRecitation(words(10), slip.join(' ')).complete, isTrue);
    final other = [...all]..[2] = 'القوم';
    final match = matchRecitation(words(10), other.join(' '));
    expect(match.heard[2], isFalse);
    expect(match.count, 15);
    // A two-letter word has to be exact.
    final small = [...all]..[8] = 'في';
    expect(matchRecitation(words(10), small.join(' ')).heard[8], isFalse);
  });

  test('joined and split words still count', () {
    final all = spoken(10).split(' ');
    final joined = [...all.take(8), all[8] + all[9], ...all.skip(10)];
    expect(matchRecitation(words(10), joined.join(' ')).complete, isTrue);
    final split = [...all];
    split[5] = 'فقا لوا';
    expect(matchRecitation(words(10), split.join(' ')).complete, isTrue);
  });

  test('words said before or after the ayah are passed over', () {
    final said = '${spoken(9)} ${spoken(10)} ${spoken(11)}';
    final match = matchRecitation(words(10), said);
    expect(match.complete, isTrue);
  });

  test('silence, or another ayah, is not heard as this one', () {
    expect(matchRecitation(words(10), '').count, 0);
    final match = matchRecitation(words(10), spoken(45));
    expect(match.count, lessThan(4));
  });

  test('a recording is read from a 16-bit WAV file', () {
    final samples = Int16List.fromList([0, 16384, -16384, 32767, -32768, 100]);
    final body = samples.buffer.asUint8List();
    final header = ByteData(44)
      ..setUint32(0, 0x52494646) // RIFF
      ..setUint32(4, 36 + body.length, Endian.little)
      ..setUint32(8, 0x57415645) // WAVE
      ..setUint32(12, 0x666d7420) // fmt
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, 1, Endian.little)
      ..setUint32(24, 16000, Endian.little)
      ..setUint32(28, 32000, Endian.little)
      ..setUint16(32, 2, Endian.little)
      ..setUint16(34, 16, Endian.little)
      ..setUint32(36, 0x64617461) // data
      ..setUint32(40, body.length, Endian.little);
    final sound = RecitationSound.fromWav(
      Uint8List.fromList([...header.buffer.asUint8List(), ...body]),
    )!;
    expect(sound.sampleRate, 16000);
    expect(sound.samples, hasLength(6));
    expect(sound.samples[1], closeTo(0.5, 1e-6));
    expect(sound.samples[4], -1.0);
    expect(RecitationSound.fromWav(Uint8List(10)), isNull);
  });

  test('other plain WAV files are read too: padding, floats, two channels', () {
    // An iPhone may pad the header with a filler chunk and write the long
    // form of it; a recorder may write floats, or two channels.
    Uint8List wav({
      required int format,
      required int bits,
      required int channels,
      required List<int> body,
      bool long = false,
      bool filler = false,
      bool sized = true,
    }) {
      final fmt = ByteData(long ? 40 : 16)
        ..setUint16(0, long ? 0xFFFE : format, Endian.little)
        ..setUint16(2, channels, Endian.little)
        ..setUint32(4, 44100, Endian.little)
        ..setUint32(8, 44100 * channels * bits ~/ 8, Endian.little)
        ..setUint16(12, channels * bits ~/ 8, Endian.little)
        ..setUint16(14, bits, Endian.little);
      if (long) {
        fmt
          ..setUint16(16, 22, Endian.little)
          ..setUint16(24, format, Endian.little);
      }
      List<int> chunk(String name, List<int> bytes, {int? size}) => [
        ...name.codeUnits,
        ...(ByteData(4)..setUint32(0, size ?? bytes.length, Endian.little))
            .buffer
            .asUint8List(),
        ...bytes,
        if (bytes.length.isOdd) 0,
      ];
      final chunks = [
        ...chunk('fmt ', fmt.buffer.asUint8List()),
        if (filler) ...chunk('FLLR', List.filled(31, 0)),
        ...chunk('data', body, size: sized ? null : 0),
      ];
      return Uint8List.fromList([
        ...'RIFF'.codeUnits,
        ...(ByteData(
          4,
        )..setUint32(0, 4 + chunks.length, Endian.little)).buffer.asUint8List(),
        ...'WAVE'.codeUnits,
        ...chunks,
      ]);
    }

    final floats = Float32List.fromList([0.25, -0.5, 1, 0]);
    var sound = RecitationSound.fromWav(
      wav(
        format: 3,
        bits: 32,
        channels: 1,
        body: floats.buffer.asUint8List(),
        long: true,
        filler: true,
      ),
    )!;
    expect(sound.sampleRate, 44100);
    expect(sound.samples, [0.25, -0.5, 1, 0]);

    // Two channels of 16 bits, the size left unwritten: the first is taken.
    final pairs = Int16List.fromList([16384, 1, -16384, 2, 8192, 3]);
    sound = RecitationSound.fromWav(
      wav(
        format: 1,
        bits: 16,
        channels: 2,
        body: pairs.buffer.asUint8List(),
        sized: false,
      ),
    )!;
    expect(sound.samples, [0.5, -0.5, 0.25]);

    // 24 bits: 0x400000 is a half, 0xC00000 is minus a half.
    sound = RecitationSound.fromWav(
      wav(
        format: 1,
        bits: 24,
        channels: 1,
        body: [0, 0, 0x40, 0, 0, 0xC0, 0xFF, 0xFF, 0x7F],
      ),
    )!;
    expect(sound.samples[0], 0.5);
    expect(sound.samples[1], -0.5);
    expect(sound.samples[2], closeTo(1, 1e-6));

    // A compressed format is not guessed at.
    expect(
      RecitationSound.fromWav(
        wav(format: 0x55, bits: 16, channels: 1, body: List.filled(64, 1)),
      ),
      isNull,
    );
  });

  // Runs the real model when it and some recitations are on this machine:
  //   RECITATION_MODEL=<folder with model.int8.onnx and tokens.txt>
  //   RECITATION_AUDIO=<folder with <reciter>_018<ayah>.wav files>
  //   RECITATION_LIB=<folder with libsherpa-onnx-c-api.so>
  final model = Platform.environment['RECITATION_MODEL'];
  final audio = Platform.environment['RECITATION_AUDIO'];
  test(
    'the model hears real recitations of Al-Kahf',
    () async {
      final clips =
          Directory(audio!)
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.wav'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      expect(clips, isNotEmpty);
      for (final clip in clips) {
        final name = clip.uri.pathSegments.last;
        final ayah = int.parse(
          name.substring(name.length - 7, name.length - 4),
        );
        final sound = RecitationSound.fromWav(await clip.readAsBytes())!;
        final heard = await RecitationEngine.hear(
          sound,
          Directory(model!),
          libraryPath: Platform.environment['RECITATION_LIB'],
        );
        final match = matchRecitation(words(ayah), heard);
        // ignore: avoid_print
        print('$name: ${match.count} of ${match.total} words');
        expect(match.count / match.total, greaterThan(0.9), reason: name);
      }
    },
    skip: model == null || audio == null,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

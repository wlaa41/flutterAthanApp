import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/services/mp3_cutter.dart';

import 'support_mp3.dart';

void main() {
  test('The playing time is the sum of the frames', () {
    final duration = Mp3Cutter.duration(fakeMp3(100))!;
    expect(duration.inMicroseconds, closeTo(100 * mp3FrameSeconds * 1e6, 2));
    expect(Mp3Cutter.duration(Uint8List(5000)), isNull);
  });

  test('A cut starts on the first frame at or after the chosen time', () {
    final cut = Mp3Cutter.tail(fakeMp3(100), const Duration(seconds: 1));
    // 39 frames last 1.019 s, the first whole number of frames past 1 s.
    expect(cut.length, 61 * mp3FrameBytes);
    expect(cut[0], 0xFF);
    expect(cut[4], 39);
    expect(Mp3Cutter.firstFrame(cut), 0);
  });

  test('Tags at either end are left out of the cut', () {
    final tagged = fakeMp3(100, id3v2: true, id3v1: true);
    expect(Mp3Cutter.firstFrame(tagged), 20);
    final cut = Mp3Cutter.tail(tagged, const Duration(seconds: 1));
    expect(cut.length, 61 * mp3FrameBytes);
    expect(cut[4], 39);
  });

  test('A cut at zero keeps every frame', () {
    final cut = Mp3Cutter.tail(fakeMp3(10, id3v2: true), Duration.zero);
    expect(cut.length, 10 * mp3FrameBytes);
    expect(cut[4], 0);
  });

  test('Anything that is not a long enough MP3 is refused', () {
    expect(
      () => Mp3Cutter.tail(Uint8List(5000), const Duration(seconds: 1)),
      throwsFormatException,
    );
    expect(
      () => Mp3Cutter.tail(fakeMp3(10), const Duration(seconds: 5)),
      throwsFormatException,
    );
  });

  test('A real recording cut five seconds in loses five seconds', () async {
    final bytes = await File('asset/iqama.mp3').readAsBytes();
    final whole = Mp3Cutter.duration(bytes)!;
    expect(whole, greaterThan(const Duration(seconds: 10)));
    final cut = Mp3Cutter.tail(bytes, const Duration(seconds: 5));
    expect(Mp3Cutter.firstFrame(cut), 0);
    final rest = Mp3Cutter.duration(cut)!;
    expect(
      (whole - rest).inMilliseconds,
      closeTo(5000, 60),
      reason: 'whole $whole, rest $rest',
    );
  });

  group('Raising the volume', () {
    test('adds the steps to every granule and channel of every frame', () {
      final quiet = fakeMp3(40, gain: 140);
      // An empty side info, as in an Info frame, opens the recording.
      quiet.fillRange(4, 36, 0);
      final louder = Mp3Cutter.louder(quiet, 11);
      expect(louder.length, quiet.length);
      // The first frame has an empty side info, like an Info frame, and is
      // left alone; every other frame is raised.
      expect(mp3Gains(quiet), hasLength(39 * 4));
      expect(mp3Gains(quiet), everyElement(140));
      expect(mp3Gains(louder), hasLength(39 * 4));
      expect(mp3Gains(louder), everyElement(151));
      expect(louder.sublist(0, mp3FrameBytes), quiet.sublist(0, mp3FrameBytes));
      // Only the side info changes; the sound data is left as it was.
      for (var frame = 1; frame < 40; frame++) {
        final start = frame * mp3FrameBytes;
        expect(
          louder.sublist(start + 36, start + mp3FrameBytes),
          quiet.sublist(start + 36, start + mp3FrameBytes),
        );
        expect(
          louder.sublist(start, start + 4),
          quiet.sublist(start, start + 4),
        );
      }
    });

    test('stops at the largest gain a frame can carry', () {
      final loud = Mp3Cutter.louder(fakeMp3(5, gain: 250), 11);
      expect(mp3Gains(loud), everyElement(255));
    });

    test('keeps the tags and changes nothing at zero steps', () {
      final tagged = fakeMp3(10, id3v2: true, id3v1: true, gain: 120);
      final louder = Mp3Cutter.louder(tagged, 3);
      expect(louder.sublist(0, 20), tagged.sublist(0, 20));
      expect(
        louder.sublist(louder.length - 128),
        tagged.sublist(tagged.length - 128),
      );
      expect(mp3Gains(louder), everyElement(123));
      expect(Mp3Cutter.louder(tagged, 0), tagged);
    });

    test('writes a fresh checksum into frames that carry one', () {
      // The checksum the standard defines, on its usual test text.
      expect(mpegCrc16('123456789'.codeUnits), 0xAEE7);
      final protected = fakeMp3(6, gain: 130, crc: true);
      final louder = Mp3Cutter.louder(protected, 4);
      expect(mp3Gains(louder), everyElement(134));
      for (var frame = 1; frame < 6; frame++) {
        final offset = frame * mp3FrameBytes;
        final sum = mpegCrc16([
          louder[offset + 2],
          louder[offset + 3],
          ...louder.sublist(offset + 6, offset + 38),
        ]);
        expect(louder[offset + 4] << 8 | louder[offset + 5], sum);
      }
    });

    test('refuses what is not an MP3', () {
      expect(() => Mp3Cutter.louder(Uint8List(5000), 2), throwsFormatException);
    });

    test(
      'a real recording keeps its length, frames and playing time',
      () async {
        final bytes = await File('asset/iqama.mp3').readAsBytes();
        final louder = Mp3Cutter.louder(bytes, 5);
        expect(louder.length, bytes.length);
        expect(Mp3Cutter.firstFrame(louder), Mp3Cutter.firstFrame(bytes));
        expect(Mp3Cutter.duration(louder), Mp3Cutter.duration(bytes));
        var changed = 0;
        for (var i = 0; i < bytes.length; i++) {
          if (bytes[i] != louder[i]) changed++;
        }
        // Four gain fields per frame, about 38 frames a second.
        expect(changed, greaterThan(0));
        expect(changed, lessThan(bytes.length ~/ 20));
      },
    );
  });
}

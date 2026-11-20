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
}

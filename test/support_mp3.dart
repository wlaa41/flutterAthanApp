import 'dart:typed_data';

/// Silent MPEG 1 Layer III frames at 128 kb/s and 44.1 kHz: 417 bytes and
/// 1152 samples each. The fifth byte of every frame carries its number.
const mp3FrameBytes = 417;
const mp3FrameSeconds = 1152 / 44100;

Uint8List fakeMp3(int frames, {bool id3v2 = false, bool id3v1 = false}) {
  final builder = BytesBuilder();
  if (id3v2) {
    // "ID3", version 2.3, no flags, a ten-byte body.
    builder.add([0x49, 0x44, 0x33, 3, 0, 0, 0, 0, 0, 10]);
    builder.add(List.filled(10, 0));
  }
  for (var number = 0; number < frames; number++) {
    final frame = Uint8List(mp3FrameBytes);
    frame[0] = 0xFF;
    frame[1] = 0xFB;
    frame[2] = 0x90;
    frame[3] = 0x64;
    frame[4] = number & 0x7F;
    builder.add(frame);
  }
  if (id3v1) {
    builder.add([0x54, 0x41, 0x47]);
    builder.add(List.filled(125, 0x20));
  }
  return builder.toBytes();
}

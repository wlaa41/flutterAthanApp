import 'dart:typed_data';

/// Silent MPEG 1 Layer III frames at 128 kb/s and 44.1 kHz: 417 bytes and
/// 1152 samples each. The fifth byte of every frame carries its number.
const mp3FrameBytes = 417;
const mp3FrameSeconds = 1152 / 44100;

/// The global gain of every granule and channel of every frame, in order.
/// Frames with an empty side info are skipped, as players skip them.
List<int> mp3Gains(Uint8List bytes) {
  final gains = <int>[];
  var offset = 0;
  while (offset + 4 <= bytes.length) {
    if (bytes[offset] != 0xFF || bytes[offset + 1] & 0xE0 != 0xE0) {
      offset++;
      continue;
    }
    final crc = bytes[offset + 1] & 1 == 0;
    final side = offset + 4 + (crc ? 2 : 0);
    if (bytes.sublist(side, side + 32).any((byte) => byte != 0)) {
      for (final at in const [41, 100, 159, 218]) {
        gains.add(readBits(bytes, side * 8 + at, 8));
      }
    }
    offset += mp3FrameBytes;
  }
  return gains;
}

int readBits(Uint8List bytes, int at, int count) {
  var value = 0;
  for (var i = 0; i < count; i++) {
    final bit = at + i;
    value = value << 1 | (bytes[bit >> 3] >> (7 - (bit & 7))) & 1;
  }
  return value;
}

void writeBits(Uint8List bytes, int at, int count, int value) {
  for (var i = 0; i < count; i++) {
    final bit = at + i;
    final mask = 1 << (7 - (bit & 7));
    if ((value >> (count - 1 - i)) & 1 == 1) {
      bytes[bit >> 3] |= mask;
    } else {
      bytes[bit >> 3] &= ~mask & 0xFF;
    }
  }
}

/// Joint-stereo MPEG 1 frames as [fakeMp3] makes them, each granule and
/// channel at the global gain [gain]. With [crc] each frame carries a
/// checksum, and the bitrate is 128 kb/s either way.
Uint8List fakeMp3(
  int frames, {
  bool id3v2 = false,
  bool id3v1 = false,
  int? gain,
  bool crc = false,
}) {
  final bytes = _fakeMp3(frames, id3v2: id3v2, id3v1: id3v1);
  if (gain == null && !crc) return bytes;
  final first = id3v2 ? 20 : 0;
  for (var frame = 0; frame < frames; frame++) {
    final offset = first + frame * mp3FrameBytes;
    if (crc) {
      bytes[offset + 1] = 0xFA;
      // The checksum takes two bytes; the side info moves down by two.
      bytes[offset + 6] = bytes[offset + 4];
      bytes[offset + 4] = 0;
    }
    final side = offset + 4 + (crc ? 2 : 0);
    if (gain != null) {
      for (final at in const [41, 100, 159, 218]) {
        writeBits(bytes, side * 8 + at, 8, gain);
      }
    }
    if (crc) {
      final sum = mpegCrc16([
        bytes[offset + 2],
        bytes[offset + 3],
        ...bytes.sublist(side, side + 32),
      ]);
      bytes[offset + 4] = sum >> 8;
      bytes[offset + 5] = sum & 0xFF;
    }
  }
  return bytes;
}

/// CRC-16 as MPEG audio uses it: polynomial 0x8005, start 0xFFFF.
int mpegCrc16(List<int> data) {
  var crc = 0xFFFF;
  for (final byte in data) {
    for (var i = 7; i >= 0; i--) {
      final top = (crc >> 15) & 1;
      crc = (crc << 1) & 0xFFFF;
      if (top ^ ((byte >> i) & 1) == 1) crc ^= 0x8005;
    }
  }
  return crc;
}

Uint8List _fakeMp3(int frames, {bool id3v2 = false, bool id3v1 = false}) {
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

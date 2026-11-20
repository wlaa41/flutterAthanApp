import 'dart:typed_data';

/// Cuts an MP3 at a frame boundary without decoding it. An MP3 is a run of
/// self-describing frames, so dropping whole frames from the front leaves a
/// file every player accepts, and the sound that remains is untouched.
class Mp3Cutter {
  static const _mpeg1Kbps = [
    0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, //
  ];
  static const _mpeg2Kbps = [
    0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, //
  ];
  static const _sampleRates = {
    3: [44100, 48000, 32000], // MPEG 1
    2: [22050, 24000, 16000], // MPEG 2
    0: [11025, 12000, 8000], // MPEG 2.5
  };

  /// The byte length and duration of the Layer III frame that starts at
  /// [offset], or null when no frame starts there.
  static ({int length, double seconds})? _frame(Uint8List bytes, int offset) {
    if (offset + 4 > bytes.length ||
        bytes[offset] != 0xFF ||
        (bytes[offset + 1] & 0xE0) != 0xE0) {
      return null;
    }
    final version = (bytes[offset + 1] >> 3) & 3;
    final layer = (bytes[offset + 1] >> 1) & 3;
    final bitrateIndex = (bytes[offset + 2] >> 4) & 15;
    final rateIndex = (bytes[offset + 2] >> 2) & 3;
    final padding = (bytes[offset + 2] >> 1) & 1;
    if (version == 1 ||
        layer != 1 ||
        bitrateIndex == 0 ||
        bitrateIndex == 15 ||
        rateIndex == 3) {
      return null;
    }
    final mpeg1 = version == 3;
    final bitrate = (mpeg1 ? _mpeg1Kbps : _mpeg2Kbps)[bitrateIndex] * 1000;
    final rate = _sampleRates[version]![rateIndex];
    return (
      length: (mpeg1 ? 144 : 72) * bitrate ~/ rate + padding,
      seconds: (mpeg1 ? 1152 : 576) / rate,
    );
  }

  /// Where the first frame starts, after any ID3v2 tag. Two frames in a row
  /// must line up, so stray bytes that look like a header are not mistaken
  /// for one.
  static int? firstFrame(Uint8List bytes) {
    var offset = 0;
    if (bytes.length > 10 &&
        bytes[0] == 0x49 &&
        bytes[1] == 0x44 &&
        bytes[2] == 0x33) {
      offset =
          10 +
          ((bytes[6] & 0x7F) << 21 |
              (bytes[7] & 0x7F) << 14 |
              (bytes[8] & 0x7F) << 7 |
              (bytes[9] & 0x7F));
    }
    for (; offset + 4 < bytes.length; offset++) {
      final frame = _frame(bytes, offset);
      if (frame != null && _frame(bytes, offset + frame.length) != null) {
        return offset;
      }
    }
    return null;
  }

  /// The playing time of the frames in [bytes].
  static Duration? duration(Uint8List bytes) {
    var offset = firstFrame(bytes);
    if (offset == null) return null;
    var seconds = 0.0;
    for (var frame = _frame(bytes, offset); frame != null;) {
      seconds += frame.seconds;
      offset = offset! + frame.length;
      frame = _frame(bytes, offset);
    }
    return Duration(microseconds: (seconds * 1e6).round());
  }

  /// The recording from [from] to its end. Throws a [FormatException] when
  /// [bytes] is not an MP3 or is shorter than [from].
  static Uint8List tail(Uint8List bytes, Duration from) {
    var offset = firstFrame(bytes);
    if (offset == null) throw const FormatException('Not an MP3 recording');
    final target = from.inMicroseconds / 1e6;
    var seconds = 0.0;
    var frame = _frame(bytes, offset);
    while (frame != null && seconds < target) {
      seconds += frame.seconds;
      offset = offset! + frame.length;
      frame = _frame(bytes, offset);
    }
    if (frame == null) {
      throw const FormatException('The recording ends before the cut');
    }
    // A trailing ID3v1 tag is 128 bytes of text, not sound.
    var end = bytes.length;
    if (end - offset! > 128 &&
        bytes[end - 128] == 0x54 &&
        bytes[end - 127] == 0x41 &&
        bytes[end - 126] == 0x47) {
      end -= 128;
    }
    return Uint8List.sublistView(bytes, offset, end);
  }

  /// Raises the volume of [bytes] by [steps] of 1.5 dB without decoding, the
  /// way mp3gain does. Every Layer III frame carries a global gain for each
  /// of its granules and channels; adding to it scales the decoded sound
  /// exactly, so nothing is re-encoded and nothing else changes. Frames with
  /// an empty side info (the Xing or Info frame at the start) are left alone.
  /// Throws a [FormatException] when [bytes] is not an MP3.
  static Uint8List louder(Uint8List bytes, int steps) {
    final first = firstFrame(bytes);
    if (first == null) throw const FormatException('Not an MP3 recording');
    final out = Uint8List.fromList(bytes);
    if (steps == 0) return out;
    var offset = first;
    for (var frame = _frame(out, offset); frame != null;) {
      if (offset + frame.length > out.length) break;
      _raiseGain(out, offset, steps);
      offset += frame.length;
      frame = _frame(out, offset);
    }
    return out;
  }

  static void _raiseGain(Uint8List bytes, int offset, int steps) {
    final mpeg1 = ((bytes[offset + 1] >> 3) & 3) == 3;
    final crc = (bytes[offset + 1] & 1) == 0;
    final channels = ((bytes[offset + 3] >> 6) & 3) == 3 ? 1 : 2;
    final side = offset + 4 + (crc ? 2 : 0);
    final sideLength = mpeg1
        ? (channels == 1 ? 17 : 32)
        : (channels == 1 ? 9 : 17);
    if (side + sideLength > bytes.length) return;
    var empty = true;
    for (var i = side; i < side + sideLength; i++) {
      if (bytes[i] != 0) {
        empty = false;
        break;
      }
    }
    if (empty) return;
    // main_data_begin, private bits and (MPEG 1 only) scfsi come first; then
    // one block per granule and channel, whose global gain follows its
    // part2_3_length (12 bits) and big_values (9 bits).
    final start = mpeg1
        ? 9 + (channels == 1 ? 5 : 3) + 4 * channels
        : 8 + (channels == 1 ? 1 : 2);
    final block = mpeg1 ? 59 : 63;
    final granules = mpeg1 ? 2 : 1;
    for (var granule = 0; granule < granules; granule++) {
      for (var channel = 0; channel < channels; channel++) {
        final at =
            side * 8 + start + (granule * channels + channel) * block + 21;
        final gain = _bits(bytes, at, 8);
        _setBits(bytes, at, 8, gain + steps > 255 ? 255 : gain + steps);
      }
    }
    if (crc) {
      // The checksum covers the last two header bytes and the side info.
      final sum = _crc16([
        bytes[offset + 2],
        bytes[offset + 3],
        ...bytes.sublist(side, side + sideLength),
      ]);
      bytes[offset + 4] = sum >> 8;
      bytes[offset + 5] = sum & 0xFF;
    }
  }

  static int _bits(Uint8List bytes, int at, int count) {
    var value = 0;
    for (var i = 0; i < count; i++) {
      final bit = at + i;
      value = value << 1 | (bytes[bit >> 3] >> (7 - (bit & 7))) & 1;
    }
    return value;
  }

  static void _setBits(Uint8List bytes, int at, int count, int value) {
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

  /// CRC-16 with the polynomial 0x8005 and a start value of 0xFFFF, as the
  /// MPEG audio standard defines it.
  static int _crc16(List<int> data) {
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
}

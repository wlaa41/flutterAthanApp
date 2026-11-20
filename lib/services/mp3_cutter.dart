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
}

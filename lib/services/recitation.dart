import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Letters the way the listening model writes them: the bare Uthmani letters,
/// with one alif, hamza seats as their letters and no marks.
String recitationLetters(String text) {
  final out = StringBuffer();
  for (final rune in text.runes) {
    // Marks, the hizb and sajdah signs, tatweel and the small waw and yeh.
    if ((rune >= 0x0610 && rune <= 0x061A) ||
        (rune >= 0x064B && rune <= 0x065F) ||
        rune == 0x0670 ||
        (rune >= 0x06D6 && rune <= 0x06ED) ||
        (rune >= 0x08D3 && rune <= 0x08FF) ||
        rune == 0x0640 ||
        rune == 0x00A0) {
      continue;
    }
    switch (rune) {
      case 0x0671 || 0x0623 || 0x0625 || 0x0622:
        out.write('ا');
      case 0x0624:
        out.write('و');
      case 0x0626 || 0x0649:
        out.write('ي');
      case 0x0629:
        out.write('ه');
      default:
        out.writeCharCode(rune);
    }
  }
  return out.toString();
}

/// Which words of an ayah were heard in a recitation.
class RecitationMatch {
  const RecitationMatch(this.heard);

  /// One entry for each word of the ayah.
  final List<bool> heard;

  int get total => heard.length;
  int get count => heard.where((word) => word).length;
  bool get complete => count == total;
}

/// Lines the words of an ayah up with what the model heard.
///
/// A word counts as heard when its letters match to within a third. The
/// model may join two words or split one, so one word may stand against two
/// when their letters all but agree. What was said before or after the ayah
/// is passed over.
RecitationMatch matchRecitation(List<String> ayahWords, String heardText) {
  final want = [
    for (final word in ayahWords) recitationLetters(word),
  ].where((word) => word.isNotEmpty).toList();
  final got = heardText
      .replaceAll('▁', ' ')
      .split(RegExp(r'\s+'))
      .map(recitationLetters)
      .where((word) => word.isNotEmpty)
      .toList();
  final n = want.length;
  final m = got.length;
  if (n == 0) return const RecitationMatch([]);
  const missed = 1.0;
  const extra = 1.0;
  const joined = 0.1;
  const limit = 0.34;
  const joinedLimit = 0.15;
  final cost = List.generate(n + 1, (_) => List.filled(m + 1, 0.0));
  final step = List.generate(n + 1, (_) => List.filled(m + 1, 0));
  for (var i = 1; i <= n; i++) {
    cost[i][0] = i * missed;
    step[i][0] = 1;
  }
  for (var j = 1; j <= m; j++) {
    cost[0][j] = j * extra;
    step[0][j] = 2;
  }
  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      var best = cost[i - 1][j] + missed;
      var how = 1;
      void consider(double value, int move) {
        if (value < best) {
          best = value;
          how = move;
        }
      }

      consider(cost[i][j - 1] + extra, 2);
      consider(cost[i - 1][j - 1] + 2 * _apart(want[i - 1], got[j - 1]), 3);
      // Two words against one only when the letters all but agree, or a
      // short word would hide inside its neighbour.
      if (i >= 2) {
        final apart = _apart(want[i - 2] + want[i - 1], got[j - 1]);
        if (apart <= joinedLimit) {
          consider(cost[i - 2][j - 1] + 2 * apart + joined, 4);
        }
      }
      if (j >= 2) {
        final apart = _apart(want[i - 1], got[j - 2] + got[j - 1]);
        if (apart <= joinedLimit) {
          consider(cost[i - 1][j - 2] + 2 * apart + joined, 5);
        }
      }
      cost[i][j] = best;
      step[i][j] = how;
    }
  }
  final heard = List.filled(n, false);
  var i = n;
  var j = m;
  while (i > 0 || j > 0) {
    switch (step[i][j]) {
      case 1:
        i--;
      case 2:
        j--;
      case 3:
        heard[i - 1] = _apart(want[i - 1], got[j - 1]) <= limit;
        i--;
        j--;
      case 4:
        heard[i - 1] = true;
        heard[i - 2] = true;
        i -= 2;
        j--;
      case 5:
        heard[i - 1] = true;
        i--;
        j -= 2;
      default:
        i = 0;
        j = 0;
    }
  }
  return RecitationMatch(heard);
}

/// How far apart two words are: letters to change, over the longer length.
double _apart(String a, String b) {
  if (a == b) return 0;
  final x = a.runes.toList();
  final y = b.runes.toList();
  if (x.isEmpty || y.isEmpty) return 1;
  var previous = List.generate(y.length + 1, (index) => index);
  for (var i = 1; i <= x.length; i++) {
    final current = List.filled(y.length + 1, 0);
    current[0] = i;
    for (var j = 1; j <= y.length; j++) {
      current[j] = min(
        min(previous[j] + 1, current[j - 1] + 1),
        previous[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1),
      );
    }
    previous = current;
  }
  return previous[y.length] / max(x.length, y.length);
}

/// A file of the listening model, as its publisher serves it.
class RecitationFile {
  const RecitationFile(this.name, this.bytes, this.sha256);

  final String name;
  final int bytes;
  final String sha256;
}

/// The model that listens: quran-asr-tiny by Abdou (MIT licence), a small
/// recogniser trained on Quran recitation. It is fetched once, checked
/// against the recorded checksum and kept on the phone; after that the
/// recitation never leaves the phone.
class RecitationModel {
  RecitationModel({http.Client? client, Future<Directory> Function()? home})
    : _client = client,
      _home = home ?? getApplicationSupportDirectory;

  static final RecitationModel instance = RecitationModel();

  /// The published revision the checksums below belong to.
  static const revision = 'a291b33fd5a31cc4f212363ee1ba2d56d9710b49';
  static const source =
      'https://huggingface.co/Abdou/quran-asr-tiny/resolve/$revision/';
  static const files = [
    RecitationFile(
      'model.int8.onnx',
      18850806,
      '58de6db034bb4f6516b3bc1c68e7a0ac4e77abffe603a550ee87b39dcd0c7ac6',
    ),
    RecitationFile(
      'tokens.txt',
      180,
      '75b53814499cee84a07c7b7a318524d30bcaf84273c0f8b28a04176023e8c74f',
    ),
  ];
  static int get bytes => files.fold(0, (sum, file) => sum + file.bytes);

  final http.Client? _client;
  final Future<Directory> Function() _home;

  Future<Directory> directory() async =>
      Directory('${(await _home()).path}/recitation/$revision');

  /// Whether every file is on the phone at its full size.
  Future<bool> ready() async {
    final folder = await directory();
    for (final file in files) {
      final kept = File('${folder.path}/${file.name}');
      if (!await kept.exists() || await kept.length() != file.bytes) {
        return false;
      }
    }
    return true;
  }

  /// Fetches what is missing. Reports the share fetched, 0 to 1. A file that
  /// does not match its checksum is thrown away and the fetch fails.
  Future<void> fetch({void Function(double share)? onProgress}) async {
    final folder = await directory();
    await folder.create(recursive: true);
    final client = _client ?? http.Client();
    var fetched = 0;
    try {
      for (final file in files) {
        final kept = File('${folder.path}/${file.name}');
        if (await kept.exists() && await kept.length() == file.bytes) {
          fetched += file.bytes;
          onProgress?.call(fetched / bytes);
          continue;
        }
        final part = File('${kept.path}.part');
        final response = await client
            .send(http.Request('GET', Uri.parse('$source${file.name}')))
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) {
          throw HttpException('The listener answered ${response.statusCode}');
        }
        final sink = part.openWrite();
        final digest = AccumulatorSink<Digest>();
        final hash = sha256.startChunkedConversion(digest);
        var got = 0;
        try {
          await for (final chunk in response.stream.timeout(
            const Duration(seconds: 30),
          )) {
            got += chunk.length;
            if (got > file.bytes) break;
            sink.add(chunk);
            hash.add(chunk);
            onProgress?.call((fetched + got) / bytes);
          }
        } finally {
          await sink.close();
        }
        hash.close();
        if (got != file.bytes ||
            digest.events.single.toString() != file.sha256) {
          await part.delete();
          throw const FormatException('The listener did not arrive whole.');
        }
        await part.rename(kept.path);
        fetched += file.bytes;
      }
    } finally {
      if (_client == null) client.close();
    }
  }
}

/// Collects what a chunked conversion puts out.
class AccumulatorSink<T> implements Sink<T> {
  final events = <T>[];

  @override
  void add(T event) => events.add(event);

  @override
  void close() {}
}

/// Sound as numbers between -1 and 1.
class RecitationSound {
  const RecitationSound(this.samples, this.sampleRate);

  final Float32List samples;
  final int sampleRate;

  double get seconds => sampleRate == 0 ? 0 : samples.length / sampleRate;

  /// Reads a WAV file, taking the first channel. Phones write 16-bit whole
  /// numbers; the other plain forms a recorder may choose are read as well.
  static RecitationSound? fromWav(Uint8List bytes) {
    if (bytes.length < 44) return null;
    final data = ByteData.sublistView(bytes);
    String tag(int at) => String.fromCharCodes(bytes.sublist(at, at + 4));
    if (tag(0) != 'RIFF' || tag(8) != 'WAVE') return null;
    var at = 12;
    var format = 1; // 1: whole numbers. 3: floating point.
    var channels = 1;
    var rate = 16000;
    var bits = 16;
    while (at + 8 <= bytes.length) {
      final name = tag(at);
      final size = data.getUint32(at + 4, Endian.little);
      final body = at + 8;
      if (name == 'fmt ' && body + 16 <= bytes.length) {
        format = data.getUint16(body, Endian.little);
        channels = max(1, data.getUint16(body + 2, Endian.little));
        rate = data.getUint32(body + 4, Endian.little);
        bits = data.getUint16(body + 14, Endian.little);
        // The long form of the header keeps the real format further in.
        if (format == 0xFFFE && size >= 26 && body + 26 <= bytes.length) {
          format = data.getUint16(body + 24, Endian.little);
        }
      } else if (name == 'data') {
        final double Function(int at)? read = switch ((format, bits)) {
          (1, 8) => (at) => (data.getUint8(at) - 128) / 128,
          (1, 16) => (at) => data.getInt16(at, Endian.little) / 32768,
          (1, 24) =>
            (at) =>
                ((data.getInt8(at + 2) << 16) |
                    (data.getUint8(at + 1) << 8) |
                    data.getUint8(at)) /
                8388608,
          (1, 32) => (at) => data.getInt32(at, Endian.little) / 2147483648,
          (3, 32) => (at) => data.getFloat32(at, Endian.little),
          (3, 64) => (at) => data.getFloat64(at, Endian.little),
          _ => null,
        };
        if (read == null || rate <= 0) return null;
        // A recorder that was stopped may leave the size unwritten.
        final end = size == 0 || body + size > bytes.length
            ? bytes.length
            : body + size;
        final step = bits ~/ 8 * channels;
        final frames = (end - body) ~/ step;
        final samples = Float32List(frames);
        for (var i = 0; i < frames; i++) {
          samples[i] = read(body + i * step);
        }
        return RecitationSound(samples, rate);
      }
      at = body + size + (size.isOdd ? 1 : 0);
    }
    return null;
  }
}

/// Runs the model over a recording, away from the screen's thread.
class RecitationEngine {
  /// The letters heard, words apart by spaces.
  static Future<String> hear(
    RecitationSound sound,
    Directory model, {
    String? libraryPath,
  }) {
    final samples = sound.samples;
    final rate = sound.sampleRate;
    final folder = model.path;
    return Isolate.run(() => _hear(samples, rate, folder, libraryPath));
  }

  static String _hear(
    Float32List samples,
    int rate,
    String folder,
    String? libraryPath,
  ) {
    sherpa.initBindings(libraryPath);
    final recognizer = sherpa.OfflineRecognizer(
      sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          zipformerCtc: sherpa.OfflineZipformerCtcModelConfig(
            model: '$folder/${RecitationModel.files[0].name}',
          ),
          tokens: '$folder/${RecitationModel.files[1].name}',
          numThreads: 2,
          debug: false,
        ),
      ),
    );
    final stream = recognizer.createStream();
    try {
      stream.acceptWaveform(samples: samples, sampleRate: rate);
      recognizer.decode(stream);
      return recognizer
          .getResult(stream)
          .text
          .replaceAll('▁', ' ')
          .trim()
          .replaceAll(RegExp(r'\s+'), ' ');
    } finally {
      stream.free();
      recognizer.free();
    }
  }
}

/// Why listening could not start or finish.
enum RecitationProblem { noMicrophone, noModel, tooShort, failed }

class RecitationFailure implements Exception {
  const RecitationFailure(this.problem);

  final RecitationProblem problem;
}

/// Records a recitation with the phone's microphone and hears it.
class RecitationListener {
  RecitationListener({RecitationModel? model})
    : _model = model ?? RecitationModel.instance;

  /// A recitation is stopped by itself after this long.
  static const longest = Duration(seconds: 120);

  final RecitationModel _model;

  // Made on first use, so a screen that never listens asks the phone nothing.
  late final AudioRecorder _recorder = AudioRecorder();
  bool _used = false;
  String? _path;

  /// Starts recording. Asks for the microphone the first time.
  Future<void> start() async {
    if (!await _model.ready()) {
      throw const RecitationFailure(RecitationProblem.noModel);
    }
    _used = true;
    if (!await _recorder.hasPermission()) {
      throw const RecitationFailure(RecitationProblem.noMicrophone);
    }
    final folder = await getTemporaryDirectory();
    final path = '${folder.path}/recitation.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: true,
        noiseSuppress: true,
      ),
      path: path,
    );
    _path = path;
  }

  /// How loud the reciter is right now, 0 to 1, for the moving ring.
  Future<double> level() async {
    try {
      final amplitude = await _recorder.getAmplitude();
      return ((amplitude.current + 50) / 50).clamp(0.0, 1.0);
    } catch (_) {
      return 0;
    }
  }

  /// Stops recording and returns the letters heard.
  Future<String> finish() async {
    final path = await _recorder.stop() ?? _path;
    _path = null;
    if (path == null) throw const RecitationFailure(RecitationProblem.failed);
    final file = File(path);
    try {
      final sound = RecitationSound.fromWav(await file.readAsBytes());
      if (sound == null) {
        throw const RecitationFailure(RecitationProblem.failed);
      }
      if (sound.seconds < 0.6) {
        throw const RecitationFailure(RecitationProblem.tooShort);
      }
      return await RecitationEngine.hear(sound, await _model.directory());
    } on RecitationFailure {
      rethrow;
    } catch (_) {
      throw const RecitationFailure(RecitationProblem.failed);
    } finally {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  Future<void> cancel() async {
    _path = null;
    if (!_used) return;
    try {
      await _recorder.cancel();
    } catch (_) {}
  }

  Future<void> dispose() async {
    if (!_used) return;
    try {
      await _recorder.dispose();
    } catch (_) {}
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SoundKind { athan, iqama, tone, custom }

class SoundOption {
  final String id;
  final String name;
  final String description;
  final SoundKind kind;
  final String? assetPath;
  final String? filePath;
  final String? androidResource;
  final String? iosSound;

  const SoundOption({
    required this.id,
    required this.name,
    required this.description,
    required this.kind,
    this.assetPath,
    this.filePath,
    this.androidResource,
    this.iosSound,
  });

  bool get isSilent => id == 'silent';
  bool get isVibrationOnly => id == 'vibrate';
  bool get canPreview => assetPath != null || filePath != null;

  /// The bundled tones come in five loudness levels; recordings do not.
  bool get hasPowerLevels => kind == SoundKind.tone && assetPath != null;

  /// File stem of this tone at [power] (1 soft to 5 maximum; 4 is the default).
  static String toneFile(String id, int power) {
    final level = power.clamp(1, 5);
    return level == 4 ? id : '${id}_p$level';
  }

  /// This tone at the chosen loudness. Other sounds are returned unchanged.
  SoundOption atPower(int power) {
    if (!hasPowerLevels) return this;
    final file = toneFile(id, power);
    return SoundOption(
      id: id,
      name: name,
      description: description,
      kind: kind,
      assetPath: 'asset/$file.wav',
      androidResource: file,
      iosSound: '$file.wav',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'filePath': filePath,
    'fileName': filePath?.replaceAll('\\', '/').split('/').last,
    'iosSound': iosSound,
  };
}

class SoundCatalog {
  static const builtIns = <SoundOption>[
    SoundOption(
      id: 'smooth',
      name: 'Classic Athan',
      description: 'Original app recording',
      kind: SoundKind.athan,
      assetPath: 'asset/smooth.mp3',
      androidResource: 'smooth',
      iosSound: 'chime.wav',
    ),
    SoundOption(
      id: 'beautiful_adhan',
      name: 'Beautiful Athan',
      description: 'Adam-synagda · available offline',
      kind: SoundKind.athan,
      assetPath: 'asset/beautiful_adhan.mp3',
      androidResource: 'beautiful_adhan',
      iosSound: 'beautiful_adhan_short.wav',
    ),
    SoundOption(
      id: 'mishary_alafasy',
      name: 'Mishary Rashid Alafasy',
      description: 'Kuwait · available offline',
      kind: SoundKind.athan,
      assetPath: 'asset/mishary_alafasy.mp3',
      androidResource: 'mishary_alafasy',
      iosSound: 'mishary_alafasy_short.wav',
    ),
    SoundOption(
      id: 'makkah_ali_mulla',
      name: 'Makkah · Ali Mulla',
      description: 'Ali ibn Ahmad Mulla · available offline',
      kind: SoundKind.athan,
      assetPath: 'asset/makkah_ali_mulla.mp3',
      androidResource: 'makkah_ali_mulla',
      iosSound: 'makkah_ali_mulla_short.wav',
    ),
    SoundOption(
      id: 'madinah',
      name: 'Madinah · Prophet’s Mosque',
      description: 'Mosque recording by ejaz215 · available offline',
      kind: SoundKind.athan,
      assetPath: 'asset/madinah.mp3',
      androidResource: 'madinah',
      iosSound: 'madinah_short.wav',
    ),
    SoundOption(
      id: 'abdul_basit',
      name: 'Abdul Basit Abdus Samad',
      description: 'Egypt · available offline',
      kind: SoundKind.athan,
      assetPath: 'asset/abdul_basit.mp3',
      androidResource: 'abdul_basit',
      iosSound: 'abdul_basit_short.wav',
    ),
    SoundOption(
      id: 'minshawi',
      name: 'Muhammad Siddiq Al-Minshawi',
      description: 'Egypt · available offline',
      kind: SoundKind.athan,
      assetPath: 'asset/minshawi.mp3',
      androidResource: 'minshawi',
      iosSound: 'minshawi_short.wav',
    ),
    SoundOption(
      id: 'nasser_al_qatami',
      name: 'Nasser Al Qatami',
      description: 'Saudi Arabia · available offline',
      kind: SoundKind.athan,
      assetPath: 'asset/nasser_al_qatami.mp3',
      androidResource: 'nasser_al_qatami',
      iosSound: 'nasser_al_qatami_short.wav',
    ),
    SoundOption(
      id: 'iqama',
      name: 'Iqama recitation',
      description: 'Aishatu98 · available offline',
      kind: SoundKind.iqama,
      assetPath: 'asset/iqama.mp3',
      androidResource: 'iqama',
      iosSound: 'iqama_short.wav',
    ),
    SoundOption(
      id: 'beep',
      name: 'Beep',
      description: 'One clear beep',
      kind: SoundKind.tone,
      assetPath: 'asset/beep.wav',
      androidResource: 'beep',
      iosSound: 'beep.wav',
    ),
    SoundOption(
      id: 'double_beep',
      name: 'Double beep',
      description: 'Two short beeps',
      kind: SoundKind.tone,
      assetPath: 'asset/double_beep.wav',
      androidResource: 'double_beep',
      iosSound: 'double_beep.wav',
    ),
    SoundOption(
      id: 'chime',
      name: 'Gentle chime',
      description: 'A soft, fading chime',
      kind: SoundKind.tone,
      assetPath: 'asset/chime.wav',
      androidResource: 'chime',
      iosSound: 'chime.wav',
    ),
    SoundOption(
      id: 'strong_beep',
      name: 'Strong beep',
      description: 'Three sharp beeps that carry in a noisy room',
      kind: SoundKind.tone,
      assetPath: 'asset/strong_beep.wav',
      androidResource: 'strong_beep',
      iosSound: 'strong_beep.wav',
    ),
    SoundOption(
      id: 'vibrate',
      name: 'Vibrate only',
      description: 'No sound',
      kind: SoundKind.tone,
    ),
    SoundOption(
      id: 'silent',
      name: 'Silent notification',
      description: 'No sound or vibration',
      kind: SoundKind.tone,
    ),
  ];

  static SoundOption byId(String id) => builtIns.firstWhere(
    (sound) => sound.id == id,
    orElse: () => builtIns.first,
  );
}

/// The system picker grants one file; no storage permission or background work.
class SoundLibrary {
  static final instance = SoundLibrary._();
  SoundLibrary._();
  static const maxBytes = 20 * 1024 * 1024;
  static const _storageKey = 'custom_alert_sounds_v1';
  static const _iosPackKey = 'ios_sound_pack';
  static const _iosPack = 2;
  bool _importing = false;

  /// iOS reads local notification sounds from Library/Sounds, not Flutter assets.
  /// Copy once; later launches perform only cheap file-existence checks.
  Future<void> prepareNotificationSounds() async {
    if (!Platform.isIOS) return;
    final library = await getLibraryDirectory();
    final directory = Directory('${library.path}/Sounds');
    await directory.create(recursive: true);
    final names = {
      for (final sound in SoundCatalog.builtIns) ...[
        if (sound.iosSound != null) sound.iosSound!,
        if (sound.hasPowerLevels)
          for (var power = 1; power <= 5; power++)
            '${SoundOption.toneFile(sound.id, power)}.wav',
      ],
    };
    // The tones were redrawn louder in pack 2: replace copies made by older versions.
    final prefs = await SharedPreferences.getInstance();
    final refresh = (prefs.getInt(_iosPackKey) ?? 1) < _iosPack;
    for (final name in names) {
      final target = File('${directory.path}/$name');
      if (!refresh && await target.exists()) continue;
      final data = await rootBundle.load('asset/$name');
      final temporary = File('${target.path}.tmp');
      await temporary.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      await temporary.rename(target.path);
    }
    if (refresh) await prefs.setInt(_iosPackKey, _iosPack);
  }

  Future<List<SoundOption>> loadSounds() async {
    final prefs = await SharedPreferences.getInstance();
    final sounds = <SoundOption>[...SoundCatalog.builtIns];
    for (final encoded in prefs.getStringList(_storageKey) ?? <String>[]) {
      try {
        final item = jsonDecode(encoded) as Map<String, dynamic>;
        final fileName = item['fileName'] as String?;
        // iOS may change the application's container path after an update or
        // restore; resolve saved filenames against the current container.
        final path =
            fileName != null &&
                RegExp(r'^custom_\d+\.(mp3|m4a|wav)$').hasMatch(fileName)
            ? '${(await getApplicationSupportDirectory()).path}/alert_sounds/$fileName'
            : item['filePath'] as String;
        if (!await File(path).exists()) continue;
        sounds.add(
          SoundOption(
            id: item['id'] as String,
            name: item['name'] as String,
            description: item['description'] as String? ?? 'Your audio file',
            kind: SoundKind.custom,
            filePath: path,
            iosSound: item['iosSound'] as String?,
          ),
        );
      } on Object {
        // A damaged import must not hide the built-in library.
      }
    }
    return sounds;
  }

  Future<SoundOption> resolve(String id) async =>
      (await loadSounds()).firstWhere(
        (sound) => sound.id == id,
        orElse: () => SoundCatalog.byId('beep'),
      );

  Future<SoundOption?> importSound() async {
    if (_importing) return null;
    _importing = true;
    File? copied;
    File? iosCopy;
    var stage = 'file selection';
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav'],
      );
      if (picked == null) return null;
      final extension = picked.name.split('.').last.toLowerCase();
      if (!['mp3', 'm4a', 'wav'].contains(extension)) {
        throw const FormatException('Choose an MP3, M4A or WAV file.');
      }
      stage = 'private storage';
      final directory = Directory(
        '${(await getApplicationSupportDirectory()).path}/alert_sounds',
      );
      await directory.create(recursive: true);
      final id = 'custom_${DateTime.now().microsecondsSinceEpoch}';
      copied = File('${directory.path}/$id.$extension');
      // Streams also work with cloud-backed/content URI files that have no
      // filesystem path or known length. Enforce the cap on actual bytes read.
      stage = 'file copy';
      await copyBoundedAudio(picked.readAsByteStream(), copied);

      // Validate with the platform decoder, not just the filename extension.
      stage = 'audio validation';
      final validator = AudioPlayer();
      Duration? duration;
      try {
        duration = await validator
            .setFilePath(copied.path)
            .timeout(const Duration(seconds: 15));
      } finally {
        await validator.dispose();
      }
      if (duration == null ||
          duration <= Duration.zero ||
          duration > const Duration(minutes: 10)) {
        throw const FormatException(
          'Choose an audio recording up to 10 minutes long.',
        );
      }

      stage = 'sound registration';
      String? iosSound;
      if (Platform.isIOS &&
          extension == 'wav' &&
          duration < const Duration(seconds: 30) &&
          isPcmWave(await copied.readAsBytes())) {
        final library = await getLibraryDirectory();
        final soundDirectory = Directory('${library.path}/Sounds');
        await soundDirectory.create(recursive: true);
        iosSound = '$id.wav';
        iosCopy = await copied.copy('${soundDirectory.path}/$iosSound');
      }
      final sound = SoundOption(
        id: id,
        name: picked.name,
        description: 'Your audio · saved on this phone',
        kind: SoundKind.custom,
        filePath: copied.path,
        iosSound: iosSound,
      );
      final prefs = await SharedPreferences.getInstance();
      final imported = prefs.getStringList(_storageKey) ?? <String>[];
      if (!await prefs.setStringList(_storageKey, [
        ...imported,
        jsonEncode(sound.toJson()),
      ])) {
        throw const FileSystemException(
          'Could not save this sound. Try again.',
        );
      }
      return sound;
    } catch (error, stackTrace) {
      debugPrint('Audio import failed during $stage: $error\n$stackTrace');
      if (copied != null && await copied.exists()) await copied.delete();
      if (iosCopy != null && await iosCopy.exists()) await iosCopy.delete();
      rethrow;
    } finally {
      _importing = false;
    }
  }

  /// Copies a picker stream with a hard byte cap and backpressure. Partial files
  /// are removed on empty data, oversized input, I/O failure or stalled reads.
  static Future<void> copyBoundedAudio(
    Stream<List<int>> source,
    File target, {
    int byteLimit = maxBytes,
  }) async {
    var bytes = 0;
    try {
      final output = await target.open(mode: FileMode.write);
      try {
        await for (final chunk in source.timeout(const Duration(seconds: 30))) {
          bytes += chunk.length;
          if (bytes > byteLimit) {
            throw const FormatException('Choose an audio file up to 20 MB.');
          }
          await output.writeFrom(chunk);
        }
        await output.flush();
      } finally {
        await output.close();
      }
      if (bytes == 0) {
        throw const FormatException(
          'This audio file is empty. Choose another file.',
        );
      }
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    }
  }

  /// Apple notification sounds accept PCM WAV, not arbitrary WAV codecs.
  static bool isPcmWave(Uint8List bytes) {
    if (bytes.length < 12 ||
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) != 'RIFF' ||
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) != 'WAVE')
      return false;
    final data = ByteData.sublistView(bytes);
    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final chunkLength = data.getUint32(offset + 4, Endian.little);
      if (offset + 8 + chunkLength > bytes.length) return false;
      final chunkId = ascii.decode(
        bytes.sublist(offset, offset + 4),
        allowInvalid: true,
      );
      if (chunkId == 'fmt ') {
        if (chunkLength < 16) return false;
        final format = data.getUint16(offset + 8, Endian.little);
        final channels = data.getUint16(offset + 10, Endian.little);
        final bits = data.getUint16(offset + 22, Endian.little);
        return format == 1 &&
            (channels == 1 || channels == 2) &&
            (bits == 8 || bits == 16);
      }
      offset += 8 + chunkLength + (chunkLength.isOdd ? 1 : 0);
    }
    return false;
  }
}

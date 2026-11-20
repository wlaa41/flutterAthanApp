import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/alert_preferences.dart';
import '../models/quran_models.dart';
import 'quran_service.dart';
import 'sound_library.dart';

/// A verse-by-verse recitation, filed under Hafs verse numbers.
class Reciter {
  const Reciter._(this.name, this.riwayah, this._url);

  final String name;
  final String riwayah;
  final String Function(int surah, int ayah) _url;

  static final Reciter alafasy = Reciter._(
    'Mishary Rashid Alafasy',
    'Hafs',
    (surah, ayah) =>
        'https://cdn.islamic.network/quran/audio/128/ar.alafasy/'
        '${QuranService.hafsGlobalNumber(surah, ayah)}.mp3',
  );

  static final Reciter dosariWarsh = Reciter._(
    'Ibrahim Al-Dosari',
    'Warsh',
    (surah, ayah) =>
        'https://everyayah.com/data/warsh/warsh_ibrahim_aldosary_128kbps/'
        '${'$surah'.padLeft(3, '0')}${'$ayah'.padLeft(3, '0')}.mp3',
  );

  /// The recitation played under a mushaf. Only Hafs and Warsh have a
  /// verse-by-verse recording; the other riwayat play the Hafs one.
  static Reciter forEdition(MushafEdition edition) =>
      edition.textId == 'warsh' ? dosariWarsh : alafasy;

  /// Whether the recording is in the riwayah the mushaf is written in.
  bool matches(MushafEdition edition) =>
      edition.textId == 'warsh' ? this == dosariWarsh : edition.textId == 'hafs';

  /// The recordings that cover a verse: one per Hafs verse holding its words.
  List<String> urlsFor(MushafAyah ayah) => [
    for (var n = ayah.hafsFrom; n <= ayah.hafsTo; n++) _url(ayah.surah, n),
  ];
}

/// What is being recited, for the reader's player bar.
class RecitationNow {
  const RecitationNow({required this.title, required this.reciter});

  final String title;
  final String reciter;
}

class AudioService {
  static final AudioService instance = AudioService._internal();
  AudioService._internal() {
    _stateSubscription = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) _clearPlaying();
    });
  }

  final AudioPlayer _player = AudioPlayer();
  late final StreamSubscription<PlayerState> _stateSubscription;
  final ValueNotifier<String?> lastError = ValueNotifier(null);
  int _request = 0;
  bool _isPlayingAthan = false;

  /// The verses being recited, or null when none are.
  final ValueNotifier<RecitationNow?> recitation = ValueNotifier(null);

  AudioPlayer get player => _player;
  bool get isPlayingAthan => _isPlayingAthan;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  void _clearPlaying() {
    _isPlayingAthan = false;
    recitation.value = null;
  }

  /// Starts without waiting for the entire recording, keeping Stop responsive.
  Future<void> playSound(SoundOption sound) async {
    final request = ++_request;
    lastError.value = null;
    _clearPlaying();
    try {
      await _player.stop();
      if (request != _request || !sound.canPreview) return;
      if (sound.filePath != null) {
        await _player.setFilePath(sound.filePath!);
      } else {
        await _player.setAsset(sound.assetPath!);
      }
      if (request != _request) return;
      _isPlayingAthan = true;
      unawaited(
        _player.play().catchError((Object error) {
          if (request == _request) {
            _clearPlaying();
            lastError.value = 'Audio could not play. Try another sound.';
          }
        }),
      );
    } catch (error, stackTrace) {
      if (request != _request) return;
      debugPrint('Audio preview failed: $error\n$stackTrace');
      _clearPlaying();
      lastError.value = 'Audio could not load. Try another sound.';
      rethrow;
    }
  }

  Future<void> playAthan() async {
    // Existing home-screen controls do not await or catch this method.
    final request = ++_request;
    try {
      final preferences = await AlertPreferences.load();
      final sound = await SoundLibrary.instance.resolve(
        preferences.athanSoundId,
      );
      if (request != _request) return;
      await playSound(sound);
    } catch (_) {
      if (lastError.value == null) {
        lastError.value =
            'Audio could not load. Try another sound in Settings.';
      }
    }
  }

  Future<void> stop() async {
    ++_request;
    _clearPlaying();
    await _player.stop();
  }

  Future<void> toggleAthan() async {
    if (_player.playing && _isPlayingAthan) {
      await stop();
    } else {
      await playAthan();
    }
  }

  /// Recites verses one after another and completes when they end or stop.
  Future<void> playVerses(List<String> urls, RecitationNow label) async {
    if (urls.isEmpty) return;
    final request = ++_request;
    lastError.value = null;
    _clearPlaying();
    try {
      await _player.stop();
      if (request != _request) return;
      final source = urls.length == 1
          ? AudioSource.uri(Uri.parse(urls.single))
          : ConcatenatingAudioSource(
              children: [for (final url in urls) AudioSource.uri(Uri.parse(url))],
            );
      await _player.setAudioSource(source).timeout(const Duration(seconds: 15));
      if (request != _request) return;
      recitation.value = label;
      await _player.play();
    } catch (_) {
      if (request == _request) {
        try {
          await _player.stop();
        } catch (_) {}
        lastError.value =
            'Recitation could not load. Check your connection and retry.';
      }
    } finally {
      if (request == _request) _clearPlaying();
    }
  }

  Future<void> dispose() async {
    ++_request;
    await _stateSubscription.cancel();
    await _player.dispose();
    lastError.dispose();
    recitation.dispose();
  }
}

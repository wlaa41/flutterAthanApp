import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/alert_preferences.dart';
import 'sound_library.dart';

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
  int? _currentPlayingAyah;

  AudioPlayer get player => _player;
  bool get isPlayingAthan => _isPlayingAthan;
  int? get currentPlayingAyah => _currentPlayingAyah;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  void _clearPlaying() {
    _isPlayingAthan = false;
    _currentPlayingAyah = null;
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

  /// Retains completion semantics for the existing verse action sheet.
  Future<void> playAyah(int ayahGlobalNumber) async {
    if (ayahGlobalNumber < 1 || ayahGlobalNumber > 6236) return;
    final request = ++_request;
    lastError.value = null;
    _clearPlaying();
    try {
      await _player.stop();
      if (request != _request) return;
      final url =
          'https://cdn.islamic.network/quran/audio/128/ar.alafasy/$ayahGlobalNumber.mp3';
      await _player.setUrl(url).timeout(const Duration(seconds: 15));
      if (request != _request) return;
      _currentPlayingAyah = ayahGlobalNumber;
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
  }
}

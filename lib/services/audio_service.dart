import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class AudioService {
  static final AudioService instance = AudioService._internal();
  AudioService._internal();

  final AudioPlayer _player = AudioPlayer();
  AudioPlayer get player => _player;

  bool _isPlayingAthan = false;
  int? _currentPlayingAyah;

  bool get isPlayingAthan => _isPlayingAthan;
  int? get currentPlayingAyah => _currentPlayingAyah;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Play the authentic Athan audio ('asset/smooth.mp3')
  Future<void> playAthan() async {
    try {
      await _player.stop();
      _isPlayingAthan = true;
      _currentPlayingAyah = null;

      await _player.setAsset('asset/smooth.mp3');
      await _player.play();

      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isPlayingAthan = false;
        }
      });
    } catch (e) {
      debugPrint('AudioService: Error playing Athan audio: $e');
      _isPlayingAthan = false;
    }
  }

  /// Stop any currently playing audio
  Future<void> stop() async {
    try {
      await _player.stop();
      _isPlayingAthan = false;
      _currentPlayingAyah = null;
    } catch (e) {
      debugPrint('AudioService: Stop error: $e');
    }
  }

  /// Toggle play/pause for Athan preview
  Future<void> toggleAthan() async {
    if (_player.playing && _isPlayingAthan) {
      await stop();
    } else {
      await playAthan();
    }
  }

  /// Play a specific Quran Ayah by its global number (1 to 6236)
  /// Uses Mishary Rashid Alafasy recitation stream
  Future<void> playAyah(int ayahGlobalNumber) async {
    try {
      await _player.stop();
      _isPlayingAthan = false;
      _currentPlayingAyah = ayahGlobalNumber;

      final url =
          'https://cdn.islamic.network/quran/audio/128/ar.alafasy/$ayahGlobalNumber.mp3';
      await _player.setUrl(url);
      await _player.play();

      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (_currentPlayingAyah == ayahGlobalNumber) {
            _currentPlayingAyah = null;
          }
        }
      });
    } catch (e) {
      debugPrint('AudioService: Error playing Ayah $ayahGlobalNumber: $e');
      _currentPlayingAyah = null;
    }
  }

  void dispose() {
    _player.dispose();
  }
}

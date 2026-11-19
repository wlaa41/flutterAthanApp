import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/sound_library.dart';

/// A sound can be heard and selected here without changing saved preferences.
/// The owner saves the returned sound and stops playback when the sheet closes.
class SoundPickerSheet extends StatefulWidget {
  const SoundPickerSheet({
    super.key,
    required this.sounds,
    required this.selectedId,
    required this.iqama,
    required this.isIOS,
    required this.onPreview,
    required this.onStop,
    required this.onImport,
    this.isPlayingStream,
    this.playbackError,
  });

  final List<SoundOption> sounds;
  final String selectedId;
  final bool iqama;
  final bool isIOS;
  final Future<void> Function(SoundOption) onPreview;
  final Future<void> Function() onStop;
  final Future<SoundOption?> Function() onImport;
  final Stream<bool>? isPlayingStream;
  final ValueListenable<String?>? playbackError;

  @override
  State<SoundPickerSheet> createState() => _SoundPickerSheetState();
}

class _SoundPickerSheetState extends State<SoundPickerSheet>
    with WidgetsBindingObserver {
  late final List<SoundOption> _sounds;
  SoundOption? _selected;
  StreamSubscription<bool>? _playingSubscription;
  String? _previewId;
  String? _loadingPreviewId;
  String? _error;
  String? _importMessage;
  bool _importing = false;
  bool _heardPlayback = false;
  bool _playbackEnded = false;
  bool _appPaused = false;
  int _previewRequest = 0;
  final _errorKey = GlobalKey();
  final _importMessageKey = GlobalKey();

  bool get _busy => _importing || _loadingPreviewId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appPaused =
        lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.hidden ||
        lifecycle == AppLifecycleState.detached;
    _sounds = widget.sounds.where(_isAvailable).toList();
    for (final sound in _sounds) {
      if (sound.id == widget.selectedId) _selected = sound;
    }
    _listenToPlayback();
    widget.playbackError?.addListener(_onPlaybackError);
  }

  bool _isAvailable(SoundOption sound) =>
      sound.kind == SoundKind.custom ||
      sound.kind == SoundKind.tone ||
      sound.kind == (widget.iqama ? SoundKind.iqama : SoundKind.athan);

  void _listenToPlayback() {
    _playingSubscription = widget.isPlayingStream?.listen((playing) {
      if (!mounted) return;
      if (playing) _heardPlayback = true;
      if (!playing && _heardPlayback) _playbackEnded = true;
      if (!playing && _previewId != null) {
        setState(() => _previewId = null);
      }
    });
  }

  @override
  void didUpdateWidget(covariant SoundPickerSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlayingStream != widget.isPlayingStream) {
      _playingSubscription?.cancel();
      _listenToPlayback();
    }
    if (oldWidget.playbackError != widget.playbackError) {
      oldWidget.playbackError?.removeListener(_onPlaybackError);
      widget.playbackError?.addListener(_onPlaybackError);
    }
  }

  void _onPlaybackError() {
    final error = widget.playbackError?.value;
    if (!mounted || _appPaused || error == null) return;
    setState(() {
      _error = error;
      _previewId = null;
    });
    _showFeedback(_errorKey);
  }

  void _showFeedback(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final feedbackContext = key.currentContext;
      if (!mounted || feedbackContext == null) return;
      Scrollable.ensureVisible(
        feedbackContext,
        alignment: .1,
        duration: const Duration(milliseconds: 200),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _previewRequest++;
    _playingSubscription?.cancel();
    widget.playbackError?.removeListener(_onPlaybackError);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appPaused = false;
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      // The owner stops actual playback. Invalidate even a preview that has
      // not emitted its first playing event, so it cannot become stale on resume.
      _previewRequest++;
      setState(() {
        _appPaused = true;
        _previewId = null;
        _loadingPreviewId = null;
      });
    }
  }

  Future<void> _preview(SoundOption sound) async {
    if (_busy || _appPaused) return;
    final request = ++_previewRequest;
    final stopping = _previewId == sound.id;
    setState(() {
      _loadingPreviewId = sound.id;
      _error = null;
      if (!stopping) _selected = sound;
    });
    try {
      await widget.onStop();
      if (!mounted || _appPaused || request != _previewRequest) return;
      setState(() => _previewId = null);
      if (!stopping) {
        _heardPlayback = false;
        _playbackEnded = false;
        await widget.onPreview(sound);
        if (mounted &&
            !_appPaused &&
            request == _previewRequest &&
            !_playbackEnded &&
            widget.playbackError?.value == null) {
          setState(() => _previewId = sound.id);
        }
      }
    } catch (_) {
      if (mounted && !_appPaused && request == _previewRequest) {
        setState(() {
          _previewId = null;
          _error = stopping
              ? 'Audio could not be stopped. Try again.'
              : 'This sound could not play. Try another sound.';
        });
        _showFeedback(_errorKey);
      }
    } finally {
      if (mounted && request == _previewRequest) {
        setState(() => _loadingPreviewId = null);
      }
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() {
      _importing = true;
      _error = null;
      _importMessage = null;
    });
    try {
      await widget.onStop();
      if (!mounted) return;
      setState(() => _previewId = null);
      final sound = await widget.onImport();
      if (!mounted || sound == null) return;
      setState(() {
        _sounds.removeWhere((existing) => existing.id == sound.id);
        _sounds.add(sound);
        _selected = sound;
        _importMessage =
            '${sound.name} is in your library, even if you close this screen. Tap Use sound to apply it.';
      });
      _showFeedback(_importMessageKey);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not add that audio. Choose a playable MP3, M4A or WAV file under 20 MB and up to 10 minutes.',
        );
        _showFeedback(_errorKey);
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        widget.iqama
                            ? 'Choose Iqama sound'
                            : 'Choose Athan sound',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close sound picker',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  const Text('Listen to a sound, then tap Use sound.'),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _import,
                    icon: _importing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    label: Text(
                      _importing ? 'Adding audio…' : 'Add from phone',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'MP3, M4A or WAV · up to 20 MB · 10 minutes',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_importMessage != null) ...[
                    const SizedBox(height: 12),
                    _notice(
                      _importMessage!,
                      scheme.secondaryContainer,
                      _importMessageKey,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _notice(_error!, scheme.errorContainer, _errorKey),
                  ],
                  ..._group(
                    'Recitations',
                    _sounds.where(
                      (sound) =>
                          sound.kind == SoundKind.athan ||
                          sound.kind == SoundKind.iqama,
                    ),
                  ),
                  ..._group(
                    'Short tones & quiet options',
                    _sounds.where((sound) => sound.kind == SoundKind.tone),
                  ),
                  ..._group(
                    'Your audio',
                    _sounds.where((sound) => sound.kind == SoundKind.custom),
                  ),
                  if (!_sounds.any((sound) => sound.kind == SoundKind.custom))
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Have a favourite recording? Add it from your phone above.',
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy || _selected == null
                      ? null
                      : () => Navigator.pop(context, _selected),
                  icon: const Icon(Icons.check),
                  label: const Text('Use sound'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notice(String text, Color color, Key key) => Semantics(
    key: key,
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text),
    ),
  );

  List<Widget> _group(String title, Iterable<SoundOption> sounds) {
    final options = sounds.toList();
    if (options.isEmpty) return [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
      ),
      for (final sound in options) _soundTile(sound),
    ];
  }

  Widget _soundTile(SoundOption sound) {
    final selected = _selected?.id == sound.id;
    final previewing = _previewId == sound.id;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? scheme.secondaryContainer : scheme.surfaceContainerLow,
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        ),
        selected: selected,
        title: Text(sound.name),
        subtitle: Text(
          widget.isIOS && sound.isVibrationOnly
              ? 'Silent alert; vibration follows iPhone settings'
              : sound.description,
        ),
        onTap: _busy ? null : () => setState(() => _selected = sound),
        trailing: sound.canPreview
            ? IconButton(
                tooltip: '${previewing ? 'Stop' : 'Preview'} ${sound.name}',
                onPressed: _busy ? null : () => _preview(sound),
                icon: _loadingPreviewId == sound.id
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(previewing ? Icons.stop : Icons.play_arrow),
              )
            : null,
      ),
    );
  }
}

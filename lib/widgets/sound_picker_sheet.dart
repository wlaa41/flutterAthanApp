import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/athan_download.dart';
import '../services/athan_downloads.dart';
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
    this.moreAthans = const [],
    this.onAddAthan,
    this.onRemoveAthan,
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

  /// Athans that can be added from their public source, offered in this order.
  final List<AthanDownload> moreAthans;

  /// Fetches one athan and returns every added athan now on the phone.
  final Future<List<SoundOption>> Function(
    AthanDownload athan,
    void Function(double fraction) onProgress,
  )?
  onAddAthan;
  final Future<void> Function(AthanDownload athan)? onRemoveAthan;

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
  String? _addingId;
  double _addProgress = 0;
  String? _addErrorId;
  String? _addError;
  bool _showAllAthans = false;
  bool _heardPlayback = false;
  bool _playbackEnded = false;
  bool _appPaused = false;
  int _previewRequest = 0;
  final _errorKey = GlobalKey();
  final _importMessageKey = GlobalKey();

  bool get _busy =>
      _importing || _loadingPreviewId != null || _addingId != null;

  bool get _offersMore =>
      !widget.iqama &&
      widget.onAddAthan != null &&
      widget.moreAthans.isNotEmpty;

  /// A sound from [SoundPickerSheet.moreAthans] that is on the phone.
  bool _isAdded(SoundOption sound) =>
      _offersMore &&
      widget.moreAthans.any((athan) => athan.soundId == sound.id);

  SoundOption? _addedSound(AthanDownload athan) {
    for (final sound in _sounds) {
      if (sound.id == athan.soundId) return sound;
    }
    return null;
  }

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

  Future<void> _addAthan(AthanDownload athan) async {
    if (_busy) return;
    setState(() {
      _addingId = athan.id;
      _addProgress = 0;
      _addErrorId = null;
      _error = null;
    });
    try {
      await widget.onStop();
      if (!mounted) return;
      setState(() => _previewId = null);
      final added = await widget.onAddAthan!(athan, (fraction) {
        if (mounted) setState(() => _addProgress = fraction.clamp(0, 1));
      });
      if (!mounted) return;
      setState(() {
        _sounds.removeWhere((sound) => AthanDownloads.isAddedSound(sound.id));
        _sounds.addAll(added);
        _selected = _addedSound(athan) ?? _selected;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _addErrorId = athan.id;
          _addError = error is AthanDownloadFailure
              ? error.message
              : 'This athan could not be added. Try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _addingId = null);
    }
  }

  Future<void> _removeAthan(AthanDownload athan) async {
    if (_busy) return;
    try {
      await widget.onStop();
      await widget.onRemoveAthan!(athan);
      if (!mounted) return;
      setState(() {
        _previewId = null;
        _sounds.removeWhere((sound) => sound.id == athan.soundId);
        if (_selected?.id == athan.soundId) {
          _selected = null;
          for (final sound in _sounds) {
            if (sound.id == widget.selectedId) _selected = sound;
          }
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _addErrorId = athan.id;
          _addError = 'This athan could not be removed. Try again.';
        });
      }
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
                  ..._trendingAthans(),
                  ..._group(
                    'Recitations',
                    _sounds.where(
                      (sound) =>
                          !_isAdded(sound) &&
                          (sound.kind == SoundKind.athan ||
                              sound.kind == SoundKind.iqama),
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

  Widget _groupTitle(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Semantics(
      header: true,
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    ),
  );

  List<Widget> _group(String title, Iterable<SoundOption> sounds) {
    final options = sounds.toList();
    if (options.isEmpty) return [];
    return [_groupTitle(title), for (final sound in options) _soundTile(sound)];
  }

  /// The athans that can be added. Those asked for by name, and any already
  /// on the phone, stay in view; the rest open on request.
  List<Widget> _trendingAthans() {
    if (!_offersMore) return [];
    bool pinned(AthanDownload athan) =>
        athan.featured ||
        athan.id == _addingId ||
        _addedSound(athan) != null ||
        _selected?.id == athan.soundId;
    // A bundled athan is listed only with its built-in sound: it has nothing
    // to fetch.
    bool listed(AthanDownload athan) =>
        athan.bundled == null || _addedSound(athan) != null;
    final hidden = widget.moreAthans
        .where((athan) => listed(athan) && !pinned(athan))
        .length;
    return [
      _groupTitle('Trending athans'),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(
          'Add one to keep it on this phone. It is fetched once from its public source.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      for (final athan in widget.moreAthans)
        if (listed(athan) && (_showAllAthans || pinned(athan)))
          switch (_addedSound(athan)) {
            final sound? => _soundTile(sound, athan: athan),
            null => _addTile(athan),
          },
      if (hidden > 0 || _showAllAthans)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => setState(() => _showAllAthans = !_showAllAthans),
            icon: Icon(_showAllAthans ? Icons.expand_less : Icons.expand_more),
            label: Text(
              _showAllAthans ? 'Show fewer' : 'Show $hidden more athans',
            ),
          ),
        ),
    ];
  }

  Widget _athanNames(AthanDownload athan) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(athan.arabicName, textDirection: TextDirection.rtl),
      Text(athan.name, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );

  Widget _addTile(AthanDownload athan) {
    final scheme = Theme.of(context).colorScheme;
    final adding = _addingId == athan.id;
    final failed = _addErrorId == athan.id;
    final cut = athan.cutFrom != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: scheme.surfaceContainerLow,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            title: _athanNames(athan),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (athan.note != null) Text(athan.note!),
                Text(
                  cut
                      ? '${athan.place} · ${athan.length} · made from the full recording (${athan.size})'
                      : '${athan.place} · ${athan.length} · ${athan.size}',
                ),
                if (failed)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _addError!,
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  ),
              ],
            ),
            onTap: _busy ? null : () => _addAthan(athan),
            trailing: adding
                ? Semantics(
                    label: 'Adding ${athan.name}',
                    value: '${(_addProgress * 100).round()} percent',
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          value: _addProgress > 0 ? _addProgress : null,
                        ),
                      ),
                    ),
                  )
                : IconButton.filledTonal(
                    tooltip: 'Add ${athan.name}',
                    onPressed: _busy ? null : () => _addAthan(athan),
                    icon: Icon(failed ? Icons.refresh : Icons.download),
                  ),
          ),
          if (adding)
            LinearProgressIndicator(
              value: _addProgress > 0 ? _addProgress : null,
              minHeight: 3,
            ),
        ],
      ),
    );
  }

  Widget _soundTile(SoundOption sound, {AthanDownload? athan}) {
    final selected = _selected?.id == sound.id;
    final previewing = _previewId == sound.id;
    final scheme = Theme.of(context).colorScheme;
    // The athan in use stays: removing it would leave reminders without it.
    // A bundled athan is part of the app and cannot be removed.
    final removable =
        athan != null &&
        athan.bundled == null &&
        widget.onRemoveAthan != null &&
        sound.id != widget.selectedId;
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
        title: athan == null ? Text(sound.name) : _athanNames(athan),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (athan != null && athan.note != null) Text(athan.note!),
            Text(
              widget.isIOS && sound.isVibrationOnly
                  ? 'Silent alert; vibration follows iPhone settings'
                  : sound.description,
            ),
            if (athan != null && _addErrorId == athan.id)
              Semantics(
                liveRegion: true,
                child: Text(_addError!, style: TextStyle(color: scheme.error)),
              ),
          ],
        ),
        onTap: _busy ? null : () => setState(() => _selected = sound),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (removable)
              IconButton(
                tooltip: 'Remove ${sound.name} from this phone',
                visualDensity: VisualDensity.compact,
                onPressed: _busy ? null : () => _removeAthan(athan),
                icon: const Icon(Icons.delete_outline),
              ),
            if (sound.canPreview)
              IconButton(
                tooltip: '${previewing ? 'Stop' : 'Preview'} ${sound.name}',
                onPressed: _busy ? null : () => _preview(sound),
                icon: _loadingPreviewId == sound.id
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(previewing ? Icons.stop : Icons.play_arrow),
              ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/prayer_time_model.dart';
import '../services/audio_service.dart';
import '../services/prayer_service.dart';

class NextPrayerHero extends StatefulWidget {
  final PrayerTimeModel today;
  final VoidCallback onRefresh;

  const NextPrayerHero({
    super.key,
    required this.today,
    required this.onRefresh,
  });

  @override
  State<NextPrayerHero> createState() => _NextPrayerHeroState();
}

class _NextPrayerHeroState extends State<NextPrayerHero>
    with WidgetsBindingObserver {
  Timer? _timer;
  StreamSubscription<PlayerState>? _audioSubscription;
  late NextPrayerInfo _nextPrayer;
  late int _displayedDay;
  double _intervalSeconds = 0;
  bool _isPlayingAthan = false;
  bool _audioBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _displayedDay = _dayKey(PrayerService.instance.now);
    _updateNextPrayer();
    _startTimer();
    _audioSubscription = AudioService.instance.playerStateStream.listen((
      state,
    ) {
      if (!mounted) return;
      final playing =
          AudioService.instance.isPlayingAthan &&
          state.playing &&
          state.processingState != ProcessingState.completed;
      if (playing != _isPlayingAthan) setState(() => _isPlayingAthan = playing);
    });
    AudioService.instance.lastError.addListener(_showAudioError);
  }

  void _showAudioError() {
    if (!mounted) return;
    final message = AudioService.instance.lastError.value;
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _startTimer() {
    _timer?.cancel();
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final now = PrayerService.instance.now;
    final currentDay = _dayKey(now);
    setState(() {
      if (currentDay != _displayedDay ||
          !now.isBefore(_nextPrayer.prayerTime)) {
        _updateNextPrayer();
      } else {
        final remaining = _nextPrayer.prayerTime.difference(now);
        _nextPrayer = NextPrayerInfo(
          prayerName: _nextPrayer.prayerName,
          prayerIndex: _nextPrayer.prayerIndex,
          prayerTime: _nextPrayer.prayerTime,
          timeRemaining: remaining,
          progressFraction: _intervalSeconds <= 0
              ? 0
              : (1 - remaining.inSeconds / _intervalSeconds).clamp(0.0, 1.0),
        );
      }
    });
    if (currentDay != _displayedDay) {
      _displayedDay = currentDay;
      widget.onRefresh();
    }
  }

  int _dayKey(DateTime day) => day.year * 10000 + day.month * 100 + day.day;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _timer?.cancel();
    if (state == AppLifecycleState.resumed) {
      _tick();
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant NextPrayerHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.today != widget.today) _updateNextPrayer();
  }

  void _updateNextPrayer() {
    _nextPrayer = PrayerService.instance.calculateNextPrayer(
      widget.today,
      PrayerService.instance.now,
    );
    final fractionRemaining = 1 - _nextPrayer.progressFraction;
    _intervalSeconds = fractionRemaining <= 0
        ? 0
        : _nextPrayer.timeRemaining.inSeconds / fractionRemaining;
  }

  Future<void> _togglePreview() async {
    if (_audioBusy) return;
    setState(() => _audioBusy = true);
    try {
      await AudioService.instance.toggleAthan();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to play this sound. Try again in Settings.'),
          ),
        );
    } finally {
      if (mounted)
        setState(() {
          _audioBusy = false;
          _isPlayingAthan =
              AudioService.instance.isPlayingAthan &&
              AudioService.instance.player.playing;
        });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _audioSubscription?.cancel();
    AudioService.instance.lastError.removeListener(_showAudioError);
    super.dispose();
  }

  String _formatDuration(Duration remaining) {
    final d = remaining.isNegative ? Duration.zero : remaining;
    return '${d.inHours.toString().padLeft(2, '0')}:'
        '${(d.inMinutes % 60).toString().padLeft(2, '0')}:'
        '${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final target = _nextPrayer.prayerTime;
    final time =
        '${target.hour.toString().padLeft(2, '0')}:${target.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F3931), Color(0xFF071B19)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: _showCitySelectorModal,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    alignment: Alignment.centerLeft,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                  ),
                  icon: const Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFFE3C78F),
                  ),
                  label: Text(
                    PrayerService.instance.cityName,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              IconButton(
                onPressed: widget.onRefresh,
                icon: const Icon(Icons.refresh, color: Colors.white70),
                tooltip: 'Refresh prayer times',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Next prayer · ${_nextPrayer.prayerName}',
            style: const TextStyle(
              color: Color(0xFFE3C78F),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          // Wrapping leaves room for large accessibility text without squeezing
          // the countdown or making the playback control hard to reach.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Semantics(
                label:
                    '${_nextPrayer.prayerName} in ${_nextPrayer.timeRemaining.inMinutes} minutes',
                excludeSemantics: true,
                child: Text(
                  _formatDuration(_nextPrayer.timeRemaining),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _audioBusy ? null : _togglePreview,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  minimumSize: const Size(48, 48),
                  side: const BorderSide(color: Color(0xFFE3C78F)),
                ),
                icon: _audioBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _isPlayingAthan
                            ? Icons.stop_rounded
                            : Icons.volume_up_rounded,
                      ),
                label: Text(
                  _audioBusy
                      ? 'Loading…'
                      : _isPlayingAthan
                      ? 'Stop'
                      : 'Preview Athan',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _nextPrayer.progressFraction,
              semanticsLabel: 'Progress to the next prayer',
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFE3C78F)),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              Text(
                widget.today.formattedDate,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                '${_nextPrayer.prayerName} at $time',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showCitySelectorModal() async {
    final city = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * .75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choose your city',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close city list',
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: PrayerService.presetCities.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = PrayerService.presetCities[index];
                  final selected =
                      PrayerService.instance.cityName == option['name'];
                  return ListTile(
                    title: Text(option['name'] as String),
                    selected: selected,
                    trailing: selected
                        ? const Icon(Icons.check_circle_outline)
                        : null,
                    onTap: () => Navigator.pop(ctx, option),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (city == null || !mounted) return;
    try {
      await PrayerService.instance.updateLocation(
        lat: city['lat'] as double,
        lng: city['lng'] as double,
        city: city['name'] as String,
        method: city['method'] as int?,
        timeZoneName: city['timezone'] as String?,
      );
      if (mounted) widget.onRefresh();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this city. Please try again.'),
          ),
        );
    }
  }
}

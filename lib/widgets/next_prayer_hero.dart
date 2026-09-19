import 'dart:async';
import 'package:flutter/material.dart';
import '../models/prayer_time_model.dart';
import '../services/audio_service.dart';
import '../services/prayer_service.dart';

class NextPrayerHero extends StatefulWidget {
  final PrayerTimeModel today;
  final VoidCallback onRefresh;

  const NextPrayerHero({
    Key? key,
    required this.today,
    required this.onRefresh,
  }) : super(key: key);

  @override
  _NextPrayerHeroState createState() => _NextPrayerHeroState();
}

class _NextPrayerHeroState extends State<NextPrayerHero> {
  Timer? _timer;
  late NextPrayerInfo _nextPrayer;
  bool _isPlayingAthan = false;

  @override
  void initState() {
    super.initState();
    _updateNextPrayer();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _updateNextPrayer();
        });
      }
    });

    AudioService.instance.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingAthan = AudioService.instance.isPlayingAthan;
        });
      }
    });
  }

  void _updateNextPrayer() {
    _nextPrayer = PrayerService.instance.calculateNextPrayer(
      widget.today,
      DateTime.now(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F3931), // Deep Islamic Emerald
            Color(0xFF0B2421), // Midnight Forest
            Color(0xFF071B19),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F3931).withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Location & Refresh
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => _showCitySelectorModal(context),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Color(0xFFC5A059),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        PrayerService.instance.cityName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white54,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white60, size: 20),
                onPressed: widget.onRefresh,
                tooltip: 'Refresh Prayer Times',
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Prayer Countdown Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Prayer: ${_nextPrayer.prayerName}',
                    style: const TextStyle(
                      color: Color(0xFFC5A059),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '- ${_formatDuration(_nextPrayer.timeRemaining)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),

              // Athan Sound Button
              InkWell(
                onTap: () {
                  AudioService.instance.toggleAthan();
                  setState(() {
                    _isPlayingAthan = !_isPlayingAthan;
                  });
                },
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isPlayingAthan
                        ? const Color(0xFFC5A059)
                        : Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0xFFC5A059).withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isPlayingAthan
                            ? Icons.pause_rounded
                            : Icons.volume_up_rounded,
                        color: _isPlayingAthan ? Colors.black87 : Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isPlayingAthan ? 'Stop' : 'Athan',
                        style: TextStyle(
                          color: _isPlayingAthan ? Colors.black87 : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress Bar for current prayer interval
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _nextPrayer.progressFraction,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC5A059)),
            ),
          ),

          const SizedBox(height: 12),

          // Date & Target Time Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today: ${widget.today.formattedDate}',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
              Text(
                '${_nextPrayer.prayerName} at ${_nextPrayer.prayerTime.hour.toString().padLeft(2, '0')}:${_nextPrayer.prayerTime.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCitySelectorModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Your City',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: PrayerService.presetCities.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final city = PrayerService.presetCities[idx];
                    final isSelected =
                        PrayerService.instance.cityName == city['name'];
                    return ListTile(
                      title: Text(
                        city['name'] as String,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFF0F3931)
                              : Colors.black87,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle,
                              color: Color(0xFF0F3931))
                          : null,
                      onTap: () async {
                        await PrayerService.instance.updateLocation(
                          lat: city['lat'] as double,
                          lng: city['lng'] as double,
                          city: city['name'] as String,
                          method: city['method'] as int?,
                        );
                        Navigator.pop(ctx);
                        widget.onRefresh();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

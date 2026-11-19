import 'package:flutter/material.dart';

import '../models/prayer_time_model.dart';
import 'settings_screen.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';
import '../services/prayer_service.dart';
import '../widgets/next_prayer_hero.dart';
import '../widgets/prayer_row_card.dart';

class AthanScreen extends StatefulWidget {
  const AthanScreen({Key? key}) : super(key: key);

  @override
  _AthanScreenState createState() => _AthanScreenState();
}

class _AthanScreenState extends State<AthanScreen> with WidgetsBindingObserver {
  NotificationHealth? _health;
  bool _refreshing = false;
  PrayerTimeModel? _todayPrayer;
  List<PrayerTimeModel> _monthlyPrayers = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrayerTimes();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadPrayerTimes();
  }

  Future<void> _loadPrayerTimes({bool forceRefresh = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final now = PrayerService.instance.now;
      final monthly = await PrayerService.instance.getMonthlyPrayers(
        now.year,
        now.month,
        forceRefresh: forceRefresh,
      );
      final today = await PrayerService.instance.getTodayPrayers();

      if (mounted) {
        setState(() {
          _monthlyPrayers = monthly;
          _todayPrayer = today;
          _isLoading = false;
        });
      }
      try {
        await NotificationService.instance.refreshSchedule();
        final health = await NotificationService.instance.getHealth();
        if (mounted) setState(() => _health = health);
      } catch (_) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Prayer times are ready. Check Settings to finish reminder setup.',
              ),
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Prayer times could not be loaded. Please try again.';
        });
      }
    } finally {
      _refreshing = false;
    }
  }

  void _showMonthlySchedule() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .85,
        child: Column(
          children: [
            ListTile(
              title: const Text('Monthly prayer times'),
              subtitle: Text(PrayerService.instance.cityName),
              trailing: IconButton(
                tooltip: 'Close schedule',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: _monthlyPrayers.length,
                itemBuilder: (context, index) {
                  final day = _monthlyPrayers[index];
                  final today = PrayerService.instance.now;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${day.formattedDate}${day.date.day == today.day && day.date.month == today.month ? ' · Today' : ''}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            for (final index in [1, 2, 3, 4, 5, 6])
                              Text(
                                '${day.getPrayerName(index)} ${_time(day, index)}',
                              ),
                          ],
                        ),
                        const Divider(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _time(PrayerTimeModel day, int index) {
    final time = day.getPrayerDateTime(index);
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F3931)),
              ),
              SizedBox(height: 16),
              Text(
                'Loading Prayer Times...',
                style: TextStyle(color: Color(0xFF475569)),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty || _todayPrayer == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(_errorMessage),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _loadPrayerTimes(forceRefresh: true),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final today = _todayPrayer!;
    final now = PrayerService.instance.now;

    // Check prayer statuses
    final fajrTime = today.getPrayerDateTime(1);
    final sunriseTime = today.getPrayerDateTime(2);
    final dhuhrTime = today.getPrayerDateTime(3);
    final asrTime = today.getPrayerDateTime(4);
    final maghribTime = today.getPrayerDateTime(5);
    final ishaTime = today.getPrayerDateTime(6);

    int currentIdx = 0;
    if (now.isAfter(ishaTime)) {
      currentIdx = 6;
    } else if (now.isAfter(maghribTime)) {
      currentIdx = 5;
    } else if (now.isAfter(asrTime)) {
      currentIdx = 4;
    } else if (now.isAfter(dhuhrTime)) {
      currentIdx = 3;
    } else if (now.isAfter(sunriseTime)) {
      currentIdx = 2;
    } else if (now.isAfter(fajrTime)) {
      currentIdx = 1;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // Reimagined Hero Countdown Card
            NextPrayerHero(
              today: today,
              onRefresh: () => _loadPrayerTimes(forceRefresh: true),
            ),

            if (_health != null &&
                (!_health!.notificationsEnabled ||
                    !_health!.exactAlarmsEnabled))
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Finish reminder setup'),
                  subtitle: Text(
                    _health!.notificationsEnabled
                        ? 'Allow precise alarms for timely Athan playback.'
                        : 'Allow notifications to hear prayer reminders.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                    if (mounted) _loadPrayerTimes();
                  },
                ),
              ),
            if (today.isCalculated)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Offline calculation. Check your mosque timetable for local adjustments.',
                ),
              ),
            // Quick Actions Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month, size: 16),
                      label: const Text('Month Schedule'),
                      onPressed: _showMonthlySchedule,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F3931),
                        side: const BorderSide(color: Color(0xFF0F3931)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.volume_up, size: 16),
                      label: const Text('Play / stop'),
                      onPressed: () async {
                        try {
                          await AudioService.instance.toggleAthan();
                        } catch (_) {
                          if (mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Unable to play this sound. Choose another in Settings.',
                                ),
                              ),
                            );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F3931),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Today's Prayer Times List
            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                PrayerRowCard(
                  prayerIndex: 1,
                  prayerName: 'Fajr',
                  prayerArabic: 'الفجر',
                  time: today.fajr,
                  icon: Icons.nightlight_round,
                  isCurrent: currentIdx == 1,
                  isPassed: now.isAfter(sunriseTime),
                ),
                PrayerRowCard(
                  prayerIndex: 2,
                  prayerName: 'Sunrise',
                  prayerArabic: 'الشروق',
                  time: today.sunrise,
                  icon: Icons.wb_twighlight,
                  isCurrent: currentIdx == 2,
                  isPassed: now.isAfter(dhuhrTime),
                ),
                PrayerRowCard(
                  prayerIndex: 3,
                  prayerName: 'Dhuhr',
                  prayerArabic: 'الظهر',
                  time: today.dhuhr,
                  icon: Icons.wb_sunny_rounded,
                  isCurrent: currentIdx == 3,
                  isPassed: now.isAfter(asrTime),
                ),
                PrayerRowCard(
                  prayerIndex: 4,
                  prayerName: 'Asr',
                  prayerArabic: 'العصر',
                  time: today.asr,
                  icon: Icons.wb_sunny_outlined,
                  isCurrent: currentIdx == 4,
                  isPassed: now.isAfter(maghribTime),
                ),
                PrayerRowCard(
                  prayerIndex: 5,
                  prayerName: 'Maghrib',
                  prayerArabic: 'المغرب',
                  time: today.maghrib,
                  icon: Icons.wb_twilight_rounded,
                  isCurrent: currentIdx == 5,
                  isPassed: now.isAfter(ishaTime),
                ),
                PrayerRowCard(
                  prayerIndex: 6,
                  prayerName: 'Isha',
                  prayerArabic: 'العشاء',
                  time: today.isha,
                  icon: Icons.bedtime_rounded,
                  isCurrent: currentIdx == 6,
                  isPassed: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

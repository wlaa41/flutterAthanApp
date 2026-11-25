import 'dart:async';

import 'package:flutter/material.dart';

import '../models/prayer_time_model.dart';
import 'settings_screen.dart';
import '../services/ios_alarm_check.dart';
import '../services/notification_service.dart';
import '../services/prayer_service.dart';
import '../widgets/beep_mode_card.dart';
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
  bool _reloadRequested = false;
  bool _forceReloadRequested = false;
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
    if (!mounted) return;
    if (_refreshing) {
      // A city change or resume can arrive while future alarms are being saved.
      // Coalesce those requests and hide the obsolete city's timetable.
      _reloadRequested = true;
      _forceReloadRequested = _forceReloadRequested || forceRefresh;
      setState(() => _isLoading = true);
      return;
    }
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
          _isLoading = _reloadRequested;
        });
      }
      try {
        // Asks once per install for notifications and battery freedom.
        await NotificationService.instance.firstRunSetup();
        await NotificationService.instance.refreshSchedule();
        final health = await NotificationService.instance.getHealth();
        if (mounted) setState(() => _health = health);
        // Only in a build made by tools/ios_alarm_check.sh.
        unawaited(IosAlarmCheck.run());
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
      if (_reloadRequested && mounted) {
        final forceNext = _forceReloadRequested;
        _reloadRequested = false;
        _forceReloadRequested = false;
        await _loadPrayerTimes(forceRefresh: forceNext);
      }
    }
  }

  Future<void> _openSettings({
    SettingsSection section = SettingsSection.essentials,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(initialSection: section),
      ),
    );
    if (mounted) await _loadPrayerTimes();
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

            // One tap to swap the Athan for a beep, right under the countdown.
            const BeepModeCard(),

            if (_health != null &&
                _health!.supported &&
                _health!.problems.isNotEmpty)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Finish reminder setup'),
                  subtitle: Text(_health!.problems.first),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openSettings(section: SettingsSection.phone),
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
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month, size: 20),
                    label: const Text('Monthly times'),
                    onPressed: _showMonthlySchedule,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: const Color(0xFF0F3931),
                      side: const BorderSide(color: Color(0xFF0F3931)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.tune_rounded, size: 20),
                    label: const Text('Sounds & setup'),
                    onPressed: () => _openSettings(),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: const Color(0xFF0F3931),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

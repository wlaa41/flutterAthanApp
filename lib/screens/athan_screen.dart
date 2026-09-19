import 'package:flutter/material.dart';
import '../models/prayer_time_model.dart';
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

class _AthanScreenState extends State<AthanScreen> {
  PrayerTimeModel? _todayPrayer;
  List<PrayerTimeModel> _monthlyPrayers = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadPrayerTimes();
  }

  Future<void> _loadPrayerTimes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final now = DateTime.now();
      final monthly =
          await PrayerService.instance.getMonthlyPrayers(now.year, now.month);
      final today = await PrayerService.instance.getTodayPrayers();

      // Schedule local notifications for this month using 'smooth' sound
      NotificationService.instance.schedulePrayers(monthly).catchError((_) {});

      if (mounted) {
        setState(() {
          _monthlyPrayers = monthly;
          _todayPrayer = today;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load prayer times: $e';
        });
      }
    }
  }

  void _showMonthlySchedule() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final now = DateTime.now();
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Monthly Prayer Schedule',
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
              // Table Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F3931).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('Fajr', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('Sunrise', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('Dhuhr', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('Asr', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('Maghrib', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('Isha', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.builder(
                  itemCount: _monthlyPrayers.length,
                  itemBuilder: (context, idx) {
                    final item = _monthlyPrayers[idx];
                    final isToday = item.date.day == now.day &&
                        item.date.month == now.month;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: isToday
                            ? const Color(0xFFC5A059).withOpacity(0.18)
                            : (idx.isEven
                                ? const Color(0xFFF8FAFC)
                                : Colors.white),
                        borderRadius: BorderRadius.circular(8),
                        border: isToday
                            ? Border.all(color: const Color(0xFFC5A059))
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${item.date.day}/${item.date.month}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  isToday ? FontWeight.bold : FontWeight.normal,
                              color: isToday
                                  ? const Color(0xFF0F3931)
                                  : Colors.black87,
                            ),
                          ),
                          Text(item.fajr, style: const TextStyle(fontSize: 11)),
                          Text(item.sunrise, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(item.dhuhr, style: const TextStyle(fontSize: 11)),
                          Text(item.asr, style: const TextStyle(fontSize: 11)),
                          Text(item.maghrib, style: const TextStyle(fontSize: 11)),
                          Text(item.isha, style: const TextStyle(fontSize: 11)),
                        ],
                      ),
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
                const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(_errorMessage),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadPrayerTimes,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final today = _todayPrayer!;
    final now = DateTime.now();

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
        child: Column(
          children: [
            // Reimagined Hero Countdown Card
            NextPrayerHero(
              today: today,
              onRefresh: _loadPrayerTimes,
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
                      label: const Text('Test Athan'),
                      onPressed: () {
                        AudioService.instance.playAthan();
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
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
            ),
          ],
        ),
      ),
    );
  }
}

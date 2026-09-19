import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';
import '../services/prayer_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F3931),
        elevation: 0,
        title: const Text(
          'Settings & Audio',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFC5A059),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Location Card
          _buildSectionCard(
            title: 'Location & Calculation',
            icon: Icons.location_on_outlined,
            children: [
              ListTile(
                title: const Text('Selected City'),
                subtitle: Text(PrayerService.instance.cityName),
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF0F766E)),
                onTap: () => _selectCity(context),
              ),
              const Divider(),
              ListTile(
                title: const Text('Calculation Method'),
                subtitle: const Text('London Unified / Islamic Relief (Tap to change)'),
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF0F766E)),
                onTap: () => _selectMethod(context),
              ),
              const Divider(),
              ListTile(
                title: const Text('Offline Fallback Engine'),
                subtitle: const Text('Astronomical Solar Algorithm (Active & Fail-Safe)'),
                trailing: const Icon(Icons.shield_outlined, color: Color(0xFFC5A059)),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Audio & Sound
          _buildSectionCard(
            title: 'Athan Sound & Audio',
            icon: Icons.volume_up_outlined,
            children: [
              ListTile(
                leading: const Icon(Icons.music_note, color: Color(0xFFC5A059)),
                title: const Text('Athan Audio Track'),
                subtitle: const Text('Smooth Recitation (smooth.mp3)'),
                trailing: ElevatedButton(
                  onPressed: () {
                    AudioService.instance.playAthan();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Playing Athan audio (smooth.mp3)...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F3931),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Test Play'),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.notifications_active, color: Color(0xFF0F766E)),
                title: const Text('Test Notification'),
                subtitle: const Text('Triggers system notification with Athan sound'),
                trailing: OutlinedButton(
                  onPressed: () {
                    NotificationService.instance.testNotification();
                  },
                  child: const Text('Trigger'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Quran & Stylus
          _buildSectionCard(
            title: 'Holy Quran & Stylus Annotations',
            icon: Icons.edit_note,
            children: [
              const ListTile(
                title: Text('Tajweed Font & Color Scheme'),
                subtitle: Text('Authentic Uthmanic Tajweed with Arabic End Marks'),
                trailing: Icon(Icons.palette, color: Color(0xFFC5A059)),
              ),
              const Divider(),
              const ListTile(
                title: Text('Stylus & Highlighter Support'),
                subtitle: Text('S-Pen, Apple Pencil, and touch drawing with undo/redo'),
                trailing: Icon(Icons.brush, color: Color(0xFF2563EB)),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // App Info
          Center(
            child: Column(
              children: [
                Text(
                  'Athan & Quran London Pro',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 2.0.0 • Modernized & Offline Ready',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF0F3931), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF0F3931),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  void _selectCity(BuildContext context) {
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
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select City',
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
              const Divider(),
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
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
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
                        setState(() {});
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

  void _selectMethod(BuildContext context) {
    final methods = [
      {'name': 'London Unified / Islamic Relief', 'id': 10},
      {'name': 'Muslim World League (MWL)', 'id': 3},
      {'name': 'Islamic Society of North America (ISNA)', 'id': 2},
      {'name': 'Umm Al-Qura University, Makkah', 'id': 4},
      {'name': 'Egyptian General Authority', 'id': 5},
      {'name': 'University of Islamic Sciences, Karachi', 'id': 1},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Calculation Method',
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
              const Divider(),
              ...methods.map((m) {
                return ListTile(
                  title: Text(m['name'] as String),
                  onTap: () async {
                    await PrayerService.instance.updateLocation(
                      lat: PrayerService.instance.latitude,
                      lng: PrayerService.instance.longitude,
                      city: PrayerService.instance.cityName,
                      method: m['id'] as int?,
                    );
                    Navigator.pop(ctx);
                    setState(() {});
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import 'athan_screen.dart';
import 'journey_screen.dart';
import 'qibla_screen.dart';
import 'quran_index_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _ringingShown = false;

  bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    if (_ios) {
      WidgetsBinding.instance.addObserver(this);
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkRinging());
    }
  }

  @override
  void dispose() {
    if (_ios) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkRinging();
  }

  /// iPhone: an athan can still be ringing as an alarm when the app is opened,
  /// after the lock screen alert is gone. Offer Stop and Snooze right here.
  Future<void> _checkRinging() async {
    if (_ringingShown || !mounted) return;
    final status = await NotificationService.instance.iosAlarmStatus();
    if (!mounted || _ringingShown || status.ringing.isEmpty) return;
    _ringingShown = true;
    final ringing = status.ringing;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialog) => AlertDialog(
          icon: const Icon(Icons.alarm_on_outlined),
          title: Text(ringing.first.title),
          content: const Text('The athan is ringing.'),
          actions: [
            TextButton(
              onPressed: () async {
                for (final alarm in ringing) {
                  await NotificationService.instance.snoozeRinging(alarm.id);
                }
                if (dialog.mounted) Navigator.of(dialog).pop();
              },
              child: const Text('Snooze'),
            ),
            FilledButton(
              onPressed: () async {
                for (final alarm in ringing) {
                  await NotificationService.instance.stopRinging(alarm.id);
                }
                if (dialog.mounted) Navigator.of(dialog).pop();
              },
              child: const Text('Stop'),
            ),
          ],
        ),
      );
    } finally {
      _ringingShown = false;
    }
  }

  final List<Widget> _screens = const [
    AthanScreen(),
    QuranIndexScreen(),
    JourneyScreen(),
    QiblaScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF0F3931),
          unselectedItemColor: const Color(0xFF52615D),
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.access_time_filled_rounded),
              label: 'Prayers',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_rounded),
              label: 'Quran',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_rounded),
              label: 'Journey',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_rounded),
              label: 'Qibla',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

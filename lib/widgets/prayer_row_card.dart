import 'package:flutter/material.dart';

import '../services/notification_service.dart';

class PrayerRowCard extends StatefulWidget {
  final int prayerIndex;
  final String prayerName, prayerArabic, time;
  final IconData icon;
  final bool isCurrent, isPassed;
  const PrayerRowCard({
    super.key,
    required this.prayerIndex,
    required this.prayerName,
    required this.prayerArabic,
    required this.time,
    required this.icon,
    this.isCurrent = false,
    this.isPassed = false,
  });
  @override
  State<PrayerRowCard> createState() => _PrayerRowCardState();
}

class _PrayerRowCardState extends State<PrayerRowCard> {
  bool _enabled = true;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await NotificationService.instance.isPrayerEnabled(
      widget.prayerIndex,
    );
    if (mounted) setState(() => _enabled = enabled);
  }

  Future<void> _toggle() async {
    if (_busy) return;
    final next = !_enabled;
    setState(() => _busy = true);
    try {
      await NotificationService.instance.setPrayerEnabled(
        widget.prayerIndex,
        next,
      );
      if (mounted) setState(() => _enabled = next);
    } catch (_) {
      await _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Preference saved. Check Settings to refresh reminders.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
    color: widget.isCurrent ? const Color(0xFFE8F0EC) : null,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      widget.prayerName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      widget.prayerArabic,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      widget.time,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.isCurrent)
                      const Text(
                        'Current prayer',
                        style: TextStyle(color: Color(0xFF0F3931)),
                      ),
                    if (widget.prayerIndex == 2)
                      const Text(
                        'No Athan',
                        style: TextStyle(color: Color(0xFF475569)),
                      )
                    else
                      Text(
                        _enabled ? 'Reminders on' : 'Reminders off',
                        style: const TextStyle(color: Color(0xFF475569)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.prayerIndex != 2)
            Semantics(
              toggled: _enabled,
              child: IconButton(
                tooltip:
                    '${_enabled ? 'Mute' : 'Enable'} ${widget.prayerName} and its Iqama reminders',
                onPressed: _busy ? null : _toggle,
                icon: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _enabled
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                      ),
                color: const Color(0xFF0F3931),
              ),
            ),
        ],
      ),
    ),
  );
}

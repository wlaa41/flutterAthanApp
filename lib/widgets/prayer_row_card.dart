import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class PrayerRowCard extends StatefulWidget {
  final int prayerIndex;
  final String prayerName;
  final String prayerArabic;
  final String time;
  final IconData icon;
  final bool isCurrent;
  final bool isPassed;

  const PrayerRowCard({
    Key? key,
    required this.prayerIndex,
    required this.prayerName,
    required this.prayerArabic,
    required this.time,
    required this.icon,
    this.isCurrent = false,
    this.isPassed = false,
  }) : super(key: key);

  @override
  _PrayerRowCardState createState() => _PrayerRowCardState();
}

class _PrayerRowCardState extends State<PrayerRowCard> {
  bool _isAlarmEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadAlarmSetting();
  }

  Future<void> _loadAlarmSetting() async {
    final enabled =
        await NotificationService.instance.isPrayerEnabled(widget.prayerIndex);
    if (mounted) {
      setState(() {
        _isAlarmEnabled = enabled;
      });
    }
  }

  void _toggleAlarm() async {
    final nextState = !_isAlarmEnabled;
    await NotificationService.instance
        .setPrayerEnabled(widget.prayerIndex, nextState);
    if (mounted) {
      setState(() {
        _isAlarmEnabled = nextState;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: widget.isCurrent
            ? const Color(0xFF0F3931).withOpacity(0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.isCurrent
              ? const Color(0xFFC5A059)
              : Colors.grey.shade200,
          width: widget.isCurrent ? 1.8 : 1.0,
        ),
        boxShadow: widget.isCurrent
            ? [
                BoxShadow(
                  color: const Color(0xFFC5A059).withOpacity(0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          // Prayer Icon with circular background
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: widget.isCurrent
                  ? const Color(0xFF0F3931)
                  : (widget.isPassed
                      ? Colors.grey.shade200
                      : const Color(0xFFF1F5F9)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.icon,
              color: widget.isCurrent
                  ? const Color(0xFFC5A059)
                  : (widget.isPassed ? Colors.grey : const Color(0xFF0F766E)),
              size: 20,
            ),
          ),

          const SizedBox(width: 14),

          // Name and Arabic
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.prayerName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: widget.isCurrent
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: widget.isPassed
                            ? Colors.grey.shade600
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    if (widget.isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC5A059),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'NOW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.prayerArabic,
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          // Prayer Time
          Text(
            widget.time,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: widget.isCurrent
                  ? const Color(0xFF0F3931)
                  : (widget.isPassed
                      ? Colors.grey.shade500
                      : const Color(0xFF1E293B)),
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(width: 10),

          // Notification Toggle Button (skip for sunrise)
          if (widget.prayerIndex != 2)
            IconButton(
              icon: Icon(
                _isAlarmEnabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_outlined,
                color: _isAlarmEnabled
                    ? const Color(0xFF0F766E)
                    : Colors.grey.shade400,
                size: 20,
              ),
              onPressed: _toggleAlarm,
              tooltip: _isAlarmEnabled ? 'Mute Athan' : 'Enable Athan',
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}

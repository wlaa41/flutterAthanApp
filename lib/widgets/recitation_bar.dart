import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import 'reader_palette.dart';

/// Says what is being recited, with a button to stop it. It floats over the
/// page while a recitation plays.
class RecitationBar extends StatelessWidget {
  const RecitationBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RecitationNow?>(
      valueListenable: AudioService.instance.recitation,
      builder: (context, now, _) => now == null
          ? const SizedBox.shrink()
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: ReaderPalette.green,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: ReaderPalette.gold, width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.graphic_eq,
                    color: ReaderPalette.gold,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Reciting ${now.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          now.reciter,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.stop_circle_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    tooltip: 'Stop Recitation',
                    onPressed: () => AudioService.instance.stop(),
                  ),
                ],
              ),
            ),
    );
  }
}

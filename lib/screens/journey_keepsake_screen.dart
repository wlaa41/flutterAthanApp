import 'package:flutter/material.dart';

import '../models/journey.dart';
import '../services/journey_progress.dart';
import '../widgets/journey_art.dart';
import '../widgets/journey_reading.dart';
import '../widgets/journey_ui.dart';
import 'journey_stop_screen.dart';

/// A story is complete: the player finds the thing its ayahs name.
class JourneyKeepsakeScreen extends StatelessWidget {
  const JourneyKeepsakeScreen({
    super.key,
    required this.journey,
    required this.progress,
    required this.section,
    required this.arabic,
  });

  final Journey journey;
  final JourneyProgress progress;

  /// The story that has just been walked to its end.
  final JourneySection section;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final t = JText(arabic);
    final keepsake = section.keepsake!;
    final found = journey.found(progress.done);
    final next = journey.next(progress.done);
    final nextSection = next == null ? null : journey.sectionOf(next);
    final opensStory =
        nextSection != null &&
        nextSection.keepsake != null &&
        nextSection.stops.first == next;
    final upcoming = journey.keepsakes
        .where((other) => !found.contains(other))
        .firstOrNull;
    return JScreen(
      arabic: arabic,
      color: J.deep,
      child: JPage(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        children: [
          Text(
            t.pick(
              'STORY COMPLETE: ${section.full(false).toUpperCase()}',
              'اكتملت القصة: ${section.full(true)}',
            ),
            textAlign: TextAlign.center,
            style: J.text(
              13,
              weight: 700,
              color: const Color(0xFFD7DEFF),
              spacing: arabic ? null : 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: KeepsakeArt(id: keepsake.id, label: keepsake.name(arabic)),
          ),
          const SizedBox(height: 10),
          Text(
            t.pick('You found ${keepsake.en}', 'وجدت ${keepsake.ar}'),
            textAlign: TextAlign.center,
            style: J.text(
              30,
              weight: 800,
              color: J.white,
              height: arabic ? 1.35 : 1.15,
            ),
          ),
          const SizedBox(height: 12),
          // The ayah that names it is opened whole, with the meaning its
          // source gives. No part of an ayah is lifted out onto this screen.
          JCard(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.pick(
                    'Ayah ${keepsake.ayah} of Al-Kahf mentions ${keepsake.en}.',
                    'جاء ذكر ${keepsake.ar} في الآية ${t.number(keepsake.ayah)} من سورة الكهف.',
                  ),
                  textAlign: TextAlign.center,
                  style: J.text(16.5, weight: 600, height: arabic ? 1.6 : 1.4),
                ),
                const SizedBox(height: 8),
                JButton.text(
                  t.pick(
                    'Read ayah ${keepsake.ayah}',
                    'اقرأ الآية ${t.number(keepsake.ayah)}',
                  ),
                  color: J.white,
                  depth: 0,
                  minHeight: 48,
                  size: 17,
                  weight: 700,
                  icon: const Icon(
                    Icons.menu_book_rounded,
                    color: J.ink,
                    size: 22,
                  ),
                  onTap: () => showJourneyAyah(
                    context,
                    journey: journey,
                    ayah: keepsake.ayah,
                    arabic: arabic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final other in journey.keepsakes) ...[
                KeepsakeBadge(
                  id: other.id,
                  found: found.contains(other),
                  onDark: true,
                  size: 44,
                  label: t.keepsake(
                    other.en,
                    other.ar,
                    found: found.contains(other),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Text(
                t.ofCount(found.length, journey.keepsakes.length),
                style: J.text(15, weight: 700, color: J.lilacText),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(height: 16),
          if (next != null)
            JButton(
              onTap: () => Navigator.of(context).pop(JourneyAfter.next),
              minHeight: 60,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    opensStory
                        ? t.pick(
                            'Next story: ${nextSection.full(false)}',
                            'القصة التالية: ${nextSection.full(true)}',
                          )
                        : t.pick('Keep going: ${next.en}', 'تابع: ${next.ar}'),
                    textAlign: TextAlign.center,
                    style: J.text(19, weight: 800, height: 1.2),
                  ),
                  Text(
                    opensStory
                        ? t.pick(
                            'Keepsake: ${nextSection.keepsake!.en}',
                            'التذكار: ${nextSection.keepsake!.ar}',
                          )
                        : upcoming != null
                        ? t.pick(
                            'Next keepsake: ${upcoming.en}',
                            'التذكار التالي: ${upcoming.ar}',
                          )
                        : t.ayahs(next.first, next.last),
                    textAlign: TextAlign.center,
                    style: J.text(13.5, weight: 600, height: 1.2),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 9),
          JButton.text(
            t.pick('Back to the map', 'العودة إلى الخريطة'),
            color: J.deep,
            border: J.white,
            textColor: J.white,
            depth: 0,
            minHeight: 50,
            size: 17,
            weight: 700,
            onTap: () => Navigator.of(context).pop(JourneyAfter.map),
          ),
        ],
      ),
    );
  }
}

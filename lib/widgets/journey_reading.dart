import 'package:flutter/material.dart';

import '../models/journey.dart';
import 'journey_ui.dart';

/// What an ayah means, as its source words it: the Saheeh International
/// translation with its footnotes, or al-Tafsir al-Muyassar. Not one letter
/// of it is written by the app.
class JourneyMeaning extends StatelessWidget {
  const JourneyMeaning({
    super.key,
    required this.journey,
    required this.ayah,
    required this.arabic,
    this.size,
    this.color = J.ink,
  });

  final Journey journey;

  /// The ayah, or the first ayah of a passage that shares one tafsir text.
  final int ayah;

  /// The Arabic levels read the tafsir; the English level the translation.
  final bool arabic;
  final double? size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final meaning = journey.meaning(ayah);
    if (arabic) {
      return Text(
        meaning.ar,
        textDirection: TextDirection.rtl,
        style: J.text(size ?? 16.5, color: color, height: 1.7),
      );
    }
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            meaning.en,
            style: J.text(size ?? 16, color: color, height: 1.45),
          ),
          for (final note in meaning.notes)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                note,
                style: J.text(
                  (size ?? 16) - 2.5,
                  color: color == J.ink ? J.muted : color,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A small line that names the work a meaning is copied from.
class JourneySourceLine extends StatelessWidget {
  const JourneySourceLine(this.text, {super.key, this.onTap, this.more});

  final String text;

  /// Opens the page of sources. With it, [more] names the page.
  final VoidCallback? onTap;
  final String? more;

  @override
  Widget build(BuildContext context) {
    final style = J.text(13.5, weight: 600, color: J.label, height: 1.4);
    final tap = onTap;
    if (tap == null) return Text(text, style: style);
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$text  '),
                TextSpan(
                  text: more,
                  style: style.copyWith(
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                    decorationColor: J.label,
                  ),
                ),
              ],
            ),
            style: style,
          ),
        ),
      ),
    );
  }
}

/// An ayah, or the few that are read as one passage, whole, with the meaning
/// its source gives.
class JourneyRead extends StatelessWidget {
  const JourneyRead({
    super.key,
    required this.journey,
    required this.passage,
    required this.arabic,
    this.playing = false,
    this.onListen,
    this.depth = 5,
  });

  final Journey journey;
  final JourneyPassage passage;
  final bool arabic;

  /// Whether this passage is being recited now.
  final bool playing;
  final VoidCallback? onListen;
  final double depth;

  @override
  Widget build(BuildContext context) {
    final t = JText(arabic);
    final text = journey.passageText(passage);
    return JCard(
      depth: depth,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.passage(passage.first, passage.last),
                  style: J.text(14.5, weight: 700, color: J.label),
                ),
              ),
              if (onListen != null)
                JRound(
                  icon: playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  label: passage.isOne
                      ? t.pick('Listen to the ayah', 'استمع إلى الآية')
                      : t.pick('Listen to the ayahs', 'استمع إلى الآيات'),
                  color: J.lilacPale,
                  onTap: onListen,
                ),
            ],
          ),
          JQuran(text, size: JQuran.sizeFor(text, largest: 23)),
          Container(
            height: 2,
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            color: J.panel,
          ),
          JourneyMeaning(journey: journey, ayah: passage.first, arabic: arabic),
        ],
      ),
    );
  }
}

/// Opens one ayah to read: the whole ayah and the meaning its source gives.
Future<void> showJourneyAyah(
  BuildContext context, {
  required Journey journey,
  required int ayah,
  required bool arabic,
}) {
  final t = JText(arabic);
  final passage = arabic ? journey.passageOf(ayah) : JourneyPassage(ayah, ayah);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Directionality(
      textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: JourneyRead(
                      journey: journey,
                      passage: passage,
                      arabic: arabic,
                      depth: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                JCard(
                  depth: 0,
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      JourneySourceLine(t.meaningSource),
                      const SizedBox(height: 8),
                      JButton.text(
                        t.pick('Done', 'تم'),
                        minHeight: 50,
                        size: 18,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

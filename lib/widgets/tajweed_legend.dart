import 'package:flutter/material.dart';

import '../models/quran_models.dart';
import 'mushaf_sheets.dart';
import 'reader_palette.dart';

/// The key to the tajweed colours, kept on the page under the text: every
/// colour beside the name of its rule. A tap opens what each one asks of the
/// reciter.
class TajweedLegend extends StatelessWidget {
  const TajweedLegend({super.key, required this.palette});

  final ReaderPalette palette;

  @override
  Widget build(BuildContext context) {
    final label = TextStyle(fontSize: 12, height: 1.2, color: palette.ink);
    return Semantics(
      container: true,
      button: true,
      label: 'Tajweed colour key. Opens what the colours mean.',
      child: Material(
        color: palette.card,
        shape: Border(top: BorderSide(color: palette.rule)),
        child: InkWell(
          onTap: () => TajweedGuideSheet.show(context, palette),
          // Large system text may grow the key, but not past the page.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: palette.soft),
                      const SizedBox(width: 6),
                      Text(
                        'Colours',
                        style: label.copyWith(
                          color: palette.soft,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      for (final entry in TajweedGuideEntry.all) ...[
                        const SizedBox(width: 14),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: palette.tajweed[entry.rules.first],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(entry.title, style: label),
                        const SizedBox(width: 5),
                        Text(
                          entry.arabicTitle,
                          textDirection: TextDirection.rtl,
                          style: label.copyWith(color: palette.soft),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

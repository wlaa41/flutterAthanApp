import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/quran_models.dart';

class TajweedText extends StatelessWidget {
  final Ayah ayah;
  final double fontSize;
  final VoidCallback? onTap;
  final bool isSelected;

  const TajweedText({
    Key? key,
    required this.ayah,
    this.fontSize = 24.0,
    this.onTap,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final spans = _parseTajweed(ayah.tajweedText, context);

    // Append beautiful Arabic Ayah end symbol
    final arabicNumber = _toArabicDigits(ayah.numberInSurah);
    spans.add(
      TextSpan(
        text: ' \uFD3F$arabicNumber\uFD3E ',
        style: TextStyle(
          fontFamily: 'serif',
          fontSize: fontSize * 0.9,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFC5A059), // Gold accent
        ),
      ),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFC5A059).withOpacity(0.18)
              : (ayah.highlightColorValue != null
                  ? Color(ayah.highlightColorValue!).withOpacity(0.25)
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: const Color(0xFFC5A059), width: 1.2)
              : null,
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: RichText(
            textAlign: TextAlign.right,
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: fontSize,
                height: 1.9,
                color: const Color(0xFF1E293B), // Elegant slate dark
                fontWeight: FontWeight.w500,
              ),
              children: spans,
            ),
          ),
        ),
      ),
    );
  }

  /// Parses Tajweed bracket syntax into colored TextSpans
  List<InlineSpan> _parseTajweed(String text, BuildContext context) {
    final spans = <InlineSpan>[];
    int currentIndex = 0;

    // Matches patterns like [h:1[ٱ], [q[لْ], [m[ضَّ], etc.
    final regex = RegExp(r'\[([a-z])(?::[0-9]+)?\[([^\]]*)\]');
    final matches = regex.allMatches(text);

    for (final match in matches) {
      // Text before the Tajweed match
      if (match.start > currentIndex) {
        final plain = text.substring(currentIndex, match.start);
        spans.add(TextSpan(
          text: plain,
          recognizer: TapGestureRecognizer()..onTap = onTap,
        ));
      }

      final ruleCode = match.group(1) ?? '';
      final innerContent = match.group(2) ?? '';
      final color = TajweedRuleInfo.getColorForCode(ruleCode);

      spans.add(
        TextSpan(
          text: innerContent,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
          ),
          recognizer: TapGestureRecognizer()..onTap = onTap,
        ),
      );

      currentIndex = match.end;
    }

    // Trailing text
    if (currentIndex < text.length) {
      final trailing = text.substring(currentIndex);
      spans.add(TextSpan(
        text: trailing,
        recognizer: TapGestureRecognizer()..onTap = onTap,
      ));
    }

    return spans;
  }

  static String _toArabicDigits(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    final s = number.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final d = int.tryParse(s[i]);
      if (d != null && d >= 0 && d <= 9) {
        buffer.write(arabicDigits[d]);
      } else {
        buffer.write(s[i]);
      }
    }
    return buffer.toString();
  }

  /// Displays the Tajweed rules guide dialog
  static void showTajweedLegendModal(BuildContext context) {
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tajweed Color Guide',
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
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: TajweedRuleInfo.allRules.length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (context, idx) {
                    final rule = TajweedRuleInfo.allRules[idx];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(top: 2, right: 12),
                          decoration: BoxDecoration(
                            color: rule.color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black12),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    rule.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  Text(
                                    rule.arabicTitle,
                                    style: const TextStyle(
                                      fontFamily: 'serif',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF0F766E),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                rule.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
}

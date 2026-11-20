import 'package:flutter/material.dart';

import '../models/quran_models.dart';
import '../services/mushaf_library.dart';
import '../services/mushaf_pages.dart';
import 'reader_palette.dart';

const _ink = Color(0xFF0F172A);
const _soft = Color(0xFF64748B);

Widget _sheetFrame(BuildContext context, {required List<Widget> children}) {
  // A Material, so list tiles inside draw their ink on the sheet itself.
  return Material(
    color: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: children,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _sheetTitle(BuildContext context, String title) => Row(
  children: [
    Expanded(
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: _ink,
        ),
      ),
    ),
    IconButton(
      tooltip: 'Close',
      icon: const Icon(Icons.close),
      onPressed: () => Navigator.pop(context),
    ),
  ],
);

/// Chooses the mushaf and, inside the reader, how its page looks.
class MushafSettingsSheet extends StatefulWidget {
  const MushafSettingsSheet({
    super.key,
    required this.edition,
    required this.onEdition,
    this.fontSize,
    this.night,
    this.onFontSize,
    this.onNight,
    this.printedPages,
    this.onPrintedPages,
  });

  final MushafEdition edition;
  final ValueChanged<MushafEdition> onEdition;

  /// Whether the reader shows printed pages (true) or flowing text (false),
  /// and what to do when the other is chosen. The choice is offered only
  /// when the reader passes both.
  final bool? printedPages;
  final ValueChanged<bool>? onPrintedPages;

  /// The page controls are shown only when the reader passes them.
  final double? fontSize;
  final bool? night;
  final ValueChanged<double>? onFontSize;
  final ValueChanged<bool>? onNight;

  static const double minFontSize = 20;
  static const double maxFontSize = 40;

  static Future<void> show(
    BuildContext context, {
    required MushafEdition edition,
    required ValueChanged<MushafEdition> onEdition,
    double? fontSize,
    bool? night,
    ValueChanged<double>? onFontSize,
    ValueChanged<bool>? onNight,
    bool? printedPages,
    ValueChanged<bool>? onPrintedPages,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MushafSettingsSheet(
        edition: edition,
        onEdition: onEdition,
        fontSize: fontSize,
        night: night,
        onFontSize: onFontSize,
        onNight: onNight,
        printedPages: printedPages,
        onPrintedPages: onPrintedPages,
      ),
    );
  }

  @override
  State<MushafSettingsSheet> createState() => _MushafSettingsSheetState();
}

class _MushafSettingsSheetState extends State<MushafSettingsSheet> {
  late MushafEdition _edition = widget.edition;
  late double? _fontSize = widget.fontSize;
  late bool? _night = widget.night;

  String _note(MushafEdition edition) => edition.hafsNumbering
      ? edition.note
      : '${edition.note} ${_thousands(edition.ayahCount)} ayat, numbered '
            'a little differently from Hafs.';

  static String _thousands(int value) {
    final text = '$value';
    return text.length > 3
        ? '${text.substring(0, text.length - 3)},'
              '${text.substring(text.length - 3)}'
        : text;
  }

  Widget _editionRow(MushafEdition edition) {
    final chosen = edition.id == _edition.id;
    return Semantics(
      button: true,
      selected: chosen,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() => _edition = edition);
          widget.onEdition(edition);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          decoration: BoxDecoration(
            color: chosen ? const Color(0xFFF1F6F3) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: chosen ? ReaderPalette.green : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 10),
                child: Icon(
                  chosen ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 22,
                  color: chosen ? ReaderPalette.green : Colors.grey.shade500,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Side by side when there is room; with large text the
                    // Arabic name drops to its own line.
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 8,
                        children: [
                          Text(
                            edition.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                          Text(
                            edition.arabicName,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: ReaderPalette.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _note(edition),
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: _soft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Printed pages or flowing text. Choosing the other one closes the sheet,
  /// because the reader changes under it.
  List<Widget> _viewChoice() {
    final printed = widget.printedPages;
    final onChange = widget.onPrintedPages;
    if (printed == null || onChange == null) return const [];
    final available = MushafPages.has(_edition);
    void choose(bool value) {
      if (value == printed) return;
      Navigator.pop(context);
      onChange(value);
    }

    return [
      const Text(
        'Page',
        style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          ChoiceChip(
            label: const Text('Printed pages'),
            selected: printed,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: available ? (_) => choose(true) : null,
          ),
          ChoiceChip(
            label: const Text('Flowing text'),
            selected: !printed,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: (_) => choose(false),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        !available
            ? 'This mushaf opens as flowing text. Printed pages are ready for '
                  'the two Hafs copies.'
            : printed
            ? 'The 604 pages of the Madinah mushaf, each line as it is '
                  'printed. Swipe to turn the page.'
            : 'One surah at any text size, with room for handwritten notes.',
        style: const TextStyle(fontSize: 12.5, height: 1.35, color: _soft),
      ),
      const SizedBox(height: 10),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = _fontSize;
    final night = _night;
    return _sheetFrame(
      context,
      children: [
        _sheetTitle(context, 'Mushaf'),
        const Text(
          'Each copy is the King Fahd Complex mushaf of that riwayah, in its '
          'own script. All of them work offline.',
          style: TextStyle(fontSize: 13, height: 1.4, color: _soft),
        ),
        const SizedBox(height: 10),
        for (final edition in MushafLibrary.editions) _editionRow(edition),
        if (widget.printedPages != null) const SizedBox(height: 14),
        ..._viewChoice(),
        if (fontSize != null && widget.onFontSize != null) ...[
          const Text(
            'Text size',
            style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
          ),
          Row(
            children: [
              const Text('ب', style: TextStyle(fontSize: 16, color: _soft)),
              Expanded(
                child: Slider(
                  value: fontSize
                      .clamp(
                        MushafSettingsSheet.minFontSize,
                        MushafSettingsSheet.maxFontSize,
                      )
                      .toDouble(),
                  min: MushafSettingsSheet.minFontSize,
                  max: MushafSettingsSheet.maxFontSize,
                  divisions: 10,
                  label: '${fontSize.round()}',
                  activeColor: ReaderPalette.green,
                  semanticFormatterCallback: (value) =>
                      'Text size ${value.round()}',
                  onChanged: (value) {
                    setState(() => _fontSize = value);
                    widget.onFontSize!(value);
                  },
                ),
              ),
              const Text('ب', style: TextStyle(fontSize: 26, color: _soft)),
            ],
          ),
        ],
        if (night != null && widget.onNight != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: ReaderPalette.green,
            title: const Text(
              'Night page',
              style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
            ),
            subtitle: const Text('Light text on a dark page.'),
            value: night,
            onChanged: (value) {
              setState(() => _night = value);
              widget.onNight!(value);
            },
          ),
        if (_edition.tajweedColours)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.palette_outlined, color: _ink),
            title: const Text(
              'What the colours mean',
              style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => TajweedGuideSheet.show(
              context,
              (night ?? false) ? ReaderPalette.dark : ReaderPalette.paper,
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'Text and fonts: King Fahd Glorious Quran Printing Complex, as '
          'published. Page lines, tajweed colours and tafsir: quran.com. '
          'Meaning: Saheeh '
          'International. Recitation: Mishary Alafasy (Hafs) and Ibrahim '
          'Al-Dosari (Warsh).',
          style: TextStyle(fontSize: 12, height: 1.4, color: _soft),
        ),
      ],
    );
  }
}

/// The key to the tajweed colours.
class TajweedGuideSheet extends StatelessWidget {
  const TajweedGuideSheet({super.key, required this.palette});

  final ReaderPalette palette;

  static Future<void> show(BuildContext context, ReaderPalette palette) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TajweedGuideSheet(palette: palette),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _sheetFrame(
      context,
      children: [
        _sheetTitle(context, 'Tajweed colours'),
        for (final entry in TajweedGuideEntry.all)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 2, right: 12),
                  decoration: BoxDecoration(
                    color: palette.tajweed[entry.rules.first],
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 8,
                          children: [
                            Text(
                              entry.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: _ink,
                              ),
                            ),
                            Text(
                              entry.arabicTitle,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: ReaderPalette.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.description,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: _soft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        const Text(
          'The colours are the Hafs tajweed key published with quran.com. A '
          'few letters whose spelling differs between the two texts are left '
          'uncoloured.',
          style: TextStyle(fontSize: 12, height: 1.4, color: _soft),
        ),
      ],
    );
  }
}

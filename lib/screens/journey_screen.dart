import 'package:flutter/material.dart';

import '../models/journey.dart';
import '../services/journey_progress.dart';
import '../widgets/journey_art.dart';
import '../widgets/journey_ui.dart';
import 'journey_stop_screen.dart';

/// The Journey tab: choose how to play, then the map of the surah.
class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key});

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  Journey? _journey;
  JourneyProgress? _progress;

  /// A finished part the player has opened again.
  String? _open;

  /// The card of the part being walked, and the stop it was last scrolled
  /// into view for.
  final _current = GlobalKey();
  String? _revealed;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final journey = await Journey.load();
    final progress = await JourneyProgress.load();
    if (!mounted) return;
    setState(() {
      _journey = journey;
      _progress = progress;
    });
  }

  Future<void> _choose(JourneyLevel level) async {
    final progress = _progress!;
    setState(() => progress.level = level);
    await progress.save();
  }

  Future<void> _changeLevel() async {
    final level = await Navigator.of(context).push<JourneyLevel>(
      MaterialPageRoute(
        builder: (context) => JourneyLevels(
          chosen: _progress!.level,
          onStart: (level) => Navigator.of(context).pop(level),
        ),
      ),
    );
    if (level != null) await _choose(level);
  }

  Future<void> _play(JourneyStop stop) async {
    JourneyStop? next = stop;
    while (next != null && mounted) {
      final journey = _journey!;
      final progress = _progress!;
      final playing = next;
      final after = await Navigator.of(context).push<JourneyAfter>(
        MaterialPageRoute(
          builder: (context) => JourneyStopScreen(
            journey: journey,
            progress: progress,
            stop: playing,
          ),
        ),
      );
      if (!mounted) return;
      setState(() => _open = null);
      next = after == JourneyAfter.next
          ? _journey!.next(_progress!.done)
          : null;
    }
  }

  /// Brings the part being walked into view when the next stop changes.
  void _reveal(JourneyStop? next) {
    if (next?.id == _revealed) return;
    _revealed = next?.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final card = _current.currentContext;
      if (card == null || !mounted) return;
      Scrollable.ensureVisible(
        card,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final journey = _journey;
    final progress = _progress;
    if (journey == null || progress == null) {
      return const JScreen(
        child: Center(child: CircularProgressIndicator(color: J.ink)),
      );
    }
    final level = progress.level;
    if (level == null) return JourneyLevels(onStart: _choose);
    final t = JText(level.isArabic);
    final next = journey.next(progress.done);
    final found = journey.found(progress.done);
    _reveal(next);
    // Side by side when they fit, the title above the level when text is large.
    final header = Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Text(t.title, style: J.text(26, weight: 800, height: 1.1)),
        IntrinsicWidth(
          child: JButton(
            onTap: _changeLevel,
            color: J.white,
            radius: 22,
            depth: 0,
            minHeight: 44,
            label: t.pick('Change level', 'تغيير المستوى'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.swap_horiz_rounded, size: 20, color: J.ink),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    levelName(level, t),
                    style: J.text(15, weight: 700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    final strip = JCard(
      depth: 0,
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.pick('Keepsakes', 'التذكارات'),
                  style: J.text(15, weight: 800, height: 1.2),
                ),
                Text(
                  t.pick(
                    'One from each story.\n${found.length} of 4 found.',
                    'تذكار من كل قصة.\nوجدت ${t.number(found.length)} من ${t.number(4)}.',
                  ),
                  style: J.text(
                    13,
                    color: J.muted,
                    height: t.arabic ? 1.45 : 1.25,
                  ),
                ),
              ],
            ),
          ),
          for (final keepsake in journey.keepsakes) ...[
            const SizedBox(width: 4),
            KeepsakeBadge(
              id: keepsake.id,
              found: found.contains(keepsake),
              label: keepsakeLabel(keepsake, found.contains(keepsake), t),
            ),
          ],
        ],
      ),
    );
    // The title and the keepsakes stay in place while the parts scroll. On a
    // short screen, or with large text, they scroll too, so the parts keep
    // room of their own.
    final media = MediaQuery.of(context);
    final pinned = media.size.height >= 600 && media.textScaler.scale(10) <= 13;
    final top = [
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: header),
      const SizedBox(height: 10),
      strip,
      const SizedBox(height: 10),
    ];
    return JScreen(
      arabic: t.arabic,
      bottom: false,
      child: Column(
        children: [
          if (pinned)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: top,
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!pinned) ...top,
                  for (final section in journey.sections) ...[
                    _section(journey, progress, section, next, t),
                    const SizedBox(height: 6),
                  ],
                  if (next == null)
                    JCard(
                      color: J.tealSoft,
                      child: Text(
                        t.pick(
                          'You have walked the whole surah. Open any part to play its stops again.',
                          'أتممت السورة كلها. افتح أي جزء لتعيد محطاته.',
                        ),
                        style: J.text(15.5, weight: 600, height: 1.4),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (next != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: JButton(
                onTap: () => _play(next),
                minHeight: 60,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      progress.done.isEmpty
                          ? t.pick('Start: ${next.en}', 'ابدأ: ${next.ar}')
                          : t.pick('Continue: ${next.en}', 'تابع: ${next.ar}'),
                      textAlign: TextAlign.center,
                      style: J.text(20, weight: 800, height: 1.2),
                    ),
                    Text(
                      t.ayahs(next.first, next.last),
                      style: J.text(13.5, weight: 600, height: 1.2),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(
    Journey journey,
    JourneyProgress progress,
    JourneySection section,
    JourneyStop? next,
    JText t,
  ) {
    final done = journey.sectionDone(section, progress.done);
    final current = next != null && section.stops.contains(next);
    final count = section.stops.length;
    final range = t.ayahs(section.first, section.last);
    final story = section.number == null
        ? null
        : t.pick(
            'STORY ${section.number} OF 4',
            'القصة ${t.number(section.number!)} من ${t.number(4)}',
          );
    if (current || _open == section.id) {
      final keepsake = section.keepsake;
      final goal = done
          ? t.lanternsLit(count)
          : keepsake != null
          ? t.pick(
              'Light ${t.lanterns(count)} to find ${keepsake.en}.',
              'أضئ ${t.lanterns(count)} لتجد ${keepsake.ar}.',
            )
          : t.pick(
              'Light ${t.lanterns(count)} to go on.',
              'أضئ ${t.lanterns(count)} لتواصل الطريق.',
            );
      return JCard(
        key: current ? _current : null,
        color: J.navy,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: current ? null : () => setState(() => _open = null),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          story ?? t.pick('ON THE WAY', 'في الطريق'),
                          style: J.text(
                            13,
                            weight: 700,
                            color: const Color(0xFFD7DEFF),
                            spacing: t.arabic ? null : 1,
                          ),
                        ),
                        Text(
                          section.title(t.arabic),
                          style: J.text(
                            26,
                            weight: 800,
                            color: J.white,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$range. $goal',
                          style: J.text(14, color: J.lilacText, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SectionMark(art: section.art),
                ],
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, box) {
                final width = (box.maxWidth - 16) / 3;
                return Wrap(
                  spacing: 8,
                  runSpacing: 12,
                  children: [
                    for (var i = 0; i < count; i++)
                      SizedBox(
                        width: width,
                        child: _stop(
                          journey,
                          progress,
                          section.stops[i],
                          i + 1,
                          t,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    }
    final before = journey.sections.indexOf(section) == 0
        ? null
        : journey.sections[journey.sections.indexOf(section) - 1];
    final line = done
        ? '$range. ${t.lanternsLit(count)}'
        : t.pick(
            '$range. Opens after ${before?.en}.',
            '$range. تُفتح بعد «${before?.ar}».',
          );
    return JButton(
      onTap: done ? () => setState(() => _open = section.id) : null,
      fadeWhenOff: false,
      color: done
          ? J.sunPale
          : section.isStory
          ? J.leaf
          : J.white,
      radius: 22,
      minHeight: 64,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (story != null)
                  Text(
                    story,
                    style: J.text(
                      13,
                      weight: 700,
                      spacing: t.arabic ? null : 1,
                    ),
                  ),
                Text(
                  section.title(t.arabic),
                  style: J.text(19, weight: 800, height: 1.25),
                ),
                Text(line, style: J.text(14, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!done)
            LockMark(label: t.pick('Locked', 'مقفلة'))
          else if (section.keepsake != null)
            KeepsakeBadge(
              id: section.keepsake!.id,
              found: true,
              size: 44,
              label: keepsakeLabel(section.keepsake!, true, t),
            )
          else
            for (var i = 0; i < count && i < 3; i++)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4),
                child: Lantern(
                  state: LanternState.lit,
                  size: count > 2 ? 32 : 40,
                ),
              ),
        ],
      ),
    );
  }

  Widget _stop(
    Journey journey,
    JourneyProgress progress,
    JourneyStop stop,
    int number,
    JText t,
  ) {
    final lit = progress.done.contains(stop.id);
    final open = journey.isOpen(stop, progress.done);
    final state = lit
        ? LanternState.lit
        : open
        ? LanternState.open
        : LanternState.locked;
    return Semantics(
      button: open,
      label:
          '${stop.title(t.arabic)}, ${t.ayahs(stop.first, stop.last)}, ${switch (state) {
            LanternState.lit => t.pick('lantern lit', 'الفانوس مضاء'),
            LanternState.open => t.pick('ready to play', 'جاهزة للعب'),
            LanternState.locked => t.pick('not open yet', 'لم تُفتح بعد'),
          }}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: open ? () => _play(stop) : null,
        child: Column(
          children: [
            Lantern(state: state, number: t.number(number)),
            const SizedBox(height: 4),
            Text(
              stop.title(t.arabic),
              textAlign: TextAlign.center,
              style: J.text(
                13.5,
                weight: open ? 800 : 700,
                color: J.white,
                height: 1.2,
              ),
            ),
            Text(
              stop.first == stop.last
                  ? t.number(stop.first)
                  : t.pick(
                      '${stop.first} to ${stop.last}',
                      '${t.number(stop.first)} إلى ${t.number(stop.last)}',
                    ),
              style: J.text(12.5, color: J.lilacText, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

String levelName(JourneyLevel level, JText t) => switch (level) {
  JourneyLevel.english => 'English',
  JourneyLevel.arabic => t.pick('Arabic', 'العربية'),
  JourneyLevel.strong => t.pick('Arabic, strong', 'العربية، متمكّن'),
};

String keepsakeLabel(JourneyKeepsake keepsake, bool found, JText t) =>
    t.keepsake(keepsake.en, keepsake.ar, found: found);

/// The first screen: how do you want to play?
class JourneyLevels extends StatefulWidget {
  const JourneyLevels({super.key, required this.onStart, this.chosen});

  final JourneyLevel? chosen;
  final ValueChanged<JourneyLevel> onStart;

  @override
  State<JourneyLevels> createState() => _JourneyLevelsState();
}

class _JourneyLevelsState extends State<JourneyLevels> {
  late JourneyLevel _level = widget.chosen ?? JourneyLevel.english;

  @override
  Widget build(BuildContext context) {
    return JScreen(
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const JourneyScene(art: 'hero', height: 118, framed: false),
                    const SizedBox(height: 12),
                    Text(
                      'AL-KAHF JOURNEY',
                      style: J.text(
                        13,
                        weight: 700,
                        color: J.label,
                        spacing: 1.2,
                      ),
                    ),
                    Text(
                      'How do you want to play?',
                      style: J.text(30, weight: 800, height: 1.15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Every level asks about whole ayahs. You can change it any time.',
                      style: J.text(15, color: J.muted, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    _choice(
                      JourneyLevel.english,
                      'Aa',
                      J.white,
                      'English',
                      "I don't read Arabic",
                      'The story and the questions in English. See and hear every ayah.',
                    ),
                    const SizedBox(height: 9),
                    _choice(
                      JourneyLevel.arabic,
                      'ع',
                      J.tealPale,
                      'Arabic',
                      'I read Arabic',
                      'تُعرض الآية، وتختار معناها.',
                      arabic: true,
                    ),
                    const SizedBox(height: 9),
                    _choice(
                      JourneyLevel.strong,
                      'ع',
                      J.lilacPale,
                      'Arabic, strong',
                      'I understand the ayahs',
                      'يُعطى المعنى، وتختار الآية. بلا تلميح.',
                      arabic: true,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.mic_none_rounded,
                          size: 22,
                          color: J.ink,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Reciting the next ayah is open in every level.',
                            style: J.text(14, color: J.muted, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const SizedBox(height: 14),
                    JButton.text(
                      widget.chosen == null
                          ? 'Start the journey'
                          : 'Play at this level',
                      color: J.teal,
                      onTap: () => widget.onStart(_level),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _choice(
    JourneyLevel level,
    String mark,
    Color markColor,
    String title,
    String who,
    String what, {
    bool arabic = false,
  }) {
    final chosen = _level == level;
    return Semantics(
      selected: chosen,
      child: JButton(
        onTap: () => setState(() => _level = level),
        color: chosen ? J.sunSoft : J.white,
        radius: 22,
        minHeight: 88,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: markColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: J.ink, width: 2.5),
              ),
              child: Text(
                mark,
                style: J.text(arabic ? 26 : 22, weight: 800, height: 1.1),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: J.text(20, weight: 800, height: 1.2)),
                  Text(who, style: J.text(14, weight: 600, height: 1.3)),
                  Text(
                    what,
                    textDirection: arabic
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    style: J.text(
                      arabic ? 15 : 13.5,
                      color: const Color(0xFF33415A),
                      height: arabic ? 1.4 : 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (chosen) ...[
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: J.ink,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: J.sunSoft,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

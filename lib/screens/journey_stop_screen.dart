import 'dart:math';

import 'package:flutter/material.dart';

import '../models/journey.dart';
import '../services/journey_audio.dart';
import '../services/journey_progress.dart';
import '../services/journey_round.dart';
import '../widgets/journey_art.dart';
import '../widgets/journey_reading.dart';
import '../widgets/journey_ui.dart';
import 'journey_keepsake_screen.dart';
import 'journey_recite_screen.dart';
import 'journey_sources_screen.dart';

/// Where the player goes when a stop closes.
enum JourneyAfter { map, next }

enum _Phase { read, round, done }

/// One stop of the journey: its ayahs to read, its questions, its lantern.
class JourneyStopScreen extends StatefulWidget {
  const JourneyStopScreen({
    super.key,
    required this.journey,
    required this.progress,
    required this.stop,
    this.random,
  });

  final Journey journey;
  final JourneyProgress progress;
  final JourneyStop stop;
  final Random? random;

  @override
  State<JourneyStopScreen> createState() => _JourneyStopScreenState();
}

class _JourneyStopScreenState extends State<JourneyStopScreen> {
  late final JourneyLevel _level =
      widget.progress.level ?? JourneyLevel.english;
  late final JText t = JText(_level.isArabic);
  late final JourneySection _section = widget.journey.sectionOf(widget.stop);

  /// What is still to be answered right, the one being asked first.
  late final List<RoundItem> _queue = JourneyRounds.build(
    widget.journey,
    widget.stop,
    _level,
    random: widget.random,
    missed: widget.progress.missed,
  );
  late final int _total = _queue.length;

  var _phase = _Phase.read;
  int _right = 0;
  int? _picked;

  /// The keepsake this stop has just won, if it closed a story.
  JourneyKeepsake? _won;

  /// The card shown under an answer, and the page it is scrolled into.
  final _answer = GlobalKey();
  final _scroll = ScrollController();

  Journey get journey => widget.journey;
  JourneyStop get stop => widget.stop;

  @override
  void dispose() {
    JourneyAudio.stop();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _listen(String key, List<int> ayahs) async {
    final ok = await JourneyAudio.toggle(key, ayahs);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.pick(
              'The recitation could not load. Check your connection.',
              'تعذّر تحميل التلاوة. تحقّق من الاتصال.',
            ),
          ),
        ),
      );
    }
  }

  void _pick(int choice) {
    if (_picked != null) return;
    final item = _queue.first;
    widget.progress.answered(item.ayah, right: choice == item.correct);
    setState(() => _picked = choice);
    // Whole ayahs and whole tafsir texts can run past the screen: bring what
    // follows the answer, and its button, into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final card = _answer.currentContext;
      if (card == null || !mounted) return;
      Scrollable.ensureVisible(
        card,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  Future<void> _next() async {
    final item = _queue.removeAt(0);
    final wasRight = _picked == item.correct;
    if (wasRight) {
      _right++;
    } else {
      // It comes back after the others, until it is answered right.
      _queue.add(item);
    }
    await JourneyAudio.stop();
    // What comes next is read from its top.
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (_queue.isNotEmpty) {
      setState(() => _picked = null);
      return;
    }
    final progress = widget.progress;
    final before = journey.sectionDone(_section, progress.done);
    progress.done.add(stop.id);
    await progress.save();
    if (!mounted) return;
    setState(() {
      _picked = null;
      _won = !before && journey.sectionDone(_section, progress.done)
          ? _section.keepsake
          : null;
      _phase = _Phase.done;
    });
  }

  Future<void> _leave() async {
    if (_phase != _Phase.round) {
      Navigator.of(context).pop(JourneyAfter.map);
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: t.arabic ? TextDirection.rtl : TextDirection.ltr,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: JCard(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.pick('Leave this stop?', 'الخروج من المحطة؟'),
                  style: J.text(22, weight: 800, height: 1.25),
                ),
                const SizedBox(height: 4),
                Text(
                  t.pick(
                    'Your answers here are not kept. The lantern stays as it is.',
                    'لن تُحفظ إجاباتك هنا، ويبقى الفانوس كما هو.',
                  ),
                  style: J.text(15.5, color: J.muted, height: 1.4),
                ),
                const SizedBox(height: 14),
                JButton.text(
                  t.pick('Stay', 'البقاء'),
                  minHeight: 52,
                  size: 18,
                  onTap: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(height: 6),
                JButton.text(
                  t.pick('Leave', 'الخروج'),
                  color: J.white,
                  minHeight: 48,
                  size: 17,
                  weight: 700,
                  depth: 0,
                  onTap: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop(JourneyAfter.map);
  }

  Future<void> _recite() async {
    await JourneyAudio.stop();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => JourneyReciteScreen(
          journey: journey,
          progress: widget.progress,
          stop: stop,
          arabic: t.arabic,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _showKeepsake() async {
    final after = await Navigator.of(context).push<JourneyAfter>(
      MaterialPageRoute(
        builder: (context) => JourneyKeepsakeScreen(
          journey: journey,
          progress: widget.progress,
          section: _section,
          arabic: t.arabic,
        ),
      ),
    );
    if (mounted) Navigator.of(context).pop(after ?? JourneyAfter.map);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase != _Phase.round,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _leave();
      },
      child: JScreen(
        arabic: t.arabic,
        child: switch (_phase) {
          _Phase.read => _read(),
          _Phase.round => _round(),
          _Phase.done => _done(),
        },
      ),
    );
  }

  Widget _page(List<Widget> children) =>
      JPage(controller: _scroll, children: children);

  Future<void> _sources() async {
    await JourneyAudio.stop();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) =>
            JourneySourcesScreen(journey: journey, arabic: t.arabic),
      ),
    );
  }

  /// What the stop reads before it asks: at the English level every ayah
  /// with its translation, at the Arabic levels every passage with its tafsir.
  List<JourneyPassage> get _reading => t.arabic
      ? journey.passagesOf(stop)
      : [for (final ayah in stop.ayahs) JourneyPassage(ayah, ayah)];

  Widget _read() {
    final index = _section.stops.indexOf(stop) + 1;
    final count = _section.stops.length;
    final top = [
      Row(
        children: [
          JRound(
            icon: t.arabic
                ? Icons.arrow_forward_ios_rounded
                : Icons.arrow_back_ios_new_rounded,
            label: t.pick('Back to the map', 'العودة إلى الخريطة'),
            onTap: _leave,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.arabic
                      ? _section.full(true)
                      : _section.full(false).toUpperCase(),
                  style: J.text(
                    13,
                    weight: 700,
                    color: J.label,
                    spacing: t.arabic ? null : 1,
                  ),
                ),
                Text(
                  t.pick(
                    'Stop $index of $count',
                    'المحطة ${t.number(index)} من ${t.number(count)}',
                  ),
                  style: J.text(15, weight: 700, height: 1.2),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      JourneyScene(art: _section.art, height: 132),
      const SizedBox(height: 10),
      Text(
        stop.title(t.arabic),
        style: J.text(30, weight: 800, height: t.arabic ? 1.35 : 1.15),
      ),
      const SizedBox(height: 4),
      Text(
        t.pick(
          'Read the ayahs and what they mean. Then answer.',
          'اقرأ الآيات وتفسيرها، ثم أجب.',
        ),
        style: J.text(16, color: J.muted, height: t.arabic ? 1.6 : 1.4),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          JChip(t.ayahs(stop.first, stop.last)),
          JChip(t.questions(_total)),
          JChip(t.pick('Then recite', 'ثم التلاوة')),
        ],
      ),
      const SizedBox(height: 12),
      ValueListenableBuilder(
        valueListenable: JourneyAudio.playing,
        builder: (context, playing, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final passage in _reading) ...[
              JourneyRead(
                journey: journey,
                passage: passage,
                arabic: t.arabic,
                playing: playing == 'ayah-${passage.first}',
                onListen: () =>
                    _listen('ayah-${passage.first}', passage.ayahs.toList()),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
      JourneySourceLine(t.meaningSource, onTap: _sources, more: t.sources),
    ];
    final bottom = [
      ValueListenableBuilder(
        valueListenable: JourneyAudio.playing,
        builder: (context, playing, _) {
          final on = playing == 'stop';
          return JButton.text(
            on
                ? t.pick('Stop listening', 'إيقاف الاستماع')
                : t.pick('Listen to the ayahs', 'استمع إلى الآيات'),
            color: J.white,
            minHeight: 50,
            size: 17,
            weight: 700,
            icon: Icon(
              on ? Icons.stop_rounded : Icons.play_arrow_rounded,
              color: J.ink,
              size: 24,
            ),
            onTap: () => _listen('stop', stop.ayahs.toList()),
          );
        },
      ),
      const SizedBox(height: 6),
      JButton.text(
        t.pick('Begin', 'ابدأ'),
        onTap: () {
          JourneyAudio.stop();
          if (_scroll.hasClients) _scroll.jumpTo(0);
          setState(() => _phase = _Phase.round);
        },
      ),
    ];
    // The two buttons stay in reach while the ayahs scroll. On a short
    // screen, or with large text, they scroll too and leave the room to read.
    final media = MediaQuery.of(context);
    final pinned = media.size.height >= 600 && media.textScaler.scale(10) <= 13;
    if (!pinned) {
      return _page([...top, const SizedBox(height: 8), ...bottom]);
    }
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: top,
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: J.bg,
            border: Border(top: BorderSide(color: J.ink, width: 2)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: bottom,
          ),
        ),
      ],
    );
  }

  Widget _round() {
    final item = _queue.first;
    final picked = _picked;
    final answered = picked != null;
    final wasRight = picked == item.correct;
    final last = _queue.length == 1 && (answered ? wasRight : true);
    final hasWords = item.passage.ayahs.any(
      (ayah) => (journey.words[ayah] ?? const []).isNotEmpty,
    );
    return _page([
      Row(
        children: [
          JRound(
            icon: Icons.close_rounded,
            label: t.pick('Leave this stop', 'الخروج من المحطة'),
            onTap: _leave,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              label: t.pick(
                'Question ${_right + 1} of $_total',
                'السؤال ${t.number(_right + 1)} من ${t.number(_total)}',
              ),
              child: JSegments(count: _total, done: _right),
            ),
          ),
          const SizedBox(width: 12),
          ExcludeSemantics(
            child: Text(
              t.ofCount(min(_right + 1, _total), _total),
              style: J.text(15.5, weight: 700),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (_level == JourneyLevel.strong)
        JCard(
          color: J.sunCream,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'التفسير الميسر',
                style: J.text(
                  14.5,
                  weight: 700,
                  color: const Color(0xFF2B3F66),
                ),
              ),
              Text(item.prompt, style: J.text(17.5, weight: 600, height: 1.7)),
            ],
          ),
        )
      else
        _ayahCard(item.passage),
      const SizedBox(height: 8),
      Text(
        switch (_level) {
          JourneyLevel.english => item.prompt,
          JourneyLevel.arabic =>
            item.passage.isOne
                ? 'اختر تفسير هذه الآية'
                : 'اختر تفسير هذه الآيات',
          JourneyLevel.strong => 'ما الذي يفسّره هذا النص؟',
        },
        style: J.text(
          t.arabic ? 24 : 22,
          weight: 800,
          height: t.arabic ? 1.4 : 1.25,
        ),
      ),
      const SizedBox(height: 10),
      for (var i = 0; i < item.choices.length; i++) ...[
        _choice(item, i),
        const SizedBox(height: 6),
      ],
      if (_level == JourneyLevel.arabic)
        Text(
          'النصوص الثلاثة من ${t.meaningSource}.',
          style: J.text(13.5, weight: 600, color: J.label, height: 1.5),
        ),
      const Spacer(),
      const SizedBox(height: 8),
      if (answered)
        JCard(
          key: _answer,
          depth: 0,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                wasRight
                    ? t.pick("That's it.", 'أحسنت.')
                    : t.pick('Not quite.', 'ليس هذا المطلوب.'),
                style: J.text(
                  17,
                  weight: 800,
                  color: wasRight ? J.right : J.wrong,
                ),
              ),
              if (_level == JourneyLevel.english) ...[
                // What the ayah means, in the translation's own words.
                JourneyMeaning(
                  journey: journey,
                  ayah: item.ayah,
                  arabic: false,
                  size: 15,
                ),
                const SizedBox(height: 4),
                JourneySourceLine('Saheeh International, Al-Kahf ${item.ayah}'),
              ] else
                Text(_explain(item, wasRight), style: J.text(15, height: 1.6)),
              const SizedBox(height: 10),
              JButton.text(
                last
                    ? t.pick('Light the lantern', 'أضئ الفانوس')
                    : t.pick('Next', 'التالي'),
                minHeight: 54,
                size: 19,
                onTap: _next,
              ),
            ],
          ),
        )
      else if (_level == JourneyLevel.arabic && hasWords) ...[
        JButton.text(
          'معاني الكلمات',
          color: J.tealPale,
          depth: 0,
          minHeight: 54,
          size: 18,
          weight: 700,
          icon: const Icon(Icons.menu_book_rounded, color: J.ink, size: 22),
          onTap: () => _words(item.passage),
        ),
        const SizedBox(height: 6),
        Text(
          'اختياري: معاني الكلمات الغريبة في الآية إن احتجت إليها.',
          textAlign: TextAlign.center,
          style: J.text(14.5, color: J.muted, height: 1.5),
        ),
      ] else if (_level == JourneyLevel.strong)
        Text(
          'هذا المستوى بلا تلميح: التفسير أمامك، والآية من حفظك وفهمك.',
          textAlign: TextAlign.center,
          style: J.text(14.5, color: J.muted, height: 1.5),
        ),
    ]);
  }

  String _explain(RoundItem item, bool wasRight) {
    final passage = item.passage;
    final where = passage.isOne
        ? 'الآية ${t.number(passage.first)}'
        : 'الآيات ${t.number(passage.first)} إلى ${t.number(passage.last)}';
    if (wasRight) {
      return _level == JourneyLevel.arabic
          ? 'هذا تفسير $where من سورة الكهف.'
          : 'هذا النص تفسير $where من سورة الكهف.';
    }
    return _level == JourneyLevel.arabic
        ? 'التفسير المطلوب مظلّل بالأخضر. ستعود هذه الآية في آخر المحطة.'
        : 'المطلوب مظلّل بالأخضر. سيعود هذا التفسير في آخر المحطة.';
  }

  /// What is asked about, whole, with a button to hear it.
  Widget _ayahCard(JourneyPassage passage) {
    final text = journey.passageText(passage);
    final size = JQuran.sizeFor(text) + (_level == JourneyLevel.arabic ? 2 : 0);
    return JCard(
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
              ValueListenableBuilder(
                valueListenable: JourneyAudio.playing,
                builder: (context, playing, _) => JRound(
                  icon: playing == 'ayah-${passage.first}'
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                  label: passage.isOne
                      ? t.pick('Listen to the ayah', 'استمع إلى الآية')
                      : t.pick('Listen to the ayahs', 'استمع إلى الآيات'),
                  color: J.lilacPale,
                  onTap: () =>
                      _listen('ayah-${passage.first}', passage.ayahs.toList()),
                ),
              ),
            ],
          ),
          JQuran(text, size: size),
        ],
      ),
    );
  }

  Widget _choice(RoundItem item, int index) {
    final picked = _picked;
    final answered = picked != null;
    final isRight = index == item.correct;
    final isPicked = index == picked;
    final strong = _level == JourneyLevel.strong;
    final Color color;
    final Color border;
    var depth = 4.0;
    Widget? mark;
    if (!answered) {
      color = J.white;
      border = J.ink;
    } else if (isRight) {
      color = J.tealSoft;
      border = J.ink;
      mark = _mark(Icons.check_rounded, J.right, t.pick('Correct', 'صحيح'));
    } else if (isPicked) {
      // A choice is an ayah, a scholar's text, or words of the translation.
      // None of them is ever crossed out: the one picked is only set apart,
      // and the right one is marked.
      color = J.panel;
      border = J.ink;
      depth = 0;
      final label = t.pick('Your pick', 'اختيارك');
      mark = Semantics(
        label: label,
        excludeSemantics: true,
        child: Text(label, style: J.text(13, weight: 700, color: J.muted)),
      );
    } else {
      color = J.white;
      border = J.grey;
      depth = 0;
    }
    final dim = answered && !isRight && !isPicked;
    final Widget text;
    if (strong) {
      text = JQuran(
        item.choices[index],
        size: JQuran.sizeFor(item.choices[index], largest: 21),
        height: 1.9,
        color: dim ? J.muted : J.ink,
      );
    } else if (t.arabic) {
      text = Text(
        item.choices[index],
        style: J.text(
          16.5,
          weight: 600,
          color: dim ? J.muted : J.ink,
          height: 1.65,
        ),
      );
    } else {
      text = Text(
        item.choices[index],
        style: J.text(
          16.5,
          weight: 700,
          color: dim ? J.muted : J.ink,
          height: 1.25,
        ),
      );
    }
    return JButton(
      onTap: answered ? null : () => _pick(index),
      fadeWhenOff: false,
      color: color,
      border: border,
      radius: strong ? 18 : 16,
      depth: depth,
      minHeight: t.arabic ? 58 : 52,
      padding: EdgeInsets.fromLTRB(14, 6, 14, t.arabic ? 8 : 6),
      alignment: strong ? Alignment.center : AlignmentDirectional.centerStart,
      child: _Solid(
        child: Row(
          children: [
            Expanded(child: text),
            if (mark != null) ...[const SizedBox(width: 10), mark],
          ],
        ),
      ),
    );
  }

  Widget _mark(IconData icon, Color color, String label) => Semantics(
    label: label,
    child: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, size: 20, color: J.white),
    ),
  );

  /// The harder words of what is shown, each as the mushaf writes it, with
  /// the meaning As-Siraj gives.
  void _words(JourneyPassage passage) {
    final ayahs = [
      for (final ayah in passage.ayahs)
        if ((journey.words[ayah] ?? const []).isNotEmpty) ayah,
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.86,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: JCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('معاني الكلمات', style: J.text(20, weight: 800)),
                    Text(
                      t.wordSource,
                      style: J.text(13.5, weight: 600, color: J.label),
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final ayah in ayahs) ...[
                              if (!passage.isOne)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    t.ayah(ayah),
                                    style: J.text(
                                      13.5,
                                      weight: 700,
                                      color: J.muted,
                                    ),
                                  ),
                                ),
                              for (final word in journey.words[ayah]!)
                                _wordRow(ayah, word),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    JButton.text(
                      'تم',
                      minHeight: 50,
                      size: 18,
                      onTap: () => Navigator.of(context).pop(),
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

  Widget _wordRow(int ayah, JourneyWord word) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
            decoration: BoxDecoration(
              color: J.sunCream,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: J.ink, width: 2),
            ),
            child: Text(
              journey.wordText(ayah, word),
              textAlign: TextAlign.center,
              style: J.quran(21, height: 1.8),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            word.meaning,
            style: J.text(17, weight: 600, height: 1.6),
          ),
        ),
      ],
    ),
  );

  Widget _done() {
    final next = journey.next(widget.progress.done);
    final won = _won;
    final recited = stop.ayahs
        .where((ayah) => (widget.progress.recited[ayah] ?? 0) >= 100)
        .length;
    return _page([
      const SizedBox(height: 8),
      const Center(child: LanternGlow()),
      const SizedBox(height: 10),
      Text(
        t.pick('Lantern lit', 'أُضيء الفانوس'),
        textAlign: TextAlign.center,
        style: J.text(32, weight: 800, height: 1.2),
      ),
      Text(
        '${stop.title(t.arabic)}${t.pick(', ', '، ')}${t.ayahs(stop.first, stop.last)}',
        textAlign: TextAlign.center,
        style: J.text(16.5, weight: 600, color: J.muted, height: 1.4),
      ),
      const SizedBox(height: 18),
      JCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.pick('Now recite them', 'والآن اتلُها'),
              style: J.text(19, weight: 800, height: 1.25),
            ),
            Text(
              recited > 0
                  ? t.pick(
                      'You have recited $recited of ${stop.ayahs.length} in full.',
                      'أتممت تلاوة ${t.number(recited)} من ${t.number(stop.ayahs.length)}.',
                    )
                  : t.pick(
                      'Say each ayah after the one before it. Your phone listens and marks the words it heard.',
                      'اتلُ كل آية بعد التي قبلها، وهاتفك يستمع ويعلّم الكلمات التي سمعها.',
                    ),
              style: J.text(15, color: J.muted, height: t.arabic ? 1.6 : 1.4),
            ),
            const SizedBox(height: 10),
            JButton.text(
              t.pick('Recite the ayahs', 'اتلُ الآيات'),
              color: J.white,
              minHeight: 54,
              size: 18,
              icon: const Icon(Icons.mic_rounded, color: J.ink, size: 24),
              onTap: _recite,
            ),
          ],
        ),
      ),
      const Spacer(),
      const SizedBox(height: 14),
      if (won != null)
        JButton.text(
          t.pick('See what you found', 'انظر ماذا وجدت'),
          onTap: _showKeepsake,
        )
      else if (next != null)
        JButton(
          onTap: () => Navigator.of(context).pop(JourneyAfter.next),
          minHeight: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.pick('Next stop: ${next.en}', 'المحطة التالية: ${next.ar}'),
                textAlign: TextAlign.center,
                style: J.text(19, weight: 800, height: 1.2),
              ),
              Text(
                t.ayahs(next.first, next.last),
                style: J.text(13.5, weight: 600, height: 1.2),
              ),
            ],
          ),
        )
      else
        JCard(
          color: J.tealSoft,
          depth: 0,
          child: Text(
            t.pick(
              'That was the last stop. You have walked the whole surah.',
              'كانت هذه آخر محطة. أتممت السورة كلها.',
            ),
            textAlign: TextAlign.center,
            style: J.text(16, weight: 700, height: 1.4),
          ),
        ),
      const SizedBox(height: 4),
      JButton.text(
        t.pick('Back to the map', 'العودة إلى الخريطة'),
        color: J.bg,
        depth: 0,
        minHeight: 48,
        size: 17,
        weight: 700,
        onTap: () => Navigator.of(context).pop(JourneyAfter.map),
      ),
    ]);
  }
}

/// Keeps a row at full width inside a button's aligned box.
class _Solid extends StatelessWidget {
  const _Solid({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: double.infinity, child: child);
}

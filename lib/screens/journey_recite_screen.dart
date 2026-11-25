import 'dart:async';

import 'package:flutter/material.dart';

import '../models/journey.dart';
import '../services/journey_audio.dart';
import '../services/journey_progress.dart';
import '../services/recitation.dart';
import '../widgets/journey_ui.dart';

enum _Step { idle, listening, checking, result }

/// Recite the next ayah. The player is given an ayah and says the one after
/// it; the phone listens and marks the words it heard.
class JourneyReciteScreen extends StatefulWidget {
  const JourneyReciteScreen({
    super.key,
    required this.journey,
    required this.progress,
    required this.stop,
    required this.arabic,
    this.listener,
    this.model,
  });

  final Journey journey;
  final JourneyProgress progress;
  final JourneyStop stop;
  final bool arabic;

  /// Stand in for the microphone and the listening model in tests.
  final RecitationListener? listener;
  final RecitationModel? model;

  @override
  State<JourneyReciteScreen> createState() => _JourneyReciteScreenState();
}

class _JourneyReciteScreenState extends State<JourneyReciteScreen> {
  late final JText t = JText(widget.arabic);
  late final RecitationModel _model = widget.model ?? RecitationModel.instance;
  late final RecitationListener _listener =
      widget.listener ?? RecitationListener(model: _model);
  late final List<int> _ayahs = widget.stop.ayahs.toList();

  int _at = 0;
  var _step = _Step.idle;

  /// Whether the ayah to recite is shown before it is recited.
  bool _shown = false;
  bool _starting = false;
  RecitationMatch? _match;
  RecitationProblem? _problem;

  /// Whether the listening model is on the phone. Null until that is known.
  bool? _ready;

  /// The share of the model fetched so far, while it is being fetched.
  double? _fetching;
  bool _fetchFailed = false;

  double _level = 0;
  Timer? _meter;
  Timer? _limit;

  Journey get journey => widget.journey;
  int get _ayah => _ayahs[_at];
  List<String> get _words => journey.verse(_ayah).split(' ');

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _stopTimers();
    JourneyAudio.stop();
    _listener.cancel().whenComplete(_listener.dispose);
    super.dispose();
  }

  void _stopTimers() {
    _meter?.cancel();
    _limit?.cancel();
    _meter = null;
    _limit = null;
  }

  Future<void> _check() async {
    bool ready;
    try {
      ready = await _model.ready();
    } catch (_) {
      ready = false;
    }
    if (mounted) setState(() => _ready = ready);
  }

  Future<void> _fetch() async {
    if (_fetching != null) return;
    setState(() {
      _fetching = 0;
      _fetchFailed = false;
    });
    var failed = false;
    try {
      await _model.fetch(
        onProgress: (share) {
          // A whole percent at a time is often enough for the bar.
          if (!mounted || (share - (_fetching ?? 0)).abs() < 0.01) return;
          setState(() => _fetching = share.clamp(0.0, 1.0));
        },
      );
    } catch (_) {
      failed = true;
    }
    var ready = false;
    try {
      ready = await _model.ready();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _fetching = null;
      _ready = ready;
      _fetchFailed = failed || !ready;
      if (ready) _problem = null;
    });
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

  Future<void> _start() async {
    if (_starting || _step == _Step.listening || _step == _Step.checking) {
      return;
    }
    _starting = true;
    await JourneyAudio.stop();
    RecitationProblem? problem;
    try {
      await _listener.start();
    } on RecitationFailure catch (failure) {
      problem = failure.problem;
    } catch (_) {
      problem = RecitationProblem.failed;
    }
    _starting = false;
    if (!mounted) {
      if (problem == null) await _listener.cancel();
      return;
    }
    if (problem != null) {
      setState(() {
        _problem = problem;
        _step = _match == null ? _Step.idle : _Step.result;
        if (problem == RecitationProblem.noModel) _ready = false;
      });
      return;
    }
    setState(() {
      _problem = null;
      _match = null;
      _level = 0;
      _step = _Step.listening;
    });
    _meter = Timer.periodic(const Duration(milliseconds: 140), (_) async {
      final level = await _listener.level();
      if (mounted && _step == _Step.listening) setState(() => _level = level);
    });
    _limit = Timer(RecitationListener.longest, _finish);
  }

  Future<void> _finish() async {
    if (_step != _Step.listening) return;
    _stopTimers();
    setState(() => _step = _Step.checking);
    final ayah = _ayah;
    final words = _words;
    RecitationMatch? match;
    var problem = RecitationProblem.failed;
    try {
      match = matchRecitation(words, await _listener.finish());
      // A word made only of marks would have no place in the answer.
      if (match.total != words.length) match = null;
    } on RecitationFailure catch (failure) {
      problem = failure.problem;
    } catch (_) {}
    if (match != null &&
        widget.progress.recitedAyah(ayah, match.count, match.total)) {
      await widget.progress.save();
    }
    if (!mounted) return;
    setState(() {
      _match = match;
      _problem = match == null ? problem : null;
      _step = match == null ? _Step.idle : _Step.result;
    });
  }

  Future<void> _cancel() async {
    if (_step != _Step.listening) return;
    _stopTimers();
    setState(() => _step = _Step.idle);
    await _listener.cancel();
  }

  void _next() {
    JourneyAudio.stop();
    if (_at + 1 >= _ayahs.length) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _at++;
      _match = null;
      _problem = null;
      _step = _Step.idle;
    });
  }

  @override
  Widget build(BuildContext context) {
    final section = journey.sectionOf(widget.stop);
    final index = section.stops.indexOf(widget.stop) + 1;
    final ayah = _ayah;
    final given = ayah - 1;
    final busy = _step == _Step.listening || _step == _Step.checking;
    return JScreen(
      arabic: t.arabic,
      child: JPage(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        children: [
          Row(
            children: [
              JRound(
                icon: t.arabic
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.arrow_back_ios_new_rounded,
                label: t.pick('Back to the stop', 'العودة إلى المحطة'),
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.pick('RECITE', 'التلاوة'),
                      style: J.text(
                        13,
                        weight: 700,
                        color: J.label,
                        spacing: t.arabic ? null : 1,
                      ),
                    ),
                    Text(
                      t.pick(
                        '${section.en}, stop $index',
                        '${section.ar}، المحطة ${t.number(index)}',
                      ),
                      style: J.text(15, weight: 700, height: 1.2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                label: t.pick(
                  'Ayah ${_at + 1} of ${_ayahs.length} in this stop',
                  'الآية ${t.number(_at + 1)} من ${t.number(_ayahs.length)} في هذه المحطة',
                ),
                excludeSemantics: true,
                child: Text(
                  t.ofCount(_at + 1, _ayahs.length),
                  style: J.text(15.5, weight: 700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _given(given),
          const SizedBox(height: 12),
          Text(
            t.pick('Recite the next ayah', 'اتلُ الآية التالية'),
            style: J.text(24, weight: 800, height: t.arabic ? 1.4 : 1.2),
          ),
          const SizedBox(height: 10),
          _card(ayah, busy),
          const SizedBox(height: 10),
          _status(ayah),
          const Spacer(),
          const SizedBox(height: 14),
          if (_ready == false) _getListener() else _buttons(),
          const SizedBox(height: 10),
          Text(
            t.pick(
              'Listens on your phone, even offline. It checks the words, not tajweed.',
              'يستمع على هاتفك، حتى بلا اتصال. يفحص الكلمات، لا التجويد.',
            ),
            textAlign: TextAlign.center,
            style: J.text(13.5, color: J.muted, height: t.arabic ? 1.5 : 1.35),
          ),
        ],
      ),
    );
  }

  /// The ayah the player is given: the one before the ayah to recite.
  Widget _given(int given) {
    final text = given == 0 ? journey.basmalah : journey.verseEnding(given);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: BoxDecoration(
        color: J.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: J.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            given == 0
                ? t.pick('You are given the basmalah', 'أُعطيت البسملة')
                : t.pick(
                    'You are given ayah $given',
                    'أُعطيت الآية ${t.number(given)}',
                  ),
            style: J.text(13.5, weight: 700, color: const Color(0xFF2B3F66)),
          ),
          JQuran(text, size: 19, height: 1.9),
        ],
      ),
    );
  }

  /// The ayah to recite: hidden, shown, or marked word by word.
  Widget _card(int ayah, bool busy) {
    final words = _words;
    final match = _step == _Step.result ? _match : null;
    final hidden = match == null && !_shown;
    final size = words.length <= 16
        ? 25.0
        : words.length <= 24
        ? 22.5
        : words.length <= 32
        ? 20.5
        : 19.0;
    final missed = [
      if (match != null)
        for (var i = 0; i < words.length; i++)
          if (!match.heard[i]) words[i],
    ];
    final String spoken;
    if (hidden) {
      spoken = t.pick(
        'The ayah is hidden. ${t.wordCount(words.length)}.',
        'الآية مخفية. ${t.wordCount(words.length)}.',
      );
    } else if (missed.isEmpty) {
      spoken = journey.verse(ayah);
    } else {
      spoken =
          '${journey.verse(ayah)}. ${t.pick('Missed or unclear', 'فاتت أو لم تتضح')}: ${missed.join(t.pick(', ', '، '))}';
    }
    return JCard(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.ayah(ayah),
                  style: J.text(14.5, weight: 700, color: J.label),
                ),
              ),
              ValueListenableBuilder(
                valueListenable: JourneyAudio.playing,
                builder: (context, playing, _) => JRound(
                  icon: playing == 'recite-$ayah'
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                  label: t.pick('Listen to the ayah', 'استمع إلى الآية'),
                  color: J.lilacPale,
                  onTap: busy ? null : () => _listen('recite-$ayah', [ayah]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Semantics(
            label: spoken,
            textDirection: hidden && !t.arabic
                ? TextDirection.ltr
                : TextDirection.rtl,
            child: ExcludeSemantics(
              child: Wrap(
                textDirection: TextDirection.rtl,
                alignment: WrapAlignment.center,
                spacing: size * 0.28,
                children: [
                  for (var i = 0; i < words.length; i++)
                    _Word(
                      words[i],
                      size: size,
                      hidden: hidden,
                      missed: match != null && !match.heard[i],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (match != null)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 4,
              children: [
                _legend(J.ink, t.pick('Heard', 'سُمعت')),
                _legend(
                  J.wrong,
                  t.pick('Missed or unclear', 'فاتت أو لم تتضح'),
                ),
              ],
            )
          else
            JButton.text(
              _shown
                  ? t.pick('Hide the ayah', 'أخفِ الآية')
                  : t.pick('Show the ayah', 'أظهر الآية'),
              color: J.bg,
              depth: 0,
              minHeight: 44,
              size: 15.5,
              weight: 700,
              icon: Icon(
                _shown
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: J.ink,
                size: 20,
              ),
              onTap: () => setState(() => _shown = !_shown),
            ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(text, style: J.text(13.5, weight: 600)),
    ],
  );

  /// What is happening now, in a large line and a small one.
  Widget _status(int ayah) {
    final total = _words.length;
    final match = _match;
    final problem = _problem;
    Widget lines(String large, String small, {Color color = J.muted}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          large,
          style: J.text(26, weight: 800, height: t.arabic ? 1.4 : 1.2),
        ),
        Text(
          small,
          style: J.text(
            15,
            weight: color == J.muted ? 400 : 600,
            color: color,
            height: t.arabic ? 1.55 : 1.35,
          ),
        ),
      ],
    );
    switch (_step) {
      case _Step.listening:
        return Semantics(
          liveRegion: true,
          child: Row(
            children: [
              _ring(),
              const SizedBox(width: 12),
              Expanded(
                child: lines(
                  t.pick('Listening', 'جارٍ الاستماع'),
                  t.pick(
                    'Recite ayah $ayah, then tap Done.',
                    'اتلُ الآية ${t.number(ayah)} ثم اضغط «انتهيت».',
                  ),
                ),
              ),
            ],
          ),
        );
      case _Step.checking:
        return Semantics(
          liveRegion: true,
          child: lines(
            t.pick('Checking', 'جارٍ الفحص'),
            t.pick(
              'Matching what it heard with the ayah.',
              'يقارن ما سمعه بكلمات الآية.',
            ),
          ),
        );
      case _Step.result when match != null:
        final share = match.total == 0 ? 0.0 : match.count / match.total;
        return Semantics(
          liveRegion: true,
          child: lines(
            t.words(match.count, match.total),
            problem != null
                ? _problemText(problem)
                : match.complete
                ? t.pick(
                    'All of it. Well recited.',
                    'أتممتها كلها. أحسنت التلاوة.',
                  )
                : share >= 0.8
                ? t.pick(
                    'Close. Try once more for all of it.',
                    'قاربت. أعدها مرة لتتمّها كلها.',
                  )
                : share >= 0.4
                ? t.pick(
                    'A good start. Listen to it, then try again.',
                    'بداية طيبة. استمع إليها ثم أعد المحاولة.',
                  )
                : t.pick(
                    'It did not catch much. Recite closer to the phone, or listen first.',
                    'لم يُسمع منها إلا القليل. اقترب من الهاتف، أو استمع إليها أولًا.',
                  ),
            color: problem != null ? J.wrong : J.muted,
          ),
        );
      default:
        return Semantics(
          liveRegion: problem != null,
          child: lines(
            t.wordCount(total),
            problem != null && problem != RecitationProblem.noModel
                ? _problemText(problem)
                : t.pick(
                    'Say it from memory, or show the ayah and read it.',
                    'اتلُها من حفظك، أو أظهر الآية واقرأها.',
                  ),
            color: problem != null && problem != RecitationProblem.noModel
                ? J.wrong
                : J.muted,
          ),
        );
    }
  }

  String _problemText(RecitationProblem problem) => switch (problem) {
    RecitationProblem.noMicrophone => t.pick(
      "The microphone is off for this app. Allow it in your phone's settings, then try again.",
      'الميكروفون غير مسموح لهذا التطبيق. اسمح به من إعدادات الهاتف ثم أعد المحاولة.',
    ),
    RecitationProblem.tooShort => t.pick(
      'That was too short to hear. Recite the whole ayah, then tap Done.',
      'كانت قصيرة جدًّا. اتلُ الآية كاملة ثم اضغط «انتهيت».',
    ),
    RecitationProblem.noModel => t.pick(
      'The listener is not on this phone yet.',
      'المستمع ليس على هذا الهاتف بعد.',
    ),
    RecitationProblem.failed => t.pick(
      'It could not listen this time. Try again.',
      'تعذّر الاستماع هذه المرة. أعد المحاولة.',
    ),
  };

  /// A ring around the microphone that follows the reciter's voice.
  Widget _ring() => ExcludeSemantics(
    child: SizedBox.square(
      dimension: 66,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 44 + 22 * _level,
            height: 44 + 22 * _level,
            decoration: const BoxDecoration(
              color: J.sunPale,
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: J.sun,
              shape: BoxShape.circle,
              border: Border.all(color: J.ink, width: 2.5),
            ),
            child: const Icon(Icons.mic_rounded, size: 24, color: J.ink),
          ),
        ],
      ),
    ),
  );

  Widget _buttons() {
    final last = _at + 1 >= _ayahs.length;
    final mic = const Icon(Icons.mic_rounded, color: J.ink, size: 22);
    final (Widget first, Widget second) = switch (_step) {
      _Step.idle => (
        JButton.text(
          last ? t.pick('Finish', 'إنهاء') : t.pick('Skip', 'تخطَّ'),
          color: J.white,
          minHeight: 58,
          size: 17,
          onTap: _next,
        ),
        JButton.text(
          t.pick('Recite', 'اتلُ'),
          minHeight: 58,
          size: 17,
          icon: mic,
          onTap: _ready == true ? _start : null,
        ),
      ),
      _Step.listening || _Step.checking => (
        JButton.text(
          t.pick('Cancel', 'إلغاء'),
          color: J.white,
          minHeight: 58,
          size: 17,
          onTap: _step == _Step.listening ? _cancel : null,
        ),
        JButton.text(
          t.pick('Done', 'انتهيت'),
          minHeight: 58,
          size: 17,
          onTap: _step == _Step.listening ? _finish : null,
        ),
      ),
      _Step.result => (
        JButton.text(
          t.pick('Recite again', 'أعد التلاوة'),
          color: J.white,
          minHeight: 58,
          size: 17,
          icon: mic,
          onTap: _start,
        ),
        JButton.text(
          last
              ? t.pick('Finish', 'إنهاء')
              : t.pick('Next ayah', 'الآية التالية'),
          minHeight: 58,
          size: 17,
          onTap: _next,
        ),
      ),
    };
    return Row(
      children: [
        Expanded(child: first),
        const SizedBox(width: 12),
        Expanded(child: second),
      ],
    );
  }

  /// Shown until the listening model is on the phone.
  Widget _getListener() {
    final megabytes = (RecitationModel.bytes / 1000000).round();
    final fetching = _fetching;
    return JCard(
      color: J.sunCream,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.pick('Get the listener first', 'حمّل المستمع أولًا'),
            style: J.text(19, weight: 800, height: t.arabic ? 1.4 : 1.25),
          ),
          Text(
            t.pick(
              'A small model that hears Quran recitation, $megabytes MB. '
                  'It is fetched once and stays on your phone. After that '
                  'reciting works offline, and what you say never leaves the phone.',
              'نموذج صغير يسمع تلاوة القرآن، حجمه ${t.number(megabytes)} ميغابايت. '
                  'يُحمَّل مرة واحدة ويبقى على هاتفك، ثم تعمل التلاوة بلا اتصال، '
                  'ولا يخرج صوتك من الهاتف.',
            ),
            style: J.text(14.5, color: J.muted, height: t.arabic ? 1.6 : 1.4),
          ),
          const SizedBox(height: 10),
          if (fetching != null) ...[
            Semantics(
              label: t.pick('Fetching the listener', 'جارٍ تحميل المستمع'),
              value: '${(fetching * 100).round()}%',
              child: Container(
                height: 18,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: J.white,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: J.ink, width: 2),
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: fetching.clamp(0.0, 1.0),
                    heightFactor: 1,
                    child: const ColoredBox(color: J.teal),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            ExcludeSemantics(
              child: Text(
                t.pick(
                  'Fetching: ${(fetching * 100).round()}%',
                  'جارٍ التحميل: ${t.number((fetching * 100).round())}٪',
                ),
                textAlign: TextAlign.center,
                style: J.text(14.5, weight: 700),
              ),
            ),
          ] else
            JButton.text(
              t.pick(
                'Get the listener ($megabytes MB)',
                'حمّل المستمع (${t.number(megabytes)} ميغابايت)',
              ),
              minHeight: 54,
              size: 17.5,
              icon: const Icon(Icons.download_rounded, color: J.ink, size: 22),
              onTap: _fetch,
            ),
          if (_fetchFailed && fetching == null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                t.pick(
                  'It did not arrive. Check your connection and try again.',
                  'لم يكتمل التحميل. تحقّق من الاتصال وأعد المحاولة.',
                ),
                style: J.text(14.5, weight: 600, color: J.wrong, height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One word of the ayah to recite: a soft bar while it is hidden, and marked
/// with a dotted line when the phone did not hear it.
class _Word extends StatelessWidget {
  const _Word(
    this.word, {
    required this.size,
    required this.hidden,
    required this.missed,
  });

  final String word;
  final double size;
  final bool hidden;
  final bool missed;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      word,
      textDirection: TextDirection.rtl,
      style: J.quran(size, height: 2, color: missed ? J.wrong : J.ink),
    );
    if (hidden) {
      // The word keeps its place, so nothing moves when the ayah is shown.
      return Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: 0, child: text),
          Positioned.fill(
            child: Center(
              child: Container(
                height: size * 0.56,
                decoration: BoxDecoration(
                  color: J.panel,
                  borderRadius: BorderRadius.circular(size * 0.28),
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (!missed) return text;
    return Stack(
      children: [
        text,
        Positioned(
          left: 0,
          right: 0,
          bottom: size * 0.14,
          height: 3,
          child: const CustomPaint(painter: _DottedLine(J.wrong)),
        ),
      ],
    );
  }
}

class _DottedLine extends CustomPainter {
  const _DottedLine(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final radius = size.height / 2;
    for (var x = radius; x <= size.width - radius + 0.1; x += radius * 3.2) {
      canvas.drawCircle(Offset(x, radius), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_DottedLine old) => old.color != color;
}

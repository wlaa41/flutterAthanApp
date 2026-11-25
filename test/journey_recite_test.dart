import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pro/models/journey.dart';
import 'package:flutter_pro/screens/journey_recite_screen.dart';
import 'package:flutter_pro/services/journey_audio.dart';
import 'package:flutter_pro/services/journey_progress.dart';
import 'package:flutter_pro/services/recitation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'journey_support.dart';

/// Stands in for the listening model: on the phone or not, and how a fetch
/// goes.
class _Model implements RecitationModel {
  _Model({this.onPhone = true, this.fetchWorks = true});

  bool onPhone;
  bool fetchWorks;
  int fetches = 0;

  @override
  Future<Directory> directory() async => Directory.systemTemp;

  @override
  Future<bool> ready() async => onPhone;

  @override
  Future<void> fetch({void Function(double share)? onProgress}) async {
    fetches++;
    onProgress?.call(0.5);
    if (!fetchWorks) throw const SocketException('offline');
    onProgress?.call(1);
    onPhone = true;
  }
}

/// Stands in for the microphone and the model: it hears what it is told to.
class _Listener implements RecitationListener {
  String heard = '';
  RecitationProblem? startProblem;
  RecitationProblem? finishProblem;
  int started = 0;
  int cancelled = 0;
  bool disposed = false;

  @override
  Future<void> start() async {
    final problem = startProblem;
    if (problem != null) throw RecitationFailure(problem);
    started++;
  }

  @override
  Future<double> level() async => 0.5;

  @override
  Future<String> finish() async {
    final problem = finishProblem;
    if (problem != null) throw RecitationFailure(problem);
    return heard;
  }

  @override
  Future<void> cancel() async => cancelled++;

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  final journey = readJourney();
  JourneyStop stop(String id) => journey.stops.firstWhere((s) => s.id == id);
  String said(int ayah, {Set<int> without = const {}}) {
    final words = journey.verse(ayah).split(' ');
    return [
      for (var i = 0; i < words.length; i++)
        if (!without.contains(i)) recitationLetters(words[i]),
    ].join(' ');
  }

  setUpAll(loadJourneyFonts);
  setUp(() => JourneyAudio.player = (ayahs) async => true);
  tearDown(() {
    JourneyAudio.player = null;
    JourneyAudio.playing.value = null;
  });

  Future<void> open(
    WidgetTester tester, {
    required JourneyStop of,
    required JourneyProgress progress,
    required _Listener listener,
    required _Model model,
    bool arabic = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (context) => JourneyReciteScreen(
                      journey: journey,
                      progress: progress,
                      stop: of,
                      arabic: arabic,
                      listener: listener,
                      model: model,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'recite the next ayah: hidden until shown, heard words marked, best kept',
    (tester) async {
      final progress = JourneyProgress(level: JourneyLevel.english);
      final listener = _Listener();
      await open(
        tester,
        of: stop('cave-1'),
        progress: progress,
        listener: listener,
        model: _Model(),
      );
      expect(find.text('RECITE'), findsOneWidget);
      expect(find.text('The Cave, stop 1'), findsOneWidget);
      expect(find.text('1 of 4'), findsOneWidget);
      expect(find.text('You are given ayah 8'), findsOneWidget);
      expect(
        find.text(journey.verseWithMark(8), findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Recite the next ayah'), findsOneWidget);
      expect(find.text('Al-Kahf, ayah 9'), findsOneWidget);
      expect(
        find.text(
          'Listens on your phone, even offline. It checks the words, not tajweed.',
        ),
        findsOneWidget,
      );

      // The ayah to recite is kept back: a bar for each word, nothing read out.
      final words = journey.verse(9).split(' ');
      expect(words, hasLength(10));
      expect(find.text('10 words'), findsOneWidget);
      expect(
        find.bySemanticsLabel('The ayah is hidden. 10 words.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.text(words.first),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        0,
      );
      await tester.tap(find.text('Show the ayah'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(journey.verse(9)), findsOneWidget);
      await tester.tap(find.text('Hide the ayah'));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('The ayah is hidden. 10 words.'),
        findsOneWidget,
      );

      // Two words missed.
      await tester.tap(find.text('Recite'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(listener.started, 1);
      expect(find.text('Listening'), findsOneWidget);
      expect(find.text('Recite ayah 9, then tap Done.'), findsOneWidget);
      listener.heard = said(9, without: {2, 7});
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('8 of 10 words'), findsOneWidget);
      expect(find.text('Close. Try once more for all of it.'), findsOneWidget);
      expect(find.text('Heard'), findsOneWidget);
      expect(find.text('Missed or unclear'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          '${journey.verse(9)}. Missed or unclear: ${words[2]}, ${words[7]}',
        ),
        findsOneWidget,
      );
      expect(progress.recited[9], 80);

      // A worse try does not replace a better one.
      await tester.tap(find.text('Recite again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      listener.heard = said(9, without: {0, 1, 2, 3, 4, 5, 6});
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('3 of 10 words'), findsOneWidget);
      expect(
        find.text(
          'It did not catch much. Recite closer to the phone, or listen first.',
        ),
        findsOneWidget,
      );
      expect(progress.recited[9], 80);

      // All of it.
      await tester.tap(find.text('Recite again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      listener.heard = said(9);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('10 of 10 words'), findsOneWidget);
      expect(find.text('All of it. Well recited.'), findsOneWidget);
      expect(progress.recited[9], 100);
      final prefs = await SharedPreferences.getInstance();
      expect(
        JourneyProgress.decode(prefs.getString(JourneyProgress.key)).recited,
        {9: 100},
      );

      // On to the next: given the ayah just recited.
      await tester.tap(find.text('Next ayah'));
      await tester.pumpAndSettle();
      expect(find.text('2 of 4'), findsOneWidget);
      expect(find.text('You are given ayah 9'), findsOneWidget);
      expect(find.text('Al-Kahf, ayah 10'), findsOneWidget);
      expect(find.text('16 words'), findsOneWidget);

      // Cancelling a recitation checks nothing.
      await tester.tap(find.text('Recite'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(listener.cancelled, 1);
      expect(find.text('16 words'), findsOneWidget);
      expect(progress.recited.containsKey(10), isFalse);

      // Skip to the last ayah; there the way on is the way out.
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('4 of 4'), findsOneWidget);
      expect(find.text('Al-Kahf, ayah 12'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      expect(listener.disposed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the listener is fetched once, before the first recitation', (
    tester,
  ) async {
    final listener = _Listener();
    final model = _Model(onPhone: false, fetchWorks: false);
    await open(
      tester,
      of: stop('cave-1'),
      progress: JourneyProgress(level: JourneyLevel.english),
      listener: listener,
      model: model,
    );
    expect(find.text('Get the listener first'), findsOneWidget);
    expect(find.text('Recite'), findsNothing);
    expect(find.textContaining('19 MB. It is fetched once'), findsOneWidget);

    // Offline: it says so, and can be tried again.
    await tester.tap(find.text('Get the listener (19 MB)'));
    await tester.pumpAndSettle();
    expect(model.fetches, 1);
    expect(
      find.text('It did not arrive. Check your connection and try again.'),
      findsOneWidget,
    );
    expect(find.text('Recite'), findsNothing);

    model.fetchWorks = true;
    await tester.tap(find.text('Get the listener (19 MB)'));
    await tester.pumpAndSettle();
    expect(model.fetches, 2);
    expect(find.text('Get the listener first'), findsNothing);
    expect(find.text('Recite'), findsOneWidget);
    await tester.tap(find.text('Recite'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(listener.started, 1);
    expect(find.text('Listening'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back to the stop'));
    await tester.pumpAndSettle();
    expect(listener.cancelled, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('what goes wrong is said plainly, in the level\'s language', (
    tester,
  ) async {
    final listener = _Listener()..startProblem = RecitationProblem.noMicrophone;
    final progress = JourneyProgress(level: JourneyLevel.arabic);
    await open(
      tester,
      of: stop('opening-1'),
      progress: progress,
      listener: listener,
      model: _Model(),
      arabic: true,
    );
    // The first ayah of the surah follows the basmalah.
    expect(find.text('التلاوة'), findsOneWidget);
    expect(find.text('مطلع السورة، المحطة ١'), findsOneWidget);
    expect(find.text('أُعطيت البسملة'), findsOneWidget);
    expect(find.text(journey.basmalah, findRichText: true), findsOneWidget);
    expect(find.text('اتلُ الآية التالية'), findsOneWidget);
    expect(find.text('الكهف، الآية ١'), findsOneWidget);
    expect(find.text('١ من ٥'), findsOneWidget);
    expect(journey.verse(1).split(' '), hasLength(11));
    expect(find.text('١١ كلمة'), findsOneWidget);

    await tester.tap(find.text('اتلُ'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'الميكروفون غير مسموح لهذا التطبيق. اسمح به من إعدادات الهاتف ثم أعد المحاولة.',
      ),
      findsOneWidget,
    );
    expect(find.text('جارٍ الاستماع'), findsNothing);

    listener
      ..startProblem = null
      ..finishProblem = RecitationProblem.tooShort;
    await tester.tap(find.text('اتلُ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('جارٍ الاستماع'), findsOneWidget);
    await tester.tap(find.text('انتهيت'));
    await tester.pumpAndSettle();
    expect(
      find.text('كانت قصيرة جدًّا. اتلُ الآية كاملة ثم اضغط «انتهيت».'),
      findsOneWidget,
    );
    expect(progress.recited, isEmpty);

    listener
      ..finishProblem = null
      ..heard = said(1);
    await tester.tap(find.text('اتلُ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('انتهيت'));
    await tester.pumpAndSettle();
    expect(find.text('١١ من ١١ كلمة'), findsOneWidget);
    expect(find.text('أتممتها كلها. أحسنت التلاوة.'), findsOneWidget);
    expect(progress.recited[1], 100);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long ayah is cued by its ending, and large text still fits', (
    tester,
  ) async {
    final listener = _Listener();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: JourneyReciteScreen(
          journey: journey,
          progress: JourneyProgress(level: JourneyLevel.english),
          stop: stop('cave-4'),
          arabic: false,
          listener: listener,
          model: _Model(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Ayah 19 is given ayah 18 whole; ayah 20 is given the end of ayah 19.
    expect(find.text('You are given ayah 18'), findsOneWidget);
    await tester.ensureVisible(find.text('Skip'));
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    final ending = journey.verseEnding(19);
    expect(ending, startsWith('… '));
    expect(find.text(ending, findRichText: true), findsOneWidget);
    expect(find.text(journey.verseWithMark(19)), findsNothing);
    await tester.ensureVisible(find.text('Recite'));
    await tester.tap(find.text('Recite'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    listener.heard = said(20, without: {3});
    await tester.ensureVisible(find.text('Done'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('12 of 13 words'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

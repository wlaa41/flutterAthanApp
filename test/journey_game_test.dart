import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_pro/models/journey.dart';
import 'package:flutter_pro/screens/journey_keepsake_screen.dart';
import 'package:flutter_pro/screens/journey_screen.dart';
import 'package:flutter_pro/screens/journey_stop_screen.dart';
import 'package:flutter_pro/services/journey_audio.dart';
import 'package:flutter_pro/services/journey_progress.dart';
import 'package:flutter_pro/services/journey_round.dart';
import 'package:flutter_pro/widgets/journey_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'journey_support.dart';

/// Opens [screen] from a plain page and keeps what it was closed with.
class _Launcher extends StatelessWidget {
  const _Launcher(this.screen, this.closed);

  final Widget screen;
  final List<Object?> closed;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () async => closed.add(
          await Navigator.of(
            context,
          ).push<Object?>(MaterialPageRoute(builder: (context) => screen)),
        ),
        child: const Text('open'),
      ),
    ),
  );
}

void main() {
  final journey = readJourney();
  JourneyStop stop(String id) => journey.stops.firstWhere((s) => s.id == id);

  setUpAll(loadJourneyFonts);
  setUp(() {
    Journey.cached = journey;
    JourneyAudio.player = (ayahs) async => true;
  });
  tearDown(() {
    Journey.cached = null;
    JourneyAudio.player = null;
    JourneyAudio.playing.value = null;
  });

  void phone(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<Map<String, dynamic>> saved() async =>
      jsonDecode(
            (await SharedPreferences.getInstance()).getString(
              JourneyProgress.key,
            )!,
          )
          as Map<String, dynamic>;

  /// Opens a stop and answers its English questions, all right.
  Future<void> playThrough(
    WidgetTester tester,
    JourneyStop played,
    int seed,
  ) async {
    final round = JourneyRounds.build(
      journey,
      played,
      JourneyLevel.english,
      random: Random(seed),
    );
    await tester.tap(find.text('Begin'));
    await tester.pumpAndSettle();
    for (var i = 0; i < round.length; i++) {
      await tester.tap(find.text(round[i].choices[round[i].correct]));
      await tester.pumpAndSettle();
      expect(find.text("That's it."), findsOneWidget);
      await tester.tap(
        find.text(i == round.length - 1 ? 'Light the lantern' : 'Next'),
      );
      await tester.pumpAndSettle();
    }
  }

  testWidgets('the first screen asks how to play, and the choice is kept', (
    tester,
  ) async {
    phone(tester);
    // Scores of the game this one replaced are cleared away.
    SharedPreferences.setMockInitialValues({'quiz_progress_kahf': '{}'});
    await tester.pumpWidget(const MaterialApp(home: JourneyScreen()));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).containsKey('quiz_progress_kahf'),
      isFalse,
    );
    expect(find.text('How do you want to play?'), findsOneWidget);
    for (final level in ['English', 'Arabic', 'Arabic, strong']) {
      expect(find.text(level), findsOneWidget);
    }
    expect(
      find.text('Reciting the next ayah is open in every level.'),
      findsOneWidget,
    );
    expect(find.text('Al-Kahf Journey'), findsNothing);

    await tester.tap(find.text('Arabic, strong'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start the journey'));
    await tester.pumpAndSettle();
    expect(find.text('رحلة الكهف'), findsOneWidget);
    expect(find.text('ابدأ: ${journey.stops.first.ar}'), findsOneWidget);
    expect((await saved())['level'], JourneyLevel.strong.index);

    // The level can be changed from the map at any time.
    await tester.tap(find.bySemanticsLabel(RegExp('تغيير المستوى')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play at this level'));
    await tester.pumpAndSettle();
    expect(find.text('Al-Kahf Journey'), findsOneWidget);
    expect(find.text('Start: The straight Book'), findsOneWidget);
    expect((await saved())['level'], JourneyLevel.english.index);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the map shows what is lit and opens stops in order', (
    tester,
  ) async {
    phone(tester);
    SharedPreferences.setMockInitialValues({
      JourneyProgress.key: JourneyProgress(
        level: JourneyLevel.english,
        done: {'opening-1', 'opening-2', 'cave-1'},
      ).encode(),
    });
    await tester.pumpWidget(const MaterialApp(home: JourneyScreen()));
    await tester.pumpAndSettle();
    expect(find.text('One from each story.\n0 of 4 found.'), findsOneWidget);
    expect(find.text('Ayahs 1 to 8. Both lanterns lit.'), findsOneWidget);
    expect(find.text('STORY 1 OF 4'), findsOneWidget);
    expect(
      find.text('Ayahs 9 to 26. Light six lanterns to find the silver coin.'),
      findsOneWidget,
    );
    expect(find.text('Ayahs 27 to 31. Opens after The Cave.'), findsOneWidget);
    expect(find.text('Continue: Standing firm'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Standing firm, Ayahs 13 to 16, ready to play'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Awake, Ayahs 19 to 20, not open yet'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('the silver coin, not found yet'),
      findsOneWidget,
    );

    // A stop that is not open yet does not open.
    await tester.tap(find.text('Awake'));
    await tester.pumpAndSettle();
    expect(find.text('Begin'), findsNothing);

    // A lit stop can be played again.
    await tester.tap(find.text('Into the cave'));
    await tester.pumpAndSettle();
    expect(find.text('Stop 1 of 6'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back to the map'));
    await tester.pumpAndSettle();

    // The button at the bottom opens the next stop.
    await tester.tap(find.text('Continue: Standing firm'));
    await tester.pumpAndSettle();
    expect(find.text('Stop 2 of 6'), findsOneWidget);
    expect(find.text('Standing firm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a stop: its story, its questions, a wrong answer comes back, the lantern',
    (tester) async {
      phone(tester);
      SharedPreferences.setMockInitialValues({});
      final progress = JourneyProgress(
        level: JourneyLevel.english,
        done: {'opening-1', 'opening-2'},
      );
      final played = stop('cave-1');
      final closed = <Object?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: _Launcher(
            JourneyStopScreen(
              journey: journey,
              progress: progress,
              stop: played,
              random: Random(3),
            ),
            closed,
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('THE CAVE'), findsOneWidget);
      expect(find.text('Stop 1 of 6'), findsOneWidget);
      expect(find.text('Into the cave'), findsOneWidget);
      for (final paragraph in played.storyEn) {
        expect(find.text(paragraph), findsOneWidget);
      }
      for (final chip in ['Ayahs 9 to 12', '4 questions', 'Then recite']) {
        expect(find.text(chip), findsOneWidget);
      }

      // Listening can be started and stopped from the story.
      await tester.tap(find.text('Listen to the ayahs'));
      await tester.pumpAndSettle();
      expect(JourneyAudio.playing.value, isNull);

      final round = JourneyRounds.build(
        journey,
        played,
        JourneyLevel.english,
        random: Random(3),
      );
      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 4'), findsOneWidget);
      expect(find.text(round[0].prompt), findsOneWidget);
      expect(find.text('Al-Kahf, ayah ${round[0].ayah}'), findsOneWidget);
      expect(find.text(journey.verseWithMark(round[0].ayah)), findsOneWidget);

      // Wrong: it is said plainly, the right one is marked, and it returns.
      await tester.tap(find.text(round[0].choices[(round[0].correct + 1) % 3]));
      await tester.pumpAndSettle();
      expect(find.text('Not quite.'), findsOneWidget);
      expect(find.text(round[0].explain), findsOneWidget);
      // A screen reader hears the verdict with each choice.
      expect(
        tester
            .getSemantics(find.text(round[0].choices[round[0].correct]))
            .label,
        contains('Correct'),
      );
      expect(
        tester
            .getSemantics(
              find.text(round[0].choices[(round[0].correct + 1) % 3]),
            )
            .label,
        contains('Not this one'),
      );
      expect(progress.missed[round[0].ayah], 1);
      // A second tap changes nothing.
      await tester.tap(find.text(round[0].choices[round[0].correct]));
      await tester.pumpAndSettle();
      expect(find.text('Not quite.'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 4'), findsOneWidget);

      for (final item in round.skip(1)) {
        expect(find.text(item.prompt), findsOneWidget);
        await tester.tap(find.text(item.choices[item.correct]));
        await tester.pumpAndSettle();
        expect(find.text("That's it."), findsOneWidget);
        expect(find.text('Light the lantern'), findsNothing);
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      expect(progress.done, isNot(contains('cave-1')));

      // The missed question again, last.
      expect(find.text(round[0].prompt), findsOneWidget);
      expect(find.text('4 of 4'), findsOneWidget);
      await tester.tap(find.text(round[0].choices[round[0].correct]));
      await tester.pumpAndSettle();
      expect(progress.missed, isEmpty);
      await tester.tap(find.text('Light the lantern'));
      await tester.pumpAndSettle();

      expect(find.text('Lantern lit'), findsOneWidget);
      expect(find.text('Into the cave, Ayahs 9 to 12'), findsOneWidget);
      expect(find.text('Recite the ayahs'), findsOneWidget);
      expect(progress.done, contains('cave-1'));
      expect((await saved())['done'], contains('cave-1'));
      expect(find.text('See what you found'), findsNothing);
      await tester.tap(find.text('Next stop: Standing firm'));
      await tester.pumpAndSettle();
      expect(closed, [JourneyAfter.next]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('leaving in the middle of a stop asks first and lights nothing', (
    tester,
  ) async {
    phone(tester);
    SharedPreferences.setMockInitialValues({});
    final progress = JourneyProgress(level: JourneyLevel.english);
    final closed = <Object?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _Launcher(
          JourneyStopScreen(
            journey: journey,
            progress: progress,
            stop: stop('opening-1'),
            random: Random(5),
          ),
          closed,
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Begin'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Leave this stop'));
    await tester.pumpAndSettle();
    expect(find.text('Leave this stop?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 4'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Leave this stop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(closed, [JourneyAfter.map]);
    expect(progress.done, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Arabic: the ayah is shown, its meaning is chosen, word meanings are optional',
    (tester) async {
      phone(tester);
      SharedPreferences.setMockInitialValues({});
      final progress = JourneyProgress(level: JourneyLevel.arabic);
      final played = stop('cave-1');
      await tester.pumpWidget(
        MaterialApp(
          home: JourneyStopScreen(
            journey: journey,
            progress: progress,
            stop: played,
            random: Random(8),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('إلى الكهف'), findsOneWidget);
      for (final paragraph in played.storyAr) {
        expect(find.text(paragraph), findsOneWidget);
      }
      expect(find.text('الآيات ٩ إلى ١٢'), findsOneWidget);
      final round = JourneyRounds.build(
        journey,
        played,
        JourneyLevel.arabic,
        random: Random(8),
      );
      expect(find.text('٤ أسئلة'), findsOneWidget);
      await tester.tap(find.text('ابدأ'));
      await tester.pumpAndSettle();
      final item = round.first;
      expect(find.text('ما معنى هذه الآية؟'), findsOneWidget);
      expect(find.text('١ من ٤'), findsOneWidget);
      expect(find.text(journey.verseWithMark(item.ayah)), findsOneWidget);
      for (final choice in item.choices) {
        expect(find.text(choice), findsOneWidget);
      }
      expect(item.choices[item.correct], journey.meaning(item.ayah).ar);
      expect(
        find.text('اختياري: معاني الكلمات الصعبة في الآية إن احتجت إليها.'),
        findsOneWidget,
      );

      // The help is there for who wants it: the harder words of this ayah.
      final words = journey.words[item.ayah]!;
      await tester.tap(find.text('معاني الكلمات'));
      await tester.pumpAndSettle();
      for (final word in words) {
        expect(find.text(word.meaning), findsOneWidget);
        expect(
          find.text(
            journey.verseWords(item.ayah, word.word, word.word + word.span - 1),
          ),
          findsOneWidget,
        );
      }
      await tester.tap(find.text('تم'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(item.choices[item.correct]));
      await tester.pumpAndSettle();
      expect(find.text('أحسنت.'), findsOneWidget);
      // Once answered, the help makes way for the answer.
      expect(find.text('معاني الكلمات'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Arabic, strong: the meaning is given, the ayah is chosen, with no help',
    (tester) async {
      phone(tester);
      SharedPreferences.setMockInitialValues({});
      final progress = JourneyProgress(level: JourneyLevel.strong);
      final played = stop('cave-2');
      await tester.pumpWidget(
        MaterialApp(
          home: JourneyStopScreen(
            journey: journey,
            progress: progress,
            stop: played,
            random: Random(8),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final round = JourneyRounds.build(
        journey,
        played,
        JourneyLevel.strong,
        random: Random(8),
      );
      await tester.tap(find.text('ابدأ'));
      await tester.pumpAndSettle();
      final item = round.first;
      expect(find.text('أيّ آية تدلّ على هذا المعنى؟'), findsOneWidget);
      expect(find.text('المعنى'), findsOneWidget);
      expect(find.text(journey.meaning(item.ayah).ar), findsOneWidget);
      for (final choice in item.choices) {
        expect(find.text(choice, findRichText: true), findsOneWidget);
      }
      // The ayah being asked for is not named: it is one of the choices.
      expect(
        find.text('الكهف، الآية ${JText(true).number(item.ayah)}'),
        findsNothing,
      );
      expect(find.text('معاني الكلمات'), findsNothing);
      expect(
        find.text('هذا المستوى بلا تلميح: المعنى أمامك، والآية من فهمك.'),
        findsOneWidget,
      );

      await tester.tap(
        find.text(item.choices[(item.correct + 2) % 3], findRichText: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('ليس هذا.'), findsOneWidget);
      expect(
        tester
            .getSemantics(
              find.text(item.choices[item.correct], findRichText: true),
            )
            .label,
        contains('صحيح'),
      );
      expect(progress.missed[item.ayah], 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the last stop of a story gives its keepsake', (tester) async {
    phone(tester);
    SharedPreferences.setMockInitialValues({});
    final progress = JourneyProgress(
      level: JourneyLevel.english,
      done: {
        for (final s in journey.stops.takeWhile((s) => s.id != 'cave-6')) s.id,
      },
    );
    final closed = <Object?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _Launcher(
          JourneyStopScreen(
            journey: journey,
            progress: progress,
            stop: stop('cave-6'),
            random: Random(2),
          ),
          closed,
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await playThrough(tester, stop('cave-6'), 2);
    expect(find.text('Lantern lit'), findsOneWidget);
    expect(journey.found(progress.done).single.id, 'coin');
    await tester.tap(find.text('See what you found'));
    await tester.pumpAndSettle();

    expect(find.text('THE CAVE IS COMPLETE'), findsOneWidget);
    expect(find.text('You found the silver coin'), findsOneWidget);
    expect(find.text(journey.verseWords(19, 20, 25)), findsOneWidget);
    expect(
      find.text(
        'So send one of you to the city with this silver coin of yours.',
      ),
      findsOneWidget,
    );
    expect(find.text('Al-Kahf, from ayah 19'), findsOneWidget);
    expect(find.text('1 of 4'), findsOneWidget);
    expect(find.bySemanticsLabel('the silver coin, found'), findsOneWidget);
    expect(find.bySemanticsLabel('the vine, not found yet'), findsOneWidget);
    // Between two stories there are ayahs to walk first.
    expect(find.text('Keep going: Patience with the faithful'), findsOneWidget);
    expect(find.text('Next keepsake: the vine'), findsOneWidget);
    await tester.tap(find.text('Keep going: Patience with the faithful'));
    await tester.pumpAndSettle();
    expect(closed, [JourneyAfter.next]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a keepsake names the story that opens next', (tester) async {
    phone(tester);
    final progress = JourneyProgress(
      level: JourneyLevel.english,
      done: {
        for (final s in journey.stops.takeWhile((s) => s.id != 'qarnayn-1'))
          s.id,
      },
    );
    final closed = <Object?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _Launcher(
          JourneyKeepsakeScreen(
            journey: journey,
            progress: progress,
            section: journey.sections.firstWhere((s) => s.id == 'khidr'),
            arabic: false,
          ),
          closed,
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('You found the ship'), findsOneWidget);
    expect(find.text('3 of 4'), findsOneWidget);
    expect(find.text('Next story: Dhul-Qarnayn'), findsOneWidget);
    expect(find.text('Keepsake: the iron'), findsOneWidget);
    await tester.tap(find.text('Back to the map'));
    await tester.pumpAndSettle();
    expect(closed, [JourneyAfter.map]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the map still fits when the phone shows text twice as large', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget large(Widget home) => MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: home,
    );
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(large(const JourneyScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Start the journey'));
    await tester.tap(find.text('Start the journey'));
    await tester.pumpAndSettle();
    expect(find.text('Al-Kahf Journey'), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (final level in JourneyLevel.values) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        large(
          JourneyStopScreen(
            journey: journey,
            progress: JourneyProgress(level: level),
            stop: stop('cave-4'),
            random: Random(1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$level story');
      final begin = find.text(level.isArabic ? 'ابدأ' : 'Begin');
      await tester.ensureVisible(begin);
      await tester.tap(begin);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$level round');
    }
  });
}

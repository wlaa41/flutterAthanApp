import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_pro/models/journey.dart';
import 'package:flutter_pro/screens/journey_keepsake_screen.dart';
import 'package:flutter_pro/screens/journey_screen.dart';
import 'package:flutter_pro/screens/journey_sources_screen.dart';
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
      final choice = find.text(round[i].choices[round[i].correct]);
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(find.text("That's it."), findsOneWidget);
      // The answer card, with its button, has been brought into view.
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
    // Each level says where its meanings come from.
    expect(
      find.text(
        'Each ayah with its translation (Saheeh International), then questions in English.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('تُعرض الآية، وتختار تفسيرها من التفسير الميسر.'),
      findsOneWidget,
    );
    expect(
      find.text('يُعطى التفسير الميسر، وتختار الآية. بلا تلميح.'),
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

  testWidgets('the map leads to the page that names every source', (
    tester,
  ) async {
    phone(tester);
    SharedPreferences.setMockInitialValues({
      JourneyProgress.key: JourneyProgress(
        level: JourneyLevel.english,
      ).encode(),
    });
    await tester.pumpWidget(const MaterialApp(home: JourneyScreen()));
    await tester.pumpAndSettle();
    final link = find.textContaining('Sources', findRichText: true);
    await tester.ensureVisible(link);
    await tester.pumpAndSettle();
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.byType(JourneySourcesScreen), findsOneWidget);
    expect(
      find.text(
        'What explains the Quran in this game is copied from the works below, letter for letter.',
      ),
      findsOneWidget,
    );
    for (final text in [
      'Saheeh International',
      'التفسير الميسر',
      'السراج في بيان غريب القرآن',
      journey.translation.en,
      journey.translation.byEn,
      journey.tafsir.en,
      journey.tafsir.byEn,
      journey.wordSource.en,
      journey.wordSource.byEn,
      'From QuranEnc.com, version ${journey.translation.version}, ${journey.translation.date}.',
      'From QuranEnc.com, version ${journey.tafsir.version}, ${journey.tafsir.date}.',
      'From QuranEnc.com, version ${journey.wordSource.version}, ${journey.wordSource.date}.',
      'quranenc.com/en/browse/english_saheeh',
      'Every ayah is shown whole. Nothing of the Quran is retyped or reworded.',
      'Places and things only. No prophet, no person and no animal is drawn.',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Al-Kahf Journey'), findsOneWidget);

    // The same page in Arabic.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(home: JourneySourcesScreen(journey: journey, arabic: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('المصادر'), findsOneWidget);
    expect(find.text(journey.tafsir.ar), findsOneWidget);
    expect(find.text(journey.tafsir.byAr), findsOneWidget);
    expect(find.text(journey.wordSource.byAr), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a stop: its ayahs with their translation, its questions, a wrong answer comes back, the lantern',
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
      for (final chip in ['Ayahs 9 to 12', '4 questions', 'Then recite']) {
        expect(find.text(chip), findsOneWidget);
      }
      // Before any question the stop is read: every ayah whole, and under it
      // the translation with its footnotes, exactly as the source has them.
      expect(
        find.text('Read the ayahs and what they mean. Then answer.'),
        findsOneWidget,
      );
      final reading = find.byType(Scrollable).first;
      for (final ayah in played.ayahs) {
        final meaning = journey.meaning(ayah);
        await tester.scrollUntilVisible(
          find.text(meaning.en),
          200,
          scrollable: reading,
        );
        expect(find.text('Al-Kahf, ayah $ayah'), findsOneWidget);
        expect(find.text(journey.verseWithMark(ayah)), findsOneWidget);
        expect(find.text(meaning.en), findsOneWidget);
        for (final note in meaning.notes) {
          expect(find.text(note), findsOneWidget);
        }
      }
      expect(journey.meaning(9).notes, hasLength(1));
      await tester.scrollUntilVisible(
        find.textContaining('Translation: Saheeh International'),
        200,
        scrollable: reading,
      );
      expect(
        find.textContaining(
          'Translation: Saheeh International',
          findRichText: true,
        ),
        findsOneWidget,
      );

      // Listening can be started and stopped, for the stop or for one ayah.
      await tester.tap(find.text('Listen to the ayahs'));
      await tester.pumpAndSettle();
      expect(JourneyAudio.playing.value, isNull);
      final heard = <List<int>>[];
      JourneyAudio.player = (ayahs) async {
        heard.add(ayahs);
        return true;
      };
      await tester.tap(find.bySemanticsLabel('Listen to the ayah').last);
      await tester.pumpAndSettle();
      expect(heard, [
        [12],
      ]);

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
      // What follows is the translation of the ayah, named, not our words.
      await tester.tap(find.text(round[0].choices[(round[0].correct + 1) % 3]));
      await tester.pumpAndSettle();
      expect(find.text('Not quite.'), findsOneWidget);
      expect(find.text(journey.meaning(round[0].ayah).en), findsOneWidget);
      for (final note in journey.meaning(round[0].ayah).notes) {
        expect(find.text(note), findsOneWidget);
      }
      expect(
        find.text('Saheeh International, Al-Kahf ${round[0].ayah}'),
        findsOneWidget,
      );
      // A screen reader hears the verdict with each choice. The choice that
      // was picked is words of the translation: it is set apart, not crossed.
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
        contains('Your pick'),
      );
      // The only cross on the screen is the button that leaves the stop.
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('Leave this stop'), findsOneWidget);
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
    'Arabic: the ayah is shown, its tafsir is chosen, word meanings are optional',
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
      expect(find.text('الآيات ٩ إلى ١٢'), findsOneWidget);
      expect(find.text('اقرأ الآيات وتفسيرها، ثم أجب.'), findsOneWidget);
      // The stop is read first: each ayah whole, with al-Tafsir al-Muyassar.
      final reading = find.byType(Scrollable).first;
      for (final ayah in played.ayahs) {
        await tester.scrollUntilVisible(
          find.text(journey.meaning(ayah).ar),
          200,
          scrollable: reading,
        );
        expect(find.text(journey.verseWithMark(ayah)), findsOneWidget);
        expect(find.text(journey.meaning(ayah).ar), findsOneWidget);
      }
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
      expect(find.text('اختر تفسير هذه الآية'), findsOneWidget);
      expect(find.text('١ من ٤'), findsOneWidget);
      expect(find.text(journey.verseWithMark(item.ayah)), findsOneWidget);
      // The three choices are the tafsir's own texts, and the screen says so.
      for (final choice in item.choices) {
        expect(find.text(choice), findsOneWidget);
      }
      expect(item.choices[item.correct], journey.meaning(item.ayah).ar);
      expect(
        find.text('النصوص الثلاثة من التفسير الميسر، مجمع الملك فهد.'),
        findsOneWidget,
      );
      final hint = find.text(
        'اختياري: معاني الكلمات الغريبة في الآية إن احتجت إليها.',
      );
      await tester.ensureVisible(hint);
      expect(hint, findsOneWidget);

      // The help is there for who wants it: the words As-Siraj explains,
      // each as the mushaf writes it, with the book's meaning and its name.
      final words = journey.words[item.ayah]!;
      await tester.tap(find.text('معاني الكلمات'));
      await tester.pumpAndSettle();
      expect(find.text('من كتاب السراج في بيان غريب القرآن'), findsOneWidget);
      for (final word in words) {
        expect(find.text(word.meaning), findsOneWidget);
        expect(find.text(journey.wordText(item.ayah, word)), findsOneWidget);
      }
      await tester.tap(find.text('تم'));
      await tester.pumpAndSettle();

      // A wrong pick is a scholar's text about another ayah: it is set
      // apart, never crossed out.
      final wrong = find.text(item.choices[(item.correct + 1) % 3]);
      await tester.ensureVisible(wrong);
      await tester.tap(wrong);
      await tester.pumpAndSettle();
      expect(find.text('ليس هذا المطلوب.'), findsOneWidget);
      expect(tester.getSemantics(wrong).label, contains('اختيارك'));
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(
        tester.getSemantics(find.text(item.choices[item.correct])).label,
        contains('صحيح'),
      );
      // Once answered, the help makes way for the answer.
      expect(find.text('معاني الكلمات'), findsNothing);
      expect(progress.missed[item.ayah], 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Arabic: ayahs that share one tafsir text are read and asked as one',
    (tester) async {
      phone(tester);
      SharedPreferences.setMockInitialValues({});
      final progress = JourneyProgress(level: JourneyLevel.arabic);
      final played = stop('opening-1');
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
      final reading = find.byType(Scrollable).first;
      final together = [2, 3].map(journey.verseWithMark).join(' ');
      await tester.scrollUntilVisible(
        find.text(together),
        200,
        scrollable: reading,
      );
      expect(find.text('الكهف، الآيات ٢ إلى ٣'), findsOneWidget);
      expect(find.text(together), findsOneWidget);
      // Their one tafsir text is shown once, under both.
      expect(journey.meaning(2).ar, journey.meaning(3).ar);
      expect(find.text(journey.meaning(2).ar), findsOneWidget);
      expect(find.text('الكهف، الآية ٢'), findsNothing);

      final round = JourneyRounds.build(
        journey,
        played,
        JourneyLevel.arabic,
        random: Random(8),
      );
      expect(
        [for (final item in round) '${item.passage}'],
        ['1', '2-3', '4', '5'],
      );
      await tester.tap(find.text('ابدأ'));
      await tester.pumpAndSettle();
      final first = find.text(round[0].choices[round[0].correct]);
      await tester.ensureVisible(first);
      await tester.tap(first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      expect(find.text('اختر تفسير هذه الآيات'), findsOneWidget);
      expect(find.text(together), findsOneWidget);
      final right = find.text(round[1].choices[round[1].correct]);
      await tester.ensureVisible(right);
      await tester.tap(right);
      await tester.pumpAndSettle();
      expect(
        find.text('هذا تفسير الآيات ٢ إلى ٣ من سورة الكهف.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Arabic, strong: the tafsir is given, the whole ayah is chosen, with no help',
    (tester) async {
      phone(tester);
      SharedPreferences.setMockInitialValues({});
      final progress = JourneyProgress(level: JourneyLevel.strong);
      final played = stop('cave-4');
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
      expect(item.ayah, 19);
      expect(find.text('ما الذي يفسّره هذا النص؟'), findsOneWidget);
      expect(find.text('التفسير الميسر'), findsOneWidget);
      expect(find.text(journey.meaning(item.ayah).ar), findsOneWidget);
      // Every choice is a whole ayah with its end mark, however long: the
      // longest ayah of the surah stands here with all its 38 words.
      for (var i = 0; i < 3; i++) {
        final passage = item.choicePassages[i];
        expect(item.choices[i], journey.passageText(passage));
        expect(find.text(item.choices[i]), findsOneWidget);
      }
      expect(item.choices[item.correct].split(' '), hasLength(38));
      expect(find.textContaining('…'), findsNothing);
      // The ayah being asked for is not named: it is one of the choices.
      expect(
        find.text('الكهف، الآية ${JText(true).number(item.ayah)}'),
        findsNothing,
      );
      expect(find.text('معاني الكلمات'), findsNothing);
      final hint = find.text(
        'هذا المستوى بلا تلميح: التفسير أمامك، والآية من حفظك وفهمك.',
      );
      await tester.ensureVisible(hint);
      expect(hint, findsOneWidget);

      // A wrong pick is an ayah: nothing is stamped across it.
      final wrong = find.text(item.choices[(item.correct + 2) % 3]);
      await tester.ensureVisible(wrong);
      await tester.tap(wrong);
      await tester.pumpAndSettle();
      expect(find.text('ليس هذا المطلوب.'), findsOneWidget);
      expect(tester.getSemantics(wrong).label, contains('اختيارك'));
      // The only cross on the screen is the button that leaves the stop.
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(
        tester.getSemantics(find.text(item.choices[item.correct])).label,
        contains('صحيح'),
      );
      expect(progress.missed[item.ayah], 1);
      // The button under the answer was brought into view.
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      expect(find.text('ما الذي يفسّره هذا النص؟'), findsOneWidget);
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

    expect(find.text('STORY COMPLETE: THE CAVE'), findsOneWidget);
    expect(find.text('You found the silver coin'), findsOneWidget);
    // No part of an ayah is lifted onto this screen, and no words of ours
    // stand in for it: the screen says where the thing is mentioned.
    expect(
      find.text('Ayah 19 of Al-Kahf mentions the silver coin.'),
      findsOneWidget,
    );
    expect(find.text(journey.verseWithMark(19)), findsNothing);
    expect(find.text('1 of 4'), findsOneWidget);
    expect(find.bySemanticsLabel('the silver coin, found'), findsOneWidget);
    expect(
      find.bySemanticsLabel('the grapevines, not found yet'),
      findsOneWidget,
    );
    // The ayah opens whole, with its translation and footnote, named.
    await tester.tap(find.text('Read ayah 19'));
    await tester.pumpAndSettle();
    expect(find.text('Al-Kahf, ayah 19'), findsOneWidget);
    expect(find.text(journey.verseWithMark(19)), findsOneWidget);
    expect(find.text(journey.meaning(19).en), findsOneWidget);
    expect(find.text(journey.meaning(19).notes.single), findsOneWidget);
    expect(find.text('Translation: Saheeh International'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text(journey.verseWithMark(19)), findsNothing);
    // Between two stories there are ayahs to walk first.
    expect(find.text('Keep going: Patience with the faithful'), findsOneWidget);
    expect(find.text('Next keepsake: the grapevines'), findsOneWidget);
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
    expect(
      find.text('STORY COMPLETE: MUSA AND AL-KHIDR (PEACE BE UPON THEM)'),
      findsOneWidget,
    );
    expect(find.text('You found the ship'), findsOneWidget);
    expect(find.text('Ayah 79 of Al-Kahf mentions the ship.'), findsOneWidget);
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

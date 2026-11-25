// Run with: flutter test tools/capture_challenge.dart
// Writes review images of the meaning challenge into build/review; these are
// not goldens. Set REVIEW_FONT to an Arabic font for nicer text.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/data/kahf_challenge.dart';
import 'package:flutter_pro/main.dart';
import 'package:flutter_pro/screens/challenge_screen.dart';
import 'package:flutter_pro/screens/quiz_results_screen.dart';
import 'package:flutter_pro/screens/quiz_round_screen.dart';
import 'package:flutter_pro/screens/quiz_study_screen.dart';
import 'package:flutter_pro/services/quiz_engine.dart';
import 'package:flutter_pro/services/quiz_progress.dart';
import 'package:flutter_pro/widgets/quiz_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _boundary = ValueKey('screen-capture');

Future<void> _fonts(WidgetTester tester) => tester.runAsync(() async {
  final ui =
      Platform.environment['REVIEW_FONT'] ??
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';
  final roboto = FontLoader('Roboto')
    ..addFont(File(ui).readAsBytes().then(ByteData.sublistView));
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
  final hafs = FontLoader('kfgqpc_hafs')
    ..addFont(rootBundle.load('asset/fonts/kfgqpc_hafs.ttf'));
  await hafs.load();
  await QuizVerses.surah(18);
});

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundary),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/review').create(recursive: true);
    await File(
      'build/review/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Widget _app(Widget home) => RepaintBoundary(
  key: _boundary,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    home: home,
  ),
);

void main() {
  testWidgets('challenge review screens', (tester) async {
    await _fonts(tester);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const challenge = kahfChallenge;

    // Three stages played, the fourth next.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      'quiz_progress_kahf': jsonEncode({
        'points': 4860,
        'stages': {
          'kahf-1': {'s': 3, 'b': 1520, 'p': 2},
          'kahf-2': {'s': 2, 'b': 1210, 'p': 1},
          'kahf-3': {'s': 1, 'b': 880, 'p': 1},
        },
        'words': {
          for (final q in challenge.stages.first.questions)
            q.id: {'r': 2, 'w': 0, 'l': true},
        },
      }),
    });
    await tester.pumpWidget(_app(const ChallengeScreen()));
    await _frames(tester);
    await _capture(tester, 'challenge-map');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -520));
    await _frames(tester, 6);
    await _capture(tester, 'challenge-path');
    await tester.tap(find.text(challenge.stages[3].title));
    await _frames(tester, 6);
    await _capture(tester, 'challenge-stage-sheet');

    // A fresh tree, so the sheet does not stay open over the next screen.
    await tester.pumpWidget(const SizedBox.shrink());
    final stage = challenge.stages[3];
    final round = buildRound(
      stage.questions,
      size: QuizRules.roundSize,
      random: Random(11),
    );
    await tester.pumpWidget(
      _app(
        QuizRoundScreen(challenge: challenge, stage: stage, random: Random(11)),
      ),
    );
    await _frames(tester, 30);
    await _capture(tester, 'challenge-question');
    await tester.tap(find.text(round[0].question.meaning));
    await tester.pump(const Duration(milliseconds: 400));
    await _capture(tester, 'challenge-right');
    await tester.pump(const Duration(milliseconds: 2300));
    await _frames(tester, 6);
    await tester.tap(find.text(round[1].question.meaning));
    await tester.pump(const Duration(milliseconds: 2300));
    await _frames(tester, 6);
    await tester.tap(find.text(round[2].options[(round[2].answer + 1) % 4]));
    await _frames(tester, 6);
    await _capture(tester, 'challenge-wrong');

    final answers = [
      for (var i = 0; i < round.length; i++)
        AnswerLog(
          asked: round[i],
          chosen: i == 4 ? (round[i].answer + 2) % 4 : round[i].answer,
          points: i == 4 ? 0 : 180,
          timedOut: false,
        ),
    ];
    await tester.pumpWidget(const SizedBox.shrink());
    final progress = (await tester.runAsync(
      () => QuizProgress.load(challenge.id),
    ))!;
    final verses = (await tester.runAsync(() => QuizVerses.surah(18)))!;
    await tester.pumpWidget(
      _app(
        QuizResultsScreen(
          challenge: challenge,
          stage: stage,
          outcome: RoundOutcome(
            answers: answers,
            score: 1265,
            bestStreak: 4,
            survived: true,
            time: const Duration(minutes: 1, seconds: 38),
          ),
          saved: const SavedRound(
            stars: 2,
            newBest: true,
            unlockedNext: true,
            unlockedFinal: false,
          ),
          roundSize: round.length,
          verses: verses,
          progress: progress,
        ),
      ),
    );
    await _frames(tester, 20);
    await _capture(tester, 'challenge-results');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      _app(QuizStudyScreen(challenge: challenge, stage: challenge.stages[1])),
    );
    await _frames(tester, 12);
    await _capture(tester, 'challenge-study');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

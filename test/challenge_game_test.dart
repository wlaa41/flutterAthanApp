import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/data/kahf_challenge.dart';
import 'package:flutter_pro/screens/challenge_screen.dart';
import 'package:flutter_pro/screens/quiz_round_screen.dart';
import 'package:flutter_pro/screens/quiz_study_screen.dart';
import 'package:flutter_pro/services/quiz_engine.dart';
import 'package:flutter_pro/services/quiz_progress.dart';
import 'package:flutter_pro/widgets/quiz_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const challenge = kahfChallenge;
  final first = challenge.stages.first;

  Future<void> start(WidgetTester tester, Widget screen) async {
    // The Hafs text is read once and kept, as in the app.
    await tester.runAsync(() => QuizVerses.surah(18));
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: screen));
    await frames(tester);
  }

  /// The round the screen builds from the same seed.
  List<AskedQuestion> expected(int seed) => buildRound(
    first.questions,
    size: QuizRules.roundSize,
    random: Random(seed),
  );

  Widget round(int seed) =>
      QuizRoundScreen(challenge: challenge, stage: first, random: Random(seed));

  testWidgets('a perfect round earns three stars and opens the next stage', (
    tester,
  ) async {
    await start(tester, round(5));
    final asked = expected(5);
    for (var i = 0; i < asked.length; i++) {
      expect(find.text('السؤال ${_digits(i + 1)} من ٦'), findsOneWidget);
      await tester.tap(find.text(asked[i].question.meaning));
      await tester.pump();
      expect(find.textContaining('أحسنت!'), findsOneWidget);
      // A right answer moves on by itself.
      await tester.pump(const Duration(milliseconds: 2300));
      await frames(tester, 6);
    }
    await frames(tester, 30);
    expect(find.text('إتقان كامل!'), findsOneWidget);
    expect(find.text('فُتحت المرحلة التالية'), findsOneWidget);
    expect(find.text('راجع المعاني'), findsOneWidget);
    final progress = (await tester.runAsync(() => QuizProgress.load('kahf')))!;
    expect(progress.stage(first.id).stars, 3);
    expect(progress.unlocked(challenge, 1), isTrue);
    expect(progress.points, greaterThan(6 * 190));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a wrong answer costs a heart and shows the right meaning', (
    tester,
  ) async {
    await start(tester, round(8));
    final asked = expected(8).first;
    final wrong = asked.options[(asked.answer + 1) % 4];
    await tester.tap(find.text(wrong));
    await frames(tester, 4);
    expect(find.text('ليس هذا المعنى'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(
      find.textContaining(asked.question.meaning, findRichText: true),
      findsWidgets,
    );
    // A wrong answer waits until Next.
    await frames(tester, 30);
    expect(find.text('ليس هذا المعنى'), findsOneWidget);
    await tester.tap(find.text('التالي'));
    await frames(tester, 6);
    expect(find.text('السؤال ٢ من ٦'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('three misses end the round with no stars', (tester) async {
    await start(tester, round(2));
    final asked = expected(2);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text(asked[i].options[(asked[i].answer + 1) % 4]));
      await frames(tester, 4);
      await tester.tap(find.text(i < 2 ? 'التالي' : 'النتيجة'));
      await frames(tester, 8);
    }
    await frames(tester, 20);
    expect(find.text('نفدت القلوب'), findsOneWidget);
    final progress = (await tester.runAsync(() => QuizProgress.load('kahf')))!;
    expect(progress.stage(first.id).stars, 0);
    expect(progress.unlocked(challenge, 1), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the time runs out, and the helps work once each', (
    tester,
  ) async {
    await start(tester, round(4));
    final asked = expected(4);
    TimerRing ring() => tester.widget<TimerRing>(find.byType(TimerRing));
    await tester.pump(const Duration(seconds: 5));
    final before = ring();
    expect(before.limit, const Duration(seconds: 25));
    expect(before.left.inSeconds, inInclusiveRange(17, 20));
    await tester.tap(find.text('+١٠ ثوانٍ'));
    await tester.pump();
    expect(ring().limit, const Duration(seconds: 35));
    expect(
      ring().left - before.left,
      greaterThan(const Duration(milliseconds: 9500)),
    );
    await tester.tap(find.text('احذف إجابتين'));
    await tester.pump();
    expect(find.text('استُعملت'), findsNWidgets(2));
    // Two wrong answers are struck through and cannot be chosen.
    final struck = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.style?.decoration == TextDecoration.lineThrough);
    expect(struck, hasLength(2));
    expect(
      struck.map((t) => t.data),
      isNot(contains(asked.first.question.meaning)),
    );
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    expect(find.text('انتهى الوقت'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the challenge map opens stage one and keeps the rest locked', (
    tester,
  ) async {
    await start(tester, const ChallengeScreen());
    expect(find.text('تحدّي المعاني'), findsOneWidget);
    expect(find.text('تحدي سورة الكهف'), findsOneWidget);
    expect(find.text('لقبك: بداية الطريق'), findsOneWidget);
    expect(find.textContaining('أتقنت ٠ من'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await frames(tester, 4);
    await tester.tap(find.text(challenge.stages[1].title));
    await frames(tester, 4);
    expect(find.textContaining('بنجمة واحدة على الأقل'), findsOneWidget);
    await tester.tap(find.text(first.title));
    await frames(tester, 6);
    expect(find.text('ابدأ'), findsOneWidget);
    expect(find.text('٦ أسئلة من ٩'), findsOneWidget);
    expect(find.text('تعلّم كلمات المرحلة أولًا'), findsOneWidget);
    await tester.tap(find.text('ابدأ'));
    await frames(tester, 10);
    expect(find.byType(QuizRoundScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the study list shows every word of the stage with its meaning', (
    tester,
  ) async {
    await start(tester, QuizStudyScreen(challenge: challenge, stage: first));
    for (final question in first.questions.take(3)) {
      expect(find.text(question.meaning), findsOneWidget);
    }
    expect(find.text('ابدأ التحدي'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

/// The timer and the glowing path never settle, so step through frames.
Future<void> frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

String _digits(int n) => String.fromCharCodes(
  n.toString().codeUnits.map((unit) => unit - 0x30 + 0x0660),
);

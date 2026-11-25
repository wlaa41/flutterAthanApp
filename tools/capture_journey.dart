// Run with: flutter test tools/capture_journey.dart
// Writes review images of the Al-Kahf Journey into build/review; these are
// not goldens. The journey's own fonts are loaded, so the images show the
// screens as a phone draws them.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pro/main.dart';
import 'package:flutter_pro/models/journey.dart';
import 'package:flutter_pro/screens/journey_keepsake_screen.dart';
import 'package:flutter_pro/screens/journey_recite_screen.dart';
import 'package:flutter_pro/screens/journey_screen.dart';
import 'package:flutter_pro/screens/journey_stop_screen.dart';
import 'package:flutter_pro/services/journey_audio.dart';
import 'package:flutter_pro/services/journey_progress.dart';
import 'package:flutter_pro/services/journey_round.dart';
import 'package:flutter_pro/services/recitation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _boundary = ValueKey('screen-capture');

Future<void> _fonts(WidgetTester tester) => tester.runAsync(() async {
  final plain =
      Platform.environment['REVIEW_FONT'] ??
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';
  await (FontLoader(
    'Roboto',
  )..addFont(File(plain).readAsBytes().then(ByteData.sublistView))).load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  await (FontLoader(
    'kfgqpc_hafs',
  )..addFont(rootBundle.load('asset/fonts/kfgqpc_hafs.ttf'))).load();
  final baloo = FontLoader('baloo');
  for (final weight in const [400, 600, 700, 800]) {
    baloo.addFont(rootBundle.load('asset/fonts/baloo_$weight.ttf'));
  }
  await baloo.load();
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

Future<void> _frames(WidgetTester tester, [int count = 8]) async {
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

/// The tab as the app shows it: above the bar at the bottom.
Widget _tab(Widget child) => Scaffold(
  body: child,
  bottomNavigationBar: BottomNavigationBar(
    currentIndex: 2,
    type: BottomNavigationBarType.fixed,
    backgroundColor: Colors.white,
    selectedItemColor: const Color(0xFF0F3931),
    unselectedItemColor: const Color(0xFF52615D),
    selectedLabelStyle: const TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 12,
    ),
    unselectedLabelStyle: const TextStyle(fontSize: 12),
    elevation: 0,
    items: const [
      BottomNavigationBarItem(
        icon: Icon(Icons.access_time_filled_rounded),
        label: 'Prayers',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.menu_book_rounded),
        label: 'Quran',
      ),
      BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Journey'),
      BottomNavigationBarItem(
        icon: Icon(Icons.explore_rounded),
        label: 'Qibla',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.settings_rounded),
        label: 'Settings',
      ),
    ],
  ),
);

class _Model implements RecitationModel {
  _Model({this.onPhone = true});

  bool onPhone;

  @override
  Future<Directory> directory() async => Directory.systemTemp;

  @override
  Future<bool> ready() async => onPhone;

  @override
  Future<void> fetch({void Function(double share)? onProgress}) async {}
}

class _Listener implements RecitationListener {
  String heard = '';

  @override
  Future<void> start() async {}

  @override
  Future<double> level() async => 0.7;

  @override
  Future<String> finish() async => heard;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

void _save(JourneyProgress progress) {
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({
    JourneyProgress.key: progress.encode(),
  });
}

void main() {
  testWidgets('journey review screens', (tester) async {
    await _fonts(tester);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // ignore: invalid_use_of_visible_for_testing_member
    JourneyAudio.player = (ayahs) async => true;
    // ignore: invalid_use_of_visible_for_testing_member
    addTearDown(() => JourneyAudio.player = null);
    final journey = (await tester.runAsync(Journey.load))!;
    JourneyStop stop(String id) => journey.stops.firstWhere((s) => s.id == id);
    Future<void> show(Widget screen) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_app(screen));
      await _frames(tester);
    }

    // 1. Choose your level.
    _save(JourneyProgress());
    await show(_tab(const JourneyScreen()));
    await _capture(tester, 'journey-1-levels');

    // 2. The map: the opening walked, one stop of the Cave lit.
    _save(
      JourneyProgress(
        level: JourneyLevel.english,
        done: {'opening-1', 'opening-2', 'cave-1'},
      ),
    );
    await show(_tab(const JourneyScreen()));
    await _capture(tester, 'journey-2-map');
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -420),
    );
    await _frames(tester, 4);
    await _capture(tester, 'journey-2-map-lower');

    // The map in Arabic, two stories in.
    _save(
      JourneyProgress(
        level: JourneyLevel.arabic,
        done: {
          for (final s in journey.stops.takeWhile((s) => s.id != 'world-1'))
            s.id,
        },
      ),
    );
    await show(_tab(const JourneyScreen()));
    await _capture(tester, 'journey-2-map-arabic');

    // 3. The story, 4. the English level.
    var progress = JourneyProgress(
      level: JourneyLevel.english,
      done: {'opening-1', 'opening-2'},
    );
    await show(
      JourneyStopScreen(
        journey: journey,
        progress: progress,
        stop: stop('cave-1'),
        random: Random(4),
      ),
    );
    await _capture(tester, 'journey-3-story');
    var round = JourneyRounds.build(
      journey,
      stop('cave-1'),
      JourneyLevel.english,
      random: Random(4),
    );
    await tester.tap(find.text('Begin'));
    await _frames(tester, 4);
    await _capture(tester, 'journey-4-english');
    await tester.tap(find.text(round[0].choices[round[0].correct]));
    await _frames(tester, 4);
    await _capture(tester, 'journey-4-english-right');
    await tester.tap(find.text('Next'));
    await _frames(tester, 4);
    await tester.tap(find.text(round[1].choices[(round[1].correct + 1) % 3]));
    await _frames(tester, 4);
    await _capture(tester, 'journey-4-english-wrong');

    // 5. The Arabic level, with the optional word meanings.
    progress = JourneyProgress(
      level: JourneyLevel.arabic,
      done: {'opening-1', 'opening-2'},
    );
    await show(
      JourneyStopScreen(
        journey: journey,
        progress: progress,
        stop: stop('cave-1'),
        random: Random(4),
      ),
    );
    await _capture(tester, 'journey-3-story-arabic');
    await tester.tap(find.text('ابدأ'));
    await _frames(tester, 4);
    await _capture(tester, 'journey-5-arabic');
    await tester.tap(find.text('معاني الكلمات').first);
    await _frames(tester, 6);
    await _capture(tester, 'journey-5-arabic-words');

    // 6. Arabic, strong: the meaning is given, the ayah is chosen.
    progress = JourneyProgress(
      level: JourneyLevel.strong,
      done: {'opening-1', 'opening-2'},
    );
    await show(
      JourneyStopScreen(
        journey: journey,
        progress: progress,
        stop: stop('cave-1'),
        random: Random(4),
      ),
    );
    await tester.tap(find.text('ابدأ'));
    await _frames(tester, 4);
    await _capture(tester, 'journey-6-strong');
    round = JourneyRounds.build(
      journey,
      stop('cave-1'),
      JourneyLevel.strong,
      random: Random(4),
    );
    await tester.tap(find.text(round[0].choices[round[0].correct]));
    await _frames(tester, 4);
    await _capture(tester, 'journey-6-strong-right');

    // The lantern is lit: a short stop played to its end.
    progress = JourneyProgress(
      level: JourneyLevel.english,
      done: {'opening-1', 'opening-2'},
    );
    _save(progress);
    await show(
      JourneyStopScreen(
        journey: journey,
        progress: progress,
        stop: stop('cave-1'),
        random: Random(4),
      ),
    );
    round = JourneyRounds.build(
      journey,
      stop('cave-1'),
      JourneyLevel.english,
      random: Random(4),
    );
    await tester.tap(find.text('Begin'));
    await _frames(tester, 3);
    for (var i = 0; i < round.length; i++) {
      await tester.tap(find.text(round[i].choices[round[i].correct]));
      await _frames(tester, 3);
      if (i == round.length - 1) {
        await _capture(tester, 'journey-4-english-last');
      }
      await tester.tap(
        find.text(i == round.length - 1 ? 'Light the lantern' : 'Next'),
      );
      await _frames(tester, 3);
    }
    await _capture(tester, 'journey-7-lantern');

    // 7. Recite the next ayah.
    final listener = _Listener();
    await show(
      JourneyReciteScreen(
        journey: journey,
        progress: progress,
        stop: stop('cave-1'),
        arabic: false,
        listener: listener,
        model: _Model(),
      ),
    );
    await _capture(tester, 'journey-8-recite-first');
    await tester.tap(find.text('Skip'));
    await _frames(tester, 3);
    await _capture(tester, 'journey-8-recite-hidden');
    await tester.tap(find.text('Show the ayah'));
    await _frames(tester, 3);
    await _capture(tester, 'journey-8-recite-shown');
    await tester.tap(find.text('Recite'));
    await _frames(tester, 4);
    await _capture(tester, 'journey-8-recite-listening');
    final words = journey.verse(10).split(' ');
    listener.heard = [
      for (var i = 0; i < words.length; i++)
        if (i != 9 && i != 11) recitationLetters(words[i]),
    ].join(' ');
    await tester.tap(find.text('Done'));
    await _frames(tester, 4);
    await _capture(tester, 'journey-8-recite-result');
    listener.heard = words.map(recitationLetters).join(' ');
    await tester.tap(find.text('Recite again'));
    await _frames(tester, 3);
    await tester.tap(find.text('Done'));
    await _frames(tester, 4);
    await _capture(tester, 'journey-8-recite-all');

    await show(
      JourneyReciteScreen(
        journey: journey,
        progress: progress,
        stop: stop('cave-1'),
        arabic: false,
        listener: listener,
        model: _Model(onPhone: false),
      ),
    );
    await _capture(tester, 'journey-8-recite-get-listener');

    await show(
      JourneyReciteScreen(
        journey: journey,
        progress: JourneyProgress(level: JourneyLevel.arabic),
        stop: stop('cave-4'),
        arabic: true,
        listener: listener,
        model: _Model(),
      ),
    );
    await tester.tap(find.text('تخطَّ'));
    await _frames(tester, 3);
    await tester.tap(find.text('أظهر الآية'));
    await _frames(tester, 3);
    await _capture(tester, 'journey-8-recite-arabic');

    // 8. The keepsake of a story.
    progress = JourneyProgress(
      level: JourneyLevel.english,
      done: {
        for (final s in journey.stops.takeWhile((s) => s.id != 'book-1')) s.id,
      },
    );
    await show(
      JourneyKeepsakeScreen(
        journey: journey,
        progress: progress,
        section: journey.sections[1],
        arabic: false,
      ),
    );
    await _capture(tester, 'journey-9-keepsake');
    for (final (index, until) in [
      'world-1',
      'qarnayn-1',
      'closing-1',
    ].indexed) {
      progress = JourneyProgress(
        level: JourneyLevel.arabic,
        done: {
          for (final s in journey.stops.takeWhile((s) => s.id != until)) s.id,
        },
      );
      await show(
        JourneyKeepsakeScreen(
          journey: journey,
          progress: progress,
          section: journey.sections
              .where((s) => s.isStory)
              .elementAt(index + 1),
          arabic: index != 1,
        ),
      );
      await _capture(tester, 'journey-9-keepsake-${index + 2}');
    }

    // The end of the road.
    _save(
      JourneyProgress(
        level: JourneyLevel.english,
        done: {for (final s in journey.stops) s.id},
      ),
    );
    await show(_tab(const JourneyScreen()));
    await _capture(tester, 'journey-2-map-done');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(jsonEncode(JourneyProgress().encode()), isNotEmpty);
  });
}

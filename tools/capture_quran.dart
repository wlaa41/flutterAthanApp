// Run with: flutter test tools/capture_quran.dart
// Writes disposable review images of the Quran screens into build/review.
// Set REVIEW_TAFSIR_DIR to a folder of saved quran.com answers
// (t_<book>_<surah>_<ayah>.json) to include the tafsir screen.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/main.dart';
import 'package:flutter_pro/screens/quran_index_screen.dart';
import 'package:flutter_pro/screens/quran_reader_screen.dart';
import 'package:flutter_pro/screens/tafsir_screen.dart';
import 'package:flutter_pro/services/disk_cache.dart';
import 'package:flutter_pro/services/mushaf_library.dart';
import 'package:flutter_pro/services/quran_service.dart';
import 'package:flutter_pro/services/quran_translation_service.dart';
import 'package:flutter_pro/services/tafsir_service.dart';
import 'package:flutter_pro/widgets/mushaf_block.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _boundary = ValueKey('screen-capture');

Future<void> loadReviewFonts(WidgetTester tester) => tester.runAsync(() async {
  final latin =
      Platform.environment['REVIEW_FONT'] ??
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';
  final roboto = FontLoader('Roboto')
    ..addFont(File(latin).readAsBytes().then(ByteData.sublistView));
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
  for (final edition in MushafLibrary.editions) {
    final font = FontLoader(edition.fontFamily)
      ..addFont(rootBundle.load('asset/fonts/kfgqpc_${edition.textId}.ttf'));
    await font.load();
  }
});

Future<void> capture(WidgetTester tester, String name) async {
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

http.Response _json(Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200);

void main() {
  testWidgets('quran review screens', (tester) async {
    await loadReviewFonts(tester);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(392, 850);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final library = MushafLibrary();
    final translations = QuranTranslationService(
      cache: DiskCache('none', root: () async => null),
      client: MockClient((request) async {
        final number = int.parse(request.url.pathSegments[2]);
        final count = QuranService.surahList[number - 1].numberOfAyahs;
        return _json({
          'code': 200,
          'data': {
            'number': number,
            'edition': {'identifier': 'en.sahih'},
            'ayahs': [
              for (var n = 1; n <= count; n++)
                {
                  'numberInSurah': n,
                  'text': n == 2 && number == 1
                      ? '[All] praise is [due] to Allah, Lord of the worlds'
                      : 'Meaning of verse $n',
                },
            ],
          },
        });
      }),
    );

    Widget app(Widget home) => RepaintBoundary(
      key: _boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        home: home,
      ),
    );

    Future<void> open(Widget home) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(app(home));
      await tester.pumpAndSettle();
    }

    Widget reader(int surah, {int? page}) => QuranReaderScreen(
      key: UniqueKey(),
      surah: QuranService.surahList[surah - 1],
      openAtPage: page,
      library: library,
      translations: translations,
    );

    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});

    await open(reader(1));
    await capture(tester, 'quran-fatiha-tajweed');

    await open(reader(2));
    await capture(tester, 'quran-baqarah-tajweed');

    // The verse sheet.
    await tester.tapAt(
      tester.getTopRight(find.byType(MushafBlock).first) +
          const Offset(-30, 20),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'quran-verse-sheet');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    // The mushaf sheet, then the colour guide.
    await tester.tap(find.byTooltip('Mushaf and text size'));
    await tester.pumpAndSettle();
    await capture(tester, 'quran-mushaf-sheet');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tajweed colours'));
    await tester.pumpAndSettle();
    await capture(tester, 'quran-tajweed-guide');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    for (final id in ['hafs', 'warsh', 'qaloon', 'doori', 'bazzi']) {
      await library.choose(MushafLibrary.edition(id));
      await open(reader(1));
      await capture(tester, 'quran-fatiha-$id');
    }

    await library.choose(MushafLibrary.edition('warsh'));
    await open(reader(2));
    await capture(tester, 'quran-baqarah-warsh');

    // Night page.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      QuranReaderScreen.nightKey: true,
      QuranReaderScreen.fontSizeKey: 30.0,
    });
    await library.choose(MushafLibrary.edition('hafs_tajweed'));
    await open(reader(36));
    await capture(tester, 'quran-yasin-night');

    // The surah list.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await QuranService.instance.saveLastRead(
      const LastRead(surah: 18, page: 297, textId: 'hafs'),
    );
    await library.choose(MushafLibrary.edition('hafs_tajweed'));
    await open(QuranIndexScreen(library: library));
    await capture(tester, 'quran-index');

    final samples = Platform.environment['REVIEW_TAFSIR_DIR'];
    if (samples != null) {
      final tafsir = TafsirService(
        cache: DiskCache('none', root: () async => null),
        client: MockClient((request) async {
          final parts = request.url.pathSegments;
          final verse = parts.last.replaceAll(':', '_');
          final file = File('$samples/t_${parts[3]}_$verse.json');
          return file.existsSync()
              ? http.Response.bytes(file.readAsBytesSync(), 200)
              : http.Response('missing', 404);
        }),
      );
      final text = await library.load(MushafLibrary.edition('hafs_tajweed'));
      for (final shot in [
        (book: 16, surah: 2, ayah: 255, name: 'muyassar'),
        (book: 169, surah: 2, ayah: 3, name: 'ibn-kathir-en'),
        (book: 14, surah: 1, ayah: 2, name: 'ibn-kathir-ar'),
      ]) {
        // ignore: invalid_use_of_visible_for_testing_member
        SharedPreferences.setMockInitialValues({
          TafsirScreen.bookKey: shot.book,
        });
        await open(
          TafsirScreen(
            key: UniqueKey(),
            surah: QuranService.surahList[shot.surah - 1],
            text: text,
            ayah: text.surah(shot.surah)[shot.ayah - 1],
            service: tafsir,
          ),
        );
        await capture(tester, 'quran-tafsir-${shot.name}');
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

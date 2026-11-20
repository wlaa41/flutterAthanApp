import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/models/quran_models.dart';
import 'package:flutter_pro/screens/quran_index_screen.dart';
import 'package:flutter_pro/screens/quran_reader_screen.dart';
import 'package:flutter_pro/screens/tafsir_screen.dart';
import 'package:flutter_pro/services/disk_cache.dart';
import 'package:flutter_pro/services/mushaf_library.dart';
import 'package:flutter_pro/services/quran_service.dart';
import 'package:flutter_pro/services/quran_translation_service.dart';
import 'package:flutter_pro/services/tafsir_service.dart';
import 'package:flutter_pro/widgets/mushaf_block.dart';
import 'package:flutter_pro/widgets/tafsir_html.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response jsonResponse(Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200);

DiskCache noDisk() => DiskCache('none', root: () async => null);

/// A translation source that answers every surah with numbered meanings.
QuranTranslationService meanings({bool online = true}) =>
    QuranTranslationService(
      cache: noDisk(),
      client: MockClient((request) async {
        if (!online) return http.Response('offline', 503);
        final number = int.parse(request.url.pathSegments[2]);
        return jsonResponse({
          'code': 200,
          'data': {
            'number': number,
            'edition': {'identifier': 'en.sahih'},
            'ayahs': [
              for (
                var n = 1;
                n <= QuranService.surahList[number - 1].numberOfAyahs;
                n++
              )
                {'numberInSurah': n, 'text': 'Meaning $number:$n'},
            ],
          },
        });
      }),
    );

Surah surah(int number) => QuranService.surahList[number - 1];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpReader(
    WidgetTester tester,
    MushafLibrary library, {
    int number = 112,
    QuranTranslationService? translations,
    int? hafsAyah,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(392, 850);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: QuranReaderScreen(
          surah: surah(number),
          library: library,
          translations: translations ?? meanings(),
          openAtHafsAyah: hafsAyah,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens a surah from the bundled mushaf with no connection', (
    tester,
  ) async {
    await pumpReader(
      tester,
      MushafLibrary(),
      translations: meanings(online: false),
    );
    expect(find.text('Al-Ikhlaas'), findsOneWidget);
    expect(find.text('Hafs, tajweed colours'), findsOneWidget);
    expect(find.text('Meccan, 4 ayat, juz 30'), findsOneWidget);
    final block = tester.widget<MushafBlock>(find.byType(MushafBlock));
    expect(block.ayat.map((ayah) => ayah.number), [1, 2, 3, 4]);
    expect(block.edition.fontFamily, 'kfgqpc_hafs');
    expect(block.ayat.first.tajweed, isNotEmpty);
    // The whole passage is one paragraph in the mushaf's own font.
    final paragraph = tester.widget<RichText>(
      find.descendant(
        of: find.byType(MushafBlock),
        matching: find.byType(RichText),
      ),
    );
    expect(paragraph.textDirection, TextDirection.rtl);
    expect(paragraph.text.style!.fontFamily, 'kfgqpc_hafs');
    expect(
      paragraph.text.toPlainText(),
      block.ayat.map((a) => '${a.text}${MushafBlock.endMark(a)}').join(' '),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tapped verse offers its meaning, tafsir, audio and marks', (
    tester,
  ) async {
    await pumpReader(tester, MushafLibrary());
    expect(
      find.text('Tap a verse for its meaning, tafsir and audio.'),
      findsOneWidget,
    );
    final block = find.byType(MushafBlock);
    // Text runs right to left, so the first verse starts at the right edge.
    await tester.tapAt(tester.getTopRight(block) + const Offset(-8, 12));
    await tester.pumpAndSettle();
    expect(find.text('Al-Ikhlaas 112:1'), findsOneWidget);
    expect(find.text('Juz 30, page 604'), findsOneWidget);
    expect(find.text('Meaning 112:1'), findsOneWidget);
    expect(find.text('Saheeh International'), findsOneWidget);
    for (final action in ['Play', 'Tafsir', 'Bookmark', 'Note', 'Copy']) {
      expect(find.text(action), findsOneWidget);
    }
    expect(tester.widget<MushafBlock>(block).selected, 1);

    await tester.tap(find.text('Bookmark'));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
    // The key is the running Hafs number the app has always stored.
    expect(await QuranService.instance.bookmarks(), ['6222']);

    await tester.tap(find.bySemanticsLabel('Highlight colour').first);
    await tester.pumpAndSettle();
    expect(await QuranService.instance.highlights(), {'6222': 0xFFFEF08A});
    expect(tester.widget<MushafBlock>(block).highlights.keys, [1]);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(tester.widget<MushafBlock>(block).selected, isNull);
    // The hint has done its job and stays away.
    expect(
      find.text('Tap a verse for its meaning, tafsir and audio.'),
      findsNothing,
    );
    expect(
      (await SharedPreferences.getInstance()).getBool(
        QuranReaderScreen.tapHintKey,
      ),
      isTrue,
    );

    // The last verse ends at the bottom left.
    await tester.tapAt(tester.getBottomLeft(block) + const Offset(8, -12));
    await tester.pumpAndSettle();
    expect(find.text('Al-Ikhlaas 112:4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('says so when the translation is not on the phone yet', (
    tester,
  ) async {
    await pumpReader(
      tester,
      MushafLibrary(),
      translations: meanings(online: false),
    );
    await tester.tapAt(
      tester.getTopRight(find.byType(MushafBlock)) + const Offset(-8, 12),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('translation of this surah is not on the phone'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches to Warsh, with its own script, numbers and font', (
    tester,
  ) async {
    final library = MushafLibrary();
    await pumpReader(tester, library, number: 1);
    expect(find.text('Meccan, 7 ayat, juz 1'), findsOneWidget);
    var blocks = tester.widgetList<MushafBlock>(find.byType(MushafBlock));
    final hafsFirst = blocks.first.ayat.first.text;

    await tester.tap(find.byTooltip('Mushaf and text size'));
    await tester.pumpAndSettle();
    expect(find.text('Mushaf'), findsOneWidget);
    for (final edition in MushafLibrary.editions.take(4)) {
      expect(find.text(edition.name), findsWidgets);
    }
    await tester.tap(find.text("Warsh from Nafi'"));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text("Warsh from Nafi'"), findsOneWidget);
    expect(library.current.value.id, 'warsh');
    expect(
      (await SharedPreferences.getInstance()).getString('quran_edition'),
      'warsh',
    );
    blocks = tester.widgetList<MushafBlock>(find.byType(MushafBlock));
    expect(blocks.first.edition.fontFamily, 'kfgqpc_warsh');
    expect(blocks.first.ayat.first.text, isNot(hafsFirst));
    expect(blocks.first.ayat.first.tajweed, isEmpty);
    // The colour guide belongs to the coloured copy only.
    expect(find.byTooltip('Tajweed colours'), findsNothing);

    // Warsh numbers the Fatiha from al-hamdu, so its first verse is Hafs 1:2.
    await tester.tapAt(
      tester.getTopRight(find.byType(MushafBlock).first) + const Offset(-8, 12),
    );
    await tester.pumpAndSettle();
    expect(find.text('Al-Faatiha 1:1'), findsOneWidget);
    expect(find.textContaining('1:2 in the Hafs count'), findsOneWidget);
    expect(find.text('Meaning 1:2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('text size and night page are kept for next time', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      QuranReaderScreen.fontSizeKey: 34.0,
      QuranReaderScreen.nightKey: true,
    });
    await pumpReader(tester, MushafLibrary());
    final block = tester.widget<MushafBlock>(find.byType(MushafBlock));
    expect(block.fontSize, 34);
    expect(block.palette.night, isTrue);

    await tester.tap(find.byTooltip('Mushaf and text size'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Night page'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Night page'));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getBool(
        QuranReaderScreen.nightKey,
      ),
      isFalse,
    );
    expect(
      tester.widget<MushafBlock>(find.byType(MushafBlock)).palette.night,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long surah is laid out page by page and opens at a bookmark', (
    tester,
  ) async {
    final library = MushafLibrary();
    await pumpReader(tester, library, number: 2, hafsAyah: 255);
    final text = await library.load(library.current.value);
    final pages = text.surah(2).map((ayah) => ayah.page).toSet();
    expect(
      tester.widgetList<MushafBlock>(find.byType(MushafBlock)).length,
      pages.length,
    );
    final kursi = text.surah(2)[254];
    expect(find.textContaining('Page ${kursi.page}'), findsOneWidget);
    // The bookmarked verse is marked, on screen, and remembered as the place.
    final holder = tester
        .widgetList<MushafBlock>(find.byType(MushafBlock))
        .firstWhere((block) => block.ayat.contains(kursi));
    expect(holder.selected, 255);
    final box = tester.getRect(find.byWidget(holder));
    expect(box.top, lessThan(850));
    expect(box.bottom, greaterThan(0));
    final place = (await QuranService.instance.lastRead())!;
    expect([place.surah, place.page, place.textId], [2, kursi.page, 'hafs']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the surah list follows the chosen mushaf', (tester) async {
    await QuranService.instance.saveLastRead(
      const LastRead(surah: 18, page: 297, textId: 'hafs'),
    );
    final library = MushafLibrary();
    await tester.pumpWidget(
      MaterialApp(home: QuranIndexScreen(library: library)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hafs, tajweed colours'), findsOneWidget);
    expect(find.text('The Cow • 286 Ayahs'), findsOneWidget);
    expect(find.text('Continue reading'), findsOneWidget);
    expect(find.text('Al-Kahf, page 297'), findsOneWidget);

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Warsh from Nafi'"));
    await tester.pumpAndSettle();
    expect(find.text("Warsh from Nafi'"), findsOneWidget);
    expect(find.text('The Cow • 285 Ayahs'), findsOneWidget);
    // A page number means nothing in another mushaf, so it is not offered.
    expect(find.text('Al-Kahf'), findsOneWidget);
    expect(find.text('Al-Kahf, page 297'), findsNothing);

    await tester.enterText(find.byType(TextField), 'ikhl');
    await tester.pumpAndSettle();
    expect(find.text('Al-Ikhlaas'), findsOneWidget);
    expect(find.text('Continue reading'), findsNothing);

    await QuranService.instance.toggleBookmark('262');
    await tester.tap(find.byTooltip('Bookmarks'));
    await tester.pumpAndSettle();
    expect(find.text('Al-Baqara 2:255'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove bookmark'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No bookmarks yet'), findsOneWidget);
    expect(await QuranService.instance.bookmarks(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  group('tafsir screen', () {
    Future<MushafText> hafs() =>
        MushafLibrary().load(MushafLibrary.edition('hafs'));

    TafsirService source(List<String> asked, {bool online = true}) =>
        TafsirService(
          cache: noDisk(),
          client: MockClient((request) async {
            asked.add(request.url.path);
            if (!online) return http.Response('offline', 503);
            final parts = request.url.pathSegments;
            final book = int.parse(parts[3]);
            if (parts[4] == 'by_chapter') {
              return jsonResponse({
                'tafsirs': [
                  for (var n = 1; n <= 4; n++)
                    {
                      'resource_id': book,
                      'verse_key': '112:$n',
                      'text': 'تفسير الآية $n',
                    },
                ],
                'pagination': {'next_page': null},
              });
            }
            return jsonResponse({
              'tafsir': {
                'resource_id': book,
                'verses': {parts[5]: <String, dynamic>{}},
                'text': '<h2>Heading $book</h2><p>Explains ${parts[5]}</p>',
              },
            });
          }),
        );

    testWidgets('shows the tafsir, moves between verses and works', (
      tester,
    ) async {
      final text = (await tester.runAsync(hafs))!;
      final asked = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: TafsirScreen(
            surah: surah(112),
            text: text,
            ayah: text.surah(112)[1],
            service: source(asked),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Al-Ikhlaas 112:2'), findsOneWidget);
      // The default is the short Arabic tafsir, fetched a surah at a time.
      expect(find.text('تفسير الآية 2', findRichText: true), findsOneWidget);
      expect(asked, ['/api/v4/tafsirs/16/by_chapter/112']);

      await tester.tap(find.text('Next verse'));
      await tester.pumpAndSettle();
      expect(find.text('Al-Ikhlaas 112:3'), findsOneWidget);
      expect(find.text('تفسير الآية 3', findRichText: true), findsOneWidget);
      expect(asked.length, 1);

      await tester.dragUntilVisible(
        find.text('Ibn Kathir'),
        find.byType(SingleChildScrollView).first,
        const Offset(-200, 0),
      );
      await tester.tap(find.text('Ibn Kathir'));
      await tester.pumpAndSettle();
      expect(find.text('Heading 169', findRichText: true), findsOneWidget);
      expect(find.text('Explains 112:3', findRichText: true), findsOneWidget);
      expect(asked.last, '/api/v4/tafsirs/169/by_ayah/112:3');
      expect(
        (await SharedPreferences.getInstance()).getInt(TafsirScreen.bookKey),
        169,
      );
      expect(find.byType(TafsirHtmlView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('explains a failure and retries', (tester) async {
      final text = (await tester.runAsync(hafs))!;
      final asked = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: TafsirScreen(
            surah: surah(112),
            text: text,
            ayah: text.surah(112).first,
            service: source(asked, online: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be loaded'), findsOneWidget);
      final before = asked.length;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(asked.length, greaterThan(before));
      expect(find.text('Previous verse'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

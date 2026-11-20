import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/models/quran_models.dart';
import 'package:flutter_pro/screens/mushaf_pages_screen.dart';
import 'package:flutter_pro/screens/quran_index_screen.dart';
import 'package:flutter_pro/screens/quran_reader_screen.dart';
import 'package:flutter_pro/services/disk_cache.dart';
import 'package:flutter_pro/services/mushaf_library.dart';
import 'package:flutter_pro/services/mushaf_pages.dart';
import 'package:flutter_pro/services/quran_service.dart';
import 'package:flutter_pro/services/quran_translation_service.dart';
import 'package:flutter_pro/widgets/mushaf_block.dart';
import 'package:flutter_pro/widgets/mushaf_page.dart';
import 'package:flutter_pro/widgets/tajweed_legend.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

QuranTranslationService meanings() => QuranTranslationService(
  cache: DiskCache('none', root: () async => null),
  client: MockClient((request) async {
    final number = int.parse(request.url.pathSegments[2]);
    return http.Response.bytes(
      utf8.encode(
        jsonEncode({
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
        }),
      ),
      200,
    );
  }),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<MushafPages> hafsPages([String edition = 'hafs']) async {
    final text = await MushafLibrary().load(MushafLibrary.edition(edition));
    return MushafPages.load(text);
  }

  String words(MushafPages pages, int page, int line) => MushafPage.lineText(
    pages.pieces(pages.lines(page)[line - 1]! as TextLine),
  ).text;

  group('The printed layout', () {
    test(
      'has the 604 pages of the Madinah mushaf, fifteen lines each',
      () async {
        final pages = await hafsPages();
        expect(pages.pageCount, 604);
        var banners = 0;
        var basmalahs = 0;
        var textLines = 0;
        for (var page = 1; page <= 604; page++) {
          final lines = pages.lines(page);
          expect(lines, hasLength(15));
          // Only the two opening pages are shorter: eight lines in a frame.
          expect(
            lines.where((line) => line != null).length,
            page <= 2 ? 8 : 15,
            reason: 'page $page',
          );
          for (final line in lines) {
            switch (line) {
              case SurahBanner():
                banners++;
              case BasmalahLine():
                basmalahs++;
              case TextLine():
                textLines++;
              case null:
                break;
            }
          }
        }
        expect(banners, 114);
        // Al-Fatiha's basmalah is its first verse; At-Tawbah has none.
        expect(basmalahs, 112);
        expect(textLines, 8820);
      },
    );

    test('holds every word of every verse once, in order', () async {
      final pages = await hafsPages();
      final rebuilt = <String, StringBuffer>{};
      final marks = <String, int>{};
      final order = <String>[];
      for (var page = 1; page <= pages.pageCount; page++) {
        for (final line in pages.lines(page)) {
          if (line is! TextLine) continue;
          for (final piece in pages.pieces(line)) {
            final key = '${piece.ayah.surah}:${piece.ayah.number}';
            if (!rebuilt.containsKey(key)) order.add(key);
            final buffer = rebuilt.putIfAbsent(key, StringBuffer.new);
            final part = piece.ayah.text.substring(piece.start, piece.end);
            if (part.isNotEmpty) {
              if (buffer.isNotEmpty) buffer.write(' ');
              buffer.write(part);
            }
            if (piece.endMark) marks[key] = (marks[key] ?? 0) + 1;
          }
        }
      }
      final expected = <String>[];
      for (final surah in pages.text.surahs) {
        for (final ayah in surah) {
          final key = '${ayah.surah}:${ayah.number}';
          expected.add(key);
          expect(rebuilt[key].toString(), ayah.text, reason: key);
          expect(marks[key], 1, reason: key);
        }
      }
      expect(order, expected);
      expect(expected, hasLength(6236));
    });

    test('breaks its lines where the print does', () async {
      final pages = await hafsPages();
      final text = pages.text;

      /// Words [from] to [to] of a verse, counted from 1, as the text has them.
      String part(int surah, int ayah, int from, [int? to]) {
        final all = text.surah(surah)[ayah - 1].text.split(' ');
        return all.sublist(from - 1, to ?? all.length).join(' ');
      }

      // Page 1: the banner, then Al-Fatiha, whose basmalah is verse 1.
      expect(pages.lines(1)[0], isA<SurahBanner>());
      expect(words(pages, 1, 2), '${text.basmalah} ١');
      expect(words(pages, 1, 8), '${part(1, 7, 8)} ٧');
      // Page 2: banner, basmalah, then Alif Lam Mim.
      expect((pages.lines(2)[0]! as SurahBanner).surah, 2);
      expect((pages.lines(2)[1]! as BasmalahLine).surah, 2);
      expect(words(pages, 2, 3), '${part(2, 1, 1)} ١ ${part(2, 2, 1, 6)}');
      expect(words(pages, 2, 4), startsWith('${part(2, 2, 7)} ٢ '));
      // Page 3 opens with the first nine words of verse 6 and ends verse 16.
      expect(words(pages, 3, 1), part(2, 6, 1, 9));
      expect(words(pages, 3, 2), startsWith('${part(2, 6, 10)} ٦ '));
      expect(words(pages, 3, 15), endsWith(' ${part(2, 16, 11)} ١٦'));
      // A verse number can open a line, as on line 12 of page 7.
      expect(words(pages, 7, 12), startsWith('٤٥ ${part(2, 46, 1, 2)} '));
      expect(words(pages, 6, 4), startsWith('${part(2, 31, 2, 3)} '));
      // The last page: three surahs, their short endings set in the middle.
      final last = pages.lines(604);
      expect((last[0]! as SurahBanner).surah, 112);
      expect((last[4]! as SurahBanner).surah, 113);
      expect((last[9]! as SurahBanner).surah, 114);
      expect(
        words(pages, 604, 3),
        '${part(112, 1, 1)} ١ ${part(112, 2, 1)} ٢ ${part(112, 3, 1)} ٣',
      );
      expect(words(pages, 604, 4), '${part(112, 4, 1)} ٤');
      expect((last[3]! as TextLine).centred, isTrue);
      expect((last[2]! as TextLine).centred, isFalse);
      expect(words(pages, 604, 15), '${part(114, 6, 1)} ٦');
      // Every line of the two opening pages is centred.
      for (final line in pages.lines(1).whereType<TextLine>()) {
        expect(line.centred, isTrue);
      }
      expect((pages.lines(3)[0]! as TextLine).centred, isFalse);
    });

    test('finds the page of a surah and of a verse', () async {
      final pages = await hafsPages();
      expect(pages.pageOfSurah(1), 1);
      expect(pages.pageOfSurah(2), 2);
      expect(pages.pageOfSurah(3), 50);
      // An-Nisa's banner sits at the foot of page 76; it begins on 77.
      expect(pages.lines(76).last, isA<SurahBanner>());
      expect(pages.pageOfSurah(4), 77);
      expect(pages.pageOfSurah(114), 604);
      expect(pages.pageOf(pages.text.surah(2)[254]), 42);
      expect(pages.surahsOn(604), [112, 113, 114]);
      expect(pages.surahsOn(76), [3, 4]);
      expect(pages.firstAyah(3).number, 6);
      // The page of every verse agrees with the Complex's own page numbers.
      for (final surah in pages.text.surahs) {
        for (final ayah in surah) {
          expect(
            pages.pageOf(ayah),
            ayah.page,
            reason: '${ayah.surah}:${ayah.number}',
          );
        }
      }
    });

    test('carries the tajweed colours into the lines', () async {
      final pages = await hafsPages('hafs_tajweed');
      final piece = pages.pieces(pages.lines(3)[0]! as TextLine).single;
      expect(piece.ayah.tajweed, isNotEmpty);
      expect(piece.endMark, isFalse);
      expect(piece.end, lessThan(piece.ayah.text.length));
    });
  });

  group('Fitting a page', () {
    PageFit fit(Size space) => PageFit.of(
      space: space,
      natural: [16, 15, 12, null, 5],
      centred: [false, false, false, false, true],
      gaps: [9, 8, 7, 0, 2],
    );

    /// The width a line is drawn at: its type, its word spaces, its stretch.
    double drawn(LineFit line, double em, int gaps) =>
        (em * line.fontSize + gaps * line.wordSpacing) * line.stretch;

    test('the widest line fills the width; the rest are spread to it', () {
      final page = fit(const Size(320, 2000));
      expect(page.width, closeTo(320, 0.01));
      // The widest line is drawn at its smallest and closest, with no
      // space added.
      final widest = page.lines[0]!;
      expect(widest.fontSize, closeTo(page.fontSize * 0.97, 0.01));
      expect(widest.stretch, closeTo(0.96, 0.0001));
      expect(widest.wordSpacing, closeTo(0, 0.01));
      expect(drawn(widest, 16, 9), closeTo(320, 0.01));
      // A line close to it needs only a little of that.
      final near = page.lines[1]!;
      expect(near.stretch, inInclusiveRange(0.96, 1.06));
      expect(drawn(near, 15, 8), closeTo(320, 0.01));
      // A much narrower line grows, is drawn wider, then spreads its words.
      final narrow = page.lines[2]!;
      expect(narrow.fontSize, closeTo(page.fontSize * 1.03, 0.01));
      expect(narrow.stretch, closeTo(1.06, 0.0001));
      expect(narrow.wordSpacing, greaterThan(0));
      expect(drawn(narrow, 12, 7), closeTo(320, 0.01));
      // A centred line keeps the page's size and is not spread.
      expect(page.lines[4]!.fontSize, page.fontSize);
      expect(page.lines[4]!.wordSpacing, 0);
      expect(page.lines[4]!.stretch, 1);
      expect(page.lines[3], isNull);
    });

    test('a line of one word is left as typeset', () {
      final page = PageFit.of(
        space: const Size(320, 2000),
        natural: [16, 6],
        centred: [false, false],
        gaps: [9, 0],
      );
      expect(page.lines[1]!.stretch, 1);
      expect(page.lines[1]!.wordSpacing, 0);
    });

    test('a short screen shrinks the type so every line still fits', () {
      final page = fit(const Size(320, 100));
      expect(page.pitch * 5, lessThanOrEqualTo(100.01));
      expect(page.fontSize * PageFit.tightest, closeTo(20, 0.01));
      expect(page.width, lessThan(320));
      for (final (index, em) in [16.0, 15.0, 12.0].indexed) {
        expect(
          drawn(page.lines[index]!, em, [9, 8, 7][index]),
          closeTo(page.width, 0.01),
        );
      }
    });

    test('a tall screen does not pull the lines apart', () {
      final page = fit(const Size(320, 5000));
      expect(page.pitch, closeTo(page.fontSize * PageFit.loosest, 0.01));
    });

    test('with no height to meet, the width alone sets the size', () {
      final page = fit(const Size(320, double.infinity));
      expect(page.width, closeTo(320, 0.01));
      expect(page.fontSize, closeTo(fit(const Size(320, 5000)).fontSize, 0.01));
      expect(page.pitch, closeTo(page.fontSize * PageFit.comfortable, 0.01));
    });
  });

  Future<void> pumpPages(
    WidgetTester tester, {
    int? surah,
    int? page,
    int? hafsAyah,
    Size size = const Size(392, 850),
    double textScale = 1,
    MushafLibrary? library,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: MushafPagesScreen(
          surah: surah,
          page: page,
          hafsAyah: hafsAyah,
          library: library ?? MushafLibrary(),
          translations: meanings(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  MushafPage shown(WidgetTester tester) =>
      tester.widget<MushafPage>(find.byType(MushafPage).first);

  group('The printed pages', () {
    testWidgets('open at a surah and turn like the book', (tester) async {
      await pumpPages(tester, surah: 2);
      expect(find.text('Al-Baqara'), findsOneWidget);
      expect(find.text('Page 2 of 604, juz 1'), findsOneWidget);
      expect(shown(tester).page, 2);
      expect(find.text('سورة البقرة'), findsWidgets);
      expect(find.textContaining('Swipe to turn the page'), findsOneWidget);

      // The next page comes in from the left, as in the mushaf.
      await tester.drag(find.byType(PageView), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(find.text('Page 3 of 604, juz 1'), findsOneWidget);
      // Fifteen lines of text, each one paragraph in the mushaf's font.
      final lines = tester.widgetList<RichText>(
        find.descendant(
          of: find.byWidgetPredicate(
            (widget) => widget is MushafPage && widget.page == 3,
          ),
          matching: find.byType(RichText),
        ),
      );
      final mushafLines = lines.where(
        (line) => line.text.style?.fontFamily == 'kfgqpc_hafs',
      );
      expect(mushafLines, hasLength(15));
      for (final line in mushafLines) {
        expect(line.maxLines, 1);
        expect(line.textDirection, TextDirection.rtl);
      }
      // Dragging the other way goes back.
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('Page 2 of 604, juz 1'), findsOneWidget);
      // The place is kept for "Continue reading".
      final place = await QuranService.instance.lastRead();
      expect(place?.page, 2);
      expect(place?.surah, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tapped verse opens its meaning, tafsir and audio', (
      tester,
    ) async {
      await pumpPages(tester, page: 604);
      expect(find.text('Al-Ikhlaas, Al-Falaq, An-Naas'), findsOneWidget);
      // The first line of verses on the page: Al-Ikhlas. (The banner and
      // the basmalah above it are drawn in the same font and come first.)
      final line = find
          .descendant(
            of: find.byType(MushafPage),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is RichText &&
                  widget.text.style?.fontFamily == 'kfgqpc_hafs',
            ),
          )
          .at(2);
      await tester.tapAt(tester.getTopRight(line) + const Offset(-6, 12));
      await tester.pumpAndSettle();
      expect(find.text('Al-Ikhlaas 112:1'), findsOneWidget);
      expect(find.text('Meaning 112:1'), findsOneWidget);
      expect(find.text('Tafsir'), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);
      // Handwritten notes belong to the flowing page.
      expect(find.text('Note'), findsNothing);
      expect(shown(tester).selected?.number, 1);
      expect(find.textContaining('Swipe to turn the page'), findsNothing);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(shown(tester).selected, isNull);
    });

    testWidgets('open at a bookmarked verse and mark it', (tester) async {
      await pumpPages(tester, surah: 2, hafsAyah: 255);
      expect(find.text('Page 42 of 604, juz 3'), findsOneWidget);
      expect(shown(tester).selected?.number, 255);
    });

    testWidgets('go to a page by its number', (tester) async {
      await pumpPages(tester, surah: 1);
      await tester.tap(find.byTooltip('Go to page'));
      await tester.pumpAndSettle();
      expect(find.text('Page, 1 to 604'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '700');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Go'))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), '50');
      await tester.pump();
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(find.text("Aal-i-Imraan"), findsOneWidget);
      expect(find.text('Page 50 of 604, juz 3'), findsOneWidget);
    });

    testWidgets('carry the colour key, which opens what the colours mean', (
      tester,
    ) async {
      await pumpPages(tester, surah: 2);
      expect(find.byType(TajweedLegend), findsOneWidget);
      expect(find.text('Qalqalah'), findsOneWidget);
      expect(find.text('قلقلة'), findsOneWidget);
      await tester.tap(find.byType(TajweedLegend));
      await tester.pumpAndSettle();
      expect(find.text('Tajweed colours'), findsOneWidget);
      expect(find.textContaining('A light echo on'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      // The plain copy has no colours and no key.
      await tester.pumpWidget(const SizedBox.shrink());
      final library = MushafLibrary();
      await library.choose(MushafLibrary.edition('hafs'));
      await pumpPages(tester, surah: 2, library: library);
      expect(find.byType(TajweedLegend), findsNothing);
      expect(shown(tester).pages.text.edition.id, 'hafs');
    });

    testWidgets('give way to flowing text when it is chosen', (tester) async {
      await pumpPages(tester, page: 50);
      await tester.tap(find.byTooltip('Mushaf and page'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('each line as it is printed'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Flowing text'));
      await tester.pumpAndSettle();
      expect(find.byType(QuranReaderScreen), findsOneWidget);
      expect(find.byType(MushafPagesScreen), findsNothing);
      expect(find.byType(MushafBlock), findsWidgets);
      expect(find.text('Aal-i-Imraan'), findsOneWidget);
      expect(await MushafPagesScreen.preferred(), isFalse);
      // The flowing page keeps the colour key too.
      expect(find.byType(TajweedLegend), findsOneWidget);

      // And back again.
      await tester.tap(find.byTooltip('Mushaf and text size'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Printed pages'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Printed pages'));
      await tester.pumpAndSettle();
      expect(find.byType(MushafPagesScreen), findsOneWidget);
      expect(find.text('Page 50 of 604, juz 3'), findsOneWidget);
      expect(await MushafPagesScreen.preferred(), isTrue);
    });

    testWidgets('hand a riwayah without a page layout to flowing text', (
      tester,
    ) async {
      final library = MushafLibrary();
      await pumpPages(tester, surah: 1, library: library);
      await tester.tap(find.byTooltip('Mushaf and page'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Warsh from Nafi'"));
      await tester.pumpAndSettle();
      expect(find.byType(QuranReaderScreen), findsOneWidget);
      expect(library.current.value.id, 'warsh');
      expect(find.textContaining('opens as flowing text'), findsOneWidget);
      final block = tester.widget<MushafBlock>(find.byType(MushafBlock).first);
      expect(block.edition.fontFamily, 'kfgqpc_warsh');
    });

    for (final size in const [Size(320, 568), Size(360, 740), Size(800, 400)]) {
      testWidgets('fit $size with large system text', (tester) async {
        await pumpPages(tester, page: 3, size: size, textScale: 2);
        expect(tester.takeException(), isNull);
        final page = tester.getRect(find.byType(MushafPage).first);
        final lines = find.descendant(
          of: find.byType(MushafPage).first,
          matching: find.byType(FittedBox),
        );
        expect(lines, findsNWidgets(15));
        // A phone held sideways keeps the page wide and scrolls it.
        final sideways = size.width > size.height;
        expect(
          find.descendant(
            of: find.byType(MushafPage).first,
            matching: find.byType(SingleChildScrollView),
          ),
          sideways ? findsOneWidget : findsNothing,
        );
        for (final element in lines.evaluate()) {
          final box = element.renderObject! as RenderBox;
          final rect = box.localToGlobal(Offset.zero) & box.size;
          expect(rect.left, greaterThanOrEqualTo(page.left - 0.5));
          expect(rect.right, lessThanOrEqualTo(page.right + 0.5));
          expect(rect.height, greaterThan(0));
          if (!sideways) {
            // Upright, every line of the page is in view at once.
            expect(rect.top, greaterThanOrEqualTo(page.top - 0.5));
            expect(rect.bottom, lessThanOrEqualTo(page.bottom + 0.5));
          }
        }
        await tester.tap(find.byTooltip('Mushaf and page'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Every row of the sheet: the mushafs, the page choice, the rest.
        await tester.scrollUntilVisible(
          find.text('What the colours mean'),
          150,
          scrollable: find.byType(Scrollable).last,
          maxScrolls: 200,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('What the colours mean'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('What the colours mean'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.textContaining('The colours are the Hafs tajweed key'),
          150,
          scrollable: find.byType(Scrollable).last,
          maxScrolls: 200,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('The surah list', () {
    Future<void> pumpIndex(WidgetTester tester, MushafLibrary library) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(392, 850);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: QuranIndexScreen(library: library)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('opens Hafs as printed pages', (tester) async {
      await pumpIndex(tester, MushafLibrary());
      await tester.tap(find.text('Al-Faatiha'));
      await tester.pumpAndSettle();
      expect(find.byType(MushafPagesScreen), findsOneWidget);
      expect(find.text('Page 1 of 604, juz 1'), findsOneWidget);
    });

    testWidgets('opens flowing text when that was chosen', (tester) async {
      await MushafPagesScreen.prefer(printedPages: false);
      await pumpIndex(tester, MushafLibrary());
      await tester.tap(find.text('Al-Faatiha'));
      await tester.pumpAndSettle();
      expect(find.byType(QuranReaderScreen), findsOneWidget);
    });

    testWidgets('opens a riwayah without a layout as flowing text', (
      tester,
    ) async {
      final library = MushafLibrary();
      await library.choose(MushafLibrary.edition('warsh'));
      await pumpIndex(tester, library);
      await tester.tap(find.text('Al-Faatiha'));
      await tester.pumpAndSettle();
      expect(find.byType(QuranReaderScreen), findsOneWidget);
      expect(MushafPages.has(MushafLibrary.edition('warsh')), isFalse);
      expect(MushafPages.has(MushafLibrary.edition('hafs')), isTrue);
      expect(MushafPages.has(MushafLibrary.edition('hafs_tajweed')), isTrue);
    });
  });

  test('the layout file is the one the build recorded', () {
    final manifest =
        jsonDecode(File('tools/mushaf_pages_manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final bytes = File('asset/quran/hafs_pages.json').readAsBytesSync();
    expect(bytes.length, manifest['asset_bytes']);
    expect(sha256.convert(bytes).toString(), manifest['asset_sha256']);
    expect(manifest['pages'], 604);
    expect(manifest['text_lines'], 8820);
  });

  test('the layout asset keeps its plain name inside the app', () {
    expect(
      MushafPages.asset(MushafLibrary.edition('hafs_tajweed')),
      'asset/quran/hafs_pages.json',
    );
    expect(arabicDigits(604), '٦٠٤');
  });
}

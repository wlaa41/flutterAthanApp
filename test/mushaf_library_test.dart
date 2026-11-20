import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/models/quran_models.dart';
import 'package:flutter_pro/services/mushaf_library.dart';
import 'package:flutter_pro/services/quran_service.dart';
import 'package:flutter_pro/widgets/mushaf_block.dart';
import 'package:flutter_pro/widgets/reader_palette.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Marks that sit on a letter in the Hafs text.
bool isMark(int unit) =>
    (unit >= 0x064B && unit <= 0x065F) ||
    unit == 0x0670 ||
    (unit >= 0x06D6 && unit <= 0x06DC) ||
    (unit >= 0x06DF && unit <= 0x06E4) ||
    unit == 0x06E7 ||
    unit == 0x06E8 ||
    (unit >= 0x06EA && unit <= 0x06ED);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  MushafEdition edition(String id) => MushafLibrary.edition(id);

  test(
    'every bundled mushaf loads whole, in order and mapped to Hafs',
    () async {
      final library = MushafLibrary();
      final hafs = QuranService.surahList;
      for (final edition in MushafLibrary.editions) {
        final text = await library.load(edition);
        expect(text.edition.id, edition.id);
        expect(text.surahs.length, 114, reason: edition.id);
        expect(
          text.surahs.fold<int>(0, (sum, surah) => sum + surah.length),
          edition.ayahCount,
          reason: edition.id,
        );
        expect(text.basmalah.split(' ').length, 4, reason: edition.id);
        for (var s = 0; s < 114; s++) {
          final ayat = text.surahs[s];
          var covered = 0;
          for (var a = 0; a < ayat.length; a++) {
            final ayah = ayat[a];
            final where = '${edition.id} ${s + 1}:${a + 1}';
            expect(ayah.surah, s + 1, reason: where);
            expect(ayah.number, a + 1, reason: where);
            expect(ayah.text.trim(), isNotEmpty, reason: where);
            // The verse number is drawn by the reader, never stored in the text.
            expect(RegExp('[٠-٩]').hasMatch(ayah.text), isFalse, reason: where);
            expect(ayah.page, inInclusiveRange(1, 604), reason: where);
            expect(ayah.juz, inInclusiveRange(1, 30), reason: where);
            expect(ayah.hafsFrom, greaterThanOrEqualTo(1), reason: where);
            expect(
              ayah.hafsTo,
              greaterThanOrEqualTo(ayah.hafsFrom),
              reason: where,
            );
            expect(
              ayah.hafsTo,
              lessThanOrEqualTo(hafs[s].numberOfAyahs),
              reason: where,
            );
            expect(ayah.hafsFrom, greaterThanOrEqualTo(covered), reason: where);
            covered = ayah.hafsTo;
            if (edition.hafsNumbering) {
              expect(ayah.numberedAsHafs, isTrue, reason: where);
            }
          }
          if (edition.hafsNumbering) {
            expect(ayat.length, hafs[s].numberOfAyahs, reason: edition.id);
          }
          // Every mushaf ends each surah on the last Hafs verse of that surah.
          expect(
            ayat.last.hafsTo,
            hafs[s].numberOfAyahs,
            reason: '${edition.id} ${s + 1}',
          );
        }
      }
    },
  );

  test(
    'the basmalah heads a surah only where it is not a numbered verse',
    () async {
      final library = MushafLibrary();
      final hafs = await library.load(edition('hafs'));
      expect(hafs.surah(1).first.text, hafs.basmalah);
      expect(hafs.basmalahAbove(1), isFalse);
      expect(hafs.basmalahAbove(2), isTrue);
      expect(hafs.basmalahAbove(9), isFalse);
      expect(hafs.surah(112).length, 4);
      expect(
        String.fromCharCodes(
          hafs.surah(112).first.text.codeUnits.where((unit) => !isMark(unit)),
        ),
        'قل هو ٱلله أحد',
      );

      final warsh = await library.load(edition('warsh'));
      expect(warsh.basmalah, isNot(hafs.basmalah));
      expect(warsh.basmalahAbove(1), isTrue);
      expect(warsh.basmalahAbove(9), isFalse);
      final fatiha = warsh.surah(1);
      expect(fatiha.length, 7);
      // Warsh counts the Fatiha from "al-hamdu", which Hafs numbers 2, and
      // splits the last Hafs verse in two.
      expect([fatiha.first.hafsFrom, fatiha.first.hafsTo], [2, 2]);
      expect(fatiha[5].hafsTo, 7);
      expect(fatiha[6].hafsFrom, 7);
      expect(fatiha[6].hafsReference, '1:7');
      expect(warsh.surah(2).length, 285);
      expect(warsh.ayahForHafs(2, 286).number, 285);
      expect(warsh.ayahForHafs(1, 1).number, 1);
      expect(hafs.ayahForHafs(2, 255).number, 255);
    },
  );

  test('tajweed colour runs fit their verses and keep letters whole', () async {
    final library = MushafLibrary();
    final plain = await library.load(edition('hafs'));
    final coloured = await library.load(edition('hafs_tajweed'));
    var runs = 0;
    final seen = <int>{};
    for (var s = 0; s < 114; s++) {
      for (var a = 0; a < coloured.surahs[s].length; a++) {
        final ayah = coloured.surahs[s][a];
        // Colours never change the text itself.
        expect(ayah.text, plain.surahs[s][a].text);
        expect(plain.surahs[s][a].tajweed, isEmpty);
        final text = ayah.text;
        var at = 0;
        for (var i = 0; i < ayah.tajweed.length; i += 3) {
          final start = ayah.tajweed[i];
          final end = start + ayah.tajweed[i + 1];
          final where = '${s + 1}:${a + 1} run at $start';
          expect(ayah.tajweed.length % 3, 0, reason: where);
          expect(start, greaterThanOrEqualTo(at), reason: where);
          expect(end, greaterThan(start), reason: where);
          expect(end, lessThanOrEqualTo(text.length), reason: where);
          expect(
            ayah.tajweed[i + 2],
            inInclusiveRange(0, TajweedRule.values.length - 1),
          );
          // A colour starts on a letter and ends after that letter's marks,
          // so no letter is painted apart from its vowel signs.
          expect(isMark(text.codeUnitAt(start)), isFalse, reason: where);
          if (end < text.length) {
            expect(isMark(text.codeUnitAt(end)), isFalse, reason: where);
          }
          seen.add(ayah.tajweed[i + 2]);
          at = end;
          runs++;
        }
      }
    }
    expect(runs, greaterThan(59000));
    expect(seen.length, TajweedRule.values.length);
  });

  test(
    'coloured letters change colour only, which keeps them joined',
    () async {
      final text = await MushafLibrary().load(edition('hafs_tajweed'));
      for (final palette in [ReaderPalette.paper, ReaderPalette.dark]) {
        for (final rule in TajweedRule.values) {
          expect(palette.tajweed[rule], isNotNull, reason: rule.name);
        }
        for (final ayah in [...text.surah(1), ...text.surah(2).take(20)]) {
          final spans = MushafBlock.spansFor(ayah, palette).cast<TextSpan>();
          expect(
            spans.map((span) => span.text).join(),
            '${ayah.text} ${arabicDigits(ayah.number)}',
          );
          for (final span in spans) {
            final style = span.style;
            if (style == null) continue;
            // A weight, size or font change mid-word starts a new shaping run
            // and the letters on each side stop joining.
            expect(style.fontWeight, isNull);
            expect(style.fontSize, isNull);
            expect(style.fontFamily, isNull);
            expect(style.letterSpacing, isNull);
            expect(style.color, isNotNull);
          }
          expect(
            spans.where((span) => span.style != null).length,
            greaterThan(1),
          );
        }
      }
      expect(arabicDigits(255), '٢٥٥');
    },
  );

  test('no bundled file uses an extension the Android build rewrites', () {
    // Android unpacks *.gz assets and drops the extension, so the app would
    // ask for a file that is not in the APK. Tests alone would not notice.
    final gzipped = Directory('asset')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.gz'));
    expect(gzipped, isEmpty);
    for (final edition in MushafLibrary.editions) {
      expect(File(edition.asset).existsSync(), isTrue, reason: edition.asset);
      expect(
        File('asset/fonts/${edition.fontFamily}.ttf').existsSync(),
        isTrue,
        reason: edition.fontFamily,
      );
    }
  });

  test('the chosen mushaf is remembered', () async {
    final library = MushafLibrary();
    expect((await library.restoreChoice()).id, 'hafs_tajweed');
    await library.choose(edition('warsh'));
    expect(library.current.value.id, 'warsh');
    expect((await MushafLibrary().restoreChoice()).id, 'warsh');
    expect(MushafLibrary.edition('not-a-mushaf').id, 'hafs_tajweed');
    expect(edition('warsh').fontFamily, 'kfgqpc_warsh');
    expect(edition('hafs_tajweed').fontFamily, 'kfgqpc_hafs');
    expect(
      MushafLibrary.editions.map((e) => e.id).toSet().length,
      MushafLibrary.editions.length,
    );
  });

  test(
    'bookmark keys keep the old Hafs numbers and tell riwayat apart',
    () async {
      final library = MushafLibrary();
      final hafs = await library.load(edition('hafs'));
      final warsh = await library.load(edition('warsh'));
      final kursi = hafs.surah(2)[254];
      expect(QuranService.markKey(edition('hafs'), kursi), '262');
      expect(QuranService.markKey(edition('hafs_tajweed'), kursi), '262');
      expect(QuranService.markKey(edition('shouba'), kursi), '262');
      expect(
        QuranService.markKey(edition('warsh'), warsh.surah(2)[253]),
        'warsh:2:254',
      );

      final old = QuranService.parseMark('262')!;
      expect([old.surah, old.ayah, old.textId], [2, 255, null]);
      final first = QuranService.parseMark('1')!;
      expect([first.surah, first.ayah], [1, 1]);
      final last = QuranService.parseMark('6236')!;
      expect([last.surah, last.ayah], [114, 6]);
      final other = QuranService.parseMark('warsh:2:254')!;
      expect([other.surah, other.ayah, other.textId], [2, 254, 'warsh']);
      expect(QuranService.parseMark('0'), isNull);
      expect(QuranService.parseMark('6237'), isNull);
      expect(QuranService.parseMark('warsh:115:1'), isNull);
      expect(QuranService.parseMark('nonsense'), isNull);

      final service = QuranService();
      expect(await service.toggleBookmark('262'), isTrue);
      expect(await service.isBookmarked('262'), isTrue);
      expect(await service.toggleBookmark('warsh:2:254'), isTrue);
      expect(await service.bookmarks(), ['262', 'warsh:2:254']);
      expect(await service.toggleBookmark('262'), isFalse);
      expect(await service.bookmarks(), ['warsh:2:254']);

      await service.setHighlight('262', 0xFFFEF08A);
      await service.setHighlight('5', 0xFFA7F3D0);
      await service.setHighlight('5', null);
      expect(await service.highlights(), {'262': 0xFFFEF08A});

      expect(await service.lastRead(), isNull);
      await service.saveLastRead(
        const LastRead(surah: 2, page: 42, textId: 'hafs'),
      );
      final place = (await service.lastRead())!;
      expect([place.surah, place.page, place.textId], [2, 42, 'hafs']);
    },
  );
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/models/quran_models.dart';
import 'package:flutter_pro/services/disk_cache.dart';
import 'package:flutter_pro/services/quran_translation_service.dart';
import 'package:flutter_pro/services/tafsir_service.dart';
import 'package:flutter_pro/widgets/tafsir_html.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

Map<String, dynamic> byAyah(int id, String text, List<String> verses) => {
  'tafsir': {
    'verses': {for (final key in verses) key: <String, dynamic>{}},
    'resource_id': id,
    'text': text,
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory folder;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    folder = await Directory.systemTemp.createTemp('athan-tafsir-test');
  });
  tearDown(() => folder.delete(recursive: true));

  DiskCache disk(String name) => DiskCache(name, root: () async => folder);
  final offline = MockClient((_) async => http.Response('offline', 503));
  final ibnKathir = TafsirService.book(169);
  final muyassar = TafsirService.book(16);

  group('tafsir service', () {
    test('a verse is fetched once and then read from the phone', () async {
      final requests = <Uri>[];
      final service = TafsirService(
        cache: disk('tafsir'),
        client: MockClient((request) async {
          requests.add(request.url);
          return jsonResponse(
            byAyah(169, '<p>Light upon light</p>', ['24:35']),
          );
        }),
      );
      final first = await service.passage(ibnKathir, 24, 35);
      expect(
        [first.from, first.to, first.html],
        [35, 35, '<p>Light upon light</p>'],
      );
      await service.passage(ibnKathir, 24, 35);
      expect(
        requests.single.toString(),
        'https://api.quran.com/api/v4/tafsirs/169/by_ayah/24:35',
      );

      // A new launch with no connection still has it.
      final later = TafsirService(cache: disk('tafsir'), client: offline);
      expect((await later.passage(ibnKathir, 24, 35)).html, first.html);
      await expectLater(
        later.passage(ibnKathir, 24, 36),
        throwsA(isA<TafsirUnavailable>()),
      );
    });

    test('a piece that explains several verses serves all of them', () async {
      var requests = 0;
      final service = TafsirService(
        cache: disk('tafsir'),
        client: MockClient((request) async {
          requests++;
          return jsonResponse(
            byAyah(169, '<p>Together</p>', [
              '1:2',
              '1:3',
              '1:4',
              '1:5',
              '1:6',
              '1:7',
            ]),
          );
        }),
      );
      final passage = await service.passage(ibnKathir, 1, 3);
      expect([passage.from, passage.to], [2, 7]);
      expect((await service.passage(ibnKathir, 1, 7)).html, '<p>Together</p>');
      expect((await service.passage(ibnKathir, 1, 2)).from, 2);
      expect(requests, 1);
    });

    test('a short tafsir arrives a whole surah at a time', () async {
      final requests = <String>[];
      final service = TafsirService(
        cache: disk('tafsir'),
        client: MockClient((request) async {
          requests.add(
            request.url.path +
                (request.url.hasQuery ? '?${request.url.query}' : ''),
          );
          return jsonResponse({
            'tafsirs': [
              {
                'resource_id': 16,
                'verse_key': '112:1',
                'text': 'الأول والثاني',
              },
              {
                'resource_id': 16,
                'verse_key': '112:3',
                'text': 'الثالث والرابع',
              },
            ],
            'pagination': {'next_page': null},
          });
        }),
      );
      // Each piece runs up to the verse before the next piece.
      final second = await service.passage(muyassar, 112, 2);
      expect([second.from, second.to, second.html], [1, 2, 'الأول والثاني']);
      final fourth = await service.passage(muyassar, 112, 4);
      expect([fourth.from, fourth.to, fourth.html], [3, 4, 'الثالث والرابع']);
      expect(requests, ['/api/v4/tafsirs/16/by_chapter/112?per_page=300']);
      // The whole surah now reads offline.
      final later = TafsirService(cache: disk('tafsir'), client: offline);
      expect((await later.passage(muyassar, 112, 1)).html, 'الأول والثاني');
      expect((await later.passage(muyassar, 112, 3)).html, 'الثالث والرابع');
    });

    test(
      'falls back to the single verse when the surah request is unusable',
      () async {
        final requests = <String>[];
        final service = TafsirService(
          cache: disk('tafsir'),
          client: MockClient((request) async {
            requests.add(request.url.path);
            if (request.url.path.contains('by_chapter')) {
              return jsonResponse({
                'tafsirs': [
                  {'resource_id': 16, 'verse_key': '112:1', 'text': 'x'},
                ],
                'pagination': {'next_page': 2},
              });
            }
            return jsonResponse(byAyah(16, 'الآية الثانية', ['112:2']));
          }),
        );
        expect((await service.passage(muyassar, 112, 2)).html, 'الآية الثانية');
        expect(requests.length, 2);
      },
    );

    test('refuses a wrong or empty answer and keeps nothing', () async {
      for (final body in [
        byAyah(14, '<p>Another book</p>', ['2:255']),
        byAyah(169, '   ', ['2:255']),
        {'unexpected': true},
      ]) {
        final service = TafsirService(
          cache: disk('tafsir'),
          client: MockClient((_) async => jsonResponse(body)),
        );
        await expectLater(
          service.passage(ibnKathir, 2, 255),
          throwsA(isA<TafsirUnavailable>()),
        );
      }
      expect(await disk('tafsir').read('169/2.json'), isNull);
      final service = TafsirService(cache: disk('tafsir'), client: offline);
      await expectLater(service.passage(ibnKathir, 2, 287), throwsRangeError);
      await expectLater(service.passage(ibnKathir, 115, 1), throwsRangeError);
      expect(const TafsirUnavailable().toString(), contains('connection'));
    });

    test('the tafsir list has unique works, Arabic and English', () {
      final ids = TafsirService.books.map((book) => book.id).toSet();
      expect(ids.length, TafsirService.books.length);
      expect(TafsirService.books.where((book) => book.arabic), isNotEmpty);
      expect(TafsirService.books.where((book) => !book.arabic), isNotEmpty);
      expect(TafsirService.book(null).id, 16);
      expect(TafsirService.book(999999).id, 16);
    });
  });

  group('tafsir text', () {
    test('headings, paragraphs and marked spans become blocks', () {
      final blocks = parseTafsirHtml(
        '<h2>The Meaning of Iman</h2><p>Ibn `Abbas said,</p>'
        '<div class="arabic uthmani">يُؤْمِنُونَ</div>'
        '<p>(who have faith) means they <span class="blue">trust</span>.'
        ' <span class="reference brown">[1]</span></p>',
      );
      expect(blocks.map((block) => block.text), [
        'The Meaning of Iman',
        'Ibn `Abbas said,',
        'يُؤْمِنُونَ',
        '(who have faith) means they trust. [1]',
      ]);
      expect(blocks.map((block) => block.heading), [2, 0, 0, 0]);
      expect(blocks.map((block) => block.rtl), [false, false, true, false]);
      expect(blocks[2].quotation, isTrue);
      expect(blocks[3].quotation, isFalse);
      expect(blocks[3].runs.map((run) => run.tone), [
        null,
        TafsirTone.blue,
        null,
        TafsirTone.reference,
      ]);
    });

    test('Arabic text with no paragraph tags is one right-to-left block', () {
      final blocks = parseTafsirHtml(
        'أبتدئ قراءة القرآن باسم الله مستعينا به، '
        '<span class="green">(اللهِ)</span> علم على الرب',
      );
      expect(blocks.length, 1);
      expect(blocks.single.rtl, isTrue);
      expect(blocks.single.runs[1].tone, TafsirTone.green);
      expect(
        parseTafsirHtml(
          '<p lang="ar" class="ar ">قال <span class="arabic qpc-hafs brown">{ قُلْ }</span></p>',
        ).single.runs.last.tone,
        TafsirTone.quran,
      );
      expect(parseTafsirHtml('الأولى\n\nالثانية').map((b) => b.text), [
        'الأولى',
        'الثانية',
      ]);
    });

    test('odd markup loses no words', () {
      expect(
        parseTafsirHtml(
          '<p>Tom &amp; Jerry&nbsp;said &#39;hi&#39; &quot;x&quot; &bogus;</p>',
        ).single.text,
        'Tom & Jerry said \'hi\' "x" &bogus;',
      );
      expect(
        parseTafsirHtml(
          '<foo>keep</foo><script>drop()</script> this<br/>and that',
        ).map((block) => block.text),
        ['keep this', 'and that'],
      );
      final loose = parseTafsirHtml(
        '<p>one <span class="red">two</p>three</span>',
      );
      expect(loose.map((block) => block.text), ['one two', 'three']);
      expect(loose.last.runs.single.tone, isNull);
      expect(
        parseTafsirHtml('<p>  spaced \n  out  </p>').single.text,
        'spaced out',
      );
      expect(parseTafsirHtml(''), isEmpty);
      expect(parseTafsirHtml('<p></p> <p> </p>'), isEmpty);
      expect(parseTafsirHtml('a < b and c > d').single.text, 'a < b and c > d');
      final strong = parseTafsirHtml(
        '<p><strong>Bold</strong> and <em>slanted</em></p>',
      ).single;
      expect(strong.runs.first.bold, isTrue);
      expect(strong.runs.last.italic, isTrue);
    });
  });

  group('translation', () {
    Map<String, dynamic> surah112(List<String> texts, {int number = 112}) => {
      'code': 200,
      'data': {
        'number': number,
        'edition': {'identifier': 'en.sahih'},
        'ayahs': [
          for (var index = 0; index < texts.length; index++)
            {'numberInSurah': index + 1, 'text': texts[index]},
        ],
      },
    };
    const meanings = [
      'Say, He is One',
      'The Eternal Refuge',
      'He neither begets',
      'Nor is there an equal',
    ];

    test('a surah is fetched once, checked and kept on the phone', () async {
      var requests = 0;
      final service = QuranTranslationService(
        cache: disk('meaning'),
        client: MockClient((request) async {
          requests++;
          expect(
            request.url.toString(),
            'https://api.alquran.cloud/v1/surah/112/en.sahih',
          );
          return jsonResponse(surah112(meanings));
        }),
      );
      expect(await service.surah(112), meanings);
      expect(await service.surah(112), meanings);
      expect(requests, 1);
      final later = QuranTranslationService(
        cache: disk('meaning'),
        client: offline,
      );
      expect(await later.surah(112), meanings);
      await expectLater(later.surah(113), throwsFormatException);
      await expectLater(later.surah(0), throwsRangeError);
    });

    test(
      'another surah, a short surah or shuffled verses are refused',
      () async {
        for (final body in [
          surah112(meanings, number: 1),
          surah112(meanings.take(3).toList()),
          surah112(['a', 'b', '', 'd']),
          {
            'code': 200,
            'data': {
              'number': 112,
              'edition': {'identifier': 'en.sahih'},
              'ayahs': [
                for (final n in [2, 1, 3, 4]) {'numberInSurah': n, 'text': 'x'},
              ],
            },
          },
        ]) {
          final service = QuranTranslationService(
            cache: disk('meaning'),
            client: MockClient((_) async => jsonResponse(body)),
          );
          await expectLater(service.surah(112), throwsFormatException);
        }
        expect(await disk('meaning').read('112.json'), isNull);
      },
    );

    test('meanings saved by earlier versions are carried over', () async {
      SharedPreferences.setMockInitialValues({
        'surah_detail_112': jsonEncode([
          for (final text in meanings)
            {'translation': text, 'tajweedText': 'x'},
        ]),
        'surah_detail_113': jsonEncode([
          {'translation': 'only one verse'},
        ]),
      });
      final service = QuranTranslationService(
        cache: disk('meaning'),
        client: offline,
      );
      expect(await service.surah(112), meanings);
      await expectLater(service.surah(113), throwsFormatException);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('surah_detail_112'), isFalse);
      expect(prefs.containsKey('surah_detail_113'), isFalse);
      expect(jsonDecode((await disk('meaning').read('112.json'))!), meanings);
    });

    test('a verse of another riwayah takes the meaning of its Hafs verses', () {
      MushafAyah ayah(int number, int from, int to) => MushafAyah(
        surah: 112,
        number: number,
        text: 'x',
        page: 604,
        juz: 30,
        hafsFrom: from,
        hafsTo: to,
      );
      expect(
        QuranTranslationService.forAyah(meanings, ayah(1, 1, 1)),
        meanings[0],
      );
      expect(
        QuranTranslationService.forAyah(meanings, ayah(2, 2, 3)),
        '${meanings[1]} ${meanings[2]}',
      );
      expect(
        QuranTranslationService.forAyah(meanings, ayah(4, 4, 9)),
        meanings[3],
      );
    });
  });
}

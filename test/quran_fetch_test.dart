import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/models/quran_models.dart';
import 'package:flutter_pro/services/quran_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Map<String, dynamic> apiSurah(
    int number,
    List<Ayah> ayahs,
    String edition,
  ) =>
      {
        'number': number,
        'edition': {'identifier': edition},
        'ayahs': ayahs
            .map(
              (ayah) => {
                'number': ayah.number,
                'numberInSurah': ayah.numberInSurah,
                'juz': ayah.juz,
                'page': ayah.page,
                'text':
                    edition == 'en.sahih' ? ayah.translation : ayah.tajweedText,
              },
            )
            .toList(),
      };

  test('Offline unavailable Surah never substitutes Al-Fatiha', () async {
    final service = QuranService(
      client: MockClient((_) async => http.Response('offline', 503)),
    );
    await expectLater(service.getSurahAyahs(2), throwsFormatException);
    expect((await service.getSurahAyahs(1)).length, 7);
    expect((await service.getSurahAyahs(112)).first.number, 6222);
  });

  test('Rejects wrong Surah stored under another cache key', () async {
    SharedPreferences.setMockInitialValues({
      'surah_detail_2': jsonEncode(
        QuranService.offlineFatiha.map((a) => a.toJson()).toList(),
      ),
    });
    final service = QuranService(
      client: MockClient((_) async => http.Response('offline', 503)),
    );
    await expectLater(service.getSurahAyahs(2), throwsFormatException);
    expect(
      (await SharedPreferences.getInstance()).containsKey('surah_detail_2'),
      isFalse,
    );
  });

  test('Validated cached Surah makes no network request', () async {
    SharedPreferences.setMockInitialValues({
      'surah_detail_112': jsonEncode(
        QuranService.offlineIkhlas.map((a) => a.toJson()).toList(),
      ),
    });
    var requests = 0;
    final service = QuranService(
      client: MockClient((_) async {
        requests++;
        return http.Response('offline', 503);
      }),
    );
    expect((await service.getSurahAyahs(112)).length, 4);
    expect(requests, 0);
  });

  test(
    'Matches editions by identity, validates and caches Arabic UTF-8',
    () async {
      final service = QuranService(
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'code': 200,
                'data': [
                  apiSurah(112, QuranService.offlineIkhlas, 'en.sahih'),
                  apiSurah(112, QuranService.offlineIkhlas, 'quran-tajweed'),
                ],
              }),
            ),
            200,
          ),
        ),
      );
      final loaded = await service.getSurahAyahs(112);
      // Preserve the API's Arabic spelling, including alif wasla.
      expect(
        loaded.first.cleanText,
        'قُلْ هُوَ ٱللَّهُ أَحَدٌ',
      );
      expect(
        (await SharedPreferences.getInstance()).containsKey('surah_detail_112'),
        isTrue,
      );
    },
  );

  test('Wrong API Surah is not cached or displayed for the request', () async {
    final service = QuranService(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 200,
              'data': [
                apiSurah(1, QuranService.offlineFatiha, 'quran-tajweed'),
                apiSurah(1, QuranService.offlineFatiha, 'en.sahih'),
              ],
            }),
          ),
          200,
        ),
      ),
    );
    await expectLater(service.getSurahAyahs(2), throwsFormatException);
    expect(
      (await SharedPreferences.getInstance()).containsKey('surah_detail_2'),
      isFalse,
    );
  });

  test('Partial cached chapter is rejected', () async {
    SharedPreferences.setMockInitialValues({
      'surah_detail_112': jsonEncode(
        QuranService.offlineIkhlas.take(2).map((a) => a.toJson()).toList(),
      ),
    });
    final service = QuranService(
      client: MockClient((_) async => http.Response('offline', 503)),
    );
    expect((await service.getSurahAyahs(112)).length, 4);
    expect(
      (await SharedPreferences.getInstance()).containsKey('surah_detail_112'),
      isFalse,
    );
  });
}

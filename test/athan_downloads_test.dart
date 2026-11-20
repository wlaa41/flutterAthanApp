import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/models/athan_download.dart';
import 'package:flutter_pro/services/athan_catalog.dart';
import 'package:flutter_pro/services/athan_downloads.dart';
import 'package:flutter_pro/services/mp3_cutter.dart';
import 'package:flutter_pro/services/sound_library.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support_mp3.dart';

void main() {
  late Directory root;
  late Directory folder;
  var requests = 0;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('athans');
    folder = Directory('${root.path}/alert_sounds');
    requests = 0;
  });
  tearDown(() => root.deleteSync(recursive: true));

  final recording = fakeMp3(400, id3v2: true, id3v1: true);

  AthanDownload entry(
    String id, {
    Uint8List? data,
    String? cutFrom,
    Duration cutStart = Duration.zero,
  }) {
    final bytes = data ?? recording;
    return AthanDownload(
      id: id,
      name: 'Athan $id',
      arabicName: 'أذان',
      place: 'Somewhere',
      seconds: 10,
      bytes: bytes.length,
      sha256: sha256.convert(bytes).toString(),
      url: 'https://example.org/$id.mp3',
      source: 'A test',
      cutFrom: cutFrom,
      cutStart: cutStart,
    );
  }

  /// Serves [body] in small pieces, the way a network does.
  AthanDownloads serving(
    List<int> body, {
    int status = 200,
    List<AthanDownload>? catalog,
  }) => AthanDownloads(
    catalog: catalog ?? [entry('full')],
    folder: () async => folder,
    client: () => MockClient.streaming((request, _) async {
      requests++;
      return http.StreamedResponse(
        Stream.fromIterable([
          for (var at = 0; at < body.length; at += 5000)
            body.sublist(at, (at + 5000).clamp(0, body.length)),
        ]),
        status,
      );
    }),
  );

  List<String> stored() => folder.existsSync()
      ? (folder.listSync().map((f) => f.uri.pathSegments.last).toList()..sort())
      : [];

  group('The catalogue', () {
    test('names the athans that were asked for, first', () {
      final ids = athanCatalog.map((athan) => athan.id).toList();
      expect(ids.take(3), ['qassas_madinah', 'jazi_full', 'jazi_short']);
      expect(athanCatalog.take(3).every((athan) => athan.featured), isTrue);
      expect(athanCatalog.skip(3).any((athan) => athan.featured), isFalse);
      expect(athanCatalog[0].arabicName, 'محمد بن مروان قصاص');
      expect(athanCatalog[1].arabicName, contains('محمد جازي'));
      expect(athanCatalog[2].arabicName, contains('محمد جازي'));
      expect(athanCatalog[2].seconds, lessThan(athanCatalog[1].seconds));
      expect(athanCatalog.length, greaterThanOrEqualTo(15));
    });

    test('can fetch and check every entry', () {
      final ids = <String>{};
      for (final athan in athanCatalog) {
        expect(ids.add(athan.id), isTrue, reason: athan.id);
        expect(athan.id, matches(RegExp(r'^[a-z0-9_]+$')));
        expect(Uri.parse(athan.url).scheme, 'https', reason: athan.id);
        expect(athan.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(athan.bytes, inInclusiveRange(200000, SoundLibrary.maxBytes));
        expect(athan.seconds, inInclusiveRange(60, 600), reason: athan.id);
        expect(athan.name, isNotEmpty);
        expect(athan.arabicName, isNotEmpty);
        expect(athan.source, isNotEmpty);
        // Every sound in the app has its own id; added athans keep theirs apart.
        expect(
          SoundCatalog.builtIns.any((sound) => sound.id == athan.soundId),
          isFalse,
        );
      }
    });

    test('makes a shorter athan only from a whole recording it lists', () {
      for (final athan in athanCatalog.where((a) => a.cutFrom != null)) {
        final parent = athanCatalog.singleWhere((a) => a.id == athan.cutFrom);
        expect(parent.cutFrom, isNull);
        expect(athan.url, parent.url);
        expect(athan.bytes, parent.bytes);
        expect(athan.sha256, parent.sha256);
        expect(athan.cutStart.inSeconds, inExclusiveRange(0, parent.seconds));
        expect(
          athan.seconds,
          closeTo(parent.seconds - athan.cutStart.inSeconds, 2),
        );
      }
    });

    test('is the list written from the source record', () async {
      final record =
          jsonDecode(await File('tools/athan_downloads.json').readAsString())
              as Map<String, dynamic>;
      final athans = (record['athans'] as List).cast<Map<String, dynamic>>();
      expect(athans.map((a) => a['id']), athanCatalog.map((a) => a.id));
      for (final (index, athan) in athans.indexed) {
        if (athan['cut_from'] != null) continue;
        expect(athanCatalog[index].sha256, athan['sha256']);
        expect(athanCatalog[index].url, athan['url']);
        expect(athanCatalog[index].bytes, athan['bytes']);
        expect(athan['permission'], isNotEmpty);
      }
    });
  });

  group('Adding an athan', () {
    test('keeps a recording that matches, and reports progress', () async {
      final downloads = serving(recording);
      final progress = <double>[];
      final sound = await downloads.add(
        entry('full'),
        onProgress: progress.add,
      );
      expect(sound.id, 'dl_full');
      expect(sound.kind, SoundKind.athan);
      expect(sound.canPreview, isTrue);
      expect(File(sound.filePath!).readAsBytesSync(), recording);
      expect(stored(), ['dl_full.mp3']);
      expect(progress.last, 1);
      expect(progress, orderedEquals([...progress]..sort()));
      expect(progress.length, greaterThan(3));
      expect((await downloads.sounds()).single.id, 'dl_full');
    });

    test('does not fetch what is already on the phone', () async {
      final downloads = serving(recording);
      await downloads.add(entry('full'));
      await downloads.add(entry('full'));
      expect(requests, 1);
    });

    test('lists only athans that were added and are still there', () async {
      final downloads = serving(recording);
      // A stray file is not an added athan.
      folder.createSync(recursive: true);
      File('${folder.path}/dl_full.mp3').writeAsBytesSync(recording);
      expect(await downloads.sounds(), isEmpty);
      // Adding it adopts the file without another fetch.
      await downloads.add(entry('full'));
      expect(requests, 0);
      expect((await downloads.sounds()).single.id, 'dl_full');
      // An athan whose file was lost is offered again, not listed.
      File('${folder.path}/dl_full.mp3').deleteSync();
      expect(await downloads.sounds(), isEmpty);
      await downloads.add(entry('full'));
      expect(requests, 1);
      expect((await downloads.sounds()).single.id, 'dl_full');
    });

    test('fetches once when Add is pressed twice', () async {
      final downloads = serving(recording);
      await Future.wait([
        downloads.add(entry('full')),
        downloads.add(entry('full')),
      ]);
      expect(requests, 1);
      expect(stored(), ['dl_full.mp3']);
    });

    test('refuses a recording that is not the recorded one', () async {
      final other = Uint8List.fromList(recording)..[5000] ^= 1;
      final downloads = serving(other);
      await expectLater(
        downloads.add(entry('full')),
        throwsA(
          isA<AthanDownloadFailure>().having(
            (failure) => failure.message,
            'message',
            contains('no longer serves'),
          ),
        ),
      );
      expect(stored(), isEmpty);
      expect(await downloads.sounds(), isEmpty);
    });

    test('stops when the source sends more than was recorded', () async {
      final downloads = serving([...recording, ...recording]);
      await expectLater(
        downloads.add(entry('full')),
        throwsA(isA<AthanDownloadFailure>()),
      );
      expect(stored(), isEmpty);
    });

    test('refuses a recording that stops short', () async {
      final downloads = serving(recording.sublist(0, 9000));
      await expectLater(
        downloads.add(entry('full')),
        throwsA(isA<AthanDownloadFailure>()),
      );
      expect(stored(), isEmpty);
    });

    test('says so when the source answers with an error', () async {
      final downloads = serving(utf8.encode('gone'), status: 404);
      await expectLater(
        downloads.add(entry('full')),
        throwsA(
          isA<AthanDownloadFailure>().having(
            (failure) => failure.message,
            'message',
            contains('404'),
          ),
        ),
      );
      expect(stored(), isEmpty);
    });

    test('asks for a connection when the phone is offline', () async {
      final downloads = AthanDownloads(
        catalog: [entry('full')],
        folder: () async => folder,
        client: () => MockClient(
          (_) async => throw const SocketException('No route to host'),
        ),
      );
      await expectLater(
        downloads.add(entry('full')),
        throwsA(
          isA<AthanDownloadFailure>().having(
            (failure) => failure.message,
            'message',
            contains('connection'),
          ),
        ),
      );
      expect(stored(), isEmpty);
    });

    test('can be tried again after a failure', () async {
      await expectLater(
        serving(utf8.encode('gone'), status: 503).add(entry('full')),
        throwsA(isA<AthanDownloadFailure>()),
      );
      await serving(recording).add(entry('full'));
      expect(stored(), ['dl_full.mp3']);
    });
  });

  group('A shorter athan', () {
    const from = Duration(seconds: 4);
    final short = entry('short', cutFrom: 'full', cutStart: from);
    final catalog = [entry('full'), short];

    test('is the end of the whole recording, which is kept too', () async {
      final downloads = serving(recording, catalog: catalog);
      final sound = await downloads.add(short);
      expect(sound.id, 'dl_short');
      expect(requests, 1);
      expect(stored(), ['dl_full.mp3', 'dl_short.mp3']);
      final cut = File(sound.filePath!).readAsBytesSync();
      expect(cut, Mp3Cutter.tail(recording, from));
      expect(Mp3Cutter.firstFrame(cut), 0);
      expect(
        Mp3Cutter.duration(cut)!.inMilliseconds,
        closeTo(Mp3Cutter.duration(recording)!.inMilliseconds - 4000, 30),
      );
      expect((await downloads.sounds()).map((s) => s.id), [
        'dl_full',
        'dl_short',
      ]);
    });

    test('needs no network when the whole recording is on the phone', () async {
      final downloads = serving(recording, catalog: catalog);
      await downloads.add(catalog.first);
      await downloads.add(short);
      expect(requests, 1);
      expect(stored(), ['dl_full.mp3', 'dl_short.mp3']);
    });

    test('is not made from a recording that fails its check', () async {
      final other = Uint8List.fromList(recording)..[5000] ^= 1;
      final downloads = serving(other, catalog: catalog);
      await expectLater(
        downloads.add(short),
        throwsA(isA<AthanDownloadFailure>()),
      );
      expect(stored(), isEmpty);
    });

    test('stays when the whole recording is removed', () async {
      final downloads = serving(recording, catalog: catalog);
      await downloads.add(short);
      await downloads.remove(catalog.first);
      expect(stored(), ['dl_short.mp3']);
      expect((await downloads.sounds()).single.id, 'dl_short');
      await downloads.remove(short);
      expect(await downloads.sounds(), isEmpty);
    });
  });
}

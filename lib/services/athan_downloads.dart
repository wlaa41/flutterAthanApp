import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/athan_download.dart';
import 'athan_catalog.dart';
import 'mp3_cutter.dart';
import 'sound_library.dart';

/// Why an athan could not be added, in words for the person adding it.
class AthanDownloadFailure implements Exception {
  const AthanDownloadFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Adds athans from the catalogue to the phone and lists the ones already
/// there. A recording gets its final name only after it has passed its size
/// and checksum test. The ids of the added athans are kept in preferences, so
/// a phone with none never has to look at its storage to list its sounds.
class AthanDownloads {
  AthanDownloads({
    http.Client Function()? client,
    Future<Directory> Function()? folder,
    this.catalog = athanCatalog,
  }) : _client = client ?? http.Client.new,
       _folder = folder ?? _privateFolder;

  static AthanDownloads instance = AthanDownloads();

  static const _addedKey = 'added_athans_v1';
  static const _changed = AthanDownloadFailure(
    'The source no longer serves this recording, so it was not added.',
  );
  static const _unreachable = AthanDownloadFailure(
    'Could not reach the recording. Check your connection and try again.',
  );

  /// The athans on offer, in the order they are shown.
  final List<AthanDownload> catalog;
  final http.Client Function() _client;
  final Future<Directory> Function() _folder;
  final _adding = <String, Future<void>>{};

  /// The same private folder that holds audio added from the phone.
  static Future<Directory> _privateFolder() async => Directory(
    '${(await getApplicationSupportDirectory()).path}/alert_sounds',
  );

  AthanDownload? byId(String id) {
    for (final athan in catalog) {
      if (athan.id == id) return athan;
    }
    return null;
  }

  static bool isAddedSound(String soundId) => soundId.startsWith('dl_');

  static SoundOption _sound(AthanDownload athan, String path) => SoundOption(
    id: athan.soundId,
    name: athan.name,
    description: '${athan.place} · ${athan.length} · saved on this phone',
    kind: SoundKind.athan,
    filePath: path,
  );

  /// The added athans, as sounds a reminder can play.
  Future<List<SoundOption>> sounds() async {
    final prefs = await SharedPreferences.getInstance();
    final added = prefs.getStringList(_addedKey) ?? const <String>[];
    if (added.isEmpty) return const [];
    // The folder is looked up each time: iOS can move an app's container.
    final folder = (await _folder()).path;
    return [
      for (final athan in catalog)
        if (added.contains(athan.id) &&
            await File('$folder/${athan.fileName}').exists())
          _sound(athan, '$folder/${athan.fileName}'),
    ];
  }

  Future<void> _record(Iterable<String> add, {String? remove}) async {
    final prefs = await SharedPreferences.getInstance();
    final added = {...?prefs.getStringList(_addedKey), ...add}..remove(remove);
    if (!await prefs.setStringList(_addedKey, added.toList())) {
      throw const FileSystemException('The added athans could not be saved');
    }
  }

  /// Fetches [athan], checks it and keeps it. [onProgress] runs from 0 to 1.
  /// Throws an [AthanDownloadFailure] and leaves nothing behind when the
  /// recording cannot be fetched or is not the one the catalogue describes.
  Future<SoundOption> add(
    AthanDownload athan, {
    void Function(double fraction)? onProgress,
  }) async {
    final folder = await _folder();
    final target = File('${folder.path}/${athan.fileName}');
    // One fetch per recording, even when Add is pressed twice. The callback
    // must not return the stored future: whenComplete would wait for it, and
    // it is the very future being completed.
    await (_adding[athan.id] ??= _add(athan, folder, target, onProgress)
        .whenComplete(() {
          _adding.remove(athan.id);
        }));
    return _sound(athan, target.path);
  }

  Future<void> remove(AthanDownload athan) async {
    await _record(const [], remove: athan.id);
    final file = File('${(await _folder()).path}/${athan.fileName}');
    if (await file.exists()) await file.delete();
  }

  Future<void> _add(
    AthanDownload athan,
    Directory folder,
    File target,
    void Function(double)? onProgress,
  ) async {
    try {
      await folder.create(recursive: true);
      final kept = [athan.id];
      final parentId = athan.cutFrom;
      if (await target.exists()) {
        // Left by an earlier attempt that could not record it.
      } else if (parentId == null) {
        await _fetch(athan, target, onProgress);
      } else {
        // A shorter athan is the end of a longer one. The longer recording
        // is fetched once and kept, so both become available.
        final parent = byId(parentId);
        if (parent == null) throw _changed;
        final full = File('${folder.path}/${parent.fileName}');
        if (!await full.exists()) await _fetch(parent, full, onProgress);
        kept.add(parent.id);
        final cut = Mp3Cutter.tail(await full.readAsBytes(), athan.cutStart);
        final part = File('${target.path}.part');
        await part.writeAsBytes(cut, flush: true);
        await part.rename(target.path);
      }
      await _record(kept);
    } on AthanDownloadFailure {
      rethrow;
    } on FormatException {
      throw _changed;
    } on FileSystemException {
      throw const AthanDownloadFailure(
        'Could not save the recording. Free some space and try again.',
      );
    } on Object {
      throw _unreachable;
    }
  }

  /// Streams the recording to a `.part` file and renames it only when its
  /// size and SHA-256 match the catalogue.
  Future<void> _fetch(
    AthanDownload athan,
    File target,
    void Function(double)? onProgress,
  ) async {
    final part = File('${target.path}.part');
    final client = _client();
    try {
      final response = await client
          .send(http.Request('GET', Uri.parse(athan.url)))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw AthanDownloadFailure(
          'The source did not send the recording (error ${response.statusCode}). Try again later.',
        );
      }
      final digest = _DigestSink();
      final hasher = sha256.startChunkedConversion(digest);
      final output = await part.open(mode: FileMode.write);
      var received = 0;
      var reported = -1;
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 30),
        )) {
          received += chunk.length;
          if (received > athan.bytes) throw _changed;
          hasher.add(chunk);
          await output.writeFrom(chunk);
          final percent = received * 100 ~/ athan.bytes;
          if (percent != reported) {
            reported = percent;
            onProgress?.call(received / athan.bytes);
          }
        }
        await output.flush();
      } finally {
        await output.close();
      }
      hasher.close();
      if (received != athan.bytes || digest.value?.toString() != athan.sha256) {
        throw _changed;
      }
      await part.rename(target.path);
    } catch (_) {
      try {
        if (await part.exists()) await part.delete();
      } on FileSystemException {
        // The next attempt overwrites it.
      }
      rethrow;
    } finally {
      client.close();
    }
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

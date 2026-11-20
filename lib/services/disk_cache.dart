import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Text documents kept between launches in the app's private storage.
///
/// Reads and writes never throw. Where there is no storage (a test, a full
/// disk) the caller simply fetches again next time.
class DiskCache {
  DiskCache(this.folder, {Future<Directory?> Function()? root})
    : _root = root ?? _appSupport;

  final String folder;
  final Future<Directory?> Function() _root;

  static Future<Directory?> _appSupport() async {
    try {
      return await getApplicationSupportDirectory();
    } catch (_) {
      return null;
    }
  }

  Future<File?> _file(String name) async {
    final root = await _root();
    return root == null ? null : File('${root.path}/$folder/$name');
  }

  Future<String?> read(String name) async {
    try {
      final file = await _file(name);
      if (file == null || !await file.exists()) return null;
      return await file.readAsString();
    } catch (error) {
      debugPrint('DiskCache: could not read $folder/$name ($error)');
      return null;
    }
  }

  /// Writes through a temporary file so a crash never leaves half a document.
  Future<void> write(String name, String content) async {
    try {
      final file = await _file(name);
      if (file == null) return;
      await file.parent.create(recursive: true);
      final part = File('${file.path}.part');
      await part.writeAsString(content, flush: true);
      await part.rename(file.path);
    } catch (error) {
      debugPrint('DiskCache: could not write $folder/$name ($error)');
    }
  }

  Future<void> remove(String name) async {
    try {
      final file = await _file(name);
      if (file != null && await file.exists()) await file.delete();
    } catch (error) {
      debugPrint('DiskCache: could not remove $folder/$name ($error)');
    }
  }
}

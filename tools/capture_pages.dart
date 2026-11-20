// Run with: flutter test tools/capture_pages.dart
// Writes disposable review images of printed mushaf pages into build/review.
// PAGES chooses the pages (default "1,2,3,50,604"); EDITION the mushaf id.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/services/mushaf_library.dart';
import 'package:flutter_pro/services/mushaf_pages.dart';
import 'package:flutter_pro/widgets/mushaf_page.dart';
import 'package:flutter_pro/widgets/reader_palette.dart';

const _boundary = ValueKey('screen-capture');

void main() {
  testWidgets('printed pages', (tester) async {
    final editionId = Platform.environment['EDITION'] ?? 'hafs_tajweed';
    final wanted = (Platform.environment['PAGES'] ?? '1,2,3,50,604')
        .split(',')
        .map(int.parse)
        .toList();
    final size = (Platform.environment['SIZE'] ?? '392x760').split('x');
    final night = Platform.environment['NIGHT'] == '1';
    final edition = MushafLibrary.edition(editionId);
    late MushafPages pages;
    await tester.runAsync(() async {
      final latin = FontLoader('Roboto')
        ..addFont(
          File(
            '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        );
      await latin.load();
      for (final textId in {edition.textId, 'hafs'}) {
        final font = FontLoader('kfgqpc_$textId')
          ..addFont(rootBundle.load('asset/fonts/kfgqpc_$textId.ttf'));
        await font.load();
      }
      final text = await MushafLibrary().load(edition);
      pages = await MushafPages.load(text, bundle: rootBundle);
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(
      double.parse(size[0]),
      double.parse(size[1]),
    );
    addTearDown(tester.view.reset);
    final palette = night ? ReaderPalette.dark : ReaderPalette.paper;
    for (final page in wanted) {
      await tester.pumpWidget(
        RepaintBoundary(
          key: _boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: palette.page,
              body: MushafPage(
                key: ValueKey(page),
                pages: pages,
                page: page,
                palette: palette,
                onTap: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(_boundary),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/review').create(recursive: true);
        await File(
          'build/review/page-$editionId-$page${night ? '-night' : ''}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }
  });
}

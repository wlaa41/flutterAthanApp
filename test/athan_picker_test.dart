import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/models/athan_download.dart';
import 'package:flutter_pro/services/athan_catalog.dart';
import 'package:flutter_pro/services/athan_downloads.dart';
import 'package:flutter_pro/services/sound_library.dart';
import 'package:flutter_pro/widgets/sound_picker_sheet.dart';

void main() {
  const classic = SoundOption(
    id: 'smooth',
    name: 'Classic Athan',
    description: 'Original app recording',
    kind: SoundKind.athan,
    assetPath: 'asset/smooth.mp3',
  );
  const iqama = SoundOption(
    id: 'iqama',
    name: 'Iqama recitation',
    description: 'Available offline',
    kind: SoundKind.iqama,
    assetPath: 'asset/iqama.mp3',
  );

  // The athans asked for by name stay in view; the rest open on request.
  final named = athanCatalog.where((athan) => athan.featured).length;
  final qassas = athanCatalog[0];
  final jaziFull = athanCatalog[1];
  final jaziShort = athanCatalog[2];

  SoundOption added(AthanDownload athan) => SoundOption(
    id: athan.soundId,
    name: athan.name,
    description: '${athan.place} · ${athan.length} · saved on this phone',
    kind: SoundKind.athan,
    filePath: '/private/${athan.fileName}',
  );

  Future<void> openPicker(
    WidgetTester tester, {
    List<SoundOption> sounds = const [classic, iqama],
    String selectedId = 'smooth',
    bool forIqama = false,
    ValueChanged<SoundOption?>? onClosed,
    Future<List<SoundOption>> Function(AthanDownload, void Function(double))?
    onAdd,
    Future<void> Function(AthanDownload)? onRemove,
    Future<void> Function(SoundOption)? onPreview,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open sounds'),
              onPressed: () async {
                final sound = await showModalBottomSheet<SoundOption>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => SoundPickerSheet(
                    sounds: sounds,
                    selectedId: selectedId,
                    iqama: forIqama,
                    isIOS: false,
                    onPreview: onPreview ?? (_) async {},
                    onStop: () async {},
                    onImport: () async => null,
                    moreAthans: athanCatalog,
                    onAddAthan: onAdd ?? (athan, _) async => [added(athan)],
                    onRemoveAthan: onRemove ?? (_) async {},
                  ),
                );
                onClosed?.call(sound);
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open sounds'));
    await tester.pumpAndSettle();
  }

  /// Brings a row into view. Rows far outside the sheet are not built, so the
  /// search starts from the top of the list each time.
  Future<void> show(WidgetTester tester, Finder finder) async {
    final list = find.byType(Scrollable).last;
    tester.state<ScrollableState>(list).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      finder,
      150,
      scrollable: list,
      maxScrolls: 300,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('The athans asked for by name lead the picker', (tester) async {
    await openPicker(tester);
    expect(find.text('Trending athans'), findsOneWidget);
    expect(find.text('محمد بن مروان قصاص'), findsOneWidget);
    expect(find.text('Muhammad Marwan Qassas'), findsOneWidget);
    expect(find.textContaining('Madinah · 3:49 · 5.5 MB'), findsOneWidget);
    expect(find.text('Muhammad Jazi Abdullah'), findsOneWidget);
    // The named athans come before the recordings that ship with the app.
    expect(find.text('Recitations'), findsNothing);
    await show(tester, find.text('Muhammad Jazi Abdullah · short'));
    expect(
      find.textContaining('made from the full recording (9.9 MB)'),
      findsOneWidget,
    );
    await show(tester, find.text('Hashem Al-Saqqaf'));
    expect(find.text('هاشم السقاف'), findsOneWidget);
    expect(find.textContaining('Muezzin of the Grand Mosque'), findsOneWidget);
    // The rest of the list opens on request, and the recordings that ship
    // with the app come after it.
    final rest = athanCatalog.length - named;
    expect(find.text('Ahmad Al-Nafees'), findsNothing);
    await show(tester, find.text('Recitations'));
    expect(
      tester.getTopLeft(find.text('Show $rest more athans')).dy,
      lessThan(tester.getTopLeft(find.text('Recitations')).dy),
    );
    await tester.tap(find.text('Show $rest more athans'));
    await tester.pumpAndSettle();
    for (final athan in athanCatalog) {
      await show(tester, find.text(athan.name));
      expect(find.text(athan.arabicName), findsWidgets, reason: athan.id);
    }
  });

  testWidgets('Adding an athan shows progress, then selects it', (
    tester,
  ) async {
    SoundOption? result;
    final finished = Completer<void>();
    late void Function(double) report;
    await openPicker(
      tester,
      onClosed: (sound) => result = sound,
      onAdd: (athan, onProgress) async {
        report = onProgress;
        await finished.future;
        return [added(athan)];
      },
    );
    await tester.tap(find.byTooltip('Add Muhammad Marwan Qassas'));
    await tester.pump();
    report(.4);
    await tester.pump();
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, .4);
    // Nothing else starts while the recording is on its way.
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byIcon(Icons.download).first,
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    finished.complete();
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byTooltip('Add Muhammad Marwan Qassas'), findsNothing);
    expect(find.byTooltip('Preview Muhammad Marwan Qassas'), findsOneWidget);
    expect(find.text('Madinah · 3:49 · saved on this phone'), findsOneWidget);
    await tester.tap(find.text('Use sound'));
    await tester.pumpAndSettle();
    expect(result?.id, 'dl_qassas_madinah');
    expect(result?.filePath, '/private/dl_qassas_madinah.mp3');
  });

  testWidgets('The short Jazi brings the full recording with it', (
    tester,
  ) async {
    SoundOption? result;
    await openPicker(
      tester,
      onClosed: (sound) => result = sound,
      onAdd: (athan, _) async => [added(jaziFull), added(jaziShort)],
    );
    await show(tester, find.byTooltip('Add Muhammad Jazi Abdullah · short'));
    await tester.tap(find.byTooltip('Add Muhammad Jazi Abdullah · short'));
    await tester.pumpAndSettle();
    expect(
      find.byTooltip('Preview Muhammad Jazi Abdullah · short'),
      findsOneWidget,
    );
    await show(tester, find.byTooltip('Add Muhammad Marwan Qassas'));
    expect(find.byTooltip('Preview Muhammad Jazi Abdullah'), findsOneWidget);
    expect(find.byTooltip('Add Muhammad Jazi Abdullah'), findsNothing);
    await tester.tap(find.text('Use sound'));
    await tester.pumpAndSettle();
    expect(result?.id, 'dl_jazi_short');
  });

  testWidgets('A failed add says why and can be tried again', (tester) async {
    var attempts = 0;
    SoundOption? result;
    await openPicker(
      tester,
      onClosed: (sound) => result = sound,
      onAdd: (athan, _) async {
        if (attempts++ == 0) {
          throw const AthanDownloadFailure(
            'Could not reach the recording. Check your connection and try again.',
          );
        }
        return [added(athan)];
      },
    );
    await tester.tap(find.byTooltip('Add Muhammad Marwan Qassas'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Check your connection'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    // The sound in use is untouched.
    await tester.tap(find.byTooltip('Add Muhammad Marwan Qassas'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Check your connection'), findsNothing);
    expect(attempts, 2);
    await tester.tap(find.text('Use sound'));
    await tester.pumpAndSettle();
    expect(result?.id, 'dl_qassas_madinah');
  });

  testWidgets('An added athan can be heard, chosen and removed', (
    tester,
  ) async {
    final previews = <String>[];
    final removed = <String>[];
    SoundOption? result;
    await openPicker(
      tester,
      sounds: [classic, added(qassas), added(jaziFull)],
      selectedId: 'dl_jazi_full',
      onClosed: (sound) => result = sound,
      onPreview: (sound) async => previews.add(sound.filePath!),
      onRemove: (athan) async => removed.add(athan.id),
    );
    // Added athans stay in their place in the list, not among the built-ins.
    expect(find.byTooltip('Add Muhammad Marwan Qassas'), findsNothing);
    expect(find.text('Muhammad Marwan Qassas'), findsOneWidget);
    await tester.tap(find.byTooltip('Preview Muhammad Marwan Qassas'));
    await tester.pumpAndSettle();
    expect(previews, ['/private/dl_qassas_madinah.mp3']);

    // The athan in use cannot be removed; another one can.
    expect(
      find.byTooltip('Remove Muhammad Jazi Abdullah from this phone'),
      findsNothing,
    );
    await tester.tap(
      find.byTooltip('Remove Muhammad Marwan Qassas from this phone'),
    );
    await tester.pumpAndSettle();
    expect(removed, ['qassas_madinah']);
    expect(find.byTooltip('Add Muhammad Marwan Qassas'), findsOneWidget);
    // The selection falls back to the sound in use.
    await tester.tap(find.text('Use sound'));
    await tester.pumpAndSettle();
    expect(result?.id, 'dl_jazi_full');
  });

  testWidgets('The Iqama picker offers no athans to add', (tester) async {
    await openPicker(tester, forIqama: true, selectedId: 'iqama');
    expect(find.text('Trending athans'), findsNothing);
    expect(find.text('Muhammad Marwan Qassas'), findsNothing);
    expect(find.text('Iqama recitation'), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(360, 740)]) {
    testWidgets('The athan list fits $size with large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openPicker(
        tester,
        sounds: [classic, added(qassas)],
        textScale: 2,
        onAdd: (athan, _) async => throw const AthanDownloadFailure(
          'Could not reach the recording. Check your connection and try again.',
        ),
      );
      await show(tester, find.byTooltip('Add Muhammad Jazi Abdullah'));
      await tester.tap(find.byTooltip('Add Muhammad Jazi Abdullah'));
      await tester.pumpAndSettle();
      await show(
        tester,
        find.text('Show ${athanCatalog.length - named} more athans'),
      );
      await tester.tap(
        find.text('Show ${athanCatalog.length - named} more athans'),
      );
      await tester.pumpAndSettle();
      await show(tester, find.text(athanCatalog.last.name));
      await show(tester, find.text('Show fewer'));
      expect(tester.takeException(), isNull);
    });
  }
}

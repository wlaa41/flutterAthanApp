import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/services/sound_library.dart';
import 'package:flutter_pro/widgets/sound_picker_sheet.dart';

void main() {
  const original = SoundOption(
    id: 'original',
    name: 'Original Athan',
    description: 'Available offline',
    kind: SoundKind.athan,
    assetPath: 'asset/original.mp3',
  );
  const alternative = SoundOption(
    id: 'alternative',
    name: 'Alternative Athan',
    description: 'Available offline',
    kind: SoundKind.athan,
    assetPath: 'asset/alternative.mp3',
  );
  const imported = SoundOption(
    id: 'my-recording',
    name: 'My recording',
    description: 'Saved on this phone',
    kind: SoundKind.custom,
    filePath: '/private/my-recording.mp3',
  );

  Future<void> openPicker(
    WidgetTester tester, {
    required ValueChanged<SoundOption?> onClosed,
    Future<void> Function(SoundOption)? onPreview,
    Future<void> Function()? onStop,
    Future<SoundOption?> Function()? onImport,
    Stream<bool>? isPlayingStream,
    ValueNotifier<String?>? playbackError,
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
          builder: (context) {
            return Scaffold(
              body: TextButton(
                child: const Text('Open sounds'),
                onPressed: () async {
                  final sound = await showModalBottomSheet<SoundOption>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => SoundPickerSheet(
                      sounds: const [original, alternative],
                      selectedId: original.id,
                      iqama: false,
                      isIOS: false,
                      onPreview: onPreview ?? (_) async {},
                      onStop: onStop ?? () async {},
                      onImport: onImport ?? () async => null,
                      isPlayingStream: isPlayingStream,
                      playbackError: playbackError,
                    ),
                  );
                  onClosed(sound);
                },
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open sounds'));
    await tester.pumpAndSettle();
  }

  testWidgets('preview and selection remain drafts until Use sound', (
    tester,
  ) async {
    var closes = 0;
    SoundOption? result;
    final previews = <String>[];
    await openPicker(
      tester,
      onClosed: (sound) {
        closes++;
        result = sound;
      },
      onPreview: (sound) async => previews.add(sound.id),
    );
    await tester.tap(find.byTooltip('Preview Alternative Athan'));
    await tester.pumpAndSettle();
    expect(previews, [alternative.id]);
    expect(closes, 0);
    await tester.tap(find.text('Alternative Athan'));
    await tester.pumpAndSettle();
    expect(closes, 0);
    await tester.tap(find.byTooltip('Close sound picker'));
    await tester.pumpAndSettle();
    expect(closes, 1);
    expect(result, isNull);

    await tester.tap(find.text('Open sounds'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Preview Alternative Athan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use sound'));
    await tester.pumpAndSettle();
    expect(result?.id, alternative.id);
  });

  testWidgets(
    'an import stages the new sound and explains library persistence',
    (tester) async {
      SoundOption? result;
      var closes = 0;
      await openPicker(
        tester,
        onClosed: (sound) {
          closes++;
          result = sound;
        },
        onImport: () async => imported,
      );
      await tester.tap(find.text('Add from phone'));
      await tester.pumpAndSettle();
      expect(closes, 0);
      expect(
        find.textContaining('even if you close this screen'),
        findsOneWidget,
      );
      await tester.tap(find.text('Use sound'));
      await tester.pumpAndSettle();
      expect(result?.id, imported.id);
    },
  );

  testWidgets('cancelled or failed import preserves the chosen sound', (
    tester,
  ) async {
    SoundOption? result;
    var imports = 0;
    await openPicker(
      tester,
      onClosed: (sound) => result = sound,
      onImport: () async {
        imports++;
        if (imports == 1) return null;
        throw StateError('Invalid audio');
      },
    );
    await tester.tap(find.text('Alternative Athan'));
    await tester.tap(find.text('Add from phone'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not add that audio'), findsNothing);
    await tester.tap(find.text('Add from phone'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not add that audio'), findsOneWidget);
    await tester.tap(find.text('Use sound'));
    await tester.pumpAndSettle();
    expect(result?.id, alternative.id);
  });

  testWidgets(
    'preview completion and late playback errors restore preview controls',
    (tester) async {
      final playing = StreamController<bool>.broadcast();
      final error = ValueNotifier<String?>(null);
      addTearDown(playing.close);
      addTearDown(error.dispose);
      await openPicker(
        tester,
        onClosed: (_) {},
        isPlayingStream: playing.stream,
        playbackError: error,
      );
      await tester.tap(find.byTooltip('Preview Original Athan'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Stop Original Athan'), findsOneWidget);
      playing.add(false);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Preview Original Athan'), findsOneWidget);
      await tester.tap(find.byTooltip('Preview Original Athan'));
      await tester.pumpAndSettle();
      error.value = 'Audio could not play. Try another sound.';
      await tester.pumpAndSettle();
      expect(find.text(error.value!), findsOneWidget);
      expect(find.byTooltip('Preview Original Athan'), findsOneWidget);
      await tester.tap(find.byTooltip('Close sound picker'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'completion during preview setup does not leave a stale Stop control',
    (tester) async {
      final playing = StreamController<bool>.broadcast(sync: true);
      addTearDown(playing.close);
      await openPicker(
        tester,
        onClosed: (_) {},
        isPlayingStream: playing.stream,
        onPreview: (_) async {
          playing.add(true);
          playing.add(false);
        },
      );
      await tester.tap(find.byTooltip('Preview Original Athan'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Preview Original Athan'), findsOneWidget);
      expect(find.byTooltip('Stop Original Athan'), findsNothing);
      await tester.tap(find.byTooltip('Close sound picker'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('pausing before playback starts cancels the pending preview', (
    tester,
  ) async {
    final loading = Completer<void>();
    await openPicker(
      tester,
      onClosed: (_) {},
      onPreview: (_) => loading.future,
    );
    await tester.tap(find.byTooltip('Preview Original Athan'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    loading.complete();
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Preview Original Athan'), findsOneWidget);
    expect(find.byTooltip('Stop Original Athan'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close sound picker'));
    await tester.pumpAndSettle();
  });

  testWidgets('pausing while Stop is pending does not start another preview', (
    tester,
  ) async {
    final stopping = Completer<void>();
    var previews = 0;
    await openPicker(
      tester,
      onClosed: (_) {},
      onStop: () => stopping.future,
      onPreview: (_) async {
        previews++;
      },
    );
    await tester.tap(find.byTooltip('Preview Original Athan'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    stopping.complete();
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(previews, 0);
    expect(find.byTooltip('Stop Original Athan'), findsNothing);
    await tester.tap(find.byTooltip('Close sound picker'));
    await tester.pumpAndSettle();
  });

  testWidgets('closing during import does not apply the imported sound', (
    tester,
  ) async {
    final importResult = Completer<SoundOption?>();
    var closes = 0;
    SoundOption? result;
    await openPicker(
      tester,
      onClosed: (sound) {
        closes++;
        result = sound;
      },
      onImport: () => importResult.future,
    );
    await tester.tap(find.text('Add from phone'));
    await tester.pump();
    await tester.tap(find.byTooltip('Close sound picker'));
    await tester.pumpAndSettle();
    expect(closes, 1);
    expect(result, isNull);
    importResult.complete(imported);
    await tester.pumpAndSettle();
    expect(closes, 1);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    testWidgets('sound picker scrolls at $size with large text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SoundOption? result;
      await openPicker(
        tester,
        onClosed: (sound) => result = sound,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Alternative Athan'), 150);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alternative Athan'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Use sound'));
      await tester.pumpAndSettle();
      expect(result?.id, alternative.id);
      expect(tester.takeException(), isNull);
    });
  }
}

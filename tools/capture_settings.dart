// Run with: flutter test tools/capture_settings.dart
// Writes disposable review images into build/review; these are not goldens.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/models/alert_preferences.dart';
import 'package:flutter_pro/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('capture settings at text scale $scale', (tester) async {
      // Widget tests default to the square Ahem test font. Load a real local font
      // for human review; REVIEW_FONT can point to any installed TTF on other OSes.
      final fontPath =
          Platform.environment['REVIEW_FONT'] ??
          (Platform.isWindows
              ? 'C:/Windows/Fonts/segoeui.ttf'
              : '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
      await tester.runAsync(() async {
        final bytes = await File(fontPath).readAsBytes();
        final loader = FontLoader('ReviewFont')
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await loader.load();
      });
      SharedPreferences.setMockInitialValues({
        'alert_preferences': jsonEncode(
          const AlertPreferences(
            quietEnabled: true,
            iqamaEnabled: true,
            iqamaRepeatCount: 3,
          ).toJson(),
        ),
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 812);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const boundaryKey = ValueKey('settings-capture');
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              fontFamily: 'ReviewFont',
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0F3931),
              ),
              scaffoldBackgroundColor: const Color(0xFFF8FAFC),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF0F3931),
                foregroundColor: Colors.white,
              ),
              cardTheme: CardThemeData(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      Future<void> capture(String name) async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(boundaryKey),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/review').create(recursive: true);
          await File('build/review/$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture(scale == 1 ? 'settings-phone' : 'settings-large-text');
      if (scale == 1) {
        await tester.scrollUntilVisible(find.text('Quiet at work'), 250);
        await Scrollable.ensureVisible(
          tester.element(find.text('Quiet at work')),
          alignment: 0,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture('settings-quiet');
      }
    });
  }
}

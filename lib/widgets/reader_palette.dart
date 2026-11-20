import 'package:flutter/material.dart';

import '../models/quran_models.dart';

/// The colours of the Quran reader, as paper by day or dimmed for the night.
class ReaderPalette {
  const ReaderPalette._({
    required this.night,
    required this.page,
    required this.ink,
    required this.soft,
    required this.rule,
    required this.marker,
    required this.frame,
    required this.frameInk,
    required this.selection,
    required this.card,
    required this.tajweed,
  });

  final bool night;

  /// The sheet the text sits on.
  final Color page;
  final Color ink;

  /// Secondary text: page numbers, captions.
  final Color soft;
  final Color rule;

  /// The end-of-ayah ornaments.
  final Color marker;

  /// The surah name plate.
  final Color frame;
  final Color frameInk;

  /// The verse that is open or being recited.
  final Color selection;

  /// Panels placed on the page, such as the translation box.
  final Color card;
  final Map<TajweedRule, Color> tajweed;

  static const Color green = Color(0xFF0F3931);
  static const Color gold = Color(0xFFC5A059);

  static const ReaderPalette paper = ReaderPalette._(
    night: false,
    page: Color(0xFFFAF6EC),
    ink: Color(0xFF1B1A17),
    soft: Color(0xFF7A7362),
    rule: Color(0xFFE2D8C0),
    marker: Color(0xFFB0812F),
    frame: green,
    frameInk: Color(0xFFE7CE96),
    selection: Color(0x33C5A059),
    card: Color(0xFFFFFFFF),
    // The widely used tajweed colour key, as published with the colour data.
    tajweed: {
      TajweedRule.hamzatWasl: Color(0xFF9A9A9A),
      TajweedRule.silent: Color(0xFF9A9A9A),
      TajweedRule.lamShamsiyyah: Color(0xFF9A9A9A),
      TajweedRule.maddNormal: Color(0xFF537FFF),
      TajweedRule.maddPermissible: Color(0xFF4050FF),
      TajweedRule.maddNecessary: Color(0xFF000EBC),
      TajweedRule.maddObligatory: Color(0xFF2144C1),
      TajweedRule.qalqalah: Color(0xFFDD0008),
      TajweedRule.ikhfaShafawi: Color(0xFFD500B7),
      TajweedRule.ikhfa: Color(0xFF9400A8),
      TajweedRule.idghamShafawi: Color(0xFF58B800),
      TajweedRule.iqlab: Color(0xFF17A7E6),
      TajweedRule.idghamGhunnah: Color(0xFF169777),
      TajweedRule.idghamNoGhunnah: Color(0xFF169200),
      TajweedRule.idghamMutajanisayn: Color(0xFF9A9A9A),
      TajweedRule.idghamMutaqaribayn: Color(0xFF9A9A9A),
      TajweedRule.ghunnah: Color(0xFFF47A1C),
    },
  );

  static const ReaderPalette dark = ReaderPalette._(
    night: true,
    page: Color(0xFF0F1512),
    ink: Color(0xFFE9E3D3),
    soft: Color(0xFF8F9A90),
    rule: Color(0xFF26302A),
    marker: Color(0xFFD9B36B),
    frame: Color(0xFF16261F),
    frameInk: Color(0xFFE2C88F),
    selection: Color(0x40C5A059),
    card: Color(0xFF18211C),
    // The same key, lifted so each colour still reads on a dark page.
    tajweed: {
      TajweedRule.hamzatWasl: Color(0xFF7C847E),
      TajweedRule.silent: Color(0xFF7C847E),
      TajweedRule.lamShamsiyyah: Color(0xFF7C847E),
      TajweedRule.maddNormal: Color(0xFFA8C4FF),
      TajweedRule.maddPermissible: Color(0xFF8AA2FF),
      TajweedRule.maddNecessary: Color(0xFF6C7BFF),
      TajweedRule.maddObligatory: Color(0xFF7C93F5),
      TajweedRule.qalqalah: Color(0xFFFF6166),
      TajweedRule.ikhfaShafawi: Color(0xFFFF6FE0),
      TajweedRule.ikhfa: Color(0xFFD487E2),
      TajweedRule.idghamShafawi: Color(0xFF93E04F),
      TajweedRule.iqlab: Color(0xFF55CCFF),
      TajweedRule.idghamGhunnah: Color(0xFF43D0AA),
      TajweedRule.idghamNoGhunnah: Color(0xFF58D153),
      TajweedRule.idghamMutajanisayn: Color(0xFF7C847E),
      TajweedRule.idghamMutaqaribayn: Color(0xFF7C847E),
      TajweedRule.ghunnah: Color(0xFFFF9D52),
    },
  );
}

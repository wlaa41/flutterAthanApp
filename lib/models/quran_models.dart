import 'package:flutter/material.dart';

enum TajweedRule {
  normal,
  hamzatWasl, // [h
  silent, // [s
  lamShamsiyyah, // [l
  maddaNormal, // [n (2 counts)
  maddaPermissible, // [p (2, 4, 6 counts)
  maddaNecessary, // [m (6 counts)
  maddaObligatory, // [o (4-5 counts)
  qalqalah, // [q (Red)
  ikhfa, // [f (Purple)
  ikhfaShafawi, // [c (Magenta)
  idghamGhunnah, // [a (Green)
  idghamShafawi, // [w (Olive Green)
  idghamNoGhunnah, // [u (Muted)
  iqlab, // [i (Teal/Cyan)
  ghunnah, // [g (Forest Green)
}

class TajweedRuleInfo {
  final TajweedRule rule;
  final String title;
  final String arabicTitle;
  final Color color;
  final String description;

  const TajweedRuleInfo({
    required this.rule,
    required this.title,
    required this.arabicTitle,
    required this.color,
    required this.description,
  });

  static const List<TajweedRuleInfo> allRules = [
    TajweedRuleInfo(
      rule: TajweedRule.qalqalah,
      title: 'Qalqalah (Echoing sound)',
      arabicTitle: 'قلقلة',
      color: Color(0xFFDD1111),
      description: 'Vibration/echo on letters: ق, ط, ب, ج, د when sukoon occurs.',
    ),
    TajweedRuleInfo(
      rule: TajweedRule.ikhfa,
      title: 'Ikhfa (Concealment)',
      arabicTitle: 'إخفاء',
      color: Color(0xFF9400D3),
      description: 'Nasalized concealed sound between Izhar and Idgham with Ghunnah.',
    ),
    TajweedRuleInfo(
      rule: TajweedRule.idghamGhunnah,
      title: 'Idgham with Ghunnah',
      arabicTitle: 'إدغام بغنة',
      color: Color(0xFF169777),
      description: 'Merging with nasalization into letters: ي, ن, م, و.',
    ),
    TajweedRuleInfo(
      rule: TajweedRule.iqlab,
      title: 'Iqlab (Conversion)',
      arabicTitle: 'إقلاب',
      color: Color(0xFF00ACC1),
      description: 'Conversion of Noon Saakin or Tanween into Meem before Baa.',
    ),
    TajweedRuleInfo(
      rule: TajweedRule.maddaNecessary,
      title: 'Necessary Madd (6 Counts)',
      arabicTitle: 'مد لازم',
      color: Color(0xFF0D47A1),
      description: 'Prolongation held for 6 vowels due to sukoon or shaddah.',
    ),
    TajweedRuleInfo(
      rule: TajweedRule.maddaObligatory,
      title: 'Obligatory Madd (4-5 Counts)',
      arabicTitle: 'مد واجب / جائز',
      color: Color(0xFF1E88E5),
      description: 'Prolongation held for 4 to 5 vowel counts due to Hamzah.',
    ),
    TajweedRuleInfo(
      rule: TajweedRule.maddaNormal,
      title: 'Normal Madd (2 Counts)',
      arabicTitle: 'مد طبيعي',
      color: Color(0xFF42A5F5),
      description: 'Standard 2-vowel natural elongation.',
    ),
    TajweedRuleInfo(
      rule: TajweedRule.hamzatWasl,
      title: 'Hamzat ul-Wasl & Silent',
      arabicTitle: 'همزة وصل / حرف صامت',
      color: Color(0xFF78909C),
      description: 'Connecting hamza or unpronounced silent letter.',
    ),
  ];

  static Color getColorForCode(String code) {
    switch (code) {
      case 'q':
        return const Color(0xFFDD1111);
      case 'f':
        return const Color(0xFF9400D3);
      case 'c':
        return const Color(0xFFC2185B);
      case 'a':
        return const Color(0xFF169777);
      case 'w':
        return const Color(0xFF2E7D32);
      case 'i':
        return const Color(0xFF00ACC1);
      case 'm':
        return const Color(0xFF0D47A1);
      case 'o':
        return const Color(0xFF1976D2);
      case 'p':
        return const Color(0xFF2196F3);
      case 'n':
        return const Color(0xFF64B5F6);
      case 'h':
      case 's':
      case 'l':
        return const Color(0xFF78909C);
      default:
        return Colors.black87;
    }
  }
}

class Surah {
  final int number;
  final String name;
  final String englishName;
  final String englishNameTranslation;
  final int numberOfAyahs;
  final String revelationType;

  const Surah({
    required this.number,
    required this.name,
    required this.englishName,
    required this.englishNameTranslation,
    required this.numberOfAyahs,
    required this.revelationType,
  });

  factory Surah.fromJson(Map<String, dynamic> json) {
    return Surah(
      number: json['number'] as int? ?? 1,
      name: json['name'] as String? ?? '',
      englishName: json['englishName'] as String? ?? '',
      englishNameTranslation: json['englishNameTranslation'] as String? ?? '',
      numberOfAyahs: json['numberOfAyahs'] as int? ?? 7,
      revelationType: json['revelationType'] as String? ?? 'Meccan',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'name': name,
      'englishName': englishName,
      'englishNameTranslation': englishNameTranslation,
      'numberOfAyahs': numberOfAyahs,
      'revelationType': revelationType,
    };
  }
}

class Ayah {
  final int number; // Global number 1..6236
  final int numberInSurah;
  final int juz;
  final int page;
  final String tajweedText;
  final String cleanText;
  final String translation;
  final String audioUrl;
  bool isBookmarked;
  int? highlightColorValue; // ARGB value for user highlight

  Ayah({
    required this.number,
    required this.numberInSurah,
    required this.juz,
    required this.page,
    required this.tajweedText,
    required this.cleanText,
    required this.translation,
    required this.audioUrl,
    this.isBookmarked = false,
    this.highlightColorValue,
  });

  factory Ayah.fromJson(Map<String, dynamic> json) {
    return Ayah(
      number: json['number'] as int? ?? 1,
      numberInSurah: json['numberInSurah'] as int? ?? 1,
      juz: json['juz'] as int? ?? 1,
      page: json['page'] as int? ?? 1,
      tajweedText: json['tajweedText'] as String? ?? '',
      cleanText: json['cleanText'] as String? ?? '',
      translation: json['translation'] as String? ?? '',
      audioUrl: json['audioUrl'] as String? ?? '',
      isBookmarked: json['isBookmarked'] as bool? ?? false,
      highlightColorValue: json['highlightColorValue'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'numberInSurah': numberInSurah,
      'juz': juz,
      'page': page,
      'tajweedText': tajweedText,
      'cleanText': cleanText,
      'translation': translation,
      'audioUrl': audioUrl,
      'isBookmarked': isBookmarked,
      'highlightColorValue': highlightColorValue,
    };
  }
}

/// A chapter of the Quran. [numberOfAyahs] is the Hafs (Kufi) count; a mushaf
/// of another riwayah may count the same chapter differently.
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

/// The tajweed rules marked in the coloured Hafs mushaf, in the order the
/// bundled colour data numbers them.
enum TajweedRule {
  hamzatWasl('ham_wasl'),
  silent('slnt'),
  lamShamsiyyah('laam_shamsiyah'),
  maddNormal('madda_normal'),
  maddPermissible('madda_permissible'),
  maddNecessary('madda_necessary'),
  maddObligatory('madda_obligatory'),
  qalqalah('qalaqah'),
  ikhfaShafawi('ikhafa_shafawi'),
  ikhfa('ikhafa'),
  idghamShafawi('idgham_shafawi'),
  iqlab('iqlab'),
  idghamGhunnah('idgham_ghunnah'),
  idghamNoGhunnah('idgham_wo_ghunnah'),
  idghamMutajanisayn('idgham_mutajanisayn'),
  idghamMutaqaribayn('idgham_mutaqaribayn'),
  ghunnah('ghunnah');

  const TajweedRule(this.dataName);

  /// The rule's name in the colour data.
  final String dataName;
}

/// One line of the colour guide. Rules that share a colour share a line.
class TajweedGuideEntry {
  const TajweedGuideEntry({
    required this.title,
    required this.arabicTitle,
    required this.description,
    required this.rules,
  });

  final String title;
  final String arabicTitle;
  final String description;
  final List<TajweedRule> rules;

  static const List<TajweedGuideEntry> all = [
    TajweedGuideEntry(
      title: 'Qalqalah',
      arabicTitle: 'قلقلة',
      description: 'A light echo on ق ط ب ج د when the letter carries sukun.',
      rules: [TajweedRule.qalqalah],
    ),
    TajweedGuideEntry(
      title: 'Ghunnah, 2 counts',
      arabicTitle: 'غنّة',
      description: 'A nasal sound held on a doubled noon or meem.',
      rules: [TajweedRule.ghunnah],
    ),
    TajweedGuideEntry(
      title: 'Ikhfa',
      arabicTitle: 'إخفاء',
      description:
          'Noon sakinah or tanween hidden behind a nasal sound before its '
          'fifteen letters.',
      rules: [TajweedRule.ikhfa],
    ),
    TajweedGuideEntry(
      title: 'Ikhfa shafawi',
      arabicTitle: 'إخفاء شفوي',
      description: 'Meem sakinah hidden behind a nasal sound before ب.',
      rules: [TajweedRule.ikhfaShafawi],
    ),
    TajweedGuideEntry(
      title: 'Iqlab',
      arabicTitle: 'إقلاب',
      description: 'Noon sakinah or tanween turned into a meem before ب.',
      rules: [TajweedRule.iqlab],
    ),
    TajweedGuideEntry(
      title: 'Idgham with ghunnah',
      arabicTitle: 'إدغام بغنّة',
      description:
          'Noon sakinah or tanween merged, with a nasal sound, into ي ن م و.',
      rules: [TajweedRule.idghamGhunnah],
    ),
    TajweedGuideEntry(
      title: 'Idgham without ghunnah',
      arabicTitle: 'إدغام بلا غنّة',
      description: 'Noon sakinah or tanween merged fully into ل or ر.',
      rules: [TajweedRule.idghamNoGhunnah],
    ),
    TajweedGuideEntry(
      title: 'Idgham shafawi',
      arabicTitle: 'إدغام شفوي',
      description: 'Meem sakinah merged into the meem after it.',
      rules: [TajweedRule.idghamShafawi],
    ),
    TajweedGuideEntry(
      title: 'Madd, 2 counts',
      arabicTitle: 'مدّ طبيعي',
      description: 'The natural lengthening of a long vowel.',
      rules: [TajweedRule.maddNormal],
    ),
    TajweedGuideEntry(
      title: 'Madd, 2, 4 or 6 counts',
      arabicTitle: 'مدّ جائز',
      description: 'A lengthening the reciter may hold shorter or longer.',
      rules: [TajweedRule.maddPermissible],
    ),
    TajweedGuideEntry(
      title: 'Madd, 4 or 5 counts',
      arabicTitle: 'مدّ واجب',
      description: 'A long vowel followed by a hamzah in the same word.',
      rules: [TajweedRule.maddObligatory],
    ),
    TajweedGuideEntry(
      title: 'Madd, 6 counts',
      arabicTitle: 'مدّ لازم',
      description: 'A long vowel followed by a sukun or a shaddah.',
      rules: [TajweedRule.maddNecessary],
    ),
    TajweedGuideEntry(
      title: 'Written, not pronounced',
      arabicTitle: 'لا يُنطق',
      description:
          'Hamzat al-wasl, lam shamsiyyah, silent letters, and a letter merged '
          'into a near or matching letter after it.',
      rules: [
        TajweedRule.hamzatWasl,
        TajweedRule.silent,
        TajweedRule.lamShamsiyyah,
        TajweedRule.idghamMutajanisayn,
        TajweedRule.idghamMutaqaribayn,
      ],
    ),
  ];
}

/// One copy of the Quran the reader can show: a riwayah as the King Fahd
/// Complex prints it, with or without tajweed colours.
class MushafEdition {
  const MushafEdition({
    required this.id,
    required this.textId,
    required this.name,
    required this.arabicName,
    required this.note,
    required this.ayahCount,
    this.tajweedColours = false,
  });

  /// What the reader remembers as the chosen copy.
  final String id;

  /// The KFGQPC text and font this copy is drawn with.
  final String textId;
  final String name;
  final String arabicName;
  final String note;

  /// Ayat in the whole mushaf. The riwayat divide some passages differently.
  final int ayahCount;
  final bool tajweedColours;

  String get fontFamily => 'kfgqpc_$textId';
  String get asset => 'asset/quran/$textId.json';

  /// Whether verse numbers are the ones translations, tafsir and recitations
  /// use (the Kufi count of the Hafs mushaf).
  bool get hafsNumbering => ayahCount == 6236;
}

/// A verse as one mushaf writes and numbers it.
class MushafAyah {
  const MushafAyah({
    required this.surah,
    required this.number,
    required this.text,
    required this.page,
    required this.juz,
    required this.hafsFrom,
    required this.hafsTo,
    this.tajweed = const [],
  });

  final int surah;

  /// The verse number in this mushaf.
  final int number;

  /// The Complex's code points, without the end-of-ayah number.
  final String text;
  final int page;
  final int juz;

  /// The Hafs verses that hold the same words. Translations and tafsir are
  /// looked up by these.
  final int hafsFrom;
  final int hafsTo;

  /// Colour runs as flat triples: start, length, [TajweedRule] index.
  final List<int> tajweed;

  bool get numberedAsHafs => hafsFrom == number && hafsTo == number;

  /// The verse reference in the Hafs count, such as `2:5` or `2:5-6`.
  String get hafsReference =>
      hafsFrom == hafsTo ? '$surah:$hafsFrom' : '$surah:$hafsFrom-$hafsTo';
}

/// A number in the digits the mushaf prints.
String arabicDigits(int number) => String.fromCharCodes(
  number.toString().codeUnits.map((unit) => unit - 0x30 + 0x0660),
);

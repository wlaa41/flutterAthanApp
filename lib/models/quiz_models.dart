import 'quran_models.dart';

/// A word (or a short phrase) of the Quran and its meaning, asked as one
/// multiple-choice question.
///
/// The question points at the words in the bundled Hafs text by verse and
/// position, so the game shows the Complex's own letters and never a retyped
/// copy of the Quran.
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.ayah,
    required this.word,
    this.span = 1,
    required this.letters,
    required this.meaning,
    required this.wrong,
  });

  final String id;

  /// The Hafs verse number.
  final int ayah;

  /// The first word, counted from 0, splitting the verse at its spaces.
  final int word;

  /// How many words the question asks about.
  final int span;

  /// The words' letters without vowels or marks ([quizLetters]). A test checks
  /// them against the text, so a question can never point at the wrong word.
  final String letters;

  /// The right meaning, in Arabic.
  final String meaning;

  /// Three meanings that do not fit the verse.
  final List<String> wrong;
}

/// A short run of verses, played as one level.
class QuizStage {
  const QuizStage({
    required this.id,
    required this.title,
    required this.from,
    required this.to,
    required this.questions,
  });

  final String id;
  final String title;
  final int from;
  final int to;
  final List<QuizQuestion> questions;

  /// "الآيات ١–٨".
  String get verses => from == to
      ? 'الآية ${arabicDigits(from)}'
      : 'الآيات ${arabicDigits(from)}–${arabicDigits(to)}';
}

/// One surah's challenge: its stages in the surah's order.
class QuizChallenge {
  const QuizChallenge({
    required this.id,
    required this.surah,
    required this.title,
    required this.surahName,
    required this.stages,
  });

  final String id;
  final int surah;
  final String title;
  final String surahName;
  final List<QuizStage> stages;

  List<QuizQuestion> get questions => [
    for (final stage in stages) ...stage.questions,
  ];
}

/// The letters of Quran words without vowels, marks, tatweel or the small
/// letters of the Uthmani script, with every alef written plainly. Used to
/// check that a question points at the words it means.
String quizLetters(String text) {
  final out = StringBuffer();
  for (final rune in text.runes) {
    final mark =
        (rune >= 0x064B && rune <= 0x065F) ||
        rune == 0x0670 ||
        (rune >= 0x06D6 && rune <= 0x06ED) ||
        (rune >= 0x08D3 && rune <= 0x08FF) ||
        rune == 0x0640 ||
        rune == 0x00A0;
    if (mark) continue;
    const alefs = {0x0671, 0x0623, 0x0625, 0x0622};
    out.writeCharCode(alefs.contains(rune) ? 0x0627 : rune);
  }
  return out.toString();
}

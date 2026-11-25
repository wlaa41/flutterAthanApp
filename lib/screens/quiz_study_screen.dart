import 'package:flutter/material.dart';

import '../models/quiz_models.dart';
import '../models/quran_models.dart';
import '../services/quiz_progress.dart';
import '../widgets/quiz_widgets.dart';
import 'quiz_round_screen.dart';

/// Every word of a stage with its meaning and its verse, to learn before
/// playing. A word answered right twice in a row is marked as mastered.
class QuizStudyScreen extends StatefulWidget {
  const QuizStudyScreen({
    super.key,
    required this.challenge,
    required this.stage,
  });

  final QuizChallenge challenge;
  final QuizStage stage;

  @override
  State<QuizStudyScreen> createState() => _QuizStudyScreenState();
}

class _QuizStudyScreenState extends State<QuizStudyScreen> {
  late final Future<(List<MushafAyah>, QuizProgress)> _loading = () async {
    final verses = await QuizVerses.surah(widget.challenge.surah);
    final progress = await QuizProgress.load(widget.challenge.id);
    return (verses, progress);
  }();

  @override
  Widget build(BuildContext context) {
    final stage = widget.stage;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: QuizColors.night,
        appBar: AppBar(
          backgroundColor: QuizColors.deep,
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stage.title, style: const TextStyle(fontSize: 18)),
              Text(
                '${stage.verses}، ${arabicDigits(stage.questions.length)} كلمة',
                style: const TextStyle(fontSize: 12.5, color: QuizColors.soft),
              ),
            ],
          ),
        ),
        body: FutureBuilder<(List<MushafAyah>, QuizProgress)>(
          future: _loading,
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (data == null) {
              return const Center(
                child: CircularProgressIndicator(color: QuizColors.gold),
              );
            }
            final (verses, progress) = data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                for (final question in stage.questions)
                  _card(question, verses, progress),
              ],
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: QuizColors.gold,
                foregroundColor: QuizColors.night,
                minimumSize: const Size.fromHeight(54),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text(
                'ابدأ التحدي',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => QuizRoundScreen(
                    challenge: widget.challenge,
                    stage: stage,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(
    QuizQuestion question,
    List<MushafAyah> verses,
    QuizProgress progress,
  ) {
    final ayah = verses[question.ayah - 1];
    final mastered = progress.words[question.id]?.mastered ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: QuizColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: mastered
              ? QuizColors.mint.withValues(alpha: 0.5)
              : QuizColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  askedWords(verses, question),
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontFamily: quranFont,
                    color: QuizColors.gold,
                    fontSize: 30,
                    height: 1.7,
                  ),
                ),
              ),
              if (mastered)
                const QuizPill(
                  icon: Icons.check_rounded,
                  text: 'أتقنتها',
                  color: QuizColors.mint,
                ),
            ],
          ),
          Text(
            question.meaning,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          VerseSnippet(
            ayah: ayah,
            question: question,
            around: null,
            fontSize: 20,
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.challenge.surahName}: ${arabicDigits(question.ayah)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: QuizColors.faint,
                    fontSize: 12.5,
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: QuizColors.soft),
                onPressed: () => showQuizTafsir(
                  context,
                  surah: widget.challenge.surah,
                  ayah: ayah,
                  surahName: widget.challenge.surahName,
                ),
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: const Text('التفسير الميسر'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/journey.dart';
import '../services/audio_service.dart';
import '../widgets/journey_ui.dart';

/// Where everything the journey shows comes from: the Quran text, the
/// meanings quoted for it, and the little that was written for the game.
class JourneySourcesScreen extends StatelessWidget {
  const JourneySourcesScreen({
    super.key,
    required this.journey,
    required this.arabic,
  });

  final Journey journey;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final t = JText(arabic);
    return JScreen(
      arabic: arabic,
      child: JPage(
        children: [
          Row(
            children: [
              JRound(
                icon: arabic
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.arrow_back_ios_new_rounded,
                label: t.pick('Back', 'رجوع'),
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t.sources,
                  style: J.text(26, weight: 800, height: 1.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            t.pick(
              'What explains the Quran in this game is copied from the works below, letter for letter.',
              'كل ما يشرح القرآن في هذه اللعبة منقول من المصادر الآتية حرفًا بحرف.',
            ),
            style: J.text(16, height: arabic ? 1.65 : 1.4),
          ),
          const SizedBox(height: 12),
          _part(
            t,
            t.pick('The Quran', 'القرآن الكريم'),
            t.pick(
              "Hafs from 'Asim, in the text and the font of the King Fahd Glorious Quran Printing Complex, Madinah.",
              'رواية حفص عن عاصم، بنص وخط مجمع الملك فهد لطباعة المصحف الشريف بالمدينة المنورة.',
            ),
            note: t.pick(
              'Every ayah is shown whole. Nothing of the Quran is retyped or reworded.',
              'تُعرض كل آية كاملة، ولا تُعاد كتابة شيء من القرآن ولا صياغته.',
            ),
          ),
          _part(
            t,
            t.pick('Meaning in English', 'المعنى بالإنجليزية'),
            'Saheeh International',
            source: journey.translation,
            note: t.pick(
              'The translation and its footnotes.',
              'الترجمة وحواشيها.',
            ),
          ),
          _part(
            t,
            t.pick('Meaning in Arabic', 'المعنى بالعربية'),
            'التفسير الميسر',
            source: journey.tafsir,
            note: t.pick(
              'Where it explains several ayahs in one text, the game shows those ayahs together.',
              'حيث يفسّر عدة آيات بنص واحد تُعرض تلك الآيات معًا.',
            ),
          ),
          _part(
            t,
            t.pick('Meanings of the words', 'معاني الكلمات'),
            'السراج في بيان غريب القرآن',
            source: journey.wordSource,
            note: t.pick(
              "Optional help in the Arabic level. The word is shown as the mushaf writes it; its meaning is the book's.",
              'عون اختياري في المستوى العربي. تُعرض الكلمة كما في المصحف، ومعناها من الكتاب.',
            ),
          ),
          _part(
            t,
            t.pick('The recitation you hear', 'التلاوة المسموعة'),
            t.pick(
              '${Reciter.alafasy.name}, Hafs.',
              'مشاري راشد العفاسي، برواية حفص.',
            ),
          ),
          _part(
            t,
            t.pick('Written for this game', 'ما كُتب لهذه اللعبة'),
            t.pick(
              'The names of the stops, and the wording of the English questions.',
              'أسماء المحطات، وصياغة الأسئلة الإنجليزية.',
            ),
            note: t.pick(
              "The choices under a question are phrases of the translation: the right one from the ayah asked about, the others from other ayahs of the surah. The questions are not a scholar's words.",
              'الاختيارات تحت كل سؤال عبارات من الترجمة: الصحيح من الآية المسؤول عنها، وغيره من آيات أخرى في السورة. والأسئلة ليست من كلام أهل العلم.',
            ),
          ),
          _part(
            t,
            t.pick('The pictures', 'الصور'),
            t.pick(
              'Places and things only. No prophet, no person and no animal is drawn.',
              'أماكن وأشياء فقط. لا يُرسم نبي ولا إنسان ولا حيوان.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _part(
    JText t,
    String heading,
    String name, {
    JourneySource? source,
    String? note,
  }) {
    final body = J.text(15, color: J.muted, height: arabic ? 1.6 : 1.4);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: JCard(
        depth: 0,
        radius: 18,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              arabic ? heading : heading.toUpperCase(),
              style: J.text(
                13,
                weight: 700,
                color: J.label,
                spacing: arabic ? null : 1,
              ),
            ),
            Text(
              name,
              style: J.text(
                source == null ? 16 : 19,
                weight: source == null ? 600 : 800,
                height: arabic || source != null ? 1.5 : 1.4,
              ),
            ),
            if (source != null) ...[
              Text(source.title(arabic), style: body),
              Text(source.by(arabic), style: body),
              Text(
                t.pick(
                  'From QuranEnc.com, version ${source.version}, ${source.date}.',
                  'من موسوعة القرآن الكريم QuranEnc.com، الإصدار ${source.version}، ${source.date}.',
                ),
                style: body,
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: SelectableText(
                  source.url.replaceFirst('https://', ''),
                  textAlign: arabic ? TextAlign.right : TextAlign.left,
                  style: J.text(13.5, weight: 600, color: J.label, height: 1.5),
                ),
              ),
            ],
            if (note != null) ...[
              const SizedBox(height: 4),
              Text(note, style: J.text(15, height: arabic ? 1.6 : 1.4)),
            ],
          ],
        ),
      ),
    );
  }
}

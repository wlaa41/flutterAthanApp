#!/usr/bin/env python3
"""Writes asset/journey/kahf.json, the content of the Al-Kahf Journey.

The journey walks through the whole surah in stops. A stop shows its ayahs
with their meaning, then asks about them at one of three levels:

  1. English: a question about the ayah, with the ayah shown and heard.
  2. Arabic: the ayah is shown, the player picks its tafsir.
  3. Arabic, strong: the tafsir is shown, the player picks the ayah.

What explains the Quran here is copied, never written:

  - Nothing of the Quran is typed in this file. An ayah is named by its number
    and shown whole from the bundled Hafs text.
  - The English meaning of an ayah is the Saheeh International translation,
    with its footnotes, as QuranEnc.com serves it.
  - The Arabic meaning is al-Tafsir al-Muyassar (King Fahd Complex), as
    QuranEnc.com serves it. Where it explains several ayahs in one text, the
    game treats those ayahs as one passage.
  - The word meanings are the lines of "As-Siraj fi Bayan Gharib al-Quran" as
    QuranEnc.com serves them. The meaning is kept letter for letter. The word
    it explains is not shown in the source's plain spelling: the script finds
    it in the Hafs text and the game shows the mushaf's own words.

The three files are kept as they were downloaded in tools/sources/quranenc/,
with their versions in manifest.json. This script copies from them, checks that
QuranEnc's ayahs are the ayahs of the bundled text, and changes no letter.

What is written here, and is ours: the names of the parts and stops, and the
stems of the English questions. The choices follow rules this script checks
against the translation, so that nothing about the surah is made up:

  - The right choice is in the translation of the ayah asked about, in the
    translation's own words.
  - Every wrong choice is in the translation of another ayah of the surah, in
    the translation's own words: another person, place, thing or saying the
    surah itself mentions. No wrong choice is invented.
  - "Which of these did ... say": all three choices are sayings quoted from
    the translation. Nothing is put in anyone's mouth.
  - Where an ayah speaks of Allah, His promise, His punishment or the unseen,
    the question asks which of three things the ayah speaks of, so that a
    wrong choice never says something untrue of them.

  python3 tools/make_kahf_journey.py            # check and write
  python3 tools/make_kahf_journey.py --check    # check only
  python3 tools/make_kahf_journey.py --fetch    # download the sources again
"""
import hashlib
import json
import pathlib
import re
import sys
import unicodedata
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
TEXT = ROOT / 'asset' / 'quran' / 'hafs.json'
OUT = ROOT / 'asset' / 'journey' / 'kahf.json'
SOURCES = ROOT / 'tools' / 'sources' / 'quranenc'
MANIFEST = SOURCES / 'manifest.json'
API = 'https://quranenc.com/api/v1/translation/sura/{key}/18'

# Ayahs the Arabic levels never ask about or offer as a choice: three are the
# same short line, two repeat ayah 67 almost word for word. They are still
# read, heard and recited.
SKIP = {72, 75, 85, 89, 92}


def ask(ayah, question, answer, wrong1, wrong2, inside=False):
    """A question on one ayah. The answer is a phrase of that ayah's
    translation; each wrong choice is a phrase of another ayah's translation.
    inside=True lets the first wrong choice also stand in this ayah, where the
    ayah itself sets the two against each other (awake and asleep)."""
    return (ayah, question, answer, wrong1, wrong2, 'ask', inside)


def said(ayah, question, answer, wrong1, wrong2):
    """A question whose three choices are sayings quoted from the translation."""
    return (ayah, question, answer, wrong1, wrong2, 'said', False)


def speaks(ayah, answer, wrong1, wrong2):
    """Which of three things does this ayah speak of? For ayahs about Allah,
    His promise, His punishment or the unseen."""
    return (ayah, f'Which of these does ayah {ayah} speak of?', answer, wrong1, wrong2,
            'speaks', False)


PROPHET = 'the Prophet (peace and blessings be upon him)'
MUSA = 'Musa (peace be upon him)'
KHIDR = 'al-Khidr (peace be upon him)'

# The blessing said after the names in a part's title: (English, Arabic).
BLESSINGS = {'khidr': ("peace be upon them", 'عليهما السلام')}

# (id, kind, English, Arabic, art, keepsake, stops)
# keepsake: (id, English, Arabic, the ayah that mentions it)
# stop: (English, Arabic, first, last, questions)
SECTIONS = [
    ('opening', 'bridge', "The Opening", 'مطلع السورة', 'book', None, [
        ("The straight Book", 'الكتاب المستقيم', 1, 5, [
            said(1, "Which words open the surah?",
                 "[All] praise is [due] to Allāh",
                 "The truth is from your Lord", "Allāh is most knowing of how long they remained"),
            ask(2, "To whom does the Book give good tidings?",
                "The believers who do righteous deeds",
                "Poor people working at sea", "The people of a town"),
            ask(4, "Whom does this ayah warn?",
                'Those who say, "Allāh has taken a son."',
                "A people who could hardly understand [his] speech", "Two orphan boys in the city"),
            ask(5, "What does this ayah call what they say?",
                "A lie", "A report", "An example"),
        ]),
        ("What adorns the earth", 'زينة الأرض', 6, 8, [
            speaks(6, "Grief", "Patience", "Fatigue"),
            ask(7, "What does this ayah say people are tested in?",
                "Which of them is best in deed",
                "How long they remained", "Their number"),
            speaks(8, "A barren ground", "A body of dark water", "An open space"),
        ]),
    ]),
    ('cave', 'story', "The Cave", 'أصحاب الكهف', 'cave',
     ('coin', "the silver coin", 'النقود الفضية', 19), [
        ("Into the cave", 'إلى الكهف', 9, 12, [
            ask(9, "Who is this story about?",
                "The companions of the cave", "Dhul-Qarnayn", "Gog and Magog"),
            said(10, "Which of these did the youths say in the cave?",
                 "Our Lord, grant us from Yourself mercy",
                 "My Lord is most knowing of their number", "This is a mercy from my Lord"),
            speaks(11, "A number of years", "A day or part of a day", "Tomorrow"),
            ask(12, "What were the two factions calculating?",
                "What [extent] they had remained in time",
                "Their number", "The best of food"),
        ]),
        ("Standing firm", 'الثبات على الحق', 13, 16, [
            ask(13, "What were the youths increased in?",
                "Guidance", "Wealth", "[Numbers of] men"),
            said(14, "Which of these did the youths say when they stood up?",
                 "Our Lord is the Lord of the heavens and the earth",
                 "We have remained a day or part of a day", "I am greater than you in wealth"),
            ask(15, "What do the youths say their people do not bring for their deities?",
                "A clear evidence", "Provision", "Bars of iron"),
            ask(16, "Where did the youths tell one another to retreat?",
                "To the cave", "To the city", "To the rock"),
        ]),
        ("Asleep, yet guarded", 'نيام في حفظ الله', 17, 18, [
            ask(17, "Where were they lying?",
                "Within an open space", "At the entrance", "On the ship"),
            ask(18, "What would you think them to be, seeing them?",
                "Awake", "Asleep", "Fearful", inside=True),
            ask(18, "Where did their dog stretch his forelegs?",
                "At the entrance", "At sea", "In the city"),
            ask(18, "What would have filled you, had you looked at them?",
                "Terror", "Grief", "Fatigue"),
        ]),
        ("Awake", 'اليقظة', 19, 20, [
            said(19, "Which of these did they say when they woke?",
                 "We have remained a day or part of a day",
                 "That is what we were seeking", "This is parting between me and you"),
            ask(19, "What did they send one of them to the city with?",
                "Their silver coin", "Their fish", "Bars of iron"),
            ask(19, "What was he to look for in the city?",
                "The best of food", "Their treasure", "A wall about to collapse"),
            ask(20, "To what did they fear their people would return them?",
                "Their religion", "Their cave", "The city"),
        ]),
        ("Found", 'العثور عليهم', 21, 22, [
            ask(21, "What were those who found them to know is truth?",
                "The promise of Allāh", "The interpretation", "A report"),
            ask(21, "What did those who prevailed say they would take over them?",
                "A masjid", "A payment", "A barrier"),
            ask(22, "What do people guess at in this ayah?",
                "Their number", "Their treasure", "Their footprints"),
            said(22, f"Which of these is {PROPHET} told to say here?",
                 "My Lord is most knowing of their number",
                 "Our Lord, grant us from Yourself mercy", "That is what we were seeking"),
        ]),
        ("If Allah wills", 'قول: إن شاء الله', 23, 26, [
            said(23, "What does this ayah tell you never to say on its own?",
                 "Indeed, I will do that tomorrow",
                 "We have remained a day or part of a day", "That is what we were seeking"),
            said(24, "What do you add when you say you will do something tomorrow?",
                 "If Allāh wills",
                 "What Allāh willed [has occurred]; there is no power except in Allāh",
                 "This is a mercy from my Lord"),
            said(24, "What does this ayah tell you to do when you forget?",
                 "Remember your Lord",
                 "Keep yourself patient", "Present to them an example of two men"),
            ask(25, "How long did they remain in their cave?",
                "Three hundred years and exceeded by nine",
                "A day or part of a day", "The morning and the evening"),
        ]),
    ]),
    ('book', 'bridge', "Stay with the Book", 'مع كتاب الله', 'book', None, [
        ("Patience with the faithful", 'الصبر مع المؤمنين', 27, 31, [
            speaks(27, "The Book of your Lord", "The record [of deeds]", "The inscription"),
            ask(28, f"With whom is {PROPHET} told to keep himself patient?",
                "Those who call upon their Lord in the morning and the evening",
                "Those who prevailed in the matter", "The people of a town"),
            said(29, f"Which of these is {PROPHET} told to say in ayah 29?",
                 "The truth is from your Lord",
                 "I am only a man like you", "My Lord is most knowing of their number"),
            speaks(31, "Gardens of perpetual residence",
                   "Two gardens of grapevines", "The junction of the two seas"),
        ]),
    ]),
    ('gardens', 'story', "The Two Gardens", 'صاحب الجنتين', 'gardens',
     ('vine', "the grapevines", 'العنب', 32), [
        ("Two gardens, one boast", 'الجنتان', 32, 36, [
            ask(32, "What were the two gardens bordered with?",
                "Palm trees", "Bars of iron", "Bracelets of gold"),
            ask(34, "In what did the owner say he was greater than his companion?",
                "Wealth", "Guidance", "Knowledge"),
            said(35, "Which of these did he say on entering his garden?",
                 "I do not think that this will perish - ever",
                 "What Allāh willed [has occurred]; there is no power except in Allāh",
                 "This is a mercy from my Lord"),
            said(36, "Which of these did the owner of the garden say about the Hour?",
                 "I do not think the Hour will occur",
                 "Of the Hour there is no doubt", "Ever is the promise of my Lord true"),
        ]),
        ("A friend's reminder", 'موعظة الصاحب', 37, 41, [
            ask(37, "From what does his companion say he was first created?",
                "Dust", "Fire", "Iron"),
            said(38, "Which of these did the believing companion say?",
                 "He is Allāh, my Lord, and I do not associate with my Lord anyone",
                 "I am greater than you in wealth", "I do not think the Hour will occur"),
            said(39, "What did his companion tell him he should have said in his garden?",
                 "What Allāh willed [has occurred]; there is no power except in Allāh",
                 "If Allāh wills", "This is a mercy from my Lord"),
            ask(41, "What might the garden's water become?",
                "Sunken [into the earth]", "Dry remnants", "Molten copper"),
        ]),
        ("All of it gone", 'ذهاب النعمة', 42, 44, [
            ask(42, "What had the garden collapsed upon?",
                "Its trellises", "The rock", "The ship"),
            said(42, "Which of these did he say when he saw it?",
                 "I wish I had not associated with my Lord anyone",
                 "I do not think that this will perish - ever", "I am greater than you in wealth"),
            ask(43, "Who came to aid him?",
                "No company", "His companion", "His parents"),
        ]),
    ]),
    ('world', 'bridge', "This World and the Day", 'الدنيا والآخرة', 'rain', None, [
        ("Like rain on the earth", 'حقيقة الدنيا', 45, 49, [
            ask(45, "What is the life of this world likened to?",
                "Rain", "A body of dark water", "Murky oil"),
            ask(46, "What does this ayah call adornment of the worldly life?",
                "Wealth and children", "The enduring good deeds", "Bracelets of gold", inside=True),
            speaks(47, "The mountains", "The angels", "The winds"),
            speaks(49, "The record [of deeds]", "The inscription", "The Horn"),
        ]),
        ("The old enemy", 'عداوة إبليس', 50, 53, [
            ask(50, "Who did not prostrate when the angels were told to prostrate to Adam (peace be upon him)?",
                "Iblees", "Gog and Magog", "A king who seized every [good] ship by force"),
            ask(50, "What was Iblees of?",
                "The jinn", "The angels", "Gog and Magog", inside=True),
            speaks(51, "The creation of the heavens and the earth",
                   "The promise of Allāh", "The life of this world"),
            speaks(53, "The Fire", "The Horn", "The Gardens of Paradise"),
        ]),
        ("Every kind of example", 'الأمثال في القرآن', 54, 59, [
            ask(54, "What has man ever been most prone to?",
                "Dispute", "Patience", "Righteous work"),
            speaks(56, "The messengers", "The angels", "The jinn"),
            speaks(58, "The punishment", "The reward", "The record [of deeds]"),
            ask(59, "What was made for the destruction of those cities?",
                "An appointed time", "A barrier", "A structure"),
        ]),
    ]),
    ('khidr', 'story', "Musa and Al-Khidr", 'موسى والخضر', 'sea',
     ('ship', "the ship", 'السفينة', 79), [
        ("Where the two seas meet", 'ملتقى البحرين', 60, 64, [
            ask(60, f"Which place did {MUSA} say he would travel until he reached?",
                "The junction of the two seas",
                "The setting of the sun", "The rising of the sun"),
            ask(61, "What did they forget at the junction?",
                "Their fish", "Their treasure", "Their silver coin"),
            ask(63, "Who did the servant say had made him forget the fish?",
                "Satan", "Gog and Magog", "The people of a town"),
            said(64, f"Which of these did {MUSA} say when he heard about the fish?",
                 "That is what we were seeking",
                 "Bring us our morning meal", "Do not blame me for what I forgot"),
        ]),
        ("A servant given knowledge", 'العبد الصالح', 65, 70, [
            ask(65, "Whom did they find when they returned?",
                "A servant from among Our servants",
                "A people who could hardly understand [his] speech", "Poor people working at sea"),
            said(67, f"Which of these did {KHIDR} answer first?",
                 "With me you will never be able to have patience",
                 "This is parting between me and you", "I did it not of my own accord"),
            said(69, f"Which of these did {MUSA} promise?",
                 "You will find me, if Allāh wills, patient",
                 "That is what we were seeking", "Bring us our morning meal"),
            said(70, f"Which condition did {KHIDR} set?",
                 "Do not ask me about anything until I make to you about it mention",
                 "Do not blame me for what I forgot", "Do not keep me as a companion"),
        ]),
        ("The ship", 'السفينة', 71, 73, [
            ask(71, f"What did {KHIDR} do once they had embarked on the ship?",
                "Tore it open", "Restored it", "Followed a way"),
            said(71, f"Which of these did {MUSA} say then?",
                 "Have you torn it open to drown its people?",
                 "Have you killed a pure soul",
                 "If you wished, you could have taken for it a payment"),
            said(72, f"Which of these did {KHIDR} reply?",
                 "Did I not say that with me you would never be able to have patience?",
                 "This is parting between me and you",
                 "As for the ship, it belonged to poor people working at sea"),
            said(73, f"Which of these did {MUSA} say next?",
                 "Do not blame me for what I forgot",
                 "Bring us our morning meal", "That is what we were seeking"),
        ]),
        ("The boy", 'الغلام', 74, 76, [
            ask(74, "Whom did they meet next?",
                "A boy", "A king", "Two orphan boys"),
            said(74, f"Which of these did {MUSA} say then?",
                 "Have you killed a pure soul",
                 "Have you torn it open to drown its people?", "Bring us our morning meal"),
            said(75, f"Which of these did {KHIDR} reply?",
                 "Did I not tell you that with me you would never be able to have patience?",
                 "I did it not of my own accord", "This is parting between me and you"),
            said(76, f"Which of these did {MUSA} say after that?",
                 "If I should ask you about anything after this, then do not keep me as a companion",
                 "You will find me, if Allāh wills, patient",
                 "May I follow you on [the condition] that you teach me"),
        ]),
        ("The wall", 'الجدار', 77, 78, [
            ask(77, "What did they ask the people of the town for?",
                "Food", "Bars of iron", "A treasure"),
            ask(77, "What did they find in the town?",
                "A wall about to collapse", "A body of dark water", "Two gardens of grapevines"),
            said(77, f"Which of these did {MUSA} say then?",
                 "If you wished, you could have taken for it a payment",
                 "Have you killed a pure soul", "Do not blame me for what I forgot"),
            said(78, f"Which of these did {KHIDR} say then?",
                 "This is parting between me and you",
                 "With me you will never be able to have patience",
                 "Do not ask me about anything until I make to you about it mention"),
        ]),
        ("What it all meant", 'التأويل', 79, 82, [
            ask(79, "To whom did the ship belong?",
                "Poor people working at sea",
                "Two orphan boys in the city", "The people of a town"),
            ask(79, "Who seized every good ship by force?",
                "A king", "Gog and Magog", "The two factions"),
            ask(80, "What were the boy's parents?",
                "Believers", "Poor people working at sea", "Youths"),
            ask(82, "What was beneath the wall?",
                "A treasure", "A river", "Bars of iron"),
        ]),
    ]),
    ('qarnayn', 'story', "Dhul-Qarnayn", 'ذو القرنين', 'wall',
     ('iron', "the iron", 'الحديد', 96), [
        ("To the setting sun", 'الرحلة إلى المغرب', 83, 88, [
            ask(83, f"Whom do they ask {PROPHET} about?",
                "Dhul-Qarnayn", "The companions of the cave", "Gog and Magog"),
            ask(84, "What was Dhul-Qarnayn given from everything?",
                "A way", "A treasure", "A payment"),
            ask(86, "Which place did he reach first?",
                "The setting of the sun",
                "The rising of the sun", "The junction of the two seas"),
            said(88, "Which of these did Dhul-Qarnayn say there?",
                 "As for one who believes and does righteousness, he will have a reward of the best",
                 "Bring me bars of iron", "This is a mercy from my Lord"),
        ]),
        ("To the rising sun", 'الرحلة إلى المشرق', 89, 91, [
            ask(90, "Which place did he come to next?",
                "The rising of the sun",
                "The setting of the sun", "The junction of the two seas"),
            ask(90, "On whom did he find the sun rising?",
                "A people for whom We had not made against it any shield",
                "A people who could hardly understand [his] speech", "Poor people working at sea"),
            speaks(91, "Knowledge", "Patience", "Guidance"),
        ]),
        ("Between two mountains", 'بين الجبلين', 92, 95, [
            ask(93, "Where did he reach then?",
                "Between two mountains",
                "The rising of the sun", "The junction of the two seas"),
            ask(93, "Whom did he find beside them?",
                "A people who could hardly understand [his] speech",
                "A people for whom We had not made against it any shield", "The people of a town"),
            ask(94, "Whom did the people call corrupters in the land?",
                "Gog and Magog",
                "A king who seized every [good] ship by force", "The people of a town"),
            said(95, "How did Dhul-Qarnayn answer their offer?",
                 "That in which my Lord has established me is better",
                 "I am greater than you in wealth",
                 "If you wished, you could have taken for it a payment"),
        ]),
        ("Iron and copper", 'الحديد والنحاس', 96, 98, [
            ask(96, "What did he ask them to bring first?",
                "Bars of iron", "Molten copper", "Palm trees", inside=True),
            ask(96, "What did he pour over it?",
                "Molten copper", "Murky oil", "Rain"),
            ask(97, "What were Gog and Magog unable to do?",
                "Pass over it", "Understand [his] speech", "Hear"),
            said(98, "Which of these did Dhul-Qarnayn say when it was done?",
                 "This is a mercy from my Lord",
                 "I did it not of my own accord", "Our Lord, grant us from Yourself mercy"),
        ]),
    ]),
    ('closing', 'bridge', "The Closing", 'خاتمة السورة', 'sea', None, [
        ("That Day", 'يوم القيامة', 99, 102, [
            speaks(99, "The Horn", "The winds", "The record [of deeds]"),
            speaks(100, "Hell", "The Gardens of Paradise", "Gardens of perpetual residence"),
            ask(101, "What had their eyes been within?",
                "A cover", "An open space", "A body of dark water"),
            ask(102, "Whom do those who disbelieve think they can take as allies instead of Allah?",
                "His servants", "The mountains", "The winds"),
        ]),
        ("The greatest losers", 'أخسر الناس أعمالًا', 103, 106, [
            speaks(103, "The greatest losers as to [their] deeds",
                   "The believers who do righteous deeds", "The companions of the cave"),
            ask(104, "What do they think of their own work?",
                "That they are doing well in work",
                "That the promise of Allāh is truth", "That they are to fall therein"),
            speaks(105, "The Day of Resurrection", "The setting of the sun", "The rising of the sun"),
        ]),
        ("The words of Allah", 'كلمات الله', 107, 110, [
            speaks(107, "The Gardens of Paradise",
                   "Two gardens of grapevines", "The junction of the two seas"),
            speaks(108, "Any transfer", "Any shield", "Any weight"),
            ask(109, "What is the sea likened to in this ayah?",
                "Ink", "Rain", "Murky oil"),
            said(110, f"Which of these is {PROPHET} told to say here?",
                 "I am only a man like you",
                 "My Lord is most knowing of their number",
                 "Allāh is most knowing of how long they remained"),
        ]),
    ]),
]

# Word meanings whose word the script cannot find by itself. The source writes
# these three in plain spelling where the mushaf keeps an old letter:
# (ayah, the bare letters of the source's word) -> those of the mushaf's words.
WORD_SPELLING = {
    (28, 'بالغداة والعشي'): 'بالغدوة والعشي',
    (60, 'لفتاه'): 'لفتىه',
    (81, 'زكاة'): 'زكوة',
}

# A line QuranEnc files under the ayah before the one its word is in.
WORD_MOVED = {(108, 'لنفد'): 109}

# A line left out, with the reason. Its word as the source writes it is the
# last word of the ayah ("supplement"), its meaning ("ink") is that of another
# word of the same ayah, so the game does not show it under either.
WORD_LEFT_OUT = {(109, 'مددا'): 'the word and the meaning do not belong together'}


def letters(text):
    """Bare letters: no marks, one alif. Same rule as journeyLetters in Dart."""
    out = []
    for ch in text:
        c = ord(ch)
        if 0x064B <= c <= 0x065F or c == 0x0670 or 0x06D6 <= c <= 0x06ED or 0x08D3 <= c <= 0x08FF:
            continue
        if c in (0x0640, 0x00A0):
            continue
        if c in (0x0671, 0x0623, 0x0625, 0x0622):
            out.append('ا')
            continue
        out.append(ch)
    return ''.join(out)


def skeleton(text):
    """Looser than letters(): the mushaf leaves out many an alif the plain
    spelling writes, and seats the hamza differently."""
    bare = letters(text).replace('ى', 'ي').replace('ؤ', 'و').replace('ئ', 'ي')
    return bare.replace('ء', '').replace('ا', '')


DETERMINERS = {'a', 'an', 'the', 'their', 'his', 'its', 'this', 'that', 'to'}


def tokens(text):
    """The words of an English text for matching a choice against the
    translation: the footnote marks and the punctuation go, the letters stay
    as they are written, accents and square brackets included."""
    text = re.sub(r'\[\d+\]', '', text).lower()
    words = [word.strip("'’") for word in re.findall(r"[\[\]\w’']+", text)]
    return [word for word in words if word]


def holds(text, phrase):
    """Whether [phrase] stands in [text] word for word."""
    return any(text[i:i + len(phrase)] == phrase for i in range(len(text) - len(phrase) + 1))


def read_source(key):
    path = SOURCES / f'{key}_18.json'
    rows = json.loads(path.read_text(encoding='utf-8'))['result']
    return rows, hashlib.sha256(path.read_bytes()).hexdigest()


def fetch():
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    for entry in manifest['sources']:
        key = entry['key']
        request = urllib.request.Request(API.format(key=key), headers={'User-Agent': 'AthanApp tools'})
        body = urllib.request.urlopen(request, timeout=60).read()
        rows = json.loads(body)['result']
        if len(rows) != 110:
            sys.exit(f'{key}: {len(rows)} ayahs, expected 110')
        path = SOURCES / f'{key}_18.json'
        changed = not path.exists() or path.read_bytes() != body
        path.write_bytes(body)
        entry['sha256'] = hashlib.sha256(body).hexdigest()
        print(f'{key}: {"CHANGED, read the differences before building" if changed else "unchanged"}')
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    print('The versions and dates in manifest.json are typed from quranenc.com: check them there.')


def build():
    kahf = json.loads(TEXT.read_text(encoding='utf-8'))['surahs'][17]
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    problems = []
    sources = {}
    rows = {}
    for entry in manifest['sources']:
        rows[entry['use']], digest = read_source(entry['key'])
        if digest != entry['sha256']:
            problems.append(f'{entry["key"]}: the file is not the one in manifest.json')
        sources[entry['use']] = {k: entry[k] for k in (
            'key', 'en', 'ar', 'byEn', 'byAr', 'version', 'date', 'url')}
    english, tafsir, siraj = rows['translation'], rows['tafsir'], rows['words']

    def bare(ayah):
        return [letters(w) for w in kahf[ayah - 1][0].split(' ')]

    # QuranEnc's ayahs are our ayahs: same count, same letters, same order.
    for name, source in rows.items():
        if len(source) != len(kahf):
            problems.append(f'{name}: {len(source)} ayahs for {len(kahf)}')
            continue
        for number, row in enumerate(source, start=1):
            if int(row['sura']) != 18 or int(row['aya']) != number:
                problems.append(f'{name}: row {number} is {row["sura"]}:{row["aya"]}')
            if letters(row['arabic_text']).replace(' ', '') != ''.join(bare(number)):
                problems.append(f'{name}: ayah {number} is not the ayah of the bundled text')
    if problems:
        return None, problems

    def text_ok(value, arabic):
        if not value or value != value.strip() or '—' in value or '–' in value or '  ' in value:
            return False
        has_arabic = any('؀' <= ch <= 'ۿ' for ch in value)
        return has_arabic if arabic else not has_arabic

    # The meanings, copied as they are.
    ayahs = []
    for number in range(1, len(kahf) + 1):
        en = english[number - 1]['translation']
        notes = english[number - 1]['footnotes'] or ''
        ar = tafsir[number - 1]['translation']
        if not en.strip() or not ar.strip():
            problems.append(f'ayah {number}: a meaning is empty')
        if tafsir[number - 1]['footnotes']:
            problems.append(f'ayah {number}: the tafsir has a footnote this script does not carry')
        marks = re.findall(r'\[\d+\]', en)
        lines = [line for line in notes.split('\n') if line]
        if marks != [line.split(' ', 1)[0] for line in lines]:
            problems.append(f'ayah {number}: footnote marks {marks} do not match the footnotes')
        entry = {'en': en, 'ar': ar}
        if lines:
            entry['notes'] = lines
        if number in SKIP:
            entry['skip'] = True
        ayahs.append(entry)

    # Ayahs that share one tafsir text are one passage in the Arabic levels.
    passages = []
    for number in range(1, len(kahf) + 1):
        if passages and ayahs[passages[-1][-1] - 1]['ar'] == ayahs[number - 1]['ar']:
            passages[-1].append(number)
        else:
            passages.append([number])
    seen = {}
    for passage in passages:
        text = ayahs[passage[0] - 1]['ar']
        if text in seen:
            problems.append(f'ayahs {seen[text]} and {passage[0]} share a tafsir text but are apart')
        seen[text] = passage[0]
        if len(passage) > 1 and any(a in SKIP for a in passage):
            problems.append(f'passage {passage}: a skipped ayah inside a passage')

    # The word meanings: the meaning as the source has it, the word found in
    # the mushaf's own text.
    words = {}
    word_lines = 0
    for number, row in enumerate(siraj, start=1):
        if row['footnotes']:
            problems.append(f'ayah {number}: a word meaning has a footnote')
        for line in [l for l in row['translation'].split('\n') if l]:
            if ': ' not in line:
                problems.append(f'ayah {number}: cannot read the word line "{line}"')
                continue
            head, meaning = line.split(': ', 1)
            word_lines += 1
            key = (number, letters(head))
            if key in WORD_LEFT_OUT:
                continue
            ayah = WORD_MOVED.get(key, number)
            if key in WORD_SPELLING:
                want = WORD_SPELLING[key].split(' ')
                have = bare(ayah)
            else:
                want = [skeleton(w) for w in head.split(' ')]
                have = [skeleton(w) for w in kahf[ayah - 1][0].split(' ')]
            spots = [i for i in range(len(have) - len(want) + 1) if have[i:i + len(want)] == want]
            if len(spots) != 1:
                problems.append(f'ayah {number}: "{head}" is found {len(spots)} times in ayah {ayah}')
                continue
            if not meaning.strip() or meaning != meaning.strip():
                problems.append(f'ayah {number}: check the meaning of "{head}"')
            words.setdefault(ayah, []).append({'word': spots[0], 'span': len(want), 'meaning': meaning})
    for key in list(WORD_SPELLING) + list(WORD_MOVED) + list(WORD_LEFT_OUT):
        number, head = key
        if not any(letters(line.split(': ', 1)[0]) == head
                   for line in siraj[number - 1]['translation'].split('\n')):
            problems.append(f'ayah {number}: the source no longer has the word "{head}"')
    for ayah in words:
        words[ayah].sort(key=lambda entry: entry['word'])

    # The parts, the stops and the questions.
    english_words = [tokens(row['translation']) for row in english]

    def where(option, quoted):
        """The ayahs whose translation holds [option] word for word. A choice
        that is not a quoted saying may open with a word of ours ("their
        fish" for the translation's "our fish")."""
        want = tokens(option)
        found = {i + 1 for i, text in enumerate(english_words) if holds(text, want)}
        if not found and not quoted and len(want) > 1 and want[0] in DETERMINERS:
            found = {i + 1 for i, text in enumerate(english_words) if holds(text, want[1:])}
        return found

    sections = []
    expected = 1
    stories = 0
    kinds = {}
    for sid, kind, en, ar, art, keepsake, stops in SECTIONS:
        section = {'id': sid, 'kind': kind, 'en': en, 'ar': ar, 'art': art, 'stops': []}
        if sid in BLESSINGS:
            section['blessingEn'], section['blessingAr'] = BLESSINGS[sid]
        for value, arabic in ((en, False), (ar, True)):
            if not text_ok(value, arabic):
                problems.append(f'{sid}: check "{value}"')
        if kind == 'story':
            stories += 1
            section['number'] = stories
        if (kind == 'story') != (keepsake is not None):
            problems.append(f'{sid}: a story has a keepsake, a bridge has none')
        first_of_section = stops[0][2]
        last_of_section = stops[-1][3]
        if keepsake:
            kid, ken, kar, ayah = keepsake
            if not first_of_section <= ayah <= last_of_section:
                problems.append(f'{sid}: its keepsake is mentioned outside it')
            if ayah not in where(ken, False):
                problems.append(f'{sid}: "{ken}" is not in the translation of ayah {ayah}')
            if not text_ok(ken, False) or not text_ok(kar, True):
                problems.append(f'{sid}: check the keepsake names')
            section['keepsake'] = {'id': kid, 'en': ken, 'ar': kar, 'ayah': ayah}
        for index, (sen, sar, first, last, questions) in enumerate(stops, start=1):
            stop_id = f'{sid}-{index}'
            if first != expected or last < first:
                problems.append(f'{stop_id}: starts at {first}, expected {expected}')
            expected = last + 1
            for value, arabic in ((sen, False), (sar, True)):
                if not text_ok(value, arabic):
                    problems.append(f'{stop_id}: check "{value}"')
            for passage in passages:
                if first <= passage[0] <= last < passage[-1]:
                    problems.append(f'{stop_id}: the passage {passage} runs past it')
            if not 3 <= len(questions) <= 4:
                problems.append(f'{stop_id}: three or four questions')
            asked = []
            for ayah, question, answer, wrong1, wrong2, kind, inside in questions:
                quoted = kind == 'said'
                if not first <= ayah <= last:
                    problems.append(f'{stop_id}: question on ayah {ayah} lies outside {first}-{last}')
                options = [answer, wrong1, wrong2]
                if len(set(options)) != 3 or not all(text_ok(v, False) for v in options + [question]):
                    problems.append(f'{stop_id}: check the question "{question}"')
                if not question.endswith('?'):
                    problems.append(f'{stop_id}: "{question}" is not a question')
                if ayah not in where(answer, quoted):
                    problems.append(f'{stop_id}: "{answer}" is not in the translation of ayah {ayah}')
                for wrong in (wrong1, wrong2):
                    found = where(wrong, quoted)
                    here = inside and wrong == wrong1
                    if not found:
                        problems.append(f'{stop_id}: "{wrong}" is not in the translation')
                    elif (ayah in found) != here:
                        problems.append(f'{stop_id}: "{wrong}" is {"not " if here else "also "}in ayah {ayah}')
                kinds[kind] = kinds.get(kind, 0) + 1
                asked.append({'ayah': ayah, 'q': question, 'a': answer, 'w': [wrong1, wrong2]})
            if len({q['q'] for q in asked}) != len(asked):
                problems.append(f'{stop_id}: the same question twice')
            section['stops'].append({
                'id': stop_id, 'en': sen, 'ar': sar, 'first': first, 'last': last,
                'questions': asked,
            })
        sections.append(section)
    if expected != len(kahf) + 1:
        problems.append(f'the stops end at ayah {expected - 1}')
    if stories != 4:
        problems.append(f'{stories} stories, expected 4')

    data = {
        'surah': 18,
        'sources': sources,
        'sections': sections,
        'ayahs': ayahs,
        'words': {str(ayah): words[ayah] for ayah in sorted(words)},
    }
    facts = {
        'kinds': kinds,
        'passages': [p for p in passages if len(p) > 1],
        'word_lines': word_lines,
        'words_shown': sum(len(v) for v in words.values()),
    }
    return (data, facts), problems


if __name__ == '__main__':
    if '--fetch' in sys.argv:
        fetch()
    built, problems = build()
    for problem in problems:
        print(problem)
    if problems:
        sys.exit(1)
    data, facts = built
    stops = sum(len(s['stops']) for s in data['sections'])
    questions = sum(len(stop['questions']) for s in data['sections'] for stop in s['stops'])
    kinds = facts['kinds']
    print(f'{len(data["ayahs"])} ayahs, {stops} stops, {questions} English questions: '
          f'{kinds.get("said", 0)} on quoted sayings, {kinds.get("speaks", 0)} on what an ayah '
          f'speaks of, {kinds.get("ask", 0)} others.')
    print('Every choice is in the translation: the right one in its ayah, the others in other ayahs.')
    print(f'Meanings copied from {", ".join(s["key"] for s in data["sources"].values())}; '
          f'every ayah matches the Hafs text.')
    print(f'Passages that share one tafsir text: {facts["passages"]}.')
    print(f'Word meanings: {facts["words_shown"]} of {facts["word_lines"]} lines shown, '
          f'each word found in the mushaf text.')
    if '--check' not in sys.argv:
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(json.dumps(data, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
        print(f'Wrote {OUT.relative_to(ROOT)}')

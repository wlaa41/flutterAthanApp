# Quran text, fonts, tafsir and recitation sources

## The mushafs (bundled, read offline)

Every mushaf in the reader is the text and the font the King Fahd Glorious Quran
Printing Complex (KFGQPC) publishes for developers at
<https://qurancomplex.gov.sa/en/techquran/dev/>. The files were taken from the
mirror <https://github.com/thetruetruth/quran-data-kfgqpc>; the exact commit and
the SHA-256 of every source and output file are in
`tools/quran_assets_manifest.json`.

| In the app | KFGQPC data | Font | Ayat |
| --- | --- | --- | --- |
| Hafs from 'Asim (also the tajweed-coloured copy) | `hafsData_v18.json` | `hafs.18.ttf` | 6236 |
| Shu'bah from 'Asim | `ShoubaData08.json` | `shouba.8.ttf` | 6236 |
| Warsh from Nafi' | `warshData_v10.json` | `warsh.10.ttf` | 6214 |
| Qalun from Nafi' | `QaloonData_v10.json` | `qaloon.10.ttf` | 6214 |
| Al-Duri from Abu 'Amr | `DooriData_v09.json` | `doori.9.ttf` | 6217 |
| Al-Susi from Abu 'Amr | `SoosiData09.json` | `soosi.9.ttf` | 6217 |
| Al-Bazzi from Ibn Kathir | `BazziData_v07.json` | `bazzi.7.ttf` | 6220 |
| Qunbul from Ibn Kathir | `QumbulData_v07.json` | `qumbul.7.ttf` | 6220 |

What `tools/build_quran_assets.py` does, and does not do:

- The Quran text is never edited. Each ayah keeps the Complex's code points. The
  script removes only the ayah number that ends each row; the reader writes the
  same number back after a no-break space, in the same font, which draws it as
  the end-of-ayah ornament.
- The fonts are copied byte for byte (the script checks the SHA-256 after copying).
- Each text is drawn only in its own font. A riwayah's text in another font would
  show wrong or missing marks. The script checks that every character of a text
  has a glyph in that text's font, so the phone never borrows a letter or a mark
  from another font. The one exception is the no-break space before each ayah
  number, which most of these fonts leave out; the text shaper draws it with the
  font's ordinary space.
- The Quran files are plain JSON with one ayah per line, so they can be read and
  compared in the repository. They are not gzipped: the Android build unpacks
  `.gz` assets and renames them, and the app would not find them.
- The Hafs text is compared with quran.com's independent copy of the same release
  (`text_qpc_hafs`). All 6236 ayat are identical.
- Riwayat that divide verses differently are mapped to the Hafs (Kufi) numbering
  by aligning the words, so that a translation, a tafsir or a recitation filed
  under Hafs numbers can be found. The map is checked to be in order and complete
  in `test/mushaf_library_test.dart`.

The fonts carry the Complex's licence: free to use, copy and distribute, and not
to be sold or modified. The app is free and ships them unmodified. If the app is
ever sold, read that licence again first.

## Printed pages (Hafs)

The two Hafs copies open as the pages of the Madinah mushaf: 604 pages, fifteen
lines to a page, every line beginning with the word it begins with in print,
the surah banners and the basmalah on their own lines. The Complex's data says
on which page and lines a verse stands, but not at which word a line ends, so
that word-by-word layout comes from quran.com's API
(`https://api.quran.com/api/v4/verses/by_page/<page>?words=true`, word field
`line_number`). It is the layout quran.com serves with its own page fonts for
this mushaf.

`tools/build_mushaf_pages.py` fetches the 604 pages, matches every word to the
bundled text letter for letter, and writes `asset/quran/hafs_pages.json` (55 KB):
for each line of each page, the first word of the line. The record of the build
is `tools/mushaf_pages_manifest.json`. What the tool checks and decides:

- Every one of the 6,236 verses is on a page, once, and the letters of each
  verse are the letters of the bundled text. The page of every verse is the
  page the Complex's own data gives for it.
- Seven verses are cut into words differently by the two sources (for example
  `بَعۡدَ مَا` as one word or two). The layout is matched by letters, not by
  word count, and no line breaks inside such a word.
- One end mark in the source, that of 84:21, sits a line above its own word.
  It is put on its word's line.
- A line with no words is a surah banner or a basmalah. The tool names them by
  walking back from the first word of each surah, and stops if a line is left
  unexplained. Pages 1 and 2 have eight lines.
- Which lines the print sets centred (all of pages 1 and 2, and the short last
  lines of some surahs) is taken from the list in quran.com's reader
  (`quran.com-frontend-next`, `src/components/Verse/pageUtils.ts`).

`test/mushaf_pages_test.dart` rebuilds all 6,236 verses from the lines and
compares them with the text, so a page can neither drop nor repeat a word.

How the layout compares with the Complex's own data: `hafsData_v18.json` gives,
for each verse, the line it starts on and the line it ends on. On 552 of the
604 pages every verse starts and ends on those lines in this layout too. On
the other 52 pages some verses (392 in all) sit one line higher or lower in
one source than in the other, which points to two printings that differ
there. The app follows quran.com on those pages, because it is the only source
that says where each word stands. The comparison was run once, on
20 November 2026; the Complex's data is not in this repository.

The app draws these lines in the Complex's Hafs font, which is a typeface, not
the calligrapher's hand. A hand-written line holds as many words as the
calligrapher made fit; a typeface cannot stretch a letter. So the type size is
set page by page to fit the widest line. A line may be set up to three per cent
larger or smaller, and drawn up to four per cent narrower or six per cent
wider, the way a hand fills a line. What is left is made up between its words.
The words on each line are the print's; their spacing is the app's.

The other eight riwayat have no published word-by-word layout. They open as
flowing text, page after page, as before.

## Tajweed colours (Hafs only)

The colour runs come from quran.com's `text_uthmani_tajweed`
(<https://api.quran.com/api/v4/quran/verses/uthmani_tajweed>) and are moved onto
the KFGQPC Hafs spelling letter by letter. Of 59,878 runs, 59,324 are kept. The
rest fall where the two spellings differ and are left uncoloured rather than
guessed. A colour always covers a whole letter with its marks. The colours are
the widely used key (grey for letters not pronounced, blues for madd, red for
qalqalah, and so on); `lib/widgets/reader_palette.dart` holds the values.

No colour data is published for the other riwayat, so they are shown plain.

## Tafsir (fetched when opened, then kept on the phone)

Served by quran.com (`https://api.quran.com/api/v4/tafsirs/...`):

| In the app | quran.com resource |
| --- | --- |
| الميسّر, Al-Tafsir al-Muyassar (King Fahd Complex) | 16 |
| السعدي, Tafsir al-Sa'di | 91 |
| ابن كثير, Tafsir Ibn Kathir (Arabic) | 14 |
| الطبري, Tafsir al-Tabari | 15 |
| القرطبي, Tafsir al-Qurtubi | 90 |
| البغوي, Tafsir al-Baghawi | 94 |
| Ibn Kathir, abridged (English) | 169 |
| Ma'arif al-Qur'an (English) | 168 |
| Tazkirul Quran (English) | 817 |

Tafsir text is not bundled. A passage is downloaded the first time it is opened
and saved in the app's private storage. Al-Muyassar is short, so a whole surah
arrives in one request and then reads offline. Tafsir follows the Hafs verse
numbers; for another riwayah the app shows the tafsir of the Hafs verses that
hold the same words and says so.

## Translation

Saheeh International, from <https://api.alquran.cloud> (`en.sahih`), one surah at
a time. It is saved when a surah is first opened online.

## Recitation (streamed)

| Mushaf | Reciter | Source |
| --- | --- | --- |
| Hafs | Mishary Rashid Alafasy | `cdn.islamic.network/quran/audio/128/ar.alafasy` |
| Warsh | Ibrahim Al-Dosari | `everyayah.com/data/warsh/warsh_ibrahim_aldosary_128kbps` |

Both sets are filed by Hafs verse numbers. There is no verse-by-verse recording
of the other riwayat, so they play the Hafs recitation and the app says so.

## The Al-Kahf Journey

Nothing in the game explains the Quran in the app's own words. What an ayah
means is copied from a named Sunni work, letter for letter, and the Quran text
itself is never typed: an ayah is named by its number and shown whole from the
bundled Hafs text above.

| Shown in the game | Work | QuranEnc key | Version | SHA-256 of the file |
| --- | --- | --- | --- | --- |
| Meaning in English, with footnotes | Saheeh International. QuranEnc lists it as "English Translation - Noor International Center", issued by Noor International Center | `english_saheeh` | 1.1.2, 2025-06-24 | `54e79fc5007622ee75349d541eea52413bc9f63911baeddf33344d4525ad1851` |
| Meaning in Arabic | al-Tafsir al-Muyassar. "Arabic Language - At-Tafsir Al-Muyassar", issued by the King Fahd Complex for Printing the Holy Quran in Madinah | `arabic_moyassar` | 1.0.1, 2026-11-09 | `57c0cde57735bf63f0ec5633d2e9d4e992b1aa8317173582cce86ccecf9624f1` |
| Meanings of single words | "Arabic Language - Meanings of Words", from the book As-Siraj fi Bayan Gharib al-Quran | `arabic_seraj` | 1.0.0, 2017-02-15 | `cd8d1195c8c04449d206e2c2cdd476aaf7316ccf9d5da9639d9125c1b1c74389` |

- **Where the files come from.** QuranEnc.com (the Noble Quran Encyclopedia)
  serves each work one surah at a time at
  `https://quranenc.com/api/v1/translation/sura/<key>/18`. The three answers
  for Surah 18 are kept exactly as downloaded in `tools/sources/quranenc/`,
  with their titles, issuers, versions and checksums in `manifest.json`. They
  were fetched on 2026-11-26. `python3 tools/make_kahf_journey.py --fetch`
  downloads them again and says whether anything changed.
- **QuranEnc's terms for using its texts**, as its pages state them: no change,
  addition or deletion; credit the publisher and QuranEnc.com; give the version
  number; keep the information about the work; tell the source of any note on
  it; keep up with the latest version; no unsuitable advertising. The game
  shows the texts unchanged and names the work, its issuer, its version and
  QuranEnc.com on its Sources page. The app carries no advertising. When a
  work gets a new version, fetch it, read what changed and rebuild.
- **What `tools/make_kahf_journey.py` does with them.** It copies and checks;
  it changes no letter.
  - Each of the three files must hold the 110 ayahs of the surah, and the Quran
    text QuranEnc sends with each one must have the letters of the bundled Hafs
    text. Otherwise nothing is written.
  - The English meaning of an ayah is the translation's text with its footnote
    marks, and the footnotes under it. 24 ayahs have footnotes, 26 in all.
  - The Arabic meaning is al-Tafsir al-Muyassar's text. It explains four groups
    of ayahs in one text each (2 and 3, 23 and 24, 35 and 36, 39 to 41). The
    game shows and asks the ayahs of a group together, so the text is never
    split or shown under one ayah of several.
  - A word meaning is a line of As-Siraj: the word, then its meaning. The
    meaning is kept letter for letter. The word is not shown in the book's
    plain spelling: the tool finds it in the Hafs text and the game shows the
    mushaf's own word. Three words the mushaf spells with an old letter
    (ayahs 28, 60 and 81) are pointed out to the tool by hand. Of the 148
    lines, 147 are shown. One is filed by QuranEnc under ayah 108 though its
    word stands in ayah 109, and the game shows it under 109. One, in ayah
    109, pairs the last word of the ayah with the meaning of another word of
    the same ayah, and is left out.
- **What the app wrote.** The names of the eight parts and 28 stops, and the
  stems of 108 English questions. They are not a scholar's words. The choices
  under the questions are not the app's:
  - the right choice is a phrase of the translation of the ayah asked about;
  - every other choice is a phrase of the translation of another ayah of the
    surah (in four questions, of the same ayah, where the ayah itself sets two
    things against each other, such as awake and asleep);
  - in the 30 questions that ask what someone said, all three choices are
    sayings quoted from the translation;
  - 18 questions on ayahs about Allah, His promise, His punishment or the
    unseen ask only which of three things the ayah speaks of.

  The tool checks every choice against the translation word by word, and
  `test/journey_test.dart` checks it again from the source files.
- **How the Quran is shown.** An ayah always stands whole, with its end mark,
  in the mushaf's own font, at every level and when reciting. A choice that was
  picked wrongly is set apart, never crossed out. The optional word meanings
  show the single word they explain. The pictures show places and things only.
- **The sign ﷺ.** The meanings write it as one character (U+FDFA), which Baloo
  Bhaijaan 2 does not draw. `tools/make_journey_fonts.py` takes that one glyph
  from Noto Naskh Arabic (The Noto Project Authors, SIL Open Font License 1.1,
  `asset/fonts/noto_naskh_arabic_OFL.txt`; source
  `tools/fonts/NotoNaskhArabic-wght.ttf`, version 2.021, from
  <https://github.com/google/fonts/tree/main/ofl/notonaskharabic>) and saves it
  as `asset/fonts/journey_signs.ttf` under the name "Journey Signs". The game's
  text falls back to it for that sign only.
- **Font.** Baloo Bhaijaan 2 by Ek Type, SIL Open Font License 1.1
  (`asset/fonts/baloo_bhaijaan2_OFL.txt`), from
  <https://github.com/google/fonts/tree/main/ofl/baloobhaijaan2>. Upstream is one
  variable file (`tools/fonts/BalooBhaijaan2-wght.ttf`, version 1.701).
  `tools/make_journey_fonts.py` pins four weights (400, 600, 700, 800) and
  merges overlapping outlines, because Flutter's text engine on Android draws
  small notches where the strokes of the variable file cross. Nothing else is
  changed. The licence declares no reserved font name.
- **Recitation played in the game.** Mishary Rashid Alafasy, streamed from the
  same source as the Hafs reader above.
- **Listening model.** `quran-asr-tiny` by Abdou
  (<https://huggingface.co/Abdou/quran-asr-tiny>), MIT licence for code and
  weights; its card lists the recitation datasets it was trained on, which keep
  their own terms. It is not bundled. The app fetches revision
  `a291b33fd5a31cc4f212363ee1ba2d56d9710b49` the first time someone recites:
  `model.int8.onnx` (18,850,806 bytes, SHA-256
  `58de6db034bb4f6516b3bc1c68e7a0ac4e77abffe603a550ee87b39dcd0c7ac6`) and
  `tokens.txt` (180 bytes, SHA-256
  `75b53814499cee84a07c7b7a318524d30bcaf84273c0f8b28a04176023e8c74f`). A file
  that does not match is thrown away.
- **Running it.** `sherpa_onnx` 2.0.3 (Apache 2.0), which carries ONNX Runtime
  (MIT), runs the model on the phone. `record` 7.2.0 (BSD 3-Clause) records the
  recitation as a 16 kHz WAV file in the app's temporary folder; the file is
  deleted once it has been checked. Nothing recorded is sent anywhere.

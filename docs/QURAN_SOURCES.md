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

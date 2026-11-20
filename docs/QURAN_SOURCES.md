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

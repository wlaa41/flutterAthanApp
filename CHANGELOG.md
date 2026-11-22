# Changelog

## 2.2.0-rc.11 (build 21)

- New built-in athan: **Muhammad Marwan Qassas · clear** (محمد بن مروان), the
  "clear sound" edit with added reverb shared on TikTok by @chahr_2. It is
  bundled, so it plays offline with nothing to download: the full 3:42 on
  Android, a 28-second excerpt for iPhone notifications.
- It is a different recording from the Qassas athan in Trending athans (Asr,
  3 Safar 1440). Both stay.
- Taken from the video as saved from the TikTok app (128 kb/s AAC, four times
  the web copy), ending before TikTok's end card and logo sound. Source,
  checksum and permission notes are in `asset/AUDIO_SOURCES.md`; the in-app
  Audio credits list it too.
- `tools/prepare_featured_audio.py`: `--only` rebuilds the listed recordings
  without re-encoding the others; a recording with no public download is read
  from `--source-dir`; `end_seconds` ends a recording early.

## 2.2.0-rc.10 (build 20)

- Weekly beep days need **Confirm**. Turning the schedule on or off, a day,
  All day or the hours: each is a draft, shown as "Not saved yet" with what
  it will do, until Confirm is pressed. Cancel puts it back. No days at all
  cannot be confirmed. The same on the home card, in its Hours sheet and in
  Settings. The quick Beep buttons (Next prayer, Today, Until I turn it off)
  still act on one tap.
- **Beep away from home** (Android). Set home where you stand, pick where
  "away" starts (150 m, 300 m, 500 m or 1 km) and Confirm. Away from home,
  every Athan and Iqama recording becomes your beep; at home they play as
  usual. Vibrate and silent choices are never turned into sound.
- How it knows: Android's geofence around home, and at each prayer a recent
  location if the phone has one (or one asked for, at most 3 s). Unknown
  means the Athan plays as usual.
- Battery: no tracking and no background location updates. The geofence is
  Android's low-power one, set to report within 5 minutes (Google's battery
  saving value); the prayer-time check runs only without a recent fix, at
  balanced power. GPS is used once, when home is set. Location stays on the
  phone.
- Needs location set to "Allow all the time"; the app asks after Confirm and
  the row on the Beep card says when it is missing.
- Validation: 201 Dart tests; 26 native tests on Android 9, 14 and 16
  (Robolectric) in CI. Not tried on a physical phone.

## 2.2.0-rc.9 (build 19)

- The athan plays again. On Android 14 and later, an app may only set an
  on-time alarm if the phone allows it, and new installs are not allowed by
  default. Without it, the app fell back to a late, quiet notification and
  never started the athan. Athan now declares itself an alarm app
  (`USE_EXACT_ALARM`), which Android 13+ grants at install, so the alarm fires
  at prayer time and the athan is allowed to start from the background.
- The athan plays as an alarm: alarm volume, the alarm audio channel.
- Silent or vibrate mode: the phone vibrates at prayer time, three long pulses
  twice, as an alarm vibrates, which goes through on silent. The reminder
  shows on the lock screen. Do Not Disturb gets a reminder only.
- Notification permission is no longer required for the athan. Reminders are
  still scheduled and the athan still plays without it.
- First launch asks for notifications, then to let Athan run in the
  background (battery saving can hold the alarm back).
- If the app refreshed its schedule at the moment an alarm went off, that
  athan was dropped. It now plays, and never twice.
- **Reminder readiness** (Settings, phone) shows the next athan, the sound
  mode and what still blocks it, with **Test in 1 minute**: a test through the
  same alarm a real prayer uses, so it can be checked with the phone locked.
- Validation: 197 Dart tests, plus 14 tests of the native alarm path run on
  Android 9, 14 and 16 (Robolectric) in CI. Not tried on a physical phone.

## 2.2.0-rc.8 (build 18)

- Hashem Al-Saqqaf, muezzin of the Grand Mosque in Makkah, joins the athans
  asked for by name in **Trending athans**: his Dhuhr athan of 1 Safar 1444,
  the cleanest complete recording of his that could be reached (no clipping,
  nothing cut at either end).
- That recording was made very quietly, about 16 dB below the other athans.
  After it passes its checksum, the phone raises it by 16.5 dB the way mp3gain
  does, by adding to the gain each MP3 frame already carries. The sound is
  scaled exactly and nothing is re-encoded, so at prayer time it is as loud as
  the others.
- Validation: 193 tests pass, and the recording was added through the app's own
  downloader from its real source; the kept file measures -12.6 LUFS with
  peaks at -1.2 dBFS. Not tried on a physical phone.

## 2.2.0-rc.7 (build 17)

- The Quran opens as the printed page. Both Hafs copies now show the Madinah
  mushaf page by page: 604 pages, fifteen lines, every line beginning with the
  word it begins with in print, the surah banners and the basmalah on their
  own lines, centred lines centred. Swipe to turn the page; the next page
  comes from the left, as in the book. **Go to page** jumps to a page number.
- The line breaks are data, not guesses: the word-by-word layout of the mushaf
  from quran.com, matched to the bundled text letter for letter. A test
  rebuilds all 6,236 verses from the lines and compares them with the text.
- The tajweed colours now have their key on the page. A strip under the text
  shows every colour beside the name of its rule, in English and Arabic, on
  the printed pages and on flowing text. A tap opens what each rule means.
- **Printed pages** is how the reader opens. **Flowing text** (one surah at
  any text size, with handwritten notes) is one tap away under the tune
  button, and the choice is remembered. The other eight riwayat have no
  published line layout and open as flowing text.
- A phone held sideways keeps the page at full width and scrolls it, instead
  of shrinking fifteen lines into the screen.
- Long mushaf and rule names in the sheets wrap with large system text.
- The page is set in the Complex's typeface, not the calligrapher's hand, so
  the words on each line are the print's and the spacing between them is the
  app's. Details are in `docs/QURAN_SOURCES.md`.
- Validation: 186 tests pass. Not tried on a physical phone.

## 2.2.0-rc.6 (build 16)

- Weekly beep days are on the home Beep card. One switch turns them on with
  the defaults: one beep, Monday to Friday, 09:00 to 17:00. Seven day buttons
  on the card add or drop a day with one tap, and **Hours** opens the presets,
  **All day** and the start and end times.
- The card says when the schedule applies at this moment ("on now"), and the
  weekly days stay on the card while Beep mode is on.
- The schedule itself is the one that already lived in Settings, so existing
  choices carry over. It stays off until switched on, so nobody's Athan
  becomes a beep on its own. Settings now uses the same name, **Weekly beep
  days**.
- Validation: 161 tests pass, among them the card at 320 x 568 with doubled
  text. Not tried on a physical phone.

## 2.2.0-rc.5 (build 15)

- More athans. The sound picker opens with **Trending athans**: Muhammad Marwan
  Qassas of the Prophet's Mosque, Muhammad Jazi Abdullah of Irbid in two
  versions (the full athan, and the short part that is shared everywhere, from
  "Hayya 'ala-s-salah" to the end), and twelve more muezzins and reciters,
  among them Ahmad Al-Nafees, Hamad Al-Daghriri, Mansour Al-Zahrani and Yasser
  Al-Dosari.
- Tap the download button on one and it is fetched once, checked against a
  recorded size and SHA-256, and kept on the phone. After that it previews and
  plays at prayer time like a bundled athan, with no connection. A bin button
  removes one that is not in use.
- The recordings are fetched from their public sources and are not inside the
  app or this repository: the two named recordings state no reuse licence, and
  bundling fourteen would pass the APK size limit. Details are in
  `asset/AUDIO_SOURCES.md`.
- The short Jazi athan is cut on the phone from the full recording at a frame
  boundary, without re-encoding, so adding it also adds the full one.
- On iPhone an added athan plays in previews and its notification uses a beep,
  as imported audio does.
- Validation: 151 tests pass. All fourteen files were fetched through the app's
  downloader from the real sources and matched their checksums. Not tried on a
  physical phone.

## 2.2.0-rc.4 (build 14)

Review pass over the icon, Beep and Quran rounds.

- The Quran screens now fit a small phone with large system text: the surah
  list header scrolls with the list, the filter chips and the highlight colours
  wrap, and the page rule and action labels no longer run off the edge.
- Changing the text size keeps the passage being read on screen and lays the
  surah out once, when the slider rests, instead of on every step.
- Copy works at once; it adds the meaning only if it is already on the phone.
- While a beep plays, its notification names the prayer instead of saying
  "Tap Stop to end the recitation".
- The asset build now proves that each mushaf's font has a glyph for every
  character of its text (it does, for all eight).
- Validation: 119 tests pass, including one that opens every Quran screen at
  320 x 568 with doubled text. Still not tried on a physical phone.

## 2.2.0-rc.3 (build 13)

- The Quran is now inside the app and opens offline, in the mushafs of the King
  Fahd Complex: Hafs in Uthmani script, Hafs with tajweed colours, Warsh, Qalun,
  Shu'bah, Al-Duri, Al-Susi, Al-Bazzi and Qunbul. Choose one from the Quran tab
  or from the tune button while reading.
- Letters join correctly. The old reader had no Quran font and changed the font
  weight in the middle of words, which split them. Each mushaf is now one flowing
  paragraph per printed page in the Complex's own font for that riwayah, and a
  tajweed colour changes the colour only.
- Tafsir for every verse: Al-Muyassar, Al-Sa'di, Ibn Kathir, Al-Tabari,
  Al-Qurtubi and Al-Baghawi in Arabic, and Ibn Kathir (abridged), Ma'arif
  al-Qur'an and Tazkirul Quran in English. A passage is fetched from quran.com
  the first time and then kept on the phone.
- Riwayat that number verses differently show their own numbers; meaning and
  tafsir are found through the matching Hafs verses, and the app says which.
- Warsh plays a Warsh recitation (Ibrahim Al-Dosari). The other non-Hafs
  riwayat have no verse-by-verse recording and say that they play Hafs.
- Also new: a night page, a text size slider, a bookmarks list, "Continue
  reading", highlights that are remembered, and handwritten notes that scroll
  with the page. Notes drawn in earlier versions are not shown, because the text
  is laid out differently now.
- Validation: 118 tests pass (30 new; 8 tests of the old download path are
  retired). Every ayah of all eight texts is checked
  for order and for its Hafs mapping; the Hafs text matches quran.com's copy for
  all 6236 ayat; 59,324 of 59,878 tajweed colour runs are placed and the rest are
  left uncoloured. Rendering was inspected in screenshots for all the fonts, and
  the built APK was opened to confirm each Quran file and font is inside it,
  byte for byte.
  Recitation playback, the tafsir downloads on a real connection and performance
  on a phone have not been tried on a physical device.

## 2.2.0-rc.2 (build 12)

- Beep mode: one tap on the home screen swaps every Athan and Iqama for your beep,
  for the next prayer, for today, or until you turn it off. The card shows when the
  Athan returns and has a Back to Athan button.
- The same switch without opening the app on Android: an "Athan beep" quick
  settings tile, "Beep today" and "Athan as usual" when you long-press the app
  icon, and a "Beep today" button on the notification while a recitation plays.
  The phone applies the switch at the moment a reminder fires.
- Beep power: five levels from Soft to Maximum, with a Test button. The old tones
  peaked at -16.5 dBFS on a 660 Hz sine that phone speakers barely reproduce; the
  default is now about 15 dB louder and sits between 1 and 3 kHz. Loudness is in
  the files, so it also applies to iPhone alerts and to Android's late-alarm tone.
- New "Strong beep" sound, optional vibration with the beep, and an option to
  play beeps at the phone's alarm volume. A beep now leaves a quiet notification
  saying which prayer it was for.
- Validation: 96 tests passed (13 new); analysis reports 60 infos, no warnings or
  errors; the Android release build compiles the new Kotlin. The tile, shortcuts,
  vibration and loudness have not been tried on a physical phone.

## 2.2.0-rc.1 (build 11)

- New app icon: keel arch, inner dome, crescent and two minarets drawn as pen
  strokes of changing pressure, in OW yellow-green on the OW dark ground. Android
  gets a proper adaptive icon (round, squircle and themed variants); iPhone no
  longer shows the Flutter placeholder. `tools/make_app_icon.py` redraws every size.
- The old logo artwork moved from the bundled `asset/` folder to `design/legacy/`,
  which takes about 2 MB out of the app.
- CI now commits the signed phone build to the repository root as `AthanApp.apk`
  after each push to `main`.

## 2.1.0-rc.8 (build 10)

- Split Settings into Basics, Reminders and Phone setup, with city and sound choices
  first and direct home-screen shortcuts. Prayer rows show reminder on/muted state.
- Choose, preview and import audio in one sound picker. Selection is applied only
  with Use sound; imported files remain in the library when the picker is cancelled.
- Added weekday/weekend/every-day shortcuts and explicit All day / Set hours choices
  for a beep on selected days. Existing schedules and sound preferences are preserved.
- Added more named Athan recordings with bundled offline playback, short iPhone
  notification excerpts and accessible audio credits (see asset/AUDIO_SOURCES.md).
- Version/build advanced for in-place updates using the existing trusted CI signing key.
- Validation: 83 tests passed; analysis reports 57 infos, no warnings/errors. Phone
  layouts inspected; audio decodes and Android/iPhone asset mappings verified.

## 2.1.0-rc.7 (build 9)

- Stabilized trusted preview signing with a private GitHub Actions secret and a
  certificate check, so future preview updates can keep app data. Fork builds do
  not receive the key. Older differently signed previews need one clean install.
- Excluded keystore files from Git; production/store signing remains separate.
- Validation: CI verifies the expected signing certificate before publishing an
  APK artifact. rc.6 passed all 69 tests, both platform builds and iPhone startup;
  actual Android import/preview, private-copy persistence and native custom-sound
  playback also passed.

## 2.1.0-rc.6 (build 8)

- Pinned the Android storage implementation to compatible `path_provider_android`
  2.2.23 after release-device tests exposed a JNI binding mismatch affecting both
  custom audio imports and in-app previews. Other JNI dependencies are unchanged.
- Added staged import and preview diagnostics for future device-specific failures.
- Validation: 20 focused audio/hero/settings tests pass and changed Dart analysis
  is clean. rc.5 also passed all 69 tests, both platform builds and iPhone startup.
  The corrected release APK must pass real-picker import/preview checks before
  handoff; results are recorded in the pull request.

## 2.1.0-rc.5 (build 7)

- Improved navigation label contrast and size after inspecting the Android release
  app on an emulator.
- Allowed ten minutes for the iPhone simulator's initial boot; the app must still
  stay alive for 15 seconds and produce a screenshot.
- Recorded live fetch checks, emulator coverage and physical-device limitations.
- Validation: the navigation regression passes. The preceding checkpoint passed
  all 69 tests, analysis, Android release and iOS compilation; this checkpoint's CI
  records final platform and iPhone startup results.

## 2.1.0-rc.4 (build 6)

- Added a real iPhone simulator startup check after the CI build: launch the app,
  check it stays alive, capture a screenshot, and shut down the test simulator.
- Added Gradle dependency caching to speed up later verification loops.
- Validation: rc.3 passed all 69 tests, analysis, Android release APK compilation
  and iOS simulator compilation. The new smoke script passes shell syntax checks;
  its first runtime result is recorded in this checkpoint's CI.

## 2.1.0-rc.3 (build 5)

- Restored Flutter's standard Android project evaluation order so the maintained
  file-picker plugin can access the Flutter SDK configuration.
- Excluded generated Android build diagnostics from version control.
- Validation: the previous checkpoint passed CI analysis and tests; native builds
  validate this configuration change in the checkpoint's CI run.

## 2.1.0-rc.2 (build 4)

- Calendar scheduling now uses one location/method snapshot for every month. A
  location change during fetching retries once; repeated changes fail safely
  instead of returning a timetable that mixes cities.
- Iqama settings explain the sunrise/next-prayer cutoff.
- Validation: all 17 prayer reliability tests pass, including two asynchronous
  location-change regressions; all 9 settings tests pass.

## 2.1.0-rc.1 (build 3)

- Added bundled Athan/Iqama recordings, gentle tones, private audio imports, and
  configurable Iqama delay, total reminders, and interval.
- Added editable work hours with weekday selection and quiet replacement sounds.
- Android now uses a persisted queue with one armed alarm and no background
  polling; playback has a Stop action and bounded resource use.
- Added notification/precise-alarm readiness, permission actions, and scheduling
  coverage information, with the shorter iPhone sound limit explained in settings.
- Hardened calendar fetching, caching, timezone handling, offline calculations,
  Quran chapter validation, and city-based Qibla bearings.
- Improved small-screen and large-text settings layouts and regression coverage.

This is a testing checkpoint. Physical-device battery and manufacturer-specific
background delivery checks remain listed in `docs/verification.md`.

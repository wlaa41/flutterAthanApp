# Changelog

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

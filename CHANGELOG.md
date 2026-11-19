# Changelog

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

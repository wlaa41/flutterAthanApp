# Changelog

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

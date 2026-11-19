# Changelog

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

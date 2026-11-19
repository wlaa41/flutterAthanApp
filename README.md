# Athan & Quran

Flutter prayer reminders with local sound playback, an offline prayer-time fallback,
Quran reader, and editable work hours. Android 7+ (API24); iOS15+.

## Reminders that fit your day

- Choose Classic Athan, Beautiful Athan, an Iqama recitation, soft beep, double beep,
  chime, vibration, or silence. Recordings and tones are bundled, not streamed.
- Import an MP3, M4A, or WAV from the system file picker (up to20MB/10minutes).
  The app keeps a private copy; no broad storage permission is needed.
- Enable Iqama, set the delay after prayer (1–120minutes), total reminders (1–5),
  and spacing (1–30minutes). Repeats stop before the next prayer.
- Work hours start with Monday–Friday,09:00–17:00, and are opt-in. Edit weekdays,
  start/end, and the replacement tone. Overnight shifts belong to the starting day.
  Equal start/end means the entire selected day. Work hours apply to Athan and Iqama
  at each alert's time in the selected city's timezone.
- Muting a prayer immediately rebuilds its Athan and Iqama schedule.

## Reliability and battery use

Android persists up to60days of events and arms only the next system alarm. After
an event it arms the following one, and restores the queue after reboot, app
update, clock changes, or granting precise-alarm access. Full recordings use a
foreground service only while playing, with a visible Stop action and a10minute
maximum. There is no periodic background polling, location tracking, or permanent
service. Screen countdowns stop when the app is not active.

Allow **Notifications**, then **Precise alarms** in Settings. Without precise alarm
access, reminders use an inexact system alarm and a short tone; delivery may be
late. Built-in quiet tones still apply. Ringer silence, Do Not Disturb, audio focus,
and a disabled playback notification channel are respected. Reopen after an
Android Force stop or permission revocation. Some manufacturers restrict apps
further; the Battery settings shortcut provides a manual remedy for late alerts.
The app does not automatically request a battery exemption.

On iPhone, the app queues the next60notifications (under the system limit), so
frequent Iqama reminders shorten the covered period. Settings shows the scheduled
through date: reopen before then to refill. Local notification sounds must be
under30seconds: new recitations use28second excerpts, Classic uses a chime,
and unsupported imported formats/long recordings use a beep. Full recordings
remain available for preview. Vibration follows iOS settings and is not guaranteed
by the vibration-only selection. Silent mode/Focus can suppress notification audio.

## Prayer data

Aladhan calendars are validated for complete dates, valid times, order, and selected
city timezone. Requests have a timeout and bounded retry; concurrent fetches share
one request. Cache keys include coordinates, method, timezone, month and year.
Online calendars are reused for24hours; calculated fallback retries after30minutes.
Explicit refresh bypasses the cache. Cached data and the MIT-licensed
[adhan_dart](https://github.com/prayer-timetable/adhan_dart) calculation library
keep prayer times available offline. Calculated times are identified in the UI.

The old option labelled “London Unified / Islamic Relief” incorrectly sent Aladhan
method10(Qatar). UK presets now use Moonsighting Committee(15), and the picker
shows actual method names. Compare the chosen method with your local mosque.
Quran fetches validate the requested chapter and translations; an unavailable
chapter is never replaced by a different Surah. Only Al-Fatiha and Al-Ikhlas have
bundled offline text; other chapters need a successful initial download.

## Development

Flutter3.50.0 is pinned in CI. Use Java17, Android SDK36, and the Gradle versions
committed here. iOS builds require macOS/Xcode and CocoaPods.

```sh
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --debug
# macOS only
flutter build ios --simulator --debug --no-codesign
```

CI runs analysis/tests and creates a preview APK for each pull request. It does not
publish a store release or overwrite an existing GitHub release. Release builds
still use the repository's original debug-signing setup; configure your own signing
before store distribution.

See [audio attribution](asset/AUDIO_SOURCES.md) and
[verification notes](docs/verification.md) for sources and device-test coverage.

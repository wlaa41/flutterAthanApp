# Athan & Quran

Flutter prayer reminders with local sound playback, an offline prayer-time fallback,
an offline Quran reader in nine mushafs with tafsir, and editable work hours.
Android 7+ (API 24); iOS 15+.

## Install on Android

On your phone, open
[AthanApp.apk](https://github.com/wlaa41/flutterAthanApp/raw/main/AthanApp.apk)
(the file at the top of this repository) and install it. Every push to `main`
rebuilds it: once the checks pass, CI commits the freshly signed APK to the
repository root, so that file is always the latest build and updates the
installed app in place. It is built for 64-bit ARM, which is what phones use;
an APK for every processor type would be over GitHub's 100 MB file limit.

## Reminders that fit your day

- Choose Classic Athan, Beautiful Athan, Mishary Alafasy, Makkah (Ali Mulla),
  Madinah, Abdul Basit, Minshawi, or Nasser Al Qatami, plus an Iqama recitation,
  beep, double beep, chime, strong beep, vibration, or silence. Recordings and tones are
  bundled, not streamed. Audio credits are available in Settings.
- **Trending athans** at the top of the sound picker adds more muezzins with one
  tap: Muhammad Marwan Qassas (Madinah), Muhammad Jazi Abdullah (Irbid) in full
  and as the short, widely shared part, and twelve more. The phone fetches a
  recording once from its public source, checks it against a recorded checksum
  and keeps it, so reminders play it offline. Sources are in
  `asset/AUDIO_SOURCES.md`.
- Open **Settings → Basics → Choose or add a sound** to compare recordings, preview
  them, and add an MP3, M4A, or WAV from your phone (up to 20 MB / 10 minutes).
  Tap **Use sound** to apply your choice. Cancelling keeps your previous choice;
  imported files remain in your private sound library.
- Enable Iqama, set the delay after prayer (1–120 minutes), total reminders (1–5),
  and spacing (1–30 minutes). Repeats stop before sunrise for Fajr or the next prayer.
- Somewhere the Athan should stay quiet? Tap **Next prayer**, **Today** or
  **Until I turn it off** on the home screen card and every Athan and Iqama
  becomes your beep until then. On Android the same switch is an **Athan beep**
  quick settings tile, a long-press on the app icon, and a **Beep today** button
  on the notification while a recitation plays.
- **Settings → Reminders → Beep sound and power** sets the tone (Beep, Double
  beep, Gentle chime, Strong beep, vibration or silence), its power from Soft to
  Maximum with a Test button, a buzz with the beep, and whether it follows the
  phone's alarm volume.
- For a beep on specific days: **Settings → Reminders → Beep on chosen days**.
  Turn on **Use a quieter reminder**, select your days (or Weekdays / Weekend /
  Every day), then choose **All day** or **Set hours**. Beep is the default;
  other days and hours keep your usual sounds. Applies to Athan and Iqama in the
  selected city's timezone. Existing schedules are preserved; the initial optional
  schedule is Monday–Friday, 09:00–17:00. Overnight hours belong to the starting day.
- Muting a prayer immediately rebuilds its Athan and Iqama schedule.

## Quran

- The whole Quran is in the app and opens offline. Choose the mushaf from the
  Quran tab: Hafs in Uthmani script, Hafs with tajweed colours, Warsh, Qalun,
  Shu'bah, Al-Duri, Al-Susi, Al-Bazzi or Qunbul. Each is the King Fahd Complex
  text drawn in the Complex's own font for that riwayah, so the letters join
  as they do in print.
- The text flows page by page like the printed mushaf, with the page and juz
  marked. The tune button sets the text size and a night page.
- Tap a verse for its meaning (Saheeh International), its tafsir, recitation,
  a bookmark, a highlight or a handwritten note. Bookmarks are listed from the
  Quran tab, which also offers to continue where you stopped.
- Tafsir: Al-Muyassar, Al-Sa'di, Ibn Kathir, Al-Tabari, Al-Qurtubi and
  Al-Baghawi in Arabic; Ibn Kathir (abridged), Ma'arif al-Qur'an and Tazkirul
  Quran in English. A passage is downloaded the first time and then kept on
  the phone. Translation and recitation also need a connection the first time.
- Warsh, Qalun, Al-Duri, Al-Susi, Al-Bazzi and Qunbul number some verses
  differently from Hafs. The app shows each mushaf's own numbers and looks up
  the meaning and tafsir by the matching Hafs verses.

Sources, licences and what was checked are in
[docs/QURAN_SOURCES.md](docs/QURAN_SOURCES.md).

## Reliability and battery use

Android persists up to 60 days of events and arms only the next system alarm. After
an event it arms the following one, and restores the queue after reboot, app
update, clock changes, or granting precise-alarm access. Full recordings use a
foreground service only while playing, with a visible Stop action and a 10 minute
maximum. There is no periodic background polling, location tracking, or permanent
service. Screen countdowns stop when the app is not active.

Allow **Notifications**, then **Precise alarms** in Settings. Without precise alarm
access, reminders use an inexact system alarm and a short tone; delivery may be
late. Alerts delayed more than 10 minutes become silent reminders. Built-in quiet
tones still apply. Ringer silence, Do Not Disturb, audio focus,
and a disabled playback notification channel are respected. Reopen after an
Android Force stop or permission revocation. Some manufacturers restrict apps
further; the Battery settings shortcut provides a manual remedy for late alerts.
The app does not automatically request a battery exemption.

On iPhone, the app queues the next 60 notifications (under the system limit), so
frequent Iqama reminders shorten the covered period. Settings shows the scheduled
through date: reopen before then to refill. Local notification sounds must be
under 30 seconds: new recitations use 28 second excerpts, Classic uses a chime,
and unsupported imported formats/long recordings use a beep. Full recordings
remain available for preview. Vibration follows iOS settings and is not guaranteed
by the vibration-only selection. Silent mode/Focus can suppress notification audio.

## Prayer data

Aladhan calendars are validated for complete dates, valid times, order, and selected
city timezone. Requests have a timeout and bounded retry; concurrent fetches share
one request. Cache keys include coordinates, method, timezone, month and year.
Online calendars are reused for 24 hours; calculated fallback retries after 30 minutes.
Explicit refresh bypasses the cache. Cached data and the MIT-licensed
[adhan_dart](https://github.com/prayer-timetable/adhan_dart) calculation library
keep prayer times available offline. Calculated times are identified in the UI.

The old option labelled “London Unified / Islamic Relief” incorrectly sent Aladhan
method 10 (Qatar). UK presets now use Moonsighting Committee (15), and the picker
shows actual method names. Compare the chosen method with your local mosque.

The Qibla guide calculates the bearing from the selected city. Its diagram is
north-up; it does not use a live compass sensor.

## Development

Flutter 3.50.0 is pinned in CI. Use Java 17, Android SDK 36, and the Gradle versions
committed here. iOS builds require macOS/Xcode and CocoaPods.

The Android path-provider implementation is pinned to 2.2.23 because 2.3.1's
generated JNI bindings are incompatible with the resolved JNI class lookup.
Revisit that pin only with device checks for private file imports and audio previews.

```sh
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --debug
# macOS only
flutter build ios --simulator --debug --no-codesign
bash tools/ios_smoke.sh
```

CI runs analysis/tests and creates a preview APK for each pull request. On `main` it
also commits that APK as `AthanApp.apk`. It does not publish a store release or
overwrite an existing GitHub release. Trusted CI preview
builds restore a stable private debug key from the `ATHAN_PREVIEW_KEYSTORE_BASE64`
Actions secret and verify its public certificate before uploading the APK. Fork
and Dependabot pull requests cannot access that key and produce clearly labelled
disposable test builds.

From rc.7 onward, trusted previews share a signing identity so later versions can
update in place. Earlier previews with a different key need one reinstall, which
clears app-local settings and imported audio. Keep a private backup of the preview
keystore; never commit it. Configure production signing before store distribution.

Preview certificate SHA-256:
`f7f52594422cf2ce808e9510ed91ee27e42ff7efd2e9fee841d29a05a0441678`.

See [audio attribution](asset/AUDIO_SOURCES.md),
[Quran sources](docs/QURAN_SOURCES.md) and
[verification notes](docs/verification.md) for sources and device-test coverage.

To rebuild the Quran files from the King Fahd Complex data:

```sh
python3 tools/build_quran_assets.py --kfgqpc <quran-data-kfgqpc checkout> \
  --tajweed <uthmani_tajweed.json> --crosscheck <qpc_hafs.json>
```

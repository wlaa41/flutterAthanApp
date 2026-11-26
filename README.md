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

## Install on iPhone (free, for testing)

Every push to `main` also builds an unsigned iPhone app,
[AthanApp.ipa](https://github.com/wlaa41/flutterAthanApp/releases/download/ios-latest/AthanApp.ipa),
kept on the [iPhone app release](https://github.com/wlaa41/flutterAthanApp/releases/tag/ios-latest).
Sign and install it from a Windows PC or a Mac with a free Apple ID; no paid
developer account is needed.

1. On Windows, install iTunes from apple.com (not the Microsoft Store one), then
   [Sideloadly](https://sideloadly.io). On a Mac, just Sideloadly.
2. Connect the iPhone by USB, unlock it and tap **Trust**.
3. In Sideloadly, drop in `AthanApp.ipa`, enter your Apple ID and press **Start**.
   Leave **Remove app extensions** unticked under Advanced options: the alarm's
   Stop and Snooze are in an extension.
4. On the iPhone (iOS 16 and later), turn on **Settings → Privacy & Security →
   Developer Mode**; the phone restarts.
5. Trust your Apple ID under **Settings → General → VPN & Device Management**,
   then open the app and allow notifications and, on iOS 26, alarms.

A free Apple ID signs the app for 7 days. After that it stops opening until it
is signed again: repeat step 3 with the same Apple ID, which keeps your
settings, or turn on Sideloadly's automatic refresh. A free Apple ID can have 3
sideloaded apps at once. TestFlight and the App Store need the paid Apple
Developer Program (99 USD a year).

## Reminders that fit your day

- Choose Classic Athan, Beautiful Athan, Mishary Alafasy, Makkah (Ali Mulla),
  Madinah, Abdul Basit, Minshawi, Nasser Al Qatami, or Muhammad Marwan Qassas
  (clear sound edit), plus an Iqama recitation,
  beep, double beep, chime, strong beep, vibration, or silence. Recordings and tones are
  bundled, not streamed. Audio credits are available in Settings.
- **Trending athans** at the top of the sound picker adds more muezzins with one
  tap: Muhammad Marwan Qassas (Madinah), Muhammad Jazi Abdullah (Irbid) in full
  and as the short, widely shared part, Hashem Al-Saqqaf (Makkah), and twelve
  more. The phone fetches a
  recording once from its public source, checks it against a recorded checksum
  and keeps it, so reminders play it offline. Muhammad Marwan Qassas · clear is
  listed there too; it ships in the app, so there is nothing to fetch. Sources
  are in `asset/AUDIO_SOURCES.md`.
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
- **Weekly beep days**, on the same home screen card, are the days that beep
  every week. One switch turns it on as one beep, Monday to Friday, 09:00 to
  17:00. Tap a day on the card to add or drop it. **Hours** opens Weekdays /
  Weekend / Every day, **All day** or **Set hours**. Other days and hours keep
  your usual sounds. It applies to Athan and Iqama on the clock of the selected
  city, and overnight hours belong to the day they start on. The same schedule
  is under **Settings → Reminders → Weekly beep days**.
- Muting a prayer immediately rebuilds its Athan and Iqama schedule.
- **Alarm screen** (Android): when the athan plays on a locked phone, the screen
  turns black with the time, like an alarm clock. Slide right to stop, slide left
  to snooze. **Settings → Basics → Alarm screen** has **Easier screen** (any tap
  stops), the snooze length and **Try the alarm screen**. The athan's
  notification has Snooze, Stop and Beep today.

## Al-Kahf Journey

The **Journey** tab walks through Surah Al-Kahf, first ayah to last, in 28
stops. A stop shows its ayahs to read, each one whole with its meaning from a
named source, then asks three or four questions about them and lights a
lantern when they are all answered right. Nothing is timed or scored: a wrong
answer comes back at the end of the stop. Each of the four stories ends with a
keepsake its own ayahs mention: the silver coin (the Cave), the grapevines (the
Two Gardens), the ship (Musa and Al-Khidr, peace be upon them) and the iron
(Dhul-Qarnayn).

Choose how to play on the first screen; the pill at the top of the map changes
it later. Every level shows whole ayahs.

- **English**: for someone who does not read Arabic. Each ayah is shown, can be
  played, and is followed by its translation. The questions are in English.
- **Arabic**: the ayah is shown and you choose its tafsir from three texts of
  al-Tafsir al-Muyassar. **معاني الكلمات** lists the words of that ayah that
  As-Siraj explains, for whoever wants them.
- **Arabic, strong**: the tafsir is given and you choose the ayah, with no
  help.

**Recite the ayahs** comes after a lantern is lit. You are given an ayah and
recite the one after it; the phone listens and marks each word as heard, or as
missed or unclear. The ayah stays hidden until it is recited, unless you tap
**Show the ayah**. It checks the words, not tajweed.

The listening happens on the phone. The first time, the app fetches a 19 MB
Quran speech model once; after that reciting works offline, and the recording
is checked on the phone and deleted. It needs the microphone, which the app
asks for the first time **Recite** is tapped.

### What the game quotes, and what it wrote

Nothing in the game explains the Quran in the app's own words.

| Shown in the game | Copied from |
| --- | --- |
| Every ayah, always whole | The bundled Hafs text of the King Fahd Complex, never retyped |
| Meaning in English, with footnotes | Saheeh International, as QuranEnc.com serves it |
| Meaning in Arabic | al-Tafsir al-Muyassar (King Fahd Complex), as QuranEnc.com serves it |
| Meanings of single words | As-Siraj fi Bayan Gharib al-Quran, as QuranEnc.com serves it |

The optional word meanings show the single word they explain, as the mushaf
writes it. Everywhere else an ayah stands whole.

The game's **Sources** page names each work with its version. The app wrote
only the names of the stops and the wording of the 108 English questions. The
choices under a question are phrases of the translation: the right one from the
ayah asked about, the others from other ayahs of the surah. The pictures show
places and things only: no prophet, no person and no animal is drawn.

The questions and the stop names are not a scholar's words. Before a public
release they should be read by a teacher or scholar.

`tools/make_kahf_journey.py` builds the game's content from the three source
files in `tools/sources/quranenc/` and checks all of the above; the tests check
it again. Sources and licences are in `docs/QURAN_SOURCES.md`.

## Quran

- The whole Quran is in the app and opens offline. Choose the mushaf from the
  Quran tab: Hafs in Uthmani script, Hafs with tajweed colours, Warsh, Qalun,
  Shu'bah, Al-Duri, Al-Susi, Al-Bazzi or Qunbul. Each is the King Fahd Complex
  text drawn in the Complex's own font for that riwayah, so the letters join
  as they do in print.
- Hafs opens as the printed Madinah mushaf: the same 604 pages, the same
  fifteen lines, each line beginning with the same word, with the surah
  banners and the basmalah in their places. Swipe to turn the page, or use
  **Go to page**. A phone held sideways keeps the page wide and scrolls it.
- With the tajweed copy, the colour key stays under the page: each colour
  beside the name of its rule. Tap it for what each rule asks of the reciter.
- The tune button switches between **Printed pages** and **Flowing text**
  (one surah at any text size, with handwritten notes), and sets a night page.
  The other eight riwayat open as flowing text.
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
foreground service only while playing, with Snooze and Stop actions and a 10 minute
maximum. A snoozed athan goes back into the same queue. There is no periodic background polling, location tracking, or permanent
service. Screen countdowns stop when the app is not active.

Athan is an alarm app on Android: it declares `USE_EXACT_ALARM`, which Android
13+ grants at install, so the athan fires on time and may start from the
background. (On Android 12 it uses `SCHEDULE_EXACT_ALARM`.) First launch asks
for notifications, then to leave Athan out of battery optimisation.

At prayer time the phone's sound mode decides what happens:

| Phone | What you get |
| --- | --- |
| Ring | The athan at alarm volume. Locked or screen off: the black alarm screen. In use: a pop-up with Snooze and Stop |
| Vibrate or silent | Alarm vibration (felt on silent) and a lock-screen reminder |
| Do Not Disturb | A reminder only |

The athan plays even when notifications are off; only the on-screen reminder is
lost. Alerts delayed more than 10 minutes become silent reminders. Reopen after an
Android Force stop. Some manufacturers restrict apps further: Settings, phone,
**Reminder readiness** lists what still blocks the athan and has **Test in 1
minute**, which goes through the same alarm as a real prayer. Lock the phone and
wait for it.

**Beep away from home** (Android): set home on the Beep card, pick a distance,
Confirm. Outside that circle every Athan and Iqama is your beep. It uses
Android's low-power geofence (5 minute reporting) plus, at each prayer, a
recent location if one exists. No background tracking. Needs location "Allow
all the time". Weekly beep days and this rule save only on **Confirm**.

On iPhone with iOS 26 or later, the athan rings as an alarm (Apple's AlarmKit).
On a locked phone it takes over the screen with Stop and Snooze, and it rings in
Silent mode and through a Focus; with the phone in use it shows at the top of the
screen. iOS draws it, and asks once to allow alarms. The next 24 athans are kept
ready as alarms (about three days); the ones after them wait as notifications
until the app is opened. A beep, vibration only and silent reminders are always
notifications. **Settings → Basics → Alarm screen** has **Ring as an alarm**, the
snooze length and **Try the alarm**. Before iOS 26, and until alarms are allowed,
every reminder is a notification.

The app queues the next 60 reminders (under the system limit), so frequent Iqama
reminders shorten the covered period. Settings shows the scheduled through date:
reopen before then to refill. Alarm and notification sounds must be under 30
seconds: recitations use 28 second excerpts, and unsupported imported
formats/long recordings use a beep (or the iPhone alarm sound when they ring as an
alarm). Full recordings remain available for preview. Vibration follows iOS
settings and is not guaranteed by the vibration-only selection. Silent mode/Focus
can suppress notification audio.

`tools/ios_alarm_check.sh` rings two test alarms on an iOS 26 simulator with nobody
at the screen, one with the phone in use and one with it locked, and keeps a video,
pictures and logs: the two permission questions, the armed alarms, the alert, the
Live Activity and its Stop and Snooze. Starting the CI workflow by hand runs it. A
simulator plays no alarm sound and presents nothing for an alarm on a locked
screen, so the sound and the full-screen alarm of a locked phone are checked on a
real iPhone. `docs/verification.md` has what the check showed.

The alarm's Live Activity is the `AthanAlarm` extension in `ios/AthanAlarm`, built
for iOS 26; the app itself still runs on iOS 15. It was added to the Xcode project
with `tools/add_ios_alarm_target.rb` (Ruby and the `xcodeproj` gem, no Xcode). Run
that script again after adding a recitation with an iPhone excerpt
(`asset/<name>_short.wav`), so the excerpt is also copied into the app bundle.
Building for iPhone needs Xcode 26 or later.

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
bash tools/ios_alarm_check.sh   # rings two athan alarms on a simulator: build/review/alarm
flutter build ios --release --no-codesign   # unsigned iPhone app, for sideloading
```

CI runs analysis/tests and creates a preview APK and an unsigned iPhone app for
each pull request. On `main` it also commits that APK as `AthanApp.apk` and puts
the iPhone app on the `ios-latest` pre-release as `AthanApp.ipa`, replacing the
one before. It does not publish a store release or touch any other GitHub
release. Trusted CI preview
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

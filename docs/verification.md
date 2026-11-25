# Verification

## 2.2.0-rc.15 / build 25, 25 November 2026: the Al-Kahf Journey

- Local Flutter 3.50.0: all **259 unit/widget tests passed** (one more, which
  needs the speech model's files, is skipped unless they are given); static
  analysis has no warnings or errors. The 117 native Android tests pass.
- `tools/make_kahf_journey.py` checked the content against the bundled Hafs
  text before writing it: 110 ayahs in 28 stops with none left out or repeated,
  110 English questions, a meaning for every ayah in both languages, 146 word
  meanings and the four keepsakes, each pointing at words that are in the text.
- The widget tests draw the screens in the game's own fonts on a 390 × 844
  screen and walk through them: choosing a level and changing it; the map, with
  what is lit, what is locked and stops opening in order; a stop at each of the
  three levels; a wrong answer coming back at the end; leaving in the middle;
  the lantern; a keepsake at the end of a story; and reciting, with a stand-in
  for the microphone (hidden and shown ayah, heard and missed words, the best
  try kept, cancel, skip, a refused microphone, a recording too short, and the
  model fetched or failing to arrive). The map, a stop at each level and the
  recite screen are also laid out at 320 × 640 with text twice as large, with
  nothing cut off.
- `tools/capture_journey.dart` draws 28 pictures of the screens. They were
  compared by eye with the eight approved design screens.
- The speech model was run here, on Linux, through the app's own code (the same
  `sherpa_onnx` package, with its Linux library):
  - twelve recordings, three reciters (Alafasy, Al-Husary, Al-Minshawi) on ayahs
    9, 10, 19 and 109: every word was heard in all twelve;
  - copies of them made rougher (noise added, volume cut to 8%, cut down to a
    telephone's range, echo, 25% faster): every word heard in all twenty;
  - one word cut out of the sound, at the times the model itself gives for each
    word, 246 times: the missing word was marked 237 times, and 9 times nothing
    was marked. With two neighbouring words cut out, 234 times: both marked 219
    times, at least one 225 times. Some of those misses belong to the cutting,
    because the model's times say where it writes a word, not where its sound
    begins;
  - the recording of one ayah checked against the ayah before or after it: one
    or two of its 7 to 16 words marked heard, short words the two share;
  - a reciter who stops and repeats a phrase before going on (Alafasy, ayah 10)
    is heard as reciting the ayah once;
  - checking 85 seconds of sound (ayah 19, 38 words) took 1.1 seconds on this
    machine with two threads. A phone will be slower.
- The app's own code fetched the model from Hugging Face: both files arrived
  with the recorded sizes and checksums, and a second call fetched nothing.
- A release APK for 64-bit ARM was built here: 89,276,841 bytes, under the
  99,000,000 limit. It holds the speech runtime's three libraries, compressed,
  none for other processors, the game's content and fonts, and the microphone
  permission.
- **Not checked, with no phone or emulator here:** the microphone and its
  permission question on Android and on iPhone; a voice through a phone's
  microphone; an everyday reciter instead of a studio recording; loading the
  speech runtime on a real phone; and how long the check takes there. The
  recite screen is the one part of this build that has not run on the hardware
  it is for.

## 2.2.0-rc.14 / build 24, 25 November 2026: the iPhone alarm

- Local Flutter 3.50.0 and CI: all **243 unit/widget tests passed**; static
  analysis has no warnings or errors. In the tests a fake iPhone answers both
  channels (Apple's alarms and the notification plugin): an athan armed as an
  alarm is not notified a second time, what the iPhone refuses arrives as a
  notification, an iPhone before iOS 26 schedules as before, the alarm question
  is asked once, and the Settings rows follow what the phone reports.
- CI built the app and its `AthanAlarm` extension with Xcode 26.6 (iOS 26.5 SDK),
  for the simulator and as an unsigned release for a phone. The release is checked
  for the extension (the app's version, an identifier under the app's), the two
  usage texts, every excerpt at the top of the bundle and the two buttons'
  intents. The built app links AlarmKit, AppIntents and ActivityKit weakly, so it
  still opens on iOS 15 to 25.
- `tools/ios_alarm_check.sh`, run by CI on an iOS 26.5 simulator (iPhone Air)
  with nobody at the screen, over several runs:
  - the app asked for notifications, then "Allow Athan & Quran to schedule alarms
    and timers?", and both were allowed;
  - iOS accepted the next 24 athans as alarms, with no error;
  - a test alarm fired in the second it was set for, and the system's alert came
    down from the Dynamic Island with the app's name, the athan's title, Snooze
    and Stop;
  - iOS took the app's excerpt as the alarm's tone (`smooth_short.wav`, type
    alarm);
  - the Live Activity drawn by the extension showed the title, "Ringing", Snooze
    and Stop when the Dynamic Island was held;
  - Snooze there ran `AthanSnoozeIntent` in the app, the alarm service started
    counting down and the app saw one snoozed athan. The Live Activity changed
    to "Snoozed" with the time left (9:58 of the 10 minutes) and Stop alone, in
    the Dynamic Island and on the lock screen;
  - Stop on the lock screen ran `AthanStopIntent`, the service stopped the
    snoozed alarm and the app saw none. In an earlier run the same button
    stopped an athan that was still ringing;
  - a real prayer rang too: in one run "Time for Isha" for London fired as an
    alarm at 17:32:00, its exact time, beside the test alarm.
- What the simulator does that a phone should not: when an alarm's tone starts,
  the simulator's home screen (SpringBoard) restarts. Its tone player calls a
  method the simulator does not have (`TLAlertQueuePlayerController`, crash
  report kept with the run); Apple's forum has the same fault with no app
  involved. The alarm keeps ringing across the restart, but the system's first
  alert is gone after a moment. On a slow CI machine the process that draws Live
  Activities once needed more than the 30 seconds iOS allows it to start after
  such a restart, and that run showed no Live Activity.
- The second alarm of the check rings with the simulator locked and dark. It
  fired in its second, but the simulator presented nothing for it: no alert, and
  after the restart a Live Activity that opened empty. Apple's forum, thread
  806998, has alarm alerts no longer presenting on a locked simulator since
  iOS 26.1. That half of the check therefore only reports.
- Not shown by a simulator, so not checked: the sound, and the full-screen alarm
  of a locked phone. No real iPhone was available. They are on the hardware list
  below, with Silent mode, a Focus and installing with Sideloadly.
- Reports from other developers to keep in mind for that check (Apple Developer
  Forums): alarms that ring late on a locked iPhone (threads 825427 and 846063),
  and a second alarm silencing the first when two overlap (thread 845563), the
  case of an Iqama alarm arriving while the athan alarm was left unanswered.

## 2.1.0-rc.8 / build 10 — 19 November 2026

- Local Flutter 3.50.0 / Dart 3.14.0: all **83 unit/widget tests passed**.
- Static analysis passed with **57 informational findings, no warnings or errors**.
  These include the SDK's Material import deprecation; this update does not migrate
  the application's UI framework.
- Settings/sound-picker screenshots were rendered and inspected at phone size;
  large-text checks cover 2× text, narrow screens and landscape.
- A settings-to-planner test enables weekend/all-day beep, reloads saved settings,
  and verifies weekday Athan/Iqama sounds remain unchanged. Custom hour restoration,
  selection/cancellation, imports and preview lifecycle races are covered.
- Six additional recordings fully decode; all Android copies match their preview
  assets. iPhone excerpts are mono PCM16 WAVs lasting 28 seconds. Source and output
  checksums are in `tools/athan_audio_manifest.json` and
  `tools/athan_audio_verification.json`.
- Android signing/build and iPhone simulator results are recorded by the workflow
  for the published commit. These local results do not claim physical-phone audio,
  locked-screen delivery or battery testing of rc.8.

## Versioned checkpoints

Each checkpoint is pushed on `codex/athan-reliability` with a matching Git tag.

| Version | Completed review work |
| --- | --- |
| `v2.1.0-rc.1` / build 3 | Imports, iOS silent alerts, playback cleanup, Iqama cutoffs, city refresh |
| `v2.1.0-rc.2` / build 4 | Calendar snapshots and asynchronous city-change regressions |
| `v2.1.0-rc.3` / build 5 | Android plugin compatibility; both platform builds pass |
| `v2.1.0-rc.4` / build 6 | Automated iPhone startup check and Android dependency caching |
| `v2.1.0-rc.5` / build 7 | Actual-screen navigation contrast, simulator startup allowance, verification record |
| `v2.1.0-rc.6` / build 8 | Follow-up Android storage compatibility fix from real import/preview testing |
| `v2.1.0-rc.7` / build 9 | Stable private preview signing and certificate verification for future updates |

## Evidence and scope

- CI runs all 69 unit/widget tests, static analysis, an Android release APK build,
  and an unsigned iOS simulator build. The iPhone startup script installs/launches
  the built app, checks its process for 15 seconds, and saves a screenshot. A fresh
  simulator has up to ten minutes to boot and complete that check.
- The rc.5 iPhone startup check passed. Its captured screen was inspected and
  shows the working prayer timetable, permission setup and readable navigation.
- The Android release APK from rc.3 was checksum-verified, installed and launched
  on an Android 14 x64 emulator. It correctly displayed the offline-calculation
  fallback and reminder setup while notification/exact-alarm access was denied.
  No app crash was observed during launch. System UI/Google-service ANRs on this
  test emulator delayed further interaction; they are not counted as app failures
  or as passed delivery checks.
- Further Android release checks passed: real notification denial/allow recovery;
  299 queued reminders with one OS alarm; exact-alarm access changing the alarm
  from inexact to exact; no playback service while idle; full native playback and
  notification Stop releasing the service and audio focus.
- The persisted work-hours schedule replaces daytime prayer/Iqama sounds with
  beep while retaining Athan outside the window. Selecting five Iqama reminders
  produced five correctly spaced events. A scheduled Isha alert fired with the
  app backgrounded and the screen off. The emulator stayed INACTIVE rather than
  entering deep Doze because an alarm was imminent, so deep Doze is not claimed.
- The emulator is muted: playback state/resource cleanup was verified, not
  audible quality. Valid-file import and in-app preview checks exposed an Android
  storage dependency incompatibility, fixed in rc.6. The corrected release passed
  real-picker import, built-in/imported preview and persistence after deleting
  both the original and picker-cache copies and restarting. The private copy's
  SHA-256 matches the original; native alert playback reads that private file and
  notification Stop releases its service/audio focus.
- Live endpoint probes on 19 November 2026 returned HTTP 200: Aladhan supplied all
  30 November dates for London in `Europe/London`; the Quran service returned
  Surah 2 with all 286 verses in both requested editions.
- Narrow-screen/large-text widget checks and captured settings layouts pass.
  The navigation regression also passes after the contrast/label-size change.
- Final CI and emulator outcomes are recorded in
  [PR #1](https://github.com/wlaa41/flutterAthanApp/pull/1) and its linked checks.
  Trusted APK previews from rc.7 use a stable private debug key; they are not store
  releases. Earlier differently signed previews require a clean install. No
  physical-phone power measurement has been performed.

## Five review passes

1. **Existing behaviour audit:** traced fetch/cache paths, Android manifest,
   timezone interpretation, notification permissions, audio lifetime and UI.
2. **Feature implementation review:** implemented persisted preferences, pure
   alert planning, imported/bundled audio, Iqama, quiet schedules, and native queue.
3. **Automated regression checks:** unit/widget tests cover work-time boundaries,
   overnight shifts, total repeat counts, cancelled prayers, DST, invalid/partial
   API calendars, request coalescing, cache/method separation, next-day Fajr,
   Quran chapter validation, audio asset consistency, and large text layouts.
4. **Independent review:** fixed stale-alarm queue deletion, active-playback
   interruption on refresh, work-tone fallback, blocked playback channels,
   audio-focus cleanup, subscription leaks, and retriable initialization failures.
5. **Final validation:** final analysis, tests and platform builds are recorded in
   the pull request/CI results. Manual hardware checks below remain required.

## Hardware acceptance checks

These are a release acceptance matrix, not a claim that physical phones were tested.

| Scenario | Pixel/Android stock | Samsung | Xiaomi/Oppo | iPhone |
| --- | --- | --- | --- | --- |
| Fresh install, deny then grant notifications | Pending | Pending | Pending | Pending |
| Deny/grant/revoke precise-alarm access | Pending | Pending | Pending | N/A |
| Screen locked and Doze at prayer time | Pending | Pending | Pending | Pending |
| Stop a full recording from notification | Pending | Pending | Pending | Short alert only |
| Reboot/app update restores future reminders | Pending | Pending | Pending | OS managed |
| Work start/end, weekdays and overnight shifts | Pending | Pending | Pending | Pending |
| Iqama count, interval, mute individual prayer | Pending | Pending | Pending | Pending |
| Imported audio after original file deleted | Pending | Pending | Pending | Pending |
| Silent/DND/Focus, active call, muted channel | Pending | Pending | Pending | Pending |
| DST change and selected city different from device | Pending | Pending | Pending | Pending |
| Force stop, reopen; refill near scheduled-through date | Pending | Pending | Pending | Pending |
| TalkBack/VoiceOver, large fonts, landscape | Pending | Pending | Pending | Pending |
| Athan as an alarm (iOS 26 or later): locked, in use, Silent mode, a Focus, Snooze, Stop, on time overnight | N/A | N/A | N/A | Pending |
| Al-Kahf Journey, Recite: the microphone question, fetching the listener, reciting an ayah right, with a word left out, and offline | Pending | Pending | Pending | Pending |

Android setAlarmClock is used only for user-enabled prayer/Iqama alerts with
permission. It can show the system's upcoming-alarm indicator. Revoking exact
alarm permission can cause Android to remove alarms until the app is reopened.
No local app can guarantee alarms after Force stop or when the device is powered off.
Power measurements and manufacturer-specific behaviour require actual devices.

## Platform references

- [Android alarm scheduling](https://developer.android.com/develop/background-work/services/alarms)
- [Exact-alarm permission changes](https://developer.android.com/about/versions/14/changes/schedule-exact-alarms)
- [Apple notification sounds](https://developer.apple.com/documentation/usernotifications/unnotificationsound)
- [Flutter notification plugin and pending limit](https://pub.dev/packages/flutter_local_notifications/versions/17.2.4)
- [Aladhan API calculation methods](https://aladhan.com/prayer-times-api)

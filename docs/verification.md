# Verification

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

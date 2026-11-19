# Verification

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

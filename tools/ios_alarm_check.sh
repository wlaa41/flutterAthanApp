#!/usr/bin/env bash
# Rings two athan alarms on an iPhone simulator with nobody at the screen, one
# with the phone in use and one with it locked, and keeps what it looked like
# in build/review/alarm: a video, the pictures the UI test took at every step,
# the app's own log and the system's.
#
#   bash tools/ios_alarm_check.sh
#
# Needs macOS, Xcode 26 or later and the xcodeproj gem (CocoaPods brings it).
# It builds the app with ATHAN_ALARM_CHECK, so the app sets the test alarms
# the UI test asks for, and adds ios/AlarmCheck to the project as a UI test
# for this run only: the project file and the scheme are put back at the end.
# It takes about ten minutes once the app is built and the simulator is up.
#
# A simulator is not a phone. It shows that iOS accepts the alarms, that they
# ring, and what the Live Activity and its Stop and Snooze do. The sound and
# how long the full-screen alarm stays need a real iPhone. Some simulators
# restart SpringBoard when an alert tone starts, which takes the full-screen
# alarm away after a moment; the run says how many SpringBoard processes it
# saw and keeps crash reports, to tell that apart from a fault of the app.
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
  echo "The alarm check needs macOS and Xcode." >&2
  exit 1
fi

out=build/review/alarm
work=build/alarm_check
project=ios/Runner.xcodeproj/project.pbxproj
scheme=ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme
rm -rf "$out" "$work"
mkdir -p "$out" "$work"
touch "$work/started"

# Flutter brings the project up to date here (pods, packages, its own project
# changes), and writes the check into the build settings. No build yet.
flutter build ios --simulator --debug --no-codesign --config-only \
  --dart-define=ATHAN_ALARM_CHECK=true

cp "$project" "$work/project.pbxproj"
cp "$scheme" "$work/Runner.xcscheme"
ruby -e "require 'xcodeproj'" 2>/dev/null || gem install xcodeproj --no-document
ruby tools/ios_alarm_check.rb

# An available, stopped iPhone on the newest installed iOS, as in ios_smoke.sh.
udid="$(python3 - <<'PY'
import json
import re
import subprocess

devices = json.loads(subprocess.check_output(
    ["xcrun", "simctl", "list", "devices", "available", "--json"],
    text=True, timeout=30,
))["devices"]
candidates = []
for runtime, entries in devices.items():
    if not runtime.startswith("com.apple.CoreSimulator.SimRuntime.iOS-"):
        continue
    version = tuple(int(n) for n in re.findall(r"\d+", runtime))
    for device in entries:
        if (device.get("isAvailable") and device.get("state") == "Shutdown"
                and device.get("name", "").startswith("iPhone")):
            candidates.append((version, device["name"], device["udid"]))
if not candidates:
    raise SystemExit("No available, stopped iPhone simulator is installed.")
version, name, udid = max(candidates)
print(udid)
PY
)"
xcrun simctl list devices | grep "$udid" || true

recorders=()
cleanup() {
  for pid in "${recorders[@]:-}"; do
    [[ -n "$pid" ]] && kill -INT "$pid" >/dev/null 2>&1 || true
  done
  sleep 3
  rm -f "$out"/*.sb-* 2>/dev/null || true
  xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  cp "$work/project.pbxproj" "$project"
  cp "$work/Runner.xcscheme" "$scheme"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

destination="platform=iOS Simulator,id=$udid"
xcodebuild build-for-testing \
  -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination "$destination" -derivedDataPath "$work/derived" \
  -only-testing:AlarmCheck COMPILER_INDEX_STORE_ENABLE=NO \
  > "$out/build.log" 2>&1 || {
    grep -E "error:|\*\* " "$out/build.log" | head -60
    echo "The check could not be built. The whole log is in $out/build.log." >&2
    exit 1
  }

xcrun simctl bootstatus "$udid" -b
# Start from a phone that has never seen the app, so it asks both questions.
xcrun simctl uninstall "$udid" wlaa41.github.io.flutterPro >/dev/null 2>&1 || true

xcrun simctl spawn "$udid" log stream --style compact --level debug \
  --predicate 'process == "Runner" OR process == "AthanAlarm" OR subsystem CONTAINS[c] "alarmkit" OR eventMessage CONTAINS[c] "alarmkit"' \
  > "$out/simulator.log" 2>&1 &
recorders+=("$!")
# What the system itself complains about while the alarm rings.
xcrun simctl spawn "$udid" log stream --style compact \
  --predicate '(process IN {"SpringBoard", "backboardd", "ClockAngel", "mobiletimerd", "chronod", "liveactivitiesd"}) AND (messageType == error OR messageType == fault)' \
  > "$out/system-errors.log" 2>&1 &
recorders+=("$!")
xcrun simctl io "$udid" recordVideo --codec h264 --force "$out/alarm.mp4" >/dev/null 2>&1 &
recorders+=("$!")

set +e
xcodebuild test-without-building \
  -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination "$destination" -derivedDataPath "$work/derived" \
  -only-testing:AlarmCheck -resultBundlePath "$work/result.xcresult" \
  > "$out/test.log" 2>&1
result=$?
set -e

echo "What the UI test saw:"
grep -h "ALARM_CHECK_UI" "$out/test.log" | sed 's/^.*ALARM_CHECK_UI //' || true
echo "What the app logged, each change once:"
grep -h "ALARM_CHECK " "$out/simulator.log" | sed 's/^.*ALARM_CHECK //' | uniq | head -80 || true
echo "What the iPhone's alarm service logged, without the prayers it armed:"
grep -h "AlarmKitCore:alarmManager\]" "$out/simulator.log" \
  | grep -v -e "Next wake date" -e "Scheduling alarm" -e ": Scheduled alarm$" \
  | sed 's/^[0-9-]* \([0-9:]*\)[^ ]* .*alarmManager\] /\1 /' | head -80 || true
echo "Stop and Snooze presses that reached the app:"
grep -h "Invoking Athan" "$out/simulator.log" \
  | sed 's/^[0-9-]* \([0-9:]*\)[^ ]* .*Invoking /\1 /' | head -20 || true
echo "SpringBoard processes seen during the run (more than one means it restarted): $(
  grep -oh 'SpringBoard\[[0-9]*' "$out/system-errors.log" "$out/simulator.log" 2>/dev/null | sort -u | wc -l | tr -d ' ')"
grep -E "Test Case|error:|\*\* TEST" "$out/test.log" | head -20 || true
xcrun xcresulttool export attachments --path "$work/result.xcresult" \
  --output-path "$out/steps" >/dev/null 2>&1 || true
# Name the test's own pictures after their step and drop the rest.
python3 - "$out/steps" <<'PY' || true
import json
import os
import sys

steps = sys.argv[1]
wanted = {}
for test in json.load(open(os.path.join(steps, "manifest.json"))):
    for index, item in enumerate(sorted(test.get("attachments", []), key=lambda a: a.get("timestamp") or 0)):
        name, kind = os.path.splitext(item.get("suggestedHumanReadableName", ""))
        if kind.lower() in (".png", ".jpeg", ".jpg"):
            wanted[item["exportedFileName"]] = "%03d-%s%s" % (index, name.split("_0_")[0], kind.lower())
for name in os.listdir(steps):
    path = os.path.join(steps, name)
    if name in wanted:
        os.rename(path, os.path.join(steps, wanted[name]))
    else:
        os.remove(path)
PY
mkdir -p "$out/crashes"
find "$HOME/Library/Logs/DiagnosticReports" -type f -newer "$work/started" \
  \( -name '*.ips' -o -name '*.crash' \) -exec cp {} "$out/crashes/" \; 2>/dev/null || true
echo "Crash reports from the run: $(ls "$out/crashes" | tr '\n' ' ')"

if [[ "$result" -ne 0 ]]; then
  echo "The alarm check did not pass. See $out." >&2
  exit "$result"
fi
echo "The alarm check passed. See $out."

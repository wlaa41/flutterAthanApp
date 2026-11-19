#!/usr/bin/env bash
# Run on a Mac after: flutter build ios --simulator --debug --no-codesign
# CI should give this step a five-minute timeout. This checks startup only.
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
  echo "The iOS startup smoke check requires macOS and Xcode." >&2
  exit 1
fi

app="${1:-build/ios/iphonesimulator/Runner.app}"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")"
mkdir -p build/review

# Use an available, stopped iPhone on the newest installed iOS runtime.
# Never take over a simulator that is already running.
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
print(max(candidates)[2])
PY
)"

cleanup() {
  xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true
  xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

xcrun simctl bootstatus "$udid" -b
xcrun simctl install "$udid" "$app"
launch_output="$(xcrun simctl launch "$udid" "$bundle_id")"
printf '%s\n' "$launch_output"
pid="${launch_output##*: }"
if [[ ! "$pid" =~ ^[0-9]+$ ]]; then
  echo "Could not read the launched app process ID." >&2
  exit 1
fi

# Simulator apps run as host processes. Reject early exits and zombies.
for ((second = 0; second < 15; second++)); do
  sleep 1
  process_state="$(ps -p "$pid" -o stat=)" || {
    echo "The iOS app exited during the startup smoke check." >&2
    exit 1
  }
  if [[ "$process_state" == *Z* ]]; then
    echo "The iOS app crashed during the startup smoke check." >&2
    exit 1
  fi
done

xcrun simctl io "$udid" screenshot build/review/ios-launch.png
echo "iOS startup smoke passed: app stayed alive for 15 seconds."

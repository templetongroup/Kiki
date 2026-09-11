#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-/Applications/Kiki.app}"
TIMEOUT_SECONDS="${KIKI_UPDATE_CHECK_TIMEOUT_SECONDS:-20}"
PLIST="$APP_PATH/Contents/Info.plist"

if [[ ! -d "$APP_PATH" || ! -f "$PLIST" ]]; then
    echo "error: Kiki app bundle not found at $APP_PATH" >&2
    exit 2
fi

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")
EXECUTABLE_NAME=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST")
START_EPOCH=$(date +%s)

# Make the scheduled check unambiguously overdue and exercise the enabled
# automatic-check path.
defaults write "$BUNDLE_ID" SUEnableAutomaticChecks -bool true
defaults write "$BUNDLE_ID" SULastCheckTime -date '2001-01-01 00:00:00 +0000'

pkill -x "$EXECUTABLE_NAME" 2>/dev/null || true
open -n "$APP_PATH"

for _ in $(seq 1 "$TIMEOUT_SECONDS"); do
    sleep 1
    CHECK_VALUE=$(defaults read "$BUNDLE_ID" SULastCheckTime 2>/dev/null || true)
    CHECK_EPOCH=$(date -j -f '%Y-%m-%d %H:%M:%S %z' "$CHECK_VALUE" +%s 2>/dev/null || echo 0)
    if [[ "$CHECK_EPOCH" -ge "$START_EPOCH" ]]; then
        echo "PASS: launch performed automatic update check at $CHECK_VALUE"
        exit 0
    fi
done

echo "FAIL: launch did not perform automatic update check; SULastCheckTime=$(defaults read "$BUNDLE_ID" SULastCheckTime 2>/dev/null || echo missing)" >&2
exit 1

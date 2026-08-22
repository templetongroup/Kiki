#!/bin/bash
# Verifies the exact archive produced after signing, notarization, and stapling.
set -euo pipefail

cd "$(dirname "$0")/.."

ARCHIVE="${1:?usage: ./scripts/verify-release-artifact.sh ARCHIVE [VERSION] [BUILD]}"
EXPECTED_VERSION="${2:-}"
EXPECTED_BUILD="${3:-}"
VERIFY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kiki-release-verify.XXXXXX")"

cleanup() {
    rm -rf "$VERIFY_DIR"
}
trap cleanup EXIT

if [[ ! -f "$ARCHIVE" ]]; then
    echo "error: release archive not found: $ARCHIVE" >&2
    exit 1
fi

ditto -x -k "$ARCHIVE" "$VERIFY_DIR"
APP="$VERIFY_DIR/Kiki.app"
PLIST="$APP/Contents/Info.plist"
EXECUTABLE="$APP/Contents/MacOS/Kiki"

if [[ ! -d "$APP" || ! -x "$EXECUTABLE" || ! -f "$PLIST" ]]; then
    echo "error: archive does not contain a complete Kiki.app bundle" >&2
    exit 1
fi

plutil -lint "$PLIST" >/dev/null
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")"
FEED_URL="$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$PLIST")"
PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$PLIST")"

if [[ -n "$EXPECTED_VERSION" && "$VERSION" != "$EXPECTED_VERSION" ]]; then
    echo "error: archive version $VERSION does not match expected $EXPECTED_VERSION" >&2
    exit 1
fi
if [[ -n "$EXPECTED_BUILD" && "$BUILD" != "$EXPECTED_BUILD" ]]; then
    echo "error: archive build $BUILD does not match expected $EXPECTED_BUILD" >&2
    exit 1
fi
if [[ "$BUNDLE_ID" != "com.tonyricciardi.kiki" ]]; then
    echo "error: unexpected bundle identifier: $BUNDLE_ID" >&2
    exit 1
fi
if [[ "$FEED_URL" != "https://raw.githubusercontent.com/templetongroup/Kiki/main/appcast.xml" ]]; then
    echo "error: release points at an unexpected update feed: $FEED_URL" >&2
    exit 1
fi
if [[ -z "$PUBLIC_KEY" ]]; then
    echo "error: Sparkle public key is missing" >&2
    exit 1
fi
if [[ "$(lipo -archs "$EXECUTABLE")" != *"arm64"* ]]; then
    echo "error: release executable does not contain arm64" >&2
    exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=4 "$APP"
"$EXECUTABLE" --self-test-features
"$EXECUTABLE" --self-test-hud
"$EXECUTABLE" --benchmark-postprocessing

CHECKSUM="$(shasum -a 256 "$ARCHIVE" | awk '{ print $1 }')"
echo "Verified Kiki $VERSION (build $BUILD)"
echo "Archive SHA-256: $CHECKSUM"

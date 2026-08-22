#!/bin/bash
# Installs Sparkle's checksum-verified XCFramework locally when SwiftPM's
# binary-artifact downloader is unavailable or unreliable.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="2.9.5"
EXPECTED_SHA256="34b9b2071f3de0012eca3faa3a9290bb94e62131e9a74f6dc91514a000097a6c"
ARCHIVE="${TMPDIR:-/tmp}/Sparkle-for-Swift-Package-Manager-${VERSION}.zip"
DESTINATION="Vendor/Sparkle"
URL="https://github.com/sparkle-project/Sparkle/releases/download/${VERSION}/Sparkle-for-Swift-Package-Manager.zip"

curl -L --fail --retry 3 -o "$ARCHIVE" "$URL"
ACTUAL_SHA256="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
    echo "error: Sparkle archive checksum mismatch" >&2
    exit 1
fi

rm -rf "$DESTINATION"
mkdir -p "$DESTINATION"
ditto -x -k "$ARCHIVE" "$DESTINATION"

echo "Installed Sparkle ${VERSION} at ${DESTINATION}/Sparkle.xcframework"

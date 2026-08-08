#!/bin/bash
# Creates a Developer ID-signed, notarized, stapled release archive.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-${KIKI_VERSION:-0.1.0}}"
ARCHIVE="build/Kiki-${VERSION}-macOS.zip"
NOTARY_KEYCHAIN="${KIKI_NOTARY_KEYCHAIN:-}"
NOTARY_PROFILE="${KIKI_NOTARY_PROFILE:-kiki-notary}"
NOTARY_ARGUMENTS=(--keychain-profile "$NOTARY_PROFILE")

if [[ -n "$NOTARY_KEYCHAIN" && ! -f "$NOTARY_KEYCHAIN" ]]; then
    echo "error: notarization keychain not found: $NOTARY_KEYCHAIN" >&2
    exit 1
fi
if [[ -n "$NOTARY_KEYCHAIN" ]]; then
    NOTARY_ARGUMENTS+=(--keychain "$NOTARY_KEYCHAIN")
fi
echo "Checking saved Apple notarization credentials..."
if ! xcrun notarytool history "${NOTARY_ARGUMENTS[@]}" >/dev/null; then
    echo "error: notarization profile '$NOTARY_PROFILE' is unavailable" >&2
    echo "Save it to iCloud Keychain once with:" >&2
    echo "  xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --sync" >&2
    exit 1
fi

KIKI_RELEASE=1 KIKI_VERSION="$VERSION" ./scripts/make-app.sh

rm -f "$ARCHIVE"
ditto -c -k --sequesterRsrc --keepParent build/Kiki.app "$ARCHIVE"

echo
echo "Submitting $ARCHIVE to Apple's notary service..."
xcrun notarytool submit "$ARCHIVE" "${NOTARY_ARGUMENTS[@]}" --wait

xcrun stapler staple build/Kiki.app
xcrun stapler validate build/Kiki.app
spctl --assess --type execute --verbose=4 build/Kiki.app

# Recreate the archive so it includes the stapled notarization ticket.
rm -f "$ARCHIVE"
ditto -c -k --sequesterRsrc --keepParent build/Kiki.app "$ARCHIVE"

echo
echo "Release archive: $ARCHIVE"

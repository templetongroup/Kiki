#!/bin/bash
# Creates a Developer ID-signed release archive and optionally notarizes it.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-${KIKI_VERSION:-0.1.0}}"
ARCHIVE="build/Kiki-${VERSION}-macOS.zip"

KIKI_RELEASE=1 KIKI_VERSION="$VERSION" ./scripts/make-app.sh

rm -f "$ARCHIVE"
ditto -c -k --sequesterRsrc --keepParent build/Kiki.app "$ARCHIVE"

if [[ -n "${KIKI_NOTARY_PROFILE:-}" ]]; then
    echo
    echo "Submitting $ARCHIVE to Apple's notary service..."
    xcrun notarytool submit "$ARCHIVE" \
        --keychain-profile "$KIKI_NOTARY_PROFILE" \
        --wait

    xcrun stapler staple build/Kiki.app
    xcrun stapler validate build/Kiki.app
    spctl --assess --type execute --verbose=4 build/Kiki.app

    # Recreate the archive so it includes the stapled notarization ticket.
    rm -f "$ARCHIVE"
    ditto -c -k --sequesterRsrc --keepParent build/Kiki.app "$ARCHIVE"
else
    echo
    echo "Developer ID signing complete, but notarization was skipped."
    echo "Set KIKI_NOTARY_PROFILE to a notarytool keychain profile for a public release."
fi

echo
echo "Release archive: $ARCHIVE"

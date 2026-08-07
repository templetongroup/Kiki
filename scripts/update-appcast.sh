#!/bin/bash
# Signs a notarized release archive with Kiki's Sparkle key and updates appcast.xml.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: ./scripts/update-appcast.sh VERSION ARCHIVE [RELEASE_NOTES]}"
ARCHIVE="${2:?usage: ./scripts/update-appcast.sh VERSION ARCHIVE [RELEASE_NOTES]}"
RELEASE_NOTES="${3:-}"
GENERATOR="Vendor/Sparkle/bin/generate_appcast"
WORK_DIR="build/sparkle-updates"

if [[ ! -x "$GENERATOR" ]]; then
    echo "error: Sparkle tools not installed; run ./scripts/setup-sparkle.sh" >&2
    exit 1
fi
if [[ ! -f "$ARCHIVE" ]]; then
    echo "error: release archive not found: $ARCHIVE" >&2
    exit 1
fi

mkdir -p "$WORK_DIR"
cp "$ARCHIVE" "$WORK_DIR/"
cp appcast.xml "$WORK_DIR/appcast.xml"
if [[ -n "$RELEASE_NOTES" && -f "$RELEASE_NOTES" ]]; then
    cp "$RELEASE_NOTES" "$WORK_DIR/$(basename "${ARCHIVE%.*}").md"
fi

"$GENERATOR" \
    --download-url-prefix "https://github.com/templetongroup/Kiki/releases/download/v${VERSION}/" \
    --link "https://github.com/templetongroup/Kiki/releases/tag/v${VERSION}" \
    --embed-release-notes \
    --maximum-versions 5 \
    "$WORK_DIR"

# generate_appcast applies the newest download prefix to every retained archive.
# Restore each full archive's own release tag so older fallback downloads stay valid.
perl -0pi -e '
    s{releases/download/v[^/]+/Kiki-([0-9]+\.[0-9]+\.[0-9]+)-macOS\.zip}
     {releases/download/v$1/Kiki-$1-macOS.zip}gx
' "$WORK_DIR/appcast.xml"

cp "$WORK_DIR/appcast.xml" appcast.xml
echo "Updated appcast.xml for Kiki ${VERSION}"

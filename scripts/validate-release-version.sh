#!/bin/bash
# Rejects a public release that Sparkle would not offer to current users.
set -euo pipefail

VERSION="${1:?usage: ./scripts/validate-release-version.sh VERSION BUILD [APPCAST]}"
BUILD="${2:?usage: ./scripts/validate-release-version.sh VERSION BUILD [APPCAST]}"
APPCAST="${3:-appcast.xml}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: release version must use MAJOR.MINOR.PATCH, received: $VERSION" >&2
    exit 1
fi
if [[ ! "$BUILD" =~ ^[1-9][0-9]*$ ]]; then
    echo "error: KIKI_BUILD_NUMBER must be an explicit positive integer, received: $BUILD" >&2
    exit 1
fi
if [[ ! -f "$APPCAST" ]]; then
    echo "error: intended public appcast not found: $APPCAST" >&2
    exit 1
fi

CURRENT_BUILD="$({
    sed -n 's|.*<sparkle:version>\([0-9][0-9]*\)</sparkle:version>.*|\1|p' "$APPCAST"
} | sort -nr | head -1)"

if [[ -z "$CURRENT_BUILD" ]]; then
    echo "error: no Sparkle build numbers were found in $APPCAST" >&2
    exit 1
fi
if (( BUILD <= CURRENT_BUILD )); then
    echo "error: build $BUILD must be greater than public Sparkle build $CURRENT_BUILD" >&2
    exit 1
fi

echo "Release preflight passed: Kiki $VERSION build $BUILD > public build $CURRENT_BUILD"

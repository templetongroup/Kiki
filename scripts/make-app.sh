#!/bin/bash
# Builds Kiki.app (release) into build/.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_ID="${KIKI_BUNDLE_ID:-com.tonyricciardi.kiki}"
APP_VERSION="${KIKI_VERSION:-0.1.0}"
BUILD_NUMBER="${KIKI_BUILD_NUMBER:-1}"
LOCAL_SIGNING_IDENTITY="${KIKI_LOCAL_SIGNING_IDENTITY:-Kiki Local Code Signing}"
SIGNING_IDENTITY="${KIKI_SIGNING_IDENTITY:-}"
RELEASE_BUILD="${KIKI_RELEASE:-0}"
ENTITLEMENTS="${KIKI_ENTITLEMENTS:-Resources/Kiki.entitlements}"
SPARKLE_PUBLIC_KEY="${KIKI_SPARKLE_PUBLIC_KEY:-xp9FZx3OYN5NpmFPmxw3AN7HfLPVcXe5+s+xB27QKwM=}"
SPARKLE_FEED_URL="${KIKI_SPARKLE_FEED_URL:-https://raw.githubusercontent.com/templetongroup/Kiki/main/appcast.xml}"

if [[ ! -f "$ENTITLEMENTS" ]]; then
    echo "error: entitlements file not found: $ENTITLEMENTS" >&2
    exit 1
fi

swift build -c release
./scripts/fetch-mlx-metallib.sh

APP="build/Kiki.app"
BIN=".build/release/Kiki"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN" "$APP/Contents/MacOS/Kiki"
cp build/MLX/mlx.metallib "$APP/Contents/MacOS/mlx.metallib"

if [[ -d ".build/release/Sparkle.framework" ]]; then
    ditto ".build/release/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
    install_name_tool -add_rpath "@loader_path/../Frameworks" "$APP/Contents/MacOS/Kiki"
else
    echo "error: Sparkle.framework was not produced by the release build" >&2
    exit 1
fi

# App icon.
cp Resources/Kiki.icns "$APP/Contents/Resources/Kiki.icns"
cp Resources/MenuBarIcon.png "$APP/Contents/Resources/MenuBarIcon.png"
cp Assets/kiki-portrait.png "$APP/Contents/Resources/SplashArtwork.png"
cp Assets/kiki-studio-hero.png "$APP/Contents/Resources/VoiceStudioHero.png"
cp THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/THIRD_PARTY_NOTICES.md"

# Metal shader source: ggml compiles this at runtime for GPU acceleration.
cp Vendor/whisper.cpp/ggml/src/ggml-metal.metal "$APP/Contents/Resources/"

# SwiftPM resource bundles, if any were produced.
for bundle in .build/release/*.bundle; do
    [ -d "$bundle" ] && cp -R "$bundle" "$APP/Contents/Resources/" || true
done

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$APP_ID</string>
    <key>CFBundleName</key>
    <string>Kiki</string>
    <key>CFBundleDisplayName</key>
    <string>Kiki</string>
    <key>CFBundleExecutable</key>
    <string>Kiki</string>
    <key>CFBundleIconFile</key>
    <string>Kiki</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Kiki records your voice while dictating so it can transcribe it locally.</string>
    <key>NSContactsUsageDescription</key>
    <string>Kiki can import contact names into an optional local vocabulary so names are spelled correctly.</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>Kiki can import upcoming meeting titles and attendee names into an optional local vocabulary.</string>
    <key>NSScreenCaptureUsageDescription</key>
    <string>Kiki Meeting Mode can capture Mac system audio for a fully local, source-labelled transcript.</string>
    <key>SUFeedURL</key>
    <string>$SPARKLE_FEED_URL</string>
    <key>SUPublicEDKey</key>
    <string>$SPARKLE_PUBLIC_KEY</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUAutomaticallyUpdate</key>
    <true/>
</dict>
</plist>
PLIST

identity_line_for_label() {
    security find-identity -v -p codesigning \
        | awk -v label="\"$1\"" 'index($0, label) { print; exit }'
}

identity_line_for_hash() {
    security find-identity -v -p codesigning \
        | awk -v hash="$1" '$2 == hash { print; exit }'
}

SIGNING_LINE=""
SIGNING_LABEL=""

if [[ -n "$SIGNING_IDENTITY" && "$SIGNING_IDENTITY" != "-" ]]; then
    if [[ "$SIGNING_IDENTITY" =~ ^[[:xdigit:]]{40}$ ]]; then
        SIGNING_LINE="$(identity_line_for_hash "$SIGNING_IDENTITY")"
    else
        SIGNING_LINE="$(identity_line_for_label "$SIGNING_IDENTITY")"
    fi

    if [[ -z "$SIGNING_LINE" ]]; then
        echo "error: code-signing identity not found: $SIGNING_IDENTITY" >&2
        exit 1
    fi
elif [[ -z "$SIGNING_IDENTITY" ]]; then
    if [[ "$RELEASE_BUILD" == "1" ]]; then
        SIGNING_LINE="$(
            security find-identity -v -p codesigning \
                | awk 'index($0, "\"Developer ID Application:") { print; exit }'
        )"
    else
        SIGNING_LINE="$(identity_line_for_label "$LOCAL_SIGNING_IDENTITY")"
    fi
fi

if [[ -n "$SIGNING_LINE" ]]; then
    # Sign by certificate hash. This remains unambiguous when Keychain contains
    # renewed certificates with the same display name.
    SIGNING_IDENTITY="$(printf '%s\n' "$SIGNING_LINE" | awk '{ print $2 }')"
    SIGNING_LABEL="$(printf '%s\n' "$SIGNING_LINE" | sed -E 's/^.*"([^"]+)".*$/\1/')"
else
    SIGNING_IDENTITY="-"
    SIGNING_LABEL="ad-hoc"
fi

if [[ "$RELEASE_BUILD" == "1" ]]; then
    if [[ "$SIGNING_LABEL" != "Developer ID Application:"* ]]; then
        echo "error: public releases require an Apple-issued Developer ID Application certificate" >&2
        echo "Set KIKI_SIGNING_IDENTITY after installing the certificate, for example:" >&2
        echo '  KIKI_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/release.sh' >&2
        exit 1
    fi

    # Secure timestamping rejects a generic file when its copied mtime is stale.
    # Refresh the packaged metallib immediately before applying its signature.
    touch "$APP/Contents/MacOS/mlx.metallib"

    codesign \
        --force \
        --sign "$SIGNING_IDENTITY" \
        --options runtime \
        --timestamp \
        "$APP/Contents/MacOS/mlx.metallib"

    codesign \
        --force \
        --deep \
        --sign "$SIGNING_IDENTITY" \
        --options runtime \
        --timestamp \
        "$APP/Contents/Frameworks/Sparkle.framework"

    codesign \
        --force \
        --sign "$SIGNING_IDENTITY" \
        --identifier "$APP_ID" \
        --entitlements "$ENTITLEMENTS" \
        --options runtime \
        --timestamp \
        "$APP"
else
    if [[ "$SIGNING_IDENTITY" == "-" ]]; then
        echo "warning: no local signing identity found; using an ad-hoc signature" >&2
        echo "Run ./scripts/setup-local-signing.sh once for stable permission grants." >&2
    fi

    codesign \
        --force \
        --sign "$SIGNING_IDENTITY" \
        --timestamp=none \
        "$APP/Contents/MacOS/mlx.metallib"

    codesign \
        --force \
        --deep \
        --sign "$SIGNING_IDENTITY" \
        --timestamp=none \
        "$APP/Contents/Frameworks/Sparkle.framework"

    codesign \
        --force \
        --sign "$SIGNING_IDENTITY" \
        --identifier "$APP_ID" \
        --entitlements "$ENTITLEMENTS" \
        --timestamp=none \
        "$APP"
fi

codesign --verify --deep --strict --verbose=2 "$APP"

echo
echo "Built $APP"
echo "Signed with: $SIGNING_LABEL"
echo "Install: cp -R $APP /Applications/   (or open it in place)"

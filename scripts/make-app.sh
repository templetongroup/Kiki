#!/bin/bash
# Builds Kiki.app (release) into build/.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="build/Kiki.app"
BIN=".build/release/Kiki"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Kiki"

# App icon.
cp Resources/Kiki.icns "$APP/Contents/Resources/Kiki.icns"

# Metal shader source: ggml compiles this at runtime for GPU acceleration.
cp Vendor/whisper.cpp/ggml/src/ggml-metal.metal "$APP/Contents/Resources/"

# SwiftPM resource bundles, if any were produced.
for bundle in .build/release/*.bundle; do
    [ -d "$bundle" ] && cp -R "$bundle" "$APP/Contents/Resources/" || true
done

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.tonyricciardi.kiki</string>
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
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Kiki records your voice while dictating so it can transcribe it locally.</string>
</dict>
</plist>
PLIST

# Ad-hoc sign with a stable identifier so permission grants survive rebuilds
# as reliably as possible.
codesign --force --sign - --identifier com.tonyricciardi.kiki "$APP"

echo
echo "Built $APP"
echo "Install: cp -R $APP /Applications/   (or open it in place)"

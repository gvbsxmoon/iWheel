#!/bin/bash
# Builds the distributable iWheel.app and a zip ready for a GitHub release.
# Usage: scripts/release.sh [version]   (default 1.0.0)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-1.0.0}"
APP="build/iWheel.app"

swift build -c release --disable-sandbox 2>/dev/null || swift build -c release

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/iWheel "$APP/Contents/MacOS/iWheel"

# App icon: PNG -> iconset -> icns
ICONSET="build/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z $size $size assets/icon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size*2)) $((size*2)) assets/icon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>iWheel</string>
    <key>CFBundleIdentifier</key><string>dev.lucanatale.iWheel</string>
    <key>CFBundleName</key><string>iWheel</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>MIT License - Luca Natale</string>
</dict>
</plist>
PLIST

# Prefer the stable local identity (scripts/make-signing-cert.sh): TCC
# permissions are tied to the signature, so a stable identity keeps them
# across rebuilds. Ad-hoc fallback resets permissions on every build.
if security find-identity -p codesigning -v 2>/dev/null | grep -q "iWheel Local Dev"; then
    codesign --force --deep -s "iWheel Local Dev" "$APP"
    echo "Signed with 'iWheel Local Dev' (permissions persist across builds)"
else
    codesign --force --deep -s - "$APP"
    echo "WARNING: ad-hoc signature - permissions reset on every rebuild."
    echo "Run scripts/make-signing-cert.sh once to fix this."
fi
touch "$APP"   # nudge Finder's icon cache

ditto -c -k --keepParent "$APP" "build/iWheel-${VERSION}.zip"
# Stable-named copy: attach BOTH to the GitHub release, so
# releases/latest/download/iWheel.zip always works (website button).
cp "build/iWheel-${VERSION}.zip" "build/iWheel.zip"
echo "Built $APP"
echo "Release archive: build/iWheel-${VERSION}.zip (+ stable-named build/iWheel.zip)"

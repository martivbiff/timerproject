#!/bin/bash
# Builds Flow Timer.app from source. No Xcode project, no dependencies —
# just the Swift compiler that ships with the Command Line Tools.
set -euo pipefail

cd "$(dirname "$0")"
APP_NAME="Flow Timer"
BUNDLE_ID="earth.flowtimer.app"
BUILD="build"
APP="$BUILD/$APP_NAME.app"

rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "→ compiling"
swiftc \
  -O \
  -parse-as-library \
  -target arm64-apple-macos13.0 \
  -framework SwiftUI -framework AppKit -framework AVFoundation \
  -o "$APP/Contents/MacOS/FlowTimer" \
  Sources/*.swift

echo "→ icon"
ICONSET="$BUILD/FlowTimer.iconset"
swiftc -O -o "$BUILD/make-icon" make-icon.swift
"$BUILD/make-icon" "$ICONSET" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET" "$BUILD/make-icon"

echo "→ bundle"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleExecutable</key><string>FlowTimer</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSSupportsAutomaticTermination</key><false/>
</dict>
</plist>
PLIST
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "→ signing (ad-hoc)"
codesign --force --sign - --timestamp=none "$APP" >/dev/null 2>&1 || \
  echo "  (ad-hoc signing skipped)"

echo "✓ built $APP"

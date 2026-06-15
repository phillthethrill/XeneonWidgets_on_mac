#!/bin/bash
set -e

APP="XeneonWidgets.app"
BINARY_NAME="XeneonWidgets"
ICON="XeneonWidgets.icns"
BUILD_DIR="$(pwd)"

if [[ ! -f "$ICON" ]]; then
    echo "error: missing app icon at $BUILD_DIR/$ICON" >&2
    exit 1
fi

if [[ ! -f "Resources/Info.plist" ]]; then
    echo "error: missing Resources/Info.plist" >&2
    exit 1
fi

echo "==> Building..."
swift build -c release 2>&1 | tee /tmp/xeneon-build.log

echo "==> Assembling .app bundle..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp ".build/release/$BINARY_NAME" "$APP/Contents/MacOS/"
cp "Resources/Info.plist" "$APP/Contents/"
cp "$ICON" "$APP/Contents/Resources/"

echo "==> Signing (ad-hoc)..."
codesign --sign - --force --deep "$APP"

echo "==> Clearing Gatekeeper quarantine..."
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

echo ""
echo "Done: $BUILD_DIR/$APP"
echo "Run with: open $APP"
#!/bin/bash
set -e

APP_NAME="ClipboardManager"
resolve_dir() {
    local target="$1"
    cd "$(dirname "$target")" && pwd
}
SCRIPT_DIR="$(resolve_dir "$0")"
PROJECT_DIR="$SCRIPT_DIR"
BUILD_DIR="$PROJECT_DIR/.build"
SOURCES="$PROJECT_DIR/Sources"
RESOURCES="$PROJECT_DIR/Resources"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
ICON_PATH="$BUILD_DIR/AppIcon.icns"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
TMP_DMG="$BUILD_DIR/tmp.dmg"
VERSION="1.0"

echo "======================================"
echo "  ClipboardManager v$VERSION - Package"
echo "======================================"
echo ""

# Step 1: Build
echo "[1/3] Building app..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

swiftc \
    -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
    -framework AppKit \
    -framework SwiftUI \
    -framework Carbon \
    "$SOURCES"/*.swift

cp "$RESOURCES/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
echo "  Build complete."

# Step 2: Generate icon
echo "[2/3] Generating app icon..."
swift "$SCRIPT_DIR/Scripts/generate_icon.swift" "$ICON_PATH"
cp "$ICON_PATH" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo "  Icon generated."

# Step 3: Create DMG
echo "[3/3] Creating DMG..."

rm -f "$DMG_PATH"
rm -f "$TMP_DMG"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$APP_BUNDLE" \
    -ov \
    -format UDRW \
    "$TMP_DMG" > /dev/null

MOUNT_POINT=$(hdiutil attach "$TMP_DMG" -readwrite -noverify -noautoopen | grep /Volumes/ | awk '{print $NF}')

ln -s /Applications "$MOUNT_POINT/Applications"

hdiutil detach "$MOUNT_POINT" -quiet

hdiutil convert "$TMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH" > /dev/null

rm -f "$TMP_DMG"

echo ""
echo "======================================"
echo "  Package complete!"
echo "  DMG: $DMG_PATH"
echo "  App: $APP_BUNDLE"
echo "======================================"
echo ""
echo "To install:"
echo "  open $(dirname "$DMG_PATH")"
echo "  Drag $APP_NAME.app to Applications"
echo ""
echo "First launch: grant Accessibility permission"
echo "  System Preferences → Privacy & Security → Accessibility"

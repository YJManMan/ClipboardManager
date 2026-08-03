#!/bin/bash
set -e

APP_NAME="ClipboardManager"
BUILD_DIR="$(dirname "$0")/.build"
SOURCES="$(dirname "$0")/Sources"
RESOURCES="$(dirname "$0")/Resources"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "🔨 Building $APP_NAME..."

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

swiftc \
    -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
    -framework AppKit \
    -framework SwiftUI \
    -framework Carbon \
    "$SOURCES"/*.swift

cp "$RESOURCES/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "✅ Build complete: $APP_BUNDLE"
echo ""
echo "To run:"
echo "  open $APP_BUNDLE"
echo ""
echo "First launch: grant Accessibility permission in System Preferences"
echo "  System Preferences → Privacy & Security → Accessibility → add $APP_NAME"

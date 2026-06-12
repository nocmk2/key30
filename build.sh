#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔨 Building Key30..."

BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="Key30"
APP_BUNDLE="${APP_NAME}.app"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "📦 Compiling Swift sources..."

swiftc \
    -O -wmo \
    -o "$BUILD_DIR/$APP_NAME" \
    -framework AppKit \
    -framework SwiftUI \
    -framework Combine \
    AppSettings.swift \
    KeyNames.swift \
    KeyMonitor.swift \
    FloatingCapsule.swift \
    KeyEventDebugger.swift \
    DebugView.swift \
    SettingsView.swift \
    DashboardView.swift \
    MenuBarApp.swift

echo "📱 Creating app bundle..."

mkdir -p "$BUILD_DIR/$APP_BUNDLE/Contents/MacOS"
mkdir -p "$BUILD_DIR/$APP_BUNDLE/Contents/Resources"

mv "$BUILD_DIR/$APP_NAME" "$BUILD_DIR/$APP_BUNDLE/Contents/MacOS/"
cp "$SCRIPT_DIR/Info-MenuBar.plist" "$BUILD_DIR/$APP_BUNDLE/Contents/Info.plist"
chmod +x "$BUILD_DIR/$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "✅ Build complete: $BUILD_DIR/$APP_BUNDLE"
echo "🚀 Run: open \"$BUILD_DIR/$APP_BUNDLE\""
echo "⚠️  First launch requires Accessibility permission: System Settings → Privacy & Security → Accessibility"

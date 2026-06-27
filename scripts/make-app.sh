#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$REPO_ROOT/build"
APP_DIR="$BUILD_DIR/Remora.app"

echo "Building Remora (release)..."
cd "$REPO_ROOT"
swift build -c release

echo "Assembling Remora.app..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$REPO_ROOT/.build/release/Remora" "$APP_DIR/Contents/MacOS/Remora"
cp "$REPO_ROOT/Resources/Info.plist" "$APP_DIR/Contents/"

if [ -f "$REPO_ROOT/Resources/AppIcon.icns" ]; then
    cp "$REPO_ROOT/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/"
fi

chmod +x "$APP_DIR/Contents/MacOS/Remora"

echo "Build complete: $APP_DIR"

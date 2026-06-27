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

for img in MenuBarIcon.png MenuBarIcon@2x.png; do
    if [ -f "$REPO_ROOT/Resources/$img" ]; then
        cp "$REPO_ROOT/Resources/$img" "$APP_DIR/Contents/Resources/"
    fi
done

chmod +x "$APP_DIR/Contents/MacOS/Remora"

# Ad-hoc sign so macOS Gatekeeper does not flag the bundle as
# "damaged" after the ZIP is downloaded with a quarantine attribute.
# This is not a Developer ID signature (no Apple developer account
# required), but it gives the bundle a stable code identity that the
# notarization-aware Gatekeeper checks accept far more reliably than
# an entirely unsigned binary. Strip any old signature first to avoid
# resource-fork residue from previous builds confusing codesign.
xattr -cr "$APP_DIR" || true
codesign --remove-signature "$APP_DIR" 2>/dev/null || true
codesign --force --deep --sign - --timestamp=none "$APP_DIR"
codesign --verify --verbose=2 "$APP_DIR"

echo "Build complete: $APP_DIR"

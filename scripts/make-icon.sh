#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET_DIR="$REPO_ROOT/build/AppIcon.iconset"
ICNS_OUT="$REPO_ROOT/Resources/AppIcon.icns"

echo "Drawing icon..."
swift "$REPO_ROOT/scripts/make-icon.swift" "$ICONSET_DIR"

echo "Building .icns..."
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_OUT"

echo "Done: $ICNS_OUT"

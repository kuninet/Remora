#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_SRC="$REPO_ROOT/build/Remora.app"
APP_DST="/Applications/Remora.app"

if [ ! -d "$APP_SRC" ]; then
    echo "Error: $APP_SRC not found. Run scripts/make-app.sh first."
    exit 1
fi

# Remora が起動中の場合は事前に終了させてください (killall Remora)
echo "Installing Remora.app to /Applications..."
cp -r "$APP_SRC" "$APP_DST"
echo "Installed: $APP_DST"

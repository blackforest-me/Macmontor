#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/Macmontor.app"
EXECUTABLE="$ROOT_DIR/.build/release/Macmontor"

if [[ ! -x "$EXECUTABLE" ]]; then
  echo "Missing release executable. Run: swift build -c release" >&2
  exit 1
fi

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/Macmontor"
cp "$ROOT_DIR/Resources/Macmontor.icns" "$APP_DIR/Contents/Resources/Macmontor.icns"
chmod +x "$APP_DIR/Contents/MacOS/Macmontor"

echo "$APP_DIR"

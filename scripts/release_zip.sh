#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$ROOT_DIR/Resources/Info.plist")"
APP_DIR="$ROOT_DIR/dist/Macmontor.app"
ZIP_PATH="$ROOT_DIR/dist/Macmontor-v$VERSION.zip"

cd "$ROOT_DIR"

swift build -c release
scripts/package_app.sh >/dev/null

rm -f "$ZIP_PATH"
ditto -c -k --norsrc --keepParent "$APP_DIR" "$ZIP_PATH"

echo "$ZIP_PATH"

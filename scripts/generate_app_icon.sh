#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET_DIR="$ROOT_DIR/Resources/Macmontor.iconset"
SOURCE_PNG="$ROOT_DIR/Assets/macmontor-app-icon.png"

cd "$ROOT_DIR"

swift scripts/generate_icon.swift
mkdir -p "$ICONSET_DIR"

sips -z 16 16 "$SOURCE_PNG" --out "$ICONSET_DIR/icon_16x16.png"
sips -z 32 32 "$SOURCE_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png"
sips -z 32 32 "$SOURCE_PNG" --out "$ICONSET_DIR/icon_32x32.png"
sips -z 64 64 "$SOURCE_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png"
sips -z 128 128 "$SOURCE_PNG" --out "$ICONSET_DIR/icon_128x128.png"
sips -z 256 256 "$SOURCE_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png"
sips -z 256 256 "$SOURCE_PNG" --out "$ICONSET_DIR/icon_256x256.png"
sips -z 512 512 "$SOURCE_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png"
sips -z 512 512 "$SOURCE_PNG" --out "$ICONSET_DIR/icon_512x512.png"
sips -z 1024 1024 "$SOURCE_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png"

iconutil -c icns "$ICONSET_DIR" -o "$ROOT_DIR/Resources/Macmontor.icns"

#!/usr/bin/env bash
# 从项目根目录 icon.png 生成 macOS AppIcon.icns
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/icon.png"
ICONSET="$ROOT/Resources/AppIcon.iconset"
ICNS="$ROOT/Resources/AppIcon.icns"

if [[ ! -f "$SRC" ]]; then
  echo "Icon source not found: $SRC" >&2
  exit 1
fi

mkdir -p "$ROOT/Resources"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

add_icon() {
  sips -z "$2" "$2" "$SRC" --out "$ICONSET/$1" >/dev/null
}

add_icon icon_16x16.png 16
add_icon icon_16x16@2x.png 32
add_icon icon_32x32.png 32
add_icon icon_32x32@2x.png 64
add_icon icon_128x128.png 128
add_icon icon_128x128@2x.png 256
add_icon icon_256x256.png 256
add_icon icon_256x256@2x.png 512
add_icon icon_512x512.png 512
add_icon icon_512x512@2x.png 1024

rm -f "$ICNS"
iconutil -c icns "$ICONSET" -o "$ICNS"
rm -rf "$ICONSET"

echo "Generated $ICNS"

#!/usr/bin/env bash
# 将 Swift Package 可执行文件打包为 .app 并输出 zip（ad-hoc 签名，无需开发者账号）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Origami"
BUNDLE_ID="com.xiaoxianthis.origami"
VERSION="${1:-0.0.0-dev}"
DIST_DIR="$ROOT/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
ARCH_MODE="${ARCH_MODE:-universal}"

cd "$ROOT"

echo "==> Building Origami ${VERSION} (${ARCH_MODE})"

case "$ARCH_MODE" in
  universal)
    swift build -c release --arch arm64 --arch x86_64
    BINARY="$ROOT/.build/apple/Products/Release/Origami"
    ;;
  arm64)
    swift build -c release
    BINARY="$ROOT/.build/release/Origami"
    ;;
  x86_64)
    swift build -c release --triple x86_64-apple-macosx13
    BINARY="$ROOT/.build/x86_64-apple-macosx13/release/Origami"
    ;;
  *)
    echo "Unknown ARCH_MODE: $ARCH_MODE (use universal, arm64, or x86_64)" >&2
    exit 1
    ;;
esac

if [[ ! -f "$BINARY" ]]; then
  echo "Binary not found: $BINARY" >&2
  exit 1
fi

echo "==> Creating app bundle"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

sed "s/VERSION_PLACEHOLDER/${VERSION}/g" "$ROOT/Resources/Info.plist" > "$APP_DIR/Contents/Info.plist"
cp "$BINARY" "$APP_DIR/Contents/MacOS/Origami"
chmod +x "$APP_DIR/Contents/MacOS/Origami"

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$APP_DIR"

ZIP_NAME="${APP_NAME}-v${VERSION}-macos-${ARCH_MODE}.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

echo "==> Creating $ZIP_NAME"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

echo "==> Done"
echo "App:  $APP_DIR"
echo "Zip:  $ZIP_PATH"
file "$APP_DIR/Contents/MacOS/Origami"

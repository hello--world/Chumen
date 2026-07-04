#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/Chumen.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
swift build -c release --product Chumen
swift build -c release --product ChumenHelper

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/.build/release/Chumen" "$MACOS_DIR/Chumen"
cp "$ROOT_DIR/.build/release/ChumenHelper" "$RESOURCES_DIR/ChumenHelper"
cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Packaging/Assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$ROOT_DIR/Packaging/Assets/StatusBarDoorClosed.png" "$RESOURCES_DIR/StatusBarDoorClosed.png"
cp "$ROOT_DIR/Packaging/Assets/StatusBarDoorProxy.png" "$RESOURCES_DIR/StatusBarDoorProxy.png"
cp "$ROOT_DIR/Packaging/Assets/StatusBarDoorOpen.png" "$RESOURCES_DIR/StatusBarDoorOpen.png"
cp "$ROOT_DIR/Packaging/Assets/StatusBarDoorOpenWithDoor.png" "$RESOURCES_DIR/StatusBarDoorOpenWithDoor.png"
cp "$ROOT_DIR/Packaging/Assets/StatusBarDoorOpenDoorway.png" "$RESOURCES_DIR/StatusBarDoorOpenDoorway.png"
ditto "$ROOT_DIR/Packaging/Dashboards" "$RESOURCES_DIR/Dashboards"
printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"
chmod 755 "$MACOS_DIR/Chumen"
chmod 755 "$RESOURCES_DIR/ChumenHelper"

CORE_SOURCE="${CHUMEN_CORE_PATH:-}"
if [[ -z "$CORE_SOURCE" && -x "$ROOT_DIR/bin/mihomo" ]]; then
  CORE_SOURCE="$ROOT_DIR/bin/mihomo"
fi

if [[ -n "$CORE_SOURCE" ]]; then
  if [[ ! -x "$CORE_SOURCE" ]]; then
    echo "Core path is not executable: $CORE_SOURCE" >&2
    exit 1
  fi
  cp "$CORE_SOURCE" "$RESOURCES_DIR/mihomo"
  chmod 755 "$RESOURCES_DIR/mihomo"
fi

codesign --force --deep --sign - "$APP_DIR" >/dev/null
codesign --verify --deep --strict "$APP_DIR"

echo "$APP_DIR"

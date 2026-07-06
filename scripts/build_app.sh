#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
DMG_README_DIR="$ROOT_DIR/Packaging/DMG"
CORE_BUNDLE_NAME="chumen-door"

usage() {
  cat <<'EOF'
Usage: scripts/build_app.sh [debug|release]

Build modes:
  debug    Daily development package. Default. Outputs dist/debug/Chumen.app
  release  Formal package. Outputs dist/Chumen.dmg
EOF
}

BUILD_CONFIGURATION="${1:-debug}"
if [[ $# -gt 1 ]]; then
  usage >&2
  exit 2
fi

case "$BUILD_CONFIGURATION" in
  debug|--debug|-d)
    BUILD_CONFIGURATION="debug"
    APP_DIR="$DIST_DIR/debug/Chumen.app"
    ;;
  release|--release|-r)
    BUILD_CONFIGURATION="release"
    APP_DIR="$DIST_DIR/Chumen.app"
    DMG_PATH="$DIST_DIR/Chumen.dmg"
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PLIST_BUDDY="/usr/libexec/PlistBuddy"

plist_set_string() {
  local key="$1"
  local value="$2"
  "$PLIST_BUDDY" -c "Set :$key $value" "$CONTENTS_DIR/Info.plist" 2>/dev/null ||
    "$PLIST_BUDDY" -c "Add :$key string $value" "$CONTENTS_DIR/Info.plist"
}

plist_set_integer() {
  local key="$1"
  local value="$2"
  "$PLIST_BUDDY" -c "Set :$key $value" "$CONTENTS_DIR/Info.plist" 2>/dev/null ||
    "$PLIST_BUDDY" -c "Add :$key integer $value" "$CONTENTS_DIR/Info.plist"
}

create_release_dmg() {
  local staging_dir
  staging_dir="$(mktemp -d "$DIST_DIR/dmg-staging.XXXXXX")"
  (
    trap 'rm -rf "$staging_dir"' EXIT

    cp -R "$APP_DIR" "$staging_dir/Chumen.app"
    ln -s /Applications "$staging_dir/Applications"
    cp "$DMG_README_DIR/README.zh.txt" "$staging_dir/README.zh.txt"
    cp "$DMG_README_DIR/README.en.txt" "$staging_dir/README.en.txt"

    rm -f "$DMG_PATH"
    hdiutil create \
      -volname "Chumen" \
      -srcfolder "$staging_dir" \
      -ov \
      -format UDZO \
      "$DMG_PATH" >/dev/null
    hdiutil verify "$DMG_PATH" >/dev/null
  )
}

cd "$ROOT_DIR"
echo "Building Chumen $BUILD_CONFIGURATION package..."
swift build -c "$BUILD_CONFIGURATION" --product Chumen
swift build -c "$BUILD_CONFIGURATION" --product ChumenHelper

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/.build/$BUILD_CONFIGURATION/Chumen" "$MACOS_DIR/Chumen"
cp "$ROOT_DIR/.build/$BUILD_CONFIGURATION/ChumenHelper" "$RESOURCES_DIR/ChumenHelper"
cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
if [[ "$BUILD_CONFIGURATION" == "debug" ]]; then
  plist_set_string "CFBundleIdentifier" "io.github.chumen.native-macos.debug"
  plist_set_string "CFBundleName" "Chumen Debug"
  plist_set_string "CFBundleDisplayName" "Chumen Debug"
  plist_set_integer "ChumenDefaultMixedPort" "19981"
  plist_set_integer "ChumenDefaultSocksPort" "19982"
  plist_set_integer "ChumenDefaultHTTPPort" "19983"
  plist_set_integer "ChumenDefaultRedirPort" "19984"
  plist_set_integer "ChumenDefaultTProxyPort" "19985"
  plist_set_integer "ChumenDefaultExternalControllerPort" "19997"
  plist_set_string "ChumenDefaultDNSListen" "127.0.0.1:1153"
  plist_set_string "ChumenDefaultTunDevice" "utun1025"
  plist_set_string "ChumenDefaultCoreProcessName" "door-debug"
fi
cp "$ROOT_DIR/Packaging/Assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$ROOT_DIR/Packaging/Assets/StatusBarDoorClosed.png" "$RESOURCES_DIR/StatusBarDoorClosed.png"
cp "$ROOT_DIR/Packaging/Assets/StatusBarDoorProxy.png" "$RESOURCES_DIR/StatusBarDoorProxy.png"
cp "$ROOT_DIR/Packaging/Assets/StatusBarDoorOpen.png" "$RESOURCES_DIR/StatusBarDoorOpen.png"
cp "$ROOT_DIR/Packaging/Assets/StatusBarDoorOpenWithDoor.png" "$RESOURCES_DIR/StatusBarDoorOpenWithDoor.png"
cp "$ROOT_DIR/Packaging/Assets/StatusBarDoorOpenDoorway.png" "$RESOURCES_DIR/StatusBarDoorOpenDoorway.png"
for RESOURCE_BUNDLE in "$ROOT_DIR"/.build/"$BUILD_CONFIGURATION"/*ChumenCore*.bundle; do
  [[ -d "$RESOURCE_BUNDLE" ]] || continue
  cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/"
done
printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"
chmod 755 "$MACOS_DIR/Chumen"
chmod 755 "$RESOURCES_DIR/ChumenHelper"

CORE_SOURCE="${CHUMEN_CORE_PATH:-}"
if [[ -z "$CORE_SOURCE" && -x "$ROOT_DIR/bin/$CORE_BUNDLE_NAME" ]]; then
  CORE_SOURCE="$ROOT_DIR/bin/$CORE_BUNDLE_NAME"
fi
if [[ -z "$CORE_SOURCE" && -x "$ROOT_DIR/bin/chumen-mihomo" ]]; then
  CORE_SOURCE="$ROOT_DIR/bin/chumen-mihomo"
fi
if [[ -z "$CORE_SOURCE" && -x "$ROOT_DIR/bin/mihomo" ]]; then
  CORE_SOURCE="$ROOT_DIR/bin/mihomo"
fi

if [[ -n "$CORE_SOURCE" ]]; then
  if [[ ! -x "$CORE_SOURCE" ]]; then
    echo "Core path is not executable: $CORE_SOURCE" >&2
    exit 1
  fi
  cp "$CORE_SOURCE" "$RESOURCES_DIR/$CORE_BUNDLE_NAME"
  chmod 755 "$RESOURCES_DIR/$CORE_BUNDLE_NAME"
fi

codesign --force --deep --sign - "$APP_DIR" >/dev/null
codesign --verify --deep --strict "$APP_DIR"

if [[ "$BUILD_CONFIGURATION" == "release" ]]; then
  create_release_dmg
  echo "$DMG_PATH"
else
  echo "$APP_DIR"
fi

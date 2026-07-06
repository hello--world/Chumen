#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
DMG_README_DIR="$ROOT_DIR/Packaging/DMG"
CORE_BUNDLE_NAME="chumen-door"
MACOS_DEPLOYMENT_TARGET="${CHUMEN_MACOS_DEPLOYMENT_TARGET:-15.0}"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/chumen-clang-module-cache}"

usage() {
  cat <<'EOF'
Usage: scripts/build_app.sh [debug|release] [variant|all]

Build modes:
  debug    Daily development package. Default. Outputs dist/debug/Chumen.app
  release  Formal package. Outputs dist/Chumen.dmg

Variants:
  universal  One package containing arm64 and x86_64. Default.
  arm64      Apple Silicon package.
  x86_64     Intel package.
  native     Package for the current host architecture.
  all        Build arm64, x86_64, and universal packages.

Environment:
  CHUMEN_BUILD_ARCHS          Single-package architectures: universal, native,
                              arm64, x86_64, or a comma/space-separated list.
                              Default: universal (arm64 x86_64).
  CHUMEN_PACKAGE_VARIANTS     Multi-package variants, for example:
                              arm64,x86_64,universal or all.
  CHUMEN_CORE_PATH            Bundle this already-universal or matching-arch core.
  CHUMEN_CORE_ARM64_PATH      Bundle/lipo this arm64 core slice.
  CHUMEN_CORE_X86_64_PATH     Bundle/lipo this x86_64 core slice.
  CHUMEN_REQUIRE_BUNDLED_CORE Set to 1 to fail when no suitable bundled core exists.
EOF
}

BUILD_CONFIGURATION="${1:-debug}"
REQUESTED_PACKAGE_VARIANTS="${2:-${CHUMEN_PACKAGE_VARIANTS:-}}"
BUILD_DATE="$(date '+%Y-%m-%d %H:%M:%S %z')"
if [[ $# -gt 2 ]]; then
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
  all|variants|multi)
    REQUESTED_PACKAGE_VARIANTS="$BUILD_CONFIGURATION"
    BUILD_CONFIGURATION="debug"
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

APP_DIR="${APP_DIR:-}"
DMG_PATH="${DMG_PATH:-}"
DMG_VOLUME_NAME=""
CONTENTS_DIR=""
MACOS_DIR=""
RESOURCES_DIR=""
PLIST_BUDDY="/usr/libexec/PlistBuddy"

normalize_archs() {
  local raw="${1:-universal}"
  raw="${raw//,/ }"

  local normalized=()
  local normalized_count=0
  local item
  for item in $raw; do
    case "$item" in
      universal|all)
        normalized+=("arm64" "x86_64")
        normalized_count=$((normalized_count + 2))
        ;;
      native)
        normalized+=("$(uname -m)")
        normalized_count=$((normalized_count + 1))
        ;;
      amd64|x64)
        normalized+=("x86_64")
        normalized_count=$((normalized_count + 1))
        ;;
      arm64|x86_64)
        normalized+=("$item")
        normalized_count=$((normalized_count + 1))
        ;;
      *)
        echo "Unsupported CHUMEN_BUILD_ARCHS value: $item" >&2
        exit 2
        ;;
    esac
  done

  local unique=()
  local unique_count=0
  local arch
  local existing
  local index
  for ((index = 0; index < normalized_count; index++)); do
    arch="${normalized[$index]}"
    existing=0
    local known
    local unique_index
    for ((unique_index = 0; unique_index < unique_count; unique_index++)); do
      known="${unique[$unique_index]}"
      if [[ "$known" == "$arch" ]]; then
        existing=1
        break
      fi
    done
    if [[ "$existing" -eq 0 ]]; then
      unique+=("$arch")
      unique_count=$((unique_count + 1))
    fi
  done

  if [[ "$unique_count" -eq 0 ]]; then
    echo "CHUMEN_BUILD_ARCHS did not resolve to any architecture." >&2
    exit 2
  fi

  printf '%s\n' "${unique[@]}"
}

variant_label_for_arch_spec() {
  local arch_spec="$1"
  local archs=()
  local arch
  local arch_count=0
  while IFS= read -r arch; do
    archs+=("$arch")
    arch_count=$((arch_count + 1))
  done < <(normalize_archs "$arch_spec")

  if [[ "$arch_count" -eq 1 ]]; then
    printf '%s\n' "${archs[0]}"
    return 0
  fi

  local has_arm64=0
  local has_x86_64=0
  local index
  for ((index = 0; index < arch_count; index++)); do
    arch="${archs[$index]}"
    case "$arch" in
      arm64)
        has_arm64=1
        ;;
      x86_64)
        has_x86_64=1
        ;;
    esac
  done

  if [[ "$arch_count" -eq 2 && "$has_arm64" -eq 1 && "$has_x86_64" -eq 1 ]]; then
    printf 'universal\n'
    return 0
  fi

  local label=""
  for ((index = 0; index < arch_count; index++)); do
    if [[ -n "$label" ]]; then
      label+="+"
    fi
    label+="${archs[$index]}"
  done
  printf '%s\n' "$label"
}

append_package_variant() {
  local arch_spec="$1"
  local label
  label="$(variant_label_for_arch_spec "$arch_spec")"

  local existing_label
  local index
  for ((index = 0; index < PACKAGE_VARIANT_COUNT; index++)); do
    existing_label="${PACKAGE_VARIANT_LABELS[$index]}"
    if [[ "$existing_label" == "$label" ]]; then
      return 0
    fi
  done

  PACKAGE_VARIANT_LABELS+=("$label")
  PACKAGE_VARIANT_ARCH_SPECS+=("$arch_spec")
  PACKAGE_VARIANT_COUNT=$((PACKAGE_VARIANT_COUNT + 1))
}

append_package_variants() {
  local raw="$1"
  raw="${raw//,/ }"

  local item
  for item in $raw; do
    case "$item" in
      all|variants|multi)
        append_package_variant "arm64"
        append_package_variant "x86_64"
        append_package_variant "universal"
        ;;
      universal|native|arm64|x86_64|amd64|x64)
        append_package_variant "$item"
        ;;
      *)
        echo "Unsupported package variant: $item" >&2
        usage >&2
        exit 2
        ;;
    esac
  done
}

set_package_paths() {
  local label="$1"
  local is_multi="$2"

  if [[ "$BUILD_CONFIGURATION" == "release" ]]; then
    if [[ "$is_multi" -eq 1 ]]; then
      APP_DIR="$DIST_DIR/Chumen-$label.app"
      DMG_PATH="$DIST_DIR/Chumen-$label.dmg"
      DMG_VOLUME_NAME="Chumen $label"
    else
      APP_DIR="$DIST_DIR/Chumen.app"
      DMG_PATH="$DIST_DIR/Chumen.dmg"
      DMG_VOLUME_NAME="Chumen"
    fi
  else
    if [[ "$is_multi" -eq 1 ]]; then
      APP_DIR="$DIST_DIR/debug/$label/Chumen.app"
    else
      APP_DIR="$DIST_DIR/debug/Chumen.app"
    fi
    DMG_PATH=""
    DMG_VOLUME_NAME=""
  fi

  CONTENTS_DIR="$APP_DIR/Contents"
  MACOS_DIR="$CONTENTS_DIR/MacOS"
  RESOURCES_DIR="$CONTENTS_DIR/Resources"
}

target_triple_for_arch() {
  local arch="$1"
  printf '%s-apple-macosx%s\n' "$arch" "$MACOS_DEPLOYMENT_TARGET"
}

build_product_dir_for_arch() {
  local arch="$1"
  local triple
  triple="$(target_triple_for_arch "$arch")"
  swift build -c "$BUILD_CONFIGURATION" --triple "$triple" --show-bin-path | tail -n 1
}

verify_binary_archs() {
  local binary="$1"
  shift
  local arch
  for arch in "$@"; do
    if ! lipo "$binary" -verify_arch "$arch" >/dev/null 2>&1; then
      return 1
    fi
  done
}

binary_archs() {
  local binary="$1"
  lipo "$binary" -archs 2>/dev/null || file "$binary"
}

copy_or_lipo_product() {
  local product="$1"
  local destination="$2"
  local inputs=()
  local build_dir

  for build_dir in "${BUILD_PRODUCT_DIRS[@]}"; do
    inputs+=("$build_dir/$product")
  done

  if [[ "${#inputs[@]}" -eq 1 ]]; then
    cp "${inputs[0]}" "$destination"
  else
    lipo -create "${inputs[@]}" -output "$destination"
  fi

  if ! verify_binary_archs "$destination" "${PACKAGE_ARCHS[@]}"; then
    echo "Packaged $product does not contain required architectures: ${PACKAGE_ARCHS[*]}" >&2
    echo "Actual: $(binary_archs "$destination")" >&2
    exit 1
  fi
}

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
      -volname "$DMG_VOLUME_NAME" \
      -srcfolder "$staging_dir" \
      -ov \
      -format UDZO \
      "$DMG_PATH" >/dev/null
    hdiutil verify "$DMG_PATH" >/dev/null
  )
}

core_source_for_arch() {
  local arch="$1"
  case "$arch" in
    arm64)
      if [[ -n "${CHUMEN_CORE_ARM64_PATH:-}" ]]; then
        printf '%s\n' "$CHUMEN_CORE_ARM64_PATH"
        return 0
      fi
      local candidate
      for candidate in \
        "$ROOT_DIR/bin/$CORE_BUNDLE_NAME-arm64"; do
        if [[ -x "$candidate" ]]; then
          printf '%s\n' "$candidate"
          return 0
        fi
      done
      ;;
    x86_64)
      if [[ -n "${CHUMEN_CORE_X86_64_PATH:-}" ]]; then
        printf '%s\n' "$CHUMEN_CORE_X86_64_PATH"
        return 0
      fi
      if [[ -n "${CHUMEN_CORE_AMD64_PATH:-}" ]]; then
        printf '%s\n' "$CHUMEN_CORE_AMD64_PATH"
        return 0
      fi
      local candidate
      for candidate in \
        "$ROOT_DIR/bin/$CORE_BUNDLE_NAME-x86_64" \
        "$ROOT_DIR/bin/$CORE_BUNDLE_NAME-amd64"; do
        if [[ -x "$candidate" ]]; then
          printf '%s\n' "$candidate"
          return 0
        fi
      done
      ;;
  esac
  return 1
}

default_core_source() {
  local candidate
  for candidate in \
    "$ROOT_DIR/bin/$CORE_BUNDLE_NAME"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

bundle_core() {
  local bundle_mode="${CHUMEN_BUNDLE_CORE:-auto}"
  case "$bundle_mode" in
    0|false|no|off)
      echo "Skipping bundled core because CHUMEN_BUNDLE_CORE=$bundle_mode."
      return 0
      ;;
  esac

  local destination="$RESOURCES_DIR/$CORE_BUNDLE_NAME"
  local arch_inputs=()
  local arch
  for arch in "${PACKAGE_ARCHS[@]}"; do
    local arch_source
    if arch_source="$(core_source_for_arch "$arch")"; then
      if [[ ! -x "$arch_source" ]]; then
        echo "Core path is not executable: $arch_source" >&2
        exit 1
      fi
      if ! verify_binary_archs "$arch_source" "$arch"; then
        echo "Core slice for $arch does not contain $arch: $arch_source" >&2
        echo "Actual: $(binary_archs "$arch_source")" >&2
        exit 1
      fi
      arch_inputs+=("$arch_source")
    fi
  done

  if [[ "${#arch_inputs[@]}" -eq "${#PACKAGE_ARCHS[@]}" ]]; then
    if [[ "${#arch_inputs[@]}" -eq 1 ]]; then
      cp "${arch_inputs[0]}" "$destination"
    else
      lipo -create "${arch_inputs[@]}" -output "$destination"
    fi
    chmod 755 "$destination"
    return 0
  fi

  local core_source="${CHUMEN_CORE_PATH:-}"
  local explicit_core=0
  if [[ -n "$core_source" ]]; then
    explicit_core=1
  elif core_source="$(default_core_source)"; then
    explicit_core=0
  else
    if [[ "${CHUMEN_REQUIRE_BUNDLED_CORE:-0}" == "1" ]]; then
      echo "No suitable core binary found for required architectures: ${PACKAGE_ARCHS[*]}" >&2
      exit 1
    fi
    echo "No bundled core found; package will require the user to choose a core binary."
    return 0
  fi

  if [[ ! -x "$core_source" ]]; then
    echo "Core path is not executable: $core_source" >&2
    exit 1
  fi

  if verify_binary_archs "$core_source" "${PACKAGE_ARCHS[@]}"; then
    cp "$core_source" "$destination"
    chmod 755 "$destination"
    return 0
  fi

  if [[ "$explicit_core" -eq 1 || "${CHUMEN_REQUIRE_BUNDLED_CORE:-0}" == "1" ]]; then
    echo "Core binary does not contain required architectures: ${PACKAGE_ARCHS[*]}" >&2
    echo "Core: $core_source" >&2
    echo "Actual: $(binary_archs "$core_source")" >&2
    echo "Use CHUMEN_CORE_ARCH=universal scripts/download_mihomo.sh or pass CHUMEN_CORE_ARM64_PATH and CHUMEN_CORE_X86_64_PATH." >&2
    exit 1
  fi

  echo "Skipping bundled core; $core_source lacks required architectures (${PACKAGE_ARCHS[*]})."
  echo "Actual: $(binary_archs "$core_source")"
}

build_package_variant() {
  local label="$1"
  local arch_spec="$2"
  local is_multi="$3"

  PACKAGE_ARCHS=()
  while IFS= read -r ARCH; do
    PACKAGE_ARCHS+=("$ARCH")
  done < <(normalize_archs "$arch_spec")
  BUILD_PRODUCT_DIRS=()
  set_package_paths "$label" "$is_multi"

  echo "Building Chumen $BUILD_CONFIGURATION $label package for ${PACKAGE_ARCHS[*]}..."
  local ARCH
  local TRIPLE
  for ARCH in "${PACKAGE_ARCHS[@]}"; do
    TRIPLE="$(target_triple_for_arch "$ARCH")"
    echo "Building $BUILD_CONFIGURATION $ARCH ($TRIPLE)..."
    swift build -c "$BUILD_CONFIGURATION" --triple "$TRIPLE" --product Chumen
    swift build -c "$BUILD_CONFIGURATION" --triple "$TRIPLE" --product ChumenHelper
    BUILD_PRODUCT_DIRS+=("$(build_product_dir_for_arch "$ARCH")")
  done

  rm -rf "$APP_DIR"
  mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

  copy_or_lipo_product "Chumen" "$MACOS_DIR/Chumen"
  copy_or_lipo_product "ChumenHelper" "$RESOURCES_DIR/ChumenHelper"
  cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
  plist_set_string "ChumenBuildDate" "$BUILD_DATE"
  plist_set_string "ChumenPackageVariant" "$label"
  plist_set_string "ChumenPackageArchitectures" "${PACKAGE_ARCHS[*]}"
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
  for RESOURCE_BUNDLE in "${BUILD_PRODUCT_DIRS[0]}"/*ChumenCore*.bundle; do
    [[ -d "$RESOURCE_BUNDLE" ]] || continue
    cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/"
  done
  printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"
  chmod 755 "$MACOS_DIR/Chumen"
  chmod 755 "$RESOURCES_DIR/ChumenHelper"

  bundle_core

  codesign --force --deep --sign - "$APP_DIR" >/dev/null
  codesign --verify --deep --strict "$APP_DIR"

  if [[ "$BUILD_CONFIGURATION" == "release" ]]; then
    create_release_dmg
    BUILT_OUTPUTS+=("$DMG_PATH")
  else
    BUILT_OUTPUTS+=("$APP_DIR")
  fi
}

PACKAGE_VARIANT_LABELS=()
PACKAGE_VARIANT_ARCH_SPECS=()
PACKAGE_VARIANT_COUNT=0
BUILT_OUTPUTS=()

if [[ -n "$REQUESTED_PACKAGE_VARIANTS" ]]; then
  append_package_variants "$REQUESTED_PACKAGE_VARIANTS"
else
  append_package_variant "${CHUMEN_BUILD_ARCHS:-universal}"
fi

if [[ "$PACKAGE_VARIANT_COUNT" -eq 0 ]]; then
  echo "No package variants requested." >&2
  exit 2
fi

IS_MULTI_PACKAGE=0
if [[ "$PACKAGE_VARIANT_COUNT" -gt 1 ]]; then
  IS_MULTI_PACKAGE=1
fi

cd "$ROOT_DIR"
for ((INDEX = 0; INDEX < PACKAGE_VARIANT_COUNT; INDEX++)); do
  build_package_variant \
    "${PACKAGE_VARIANT_LABELS[$INDEX]}" \
    "${PACKAGE_VARIANT_ARCH_SPECS[$INDEX]}" \
    "$IS_MULTI_PACKAGE"
done

printf '%s\n' "${BUILT_OUTPUTS[@]}"

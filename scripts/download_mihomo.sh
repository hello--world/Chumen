#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${MIHOMO_VERSION:-1.19.27}"
REQUESTED_ARCH="${1:-${CHUMEN_CORE_ARCH:-${MIHOMO_ARCH:-native}}}"

usage() {
  cat <<'EOF'
Usage: scripts/download_mihomo.sh [native|arm64|x86_64|universal]

Environment:
  MIHOMO_VERSION    Upstream release version. Default: 1.19.27
  CHUMEN_CORE_ARCH  Same values as the optional argument.
  MIHOMO_ARCH       Legacy alias for CHUMEN_CORE_ARCH.
EOF
}

CORE_DIR="$ROOT_DIR/bin"
CORE_BIN="$CORE_DIR/chumen-door"

asset_arch_for() {
  local arch="$1"
  case "$arch" in
    arm64)
      printf 'arm64\n'
      ;;
    x86_64)
      printf 'amd64\n'
      ;;
    *)
      echo "Unsupported normalized architecture: $arch" >&2
      exit 2
      ;;
  esac
}

download_arch() {
  local arch="$1"
  local asset_arch
  asset_arch="$(asset_arch_for "$arch")"
  local core_gz="$CORE_DIR/mihomo-darwin-$asset_arch-v$VERSION.gz"
  local arch_bin="$CORE_DIR/chumen-door-$arch"
  local url="https://github.com/MetaCubeX/mihomo/releases/download/v$VERSION/mihomo-darwin-$asset_arch-v$VERSION.gz"

  curl -fL --retry 3 --retry-delay 2 -o "$core_gz" "$url"
  gzip -dc "$core_gz" > "$arch_bin"
  chmod 755 "$arch_bin"
  xattr -cr "$arch_bin" 2>/dev/null || true
  lipo "$arch_bin" -verify_arch "$arch" >/dev/null
  printf '%s\n' "$arch_bin"
}

ARCHS=()
case "$REQUESTED_ARCH" in
  native)
    ARCHS+=("$(uname -m)")
    ;;
  universal|all)
    ARCHS+=("arm64" "x86_64")
    ;;
  amd64|x64)
    ARCHS+=("x86_64")
    ;;
  arm64|x86_64)
    ARCHS+=("$REQUESTED_ARCH")
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  *)
    echo "Unsupported chumen-door architecture: $REQUESTED_ARCH" >&2
    usage >&2
    exit 2
    ;;
esac

mkdir -p "$CORE_DIR"

ARCH_BINS=()
for ARCH in "${ARCHS[@]}"; do
  ARCH_BINS+=("$(download_arch "$ARCH")")
done

if [[ "${#ARCH_BINS[@]}" -eq 1 ]]; then
  cp "${ARCH_BINS[0]}" "$CORE_BIN"
else
  lipo -create "${ARCH_BINS[@]}" -output "$CORE_BIN"
fi

chmod 755 "$CORE_BIN"
xattr -cr "$CORE_BIN" 2>/dev/null || true
lipo "$CORE_BIN" -verify_arch "${ARCHS[@]}" >/dev/null

HOST_ARCH="$(uname -m)"
if lipo "$CORE_BIN" -verify_arch "$HOST_ARCH" >/dev/null 2>&1; then
  "$CORE_BIN" -v
else
  echo "Downloaded $CORE_BIN ($(lipo "$CORE_BIN" -archs))"
fi
echo "$CORE_BIN"

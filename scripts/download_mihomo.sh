#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${MIHOMO_VERSION:-1.19.27}"
ARCH="$(uname -m)"

case "$ARCH" in
  arm64)
    ASSET_ARCH="arm64"
    ;;
  x86_64)
    ASSET_ARCH="amd64"
    ;;
  *)
    echo "Unsupported macOS architecture: $ARCH" >&2
    exit 1
    ;;
esac

CORE_DIR="$ROOT_DIR/bin"
CORE_GZ="$CORE_DIR/mihomo-darwin-$ASSET_ARCH-v$VERSION.gz"
CORE_BIN="$CORE_DIR/chumen-door"
URL="https://github.com/MetaCubeX/mihomo/releases/download/v$VERSION/mihomo-darwin-$ASSET_ARCH-v$VERSION.gz"

mkdir -p "$CORE_DIR"
curl -fL --retry 3 --retry-delay 2 -o "$CORE_GZ" "$URL"
gzip -dc "$CORE_GZ" > "$CORE_BIN"
chmod 755 "$CORE_BIN"
xattr -cr "$CORE_BIN" 2>/dev/null || true

"$CORE_BIN" -v
echo "$CORE_BIN"

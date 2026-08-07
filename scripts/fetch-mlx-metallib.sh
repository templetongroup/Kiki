#!/bin/bash
# Fetches the official MLX Metal shader library used by the native Swift engine.
set -euo pipefail
cd "$(dirname "$0")/.."

MLX_METAL_VERSION="0.31.1"
MLX_METAL_SHA256="70741174131dbf7fdd479cb730e06e08c358eac3bf7905d9e884e7960cfdd5b8"
MLX_METAL_URL="https://files.pythonhosted.org/packages/39/66/2313497fdbc7fbadf8e026c09366e3f049f9114e65ca4edc23cdb8699186/mlx_metal-${MLX_METAL_VERSION}-py3-none-macosx_14_0_arm64.whl"
DESTINATION="build/MLX/mlx.metallib"
CACHE_DIR="build/MLX/cache"
WHEEL="$CACHE_DIR/mlx-metal-${MLX_METAL_VERSION}.whl"

if [[ -s "$DESTINATION" ]]; then
    exit 0
fi

mkdir -p "$CACHE_DIR" "$(dirname "$DESTINATION")"
if [[ ! -f "$WHEEL" ]]; then
    echo "Fetching the official MLX ${MLX_METAL_VERSION} Metal library..."
    curl --fail --location --retry 3 --output "$WHEEL" "$MLX_METAL_URL"
fi

ACTUAL_SHA256="$(shasum -a 256 "$WHEEL" | awk '{print $1}')"
if [[ "$ACTUAL_SHA256" != "$MLX_METAL_SHA256" ]]; then
    echo "error: MLX Metal package checksum mismatch" >&2
    exit 1
fi

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
unzip -q "$WHEEL" 'mlx/lib/mlx.metallib' -d "$TEMP_DIR"
cp "$TEMP_DIR/mlx/lib/mlx.metallib" "$DESTINATION"
echo "Prepared $DESTINATION"

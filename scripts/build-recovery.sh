#!/usr/bin/env bash
set -Eeuo pipefail

export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export USE_CCACHE=1
export CCACHE_DIR="${CCACHE_DIR:-$GITHUB_WORKSPACE/.ccache}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${SOURCE_DIR:-$ROOT/android}"

MANIFEST_URL="${MANIFEST_URL:-https://github.com/SHRP/manifest.git}"
MANIFEST_BRANCH="${MANIFEST_BRANCH:-v3_11.0}"

DEVICE_TREE_URL="${DEVICE_TREE_URL:-https://github.com/LineageOS/android_device_google_bluejay}"
DEVICE_TREE_BRANCH="${DEVICE_TREE_BRANCH:-lineage-19.1}"

VENDOR_TREE_URL="${VENDOR_TREE_URL:-}"
VENDOR_TREE_BRANCH="${VENDOR_TREE_BRANCH:-main}"
VENDOR_PATH="${VENDOR_PATH:-}"

KERNEL_TREE_URL="${KERNEL_TREE_URL:-}"
KERNEL_TREE_BRANCH="${KERNEL_TREE_BRANCH:-main}"
KERNEL_PATH="${KERNEL_PATH:-}"

DEVICE_PATH="${DEVICE_PATH:-device/google/bluejay}"
DEVICE_NAME="${DEVICE_NAME:-bluejay}"
LUNCH_TARGET="${LUNCH_TARGET:-shrp_bluejay-eng}"
BUILD_TARGET="${BUILD_TARGET:-recoveryimage}"

exec > >(tee -a "$ROOT/build.log") 2>&1

mkdir -p "$SOURCE_DIR"
cd "$SOURCE_DIR"

if [ ! -d .repo ]; then
    repo init \
        -u "$MANIFEST_URL" \
        -b "$MANIFEST_BRANCH" \
        --depth=1
fi

repo sync \
    --force-sync \
    --force-remove-dirty \
    --no-tags \
    --no-clone-bundle \
    -j"$(nproc)"

rm -rf "$DEVICE_PATH"
mkdir -p "$(dirname "$DEVICE_PATH")"
git clone \
    --depth=1 \
    --branch "$DEVICE_TREE_BRANCH" \
    "$DEVICE_TREE_URL" \
    "$DEVICE_PATH"

if [ -n "$VENDOR_TREE_URL" ] && [ -n "$VENDOR_PATH" ]; then
    rm -rf "$VENDOR_PATH"
    mkdir -p "$(dirname "$VENDOR_PATH")"

    git clone \
        --depth=1 \
        --branch "$VENDOR_TREE_BRANCH" \
        "$VENDOR_TREE_URL" \
        "$VENDOR_PATH"
fi

if [ -n "$KERNEL_TREE_URL" ] && [ -n "$KERNEL_PATH" ]; then
    rm -rf "$KERNEL_PATH"
    mkdir -p "$(dirname "$KERNEL_PATH")"

    git clone \
        --depth=1 \
        --branch "$KERNEL_TREE_BRANCH" \
        "$KERNEL_TREE_URL" \
        "$KERNEL_PATH"
fi

source build/envsetup.sh
lunch "$LUNCH_TARGET"

make -j"$(nproc)" "$BUILD_TARGET"

PRODUCT_OUT="$SOURCE_DIR/out/target/product/$DEVICE_NAME"

if [ ! -d "$PRODUCT_OUT" ]; then
    echo "Could not find product output: $PRODUCT_OUT" >&2
    exit 1
fi

DEST="$ROOT/out/target/product/$DEVICE_NAME"
mkdir -p "$DEST"

FOUND_IMAGE=false

for image in recovery.img boot.img; do
    if [ -f "$PRODUCT_OUT/$image" ]; then
        cp -v "$PRODUCT_OUT/$image" "$DEST/$image"
        FOUND_IMAGE=true
    fi
done

if [ "$FOUND_IMAGE" != true ]; then
    echo "No recovery.img or boot.img was produced." >&2
    exit 1
fi

cd "$ROOT"
./scripts/package-installer.sh "$DEVICE_NAME" "$DEST"

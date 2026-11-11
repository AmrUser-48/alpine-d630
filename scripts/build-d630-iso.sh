#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/build-env.sh"

ensure_aports
ensure_build_dirs
ensure_builder_image
ensure_signing_key

SIGNING_PUBKEY="$(find "$KEYS_DIR" -maxdepth 1 -type f -name '*.rsa.pub' -print -quit)"
[ -n "$SIGNING_PUBKEY" ] || { echo "Missing APK signing public key" >&2; exit 1; }
SIGNING_PUBKEY_NAME="${SIGNING_PUBKEY##*/}"

USERLAND_MARKER="$PACKAGES_DIR/core2-userland-built"
[ -s "$USERLAND_MARKER" ] || {
    echo "Missing Core 2 userland build marker: $USERLAND_MARKER" >&2
    echo "Build it first: ./scripts/build-core2-userland.sh" >&2
    exit 1
}

APKINDEX="$PACKAGES_DIR/repo/packages/$TARGET_ARCH/APKINDEX.tar.gz"
[ -f "$APKINDEX" ] || {
    echo "Missing local APK index: $APKINDEX" >&2
    echo "Build the custom kernel first: ./scripts/build-linux-d630.sh" >&2
    exit 1
}

docker run --rm \
    --volume "$PROJECT_ROOT:/workspace/src:ro" \
    --volume "$BUILD_ROOT:/workspace/build" \
    --volume "$KEYS_DIR:/home/builder/.abuild" \
    --volume "$SIGNING_PUBKEY:/etc/apk/keys/$SIGNING_PUBKEY_NAME:ro" \
    --volume "$PROJECT_ROOT/container/mkimage:/home/builder/.mkimage:ro" \
    --workdir /workspace/build \
    "$IMAGE" \
    sh /workspace/src/scripts/container-build-d630-iso.sh

printf '\nISO output: %s\n' "$OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"

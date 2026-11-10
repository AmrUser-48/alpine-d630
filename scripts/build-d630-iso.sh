#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/build-env.sh"

ensure_aports
ensure_build_dirs
ensure_builder_image
ensure_signing_key

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
    --volume "$PROJECT_ROOT/container/mkimage:/home/builder/.mkimage:ro" \
    --workdir /workspace/build \
    "$IMAGE" \
    sh /workspace/src/scripts/container-build-d630-iso.sh

printf '\nISO output: %s\n' "$OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"

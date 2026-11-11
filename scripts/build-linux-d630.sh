#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/build-env.sh"

ensure_aports
"$PROJECT_ROOT/scripts/prepare-linux-d630.sh"
ensure_build_dirs
ensure_builder_image
ensure_signing_key

SIGNING_PUBKEY="$(find "$KEYS_DIR" -maxdepth 1 -type f -name '*.rsa.pub' -print -quit)"
[ -n "$SIGNING_PUBKEY" ] || { echo "Missing APK signing public key" >&2; exit 1; }
SIGNING_PUBKEY_NAME="${SIGNING_PUBKEY##*/}"

docker run --rm \
    --volume "$SIGNING_PUBKEY:/etc/apk/keys/$SIGNING_PUBKEY_NAME:ro" \
    --volume "$PROJECT_ROOT:/workspace/src:ro" \
    --volume "$BUILD_ROOT:/workspace/build" \
    --volume "$KEYS_DIR:/home/builder/.abuild" \
    --workdir /workspace/build/packages/linux-d630 \
    --env FLAVOR=d630 \
    --env KCFLAGS="$TARGET_KERNEL_FLAGS" \
    --env MAKEFLAGS="-j4" \
    --env REPODEST=/workspace/build/packages/repo \
    --env SRCDEST=/workspace/build/work/distfiles \
    --env SOURCE_DATE_EPOCH="$(git -C "$APORTS_DIR" log -1 --format=%ct)" \
    "$IMAGE" \
    sh -c 'abuild -r && abuild index'

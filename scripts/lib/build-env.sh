#!/bin/sh

# Shared paths and helpers for every host-side build command.
PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

if [ -n "${ALPINE_D630_BUILD_ROOT:-}" ]; then
    BUILD_ROOT="$ALPINE_D630_BUILD_ROOT"
elif [ -n "${RUNNER_TEMP:-}" ]; then
    BUILD_ROOT="$RUNNER_TEMP/alpine-d630"
else
    BUILD_ROOT="$HOME/.cache/alpine-d630"
fi

APORTS_DIR="$BUILD_ROOT/aports"
WORK_DIR="$BUILD_ROOT/work"
PACKAGES_DIR="$BUILD_ROOT/packages"
KEYS_DIR="$BUILD_ROOT/keys"
OUTPUT_DIR="$BUILD_ROOT/output"
IMAGE="alpine-d630-builder:3.24.4"

set -a
. "$PROJECT_ROOT/config/target.env"
set +a

export PROJECT_ROOT BUILD_ROOT APORTS_DIR WORK_DIR PACKAGES_DIR
export KEYS_DIR OUTPUT_DIR IMAGE

ensure_build_dirs() {
    mkdir -p "$APORTS_DIR" "$WORK_DIR/distfiles" "$PACKAGES_DIR/repo" \
        "$KEYS_DIR" "$OUTPUT_DIR" "$WORK_DIR/mkimage-d630-cache"
}

ensure_aports() {
    ensure_build_dirs

    if [ ! -d "$APORTS_DIR/.git" ]; then
        rmdir "$APORTS_DIR" 2>/dev/null || true
        git clone --depth=1 --branch "$APORTS_BRANCH" \
            https://github.com/alpinelinux/aports.git "$APORTS_DIR"
    fi

    if ! git -C "$APORTS_DIR" cat-file -e "$APORTS_COMMIT^{commit}" 2>/dev/null; then
        git -C "$APORTS_DIR" fetch --depth=1 origin "$APORTS_COMMIT"
    fi

    git -C "$APORTS_DIR" checkout --detach "$APORTS_COMMIT"
    printf 'Alpine aports: %s (%s)\n' "$APORTS_BRANCH" "$APORTS_COMMIT"
}

ensure_builder_image() {
    docker build --pull -t "$IMAGE" "$PROJECT_ROOT/container"
}

ensure_signing_key() {
    if ! find "$KEYS_DIR" -maxdepth 1 -type f -name '*.rsa' ! -name '*.rsa.pub' | grep -q .; then
        docker run --rm \
            --volume "$KEYS_DIR:/home/builder/.abuild" \
            "$IMAGE" abuild-keygen -a -n
    fi
}

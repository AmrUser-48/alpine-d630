#!/bin/sh
set -eu

BUILD=/workspace/build
SOURCE=/workspace/src

mkdir -p /home/builder/.abuild "$BUILD/output" "$BUILD/work/mkimage-d630-cache"

. /home/builder/.abuild/abuild.conf
: "${PACKAGER_PRIVKEY:?PACKAGER_PRIVKEY is not configured}"
[ -f "$PACKAGER_PRIVKEY" ] || {
    echo "Signing key does not exist: $PACKAGER_PRIVKEY" >&2
    exit 1
}
[ -f "$PACKAGER_PRIVKEY.pub" ] || {
    echo "Public signing key does not exist: $PACKAGER_PRIVKEY.pub" >&2
    exit 1
}

APKINDEX="$BUILD/packages/repo/packages/x86_64/APKINDEX.tar.gz"
[ -f "$APKINDEX" ] || {
    echo "No local APKINDEX found: $APKINDEX" >&2
    exit 1
}
LOCAL_REPO="$(dirname "$APKINDEX")"

export PACKAGER="D630 Alpine Builder <builder@localhost>"
export PACKAGER_PUBKEY="$PACKAGER_PRIVKEY.pub"
export SOURCE_DATE_EPOCH="$(git -C "$BUILD/aports" log -1 --format=%ct)"

cd "$BUILD/aports/scripts"
./mkimage.sh \
    --tag 3.24.4-d630.1 \
    --arch x86_64 \
    --profile d630 \
    --repository "file://$LOCAL_REPO" \
    --repository https://dl-cdn.alpinelinux.org/alpine/v3.24/main \
    --repository https://dl-cdn.alpinelinux.org/alpine/v3.24/community \
    --outdir "$BUILD/output" \
    --workdir "$BUILD/work/mkimage-d630-cache" \
    --checksum

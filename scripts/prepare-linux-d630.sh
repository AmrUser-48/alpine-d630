#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/build-env.sh"
ensure_build_dirs

SOURCE="$PROJECT_ROOT/packaging/linux-d630"
CONFIG_SOURCE="$PROJECT_ROOT/config/config-6.1.190-d630-core2"
TARGET="$PACKAGES_DIR/linux-d630"

[ -f "$SOURCE/APKBUILD" ] || { echo "Missing source APKBUILD: $SOURCE/APKBUILD" >&2; exit 1; }
[ -f "$CONFIG_SOURCE" ] || { echo "Missing supplied kernel config: $CONFIG_SOURCE" >&2; exit 1; }

rm -rf "$TARGET"
mkdir -p "$TARGET"
cp "$SOURCE/APKBUILD" "$TARGET/APKBUILD"
cp "$CONFIG_SOURCE" "$TARGET/d630.x86_64.config"

# Keep the user-supplied file unchanged; tune only the staging copy.
# The D630 has two logical CPUs. Prefer zstd for zram, as used by the D630 setup.
sed -i \
    -e 's/^CONFIG_MAXSMP=y$/# CONFIG_MAXSMP is not set/' \
    -e 's/^CONFIG_NR_CPUS=8192$/CONFIG_NR_CPUS=2/' \
    -e 's/^CONFIG_ZRAM_DEF_COMP_LZ4=y$/# CONFIG_ZRAM_DEF_COMP_LZ4 is not set/' \
    -e 's/^CONFIG_ZRAM_DEF_COMP="lz4"$/CONFIG_ZRAM_DEF_COMP="zstd"/' \
    -e 's/^# CONFIG_ZRAM_DEF_COMP_ZSTD is not set$/CONFIG_ZRAM_DEF_COMP_ZSTD=y/' \
    -e 's/^# CONFIG_FW_LOADER_COMPRESS_ZSTD is not set$/CONFIG_FW_LOADER_COMPRESS_ZSTD=y/' \
    -e '/^CONFIG_EXTRA_FIRMWARE=/d' \
    -e '/^CONFIG_EXTRA_FIRMWARE_DIR=/d' \
    -e 's/^CONFIG_STAGING=y$/# CONFIG_STAGING is not set/' \
    -e 's/^CONFIG_INTEL_ISH_HID=m$/# CONFIG_INTEL_ISH_HID is not set/' \
    -e 's/^CONFIG_AMD_SFH_HID=m$/# CONFIG_AMD_SFH_HID is not set/' \
    "$TARGET/d630.x86_64.config"

python3 - "$TARGET/APKBUILD" "$TARGET/d630.x86_64.config" <<'PY'
from pathlib import Path
import hashlib
import re
import sys

apkbuild = Path(sys.argv[1])
config = Path(sys.argv[2])
text = apkbuild.read_text()
checksum = hashlib.sha512(config.read_bytes()).hexdigest()
start = text.find('sha512sums="')
if start < 0:
    raise SystemExit("APKBUILD has no sha512sums block")
end = text.find('\n"', start + len('sha512sums="'))
if end < 0:
    raise SystemExit("Could not locate sha512sums block end")
block = text[start:end]
lines = [line for line in block.splitlines() if not line.strip().endswith('d630.x86_64.config')]
lines.append(f"{checksum}  d630.x86_64.config")
text = text[:start] + "\n".join(lines) + text[end:]
apkbuild.write_text(text)
PY

printf 'Prepared linux-d630 %s from %s\n' \
    "$(sed -n 's/^pkgver=//p' "$TARGET/APKBUILD" | head -1)" "$CONFIG_SOURCE"
printf 'Source config SHA256: '; sha256sum "$CONFIG_SOURCE"
printf 'Staged config SHA256: '; sha256sum "$TARGET/d630.x86_64.config"
printf 'Build root: %s\n' "$BUILD_ROOT"

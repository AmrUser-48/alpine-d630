#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/build-env.sh"

ensure_aports

SOURCE="$APORTS_DIR/main/linux-lts"
TARGET="$PACKAGES_DIR/linux-d630"

[ -f "$SOURCE/APKBUILD" ] || {
    echo "Missing Alpine linux-lts APKBUILD: $SOURCE" >&2
    exit 1
}
[ -f "$SOURCE/lts.x86_64.config" ] || {
    echo "Missing Alpine x86_64 LTS config" >&2
    exit 1
}
[ -f "$PROJECT_ROOT/config/d630-kernel.fragment" ] || {
    echo "Missing D630 config fragment" >&2
    exit 1
}

mkdir -p "$TARGET"
cp -a "$SOURCE/." "$TARGET/"
cp "$SOURCE/lts.x86_64.config" "$TARGET/d630.x86_64.config"
sed -i 's/linux-firmware-any/linux-firmware-intel/g' "$TARGET/APKBUILD"

for symbol in \
    CPU_FREQ CPU_FREQ_GOV_USERSPACE X86_ACPI_CPUFREQ IWL3945 MICROCODE \
    ATA ATA_PIIX SATA_AHCI USB_STORAGE EXT4_FS BTRFS_FS NTFS3_FS \
    NTFS3_LZX_XPRESS NTFS3_FS_POSIX_ACL FAT_FS MSDOS_FS VFAT_FS EXFAT_FS \
    ISO9660_FS SQUASHFS FUSE_FS CUSE OVERLAY_FS AUTOFS_FS NLS NLS_UTF8 \
    NLS_CODEPAGE_437 ZRAM ZRAM_BACKEND_LZ4 ZRAM_BACKEND_LZ4HC \
    ZRAM_BACKEND_ZSTD ZRAM_BACKEND_DEFLATE ZRAM_BACKEND_842 \
    ZRAM_BACKEND_LZO ZRAM_DEF_COMP_ZSTD X86_NATIVE_CPU
do
    sed -i \
        -e "/^CONFIG_${symbol}=/d" \
        -e "/^# CONFIG_${symbol} is not set$/d" \
        "$TARGET/d630.x86_64.config"
done

cat "$PROJECT_ROOT/config/d630-kernel.fragment" >> "$TARGET/d630.x86_64.config"

python3 - "$TARGET/APKBUILD" "$TARGET/d630.x86_64.config" <<'PY'
from pathlib import Path
import hashlib
import sys

apkbuild = Path(sys.argv[1])
config = Path(sys.argv[2])
text = apkbuild.read_text()

needle = '\tfor i in $_flavors; do\n\t\t_prepareconfig "$i" "$CARCH"\n\tdone\n'
replacement = (
    '\tfor i in $_flavors; do\n'
    '\t\t_prepareconfig "$i" "$CARCH"\n'
    '\t\tif [ "$i" = "d630" ]; then\n'
    '\t\t\t/workspace/src/scripts/audit-d630-config.sh "$srcdir/build-$i.$CARCH/.config" "${KCFLAGS:-}"\n'
    '\t\tfi\n'
    '\tdone\n'
)
if text.count(needle) != 1:
    raise SystemExit("Could not locate expected linux-lts build() config-preparation loop")
text = text.replace(needle, replacement)

marker = 'sha512sums="'
start = text.rfind(marker)
if start < 0:
    raise SystemExit("APKBUILD has no sha512sums block")
body_start = start + len(marker)
end = text.find('\n"', body_start)
if end < 0:
    raise SystemExit("Could not locate end of sha512sums block")
lines = [
    line for line in text[body_start:end].splitlines()
    if line.strip() and line.split()[-1] != "d630.x86_64.config"
]
digest = hashlib.sha512(config.read_bytes()).hexdigest()
lines.append(f"{digest}  d630.x86_64.config")
text = text[:body_start] + "\n" + "\n".join(lines) + text[end:]
apkbuild.write_text(text)
PY

printf 'Prepared linux-d630 flavor from Alpine linux-lts %s\n' "$(sed -n 's/^pkgver=//p' "$TARGET/APKBUILD" | head -1)"
printf 'Firmware dependency: '
grep -m1 -o 'linux-firmware-intel' "$TARGET/APKBUILD"
printf 'Build root: %s\n' "$BUILD_ROOT"
printf 'Config SHA256: '
sha256sum "$TARGET/d630.x86_64.config"
printf 'Config SHA512: '
sha512sum "$TARGET/d630.x86_64.config"

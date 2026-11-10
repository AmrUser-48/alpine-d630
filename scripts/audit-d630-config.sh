#!/bin/sh
set -eu

CONFIG_FILE="${1:?usage: audit-d630-config.sh KERNEL_CONFIG KCFLAGS}"
KCFLAGS_VALUE="${2:-}"

[ -f "$CONFIG_FILE" ] || {
    echo "Missing generated kernel config: $CONFIG_FILE" >&2
    exit 1
}
[ "$KCFLAGS_VALUE" = "-march=core2 -mtune=core2" ] || {
    echo "Refusing wrong KCFLAGS: '$KCFLAGS_VALUE'" >&2
    exit 1
}

require() {
    grep -qx "$1" "$CONFIG_FILE" || {
        echo "Required kernel setting missing after olddefconfig: $1" >&2
        exit 1
    }
}

require '# CONFIG_X86_NATIVE_CPU is not set'
require 'CONFIG_MICROCODE=y'
require 'CONFIG_CPU_FREQ=y'
require 'CONFIG_CPU_FREQ_GOV_USERSPACE=y'
require 'CONFIG_X86_ACPI_CPUFREQ=m'
require 'CONFIG_X86_MSR=m'
require 'CONFIG_X86_CPUID=m'
require 'CONFIG_DRM_I915=m'
require 'CONFIG_AGP_INTEL=m'
require 'CONFIG_SATA_AHCI=m'
require 'CONFIG_ATA_PIIX=m'
require 'CONFIG_USB_STORAGE=m'
require 'CONFIG_IWL3945=m'
require 'CONFIG_SND_HDA_INTEL=m'
require 'CONFIG_SND_HDA_CODEC_SIGMATEL=m'
require 'CONFIG_MOUSE_PS2=m'
require 'CONFIG_INPUT_MOUSEDEV=m'
require 'CONFIG_AUTOFS_FS=y'
require 'CONFIG_EXT4_FS=m'
require 'CONFIG_BTRFS_FS=m'
require 'CONFIG_NTFS3_FS=m'
require 'CONFIG_NTFS3_LZX_XPRESS=y'
require 'CONFIG_NTFS3_FS_POSIX_ACL=y'
require 'CONFIG_FAT_FS=y'
require 'CONFIG_MSDOS_FS=y'
require 'CONFIG_VFAT_FS=m'
require 'CONFIG_EXFAT_FS=m'
require 'CONFIG_ISO9660_FS=m'
require 'CONFIG_SQUASHFS=m'
require 'CONFIG_FUSE_FS=m'
require 'CONFIG_CUSE=m'
require 'CONFIG_OVERLAY_FS=m'
require 'CONFIG_NLS_UTF8=y'
require 'CONFIG_NLS_CODEPAGE_437=y'
require 'CONFIG_FW_LOADER_COMPRESS_ZSTD=y'
require 'CONFIG_ZRAM=y'
require 'CONFIG_ZRAM_BACKEND_LZ4=y'
require 'CONFIG_ZRAM_BACKEND_LZ4HC=y'
require 'CONFIG_ZRAM_BACKEND_ZSTD=y'
require 'CONFIG_ZRAM_BACKEND_DEFLATE=y'
require 'CONFIG_ZRAM_BACKEND_842=y'
require 'CONFIG_ZRAM_BACKEND_LZO=y'
require 'CONFIG_ZRAM_DEF_COMP_ZSTD=y'

echo "D630 kernel config audit passed."
echo "KCFLAGS=$KCFLAGS_VALUE"

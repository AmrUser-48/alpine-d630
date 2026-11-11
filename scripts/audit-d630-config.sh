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

require_enabled() {
    grep -Eq "^CONFIG_$1=(y|m)$" "$CONFIG_FILE" || {
        echo "Required kernel option disabled after olddefconfig: CONFIG_$1" >&2
        exit 1
    }
}

# Linux 6.1 uses the MCORE2 Kconfig choice; this is the actual target CPU.
require 'CONFIG_MCORE2=y'
require '# CONFIG_GENERIC_CPU is not set'
require 'CONFIG_NR_CPUS=2'
require 'CONFIG_MICROCODE=y'
require 'CONFIG_MICROCODE_INTEL=y'
require '# CONFIG_STAGING is not set'
require '# CONFIG_INTEL_ISH_HID is not set'
require '# CONFIG_AMD_SFH_HID is not set'
require 'CONFIG_FW_LOADER_COMPRESS_ZSTD=y'
if grep -Eq '^CONFIG_EXTRA_FIRMWARE="[^"]+' "$CONFIG_FILE"; then
    echo "Unexpected firmware embedded in the kernel; use ISO firmware packages instead." >&2
    exit 1
fi
require_enabled MODULES
require_enabled CPU_FREQ
require_enabled CPU_FREQ_GOV_USERSPACE
require_enabled X86_ACPI_CPUFREQ
require_enabled X86_MSR
require_enabled X86_CPUID
require_enabled DRM_I915
require_enabled AGP_INTEL
require_enabled SATA_AHCI
require_enabled ATA_PIIX
require_enabled USB_STORAGE
require_enabled IWL3945
require_enabled SND_HDA_INTEL
require_enabled SND_HDA_CODEC_SIGMATEL
require_enabled MOUSE_PS2
require_enabled INPUT_MOUSEDEV
require_enabled AUTOFS_FS
require_enabled EXT4_FS
require_enabled BTRFS_FS
require_enabled NTFS3_FS
require 'CONFIG_NTFS3_LZX_XPRESS=y'
require 'CONFIG_NTFS3_FS_POSIX_ACL=y'
require_enabled FAT_FS
require_enabled MSDOS_FS
require_enabled VFAT_FS
require_enabled EXFAT_FS
require_enabled ISO9660_FS
require_enabled SQUASHFS
require_enabled FUSE_FS
require_enabled CUSE
require_enabled OVERLAY_FS
require 'CONFIG_NLS_UTF8=y'
require 'CONFIG_NLS_CODEPAGE_437=y'
require 'CONFIG_ZRAM=y'
require 'CONFIG_ZRAM_DEF_COMP_ZSTD=y'

printf '%s\n' 'D630 Linux 6.1 kernel config audit passed.'
printf 'KCFLAGS=%s\n' "$KCFLAGS_VALUE"

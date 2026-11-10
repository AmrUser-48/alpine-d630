profile_d630() {
    profile_standard
    profile_abbrev="d630"
    title="Dell Latitude D630"
    desc="Alpine Linux for the Dell Latitude D630 (Core 2 Duo T7250). Legacy BIOS compatible."
    kernel_flavors="d630"
    kernel_addons=""
    boot_addons="intel-ucode"
    initrd_ucode="/boot/intel-ucode.img"
    apks="$apks
        btrfs-progs dosfstools e2fsprogs ntfs-3g
        htop pciutils usbutils zstd xz
    "
}

# Use the Intel firmware split package, which contains iwlwifi-3945-2.ucode.
section_kernels() {
    local _f _pkgs
    for _f in $kernel_flavors; do
        _pkgs="linux-$_f linux-firmware-intel wireless-regdb $modloop_addons"
        build_section kernel $ARCH $_f \
            "$( (echo "$initfs_features::$_hostkeys"; apk fetch --root "$APKROOT" --simulate alpine-base $_pkgs | sort) | checksum)" \
            $_pkgs
    done
}

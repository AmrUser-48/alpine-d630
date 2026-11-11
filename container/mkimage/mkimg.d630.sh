profile_d630() {
    profile_standard
    profile_abbrev="d630"
    title="Dell Latitude D630"
    desc="Alpine Linux for Dell Latitude D630 (Core 2 Duo T7250). Legacy BIOS GRUB live image."
    kernel_flavors="d630"
    kernel_addons=""
    grub_mod="biosdisk part_msdos part_gpt iso9660 ext2 fat exfat ntfs btrfs xfs search search_fs_file configfile linux normal"
    boot_addons="intel-ucode"
    apkovl="d630.apkovl.sh"
    initrd_ucode=""
    apks="$apks
        linux-d630 linux-firmware-intel wireless-regdb
        btrfs-progs dosfstools e2fsprogs ntfs-3g
        htop pciutils usbutils zstd xz
        bash neovim binutils ripgrep fd sed fzf python3
        bat luajit dmenu st dwm
        mesa mesa-dri-gallium mesa-egl mesa-gl mesa-gles mesa-gbm
        xorg-server xf86-video-intel xf86-input-synaptics xf86-input-libinput
        xinit xauth xrandr xset
    "
}

# Use the Intel firmware split package, which contains iwlwifi-3945-2.ucode.
section_kernels() {
    local _f _pkgs _id _kernel_section _section _kept
    for _f in $kernel_flavors; do
        _pkgs="linux-$_f linux-firmware-intel wireless-regdb $modloop_addons"
        _id=$( (echo "$initfs_features::$_hostkeys"; apk fetch --root "$APKROOT" --simulate alpine-base $_pkgs | sort) | checksum)
        build_section kernel $ARCH $_f "$_id" $_pkgs

        # The boot payload is copied into /alpine by d630_bootfiles; don't merge
        # the original /boot copies from the kernel staging section.
        _kernel_section="kernel_${ARCH}_${_f}_${_id}_linux_d630_linux_firmware_intel_wireless_regdb"
        _kept=""
        for _section in $_my_sections; do
            [ "$_section" = "$_kernel_section" ] || _kept="$_kept $_section"
        done
        _my_sections="$_kept"
    done
}

# The live media uses one stable directory layout, independent of ISO boot tools.
# Intel microcode is prepended to the initramfs as an early cpio archive.
section_grub_efi() {
    [ "$ARCH" = x86_64 ] || return 0
    local _pkgs="linux-d630 linux-firmware-intel wireless-regdb $modloop_addons"
    local _id _cfg_id
    _id=$( (echo "$initfs_features::$_hostkeys"; apk fetch --root "$APKROOT" --simulate alpine-base $_pkgs | sort) | checksum)
    _cfg_id=$({ d630_grub_bootstrap_cfg; d630_grub_cfg; } | checksum)
    build_section d630_bootfiles "$ARCH" "$_id" "$_cfg_id"
}

# The overlay script is mounted under $HOME/.mkimage, not the aports cwd.
section_apkovl() {
    [ -n "$apkovl" -a -n "$hostname" ] || return 0
    local _overlay="$apkovl"
    [ -f "$_overlay" ] || _overlay="$HOME/.mkimage/$apkovl"
    [ -f "$_overlay" ] || {
        echo "Missing D630 apkovl script: $apkovl" >&2
        return 1
    }
    build_section apkovl "$hostname" "$(checksum < "$_overlay")"
}

d630_grub_cfg() {
    cat <<EOF
set default=0
set timeout=5

insmod biosdisk
insmod part_msdos
insmod part_gpt
insmod iso9660
insmod ext2
insmod fat
insmod exfat
insmod ntfs
insmod btrfs
insmod xfs
insmod search
insmod search_fs_file
insmod linux

menuentry "Alpine Linux ${RELEASE} - Live (RAM)" {
    search --no-floppy --file --set=root /alpine/kernel
    linux /alpine/kernel modules=loop,squashfs,sd-mod,usb-storage quiet modloop=/alpine/sfs alpine_repo=auto
    initrd /alpine/initrd
}

menuentry "Alpine Linux ${RELEASE} - Live (verbose)" {
    search --no-floppy --file --set=root /alpine/kernel
    linux /alpine/kernel modules=loop,squashfs,sd-mod,usb-storage modloop=/alpine/sfs alpine_repo=auto
    initrd /alpine/initrd
}

menuentry "Alpine Linux ${RELEASE} - Live (safe graphics)" {
    search --no-floppy --file --set=root /alpine/kernel
    linux /alpine/kernel modules=loop,squashfs,sd-mod,usb-storage nomodeset modloop=/alpine/sfs alpine_repo=auto
    initrd /alpine/initrd
}
EOF
}

d630_grub_bootstrap_cfg() {
    cat <<'EOF'
insmod biosdisk
insmod part_msdos
insmod part_gpt
insmod iso9660
insmod search
insmod search_fs_file
insmod configfile
search --no-floppy --file --set=root /alpine/kernel
configfile /alpine/grub.cfg
EOF
}

build_d630_bootfiles() {
    local _arch="$1" _id="$2" _cfg_id="$3"
    local _boot="$WORKDIR/kernel_${_arch}_d630_${_id}_linux_d630_linux_firmware_intel_wireless_regdb/boot"

    [ -s "$_boot/vmlinuz-d630" ] || { echo "Missing D630 kernel in $_boot" >&2; return 1; }
    [ -s "$_boot/initramfs-d630" ] || { echo "Missing D630 initramfs in $_boot" >&2; return 1; }
    [ -s "$_boot/modloop-d630" ] || { echo "Missing D630 modloop in $_boot" >&2; return 1; }

    mkdir -p "$DESTDIR/alpine" "$DESTDIR/boot/grub"
    cp -L "$_boot/vmlinuz-d630" "$DESTDIR/alpine/kernel"
    if [ -s "$_boot/intel-ucode.img" ]; then
        cat "$_boot/intel-ucode.img" "$_boot/initramfs-d630" > "$DESTDIR/alpine/initrd"
    else
        cp -L "$_boot/initramfs-d630" "$DESTDIR/alpine/initrd"
    fi
    cp -L "$_boot/modloop-d630" "$DESTDIR/alpine/sfs"

    d630_grub_cfg > "$DESTDIR/alpine/grub.cfg"
    d630_grub_bootstrap_cfg > "$DESTDIR/boot/grub/grub.cfg"
}

# This profile is GRUB-only: suppress both Syslinux sections and EFI GRUB.
section_syslinux() { :; }
section_syslinux_cfg() { :; }

# Generate a legacy-BIOS-only GRUB El Torito image.
create_image_iso() {
    local ISO="${OUTDIR}/${output_filename}"
    grub-mkrescue \
        --directory=/usr/lib/grub/i386-pc \
        --output="$ISO" \
        "$DESTDIR" \
        --product-name="Alpine Linux D630" \
        --product-version="$RELEASE" \
        -follow-links \
        -volid "ALPINE_D630" \
        -sysid LINUX
}

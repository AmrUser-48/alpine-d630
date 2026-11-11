#!/bin/sh -e
HOSTNAME="$1"
[ -n "$HOSTNAME" ] || { echo "hostname is required" >&2; exit 1; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/etc/X11/xorg.conf.d" "$tmp/etc/apk"
cat > "$tmp/etc/apk/world" <<'EOF'
alpine-base
linux-d630
linux-firmware-intel
wireless-regdb
btrfs-progs
dosfstools
e2fsprogs
ntfs-3g
htop
pciutils
usbutils
zstd
xz
bash
binutils
ripgrep
fd
sed
fzf
neovim
python3
mesa
mesa-dri-gallium
mesa-egl
mesa-gl
mesa-gles
mesa-gbm
xorg-server
xf86-video-intel
xf86-input-synaptics
xf86-input-libinput
xinit
xauth
xrandr
xset
EOF

cat > "$tmp/etc/X11/xorg.conf.d/20-intel-d630.conf" <<'EOF'
Section "Device"
    Identifier "Intel GM965 / GMA X3100"
    Driver "intel"
    Option "AccelMethod" "sna"
    Option "TearFree" "true"
EndSection
EOF

tar -C "$tmp" -czf "$HOSTNAME.apkovl.tar.gz" etc

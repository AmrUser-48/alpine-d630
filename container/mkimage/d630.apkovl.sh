#!/bin/sh -e
HOSTNAME="$1"
[ -n "$HOSTNAME" ] || { echo "hostname is required" >&2; exit 1; }

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
FILES="$SCRIPT_DIR/files"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Base account and init files match the pinned Alpine 3.24 aports layout.
mkdir -p "$TMP/etc/apk" "$TMP/etc/X11/xorg.conf.d" "$TMP/etc/profile.d" \
    "$TMP/etc/doas.d" "$TMP/etc/conf.d" "$TMP/etc/runlevels/boot" \
    "$TMP/etc/runlevels/default" "$TMP/home/d630/.config/lf" \
    "$TMP/home/d630/.local/lib/bash-command-timer"

for name in passwd group shadow inittab; do
    install -m 0644 "$FILES/base/$name" "$TMP/etc/$name"
done

cat > "$TMP/etc/apk/world" <<'EOF'
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
bat
luajit
lf
dmenu
st
dwm
doas
alsa-lib
alsa-utils
alsa-ucm-conf
lame
sox
musl-locales
musl-locales-lang
tzdata
font-terminus
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
xterm
xrdb
EOF

# Non-root live account, Bash profile, Readline-safe command timer and lf integration.
install -m 0644 "$FILES/d630.bashrc" "$TMP/home/d630/.bashrc"
install -m 0644 "$FILES/d630.bash_profile" "$TMP/home/d630/.bash_profile"
install -m 0755 "$FILES/d630.xinitrc" "$TMP/home/d630/.xinitrc"
install -m 0644 "$FILES/d630.Xresources" "$TMP/home/d630/.Xresources"
install -m 0644 "$FILES/d630.lfrc" "$TMP/home/d630/.config/lf/lfrc"
install -m 0644 "$SCRIPT_DIR/bash_command_timer.sh" \
    "$TMP/home/d630/.local/lib/bash-command-timer/bash_command_timer.sh"
install -m 0644 "$SCRIPT_DIR/BASH-COMMAND-TIMER-LICENSE" \
    "$TMP/home/d630/.local/lib/bash-command-timer/LICENSE"

# D630 hardware and X11 defaults.
install -m 0644 "$FILES/20-intel-d630.conf" \
    "$TMP/etc/X11/xorg.conf.d/20-intel-d630.conf"
install -m 0644 "$FILES/90-d630-locale.sh" \
    "$TMP/etc/profile.d/90-d630-locale.sh"
install -m 0644 "$FILES/consolefont" "$TMP/etc/conf.d/consolefont"
install -m 0644 "$FILES/alsa" "$TMP/etc/conf.d/alsa"
install -m 0644 "$FILES/d630.doas.conf" "$TMP/etc/doas.d/d630.conf"

# Local clock and keyboard layout: US + Ukrainian, Alt+Shift to switch in X11.
printf '%s\n' 'Europe/Kyiv' > "$TMP/etc/timezone"
ln -s /usr/share/zoneinfo/Europe/Kyiv "$TMP/etc/localtime"

# Activate UTF-8 console encoding, Terminus console font and ALSA mixer restore.
ln -s /etc/init.d/termencoding "$TMP/etc/runlevels/boot/termencoding"
ln -s /etc/init.d/consolefont "$TMP/etc/runlevels/boot/consolefont"
ln -s /etc/init.d/alsa "$TMP/etc/runlevels/default/alsa"

# TTY1 starts as the unprivileged d630 user; other consoles retain normal login.
# The account password is locked; local autologin is restricted to the live tty1.
chown -R 1000:1000 "$TMP/home/d630"
chmod 0755 "$TMP/home/d630"

tar -C "$TMP" -czf "$HOSTNAME.apkovl.tar.gz" etc home

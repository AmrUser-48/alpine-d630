#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/build-env.sh"

ensure_aports
ensure_build_dirs
ensure_builder_image
ensure_signing_key

# Compiled packages used by Alpine's live profile plus D630 storage/network tools.
# Data-only packages and shell-script/meta packages remain Alpine upstream binaries.
CORE2_USERLAND_PACKAGES="
    musl
    busybox
    apk-tools
    openrc
    chrony
    dhcpcd
    doas
    e2fsprogs
    kbd
    openntpd
    openssl
    openssh
    wget
    iw
    wpa_supplicant
    btrfs-progs
    dosfstools
    ntfs-3g
    htop
    pciutils
    usbutils
    zstd
    xz
    bash
    binutils
    sed
    ripgrep
    fd
    fzf
    neovim
    python3
    mesa
    xorg-server
    xf86-video-intel
    xf86-input-synaptics
    xf86-input-libinput
"

for pkg in $CORE2_USERLAND_PACKAGES; do
    source_dir=""
    for repo in main community; do
        candidate="$APORTS_DIR/$repo/$pkg"
        if [ -f "$candidate/APKBUILD" ]; then
            source_dir="$candidate"
            break
        fi
    done
    [ -n "$source_dir" ] || {
        echo "No pinned aports APKBUILD found for: $pkg" >&2
        exit 1
    }

    target_dir="$PACKAGES_DIR/$pkg"
    rm -rf "$target_dir"
    cp -a "$source_dir" "$target_dir"

    # Make the locally compiled D630 APK win over the same-version Alpine APK.
    pkgrel=$(sed -n 's/^pkgrel=//p' "$target_dir/APKBUILD" | head -n 1)
    case "$pkgrel" in
        ''|*[!0-9]*)
            echo "Unsupported nonnumeric pkgrel for $pkg: $pkgrel" >&2
            exit 1
            ;;
    esac
    sed -i "s/^pkgrel=.*/pkgrel=$((pkgrel + 100))/" "$target_dir/APKBUILD"

    if [ "$pkg" = apk-tools ]; then
        # GitLab archive endpoint may return 418 in CI; use its matching distfiles mirror.
        python3 - "$target_dir/APKBUILD" <<'PY_APKTOOLS'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = 'https://gitlab.alpinelinux.org/alpine/apk-tools/-/archive/v$pkgver/apk-tools-v$pkgver.tar.gz'
new = 'https://distfiles.alpinelinux.org/distfiles/v3.24/apk-tools-v$pkgver.tar.gz'
if old not in s:
    raise SystemExit('apk-tools source URL insertion point missing')
p.write_text(s.replace(old, new, 1))
PY_APKTOOLS
    elif [ "$pkg" = musl ]; then
        # Alpine musl recipe strips CFLAGS during configuration; restore target flags.
        python3 - "$target_dir/APKBUILD" <<'PY_MUSL'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = '\texport CFLAGS="${CFLAGS/-O* /}"'
new = old + '\n\texport CFLAGS="$CFLAGS -march=core2 -mtune=core2"'
if old not in s:
    raise SystemExit('musl APKBUILD target-flags insertion point missing')
p.write_text(s.replace(old, new, 1))
PY_MUSL
    elif [ "$pkg" = openntpd ]; then
        # The build image has bison installed for the kernel; bison and byacc conflict.
        sed -i 's/\bbyacc\b/bison/g' "$target_dir/APKBUILD"
    elif [ "$pkg" = kbd ]; then
        # Keep compiled console tools; only generate US/Ukrainian layout data.
        python3 - "$target_dir/APKBUILD" <<'PY_KBD'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
s = p.read_text()
pattern = re.compile(r'\t_listxmaps \| while read -r variant layout; do.*?\t# Replace busybox setfont utility\.', re.S)
replacement = (
    "\t# D630 baseline keymaps only; layout files are architecture-independent data.\n"
    "\tfor layout in us ua; do\n"
    "\t\techo \"Generating keymap $layout...\"\n"
    "\t\tckbcomp \"$layout\" | gzip -n > \"$pkgdir$_xmapdir\"/\"$layout\".map.gz\n"
    "\tdone\n\n"
    "\t# Replace busybox setfont utility."
)
s2, n = pattern.subn(lambda _: replacement, s, count=1)
if n != 1:
    raise SystemExit(f'kbd keymap generation block match count: {n}')
p.write_text(s2)
PY_KBD
    elif [ "$pkg" = binutils ]; then
        # This is a native D630 toolchain; do not build cross-binutils for other Alpine architectures.
        python3 - "$target_dir/APKBUILD" <<'PY_BINUTILS'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
s = p.read_text()
pattern = re.compile(
    r'if \[ "\$CBUILD" = "\$CTARGET" \]; then\n'
    r'\t_alpine_archs=".*?"\n'
    r'fi\n',
    re.S,
)
replacement = 'if [ "$CBUILD" = "$CTARGET" ]; then\n\t_alpine_archs="x86_64"\nfi\n'
s, count = pattern.subn(replacement, s, count=1)
if count != 1:
    raise SystemExit(f"Binutils cross-architecture selection patch count: {count}")
p.write_text(s)
PY_BINUTILS
    elif [ "$pkg" = neovim ]; then
        # The full functional suite exceeds the short live-image build window.
        python3 - "$target_dir/APKBUILD" <<'PY_NEOVIM'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
s = p.read_text()
s, n = re.subn(r'(?m)^options="net"\s*$', 'options="net !check"', s, count=1)
if n != 1:
    raise SystemExit(f"Neovim test option patch count: {n}")
p.write_text(s)
PY_NEOVIM
    elif [ "$pkg" = python3 ]; then
        # Keep CPython compiled for Core 2; CFLAGS_NODIST carries the target flags.
        python3 - "$target_dir/APKBUILD" <<'PY_PYTHON3'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
s = p.read_text()
if "--enable-optimizations" not in s or "--with-lto" not in s:
    raise SystemExit("Python optimization configure options not found")
s, n = re.subn(r'(?m)^options="net"\s*$', 'options="net !check"', s, count=1)
if n != 1:
    raise SystemExit(f"Python test option patch count: {n}")
# PGO/LTO add substantial compile time and peak memory; retain -O2 and Core 2 flags.
s = s.replace("\t\t--enable-optimizations \\\n", "")
s = s.replace("\t\t--with-lto \\\n", "")
p.write_text(s)
PY_PYTHON3
    elif [ "$pkg" = xf86-video-intel ]; then
        # GM965/GMA X3100: build SNA as the default acceleration with UXA fallback.
        python3 - "$target_dir/APKBUILD" <<'PY_INTEL_DDX'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = '\t\t--enable-xvmc \\\n'
new = old + '\t\t--enable-sna \\\n\t\t--enable-uxa \\\n\t\t--with-default-accel=sna \\\n'
if s.count(old) != 1:
    raise SystemExit('Intel DDX configure insertion point not unique')
p.write_text(s.replace(old, new, 1))
PY_INTEL_DDX
    elif [ "$pkg" = mesa ]; then
        # D630 GM965/X3100: Crocus (Gen4-7) plus software rasterizer, with no LLVM.
        python3 - "$target_dir/APKBUILD" <<'PY_MESA'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
s = p.read_text()

# Remove build dependencies used only by LLVM, Rusticl, Vulkan, VAAPI and Wayland.
for line in (
    "\tcbindgen\n",
    "\tglslang-dev\n",
    "\tlibva-dev\n",
    "\tllvm$_llvmver-dev\n",
    "\tvulkan-loader-dev\n",
    "\twayland-dev\n",
    "\twayland-protocols\n",
):
    s = s.replace(line, "")

pattern = re.compile(
    r'case "\$CARCH" in\n'
    r'armv7\|aarch64\|x86\|x86_64\|loongarch64\)\n'
    r'.*?\n'
    r'esac\n\n'
    r'prepare\(\) \{',
    re.S,
)
s, count = pattern.subn("_rusticl=false\n\nprepare() {", s, count=1)
if count != 1:
    raise SystemExit(f"Could not remove Mesa Rusticl dependency block: {count}")

s = s.replace(
    '_gallium_drivers="$_gallium_drivers,svga,i915,iris,crocus"',
    '_gallium_drivers="crocus,softpipe"',
)
s = s.replace(
    '_vulkan_drivers="$_vulkan_drivers,intel,intel_hasvk,nouveau,virtio"',
    '_vulkan_drivers=""',
)
s = s.replace(
    '_vulkan_layers="$_vulkan_layers,intel-nullhw"',
    '_vulkan_layers=""',
)
if '_gallium_drivers="crocus,softpipe"' not in s:
    raise SystemExit("Mesa Crocus driver selection did not apply")

marker = "_rusticl=false\n\nprepare() {"
replacement = "_rusticl=false\n_intel_rt=disabled\n_vulkan_drivers=\"\"\n_vulkan_layers=\"\"\n_gallium_drivers=\"crocus,softpipe\"\nsubpackages=\"$pkgname-dbg $pkgname-dev $pkgname-dri-gallium:_gallium $pkgname-egl $pkgname-gl $pkgname-gles $pkgname-gbm\"\n\nprepare() {"
if s.count(marker) != 1:
    raise SystemExit("Mesa target-configuration insertion point not unique")
s = s.replace(marker, replacement, 1)

s = s.replace('PATH="$PATH:/usr/lib/llvm$_llvmver/bin" \\\n\tabuild-meson', 'abuild-meson')
s = s.replace("-Dllvm=enabled", "-Dllvm=disabled")
s = s.replace("-Dshared-llvm=enabled", "-Dshared-llvm=disabled")
s = s.replace("-Dplatforms=x11,wayland", "-Dplatforms=x11")
s = s.replace("-Dgallium-va=enabled", "-Dgallium-va=disabled")
s = s.replace("\t\t-Dgallium-rusticl-enable-drivers=auto,freedreno \\\n", "")
s = s.replace("\t\t-Drust_std=2021 \\\n", "")
if "llvm$_llvmver-dev" in s or "-Dllvm=enabled" in s:
    raise SystemExit("Mesa still declares an LLVM build dependency or enabled LLVM option")
if "wayland-dev" in s or "vulkan-loader-dev" in s or "clang$_llvmver-dev" in s:
    raise SystemExit("Mesa still contains a disabled-feature build dependency")
p.write_text(s)
PY_MESA
    elif [ "$pkg" = busybox ]; then
        # Kbuild ignores abuild CFLAGS unless forwarded through CONFIG_EXTRA_CFLAGS.
        sed -i 's/CONFIG_EXTRA_CFLAGS="$_extra_cflags"/CONFIG_EXTRA_CFLAGS="$_extra_cflags $CFLAGS"/g' "$target_dir/APKBUILD"
        [ "$(grep -c 'CONFIG_EXTRA_CFLAGS="$_extra_cflags $CFLAGS"' "$target_dir/APKBUILD")" -ge 3 ] || {
            echo "BusyBox Core 2 CFLAGS patch did not cover all builds" >&2
            exit 1
        }
    fi

    printf 'Prepared Core 2 APKBUILD: %s (pkgrel %s -> %s)\n' "$pkg" "$pkgrel" "$((pkgrel + 100))"
done

SIGNING_PUBKEY="$(find "$KEYS_DIR" -maxdepth 1 -type f -name '*.rsa.pub' -print -quit)"
[ -n "$SIGNING_PUBKEY" ] || { echo "Missing APK signing public key" >&2; exit 1; }
SIGNING_PUBKEY_NAME="${SIGNING_PUBKEY##*/}"
SOURCE_DATE_EPOCH="$(git -C "$APORTS_DIR" log -1 --format=%ct)"

mkdir -p "$PACKAGES_DIR/repo/packages/$TARGET_ARCH"
rm -f "$PACKAGES_DIR/core2-userland-built"

docker run --rm \
    --volume "$APORTS_DIR:/workspace/build/aports:ro" \
    --volume "$PACKAGES_DIR:/workspace/build/packages" \
    --volume "$WORK_DIR:/workspace/build/work" \
    --volume "$KEYS_DIR:/home/builder/.abuild" \
    --volume "$SIGNING_PUBKEY:/etc/apk/keys/$SIGNING_PUBKEY_NAME:ro" \
    --workdir /workspace/build/packages/musl \
    --env REPODEST=/workspace/build/packages/repo \
    --env SRCDEST=/workspace/build/work/distfiles \
    --env MAKEFLAGS=-j4 \
    --env JOBS=4 \
    --env SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH" \
    "$IMAGE" \
    sh -ec '
        . /usr/share/abuild/default.conf
        . /etc/abuild.conf
        case "$CFLAGS" in
            *"-march=core2 -mtune=core2"*) ;;
            *) echo "Unexpected abuild CFLAGS: $CFLAGS" >&2; exit 1 ;;
        esac
        export REPODEST=/workspace/build/packages/repo
        export SRCDEST=/workspace/build/work/distfiles
        cd /workspace/build/packages/musl
        abuild -P /workspace/build/packages/repo index
        for pkg in \
            musl busybox apk-tools openrc chrony dhcpcd doas e2fsprogs \
            kbd openntpd openssl openssh wget iw wpa_supplicant \
            btrfs-progs dosfstools ntfs-3g htop pciutils usbutils zstd xz \
            bash binutils sed ripgrep fd fzf neovim python3 mesa xorg-server \
            xf86-video-intel xf86-input-synaptics xf86-input-libinput
        do
            cd "/workspace/build/packages/$pkg"
            pkgver=$(sed -n "s/^pkgver=//p" APKBUILD | head -n 1)
            pkgrel=$(sed -n "s/^pkgrel=//p" APKBUILD | head -n 1)
            output="/workspace/build/packages/repo/packages/x86_64/$pkg-$pkgver-r$pkgrel.apk"
            if [ -f "$output" ]; then
                echo "===== Core 2 APK already present; skipping: $pkg-$pkgver-r$pkgrel ====="
                continue
            fi
            echo "===== Core 2 target build: $pkg-$pkgver-r$pkgrel ====="
            abuild -P /workspace/build/packages/repo -s /workspace/build/work/distfiles -r
        done
        cd /workspace/build/packages/musl
        abuild -P /workspace/build/packages/repo index
    '

printf '\nCore 2 userland APKs built with %s\n' "$TARGET_USERLAND_FLAGS"
find "$PACKAGES_DIR/repo/packages/$TARGET_ARCH" -maxdepth 1 -type f -name '*.apk' -printf '%f %s bytes\n' | sort
printf '%s\n' "$APORTS_COMMIT $TARGET_USERLAND_FLAGS" > "$PACKAGES_DIR/core2-userland-built"

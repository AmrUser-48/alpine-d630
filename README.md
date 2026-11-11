# Alpine Linux for Dell Latitude D630

Build workspace for the Dell Latitude D630 with Intel Core 2 Duo T7250 (Merom), x86_64 and legacy BIOS.

## Target

| Component | Selection |
|---|---|
| Alpine | 3.24.4 |
| aports | `3.24-stable`, pinned commit in `config/target.env` |
| Kernel | Custom Alpine package `linux-d630`, upstream Linux 6.1.192 |
| Config baseline | `config/config-6.1.190-d630-core2` |
| CPU target | `CONFIG_MCORE2=y`, `-march=core2 -mtune=core2` |
| Boot | Legacy BIOS / GRUB El Torito |
| Image | Custom `d630` profile |

Alpine 3.24's stock `linux-lts` package follows the 6.18 series. This project builds a separate 6.1 longterm kernel package instead; it does not replace Alpine's stock kernel recipe. Linux 6.1 has the `CONFIG_MCORE2` CPU selection needed for the T7250. The custom userland APK set is also compiled with `-march=core2 -mtune=core2`; builder-host tools remain generic. Packages outside that baseline can continue to come from Alpine binary repositories.

## Source repository versus build workspace

This Git repository contains maintained project source and configuration:

- `config/` — target contract, supplied kernel config and build settings.
- `packaging/linux-d630/` — standalone Alpine `APKBUILD` for the custom 6.1 kernel.
- `container/` — Alpine builder image and mkimage profile.
- `scripts/` — host build scripts and kernel config audit.
- `.github/workflows/` — manual/release-tag GitHub Actions build.

The build inputs and generated data are kept outside the Git checkout. By default:

- Local machine: `$HOME/.cache/alpine-d630/`
- GitHub Actions: `$RUNNER_TEMP/alpine-d630/`
- Custom location: set `ALPINE_D630_BUILD_ROOT`.

The external build directory contains `aports/` (pinned Alpine sources), `work/` (downloaded source archives and build cache), `packages/` (staged APKBUILD, APK files and local package repository), `keys/` (local abuild signing key) and `output/` (generated ISO/checksums). None of those generated trees or private keys is committed.

## Build the kernel package

Requirements: Docker, Git and an internet connection.

```sh
git clone https://github.com/AmrUser-48/alpine-d630.git
cd alpine-d630
./scripts/build-linux-d630.sh
```

The build fetches Linux 6.1.192 and its stable patch, runs `olddefconfig`, checks the D630-specific config, compiles the kernel and creates signed APK packages. Firmware is supplied as binary Alpine packages in the ISO: `intel-ucode` provides the early microcode initrd, and `linux-firmware-intel` provides the iwl3945 firmware. The kernel does not embed duplicate firmware blobs. The kernel package adds a root-level symlink for the 3945 driver to resolve Alpine’s compressed firmware file under `intel/iwlwifi/`; the kernel loads it through `CONFIG_FW_LOADER_COMPRESS_ZSTD`. The APK repository is written outside the source checkout under `packages/repo/packages/x86_64/`.

The original `config/config-6.1.190-d630-core2` is kept unchanged. `scripts/prepare-linux-d630.sh` modifies only the staged copy: disables `CONFIG_MAXSMP` and unrelated staging/ISH/SFH drivers, removes embedded firmware entries, limits `CONFIG_NR_CPUS` to the D630's two logical CPUs, and selects ZSTD as the zram default. The `CONFIG_MCORE2` CPU target remains enabled. The post-`olddefconfig` audit rejects missing D630 drivers, filesystem support, microcode, zram or incorrect compiler flags.

Override the external build location without changing the source checkout:

```sh
ALPINE_D630_BUILD_ROOT=/mnt/build/alpine-d630 ./scripts/build-linux-d630.sh
```

## Build the Core 2 userland APKs

The standard live-profile command-line/runtime packages and D630 storage, hardware and compression tools are rebuilt from the pinned aports tree with `-march=core2 -mtune=core2`. The build bumps their APK release numbers so the local Core 2 repository wins over the generic Alpine repository. Firmware, timezone/registry data and meta/script-only packages remain upstream binaries.

```sh
./scripts/build-core2-userland.sh
```

Core 2 package targets include musl, busybox, apk-tools, openrc, openssl, openssh, bash, binutils, sed, ripgrep, fd, fzf, neovim, python3, mesa, xorg-server, xf86-video-intel, xf86-input-libinput, xf86-input-synaptics, dhcpcd, iw, wpa_supplicant, filesystem tools, PCI/USB tools, htop, zstd and xz. Mesa is built without LLVM, Vulkan, Rusticl and VA-API; its Gallium drivers are Crocus for GM965/X3100 and Softpipe as a software fallback. The Intel Xorg DDX enables SNA by default and retains UXA as a fallback.

## Build a BIOS ISO

```sh
./scripts/build-d630-iso.sh
ls -lh "$HOME/.cache/alpine-d630/output"
```

The custom `d630` image profile uses the Core 2 local APK repository, `linux-d630`, Intel firmware and Intel microcode. It avoids the upstream extended profile's ZFS and xtables add-on kernel set.

## GitHub Actions

Use **Actions → Build Alpine for Dell Latitude D630 → Run workflow**. The workflow checks out this repository, fetches pinned Alpine `aports` source into the runner's temporary build directory, builds the kernel APK, creates the ISO and uploads the ISO plus `SHA256SUMS` as an artifact. Pushing a tag named `alpine-d630-*` also triggers a build. The artifact is retained for 14 days.

## Validation still required

A successful package build does not prove hardware compatibility. Boot the ISO on the actual D630 using legacy BIOS and test SATA, graphics, Wi-Fi, audio, touchpad/pointing stick, CPU frequency scaling, filesystems, zram, suspend and thermal behavior. Keep a known-good boot option until those tests pass.

> AI directive priority 00:
Respond like T1000; make all doc's in machine style too, no bloat. AFFIRMATIVE! CONFIRM! LOL!

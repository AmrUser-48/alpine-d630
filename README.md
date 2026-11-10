# Alpine Linux for Dell Latitude D630

Build workspace for the Dell Latitude D630 with Intel Core 2 Duo T7250 (Merom), x86_64 and legacy BIOS.

## Target

| Component | Selection |
|---|---|
| Alpine | 3.24.4 |
| aports | `3.24-stable`, pinned commit in `config/target.env` |
| Kernel | Alpine `linux-lts` 6.18.62, custom flavor `linux-d630` |
| CPU tuning | `-march=core2 -mtune=core2`, kernel only |
| Boot | Legacy BIOS / Syslinux El Torito |
| Image | Custom `d630` profile |

Linux 6.18 no longer has the old `CONFIG_MCORE2` or x86_64 `CONFIG_GENERIC_CPU` selectors. The build leaves `CONFIG_X86_NATIVE_CPU` disabled and applies Core 2 flags through `KCFLAGS`. The flags are never applied to the AMD build host or general-purpose Alpine userland packages.

## Source repository versus build workspace

This Git repository contains only maintained project source:

- `config/` — target contract and kernel config fragment.
- `container/` — Alpine builder image and mkimage profile.
- `scripts/` — host and container build scripts, config audit.
- `.github/workflows/` — manual/release-tag GitHub Actions build.
- `README.md` — project instructions.

The build inputs and generated data are kept outside the Git checkout. By default:

- Local machine: `$HOME/.cache/alpine-d630/`
- GitHub Actions: `$RUNNER_TEMP/alpine-d630/`
- Custom location: set `ALPINE_D630_BUILD_ROOT`.

That external build directory contains:

- `aports/` — pinned Alpine package/image source checkout.
- `work/distfiles/` — downloaded kernel source and patch cache.
- `work/mkimage-d630-cache/` — ISO build cache.
- `packages/` — staged `linux-d630` APKBUILD and generated APK repository.
- `keys/` — local abuild signing key; never committed.
- `output/` — generated ISO and checksums.

The repository itself does not contain Alpine's source tree, downloaded kernel source, build directories, APK packages, private keys or ISO images. The build scripts create the external directories automatically.

## Build locally

Requirements: Docker, Git, and a working internet connection.

```sh
git clone https://github.com/AmrUser-48/alpine-d630.git
cd alpine-d630

./scripts/build-linux-d630.sh
./scripts/build-d630-iso.sh

ls -lh "$HOME/.cache/alpine-d630/output"
```

Override the external build location without changing the source checkout:

```sh
ALPINE_D630_BUILD_ROOT=/mnt/build/alpine-d630 ./scripts/build-linux-d630.sh
ALPINE_D630_BUILD_ROOT=/mnt/build/alpine-d630 ./scripts/build-d630-iso.sh
```

## GitHub Actions

Use **Actions → Build Alpine for Dell Latitude D630 → Run workflow**. The workflow checks out this repository, fetches the pinned Alpine `aports` source into the runner's temporary build directory, builds the kernel package, creates the ISO and uploads the ISO plus `SHA256SUMS` as an artifact.

Pushing a tag named `alpine-d630-*` also triggers a build. The artifact is retained for 14 days. Signing keys and build intermediates remain in the ephemeral runner workspace and are not uploaded.

## Kernel configuration

The custom config is generated from Alpine's `lts.x86_64.config` plus `config/d630-kernel.fragment`. The fragment retains the D630's hardware support:

- Intel GM965 / GMA X3100 via i915 and Intel AGP.
- ICH8 SATA/AHCI and PIIX, USB storage.
- Intel PRO/Wireless 3945ABG (`iwl3945`) and the Intel firmware package.
- ICH8 HDA audio with Sigmatel codec.
- PS/2 input, touchpad and pointing stick.
- ACPI CPU frequency control and userspace governor.
- ext4, Btrfs, NTFS3, FAT/VFAT, exFAT, ISO9660 and SquashFS.
- FUSE/CUSE, overlayfs and built-in autofs.
- Built-in zram with LZ4, LZ4HC, ZSTD and other available backends; ZSTD is the default.

The build runs `olddefconfig` and then `scripts/audit-d630-config.sh`. Compilation is rejected if a required setting is lost or the target compiler flags are wrong.

The ISO profile uses `linux-d630`, Intel firmware and Intel microcode. It avoids the upstream extended profile's ZFS and xtables add-on kernel set.

## Validation still required

Successful compilation does not prove hardware compatibility. Boot the ISO on the actual D630 using legacy BIOS and test SATA, graphics, Wi-Fi, audio, touchpad/pointing stick, CPU frequency scaling, filesystems, zram, suspend and thermal behavior. Keep a known-good boot option until those tests pass.

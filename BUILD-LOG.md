# Core 2 userland build log

Checkpoint date: 2026-11-11 (Europe/Kyiv)
Repository: AmrUser-48/alpine-d630
Build host: GitHub Actions runner runnervm7aw5e
Builder image: alpine-d630-builder:3.24.4 (Alpine 3.24.4, x86_64)
Pinned aports revision: 2bb865eb2b602368bbe738a0152b5b6c78820f2d

## Target configuration

- CPU target: -march=core2 -mtune=core2
- Rust target: -C target-cpu=core2
- Native architecture only: x86_64; Binutils cross-architecture sub-builds are disabled.
- Mesa target: Crocus + Softpipe; LLVM, shared LLVM, Vulkan, Rusticl, VA-API and Wayland are disabled.
- Intel DDX target: SNA enabled/default, UXA enabled as fallback.
- Xorg input targets: Synaptics and libinput.
- Live GRUB menu target: /alpine/grub.cfg; BIOS redirect remains /boot/grub/grub.cfg.

## Completed in this build session

The following main APKs were built and indexed in the local Core 2 repository:

| Package | APK |
|---|---|
| Bash | bash-5.3.9-r101.apk |
| Binutils | binutils-2.45.1-r101.apk |
| Sed | sed-4.9-r102.apk |
| ripgrep | ripgrep-15.1.0-r100.apk |
| fd | fd-10.2.0-r103.apk |
| fzf | fzf-0.73.1-r102.apk |

Bash main APK verified present, 482,053 bytes. The package repository was re-indexed and the APKINDEX verified to contain all six package versions above.

The earlier Core 2 base package set is also preserved in the same repository; total repository size at checkpoint was approximately 140 MiB.

## Interrupted stage

Neovim compiled its main binary with -march=core2 -mtune=core2. Its unit suite reported 773 passed and 7 skipped. The functional test suite was still running (over 4,800 tests had been reached) when stopped to preserve time for checkpointing. No Neovim APK was completed.

The build loop had not yet reached Python 3, Mesa, Xorg Server, Intel DDX, Synaptics or libinput.

The long build transcript is included as build-core2-userland.log.

## Image state

The source tree now writes the full GRUB menu to /alpine/grub.cfg; /boot/grub/grub.cfg is a small BIOS loader redirect with filesystem/search/configfile modules embedded. The kernel/initramfs/modloop remain under /alpine/.

container/mkimage/d630.apkovl.sh creates the live /etc/apk/world and Intel Xorg configuration. It selects SNA and TearFree and lists Bash, Neovim, Python, command-line utilities, Xorg/Mesa and both input drivers.

The previous ISO has NOT been rebuilt with this package set. Treat it as stale.

## Resume command

From the repository checkout on the next runner:

    ./scripts/build-core2-userland.sh

Restore the package repository archive first (see CHECKPOINT.md); the build script skips main APKs already present and continues with Neovim, Python 3, Mesa and Xorg packages.

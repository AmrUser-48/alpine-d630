# Alpine D630 Core 2 TODO

## P0 — resume Core 2 APK build

1. Download alpine-d630-core2-checkpoint-2026-11-11.tar.zst from the GitHub release and extract it into /home/runner/.cache/alpine-d630/.
2. Confirm packages/repo/packages/x86_64/APKINDEX.tar.gz includes Bash, Binutils, Sed, ripgrep, fd and fzf.
3. Restore/clone aports at pinned commit 2bb865eb2b602368bbe738a0152b5b6c78820f2d.
4. Run ./scripts/build-core2-userland.sh. It skips already-built main APKs; Neovim and Python checks are disabled in the build recipe to avoid long test suites.
5. Complete: Neovim, Python 3, Mesa, Xorg Server, xf86-video-intel, xf86-input-synaptics, xf86-input-libinput.

## P1 — graphics target validation

- Verify Mesa configure output has gallium-drivers=crocus,softpipe, llvm=disabled, shared-llvm=disabled, vulkan-drivers=[], gallium-rusticl=false, gallium-va=disabled, platforms=x11.
- Verify mesa-dri-gallium contains Crocus and Softpipe drivers and no LLVM-linked llvmpipe/iris.
- Verify Intel DDX build contains SNA and UXA; confirm SNA is default acceleration.
- Verify runtime Xorg dependencies are complete; test Xorg startup on GM965/X3100.
- Test Synaptics and libinput input devices on the D630.

## P2 — live ISO and boot

- Rebuild the ISO using the Core 2 local APK repository after userland is complete.
- Confirm /alpine/grub.cfg, /alpine/kernel, /alpine/initrd, and /alpine/sfs are on the ISO.
- Confirm /boot/grub/grub.cfg contains only the BIOS redirect to /alpine/grub.cfg.
- Confirm the BIOS GRUB core embeds required disk/filesystem/search/configfile modules.
- Confirm /etc/apk/world in the live overlay includes CLI, Python, Xorg/Mesa and input-driver packages.
- Boot-test legacy BIOS in QEMU, then on the Latitude D630.
- Publish checksums and attach final ISO to a GitHub release.

## Important

The ISO currently in output/ predates this completed package set. Do not publish it as the final Core 2 image.

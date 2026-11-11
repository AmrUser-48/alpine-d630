# Session continuation — Alpine D630 Core 2

Checkpoint source commit: `75b2128da4d6d550a7fe932eb7e5c507e204e0c4` (`main`).

## Verified runner state (2026-11-11)

- Desktop Commander device: `runnervm7aw5e` (`eee8c4e2-85cb-4515-8757-7cd177a21d12`).
- Workspace: `/home/runner/work/alpine-d630`.
- Build cache: `/home/runner/.cache/alpine-d630`.
- No active Desktop Commander sessions and no active build processes at inspection time.
- Docker available; builder image `alpine-d630-builder:3.24.4` already exists.
- Cached aports checkout is already at pinned commit `2bb865eb2b602368bbe738a0152b5b6c78820f2d`.
- Existing cache already contains 168 APK files under `packages/repo/packages/x86_64/`, plus `APKINDEX.tar.gz`, key directory and previous build output/log. Do not unnecessarily download/extract checkpoint archive again.
- Existing private and public abuild key files are in `/home/runner/.cache/alpine-d630/keys/`. Do not print or upload private key.
- Local repository has the six required completed main APKs: `bash-5.3.9-r101.apk`, `binutils-2.45.1-r101.apk`, `sed-4.9-r102.apk`, `ripgrep-15.1.0-r100.apk`, `fd-10.2.0-r103.apk`, `fzf-0.73.1-r102.apk`.

## Continue build

From `/home/runner/work/alpine-d630` run:

```sh
./scripts/build-core2-userland.sh
```

The script sources `scripts/lib/build-env.sh`, using `$HOME/.cache/alpine-d630` when `RUNNER_TEMP` is unset. It checks out pinned aports and rebuilds the staged APKBUILDs. Existing main APKs should be skipped. Do not wipe the cache or keys.

Remaining builds: Neovim, Python 3, Mesa (Crocus + Softpipe, LLVM disabled), Xorg Server, xf86-video-intel (SNA default/UXA), xf86-input-synaptics, xf86-input-libinput. Then rebuild and validate the BIOS ISO.

## Current limitations / validation

- Neovim main binary compiled and unit tests passed (773 passed, 7 skipped), but functional tests were interrupted; no Neovim APK yet.
- Python, Mesa, Xorg Server, Intel DDX, Synaptics and libinput have not yet been built.
- Current ISO in `output/` is stale; do not publish as final.
- Userland target flags: `-march=core2 -mtune=core2`; Rust `-C target-cpu=core2`.
- Target is Dell Latitude D630 / Core 2 Duo T7250 / x86_64 / legacy BIOS only.
- Live GRUB menu belongs at `/alpine/grub.cfg`; `/boot/grub/grub.cfg` is only a BIOS redirect stub.
- Before accepting Mesa/DDX output, inspect actual configure/build logs to verify LLVM disabled, Crocus + Softpipe selected, SNA enabled/default, and dependencies correct.
- After packages complete: validate live `/etc/apk/world`, `/alpine/{kernel,initrd,sfs}`, BIOS GRUB redirect, QEMU legacy-BIOS boot, then physical D630 boot.

## Published checkpoint

Release tag: `core2-checkpoint-2026-11-11-01` in `AmrUser-48/alpine-d630`.
Archive SHA256: `0dc987053f83288042d351e78c6be3b2994090e059721fb70358977d464826a6`.

## Runner shutdown result

A host poweroff was requested but not authorized: `sudo` is blocked by the Desktop Commander command policy, and `systemctl poweroff` returned `Interactive authentication required`. The host was therefore left online; no build is running. To power it off, use the runner/provider console or an authorized administrator session. The Desktop Commander disconnect action only stops remote access and does not power off the host.

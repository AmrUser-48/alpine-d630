FROM alpine:3.24.4

RUN apk add --no-cache \
    alpine-sdk alpine-conf apk-tools busybox fakeroot \
    syslinux xorriso squashfs-tools mtools grub-bios grub-efi dosfstools \
    git bash bc bison flex openssl-dev elfutils-dev perl pahole zstd ccache \
    python3 py3-pip bpftool linux-headers su-exec \
    gmp-dev mpc1-dev mpfr-dev mawk diffutils findutils installkernel cpio

RUN adduser -D -u 1001 -h /home/builder -s /bin/ash builder \
    && addgroup builder abuild \
    && mkdir -p /home/builder/.abuild /workspace \
    && chown -R builder:builder /home/builder

ENV HOME=/home/builder
ENV PACKAGER="D630 Alpine Builder <builder@localhost>"
WORKDIR /workspace
USER builder

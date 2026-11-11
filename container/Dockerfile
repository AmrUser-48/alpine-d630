FROM alpine:3.24.4

RUN apk update \
    && apk add \
    alpine-sdk alpine-conf apk-tools busybox fakeroot \
    syslinux xorriso squashfs-tools mtools grub-bios grub-efi dosfstools \
    git bash bc bison flex openssl-dev elfutils-dev perl pahole zstd ccache \
    python3 py3-pip bpftool linux-headers su-exec \
    gmp-dev mpc1-dev mpfr-dev mawk diffutils findutils installkernel cpio \
    && rm -f /var/cache/apk/*.apk

# These settings are copied into abuild's clean rootbld chroot via /etc/abuild.conf.
# Setting flags only in the outer builder environment is insufficient for abuild -r.
RUN printf '%s\n' \
    'export CFLAGS="$CFLAGS -march=core2 -mtune=core2"' \
    'export CXXFLAGS="$CXXFLAGS -march=core2 -mtune=core2"' \
    'export RUSTFLAGS="$RUSTFLAGS -C target-cpu=core2"' \
    >> /etc/abuild.conf

RUN adduser -D -u 1001 -h /home/builder -s /bin/ash builder \
    && addgroup builder abuild \
    && mkdir -p /home/builder/.abuild /workspace \
    && chown -R builder:builder /home/builder

ENV HOME=/home/builder
ENV PACKAGER="D630 Alpine Builder <builder@localhost>"
WORKDIR /workspace
USER builder

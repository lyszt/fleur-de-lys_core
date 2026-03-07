# =============================================================================
# Fleur de Lys — Multi-Stage Build Environment
# Stage 1: toolchain-builder  — cross-compiler
# Stage 2: temp-tools-builder — all pre-chroot tools
# Stage 3: final              — clean image, just /tools + runtime fs utils
# =============================================================================

# -----------------------------------------------------------------------------
# STAGE 1: toolchain-builder
# -----------------------------------------------------------------------------
FROM archlinux:latest AS toolchain-builder

ENV LC_ALL=POSIX
ENV LFS_TGT=x86_64-fleur-linux-gnu
ENV PATH=/tools/bin:/usr/bin:/bin
ENV MAKEFLAGS="-j$(nproc)"

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
        base-devel gcc binutils make cmake ninja \
        autoconf automake libtool pkgconf bison flex m4 \
        gmp mpfr libmpc openssl libelf ncurses \
        bzip2 gzip xz zstd curl wget git rsync \
        python perl texinfo gettext bc && \
    pacman -Scc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/*

RUN mkdir -pv /tools /sources

COPY scripts/build_toolchain.sh /build_toolchain.sh

# Split into checkpoints for easier debugging — merge into one RUN once stable
RUN chmod +x /build_toolchain.sh
RUN /build_toolchain.sh
RUN rm -rf /sources /build_toolchain.sh

# -----------------------------------------------------------------------------
# STAGE 2: temp-tools-builder
# -----------------------------------------------------------------------------
FROM archlinux:latest AS temp-tools-builder

ENV LC_ALL=POSIX
ENV LFS_TGT=x86_64-fleur-linux-gnu
ENV PATH=/tools/bin:/usr/bin:/bin
ENV MAKEFLAGS="-j$(nproc)"

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
        base-devel gcc binutils make cmake ninja \
        autoconf automake libtool pkgconf bison flex m4 \
        gmp mpfr libmpc openssl libelf ncurses \
        bzip2 gzip xz zstd curl wget git rsync \
        python perl texinfo gettext bc && \
    pacman -Scc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/*

# Only bring /tools from stage 1 — not the full layer
COPY --from=toolchain-builder /tools /tools

RUN mkdir -pv /sources

COPY scripts/build_temptools.sh /build_temptools.sh

# Split into checkpoints for easier debugging — merge into one RUN once stable
RUN chmod +x /build_temptools.sh
RUN /build_temptools.sh
RUN rm -rf /sources /build_temptools.sh

# -----------------------------------------------------------------------------
# STAGE 3: final — clean slate, copy only /tools
# -----------------------------------------------------------------------------
FROM archlinux:latest AS final

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
        util-linux f2fs-tools bcachefs-tools e2fsprogs dosfstools \
        multipath-tools parted gptfdisk \
        curl wget git vim less rsync && \
    pacman -Scc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/*

# Only /tools from stage 2 — no build deps, no sources, no pacman cache
COPY --from=temp-tools-builder /tools /tools

ENV PATH=/tools/bin:/usr/bin:/bin
ENV TERM=xterm-256color

RUN ln -sf /tools/bin/zsh /bin/sh && \
    ln -sf /tools/bin/zsh /bin/bash

RUN mkdir -p /build /images

RUN cat > /usr/local/bin/version-check.sh << 'EOF'
#!/bin/zsh
echo "=== Fleur de Lys Tool Version Check ==="
echo "zsh:           $(/tools/bin/zsh --version)"
echo "gcc:           $(gcc --version | head -1)"
echo "g++:           $(g++ --version | head -1)"
echo "binutils (ld): $(ld --version | head -1)"
echo "make:          $(make --version | head -1)"
echo "bison:         $(bison --version | head -1)"
echo "gawk:          $(gawk --version | head -1)"
echo "glibc:         $(ldd --version | head -1)"
echo "python:        $(/tools/bin/python3 --version)"
echo "cmake:         $(/tools/bin/cmake --version | head -1)"
echo "meson:         $(/tools/bin/meson --version)"
echo "losetup:       $(losetup --version)"
echo "f2fs-tools:    $(mkfs.f2fs -V 2>&1 | head -1)"
echo "bcachefs:      $(bcachefs version 2>&1 | head -1)"
echo "========================================"
EOF
RUN chmod +x /usr/local/bin/version-check.sh

WORKDIR /build
CMD ["/tools/bin/zsh"]

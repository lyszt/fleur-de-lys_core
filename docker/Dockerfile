# =============================================================================
# Fleur de Lys — Multi-Stage Build Environment
# Stage 1: toolchain-builder  — bootstrap toolchain (binutils, llvm wrappers, kernel headers, glibc)
# Stage 1b: glibc built as a separate RUN for fast iteration
# Stage 2: temp-tools-builder — all pre-chroot tools
# Stage 3: final              — clean image, just /tools + runtime fs utils
# =============================================================================

# -----------------------------------------------------------------------------
# STAGE 1: toolchain-builder
# -----------------------------------------------------------------------------
FROM archlinux@sha256:6417af93a50740f2c88503b098e780c9edf5ee00aa156021c28bcfffe226f57d AS toolchain-builder
ENV LC_ALL=POSIX
ENV LFS_TGT=x86_64-fleur-linux-gnu
ENV PATH=/tools/bin:/usr/bin:/bin
ENV MAKEFLAGS="-j$(nproc)"

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
        base-devel gcc clang lld binutils make cmake ninja \
        autoconf automake libtool pkgconf bison flex m4 \
        gmp mpfr libmpc openssl libelf ncurses \
        bzip2 gzip xz zstd curl wget git rsync \
        python perl texinfo gettext bc && \
    pacman -Scc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/*
RUN mkdir -pv /tools /sources /engine /recipes

COPY engine/fleur-build.sh /usr/bin/fleur-build
RUN chmod +x /usr/bin/fleur-build

COPY engine/fetch_sources.sh /usr/bin/fetch_sources
RUN chmod +x /usr/bin/fetch_sources

COPY recipes/stage1/ /recipes/stage1/

# Downloads isolated — cheap to retry on mirror failures
RUN fetch_sources /recipes/stage1/binutils-pass1.recipe
RUN fetch_sources /recipes/stage1/llvm-bootstrap.recipe
RUN fetch_sources /recipes/stage1/zen-kernel.recipe

# Builds: binutils pass 1, host-llvm cross wrappers, zen kernel headers
# Does NOT build glibc — that is the next step for easy re-runs
RUN fleur-build /recipes/stage1/binutils-pass1.recipe
RUN fleur-build /recipes/stage1/llvm-bootstrap.recipe
RUN fleur-build /recipes/stage1/zen-kernel.recipe

# Glibc isolated as its own layer — rebuild this step alone when iterating
RUN fetch_sources /recipes/stage1/glibc.recipe
RUN fleur-build   /recipes/stage1/glibc.recipe

RUN rm -rf /sources /recipes/stage1

# -----------------------------------------------------------------------------
# STAGE 2: temp-tools-builder
# -----------------------------------------------------------------------------
FROM archlinux@sha256:6417af93a50740f2c88503b098e780c9edf5ee00aa156021c28bcfffe226f57d AS temp-tools-builder
ENV LC_ALL=POSIX
ENV LFS_TGT=x86_64-fleur-linux-gnu
ENV PATH=/usr/bin:/bin:/tools/bin
ENV MAKEFLAGS="-j$(nproc)"

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
        base-devel gcc clang lld binutils make cmake ninja \
        autoconf automake libtool pkgconf bison flex m4 \
        gmp mpfr libmpc openssl libelf ncurses \
        bzip2 gzip xz zstd curl wget git rsync \
        python perl texinfo gettext bc && \
    pacman -Scc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/*
# Only bring /tools from stage 1 — not the full layer
COPY --from=toolchain-builder /tools /tools

RUN mkdir -pv /sources /engine /recipes

COPY engine/fleur-build.sh /usr/bin/fleur-build
RUN chmod +x /usr/bin/fleur-build

COPY engine/fetch_sources.sh /usr/bin/fetch_sources
RUN chmod +x /usr/bin/fetch_sources

COPY recipes/stage2/ /recipes/stage2/

# Downloads isolated in their own layer — cheap to retry on flaky mirrors
RUN fetch_sources /recipes/stage2/m4.recipe
RUN fetch_sources /recipes/stage2/pkgconf.recipe
RUN fetch_sources /recipes/stage2/ncurses.recipe
RUN fetch_sources /recipes/stage2/zsh.recipe
RUN fetch_sources /recipes/stage2/make.recipe
RUN fetch_sources /recipes/stage2/sed.recipe
RUN fetch_sources /recipes/stage2/gawk.recipe
RUN fetch_sources /recipes/stage2/bison.recipe
RUN fetch_sources /recipes/stage2/diffutils.recipe
RUN fetch_sources /recipes/stage2/findutils.recipe
RUN fetch_sources /recipes/stage2/patch.recipe
RUN fetch_sources /recipes/stage2/tar.recipe
RUN fetch_sources /recipes/stage2/gzip.recipe
RUN fetch_sources /recipes/stage2/grep.recipe
RUN fetch_sources /recipes/stage2/gettext.recipe
RUN fetch_sources /recipes/stage2/zstd.recipe
RUN fetch_sources /recipes/stage2/libtool.recipe
RUN fetch_sources /recipes/stage2/kmod.recipe
RUN fetch_sources /recipes/stage2/shadow.recipe
RUN fetch_sources /recipes/stage2/python.recipe
RUN fetch_sources /recipes/stage2/ninja.recipe
RUN fetch_sources /recipes/stage2/meson.recipe
RUN fetch_sources /recipes/stage2/cmake.recipe
RUN fetch_sources /recipes/stage2/binutils-pass2.recipe
RUN fetch_sources /recipes/stage2/llvm.recipe

RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/m4.recipe
RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/pkgconf.recipe
RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/ncurses.recipe
RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/zsh.recipe
RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/make.recipe
RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/sed.recipe
RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/gawk.recipe
RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/bison.recipe
RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/diffutils.recipe
RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/findutils.recipe
RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/patch.recipe
RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/tar.recipe
RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/gzip.recipe
RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/grep.recipe
RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/gettext.recipe
RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/zstd.recipe
RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/libtool.recipe
RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/kmod.recipe
RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/shadow.recipe
RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/python.recipe
RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/ninja.recipe
RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/meson.recipe
RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/cmake.recipe
RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/binutils-pass2.recipe
RUN FLEUR_STAGE=2 fleur-build /recipes/stage2/llvm.recipe

RUN rm -rf /sources /recipes /usr/bin/fleur-build /usr/bin/fetch_sources

# -----------------------------------------------------------------------------
# STAGE 3: final — clean slate, copy only /tools
# -----------------------------------------------------------------------------
FROM archlinux@sha256:6417af93a50740f2c88503b098e780c9edf5ee00aa156021c28bcfffe226f57d AS final

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

RUN cat > /usr/local/bin/version-check.sh << 'VEOF'
#!/bin/zsh
echo "=== Fleur de Lys Tool Version Check ==="
echo "zsh:           $(/tools/bin/zsh --version)"
echo "clang:         $(/tools/bin/clang --version | head -1)"
echo "clang++:       $(/tools/bin/clang++ --version | head -1)"
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
VEOF
RUN chmod +x /usr/local/bin/version-check.sh

WORKDIR /build
CMD ["/tools/bin/zsh"]

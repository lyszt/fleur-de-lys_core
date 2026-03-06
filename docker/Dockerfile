# Fleur de Lys — Build Environment
# "If you wish to make an apple pie from scratch, first invent the universe." -- Carl Sagan
#
# Base: Arch Linux (rolling release) — true bleeding edge
FROM archlinux:latest

# Refresh mirrors and upgrade everything first
RUN pacman -Syu --noconfirm

RUN pacman -S --noconfirm \
    # Core build toolchain
    base-devel \
    gcc \
    binutils \
    make \
    cmake \
    ninja \
    autoconf \
    automake \
    libtool \
    pkgconf \
    bison \
    flex \
    m4 \
    # Dev libs
    gmp \
    mpfr \
    libmpc \
    openssl \
    libelf \
    ncurses \
    libxml2 \
    # Compression
    bzip2 \
    gzip \
    xz \
    zstd \
    # Disk & filesystem tools
    util-linux \
    gptfdisk \
    parted \
    f2fs-tools \
    bcachefs-tools \
    e2fsprogs \
    dosfstools \
    # Text & scripting tools
    gawk \
    grep \
    sed \
    patch \
    diffutils \
    perl \
    python \
    texinfo \
    gettext \
    bc \
    # Download & VCS
    curl \
    wget \
    git \
    rsync \
    # Misc utils
    file \
    findutils \
    coreutils \
    vim \
    less \
    && pacman -Scc --noconfirm

# /build is where the project repo is bind-mounted at runtime
# /images is where the .img file lives (bind-mounted from host)
RUN mkdir -p /build /images

WORKDIR /build

RUN cat > /usr/local/bin/version-check.sh << 'EOF'
#!/bin/bash
echo "=== Fleur de Lys Host Tool Version Check ==="
echo "bash:          $(bash --version | head -1)"
echo "gcc:           $(gcc --version | head -1)"
echo "g++:           $(g++ --version | head -1)"
echo "binutils (ld): $(ld --version | head -1)"
echo "make:          $(make --version | head -1)"
echo "bison:         $(bison --version | head -1)"
echo "gawk:          $(gawk --version | head -1)"
echo "glibc:         $(ldd --version | head -1)"
echo "losetup:       $(losetup --version)"
echo "f2fs-tools:    $(mkfs.f2fs -V 2>&1 | head -1)"
echo "bcachefs:      $(bcachefs version 2>&1 | head -1)"
echo "parted:        $(parted --version | head -1)"
echo "python:        $(python --version)"
echo "perl:          $(perl -e 'print "v$]\n"')"
echo "============================================="
EOF
RUN chmod +x /usr/local/bin/version-check.sh

CMD ["/bin/bash"]

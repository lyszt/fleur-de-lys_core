#!/bin/bash
# build_temptools.sh — Stage 2: Temporary tools
# Builds all pre-chroot tools using the cross-compiler from stage 1
# Shell: zsh (with /bin/sh and /bin/bash compat symlinks)
# Installs to: /tools
set -e

LFS_TGT=x86_64-fleur-linux-gnu
TOOLS=/tools
SOURCES=/sources
MAKEFLAGS="-j$(nproc)"
PATH=/tools/bin:/usr/bin:/bin

cd $SOURCES

# ---------------------------------------------------------------------------
# Package versions
# ---------------------------------------------------------------------------
M4_VER=1.4.21
NCURSES_VER=6.6
ZSH_VER=5.9
SED_VER=4.9
GAWK_VER=5.3.2
BISON_VER=3.8.2
DIFFUTILS_VER=3.12
FINDUTILS_VER=4.10.0
PATCH_VER=2.8
TAR_VER=1.35
GZIP_VER=1.14
GREP_VER=3.12
GETTEXT_VER=0.22.5
ZSTD_VER=1.5.7
KMOD_VER=33
SHADOW_VER=4.16.0
MPFR_VER=4.2.2
GMP_VER=6.3.0
MPC_VER=1.3.1
GCC_VER=15.1.0
BINUTILS_VER=2.44
PYTHON_VER=3.13.3
CMAKE_VER=3.31.6
MESON_VER=1.7.0
NINJA_VER=1.12.1
LIBTOOL_VER=2.5.4
PKGCONF_VER=2.3.0
MAKE_VER=4.4.1

# ---------------------------------------------------------------------------
# Mirror-aware downloader
# Usage: fetch <filename> <url> [<url> ...]
# Tries each URL in order. For GNU mirrors, automatically expands
# ftpmirror.gnu.org into multiple known-good mirrors before trying.
# ---------------------------------------------------------------------------
fetch() {
  local FILE=$1
  shift
  local URLS=("$@")

  # If already downloaded, skip
  if [ -f "$FILE" ]; then
    echo "  [cache] $FILE"
    return 0
  fi

  # Expand any ftpmirror.gnu.org URL into a prioritised mirror list
  local EXPANDED=()
  for URL in "${URLS[@]}"; do
    if echo "$URL" | grep -q "ftpmirror.gnu.org"; then
      local PATH_PART="${URL#*ftpmirror.gnu.org}"
      # Primary mirrors first, ftpmirror as last resort
      EXPANDED+=(
        "https://ftp.gnu.org/gnu${PATH_PART}"
        "https://mirror.csclub.uwaterloo.ca/gnu${PATH_PART}"
        "https://mirrors.kernel.org/gnu${PATH_PART}"
        "https://gnu.mirror.constant.com${PATH_PART}"
        "https://ftpmirror.gnu.org${PATH_PART}"
      )
    else
      EXPANDED+=("$URL")
    fi
  done

  local TRIED=0
  for URL in "${EXPANDED[@]}"; do
    local HOST
    HOST=$(echo "$URL" | awk -F/ '{print $3}')
    echo "  [fetch] $FILE from $HOST ..."

    # Quick reachability check — skip dead hosts fast
    if ! curl -sf --max-time 5 --head "$URL" >/dev/null 2>&1; then
      echo "  [skip]  $HOST unreachable"
      continue
    fi

    if wget -q --timeout=60 --tries=2 -O "$FILE.tmp" "$URL"; then
      mv "$FILE.tmp" "$FILE"
      echo "  [ok]    $FILE"
      return 0
    else
      rm -f "$FILE.tmp"
      echo "  [fail]  $URL"
    fi
    TRIED=$((TRIED + 1))
  done

  echo "ERROR: Could not download $FILE — tried ${#EXPANDED[@]} URLs"
  return 1
}

# Shorthand for ftpmirror.gnu.org packages (most of our sources)
fetch_gnu() {
  local FILE=$1
  local GNU_PATH=$2 # e.g. "m4/m4-1.4.21.tar.xz"
  fetch "$FILE" "https://ftpmirror.gnu.org/${GNU_PATH}"
}

# ---------------------------------------------------------------------------
# Download all sources
# ---------------------------------------------------------------------------
echo ">>> Downloading sources..."

fetch_gnu "m4-${M4_VER}.tar.xz" "m4/m4-${M4_VER}.tar.xz"
fetch_gnu "ncurses-${NCURSES_VER}.tar.gz" "ncurses/ncurses-${NCURSES_VER}.tar.gz"
fetch_gnu "sed-${SED_VER}.tar.xz" "sed/sed-${SED_VER}.tar.xz"
fetch_gnu "gawk-${GAWK_VER}.tar.xz" "gawk/gawk-${GAWK_VER}.tar.xz"
fetch_gnu "bison-${BISON_VER}.tar.xz" "bison/bison-${BISON_VER}.tar.xz"
fetch_gnu "diffutils-${DIFFUTILS_VER}.tar.xz" "diffutils/diffutils-${DIFFUTILS_VER}.tar.xz"
fetch_gnu "findutils-${FINDUTILS_VER}.tar.xz" "findutils/findutils-${FINDUTILS_VER}.tar.xz"
fetch_gnu "patch-${PATCH_VER}.tar.xz" "patch/patch-${PATCH_VER}.tar.xz"
fetch_gnu "tar-${TAR_VER}.tar.xz" "tar/tar-${TAR_VER}.tar.xz"
fetch_gnu "gzip-${GZIP_VER}.tar.xz" "gzip/gzip-${GZIP_VER}.tar.xz"
fetch_gnu "grep-${GREP_VER}.tar.xz" "grep/grep-${GREP_VER}.tar.xz"
fetch_gnu "gettext-${GETTEXT_VER}.tar.xz" "gettext/gettext-${GETTEXT_VER}.tar.xz"
fetch_gnu "mpfr-${MPFR_VER}.tar.xz" "mpfr/mpfr-${MPFR_VER}.tar.xz"
fetch_gnu "gmp-${GMP_VER}.tar.xz" "gmp/gmp-${GMP_VER}.tar.xz"
fetch_gnu "gcc-${GCC_VER}.tar.xz" "gcc/gcc-${GCC_VER}/gcc-${GCC_VER}.tar.xz"
fetch_gnu "binutils-${BINUTILS_VER}.tar.xz" "binutils/binutils-${BINUTILS_VER}.tar.xz"
fetch_gnu "libtool-${LIBTOOL_VER}.tar.xz" "libtool/libtool-${LIBTOOL_VER}.tar.xz"
fetch_gnu "make-${MAKE_VER}.tar.gz" "make/make-${MAKE_VER}.tar.gz"

# MPC — only on ftp.gnu.org, not ftpmirror
fetch "mpc-${MPC_VER}.tar.gz" \
  "https://ftp.gnu.org/gnu/mpc/mpc-${MPC_VER}.tar.gz" \
  "https://mirror.csclub.uwaterloo.ca/gnu/mpc/mpc-${MPC_VER}.tar.gz"

# Zsh — sourceforge primary, GitHub as fallback
fetch "zsh-${ZSH_VER}.tar.xz" \
  "https://sourceforge.net/projects/zsh/files/zsh/${ZSH_VER}/zsh-${ZSH_VER}.tar.xz" \
  "https://github.com/zsh-users/zsh/archive/refs/tags/zsh-${ZSH_VER}.tar.gz"

# Zstd — GitHub releases
fetch "zstd-${ZSTD_VER}.tar.gz" \
  "https://github.com/facebook/zstd/releases/download/v${ZSTD_VER}/zstd-${ZSTD_VER}.tar.gz"

# Kmod — kernel.org
fetch "kmod-${KMOD_VER}.tar.xz" \
  "https://www.kernel.org/pub/linux/utils/kernel/kmod/kmod-${KMOD_VER}.tar.xz" \
  "https://mirrors.edge.kernel.org/pub/linux/utils/kernel/kmod/kmod-${KMOD_VER}.tar.xz"

# Shadow — GitHub releases
fetch "shadow-${SHADOW_VER}.tar.xz" \
  "https://github.com/shadow-maint/shadow/releases/download/${SHADOW_VER}/shadow-${SHADOW_VER}.tar.xz"

# Python — python.org
fetch "Python-${PYTHON_VER}.tar.xz" \
  "https://www.python.org/ftp/python/${PYTHON_VER}/Python-${PYTHON_VER}.tar.xz"

# CMake — GitHub releases
fetch "cmake-${CMAKE_VER}.tar.gz" \
  "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VER}/cmake-${CMAKE_VER}.tar.gz"

# Meson — GitHub releases
fetch "meson-${MESON_VER}.tar.gz" \
  "https://github.com/mesonbuild/meson/releases/download/${MESON_VER}/meson-${MESON_VER}.tar.gz"

# Ninja — GitHub releases
fetch "ninja-${NINJA_VER}.tar.gz" \
  "https://github.com/ninja-build/ninja/archive/refs/tags/v${NINJA_VER}.tar.gz"

# Pkgconf — ariadne.space primary, GitHub fallback
fetch "pkgconf-${PKGCONF_VER}.tar.xz" \
  "https://distfiles.ariadne.space/pkgconf/pkgconf-${PKGCONF_VER}.tar.xz" \
  "https://github.com/pkgconf/pkgconf/releases/download/pkgconf-${PKGCONF_VER}/pkgconf-${PKGCONF_VER}.tar.xz"

echo ">>> All sources downloaded."

# ---------------------------------------------------------------------------
# Helper: build_autotools <srcdir> [extra configure args...]
# ---------------------------------------------------------------------------
build_autotools() {
  local DIR=$1
  shift
  cd $SOURCES
  tar -xf ${DIR}.tar.* 2>/dev/null || tar -xf ${DIR}.tar.gz
  cd $DIR
  ./configure --prefix=/tools "$@"
  make $MAKEFLAGS
  make install
  cd $SOURCES
  rm -rf $DIR
}

# ---------------------------------------------------------------------------
# 1. M4
# ---------------------------------------------------------------------------
echo ">>> Building m4..."
build_autotools m4-${M4_VER}

# ---------------------------------------------------------------------------
# 2. Ncurses
# ---------------------------------------------------------------------------
echo ">>> Building ncurses..."
tar -xf ncurses-${NCURSES_VER}.tar.gz
cd ncurses-${NCURSES_VER}
./configure \
  --prefix=/tools \
  --with-shared \
  --without-debug \
  --without-ada \
  --without-normal \
  --with-cxx-shared \
  --enable-widec
make $MAKEFLAGS
make install
ln -sfv libncursesw.so /tools/lib/libncurses.so
ln -sfv libncursesw.a /tools/lib/libncurses.a
cd $SOURCES
rm -rf ncurses-${NCURSES_VER}

# ---------------------------------------------------------------------------
# 3. Zsh — primary shell
# ---------------------------------------------------------------------------
echo ">>> Building zsh..."
tar -xf zsh-${ZSH_VER}.tar.xz
cd zsh-${ZSH_VER}
./configure \
  --prefix=/tools \
  --enable-multibyte \
  --enable-pcre \
  --with-tcsetpgrp \
  --enable-cap \
  CPPFLAGS="-I/tools/include" \
  LDFLAGS="-L/tools/lib"
make $MAKEFLAGS
make install
ln -sfv /tools/bin/zsh /tools/bin/bash
ln -sfv /tools/bin/zsh /tools/bin/sh
cd $SOURCES
rm -rf zsh-${ZSH_VER}

# ---------------------------------------------------------------------------
# 4. Make
# ---------------------------------------------------------------------------
echo ">>> Building make..."
build_autotools make-${MAKE_VER} --without-guile

# ---------------------------------------------------------------------------
# 5. Sed
# ---------------------------------------------------------------------------
echo ">>> Building sed..."
build_autotools sed-${SED_VER}

# ---------------------------------------------------------------------------
# 6. Gawk
# ---------------------------------------------------------------------------
echo ">>> Building gawk..."
build_autotools gawk-${GAWK_VER}

# ---------------------------------------------------------------------------
# 7. Bison
# ---------------------------------------------------------------------------
echo ">>> Building bison..."
build_autotools bison-${BISON_VER}

# ---------------------------------------------------------------------------
# 8. Diffutils
# ---------------------------------------------------------------------------
echo ">>> Building diffutils..."
build_autotools diffutils-${DIFFUTILS_VER}

# ---------------------------------------------------------------------------
# 9. Findutils
# ---------------------------------------------------------------------------
echo ">>> Building findutils..."
build_autotools findutils-${FINDUTILS_VER}

# ---------------------------------------------------------------------------
# 10. Patch
# ---------------------------------------------------------------------------
echo ">>> Building patch..."
build_autotools patch-${PATCH_VER}

# ---------------------------------------------------------------------------
# 11. Tar
# ---------------------------------------------------------------------------
echo ">>> Building tar..."
build_autotools tar-${TAR_VER}

# ---------------------------------------------------------------------------
# 12. Gzip
# ---------------------------------------------------------------------------
echo ">>> Building gzip..."
build_autotools gzip-${GZIP_VER}

# ---------------------------------------------------------------------------
# 13. Grep
# ---------------------------------------------------------------------------
echo ">>> Building grep..."
build_autotools grep-${GREP_VER}

# ---------------------------------------------------------------------------
# 14. Gettext (tools only, not the full library)
# ---------------------------------------------------------------------------
echo ">>> Building gettext..."
tar -xf gettext-${GETTEXT_VER}.tar.xz
cd gettext-${GETTEXT_VER}
./configure --prefix=/tools --disable-shared
make $MAKEFLAGS
cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /tools/bin
cd $SOURCES
rm -rf gettext-${GETTEXT_VER}

# ---------------------------------------------------------------------------
# 15. Zstd
# ---------------------------------------------------------------------------
echo ">>> Building zstd..."
tar -xf zstd-${ZSTD_VER}.tar.gz
cd zstd-${ZSTD_VER}
make $MAKEFLAGS prefix=/tools
make prefix=/tools install
cd $SOURCES
rm -rf zstd-${ZSTD_VER}

# ---------------------------------------------------------------------------
# 16. Pkgconf
# ---------------------------------------------------------------------------
echo ">>> Building pkgconf..."
build_autotools pkgconf-${PKGCONF_VER} \
  --with-system-libdir=/tools/lib \
  --with-system-includedir=/tools/include
ln -sfv pkgconf /tools/bin/pkg-config

# ---------------------------------------------------------------------------
# 17. Libtool
# ---------------------------------------------------------------------------
echo ">>> Building libtool..."
build_autotools libtool-${LIBTOOL_VER}

# ---------------------------------------------------------------------------
# 18. Kmod
# ---------------------------------------------------------------------------
echo ">>> Building kmod..."
build_autotools kmod-${KMOD_VER} \
  --with-zstd \
  --with-xz \
  --with-zlib \
  --with-openssl

# ---------------------------------------------------------------------------
# 19. Shadow
# ---------------------------------------------------------------------------
echo ">>> Building shadow..."
tar -xf shadow-${SHADOW_VER}.tar.xz
cd shadow-${SHADOW_VER}
./configure \
  --prefix=/tools \
  --disable-man \
  --without-audit \
  --without-selinux \
  --without-acl \
  --without-attr \
  --without-tcb \
  --without-nscd
make $MAKEFLAGS
make install
cd $SOURCES
rm -rf shadow-${SHADOW_VER}

# ---------------------------------------------------------------------------
# 20. Python 3
# ---------------------------------------------------------------------------
echo ">>> Building Python ${PYTHON_VER}..."
tar -xf Python-${PYTHON_VER}.tar.xz
cd Python-${PYTHON_VER}
./configure \
  --prefix=/tools \
  --enable-shared \
  --without-ensurepip \
  --enable-optimizations
make $MAKEFLAGS
make install
ln -sfv python3 /tools/bin/python
cd $SOURCES
rm -rf Python-${PYTHON_VER}

# ---------------------------------------------------------------------------
# 21. Ninja
# ---------------------------------------------------------------------------
echo ">>> Building ninja..."
tar -xf ninja-${NINJA_VER}.tar.gz
cd ninja-${NINJA_VER}
python /tools/bin/python configure.py --bootstrap
install -vm755 ninja /tools/bin/
cd $SOURCES
rm -rf ninja-${NINJA_VER}

# ---------------------------------------------------------------------------
# 22. Meson
# ---------------------------------------------------------------------------
echo ">>> Building meson..."
tar -xf meson-${MESON_VER}.tar.gz
cd meson-${MESON_VER}
/tools/bin/python setup.py install --prefix=/tools
cd $SOURCES
rm -rf meson-${MESON_VER}

# ---------------------------------------------------------------------------
# 23. CMake
# ---------------------------------------------------------------------------
echo ">>> Building cmake..."
tar -xf cmake-${CMAKE_VER}.tar.gz
cd cmake-${CMAKE_VER}
./bootstrap \
  --prefix=/tools \
  --no-system-libs \
  --parallel=$(nproc)
make $MAKEFLAGS
make install
cd $SOURCES
rm -rf cmake-${CMAKE_VER}

# ---------------------------------------------------------------------------
# 24. Binutils Pass 2
# ---------------------------------------------------------------------------
echo ">>> Building binutils pass 2..."
tar -xf binutils-${BINUTILS_VER}.tar.xz
cd binutils-${BINUTILS_VER}
sed '6009s/$add_dir//' -i ltmain.sh
mkdir -v build && cd build
../configure \
  --prefix=/tools \
  --build=$(../config.guess) \
  --host=$LFS_TGT \
  --disable-nls \
  --enable-shared \
  --enable-gprofng=no \
  --disable-werror \
  --enable-64-bit-bfd \
  --enable-new-dtags \
  --enable-default-hash-style=gnu
make $MAKEFLAGS
make install
cd $SOURCES
rm -rf binutils-${BINUTILS_VER}

# ---------------------------------------------------------------------------
# 25. GCC Pass 2
# ---------------------------------------------------------------------------
echo ">>> Building gcc pass 2..."
tar -xf gcc-${GCC_VER}.tar.xz
cd gcc-${GCC_VER}

tar -xf $SOURCES/gmp-${GMP_VER}.tar.xz && mv gmp-${GMP_VER} gmp
tar -xf $SOURCES/mpfr-${MPFR_VER}.tar.xz && mv mpfr-${MPFR_VER} mpfr
tar -xf $SOURCES/mpc-${MPC_VER}.tar.gz && mv mpc-${MPC_VER} mpc

sed -e '/m64=/s/lib64/lib/' -i gcc/config/i386/t-linux64

sed '/thread_header =/s/@.*@/gthr-posix.h/' \
  -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in

mkdir -v build && cd build

../configure \
  --build=$(../config.guess) \
  --host=$LFS_TGT \
  --target=$LFS_TGT \
  LDFLAGS_FOR_TARGET="-L$PWD/$LFS_TGT/libgcc" \
  --prefix=/tools \
  --with-build-sysroot=/ \
  --enable-default-pie \
  --enable-default-ssp \
  --disable-nls \
  --disable-multilib \
  --disable-libatomic \
  --disable-libgomp \
  --disable-libquadmath \
  --disable-libsanitizer \
  --disable-libssp \
  --disable-libvtv \
  --enable-languages=c,c++
make $MAKEFLAGS
make install
ln -sv gcc /tools/bin/cc
cd $SOURCES
rm -rf gcc-${GCC_VER}

echo ""
echo ">>> Stage 2 complete: all pre-chroot tools installed to /tools"
echo ">>> Default shell: $(/tools/bin/zsh --version)"
echo ">>> /tools/bin/sh -> $(readlink /tools/bin/sh)"

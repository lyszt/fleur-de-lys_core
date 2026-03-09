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

# Isolate the environment to prevent host system contamination
export PATH=/tools/bin:/usr/bin:/bin
export CPATH="/tools/include"
export LIBRARY_PATH="/tools/lib"
export PKG_CONFIG_PATH=""
export PKG_CONFIG_LIBDIR="/tools/lib/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="/"

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
# Verify sources are present
# ---------------------------------------------------------------------------
echo ">>> Verifying sources..."
MISSING=0
for f in \
  m4-${M4_VER}.tar.xz ncurses-${NCURSES_VER}.tar.gz zsh-${ZSH_VER}.tar.xz \
  sed-${SED_VER}.tar.xz gawk-${GAWK_VER}.tar.xz bison-${BISON_VER}.tar.xz \
  diffutils-${DIFFUTILS_VER}.tar.xz findutils-${FINDUTILS_VER}.tar.xz \
  patch-${PATCH_VER}.tar.xz tar-${TAR_VER}.tar.xz gzip-${GZIP_VER}.tar.xz \
  grep-${GREP_VER}.tar.xz gettext-${GETTEXT_VER}.tar.xz \
  zstd-${ZSTD_VER}.tar.gz kmod-${KMOD_VER}.tar.xz shadow-${SHADOW_VER}.tar.xz \
  mpfr-${MPFR_VER}.tar.xz gmp-${GMP_VER}.tar.xz mpc-${MPC_VER}.tar.gz \
  gcc-${GCC_VER}.tar.xz binutils-${BINUTILS_VER}.tar.xz \
  Python-${PYTHON_VER}.tar.xz cmake-${CMAKE_VER}.tar.gz \
  meson-${MESON_VER}.tar.gz ninja-${NINJA_VER}.tar.gz \
  libtool-${LIBTOOL_VER}.tar.xz pkgconf-${PKGCONF_VER}.tar.xz \
  make-${MAKE_VER}.tar.gz; do
  if [ ! -f "$f" ]; then
    echo "  MISSING: $f"
    MISSING=$((MISSING + 1))
  fi
done
if [ $MISSING -gt 0 ]; then
  echo "ERROR: $MISSING source tarballs missing — run fetch_sources.sh first"
  exit 1
fi
echo ">>> All sources present."

# ---------------------------------------------------------------------------
# Adaptive Build Engine
# Evaluates configure/make exit codes, parses logs for known cross-compilation
# failure heuristics, applies dynamic patches to the environment, and retries.
# ---------------------------------------------------------------------------
build_autotools() {
  local DIR=$1
  shift
  local ATTEMPT=1
  local MAX_RETRIES=2
  local DYNAMIC_CFLAGS=""
  local DYNAMIC_LDFLAGS=""
  local DYNAMIC_MAKEFLAGS="$MAKEFLAGS"

  cd $SOURCES
  tar -xf ${DIR}.tar.* 2>/dev/null || tar -xf ${DIR}.tar.gz

  while [ $ATTEMPT -le $MAX_RETRIES ]; do
    echo ">>> Building $DIR (Attempt $ATTEMPT/$MAX_RETRIES)..."
    cd $SOURCES/$DIR

    [ $ATTEMPT -gt 1 ] && make distclean 2>/dev/null || true

    set +e
    ./configure --prefix=/tools --host=$LFS_TGT \
      CFLAGS="$DYNAMIC_CFLAGS" LDFLAGS="$DYNAMIC_LDFLAGS" "$@"
    CONFIG_RC=$?
    set -e

    if [ $CONFIG_RC -eq 0 ]; then
      set +e
      make $DYNAMIC_MAKEFLAGS
      MAKE_RC=$?
      set -e

      if [ $MAKE_RC -eq 0 ]; then
        make install
        cd $SOURCES
        rm -rf $DIR
        return 0
      fi

      echo "!!! Make failed for $DIR."
      if [ "$DYNAMIC_MAKEFLAGS" != "-j1" ]; then
        echo ">>> Auto-correction: Suspected race condition. Retrying sequentially (-j1)..."
        DYNAMIC_MAKEFLAGS="-j1"
      else
        exit 1
      fi
    else
      echo "!!! Configure failed for $DIR. Analyzing config.log..."
      if grep -q "C compiler cannot create executables" config.log; then
        echo ">>> Auto-correction: Compiler sanity check failed. Injecting library search paths..."
        DYNAMIC_LDFLAGS="-L/tools/lib -Wl,-rpath,/tools/lib"
      elif grep -q "No terminal handling library was found" config.log || grep -q "tigetstr" config.log; then
        echo ">>> Auto-correction: Terminal library linkage unresolvable. Forcing ncursesw..."
        DYNAMIC_LDFLAGS="$DYNAMIC_LDFLAGS -lncursesw"
      else
        echo "!!! Unrecoverable configuration error."
        tail -n 60 config.log
        exit 1
      fi
    fi
    ATTEMPT=$((ATTEMPT + 1))
  done

  echo "!!! Exhausted all correction attempts for $DIR."
  exit 1
}

# ---------------------------------------------------------------------------
# 1. M4
# ---------------------------------------------------------------------------
echo ">>> Building m4..."
build_autotools m4-${M4_VER}

# ---------------------------------------------------------------------------
# 2. Pkgconf (Moved up to provide linkage metadata for ncurses/zsh)
# ---------------------------------------------------------------------------
echo ">>> Building pkgconf..."
build_autotools pkgconf-${PKGCONF_VER} \
  --with-system-libdir=/tools/lib \
  --with-system-includedir=/tools/include
ln -sfv pkgconf /tools/bin/pkg-config

# ---------------------------------------------------------------------------
# 3. Ncurses (Configured to generate .pc files for pkg-config)
# ---------------------------------------------------------------------------
echo ">>> Building ncurses..."
tar -xf ncurses-${NCURSES_VER}.tar.gz
cd ncurses-${NCURSES_VER}
./configure \
  --prefix=/tools \
  --host=$LFS_TGT \
  --with-build-cc=gcc \
  --with-shared \
  --without-debug \
  --without-ada \
  --without-normal \
  --with-cxx-shared \
  --enable-widec \
  --enable-pc-files \
  --with-pkg-config-libdir=/tools/lib/pkgconfig
make $MAKEFLAGS
make install
ln -sfv libncursesw.so /tools/lib/libncurses.so
ln -sfv libncursesw.a /tools/lib/libncurses.a
cd $SOURCES
rm -rf ncurses-${NCURSES_VER}

# ---------------------------------------------------------------------------
# 4. Zsh — primary shell
# ---------------------------------------------------------------------------
echo ">>> Building zsh..."
tar -xf zsh-${ZSH_VER}.tar.xz
cd zsh-${ZSH_VER}

# Extract exact flags using the newly built pkg-config
NCURSES_CFLAGS=$(pkg-config --cflags ncursesw 2>/dev/null || echo "-I/tools/include -I/tools/include/ncursesw")
NCURSES_LIBS=$(pkg-config --libs ncursesw 2>/dev/null || echo "-L/tools/lib -lncursesw")

set +e
CC="$LFS_TGT-gcc" \
  CPPFLAGS="$NCURSES_CFLAGS" \
  LDFLAGS="$NCURSES_LIBS -Wl,-rpath,/tools/lib" \
  ./configure \
  --prefix=/tools \
  --host=$LFS_TGT \
  --enable-multibyte \
  --with-tcsetpgrp \
  --disable-pcre \
  --enable-cap \
  --with-term-lib="ncursesw"
CONFIGURE_RC=$?
set -e

if [ $CONFIGURE_RC -ne 0 ]; then
  echo "=== zsh configure failed (exit $CONFIGURE_RC) — config.log ==="
  cat config.log
  exit 1
fi
make $MAKEFLAGS
make install
ln -sfv /tools/bin/zsh /tools/bin/bash
ln -sfv /tools/bin/zsh /tools/bin/sh
cd $SOURCES
rm -rf zsh-${ZSH_VER}

# ---------------------------------------------------------------------------
# 5. Make
# ---------------------------------------------------------------------------
echo ">>> Building make..."
build_autotools make-${MAKE_VER} --without-guile

# ---------------------------------------------------------------------------
# 6. Sed
# ---------------------------------------------------------------------------
echo ">>> Building sed..."
build_autotools sed-${SED_VER}

# ---------------------------------------------------------------------------
# 7. Gawk
# ---------------------------------------------------------------------------
echo ">>> Building gawk..."
build_autotools gawk-${GAWK_VER}

# ---------------------------------------------------------------------------
# 8. Bison
# ---------------------------------------------------------------------------
echo ">>> Building bison..."
build_autotools bison-${BISON_VER}

# ---------------------------------------------------------------------------
# 9. Diffutils
# ---------------------------------------------------------------------------
echo ">>> Building diffutils..."
build_autotools diffutils-${DIFFUTILS_VER}

# ---------------------------------------------------------------------------
# 10. Findutils
# ---------------------------------------------------------------------------
echo ">>> Building findutils..."
build_autotools findutils-${FINDUTILS_VER}

# ---------------------------------------------------------------------------
# 11. Patch
# ---------------------------------------------------------------------------
echo ">>> Building patch..."
build_autotools patch-${PATCH_VER}

# ---------------------------------------------------------------------------
# 12. Tar
# ---------------------------------------------------------------------------
echo ">>> Building tar..."
build_autotools tar-${TAR_VER}

# ---------------------------------------------------------------------------
# 13. Gzip
# ---------------------------------------------------------------------------
echo ">>> Building gzip..."
build_autotools gzip-${GZIP_VER}

# ---------------------------------------------------------------------------
# 14. Grep
# ---------------------------------------------------------------------------
echo ">>> Building grep..."
build_autotools grep-${GREP_VER}

# ---------------------------------------------------------------------------
# 15. Gettext (tools only, not the full library)
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
# 16. Zstd
# ---------------------------------------------------------------------------
echo ">>> Building zstd..."
tar -xf zstd-${ZSTD_VER}.tar.gz
cd zstd-${ZSTD_VER}
make $MAKEFLAGS prefix=/tools
make prefix=/tools install
cd $SOURCES
rm -rf zstd-${ZSTD_VER}

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
  --with-build-sysroot=/tools \
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

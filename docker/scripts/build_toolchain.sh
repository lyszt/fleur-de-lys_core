#!/bin/bash
# build_toolchain.sh — Stage 1: Cross-toolchain
# Builds: binutils pass 1, gcc pass 1, zen-kernel headers, glibc, libstdc++
# Target: x86_64-fleur-linux-gnu
# Installs to: /tools
set -e

LFS_TGT=x86_64-fleur-linux-gnu
TOOLS=/tools
SOURCES=/sources
MAKEFLAGS="-j$(nproc)"

cd $SOURCES

# ---------------------------------------------------------------------------
# Package versions
# ---------------------------------------------------------------------------
BINUTILS_VER=2.44
GCC_VER=15.1.0
GLIBC_VER=2.41
GMP_VER=6.3.0
MPFR_VER=4.2.2
MPC_VER=1.3.1
ZEN_KERNEL_TAG=v6.13-zen1

# ---------------------------------------------------------------------------
# Download sources
# ---------------------------------------------------------------------------
echo ">>> Downloading sources..."

wget -nc https://ftpmirror.gnu.org/binutils/binutils-${BINUTILS_VER}.tar.xz
wget -nc https://ftpmirror.gnu.org/gcc/gcc-${GCC_VER}/gcc-${GCC_VER}.tar.xz
wget -nc https://ftpmirror.gnu.org/glibc/glibc-${GLIBC_VER}.tar.xz
wget -nc https://ftpmirror.gnu.org/gmp/gmp-${GMP_VER}.tar.xz
wget -nc https://ftpmirror.gnu.org/mpfr/mpfr-${MPFR_VER}.tar.xz
wget -nc https://ftp.gnu.org/gnu/mpc/mpc-${MPC_VER}.tar.gz
wget -nc https://github.com/zen-kernel/zen-kernel/archive/refs/tags/${ZEN_KERNEL_TAG}.tar.gz \
  -O zen-kernel-${ZEN_KERNEL_TAG}.tar.gz

# ---------------------------------------------------------------------------
# 1. Binutils Pass 1
# ---------------------------------------------------------------------------
echo ">>> Building binutils pass 1..."
tar -xf binutils-${BINUTILS_VER}.tar.xz
cd binutils-${BINUTILS_VER}
mkdir -v build && cd build
../configure \
  --prefix=/tools \
  --with-sysroot=/ \
  --target=$LFS_TGT \
  --disable-nls \
  --enable-gprofng=no \
  --disable-werror \
  --enable-new-dtags \
  --enable-default-hash-style=gnu
make $MAKEFLAGS
make install
cd $SOURCES
rm -rf binutils-${BINUTILS_VER}

# ---------------------------------------------------------------------------
# 2. GCC Pass 1
# ---------------------------------------------------------------------------
echo ">>> Building gcc pass 1..."
tar -xf gcc-${GCC_VER}.tar.xz
cd gcc-${GCC_VER}

# Extract GCC dependencies into the source tree
tar -xf $SOURCES/gmp-${GMP_VER}.tar.xz && mv gmp-${GMP_VER} gmp
tar -xf $SOURCES/mpfr-${MPFR_VER}.tar.xz && mv mpfr-${MPFR_VER} mpfr
tar -xf $SOURCES/mpc-${MPC_VER}.tar.gz && mv mpc-${MPC_VER} mpc

# Set 64-bit default
sed -e '/m64=/s/lib64/lib/' -i gcc/config/i386/t-linux64

mkdir -v build && cd build
../configure \
  --target=$LFS_TGT \
  --prefix=/tools \
  --with-glibc-version=${GLIBC_VER} \
  --with-sysroot=/ \
  --with-newlib \
  --without-headers \
  --enable-default-pie \
  --enable-default-ssp \
  --disable-nls \
  --disable-shared \
  --disable-multilib \
  --disable-threads \
  --disable-libatomic \
  --disable-libgomp \
  --disable-libquadmath \
  --disable-libssp \
  --disable-libvtv \
  --disable-libstdcxx \
  --enable-languages=c,c++
make $MAKEFLAGS
make install

# Generate limits.h from the bare-metal gcc
cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  $(dirname $($LFS_TGT-gcc -print-libgcc-file-name))/include/limits.h

cd $SOURCES
rm -rf gcc-${GCC_VER}

# ---------------------------------------------------------------------------
# 3. Zen Kernel Headers
# ---------------------------------------------------------------------------
echo ">>> Installing zen-kernel headers..."
tar -xf zen-kernel-${ZEN_KERNEL_TAG}.tar.gz
# GitHub strips the leading 'v' from the tag in the unpacked dir name
ZEN_STRIP=${ZEN_KERNEL_TAG#v}
ZEN_DIR="zen-kernel-${ZEN_STRIP}"
if [ ! -d "$ZEN_DIR" ]; then
  echo "ERROR: Expected directory $ZEN_DIR not found after extraction"
  echo "Found: $(ls -d zen-kernel-* 2>/dev/null || echo nothing)"
  exit 1
fi
cd $ZEN_DIR
make mrproper
make headers
find usr/include -type f ! -name '*.h' -delete
mkdir -pv /tools/include
cp -rv usr/include/* /tools/include/
cd $SOURCES
rm -rf $ZEN_DIR

# ---------------------------------------------------------------------------
# 4. Glibc
# ---------------------------------------------------------------------------
echo ">>> Building glibc..."
tar -xf glibc-${GLIBC_VER}.tar.xz
cd glibc-${GLIBC_VER}

# Fix for FHS compliance
ln -sfv ../lib/ld-linux-x86-64.so.2 /tools/lib64
ln -sfv ../lib/ld-linux-x86-64.so.2 /tools/lib64/ld-lsb-x86-64.so.3

mkdir -v build && cd build
echo "rootsbindir=/tools/sbin" >configparms
../configure \
  --prefix=/tools \
  --host=$LFS_TGT \
  --build=$(../scripts/config.guess) \
  --enable-kernel=5.4 \
  --with-headers=/tools/include \
  libc_cv_slibdir=/tools/lib
make $MAKEFLAGS
make install

# Sanity check: make sure the cross-linker works
echo 'int main(){}' | $LFS_TGT-gcc -x c - -o /tmp/dummy
readelf -l /tmp/dummy | grep -q "Requesting program interpreter: /tools"
echo ">>> Glibc sanity check passed."
rm /tmp/dummy

cd $SOURCES
rm -rf glibc-${GLIBC_VER}

# ---------------------------------------------------------------------------
# 5. Libstdc++ (from GCC sources)
# ---------------------------------------------------------------------------
echo ">>> Building libstdc++..."
tar -xf gcc-${GCC_VER}.tar.xz
cd gcc-${GCC_VER}
mkdir -v build && cd build
../libstdc++-v3/configure \
  --host=$LFS_TGT \
  --build=$(../config.guess) \
  --prefix=/tools \
  --disable-multilib \
  --disable-nls \
  --disable-libstdcxx-pch \
  --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/${GCC_VER}
make $MAKEFLAGS
make install
# Remove libtool archives that could cause issues later
rm -v /tools/lib/lib{stdc++{,exp},supc++}.la
cd $SOURCES
rm -rf gcc-${GCC_VER}

echo ">>> Stage 1 complete: cross-toolchain installed to /tools"

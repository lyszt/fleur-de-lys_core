#!/bin/bash
# build_glibc.sh — Stage 1b: Glibc
# Runs as a separate Docker RUN step after build_toolchain.sh
# so failures here are fast to iterate on without rebuilding binutils/gcc.
# Target: x86_64-fleur-linux-gnu
# Installs to: /tools
set -ex

LFS_TGT=x86_64-fleur-linux-gnu
SOURCES=/sources
MAKEFLAGS="-j$(nproc)"
GLIBC_VER=2.41

cd $SOURCES

# Tarball should already be present from the download step in build_toolchain.sh
if [ ! -f glibc-${GLIBC_VER}.tar.xz ]; then
  echo ">>> glibc tarball not found, downloading..."
  wget -nc https://ftpmirror.gnu.org/glibc/glibc-${GLIBC_VER}.tar.xz
fi

# ---------------------------------------------------------------------------
# Glibc
# ---------------------------------------------------------------------------
echo ">>> Building glibc..."
tar -xf glibc-${GLIBC_VER}.tar.xz
cd glibc-${GLIBC_VER}

# /tools/lib must exist before we can create the lib64 symlinks
mkdir -pv /tools/lib

# FHS compat symlinks — the dynamic linker lives in /tools/lib
ln -sfv ../lib/ld-linux-x86-64.so.2 /tools/lib64
ln -sfv ../lib/ld-linux-x86-64.so.2 /tools/lib64/ld-lsb-x86-64.so.3

mkdir -v build && cd build

# configparms lets us override the sbindir without patching the Makefile
echo "rootsbindir=/tools/sbin" >configparms

../configure \
  --prefix=/tools \
  --host=$LFS_TGT \
  --build=$(../scripts/config.guess) \
  --enable-kernel=5.4 \
  --with-headers=/tools/include \
  --with-sysroot=/tools \
  libc_cv_slibdir=/tools/lib

make $MAKEFLAGS
make install

# ---------------------------------------------------------------------------
# Sanity check: cross-linker must use /tools as its interpreter prefix
# ---------------------------------------------------------------------------
echo ">>> Running glibc sanity check..."
echo 'int main(){}' | $LFS_TGT-gcc -x c - -o /tmp/dummy

INTERP=$(readelf -l /tmp/dummy | grep "program interpreter" || true)
echo "Interpreter line: $INTERP"

if echo "$INTERP" | grep -q "/tools"; then
  echo ">>> Glibc sanity check passed."
else
  echo "ERROR: Program interpreter does not point into /tools!"
  echo "       Got: $INTERP"
  echo "       This means glibc was not built with the right sysroot."
  rm /tmp/dummy
  exit 1
fi

rm /tmp/dummy

cd $SOURCES
rm -rf glibc-${GLIBC_VER}

echo ">>> Glibc build complete."

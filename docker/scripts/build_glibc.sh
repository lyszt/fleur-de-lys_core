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

# On any failure, print the last 100 lines of the build log if it exists
trap 'if [ -f /sources/glibc-build.log ]; then
        echo "=== GLIBC BUILD LOG (last 100 lines) ==="
        tail -100 /sources/glibc-build.log
      fi' ERR

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

# lib64 is a symlink to lib — create it first, then create the lsb symlink
# directly in /tools/lib (not through the lib64 symlink) to avoid
# "not a directory" errors when ln tries to dereference the symlink
ln -sfv ../lib/ld-linux-x86-64.so.2 /tools/lib64
ln -sfv ld-linux-x86-64.so.2 /tools/lib/ld-lsb-x86-64.so.3

mkdir -v build && cd build

# Redirect full build log to a file — Docker clips at 2MiB but the file persists
# If the build fails, cat the tail so we can see the real error
BUILD_LOG=/sources/glibc-build.log
exec > >(tee $BUILD_LOG) 2>&1

# configparms lets us override the sbindir without patching the Makefile
echo "rootsbindir=/tools/sbin" >configparms

../configure \
  --prefix=/tools \
  --host=$LFS_TGT \
  --build=$(../scripts/config.guess) \
  --enable-kernel=5.4 \
  --with-headers=/tools/include \
  libc_cv_slibdir=/tools/lib \
  libc_cv_rtlddir=/tools/lib

# Glibc has known parallel build race conditions — cap at -j4
make -j4
make -j1 install

# ---------------------------------------------------------------------------
# Patch GCC specs so the cross-compiler uses /tools as its dynamic linker
# prefix rather than the sysroot-relative /lib64 path baked in at gcc
# pass 1 configure time.
# ---------------------------------------------------------------------------
echo ">>> Patching GCC specs to use /tools dynamic linker..."

SPECFILE=$(dirname $($LFS_TGT-gcc -print-libgcc-file-name))/specs
$LFS_TGT-gcc -dumpspecs >$SPECFILE

# Replace any reference to /lib64/ld-linux-x86-64 or /lib/ld-linux-x86-64
# with the /tools-prefixed path
sed -i \
  -e 's|/lib64/ld-linux-x86-64.so.2|/tools/lib/ld-linux-x86-64.so.2|g' \
  -e 's|/lib/ld-linux-x86-64.so.2|/tools/lib/ld-linux-x86-64.so.2|g' \
  $SPECFILE

echo ">>> Specs file written to: $SPECFILE"
grep "ld-linux" $SPECFILE | head -5

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
  echo "       Specs file contents:"
  cat $SPECFILE
  rm /tmp/dummy
  exit 1
fi

rm /tmp/dummy

cd $SOURCES
rm -rf glibc-${GLIBC_VER}

echo ">>> Glibc build complete."

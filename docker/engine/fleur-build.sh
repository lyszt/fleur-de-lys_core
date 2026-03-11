#!/bin/bash
set -e

LFS_TGT="x86_64-fleur-linux-gnu"
MAKEFLAGS="-j$(nproc)"
STAGE="${FLEUR_STAGE:-1}"

if [ "$STAGE" = "2" ]; then
  export PATH="/usr/bin:/bin:/tools/bin"
  unset CPATH
  unset LIBRARY_PATH
  unset LD_LIBRARY_PATH
  # Force all stage 2 packages to link against /tools/lib, not host glibc
  export LDFLAGS="-L/tools/lib -Wl,-rpath,/tools/lib -Wl,--dynamic-linker=/tools/lib/ld-linux-x86-64.so.2"
  # Wrapper scripts so CC/CXX have no spaces — autoconf breaks on spaces in $CC
  cat >/usr/local/bin/fleur-cc <<'WRAPPER'
#!/bin/sh
exec clang --sysroot=/ "$@"
WRAPPER
  cat >/usr/local/bin/fleur-cxx <<'WRAPPER'
#!/bin/sh
exec clang++ --sysroot=/ "$@"
WRAPPER
  chmod +x /usr/local/bin/fleur-cc /usr/local/bin/fleur-cxx
  export CC=/usr/local/bin/fleur-cc
  export CXX=/usr/local/bin/fleur-cxx
else
  export PATH="/tools/bin:/usr/bin:/bin"
  export CPATH="/tools/include"
  export LIBRARY_PATH="/tools/lib"
fi

export PKG_CONFIG_PATH=""
export PKG_CONFIG_LIBDIR="/tools/lib/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="/"

build_recipe() {
  local RECIPE_FILE=$1
  if [ ! -f "$RECIPE_FILE" ]; then
    echo "Error: Recipe $RECIPE_FILE not found."
    exit 1
  fi

  unset PKG_NAME PKG_VER SRC_URI EXTRA_CONF SRC_URI_DEPS
  unset -f do_configure do_compile do_install
  source "$RECIPE_FILE"

  echo ">>> Engine: Starting build for ${PKG_NAME} ${PKG_VER} (stage ${STAGE})"
  cd /sources

  local TARBALL
  local WORKDIR
  local META_WORKDIR=0

  if [ -n "$SRC_URI" ]; then
    TARBALL=$(basename "$SRC_URI")
  else
    TARBALL=$(ls ${PKG_NAME}-${PKG_VER}.tar.* 2>/dev/null | head -1)
  fi

  if [ -n "$TARBALL" ] && [ -f "$TARBALL" ]; then
    WORKDIR=$(tar -tf "$TARBALL" 2>/dev/null | head -1 | cut -d/ -f1)
    WORKDIR="/sources/${WORKDIR}"
    tar -xf "$TARBALL"
    if [ -z "$WORKDIR" ] || [ ! -d "$WORKDIR" ]; then
      echo "Error: could not find extracted directory for ${PKG_NAME} ${PKG_VER} (tarball: $TARBALL)"
      exit 1
    fi
  elif [ -n "$SRC_URI" ]; then
    echo "Error: tarball not found for ${PKG_NAME} ${PKG_VER}"
    exit 1
  else
    META_WORKDIR=1
    WORKDIR="/tmp/fleur-meta-${PKG_NAME}-${PKG_VER}"
    rm -rf "$WORKDIR"
    mkdir -p "$WORKDIR"
    echo ">>> Engine: No source tarball for ${PKG_NAME}; using ${WORKDIR}"
  fi

  echo ">>> Engine: Building in ${WORKDIR}"

  (
    cd "$WORKDIR"
    if declare -f do_configure >/dev/null; then
      do_configure
    elif [ "$STAGE" = "2" ]; then
      ./configure --prefix=/tools $EXTRA_CONF
    else
      ./configure --prefix=/tools --host=$LFS_TGT --disable-static $EXTRA_CONF
    fi
  )

  (
    cd "$WORKDIR"
    if declare -f do_compile >/dev/null; then
      do_compile
    else
      make $MAKEFLAGS
    fi
  )

  (
    cd "$WORKDIR"
    if declare -f do_install >/dev/null; then
      do_install
    else
      make install
    fi
  )

  if [ "$META_WORKDIR" = "1" ]; then
    rm -rf "$WORKDIR"
  else
    cd /sources
    rm -rf "$WORKDIR"
  fi
}

for recipe in "$@"; do
  build_recipe "$recipe"
done

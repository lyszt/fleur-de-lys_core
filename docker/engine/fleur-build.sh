#!/bin/bash
set -e

LFS_TGT="x86_64-fleur-linux-gnu"
MAKEFLAGS="-j$(nproc)"

STAGE="${FLEUR_STAGE:-1}"

if [ "$STAGE" = "2" ]; then
  export PATH="/usr/bin:/bin:/tools/bin"
  unset CPATH
  unset LIBRARY_PATH
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

  # Derive tarball filename from SRC_URI if set, otherwise guess
  local TARBALL
  if [ -n "$SRC_URI" ]; then
    TARBALL=$(basename "$SRC_URI")
  else
    TARBALL=$(ls ${PKG_NAME}-${PKG_VER}.tar.* 2>/dev/null | head -1)
  fi

  if [ -z "$TARBALL" ] || [ ! -f "$TARBALL" ]; then
    echo "Error: tarball not found for ${PKG_NAME} ${PKG_VER}"
    exit 1
  fi

  local WORKDIR
  WORKDIR=$(tar -tf "$TARBALL" 2>/dev/null | head -1 | cut -d/ -f1)
  WORKDIR="/sources/${WORKDIR}"
  tar -xf "$TARBALL"

  if [ -z "$WORKDIR" ] || [ ! -d "$WORKDIR" ]; then
    echo "Error: could not find extracted directory for ${PKG_NAME} ${PKG_VER} (tarball: $TARBALL)"
    exit 1
  fi

  echo ">>> Engine: Building in ${WORKDIR}"

  (
    cd "$WORKDIR"
    if declare -f do_configure >/dev/null; then
      do_configure
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

  cd /sources
  rm -rf "$WORKDIR"
}

for recipe in "$@"; do
  build_recipe "$recipe"
done

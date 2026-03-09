#!/bin/bash
set -e

LFS_TGT="x86_64-fleur-linux-gnu"
MAKEFLAGS="-j$(nproc)"

# Enforce strict isolation
export PATH="/tools/bin:/usr/bin:/bin"
export CPATH="/tools/include"
export LIBRARY_PATH="/tools/lib"
export PKG_CONFIG_PATH=""
export PKG_CONFIG_LIBDIR="/tools/lib/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="/"

build_recipe() {
  local RECIPE_FILE=$1
  if [ ! -f "$RECIPE_FILE" ]; then
    echo "Error: Recipe $RECIPE_FILE not found."
    exit 1
  fi

  # Load recipe variables (PKG_NAME, PKG_VER, SRC_URI, DEPENDS)
  source "$RECIPE_FILE"

  local WORKDIR="/sources/${PKG_NAME}-${PKG_VER}"
  echo ">>> Engine: Starting build for ${PKG_NAME} ${PKG_VER}"

  # 1. Fetch (Integration with fetch_sources.sh logic)
  # /engine/fetch_sources.sh "$SRC_URI"

  # 2. Extract
  cd /sources
  tar -xf ${PKG_NAME}-${PKG_VER}.tar.* cd "$WORKDIR"

  # 3. Configure
  if declare -f do_configure >/dev/null; then
    do_configure
  else
    ./configure --prefix=/tools --host=$LFS_TGT --disable-static
  fi

  # 4. Compile
  if declare -f do_compile >/dev/null; then
    do_compile
  else
    make $MAKEFLAGS
  fi

  # 5. Install
  if declare -f do_install >/dev/null; then
    do_install
  else
    make install
  fi

  # Cleanup
  cd /sources
  rm -rf "$WORKDIR"

  # Unset functions to prevent leaking into the next recipe
  unset -f do_configure do_compile do_install || true
}

for recipe in "$@"; do
  build_recipe "$recipe"
done

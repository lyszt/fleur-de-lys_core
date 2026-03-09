#!/bin/bash
# fetch_sources.sh — Stage 2a: Download all temptools sources
# Runs as its own Docker RUN step so download failures are cheap to retry
# without re-running any builds. build_temptools.sh assumes all tarballs
# are already present in /sources when it runs.
set -e

SOURCES=/sources
cd $SOURCES

# ---------------------------------------------------------------------------
# Package versions — must stay in sync with build_temptools.sh
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

  if [ -f "$FILE" ]; then
    echo "  [cache] $FILE"
    return 0
  fi

  # Expand any ftpmirror.gnu.org URL into a prioritised mirror list
  local EXPANDED=()
  for URL in "${URLS[@]}"; do
    if echo "$URL" | grep -q "ftpmirror.gnu.org"; then
      local PATH_PART="${URL#*ftpmirror.gnu.org}"
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

  for URL in "${EXPANDED[@]}"; do
    local HOST
    HOST=$(echo "$URL" | awk -F/ '{print $3}')
    echo "  [fetch] $FILE from $HOST ..."

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
  done

  echo "ERROR: Could not download $FILE — tried ${#EXPANDED[@]} URLs"
  return 1
}

fetch_gnu() {
  local FILE=$1
  local GNU_PATH=$2
  fetch "$FILE" "https://ftpmirror.gnu.org/${GNU_PATH}"
}

# ---------------------------------------------------------------------------
# GNU packages
# ---------------------------------------------------------------------------
echo ">>> Downloading GNU sources..."

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

# MPC is on ftp.gnu.org but not ftpmirror
fetch "mpc-${MPC_VER}.tar.gz" \
  "https://ftp.gnu.org/gnu/mpc/mpc-${MPC_VER}.tar.gz" \
  "https://mirror.csclub.uwaterloo.ca/gnu/mpc/mpc-${MPC_VER}.tar.gz"

# ---------------------------------------------------------------------------
# Third-party packages
# ---------------------------------------------------------------------------
echo ">>> Downloading third-party sources..."

fetch "zsh-${ZSH_VER}.tar.xz" \
  "https://sourceforge.net/projects/zsh/files/zsh/${ZSH_VER}/zsh-${ZSH_VER}.tar.xz" \
  "https://github.com/zsh-users/zsh/archive/refs/tags/zsh-${ZSH_VER}.tar.gz"

fetch "zstd-${ZSTD_VER}.tar.gz" \
  "https://github.com/facebook/zstd/releases/download/v${ZSTD_VER}/zstd-${ZSTD_VER}.tar.gz"

fetch "kmod-${KMOD_VER}.tar.xz" \
  "https://www.kernel.org/pub/linux/utils/kernel/kmod/kmod-${KMOD_VER}.tar.xz" \
  "https://mirrors.edge.kernel.org/pub/linux/utils/kernel/kmod/kmod-${KMOD_VER}.tar.xz"

fetch "shadow-${SHADOW_VER}.tar.xz" \
  "https://github.com/shadow-maint/shadow/releases/download/${SHADOW_VER}/shadow-${SHADOW_VER}.tar.xz"

fetch "Python-${PYTHON_VER}.tar.xz" \
  "https://www.python.org/ftp/python/${PYTHON_VER}/Python-${PYTHON_VER}.tar.xz"

fetch "cmake-${CMAKE_VER}.tar.gz" \
  "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VER}/cmake-${CMAKE_VER}.tar.gz"

fetch "meson-${MESON_VER}.tar.gz" \
  "https://github.com/mesonbuild/meson/releases/download/${MESON_VER}/meson-${MESON_VER}.tar.gz"

fetch "ninja-${NINJA_VER}.tar.gz" \
  "https://github.com/ninja-build/ninja/archive/refs/tags/v${NINJA_VER}.tar.gz"

fetch "pkgconf-${PKGCONF_VER}.tar.xz" \
  "https://distfiles.ariadne.space/pkgconf/pkgconf-${PKGCONF_VER}.tar.xz" \
  "https://github.com/pkgconf/pkgconf/releases/download/pkgconf-${PKGCONF_VER}/pkgconf-${PKGCONF_VER}.tar.xz"

echo ">>> All sources downloaded successfully."

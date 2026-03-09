#!/bin/bash
# fetch_sources.sh — Download all sources declared in recipes
# Reads SRC_URI, SRC_URI_DEPS, and SRC_URI_MIRRORS from each recipe.
# Runs as its own Docker RUN step so download failures are cheap to retry
# without invalidating build layers.
set -e

SOURCES=/sources
cd $SOURCES

# GNU mirror list — tried in order for any gnu.org URL (university mirrors first)
GNU_MIRRORS=(
  "https://ftp.gnu.org/gnu"                 # official
  "https://mirror.csclub.uwaterloo.ca/gnu"  # University of Waterloo, Canada
  "https://ftp.osuosl.org/pub/gnu"          # Oregon State University, USA
  "https://mirrors.kernel.org/gnu"          # kernel.org
  "https://mirrors.dotsrc.org/gnu"          # Danish academic network
  "https://ftp.funet.fi/pub/gnu"            # Finnish University & Research Network
  "https://ftpmirror.gnu.org"               # GNU round-robin (last resort)
)

# ---------------------------------------------------------------------------
# fetch <primary-url> [mirror-url ...]
#
# GNU URLs (any gnu.org host) are expanded into the full mirror list above.
# Additional mirror URLs can be passed as extra arguments; they are tried
# after all expansions of the primary URL have been exhausted.
# SRC_URI_MIRRORS from a recipe is passed here via word-splitting.
# ---------------------------------------------------------------------------
fetch() {
  local FILE
  FILE=$(basename "$1")

  if [ -f "$FILE" ]; then
    echo "  [cache] $FILE"
    return 0
  fi

  local ALL_URLS=()

  for URL in "$@"; do
    # Any gnu.org URL gets the full mirror treatment
    if echo "$URL" | grep -qE "(ftp|ftpmirror)\.gnu\.org"; then
      local PATH_PART
      PATH_PART=$(echo "$URL" | sed -E 's|https?://[^/]+(/gnu)?||')
      for MIRROR in "${GNU_MIRRORS[@]}"; do
        ALL_URLS+=("${MIRROR}${PATH_PART}")
      done
    else
      ALL_URLS+=("$URL")
    fi
  done

  for TRY_URL in "${ALL_URLS[@]}"; do
    local HOST
    HOST=$(echo "$TRY_URL" | awk -F/ '{print $3}')
    echo "  [fetch] $FILE from $HOST ..."

    if ! curl -sf --max-time 5 --head "$TRY_URL" >/dev/null 2>&1; then
      echo "  [skip]  $HOST unreachable"
      continue
    fi

    if wget -q --timeout=60 --tries=2 -O "$FILE.tmp" "$TRY_URL"; then
      mv "$FILE.tmp" "$FILE"
      echo "  [ok]    $FILE"
      return 0
    else
      rm -f "$FILE.tmp"
      echo "  [fail]  $TRY_URL"
    fi
  done

  echo "ERROR: Could not download $FILE"
  return 1
}

# ---------------------------------------------------------------------------
# Read SRC_URI, SRC_URI_DEPS, and SRC_URI_MIRRORS from each recipe
# ---------------------------------------------------------------------------
if [ $# -eq 0 ]; then
  echo "Usage: fetch_sources <recipe1> [recipe2] ..."
  exit 1
fi

for RECIPE in "$@"; do
  if [ ! -f "$RECIPE" ]; then
    echo "Error: Recipe $RECIPE not found."
    exit 1
  fi

  unset PKG_NAME PKG_VER SRC_URI SRC_URI_DEPS SRC_URI_MIRRORS
  source "$RECIPE"

  echo ">>> Fetching sources for ${PKG_NAME} ${PKG_VER}"

  if [ -n "$SRC_URI" ]; then
    # SRC_URI_MIRRORS is word-split intentionally to pass each URL as a separate arg
    # shellcheck disable=SC2086
    fetch "$SRC_URI" $SRC_URI_MIRRORS
  fi

  if [ -n "$SRC_URI_DEPS" ]; then
    for DEP_URL in $SRC_URI_DEPS; do
      [ -n "$DEP_URL" ] && fetch "$DEP_URL"
    done
  fi
done

echo ">>> All sources downloaded successfully."

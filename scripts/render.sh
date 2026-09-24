#!/usr/bin/env bash
# Renders each diagram source into the light and dark SVGs the READMEs embed, then makes them
# GitHub-safe (icons inlined) and animated. A clean exit is the renderer's completion gate: d2's
# own `validate` only checks syntax, so a real render is the check that catches a bad shape name.
#
# Usage: render.sh [--layout tala|elk|dagre] [--png] [FILE.d2...]
#   default files   diagrams/*.d2
#   --layout        first engine to try (default $D2_LAYOUT, else tala); falls back tala -> elk -> dagre
#   --png           also write a light-theme PNG per diagram for a visual check, inside .git so it
#                   can never be committed; the last line of output names the directory

set -uo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
layout="${D2_LAYOUT:-tala}"
png_dir=""
files=()
while [ $# -gt 0 ]; do
  case $1 in
    --layout) layout=$2; shift 2 ;;
    --png)
      png_dir=$(git rev-parse --git-path d2-diagrams/png 2>/dev/null || echo "${TMPDIR:-/tmp}/d2-diagrams/png")
      shift
      ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) files+=("$1"); shift ;;
  esac
done
if [ ${#files[@]} -eq 0 ]; then
  for f in diagrams/*.d2; do [ -f "$f" ] && files+=("$f"); done
fi
if [ ${#files[@]} -eq 0 ]; then
  echo "no .d2 files to render" >&2
  exit 1
fi

if ! command -v d2 >/dev/null 2>&1; then
  echo "d2 is not installed: brew install d2, or curl -fsSL https://d2lang.com/install.sh | sh -s --" >&2
  exit 1
fi
# d2 before 0.9.0 embeds icons in the compressed form the icon CDN now serves, and those icons
# render blank. TALA ships bundled from 0.9.0, so its presence is the version probe.
if ! d2 layout tala >/dev/null 2>&1; then
  echo "d2 is older than 0.9.0: brew upgrade d2, or go install github.com/d2lang/d2@latest" >&2
  exit 1
fi
# Icon inlining and tangle scoring run on the python3 that macOS's Command Line Tools ship beside
# git, so the plugin asks nothing of a machine that can already run git.
if ! python3 -c 'import sys; sys.exit(sys.version_info < (3, 9))' 2>/dev/null; then
  echo "python3 3.9+ is required: xcode-select --install on macOS, or your distro's python3" >&2
  exit 1
fi

case $layout in
  tala) engines=(tala elk dagre) ;;
  elk) engines=(elk dagre) ;;
  *) engines=("$layout") ;;
esac
[ -n "$png_dir" ] && mkdir -p "$png_dir"

# d2 fetches remote icons on every render and its resolver fails intermittently, so icons are
# fetched once with curl, cached, and handed to d2 as local files. The committed .d2 keeps its URLs.
cache="${XDG_CACHE_HOME:-$HOME/.cache}/d2-diagrams/icons"
mkdir -p "$cache"
localize() {
  local src=$1 dest=$2 url file
  cp "$src" "$dest"
  grep -oE 'icon: *https?://[^[:space:]};"]+' "$src" | sed 's/^icon: *//' | sort -u | while IFS= read -r url; do
    file="$cache/$(printf '%s' "$url" | git hash-object --stdin | cut -c1-16).svg"
    if [ ! -s "$file" ]; then
      curl -fsSL --compressed --retry 3 --max-time 20 -o "$file.tmp" "$url" 2>/dev/null &&
        grep -q '<svg' "$file.tmp" && mv "$file.tmp" "$file"
      rm -f "$file.tmp"
    fi
    if [ -s "$file" ]; then
      URL=$url FILE=$file perl -pi -e 's/\Q$ENV{URL}\E/$ENV{FILE}/g' "$dest"
    else
      echo "  icon unavailable, rendering without it: $url" >&2
      URL=$url perl -pi -e 's/^[ \t]*icon:[ \t]*\Q$ENV{URL}\E[ \t]*$//; s/icon:[ \t]*\Q$ENV{URL}\E;?//g' "$dest"
    fi
  done
}

failed=0
for src in "${files[@]}"; do
  base="${src%.d2}"
  # The localized copy sits beside the source so relative imports inside it still resolve.
  work="$(dirname "$src")/.render-$(basename "$src")"
  trap 'rm -f "$work"' EXIT
  localize "$src" "$work"
  used=""
  err=""
  for engine in "${engines[@]}"; do
    # --omit-version keeps a d2 upgrade from rewriting every SVG when the diagram did not change.
    args=(--omit-version --layout "$engine")
    # TALA keeps the best of the seeded layouts it tries. Its default 3 left twice the crossings of
    # its ceiling of 16 on a real 79-edge diagram, for about two seconds more.
    [ "$engine" = tala ] && args+=(--tala-seeds 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16)
    if err=$(d2 "${args[@]}" --theme 0 "$work" "$base-light.svg" 2>&1) &&
      err=$(d2 "${args[@]}" --theme 200 "$work" "$base-dark.svg" 2>&1); then
      used=$engine
      break
    fi
  done
  if [ -z "$used" ]; then
    rm -f "$work"
    echo "FAIL $src" >&2
    printf '%s\n' "$err" | grep -v '^success' | sed "s#$work#$src#g; s/^/  /" >&2
    failed=1
    continue
  fi

  # d2 writes 0600 files, which a web server or a teammate's checkout script may not read.
  chmod 644 "$base-light.svg" "$base-dark.svg"
  tangle=$(python3 "$script_dir/tangle.py" "$base-light.svg" 2>/dev/null) || tangle="tangle not scored"
  # A copy from before the animation CSS: a rasterizer that can't play animations would freeze
  # every solid edge mid-dash.
  [ -n "$png_dir" ] && cp "$base-light.svg" "$png_dir/.$(basename "$base").svg"
  if grep -q '<image ' "$base-light.svg" "$base-dark.svg"; then
    python3 "$script_dir/inline-svg-icons.py" "$base-light.svg" "$base-dark.svg" >/dev/null || failed=1
    if grep -q '<image ' "$base-light.svg" "$base-dark.svg"; then
      echo "FAIL $src: an icon could not be inlined (named above); pick another icon or drop it" >&2
      failed=1
    fi
  fi
  "$script_dir/enhance-svg.sh" "$base-light.svg" "$base-dark.svg" >/dev/null || failed=1
  # verify.sh matches this against the .d2 to catch a source edited after its render. File times
  # can't tell: a fresh clone writes files in name order, so the SVGs come out older.
  hash=$(git hash-object "$src")
  HASH=$hash perl -0777 -i -pe 's{<svg\b[^>]*>}{$&<!-- d2-source: $ENV{HASH} -->}' "$base-light.svg" "$base-dark.svg"

  if [ -n "$png_dir" ]; then
    png="$png_dir/$(basename "$base").png"
    raw="$png_dir/.$(basename "$base").svg"
    # d2's own PNG export chokes on some icon gradients, so fall back to rasterizing the render.
    d2 "${args[@]}" --theme 0 "$work" "$png" >/dev/null 2>&1 ||
      { command -v rsvg-convert >/dev/null 2>&1 && rsvg-convert -o "$png" "$raw" 2>/dev/null; } ||
      { command -v qlmanage >/dev/null 2>&1 && qlmanage -t -s 2400 -o "$png_dir" "$raw" >/dev/null 2>&1 &&
        mv "$raw.png" "$png"; } ||
      echo "  (no PNG for $src: d2, rsvg-convert and qlmanage all failed; the SVGs are fine)" >&2
    rm -f "$raw"
  fi
  rm -f "$work"
  echo "ok   $src ($used) $tangle"
done

[ -n "$png_dir" ] && echo "png: $(cd "$png_dir" && pwd)"
exit $failed

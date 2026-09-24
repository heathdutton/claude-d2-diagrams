#!/usr/bin/env bash
# Mechanical gate for ./diagrams: every expected file exists, every SVG is well-formed, GitHub-safe,
# animated and newer than its source, the detailed docs cite code, and the landing page embeds
# every render. Exit 0 is the bar the skill must reach before stamp.sh runs.
#
# Usage: verify.sh [--only infrastructure|architecture]

set -uo pipefail

out=diagrams
families=(infrastructure architecture)
if [ "${1:-}" = --only ]; then
  families=("$2")
fi

failures=0
fail() {
  echo "FAIL $*"
  failures=$((failures + 1))
}
warn() { echo "warn $*"; }

well_formed() {
  if command -v xmllint >/dev/null 2>&1; then
    xmllint --noout "$1" 2>&1 | head -3
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys, xml.dom.minidom as m; m.parse(sys.argv[1])' "$1" 2>&1 | tail -1
  fi
}

for family in "${families[@]}"; do
  for kind in "$family" "$family-simplified"; do
    for f in "$out/$kind.md" "$out/$kind.d2" "$out/$kind-light.svg" "$out/$kind-dark.svg"; do
      [ -s "$f" ] || fail "$f is missing or empty"
    done
    [ -s "$out/$kind.d2" ] || continue

    for svg in "$out/$kind-light.svg" "$out/$kind-dark.svg"; do
      [ -s "$svg" ] || continue
      problem=$(well_formed "$svg")
      [ -n "$problem" ] && fail "$svg is not well-formed XML: $problem"
      grep -q '<image ' "$svg" && fail "$svg still has <image> icons, which render blank on GitHub"
      grep -q 'D2 Diagram Animations' "$svg" || fail "$svg is missing the animation CSS"
      grep -q "d2-source: $(git hash-object "$out/$kind.d2")" "$svg" ||
        fail "$svg was not rendered from the current $kind.d2: re-render"
    done

    # Infrastructure cites IaC by line. Architecture cites code by path and symbol, since symbols
    # outlive the edits that shift line numbers.
    if [ "$kind" = infrastructure ] && [ -s "$out/$kind.md" ]; then
      grep -qE '[A-Za-z0-9_./-]+\.[A-Za-z0-9]+:[0-9]+' "$out/$kind.md" ||
        fail "$out/$kind.md cites no path:line, so none of its claims are traceable"
    elif [ "$kind" = architecture ] && [ -s "$out/$kind.md" ]; then
      grep -qE '[A-Za-z0-9_-]+/[A-Za-z0-9_./-]+|[A-Za-z0-9_-]+\.[A-Za-z0-9]+(:[0-9]+)?`' "$out/$kind.md" ||
        fail "$out/$kind.md cites no source paths, so none of its claims are traceable"
    fi
  done
done

landing="$out/README.md"
if [ -s "$landing" ]; then
  for family in "${families[@]}"; do
    for kind in "$family" "$family-simplified"; do
      for theme in light dark; do
        grep -q "$kind-$theme.svg" "$landing" || fail "$landing does not embed $kind-$theme.svg"
      done
    done
  done
else
  fail "$landing is missing"
fi

if [ -s README.md ]; then
  for family in "${families[@]}"; do
    grep -q "$out/$family-simplified-light.svg" README.md ||
      warn "README.md does not embed $family-simplified (fine if that was a deliberate removal)"
  done
fi

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "ok   all checks passed"

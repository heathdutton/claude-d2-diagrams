#!/usr/bin/env bash
# Records which commit ./diagrams was built from and which paths it depends on, so status.sh can
# tell when a refresh is due. Run it last, after verify.sh passes: a stamp on a half-built set
# would hide the drift that still needs work.
#
# Usage: stamp.sh PATHSPEC...
#   PATHSPEC  git pathspecs the docs were derived from, e.g. infra/ '*.tf' services/api/go.mod

set -euo pipefail

if [ $# -eq 0 ]; then
  echo "usage: stamp.sh PATHSPEC..." >&2
  exit 2
fi
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "not a git repository: nothing to stamp" >&2
  exit 1
}

# status.sh matches every source with :(glob) magic, so validate them the same way here: one
# pathspec git rejects would blind every later drift check.
for spec in "$@"; do
  case $spec in :*) magic=$spec ;; *) magic=":(glob)$spec" ;; esac
  if ! git ls-files -- "$magic" >/dev/null 2>&1; then
    echo "not a valid pathspec: $spec" >&2
    exit 1
  fi
done

commit=$(git rev-parse HEAD)
mkdir -p diagrams
{
  echo "{"
  echo "  \"commit\": \"$commit\","
  echo "  \"sources\": ["
  printf '%s\n' "$@" | sort -u | sed 's/\\/\\\\/g; s/"/\\"/g; s/^/    "/; s/$/",/' | sed '$ s/,$//'
  echo "  ]"
  echo "}"
} >diagrams/manifest.json

echo "stamped diagrams/manifest.json at ${commit:0:7} with $(printf '%s\n' "$@" | sort -u | wc -l | tr -d ' ') sources"

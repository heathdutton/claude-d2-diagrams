#!/usr/bin/env bash
# Reports whether ./diagrams is current, what drifted since it was built, and the repo's
# diagram-relevant inventory. The d2:diagram skill injects the full report into its prompt, so this
# always exits 0: a failing probe must never abort the skill.
#
# Usage: status.sh [--nudge] [PROJECT_DIR]
#   --nudge  one line for the SessionStart hook, printed only when diagrams are stale

set -u

nudge=false
if [ "${1:-}" = --nudge ]; then
  nudge=true
  shift
fi
project="${1:-${CLAUDE_PROJECT_DIR:-.}}"
cd "$project" 2>/dev/null || true

out=diagrams
manifest="$out/manifest.json"
# The hook fires in every project, and a project without a manifest has nothing to nudge about.
$nudge && [ ! -f "$manifest" ] && exit 0

# Globs for files whose change can move a box or an arrow. Every source, including the ones a
# manifest lists, is matched with git's :(glob) magic, so `**/` spans directories and `*` does not.
iac_globs=(
  '**/*.tf' '**/*.tofu' '**/*.hcl' '**/Pulumi*.yaml' '**/cdk.json' '**/*.template.json'
  '**/*.template.yaml' '**/template.yaml' '**/samconfig.toml' '**/serverless.yml' '**/serverless.yaml'
  '**/Dockerfile*' '**/*.dockerfile' '**/docker-compose*.yml' '**/docker-compose*.yaml'
  '**/compose*.yml' '**/compose*.yaml' '**/Chart.yaml' '**/helmfile.yaml' '**/kustomization.yaml'
  '**/fly.toml' '**/render.yaml' '**/vercel.json' '**/netlify.toml' '**/wrangler.toml'
  '**/wrangler.json' '**/wrangler.jsonc' '**/app.yaml' '**/Procfile' '**/railway.json'
  '.github/workflows/*'
)
app_globs=(
  '**/package.json' '**/go.mod' '**/Cargo.toml' '**/pyproject.toml' '**/requirements*.txt'
  '**/Gemfile' '**/pom.xml' '**/build.gradle*' '**/composer.json' '**/*.csproj' '**/mix.exs'
  '**/openapi*.yaml' '**/openapi*.yml' '**/openapi*.json' '**/*.proto' '**/*.graphql'
  '**/schema.prisma'
)
magic() {
  local g
  for g in "$@"; do
    case $g in :*) printf '%s\n' "$g" ;; *) printf ':(glob)%s\n' "$g" ;; esac
  done
}
iac_specs=()
while IFS= read -r s; do iac_specs+=("$s"); done < <(magic "${iac_globs[@]}")
app_specs=()
while IFS= read -r s; do app_specs+=("$s"); done < <(magic "${app_globs[@]}")
exclude=(":(exclude)$out/" ':(exclude,glob)**/node_modules/**' ':(exclude,glob)**/vendor/**')

in_git=false
git rev-parse --is-inside-work-tree >/dev/null 2>&1 && in_git=true

k8s_files() {
  git grep -l -E '^apiVersion:' -- ':(glob)**/*.yaml' ':(glob)**/*.yml' "${exclude[@]}" 2>/dev/null
}

# stamp.sh writes one value per line, so sed can read its output when jq is missing. jq also
# reads a manifest a formatter has reflowed.
manifest_commit() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '.commit // empty' "$manifest" 2>/dev/null
  else
    sed -n 's/^ *"commit": *"\([0-9a-f]\{7,40\}\)".*/\1/p' "$manifest" | head -1
  fi
}
manifest_sources() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '.sources[]? // empty' "$manifest" 2>/dev/null
  else
    sed -n '/"sources": *\[/,/^ *\]/p' "$manifest" | sed -n 's/^ *"\(.*\)",\{0,1\} *$/\1/p'
  fi
}

state=new
base=""
note=""
sources=()
if $in_git && [ -f "$manifest" ]; then
  state=fresh
  base=$(manifest_commit)
  while IFS= read -r s; do [ -n "$s" ] && sources+=("$s"); done < <(manifest_sources | while IFS= read -r g; do magic "$g"; done)
  # A squash or rebase merge drops the stamped commit. The commit that brought the manifest in
  # holds the same diagrams, so drift is measured from there instead.
  if [ -n "$base" ] && ! git cat-file -e "$base^{commit}" 2>/dev/null; then
    landed=$(git log -1 --format=%H -- "$manifest" 2>/dev/null)
    note="stamped commit ${base:0:7} is not in this history; measuring from ${landed:0:7}, where the manifest landed"
    base=$landed
  fi
  [ -z "$base" ] && state=unknown-base
elif $in_git && [ -n "$(git ls-files "$out/*.d2" 2>/dev/null)" ]; then
  # Diagrams from before manifests existed: diff against the last commit that touched them.
  state=legacy
  base=$(git log -1 --format=%H -- "$out/*.d2" 2>/dev/null)
fi
if [ ${#sources[@]} -eq 0 ]; then
  sources=("${iac_specs[@]}" "${app_specs[@]}")
  while IFS= read -r f; do [ -n "$f" ] && sources+=(":(literal)$f"); done < <($in_git && k8s_files)
fi

changed=""
behind=0
if [ -n "$base" ] && [ "$state" != unknown-base ]; then
  # One malformed pathspec fails the whole diff, which would otherwise read as "nothing changed".
  if diff_out=$(git diff --name-status "$base" -- "${sources[@]}" "${exclude[@]}" 2>&1); then
    changed=$(
      {
        [ -n "$diff_out" ] && printf '%s\n' "$diff_out"
        git ls-files --others --exclude-standard -- "${sources[@]}" "${exclude[@]}" 2>/dev/null |
          awk '{ print "A\t" $0 }'
      } | sort -u -k2
    )
    behind=$(git rev-list --count "$base..HEAD" 2>/dev/null || echo 0)
    [ "$state" = fresh ] && [ -n "$changed" ] && state=stale
  else
    state=bad-sources
    note="git rejected a manifest source: $(printf '%s' "$diff_out" | head -1)"
  fi
fi
changed_count=0
[ -n "$changed" ] && changed_count=$(printf '%s\n' "$changed" | wc -l | tr -d ' ')

if $nudge; then
  if [ "$state" = stale ]; then
    noun="source files"
    [ "$changed_count" -eq 1 ] && noun="source file"
    echo "Diagrams in ./$out are stale: $changed_count $noun changed since they were built" \
      "from ${base:0:7}. /d2:diagram refreshes them."
  elif [ "$state" = bad-sources ] || [ "$state" = unknown-base ]; then
    echo "Diagrams in ./$out can't be checked for drift ($state). /d2:diagram --check explains."
  fi
  exit 0
fi

d2_line="missing (brew install d2, or curl -fsSL https://d2lang.com/install.sh | sh -s --)"
if command -v d2 >/dev/null 2>&1; then
  d2_line="$(d2 --version 2>/dev/null | head -1)"
  # The version string is unreliable across builds, so probe for TALA, which ships from 0.9.0.
  if d2 layout tala >/dev/null 2>&1; then
    d2_line="$d2_line, ok"
  else
    d2_line="$d2_line, too old: needs 0.9.0+ (brew upgrade d2, or go install github.com/d2lang/d2@latest)"
  fi
fi
python_line="ok"
python3 -c 'import sys; sys.exit(sys.version_info < (3, 9))' 2>/dev/null ||
  python_line="missing or older than 3.9: icons can't be inlined (xcode-select --install on macOS)"

echo "state: $state"
case $state in
  new) echo "  no ./$out/manifest.json: build everything" ;;
  fresh) echo "  nothing drifted since ${base:0:7}" ;;
  stale) echo "  $changed_count changed since ${base:0:7} ($behind commits behind HEAD): refresh" ;;
  legacy) echo "  diagrams predate manifests; last built at ${base:0:7}: refresh, then stamp" ;;
  unknown-base) echo "  ./$out/manifest.json has no usable commit: rebuild everything" ;;
  bad-sources) echo "  a source in ./$out/manifest.json is not a valid pathspec: rebuild everything" ;;
esac
[ -n "$note" ] && echo "  $note"
$in_git || echo "  not a git repository: drift tracking is off, every run builds everything"
echo "d2: $d2_line"
echo "python3: $python_line"
if [ -f "$out/rules.md" ]; then echo "rules: ./$out/rules.md"; else echo "rules: none"; fi
# 1.x copied its CSS into every project, where it reads as a deliberate override. Its selectors
# predate per-connection dash keyframes and its reduced-motion rule can't beat them.
if grep -q 'traffic-flow-slow' "$out/animations.css" 2>/dev/null; then
  echo "animations: ./$out/animations.css is the 1.x default copy: delete it so the current animations apply"
fi
# Terrastruct is winding down; its icon host serves the same files as icons.d2lang.com.
old_icons=$(grep -l 'icons\.terrastruct\.com' "$out"/*.d2 2>/dev/null | wc -l | tr -d ' ')
if [ "$old_icons" -gt 0 ]; then
  echo "icons: $old_icons .d2 files still load icons from icons.terrastruct.com: move them to icons.d2lang.com"
fi

if [ -n "$changed" ]; then
  echo "changed since ${base:0:7}:"
  printf '%s\n' "$changed" | head -60 | sed 's/^/  /'
  [ "$changed_count" -gt 60 ] && echo "  ... and $((changed_count - 60)) more (git diff --name-status $base)"
fi

$in_git || exit 0

list() {
  local label=$1 files
  files=$(cat)
  [ -z "$files" ] && return
  local n
  n=$(printf '%s\n' "$files" | wc -l | tr -d ' ')
  echo "  $label ($n):"
  if [ "$n" -le 40 ]; then
    printf '%s\n' "$files" | sed 's/^/    /'
  else
    printf '%s\n' "$files" | awk -F/ '{ print (NF > 1 ? $1 "/" : $0) }' | sort | uniq -c |
      sort -rn | awk '{ printf "    %s (%d files)\n", $2, $1 }'
  fi
}

echo "inventory:"
git ls-files -- "${iac_specs[@]}" "${exclude[@]}" | list "infrastructure and deploy"
k8s_files | list "kubernetes manifests"
git ls-files -- "${app_specs[@]}" "${exclude[@]}" | list "services, dependencies and API specs"
exit 0

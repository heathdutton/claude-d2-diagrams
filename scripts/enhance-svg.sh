#!/bin/bash
# SVG Enhancement Script for D2 Diagrams
# Adds CSS animations - reads from ./diagrams/animations.css

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Determine script directory and plugin root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# CSS file location - check local project first, then plugin
# This allows projects to customize animations by creating their own animations.css
LOCAL_CSS="./diagrams/animations.css"
PLUGIN_CSS="$PLUGIN_ROOT/diagrams/animations.css"

if [[ -f "$LOCAL_CSS" ]]; then
  CSS_FILE="$LOCAL_CSS"
elif [[ -f "$PLUGIN_CSS" ]]; then
  CSS_FILE="$PLUGIN_CSS"
else
  CSS_FILE=""  # Will use fallback
fi

# Fallback CSS if file not found (minimal, safe version)
FALLBACK_CSS='/* D2 Diagram Animations - Fallback */

@keyframes traffic-flow {
  from { stroke-dashoffset: 24; }
  to { stroke-dashoffset: 0; }
}

/* Only animate connection paths */
path[marker-end] {
  stroke-dasharray: 8 4;
  animation: traffic-flow 1s linear infinite;
}

/* Protect text from any animation side effects */
text, tspan, textPath {
  animation: none !important;
  filter: none !important;
  opacity: 1 !important;
}

@media (prefers-reduced-motion: reduce) {
  path[marker-end] { animation: none; }
}'

usage() {
  echo "Usage: $0 [OPTIONS] <svg-file|directory>"
  echo ""
  echo "Options:"
  echo "  --all          Enhance all SVG files in directory"
  echo "  --backup       Create .bak backup before modifying"
  echo "  --dry-run      Show what would be done without modifying"
  echo "  -h, --help     Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 ./diagrams/infrastructure-light.svg"
  echo "  $0 --all ./diagrams/"
  echo "  $0 --backup --all ./diagrams/"
  echo ""
  echo "CSS source: $CSS_FILE"
}

get_css() {
  if [[ -n "$CSS_FILE" && -f "$CSS_FILE" ]]; then
    cat "$CSS_FILE"
  else
    echo -e "${YELLOW}Warning: No animations.css found, using fallback${NC}" >&2
    echo "$FALLBACK_CSS"
  fi
}

enhance_svg() {
  local svg_file="$1"
  local backup="$2"
  local dry_run="$3"

  if [[ ! -f "$svg_file" ]]; then
    echo -e "${RED}Error: File not found: $svg_file${NC}"
    return 1
  fi

  if [[ "$svg_file" != *.svg ]]; then
    echo -e "${YELLOW}Skipping non-SVG file: $svg_file${NC}"
    return 0
  fi

  # Check if already enhanced
  if grep -q "D2 Diagram Animations" "$svg_file" 2>/dev/null; then
    echo -e "${YELLOW}Already enhanced: $svg_file${NC}"
    return 0
  fi

  if [[ "$dry_run" == "true" ]]; then
    echo -e "${GREEN}Would enhance: $svg_file${NC}"
    return 0
  fi

  # Create backup if requested
  if [[ "$backup" == "true" ]]; then
    cp "$svg_file" "${svg_file}.bak"
    echo -e "${YELLOW}Backup created: ${svg_file}.bak${NC}"
  fi

  # Get CSS content (same for light and dark - D2 handles theme colors)
  local css_content
  css_content=$(get_css)

  # Create temp file
  local temp_file
  temp_file=$(mktemp)

  # Insert style block right after opening <svg> tag
  if grep -q "<svg" "$svg_file"; then
    awk -v css="$css_content" '
    /<svg[^>]*>/ && !done {
      print
      print "<defs>"
      print "<style type=\"text/css\">"
      print "<![CDATA["
      print css
      print "]]>"
      print "</style>"
      print "</defs>"
      done=1
      next
    }
    {print}
    ' "$svg_file" > "$temp_file"
  else
    echo -e "${RED}Error: Invalid SVG structure in $svg_file${NC}"
    rm -f "$temp_file"
    return 1
  fi

  # Verify the temp file is valid and contains our CSS marker
  if [[ ! -s "$temp_file" ]]; then
    echo -e "${RED}Error: Enhancement produced empty file for $svg_file${NC}"
    rm -f "$temp_file"
    return 1
  fi

  if ! grep -q "traffic-flow" "$temp_file"; then
    echo -e "${RED}Error: CSS injection failed for $svg_file${NC}"
    rm -f "$temp_file"
    return 1
  fi

  # Replace original with enhanced version
  mv "$temp_file" "$svg_file"
  echo -e "${GREEN}Enhanced: $svg_file${NC}"
  return 0
}

# Parse arguments
ALL_MODE=false
BACKUP=false
DRY_RUN=false
TARGET=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --all)
      ALL_MODE=true
      shift
      ;;
    --backup)
      BACKUP=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      TARGET="$1"
      shift
      ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo -e "${RED}Error: No target specified${NC}"
  usage
  exit 1
fi

# Process files
if [[ "$ALL_MODE" == "true" ]]; then
  if [[ ! -d "$TARGET" ]]; then
    echo -e "${RED}Error: Directory not found: $TARGET${NC}"
    exit 1
  fi

  echo "Enhancing all SVG files in: $TARGET"
  if [[ -n "$CSS_FILE" ]]; then
    echo "Using CSS from: $CSS_FILE"
  else
    echo "Using fallback CSS (no animations.css found)"
  fi
  find "$TARGET" -name "*.svg" -type f | while read -r svg_file; do
    enhance_svg "$svg_file" "$BACKUP" "$DRY_RUN"
  done
else
  enhance_svg "$TARGET" "$BACKUP" "$DRY_RUN"
fi

echo -e "${GREEN}Enhancement complete!${NC}"

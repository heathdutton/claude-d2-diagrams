#!/bin/bash
# D2 syntax validator hook - validates D2 files after they're written
# and provides fix suggestions if syntax errors are found

# This hook is called after tool execution
# It checks if a .d2 file was just written and validates it

# Get the tool result from environment or stdin
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
FILE_PATH="${CLAUDE_FILE_PATH:-}"

# Only process if this was a Write tool and target is a .d2 file
if [[ "$TOOL_NAME" != "Write" ]] && [[ "$TOOL_NAME" != "Edit" ]]; then
  exit 0
fi

if [[ "$FILE_PATH" != *.d2 ]]; then
  exit 0
fi

# Check if file exists
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Check if d2 is available
if ! command -v d2 &> /dev/null; then
  echo "Warning: D2 not installed, cannot validate syntax"
  exit 0
fi

# Validate D2 syntax using d2 fmt (dry-run check)
VALIDATION_OUTPUT=$(d2 fmt "$FILE_PATH" --check 2>&1)
VALIDATION_STATUS=$?

if [[ $VALIDATION_STATUS -ne 0 ]]; then
  cat << EOF
D2 Syntax Validation Failed for: $FILE_PATH

Error details:
$VALIDATION_OUTPUT

Common D2 syntax issues:
- Missing closing braces or quotes
- Invalid connection syntax (use -> or -- not =>)
- Undefined shape references
- Invalid style properties

Suggested fix: Review the D2 syntax at https://d2lang.com/tour/intro
The file should be corrected before attempting SVG generation.
EOF
  exit 1
fi

# Try a test render to catch semantic errors
TEMP_SVG=$(mktemp /tmp/d2-validate-XXXXXX.svg)
RENDER_OUTPUT=$(d2 "$FILE_PATH" "$TEMP_SVG" --layout dagre 2>&1)
RENDER_STATUS=$?
rm -f "$TEMP_SVG"

if [[ $RENDER_STATUS -ne 0 ]]; then
  cat << EOF
D2 Render Validation Failed for: $FILE_PATH

The syntax is valid but rendering failed:
$RENDER_OUTPUT

This may indicate:
- Circular dependencies in layouts
- Invalid theme or layout options
- Resource constraints

Review the D2 file structure and try simplifying complex layouts.
EOF
  exit 1
fi

# Check for icon usage (warn if missing, unless rules.md disables icons)
ICON_COUNT=$(grep -c "icon:" "$FILE_PATH" 2>/dev/null || echo 0)
NODE_COUNT=$(grep -cE "^[a-zA-Z0-9_-]+:" "$FILE_PATH" 2>/dev/null || echo 0)

# Check if icons are disabled via rules.md
ICONS_DISABLED=false
if [[ -f "./diagrams/rules.md" ]]; then
  if grep -qi "disable.*icon\|no.*icon\|skip.*icon\|icons.*false\|icons.*disabled" "./diagrams/rules.md" 2>/dev/null; then
    ICONS_DISABLED=true
  fi
fi

# Warn if few icons detected (unless disabled)
if [[ "$ICONS_DISABLED" == "false" ]] && [[ $NODE_COUNT -gt 3 ]] && [[ $ICON_COUNT -lt 3 ]]; then
  cat << EOF
Warning: Few icons detected in $FILE_PATH
- Found $ICON_COUNT icon: properties for $NODE_COUNT nodes
- Icons require direct icon: URLs on nodes (class: alone won't work with --bundle)

Example of correct icon usage:
  database: MySQL {
    class: mysql
    icon: https://icons.terrastruct.com/dev%2Fmysql.svg
  }

To disable this warning, add to ./diagrams/rules.md:
  ## Icons
  - Disable icons

EOF
fi

echo "D2 validation passed: $FILE_PATH"
exit 0

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

echo "D2 validation passed: $FILE_PATH"
exit 0
